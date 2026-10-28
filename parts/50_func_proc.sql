/*
** Author: Ethan Oxley, Daniel Warren
** Group: E & D Group
** Course: IFT 530: Advanced Database Management Systems
** SQL Server Version: Microsoft SQL Server 2025 (Developer Edition)
** OS: macOS 26.6.2 (SQL Server running in Microsoft's official Linux
**     container under Docker)
** Date: 10/27/2026
** Assignment: Final Project
*/

/* ======================================================================
   SECTION 5: A USER DEFINED FUNCTION AND A STORED PROCEDURE

   Both are created here, before the views, because section 6's
   suspicious transaction view calls the function. Section 2 drops them
   both; each is also dropped immediately before it is created, so this
   section can be re-run on its own.
   ====================================================================== */

/* ----------------------------------------------------------------------
   fnGeoDistanceKm - great-circle distance between two places, in km.

   This is the haversine formula. It exists because "the payment came
   from a different country" is a weak signal on its own - plenty of
   people travel - while "the payment came from 11,000 km away, forty
   minutes after they were last seen" is not something a traveller can
   do. Section 6 divides this by the elapsed time to get an implied
   speed, and that is what separates a holiday from a stolen card.

   Scalar, not table-valued, because it answers with one number and is
   called once per row of a view.
   ---------------------------------------------------------------------- */
DROP FUNCTION IF EXISTS dbo.fnGeoDistanceKm;
GO

CREATE FUNCTION dbo.fnGeoDistanceKm
(
    @GeoID1 INT,
    @GeoID2 INT
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @lat1 FLOAT, @lon1 FLOAT,
            @lat2 FLOAT, @lon2 FLOAT;

    SELECT @lat1 = Latitude, @lon1 = Longitude
      FROM dbo.DimGeography
     WHERE GeoID = @GeoID1;

    SELECT @lat2 = Latitude, @lon2 = Longitude
      FROM dbo.DimGeography
     WHERE GeoID = @GeoID2;

    /* Either side unknown means no answer, not a distance of zero.
       A NULL LastSeenGeoID is a user who has never played. */
    IF @lat1 IS NULL OR @lat2 IS NULL
        RETURN NULL;

    DECLARE @R    FLOAT = 6371.0;          -- mean earth radius, km
    DECLARE @dLat FLOAT = RADIANS(@lat2 - @lat1);
    DECLARE @dLon FLOAT = RADIANS(@lon2 - @lon1);

    DECLARE @a FLOAT =
        SIN(@dLat / 2) * SIN(@dLat / 2) +
        COS(RADIANS(@lat1)) * COS(RADIANS(@lat2)) *
        SIN(@dLon / 2) * SIN(@dLon / 2);

    RETURN CAST(@R * 2 * ATN2(SQRT(@a), SQRT(1 - @a)) AS DECIMAL(10,2));
END;
GO

/* ----------------------------------------------------------------------
   spMonthlyActiveUsers - monthly actives, new vs returning, and the
   revenue that went with them.

   @Year is required. @Month defaults to NULL, which reports every month
   of that year rather than forcing a caller who wants the whole year to
   run it twelve times.

   Both parameters are validated and raise a numbered error rather than
   returning an empty set, because an empty result and a bad argument
   look identical to whoever called it.
   ---------------------------------------------------------------------- */
DROP PROCEDURE IF EXISTS dbo.spMonthlyActiveUsers;
GO

CREATE PROCEDURE dbo.spMonthlyActiveUsers
    @Year  INT,
    @Month INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Year IS NULL OR @Year < 2020 OR @Year > 2100
        THROW 50001, 'Year must be between 2020 and 2100.', 1;

    IF @Month IS NOT NULL AND (@Month < 1 OR @Month > 12)
        THROW 50002, 'Month must be between 1 and 12.', 1;

    /* This procedure prints "Null value is eliminated by an aggregate"
       when it runs. That is expected and is not a fault. The new and
       returning counts below are COUNT(DISTINCT CASE WHEN ... END),
       where the CASE returns NULL for every row outside the group
       being counted, and COUNT skipping those NULLs is exactly the
       mechanism that makes a conditional distinct count work. */
    ;WITH Activity AS (
        SELECT  YEAR(e.EventTS)  AS ActivityYear,
                MONTH(e.EventTS) AS ActivityMonth,
                e.UserID,
                u.SignupDate
          FROM  dbo.FactUserEvent AS e
          JOIN  dbo.DimUser       AS u ON u.UserID = e.UserID
         WHERE  YEAR(e.EventTS) = @Year
           AND  (@Month IS NULL OR MONTH(e.EventTS) = @Month)
    ),
    Revenue AS (
        SELECT  YEAR(f.PaymentTS)  AS ActivityYear,
                MONTH(f.PaymentTS) AS ActivityMonth,
                SUM(CASE WHEN f.PaymentType = 'Refund'
                         THEN -f.AmountUSD ELSE f.AmountUSD END) AS Net
          FROM  dbo.FactPayment AS f
         WHERE  YEAR(f.PaymentTS) = @Year
           AND  (@Month IS NULL OR MONTH(f.PaymentTS) = @Month)
         GROUP BY YEAR(f.PaymentTS), MONTH(f.PaymentTS)
    )
    SELECT  a.ActivityYear,
            a.ActivityMonth,
            COUNT(DISTINCT a.UserID) AS MAU,
            COUNT(DISTINCT CASE
                    WHEN a.SignupDate >= DATEFROMPARTS(a.ActivityYear,
                                                       a.ActivityMonth, 1)
                    THEN a.UserID END) AS NewUsers,
            COUNT(DISTINCT CASE
                    WHEN a.SignupDate <  DATEFROMPARTS(a.ActivityYear,
                                                       a.ActivityMonth, 1)
                    THEN a.UserID END) AS ReturningUsers,
            ISNULL(r.Net, 0) AS NetRevenueUSD,
            CAST(ISNULL(r.Net, 0) /
                 NULLIF(COUNT(DISTINCT a.UserID), 0)
                 AS DECIMAL(10,2)) AS ArpuUSD
      FROM  Activity AS a
      LEFT JOIN Revenue AS r
             ON r.ActivityYear  = a.ActivityYear
            AND r.ActivityMonth = a.ActivityMonth
     GROUP BY a.ActivityYear, a.ActivityMonth, r.Net
     ORDER BY a.ActivityYear, a.ActivityMonth;
END;
GO
