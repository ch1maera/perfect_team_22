import sys
import time
from datetime import datetime
from bs4 import BeautifulSoup
from utilities import database, levels  # these are just things I use in other scripts
from pathlib import Path
from sqlalchemy import MetaData, Table


def main(argv):

    src_path = '' #enter saved_games folder here
    p = Path(src_path)
    now = time.time()
    abbr = levels.level_map(argv[0])

    engine = database.connector()

    metadata = MetaData(bind=engine)
    metadata.reflect(engine)

    connection = engine.connect()

    input("Press any key when ready")

    for path in p.rglob("*.html"):

        ts = path.stat().st_ctime

        # Only care about files that were created after the script started
        if ts > now:
            print(path.joinpath())
            print(datetime.utcfromtimestamp(ts).strftime("%Y-%m-%d %H:%M:%S"))

            try:
                # The name of the stats export should parse out to a datetime
                # If it's not a date time then it's not a stats export
                name = str(path.joinpath()).split("\\")[-1].split(".")[0]
                datetime.strptime(name, "%Y-%m-%d-%H-%M-%S")
                stats = parse_report(path.joinpath())
                insert_records(connection, metadata, engine, stats, abbr)

            except ValueError:
                print("Something wrong with this report. Moving to the next one.")

    connection.close()
    

def parse_report(src_path):
    # this whole method is janky af and could easily break if I added another column to the export

    file = open(src_path, "r")
    soup = BeautifulSoup(file, "lxml")

    # I use the folder name as a proxy for tournament id
    tournament_id = str(src_path).split("\\")[6].split(".")[0]

    table = soup.select_one("table.data.sortable")
    headers = [th.text for th in table.select("tr th")]

    headers[0] = "card_id"
    headers[1] = "team"
    headers = [header.lower().replace("-", "_") for header in headers]

    bases = {"1b": "s", "2b": "d", "3b": "t"}
    now = datetime.now()
    for header in headers:
        if header in bases.keys():
            headers[headers.index(header)] = bases[header]
        if header.lower() == "pi/pa":
            headers[headers.index(header)] = "pi_pa"

    ts = "added_ts"
    th = "tournament_id"

    batting_headers = headers[0:26]
    batting_headers.extend([th, ts])

    pitching_headers = headers[0:2]
    pitching_headers.extend(headers[26:72])
    pitching_headers.extend([th, ts])

    fielding_headers = headers[0:2]
    fielding_headers.extend(headers[72:])
    fielding_headers.extend([th, ts])

    batting, pitching, fielding = [], [], []

    for row in table.select("tr + tr"):
        cols = [td.text.strip() for td in row.find_all("td")]
        bat = cols[0:26]
        bat.extend([tournament_id, now])

        pitch = cols[0:2]
        pitch.extend(cols[26:72])
        pitch.extend([tournament_id, now])

        field = cols[0:2]
        field.extend(cols[72:])
        field.extend([tournament_id, now])

        if int(bat[4]) != 0:
            for col in bat:
                if col == "":
                    bat[bat.index(col)] = 0
            batting.append(dict(zip(batting_headers, bat)))
        if int(pitch[2]) != 0:
            pitching.append(dict(zip(pitching_headers, pitch)))
        if int(field[2]) != 0:
            fielding.append(dict(zip(fielding_headers, field)))

    stats = [batting, pitching, fielding]

    return stats


def insert_records(con, metadata, engine, stats, abbr):

    tables = [
        "{}_b07_batting_da".format(abbr),
        "{}_b07_pitching_da".format(abbr),
        "{}_b07_fielding_da".format(abbr),
    ]

    for i in range(3):
        db_table = Table(tables[i], metadata, autoload=True, autoload_with=engine)

        con.execute(db_table.insert(), stats[i])

    print("Inserting completed")


if __name__ == "__main__":
    main(sys.argv[1:])
