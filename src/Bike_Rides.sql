-----------------------------------------------------------BIKE TRIP DATA--------------------------------------------------------------------------





----------------------------------------------------CLEANING AND TRANSFROMING DATA--------------------------------------------------


-- Merging each month table into one single temporary table using UNION ALL

SELECT *
	INTO TEMP_UNION
FROM (

	SELECT *
	  FROM [Bike_Sales].[dbo].[202306-divvy-tripdata]

	UNION ALL

	SELECT *
	  FROM [Bike_Sales].[dbo].[202307-divvy-tripdata]

	UNION ALL

	SELECT *
	  FROM [Bike_Sales].[dbo].[202308-divvy-tripdata]

	UNION ALL

	SELECT *
	  FROM [Bike_Sales].[dbo].[202309-divvy-tripdata]

	UNION ALL

	SELECT *
	  FROM [Bike_Sales].[dbo].[202310-divvy-tripdata]

	UNION ALL

	SELECT *
	  FROM [Bike_Sales].[dbo].[202311-divvy-tripdata]

	UNION ALL

	SELECT *
	  FROM [Bike_Sales].[dbo].[202312-divvy-tripdata]

	UNION ALL

	SELECT *
	  FROM [Bike_Sales].[dbo].[202401-divvy-tripdata]

	UNION ALL

	SELECT *
	  FROM [Bike_Sales].[dbo].[202402-divvy-tripdata]

	UNION ALL

	SELECT *
	  FROM [Bike_Sales].[dbo].[202403-divvy-tripdata]

	UNION ALL

	SELECT *
	  FROM [Bike_Sales].[dbo].[202404-divvy-tripdata]

	UNION ALL

	SELECT *
	  FROM [Bike_Sales].[dbo].[202405-divvy-tripdata]
) combined





--Checking all the null values in 'start_station_name' and 'end_station_name' column, 
--which turned out to be 905237 and 956579, respectively.

SELECT COUNT(*)
	FROM TEMP_UNION
WHERE start_station_name IS NULL

SELECT COUNT(*)
	FROM TEMP_UNION
WHERE end_station_name IS NULL




--Backing up all the data before modifying the original values in table TEMP_UNION.

SELECT * INTO backup_table
FROM TEMP_UNION;




--Updating all the null values in 'start_station_name' and 'end_station_name' to dummy names, 
--since 956579 and 905237 are huge numbers and deleting such amount of rows could violate 
--data integrity and introduce data biases.

UPDATE TEMP_UNION
SET start_station_name = 'dummy_start_station'
WHERE start_station_name IS NULL;

UPDATE TEMP_UNION
SET end_station_name = 'dummy_end_station'
WHERE end_station_name IS NULL;





-- Adding four new columns, 'start_date', 'end_date', 'start_time' and 'end_time' by splitting the existing 'started_at'and
-- 'ended_at' columns for better readability and further operations.

ALTER TABLE TEMP_UNION
ADD start_date date;

ALTER TABLE TEMP_UNION
ADD start_time time;

ALTER TABLE TEMP_UNION
ADD end_date date;

ALTER TABLE TEMP_UNION
ADD end_time time;


UPDATE TEMP_UNION
SET start_date = CONVERT(DATE, CAST(started_at AS date), 112);

UPDATE TEMP_UNION
SET start_time = CAST(started_at AS time);

UPDATE TEMP_UNION
SET end_date = CONVERT(DATE, CAST(ended_at AS date), 112);

UPDATE TEMP_UNION
SET end_time = CAST(ended_at AS time);





--Since most of the rides end on the same day, therefore, this assumption can be used to fill out missing 
--values in 'start_date' column

UPDATE TEMP_UNION
SET start_date = end_date
WHERE start_date IS NULL;





--Calculating the average time taken by bike rides by subtracting end_time from start time and taking their mean
--which turns out to be 9 minutes.

SELECT AVG(DATEDIFF(MINUTE, start_time , end_time))
FROM TEMP_UNION




--This information can be used to populate the 'start_time' column by subtracting
--the average time of 9 minutes from the end_time column.

UPDATE TEMP_UNION
SET start_time = CAST(DATEADD(minute, -9, end_time) AS TIME)
WHERE start_time IS NULL





--'start_date' column can be used to derive a new column 'day_of_week'
--which leads to better analysis and achievable insights.

ALTER TABLE TEMP_UNION
ADD day_of_week varchar(20);

UPDATE TEMP_UNION
SET day_of_week = DATENAME(DW, end_date);













----------------------------------------------------ANALYZING DATA------------------------------------------------------------------
                                                     


--Analyzing the most popular days of the week for rides among both groups. 
--This insight can be used to create special weekend offers or weekday promotions.
--Annual members commute bike ride mostly in middle of the week (Wednesday and Thursday),
--while casual riders mostly prefer weekends (Saturday and Sunday).

SELECT 
	member_casual,
	day_of_week, 
	ride_count
FROM (
	SELECT 
        member_casual,
        day_of_week,
        COUNT(*) AS ride_count,
        RANK() OVER (PARTITION BY member_casual ORDER BY COUNT(*) DESC) AS rank
    FROM 
        TEMP_UNION
    GROUP BY
        member_casual,
        day_of_week
) AS RankedWeeks
WHERE
	rank <= 3
ORDER BY 
	member_casual,
	rank;




--Calculating the average bike ride duration by different category of users
--Annual members on an average take bike ride for 8 minutes, and casual riders
--take bike ride on an avrage of 10 minutes.

SELECT 
	member_casual, 
	AVG(DATEDIFF(MINUTE, start_time , end_time))
FROM 
	TEMP_UNION
GROUP BY 
	member_casual




--Determining the preference for rideable bike types among casual riders and premium members.
--This gives the perception that casual riders prefer electric bikes the most but annual members
--don't have such preferences. They nearly equally prefer classic and electric bikes, and don't
--even consider docked bikes.

SELECT 
    member_casual,
    rideable_type,
    COUNT(*) AS ride_count
FROM 
    TEMP_UNION
GROUP BY 
    member_casual, 
    rideable_type
ORDER BY 
    member_casual, 
    ride_count DESC;




--Identifying the peak hours when casual riders and premium members are most active. 
--This can help in planning targeted marketing campaigns during those hours.
--One distinguishing factor is that annual members mostly prefer 8:00 am for bike 
--rides, while casual riders prefer 2:00 pm for bike rides.

SELECT 
    member_casual,
    start_hour,
    ride_count
FROM (
    SELECT 
        member_casual,
        DATEPART(HOUR, start_time) AS start_hour,
        COUNT(*) AS ride_count,
        RANK() OVER (PARTITION BY member_casual ORDER BY COUNT(*) DESC) AS rank
    FROM 
        TEMP_UNION
    GROUP BY
        member_casual,
        DATEPART(HOUR, start_time)
) AS RankedHours
WHERE 
    rank <= 5
ORDER BY 
    member_casual,
    rank;




--Determining the most popular start and end stations for both casual riders and annual members. 
--This information can be useful for station placement, bike availability, and targeted promotions 
--at high-traffic locations.

WITH RankedRides AS (
	SELECT
		member_casual,
		start_station_name,
		COUNT(*) AS ride_count,
		RANK() OVER (PARTITION BY member_casual ORDER BY COUNT(*) DESC) AS rank
	FROM
		TEMP_UNION
	WHERE
		start_station_name <> 'dummy_start_station'
	GROUP BY
		member_casual,
		start_station_name
)
SELECT
	member_casual,
	start_station_name,
	ride_count
FROM
	RankedRides
WHERE
	rank <= 5
ORDER BY
	member_casual,
	ride_count DESC




-- Comparing the average number of rides taken by casual riders versus premium members.
-- Understanding the ride frequency can help design loyalty programs and incentives for
-- more frequent use.
-- Members are high in terms of ride counts, as compared to casuals.

SELECT
	member_casual,
	COUNT(*)/COUNT(DISTINCT member_casual) AS ride_count
FROM	
	TEMP_UNION
GROUP BY
	member_casual
ORDER BY
	ride_count DESC





SELECT 
	*
INTO
	Combined_Data
FROM 
	TEMP_UNION
