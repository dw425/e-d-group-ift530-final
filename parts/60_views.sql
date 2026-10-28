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
   SECTION 6: THREE QUERIES, EACH CONVERTED INTO A VIEW

   Each query is shown first as a plain SELECT, exactly as it was
   written and tested, and then again inside CREATE VIEW. The only
   difference between the two forms is the wrapper, which is what
   "convert them into views" means here.

   All three join more than one table and all three restrict with a
   WHERE clause, as the assignment requires. The three restrictions are
   deliberately different in kind: query 1 throws out rows before
   grouping, query 2 restricts to open accounts, and query 3 is a
   restriction that only exists because two copies of one dimension are
   being compared against each other.

   No ORDER BY inside any view: SQL Server does not allow it in a view
   definition without TOP or OFFSET, because a view is a table
   expression and a table has no order. Ordering belongs to whoever
   reads the view, and the tests in section 9 do it there.

   No WITH SCHEMABINDING either. It would bind each view to the columns
   it reads and block the DROP TABLE statements in section 2, which
   would stop the script being re-runnable.
   ====================================================================== */

/* ----------------------------------------------------------------------
   QUERY 1 - Daily active users, split free against paid, with a rolling
   thirty-day active count and the ratio between them.

   Why this is useful: daily actives is the number this business is run
   on, but on its own it only says how busy yesterday was. Divided by
   the rolling thirty-day count it becomes stickiness - what share of
   the people who played this month played today - which is the
   difference between a game people return to and one they tried once.

   The rolling count is a CROSS APPLY rather than a window function
   because SQL Server has no COUNT(DISTINCT) OVER (). A correlated
   subquery per day is the way to get a distinct count over a moving
   window.

   Only SessionStart rows are counted, so a long session does not make
   somebody more active than a short one.

   Selecting from this view prints "Null value is eliminated by an
   aggregate". That is expected: the paid and free splits are
   COUNT(DISTINCT CASE WHEN ... END), and COUNT skipping the NULLs the
   CASE returns for the other side is exactly what makes a conditional
   distinct count work. The free and paid splits use
   the open account; a user with no account at all still counts toward
   the total, which is why the two splits need not sum to DAU.
   ---------------------------------------------------------------------- */

/* ---- as a plain SELECT -------------------------------------------- */
SELECT  d.ActivityDate,
        d.DAU,
        d.PaidDAU,
        d.FreeDAU,
        m.Rolling30DayMAU,
        CAST(100.0 * d.DAU / NULLIF(m.Rolling30DayMAU, 0)
             AS DECIMAL(5,2)) AS StickinessPct
  FROM (
        SELECT  CAST(e.EventTS AS date) AS ActivityDate,
                COUNT(DISTINCT e.UserID) AS DAU,
                COUNT(DISTINCT CASE WHEN p.IsPaid = 1
                                    THEN e.UserID END) AS PaidDAU,
                COUNT(DISTINCT CASE WHEN p.IsPaid = 0
                                    THEN e.UserID END) AS FreeDAU
          FROM  dbo.FactUserEvent AS e
          JOIN  dbo.DimUser       AS u ON u.UserID = e.UserID
          LEFT JOIN dbo.DimAccount AS a
                 ON a.UserID = u.UserID
                AND a.ClosedDate IS NULL
          LEFT JOIN dbo.DimPlan   AS p ON p.PlanID = a.PlanID
         WHERE  e.EventType = 'SessionStart'
           AND  u.LifecycleStage <> 'Banned'
         GROUP BY CAST(e.EventTS AS date)
       ) AS d
 CROSS APPLY (
        SELECT COUNT(DISTINCT e2.UserID) AS Rolling30DayMAU
          FROM dbo.FactUserEvent AS e2
          JOIN dbo.DimUser       AS u2 ON u2.UserID = e2.UserID
         WHERE e2.EventType = 'SessionStart'
           AND u2.LifecycleStage <> 'Banned'
           AND e2.EventTS >= DATEADD(day, -29,
                                CAST(d.ActivityDate AS datetime2))
           AND e2.EventTS <  DATEADD(day, 1,
                                CAST(d.ActivityDate AS datetime2))
       ) AS m
 ORDER BY d.ActivityDate;
GO

/* ---- and the same query as a view ---------------------------------- */
DROP VIEW IF EXISTS dbo.vwDailyActiveUsers;
GO

CREATE VIEW dbo.vwDailyActiveUsers
AS
SELECT  d.ActivityDate,
        d.DAU,
        d.PaidDAU,
        d.FreeDAU,
        m.Rolling30DayMAU,
        CAST(100.0 * d.DAU / NULLIF(m.Rolling30DayMAU, 0)
             AS DECIMAL(5,2)) AS StickinessPct
  FROM (
        SELECT  CAST(e.EventTS AS date) AS ActivityDate,
                COUNT(DISTINCT e.UserID) AS DAU,
                COUNT(DISTINCT CASE WHEN p.IsPaid = 1
                                    THEN e.UserID END) AS PaidDAU,
                COUNT(DISTINCT CASE WHEN p.IsPaid = 0
                                    THEN e.UserID END) AS FreeDAU
          FROM  dbo.FactUserEvent AS e
          JOIN  dbo.DimUser       AS u ON u.UserID = e.UserID
          LEFT JOIN dbo.DimAccount AS a
                 ON a.UserID = u.UserID
                AND a.ClosedDate IS NULL
          LEFT JOIN dbo.DimPlan   AS p ON p.PlanID = a.PlanID
         WHERE  e.EventType = 'SessionStart'
           AND  u.LifecycleStage <> 'Banned'
         GROUP BY CAST(e.EventTS AS date)
       ) AS d
 CROSS APPLY (
        SELECT COUNT(DISTINCT e2.UserID) AS Rolling30DayMAU
          FROM dbo.FactUserEvent AS e2
          JOIN dbo.DimUser       AS u2 ON u2.UserID = e2.UserID
         WHERE e2.EventType = 'SessionStart'
           AND u2.LifecycleStage <> 'Banned'
           AND e2.EventTS >= DATEADD(day, -29,
                                CAST(d.ActivityDate AS datetime2))
           AND e2.EventTS <  DATEADD(day, 1,
                                CAST(d.ActivityDate AS datetime2))
       ) AS m;
GO

/* ----------------------------------------------------------------------
   QUERY 2 - What each plan is actually worth, in engagement and money.

   Why this is useful: it answers the question every pricing argument
   turns on, which is whether paying players genuinely play more or
   simply pay. Engagement and revenue sit in different fact tables at
   different grains, so they are aggregated separately through OUTER
   APPLY and only then brought together. Joining both fact tables
   directly would multiply sessions by payments and overstate both.

   Refunds are subtracted rather than ignored, so the revenue column is
   net. Restricted to open accounts: a cancelled account's history is
   worth keeping but it is not what a current plan is worth.
   ---------------------------------------------------------------------- */

/* ---- as a plain SELECT -------------------------------------------- */
SELECT  pl.IsPaid,
        pl.PlanName,
        pl.PriceUSD,
        COUNT(DISTINCT a.AccountID) AS Accounts,
        SUM(ev.Sessions)            AS Sessions,
        SUM(ev.Events)              AS Events,
        CAST(AVG(CAST(ev.Sessions AS DECIMAL(9,2)))
             AS DECIMAL(9,2))       AS AvgSessionsPerAccount,
        CAST(SUM(pay.NetRevenue) AS DECIMAL(10,2)) AS NetRevenueUSD,
        CAST(SUM(pay.NetRevenue) /
             NULLIF(COUNT(DISTINCT a.AccountID), 0)
             AS DECIMAL(10,2))      AS RevenuePerAccountUSD
  FROM  dbo.DimAccount AS a
  JOIN  dbo.DimPlan    AS pl ON pl.PlanID = a.PlanID
  JOIN  dbo.DimUser    AS u  ON u.UserID  = a.UserID
  OUTER APPLY (
        SELECT COUNT(DISTINCT e.SessionID) AS Sessions,
               COUNT(*)                    AS Events
          FROM dbo.FactUserEvent AS e
         WHERE e.UserID = u.UserID
       ) AS ev
  OUTER APPLY (
        SELECT ISNULL(SUM(CASE WHEN f.PaymentType = 'Refund'
                               THEN -f.AmountUSD
                               ELSE  f.AmountUSD END), 0) AS NetRevenue
          FROM dbo.FactPayment AS f
         WHERE f.AccountID = a.AccountID
       ) AS pay
 WHERE  a.ClosedDate IS NULL
 GROUP BY pl.IsPaid, pl.PlanName, pl.PriceUSD
 ORDER BY pl.IsPaid DESC, NetRevenueUSD DESC;
GO

/* ---- and the same query as a view ---------------------------------- */
DROP VIEW IF EXISTS dbo.vwFreeVsPaidValue;
GO

CREATE VIEW dbo.vwFreeVsPaidValue
AS
SELECT  pl.IsPaid,
        pl.PlanName,
        pl.PriceUSD,
        COUNT(DISTINCT a.AccountID) AS Accounts,
        SUM(ev.Sessions)            AS Sessions,
        SUM(ev.Events)              AS Events,
        CAST(AVG(CAST(ev.Sessions AS DECIMAL(9,2)))
             AS DECIMAL(9,2))       AS AvgSessionsPerAccount,
        CAST(SUM(pay.NetRevenue) AS DECIMAL(10,2)) AS NetRevenueUSD,
        CAST(SUM(pay.NetRevenue) /
             NULLIF(COUNT(DISTINCT a.AccountID), 0)
             AS DECIMAL(10,2))      AS RevenuePerAccountUSD
  FROM  dbo.DimAccount AS a
  JOIN  dbo.DimPlan    AS pl ON pl.PlanID = a.PlanID
  JOIN  dbo.DimUser    AS u  ON u.UserID  = a.UserID
  OUTER APPLY (
        SELECT COUNT(DISTINCT e.SessionID) AS Sessions,
               COUNT(*)                    AS Events
          FROM dbo.FactUserEvent AS e
         WHERE e.UserID = u.UserID
       ) AS ev
  OUTER APPLY (
        SELECT ISNULL(SUM(CASE WHEN f.PaymentType = 'Refund'
                               THEN -f.AmountUSD
                               ELSE  f.AmountUSD END), 0) AS NetRevenue
          FROM dbo.FactPayment AS f
         WHERE f.AccountID = a.AccountID
       ) AS pay
 WHERE  a.ClosedDate IS NULL
 GROUP BY pl.IsPaid, pl.PlanName, pl.PriceUSD;
GO

/* ----------------------------------------------------------------------
   QUERY 3 - Payments worth a second look.

   Why this is useful: this is the query the whole geography design was
   built for. DimGeography is joined three times against the same
   payment - once as where the money moved, once as where the account
   was registered, once as where the person was last seen - and the
   suspicion is entirely in the disagreement between those three.

   Three rules, and the reason each is here:

     - the payment came from a country the person never registered in
     - the payment came from a place the dimension marks as high risk
     - the implied speed between the last session and the payment is
       over 900 km/h, which is faster than a commercial flight and is
       the signal that does not have an innocent explanation

   The implied speed is where fnGeoDistanceKm earns its place. Distance
   alone says nothing, because people travel; distance divided by the
   minutes since they were last seen says whether a human body could
   have made the trip.

   Refunds are excluded: a refund moves money back and is not a
   transaction anybody is trying to get away with.

   One limitation worth stating. LastSeenAt on DimUser is the person's
   most recent session, full stop, not the last one before this
   particular payment. That is the right comparison for a screen
   running against live traffic, where the payment being checked is the
   newest thing that has happened. Run over history it is backwards for
   any payment older than that session, so MinsSinceLastSeen is left
   NULL in that case rather than reported as a negative number, and the
   travel rule cannot fire on it. Comparing against the session
   immediately preceding each payment would fix it and would cost a
   correlated subquery per row.
   ---------------------------------------------------------------------- */

/* ---- as a plain SELECT -------------------------------------------- */
SELECT  f.PaymentID,
        u.Username,
        a.AccountNumber,
        f.PaymentTS,
        f.AmountUSD,
        f.PaymentMethod,
        rg.CountryCode AS RegisteredCountry,
        pg.CountryCode AS PaymentCountry,
        pg.RiskTier    AS PaymentRiskTier,
        lg.CountryCode AS LastSeenCountry,
        CASE WHEN f.PaymentTS >= u.LastSeenAt
             THEN DATEDIFF(minute, u.LastSeenAt, f.PaymentTS)
        END AS MinsSinceLastSeen,
        dbo.fnGeoDistanceKm(u.LastSeenGeoID, f.GeoID) AS KmFromLastSeen,
        CASE
            WHEN u.LastSeenAt IS NOT NULL
             AND DATEDIFF(minute, u.LastSeenAt, f.PaymentTS) BETWEEN 1 AND 600
             AND dbo.fnGeoDistanceKm(u.LastSeenGeoID, f.GeoID) /
                 (DATEDIFF(minute, u.LastSeenAt, f.PaymentTS) / 60.0) > 900
                THEN 'Impossible travel'
            WHEN pg.RiskTier = 'High'
                THEN 'High risk location'
            ELSE 'Country mismatch'
        END AS Reason
  FROM  dbo.FactPayment  AS f
  JOIN  dbo.DimAccount   AS a  ON a.AccountID = f.AccountID
  JOIN  dbo.DimUser      AS u  ON u.UserID    = a.UserID
  JOIN  dbo.DimGeography AS pg ON pg.GeoID    = f.GeoID
  JOIN  dbo.DimGeography AS rg ON rg.GeoID    = u.RegisteredGeoID
  LEFT JOIN dbo.DimGeography AS lg ON lg.GeoID = u.LastSeenGeoID
 WHERE  f.PaymentType <> 'Refund'
   AND  (pg.CountryCode <> rg.CountryCode OR pg.RiskTier = 'High')
 ORDER BY f.PaymentTS;
GO

/* ---- and the same query as a view ---------------------------------- */
DROP VIEW IF EXISTS dbo.vwSuspiciousTransactions;
GO

CREATE VIEW dbo.vwSuspiciousTransactions
AS
SELECT  f.PaymentID,
        u.Username,
        a.AccountNumber,
        f.PaymentTS,
        f.AmountUSD,
        f.PaymentMethod,
        rg.CountryCode AS RegisteredCountry,
        pg.CountryCode AS PaymentCountry,
        pg.RiskTier    AS PaymentRiskTier,
        lg.CountryCode AS LastSeenCountry,
        CASE WHEN f.PaymentTS >= u.LastSeenAt
             THEN DATEDIFF(minute, u.LastSeenAt, f.PaymentTS)
        END AS MinsSinceLastSeen,
        dbo.fnGeoDistanceKm(u.LastSeenGeoID, f.GeoID) AS KmFromLastSeen,
        CASE
            WHEN u.LastSeenAt IS NOT NULL
             AND DATEDIFF(minute, u.LastSeenAt, f.PaymentTS) BETWEEN 1 AND 600
             AND dbo.fnGeoDistanceKm(u.LastSeenGeoID, f.GeoID) /
                 (DATEDIFF(minute, u.LastSeenAt, f.PaymentTS) / 60.0) > 900
                THEN 'Impossible travel'
            WHEN pg.RiskTier = 'High'
                THEN 'High risk location'
            ELSE 'Country mismatch'
        END AS Reason
  FROM  dbo.FactPayment  AS f
  JOIN  dbo.DimAccount   AS a  ON a.AccountID = f.AccountID
  JOIN  dbo.DimUser      AS u  ON u.UserID    = a.UserID
  JOIN  dbo.DimGeography AS pg ON pg.GeoID    = f.GeoID
  JOIN  dbo.DimGeography AS rg ON rg.GeoID    = u.RegisteredGeoID
  LEFT JOIN dbo.DimGeography AS lg ON lg.GeoID = u.LastSeenGeoID
 WHERE  f.PaymentType <> 'Refund'
   AND  (pg.CountryCode <> rg.CountryCode OR pg.RiskTier = 'High');
GO
