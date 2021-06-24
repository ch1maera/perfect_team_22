BEGIN

DROP TABLE IF EXISTS bz_b07_guts;
SET @ts = (SELECT CURRENT_DATE - INTERVAL 7 DAY);

CREATE TABLE bz_b07_guts
AS 
	SELECT		 
		 SUM(ROUND(ip / 1)) * 3 + SUM(CAST(ROUND(ip % 1 * 10, 1) AS SIGNED)) AS 'total_outs'
		,(SUM(ROUND(ip / 1)) + SUM(CAST(ROUND(ip % 1 * 10, 1) AS SIGNED)/ 3)) AS 'lg_ip'
		,SUM(bf) as 'lg_pa'
		,SUM(r) as 'lg_runs'
		,SUM(r) / (SUM(ROUND(ip / 1)) * 3 + SUM(CAST(ROUND(ip % 1 * 10, 1) AS SIGNED))) AS 'runs_per_out'
		,9 * (SUM(r) / ((SUM(ROUND(ip / 1)) + SUM(CAST(ROUND(ip % 1 * 10, 1) AS SIGNED)/ 3)))) * 1.5 + 3 AS 'runs_per_win'
		,SUM(er) / ((SUM(ROUND(ip / 1)) + SUM(CAST(ROUND(ip % 1 * 10, 1) AS SIGNED)/ 3))) * 9 AS 'lg_era'
		,SUM(r) / ((SUM(ROUND(ip / 1)) + SUM(CAST(ROUND(ip % 1 * 10, 1) AS SIGNED)/ 3))) * 9 AS 'lg_r9'
		,(SUM(hr) * 13 + SUM(bb + hp) * 3 - SUM(k) * 2) / (SUM(ROUND(ip / 1)) + SUM(CAST(ROUND(ip % 1 * 10, 1) AS SIGNED)/ 3)) AS 'fip'
		,(SUM(er) / (SUM(ROUND(ip / 1)) + SUM(CAST(ROUND(ip % 1 * 10, 1) AS SIGNED)/ 3)) * 9) - ((SUM(hr) * 13 + SUM(bb + hp) * 3 - SUM(k) * 2) / (SUM(ROUND(ip / 1)) + SUM(CAST(ROUND(ip % 1 * 10, 1) AS SIGNED)/ 3))) AS 'fip_constant'
		,(SUM(r) / (SUM(ROUND(ip / 1)) + SUM(CAST(ROUND(ip % 1 * 10, 1) AS SIGNED)/ 3)) * 9) - (SUM(er) / (SUM(ROUND(ip / 1)) + SUM(CAST(ROUND(ip % 1 * 10, 1) AS SIGNED)/ 3)) * 9) AS 'lg_fipr9_adj'
		,(SUM(ha - hr) / sum(ab - k - hr + sf)) AS 'babip'	
	FROM bz_b07_pitching
	WHERE added_ts >= @ts ;

DROP TABLE IF EXISTS bz_b07_run_values;
CREATE TABLE bz_b07_run_values
AS 
	SELECT
		 btg.runs_per_out
		,btg.runs_per_out + 0.14 AS 'runBB'
		,btg.runs_per_out + 0.14  + 0.025 AS 'runHB'
		,btg.runs_per_out + 0.14 + 0.155 AS 'run1B'
		,btg.runs_per_out + 0.14 + 0.155 + 0.3 AS 'run2B'
		,btg.runs_per_out + 0.14 + 0.155 + 0.3 + 0.27 AS 'run3B'
		,1.4 AS 'runHR'
		,0.2 AS 'runSB'
		,2 * btg.runs_per_out + 0.075 AS 'runCS'
	FROM bz_b07_guts btg;


DROP TABLE IF EXISTS bz_b07_woba_coefs;
CREATE TABLE bz_b07_woba_coefs 
AS
	SELECT
		 1 AS 'row_id' 
		,a.*
		,1 / (runPlus + runMinus) AS 'wobaScale'
		,(a.runbb + runMinus) * (1 / (runPlus + runMinus)) AS 'wobaBB'
		,(a.runhb + runMinus) * (1 / (runPlus + runMinus)) AS 'wobaHB'
		,(a.run1B + runMinus) * (1 / (runPlus + runMinus)) AS 'woba1B'
		,(a.run2B + runMinus) * (1 / (runPlus + runMinus)) AS 'woba2B'
		,(a.run3B + runMinus) * (1 / (runPlus + runMinus)) AS 'woba3B'
		,(a.runHR + runMinus) * (1 / (runPlus + runMinus)) AS 'wobaHR'
		,a.runSB  * (1 / (runPlus + runMinus)) AS 'wobaSB'
		,a.runCS * (1 / (runPlus + runMinus)) AS 'wobaCS'
	FROM (
		SELECT 
			 btrv.*
			,(btrv.runBB * (SELECT SUM(bb - ibb) FROM bz_b07_batting WHERE added_ts >= @ts) +
			 btrv.runHB * (SELECT SUM(hp) FROM bz_b07_batting WHERE added_ts >= @ts) + 
			 btrv.run1B * (SELECT SUM(s) FROM bz_b07_batting WHERE added_ts >= @ts) +
			 btrv.run2B * (SELECT SUM(d) FROM bz_b07_batting WHERE added_ts >= @ts) +
			 btrv.run3B * (SELECT SUM(t) FROM bz_b07_batting WHERE added_ts >= @ts) +
			 btrv.runHR * (SELECT SUM(hr) FROM bz_b07_batting WHERE added_ts >= @ts) +
			 btrv.runSB * (SELECT SUM(sb) FROM bz_b07_batting WHERE added_ts >= @ts) -
			 btrv.runCS * (SELECT SUM(cs) FROM bz_b07_batting WHERE added_ts >= @ts)) /
			 (SELECT SUM(ab - h + sf) FROM bz_b07_batting WHERE added_ts >= @ts) AS 'runMinus'
			,(btrv.runBB * (SELECT SUM(bb - ibb) FROM bz_b07_batting WHERE added_ts >= @ts) +
			 btrv.runHB * (SELECT SUM(hp) FROM bz_b07_batting WHERE added_ts >= @ts) + 
			 btrv.run1B * (SELECT SUM(s) FROM bz_b07_batting WHERE added_ts >= @ts) +
			 btrv.run2B * (SELECT SUM(d) FROM bz_b07_batting WHERE added_ts >= @ts) +
			 btrv.run3B * (SELECT SUM(t) FROM bz_b07_batting WHERE added_ts >= @ts) +
			 btrv.runHR * (SELECT SUM(hr) FROM bz_b07_batting WHERE added_ts >= @ts) +
			 btrv.runSB * (SELECT SUM(sb) FROM bz_b07_batting WHERE added_ts >= @ts) -
			 btrv.runCS * (SELECT SUM(cs) FROM bz_b07_batting WHERE added_ts >= @ts)) /
			 (SELECT SUM(bb - ibb + hp + h) FROM bz_b07_batting WHERE added_ts >= @ts) AS 'runPlus'
			,(SELECT SUM(h + bb - ibb + hp) / SUM(ab + bb - ibb + hp + sf) FROM bz_b07_batting WHERE added_ts >= @ts) AS 'woba'
		FROM bz_b07_run_values btrv
		) a;

-- The only reason to add this is to work with the woba coefs table 
-- in SQL Alchemy which requires each table to have a primary key.
ALTER TABLE `bz_b07_woba_coefs`
	CHANGE COLUMN `row_id` `row_id` INT(10) NOT NULL AUTO_INCREMENT FIRST,
	ADD PRIMARY KEY (`row_id`);

END