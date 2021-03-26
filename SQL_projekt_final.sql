CREATE TABLE t_Hanka_Voznicova_projekt_SQL_final AS (
WITH zaklad AS
(SELECT
	date,
	country,
	confirmed,
	deaths,
	recovered,
	CASE WHEN
		WEEKDAY(`date`) in (0,1,2,3,4) THEN 1
		ELSE 0 END as flag_weekday,
	CASE 
		WHEN date BETWEEN '2019-12-21' and '2020-03-20' THEN 3
		WHEN date BETWEEN '2020-03-21' and '2020-06-20' THEN 0
		WHEN date BETWEEN '2020-06-21' and '2020-09-20' THEN 1
		WHEN date BETWEEN '2020-09-21' and '2020-12-20' THEN 2
		WHEN date BETWEEN '2020-12-21' and '2021-03-20' THEN 3
		WHEN date BETWEEN '2021-03-21' and '2021-06-20' THEN 0
		ELSE ' ' END as flag_seasons
FROM covid19_basic_differences
GROUP BY country, date),

testovani AS
(SELECT  
	CAST(date AS date) AS date,
	country,
	tests_performed 
FROM Hanka_covid19_tests
),

country_tab AS 
(SELECT 
	country,
	population,
	ROUND(population_density,0) AS pop_density,
	median_age_2018
FROM Hanka_countries),

religion AS 
(SELECT 
	r.country, 
	r.religion, 
    round( r.population / rsum.total_population * 100, 2 ) as religion_share
FROM Hanka_religions r 
JOIN (
        SELECT r.country , r.year,  sum(r.population) as total_population
        FROM Hanka_religions r 
        WHERE r.year = 2020 and r.country != 'All Countries'
        GROUP BY r.country
    ) rsum
    ON r.country = rsum.country
    AND r.year = rsum.year
    AND r.population > 0),

  hdp AS 
    ( SELECT 
   	country,
   	ROUND(GDP,0) AS HDP,
   	ROUND(mortaliy_under5,2) AS mortaliy_under5
 FROM Hanka_economies
 WHERE `year` = '2019'),
 
 gini AS 
 (SELECT 
	country,
	gini AS gini_2017
FROM Hanka_economies
WHERE `year` = '2017'),

life AS 
(SELECT a.country,
    round( b.life_exp_2015 - a.life_exp_1965,1) as life_exp_dif_1965to2015
FROM (
    SELECT country , life_expectancy as life_exp_1965
    FROM Hanka_life_expectancy
    WHERE year = '1965'
    ) a JOIN (
    SELECT country , life_expectancy as life_exp_2015
    FROM Hanka_life_expectancy 
    WHERE year = '2015'
    ) b
    ON a.country = b.country),
    
 vliv_pocasi AS 
 (WITH pocasi AS (SELECT 
	r.date,
	r.city,
	r.notnull_rain,
	t.avg_temp,
	wi.max_wind
FROM weather w
RIGHT JOIN (SELECT 
	date,
	city,
	24-COUNT(rain)*3 as notnull_rain
	FROM weather w
	WHERE rain = '0'
	GROUP BY date, city)
as r ON w.date=r.date AND w.city=r.city
RIGHT JOIN (SELECT 
	date,
	city,
	ROUND(AVG(temp), 2) AS avg_temp
	FROM weather w
	WHERE hour IN (6, 9, 12, 15, 18, 21)
	GROUP BY date,city)
as t ON r.date=t.date AND r.city=t.city
RIGHT JOIN (SELECT 
	date,
	city,
	MAX(wind) AS max_wind
	FROM weather w
	GROUP BY date, city) as wi
ON t.date=wi.date and t.city=wi.city
WHERE r.date IS NOT NULL 
GROUP BY date, city)

SELECT 
	pocasi.date,
	hc.country,
	pocasi.notnull_rain,
	pocasi.avg_temp,
	pocasi.max_wind
FROM Hanka_countries hc 
LEFT JOIN pocasi  
on pocasi.city=hc.capital_city 
WHERE date IS NOT NULL 
GROUP BY country, date)

SELECT 
	zaklad.date,
	zaklad.country,
	zaklad.confirmed,
	zaklad.deaths,
	zaklad.recovered,
	testovani.tests_performed,
	ROUND(zaklad.confirmed/testovani.tests_performed*100, 2) AS pos_tests_ratio_perc,
	country_tab.population,
	hdp.HDP,
	country_tab.pop_density,
	country_tab.median_age_2018,
	hdp.mortaliy_under5,
	life.life_exp_dif_1965to2015,
	gini.gini_2017,
	religion.religion,
	religion.religion_share,
	zaklad.flag_weekday,
	zaklad.flag_seasons,
	vliv_pocasi.notnull_rain,
	vliv_pocasi.avg_temp,
	vliv_pocasi.max_wind
FROM zaklad
LEFT JOIN testovani
ON zaklad.date=testovani.date
AND zaklad.country=testovani.country
LEFT JOIN country_tab
ON zaklad.country=country_tab.country
LEFT JOIN religion
ON zaklad.country=religion.country
LEFT JOIN hdp 
ON zaklad.country=hdp.country
LEFT JOIN gini 
ON zaklad.country=gini.country
LEFT JOIN life 
ON zaklad.country=life.country
LEFT JOIN vliv_pocasi
ON zaklad.country=vliv_pocasi.country
AND zaklad.date=vliv_pocasi.date
);