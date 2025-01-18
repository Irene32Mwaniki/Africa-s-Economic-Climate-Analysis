-- Step 1: I create a new database for African_data -- 
DROP DATABASE IF EXISTS African_data; 
CREATE DATABASE African_data; 

-- Step 2: Import Excel data into the database 
	
-- Step 3: Use the created database African_data and create table, columns and rows, datatpes-- 
USE African_data; 
DROP SCHEMA IF EXISTS Data_Analysis; 
CREATE SCHEMA Data_Analysis;
USE Data_Analysis; 
-- Define the constraints and data types-- 
DROP TABLE IF EXISTS Africa_Corruption;

CREATE TABLE Africa_Corruption (
	Country CHAR (25) NOT NULL,
    CurrentValue INT NOT NULL, 
    PreviousValue INT NOT NULL,
    PRIMARY KEY (Country)
); 
INSERT INTO Africa_Corruption (Country, CurrentValue, PreviousValue)
SELECT country, current_value, previous_value FROM african_data.corruption_index;

SELECT *
FROM africa_Corruption;


DROP TABLE IF EXISTS African_debt;
CREATE TABLE African_debt (
	CountryName CHAR (30) references Africa_Corruption(Country),
    CurrentDebt DOUBLE NOT NULL,
    PreviousDebt DOUBLE NOT NULL
); 
   
INSERT INTO African_debt (CountryName, CurrentDebt, PreviousDebt)
SELECT CountryName, CurrentDebt, PreviousDebt FROM african_data.external_debt; 

SELECT *
FROM African_debt; 


CREATE TABLE African_GDP (
	CountryName CHAR (25) references African_corruption(country),
    CurrentGDP Double NOT NULL,
    PreviousGDP Double NOT NULL
); 
    
INSERT INTO African_GDP (CountryName, CurrentGDP, PreviousGDP)
SELECT Country, CurrentGDP, PreviousGDP FROM african_data.gdp; 

SELECT *
FROM African_GDP;

DROP TABLE IF EXISTS DEBT_to_GDP; 

CREATE TABLE  DEBT_to_GDP (
	Country CHAR(30) references African_corruption(country),
    CurrentValue INT NOT NULL,
    PreviousValue INT NOT NULL
);

INSERT INTO DEBT_to_GDP (Country, CurrentValue, PreviousValue)
SELECT Country, CurrentValue, PreviousValue FROM african_data.governmentdebt_to_gdp_africa; 

SELECT *
FROM DEBT_to_GDP; 
	
DROP TABLE IF EXISTS Personal_Income_Tax; 

CREATE TABLE Personal_Income_Tax (
	Country CHAR(30) references African_corruption(country),
    CurrentTax INT NOT NULL,
    PreviousTax INT NOT NULL
); 

INSERT INTO Personal_Income_Tax (Country, CurrentTax, PreviousTax)
SELECT Country, Last, Previous FROM african_data.personalincome_tax_rate_africa; 


SELECT *
FROM Personal_Income_Tax; 


-- Objective 1: To analyze the relationship between corruption and GDP 
/* to calculate the trends between corruption index scores and GDP to determine how corruption levels impact economic performance*/

SELECT 
	country, 
    ag.currentgdp,
    ac.currentvalue, 
    ag.previousgdp,
    ac.previousvalue    
FROM africa_corruption as ac
LEFT JOIN african_gdp as ag 
ON ac.country = ag.countryname; 

-- Objective 2: Evalaute the effect of personal income tax on GDP Growth --
-- 1. Calculate GDP Growth and Tax Rate Change --
 
WITH GDPGrowthTaxChange AS (
	SELECT 
		g.CountryName, 
        (g.CurrentGDP - g.PreviousGDP) / g.PreviousGDP * 100 AS GDPGrowth, 
        (t.CurrentTax - t.PreviousTax) AS TaxRateChange 
	FROM african_gdp g 
    JOIN 
		personal_income_tax t 
	ON 
		g.CountryName = t.Country 
	WHERE 
		g.PreviousGDP IS NOT NULL AND t.PreviousTax IS NOT NULL
)
SELECT 
	CountryName,
    GDPGrowth, 
    TaxRateChange
FROM 
	GDPGrowthTaxChange
ORDER BY 
	GDPGrowth DESC; 
 
-- 2. Group countries GDP Growth by Tax Rate Ranges -- 
WITH GDPGrowthTaxChange AS (
	SELECT 
		g.CountryName,
        (g.CurrentGDP - g.PreviousGDP) / g.PreviousGDP * 100 AS GDPGrowth, 
        t.CurrentTax
	FROM 
		African_GDP g
	JOIN 
		Personal_income_tax t 
	ON 
		g.CountryName = t.Country
	WHERE 
		g.PreviousGDP IS NOT NULL 
),
AggregateResults AS (
	SELECT 
		CASE 
			WHEN CurrentTax < 10 THEN '0-10%'
			WHEN CurrentTax BETWEEN 10 AND 20 THEN '10-20%'
			WHEN CurrentTax BETWEEN 20 AND 30 THEN '20-30%'
			ELSE '30%+'
		END AS TaxRateRange,
        AVG(GDPGrowth) AS AvgGDPGrowth
	FROM 
		GDPGrowthTaxChange
	GROUP BY 
	TaxRateRange
)
SELECT 
	 g.CountryName,
     a.TaxRateRange,
     a.AvgGDPGrowth
FROM 
	AggregateResults a
JOIN 
	GDPGrowthTaxChange g
ON 
	CASE 
		WHEN g.CurrentTax < 10 THEN '0-10%'
        WHEN g.CurrentTax BETWEEN 10 AND 20 THEN '10-20%'
        WHEN g.CurrentTax BETWEEN 20 AND 30 THEN '20-30%'
        ELSE '30%+'
    END = a.TaxRateRange
ORDER BY 
    a.TaxRateRange, a.AvgGDPGrowth DESC;


-- 3. Identify Countries with the highest GDP Growth -- 
WITH GDPGrowthTaxChange AS (
	SELECT 
		g.CountryName, 
        (g.CurrentGDP - g.PreviousGDP) / g.PreviousGDP * 100 AS GDPGrowth, 
        t.CurrentTax
	FROM 
		African_gdp g 
	JOIN 
		Personal_Income_tax t
	ON 
		g.CountryName = t.Country
	WHERE 
		g.PreviousGDP IS NOT NULL 
) 
SELECT 
	CountryName,
    GDPGrowth, 
    CurrentTax
FROM 
	GDPGrowthTaxChange
ORDER BY 
	GDPGrowth DESC
LIMIT 10; 

-- Objective 3: Assess the impact of External debt on economic stability -- 
/*Examine the relationship between external debt and GDP, identifying patterns or thresholds where debt negatively impacts economic growth*/

-- 1. Calculate Debt Change (to devide countries into quartiles based on thier debt change and analyze how GDP growth varies across these groups -- 
WITH DebtGDPChange AS (
	SELECT 
		d.Country, 
        (d.CurrentValue - d.PreviousValue) / d.PreviousValue * 100 AS DebtChange,
        (g.CurrentGDP - g.PreviousGDP) / g.PreviousGDP * 100 AS GDPGrowth
	FROM 
		debt_to_gdp d
	JOIN 
		african_gdp g
	ON 
		d.Country = g.CountryName 
	WHERE 
		d.PreviousValue IS NOT NULL AND g.PreviousGDP IS NOT NULL 
)
SELECT 
	Country, 
    DebtChange,
    GDPGrowth,
    NTILE(4) OVER (ORDER BY DebtChange DESC) AS DebtQuartile
FROM 
	DebtGDPChange 
ORDER BY 
	DebtQuartile, GDPGrowth DESC; 
    
-- 2. Using RANK to identify African countries with extreme debt status --
WITH DebtGDPChange AS (
	SELECT 
		d.CountryName, 
        (d.CurrentDebt- d.PreviousDebt) / d.PreviousDebt* 100 AS DebtChange, 
        (g.CurrentGDP - g.PreviousGDP) / g.PreviousGDP * 100 AS GDPGrowth
	FROM 
		african_debt d
	JOIN 
		african_gdp g
	ON 
		d.CountryName = g.CountryName
	WHERE 
		d.PreviousDebt IS NOT NULL AND g.PreviousGDP IS NOT NULL
)
SELECT 
	CountryName, 
    DebtChange,
    GDPGrowth,
    RANK() OVER (ORDER BY DebtChange DESC) AS DebtRank
FROM 
	DebtGDPChange
ORDER BY 
	DebtRank; 
		
 -- 3. Determine top Countries using RANK to determine highest debt increased against their GDP growth --
 WITH DebtGDPChange AS (
	SELECT 
		d.CountryName,
        (d.CurrentDebt - d.PreviousDebt) / d.PreviousDebt * 100 AS DebtChange,
        (g.CurrentGDP - g.PreviousGDP) / g.PreviousGDP * 100 AS GDPGrowth
	FROM 
		african_debt d
	JOIN 
		african_gdp g
	ON 
		d.CountryName = g.CountryName 
	WHERE 
		d.PreviousDebt IS NOT NULL AND g.PreviousGDP IS NOT NULL 
),
RankedCountries AS (
	SELECT 
		CountryName, 
        DebtChange,
        GDPGrowth,
        RANK() OVER (ORDER BY DebtChange DESC) AS DebtRank
	FROM 
		DebtGDPChange
) 
SELECT 
	CountryName,
    DebtChange,
    GDPGrowth
FROM 
	RankedCountries 
WHERE 
	DebtRank <= 5 
ORDER BY 
	DebtRank; 
    
-- 4. Review the average debt change against average gdp growth change in the continent (Increase, stable or decreased) -- 
WITH DebtGDPChange AS (
	SELECT 
		d.CountryName,
        (d.CurrentDebt - d.PreviousDebt) / d.PreviousDebt * 100 AS DebtChange, 
        (g.CurrentGDP - g.PreviousGDP) / g.PreviousGDP * 100 AS GDPGrowth
	FROM 
		african_debt d
	JOIN 
		african_gdp g
	ON 
		d.CountryName = g.CountryName 
	WHERE 
		d.PreviousDebt IS NOT NULL AND g.PreviousGDP IS NOT NULL 
)
SELECT 
	CASE 
		WHEN DebtChange < - 10 THEN 'Decrease > 10%'
        WHEN DebtChange BETWEEN - 10 AND 10 THEN 'Stable (-10% to + 10%)' 
        ELSE 'Increase > 10%'
	END AS DebtChangeRange,
    AVG(GDPGrowth) AS AvgGDPGrowth
FROM 
	DebtGDPChange
GROUP BY 
	DebtChangeRange 
ORDER BY 
	DebtChangeRange; 

-- Determine countries with lowest debt and highest GPD Growth -- 
WITH GDPGrowth AS (
    SELECT 
        g.CountryName,
        ((g.CurrentGDP - g.PreviousGDP) / g.PreviousGDP) * 100 AS GDPGrowthRate
    FROM 
        african_gdp g
    WHERE 
        g.PreviousGDP > 0
),
DebtChange AS (
    SELECT 
        d.CountryName,
        ((d.CurrentDebt - d.PreviousDebt) / d.PreviousDebt) * 100 AS DebtChangeRate
    FROM 
        african_debt d
    WHERE 
        d.PreviousDebt > 0
),
DebtToGDP AS (
    SELECT 
        t.Country,
        t.CurrentValue AS DebtToGDPCurrent,
        t.PreviousValue AS DebtToGDPPrevious,
        ((t.CurrentValue - t.PreviousValue) / t.PreviousValue) * 100 AS DebtToGDPChange
    FROM 
        debt_to_gdp t
    WHERE 
        t.PreviousValue > 0
)
SELECT 
    g.CountryName AS Country,
    g.GDPGrowthRate,
    d.DebtChangeRate,
    t.DebtToGDPChange
FROM 
    GDPGrowth g
JOIN 
    DebtChange d ON g.CountryName = d.CountryName
JOIN 
    DebtToGDP t ON g.CountryName = t.Country
WHERE 
    d.DebtChangeRate < 5 -- Low debt increase or decrease (adjust threshold as needed)
    AND g.GDPGrowthRate > 5 -- High GDP growth (adjust threshold as needed)
ORDER BY 
    g.GDPGrowthRate DESC, d.DebtChangeRate ASC;

