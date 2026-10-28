/*
** Author: Ethan Oxley, Daniel Warren
** Group: E & D Group
** Course: IFT 530: Advanced Database Management Systems
** SQL Server Version: Microsoft SQL Server 2025 (Developer Edition)
** OS: macOS 26.5.1 (SQL Server running in Microsoft's official Linux
**     container under Docker)
** Date: 10/27/2026
** Assignment: Final Project
*/

/* ======================================================================
   SECTION 9: TESTS

   The announcement asks that the script also carry the queries that
   test the code. Each test reports PASS or FAIL in a column called
   Result, so a run can be checked by reading one column rather than by
   comparing numbers by eye.

   What is tested, and why each one is here rather than trusting that
   the script "ran without errors":

     1-3  the objects exist, out of the catalog views, not from the
          absence of an error message
     4    row counts are what section 4 loaded
     5    no orphan rows on any foreign key
     6-8  each view returns rows AND genuinely restricts - a view whose
          WHERE clause does nothing would still return rows
     9    the audit trigger recorded all three operations
     10   the function returns a known distance
     11   the procedure returns the months it should
     12   the procedure rejects bad arguments instead of returning empty
     13   the transactional tables sit inside the 20-50 rows the
          assignment asks for, which is a requirement and not a detail
   ====================================================================== */

PRINT '== Tests';

SET NOCOUNT ON;
GO

DROP TABLE IF EXISTS #Results;
CREATE TABLE #Results (
    Seq    INT,
    Test   VARCHAR(60),
    Got    VARCHAR(40),
    Want   VARCHAR(40),
    Result VARCHAR(4)
);
GO

/* ---- 1-3: the objects this script creates are all present --------- */
INSERT INTO #Results
SELECT 1, 'Tables created', CAST(COUNT(*) AS VARCHAR), '10',
       CASE WHEN COUNT(*) = 10 THEN 'PASS' ELSE 'FAIL' END
  FROM sys.tables;

INSERT INTO #Results
SELECT 2, 'Views created', CAST(COUNT(*) AS VARCHAR), '3',
       CASE WHEN COUNT(*) = 3 THEN 'PASS' ELSE 'FAIL' END
  FROM sys.views;

INSERT INTO #Results
SELECT 3, 'Proc, function and trigger',
       CAST((SELECT COUNT(*) FROM sys.procedures
              WHERE name = 'spMonthlyActiveUsers') +
            (SELECT COUNT(*) FROM sys.objects
              WHERE name = 'fnGeoDistanceKm' AND type = 'FN') +
            (SELECT COUNT(*) FROM sys.triggers
              WHERE name = 'TR_DimPlan_Audit') AS VARCHAR),
       '3',
       CASE WHEN (SELECT COUNT(*) FROM sys.procedures
                   WHERE name = 'spMonthlyActiveUsers') +
                 (SELECT COUNT(*) FROM sys.objects
                   WHERE name = 'fnGeoDistanceKm' AND type = 'FN') +
                 (SELECT COUNT(*) FROM sys.triggers
                   WHERE name = 'TR_DimPlan_Audit') = 3
            THEN 'PASS' ELSE 'FAIL' END;
GO

/* ---- 4: row counts, dimensions and facts -------------------------- */
INSERT INTO #Results
SELECT 4, 'Row counts',
       CAST((SELECT COUNT(*) FROM dbo.DimGeography) AS VARCHAR) + '/' +
       CAST((SELECT COUNT(*) FROM dbo.DimUser)      AS VARCHAR) + '/' +
       CAST((SELECT COUNT(*) FROM dbo.DimAccount)   AS VARCHAR),
       '10/10/10',
       CASE WHEN (SELECT COUNT(*) FROM dbo.DimGeography) = 10
             AND (SELECT COUNT(*) FROM dbo.DimUser)      = 10
             AND (SELECT COUNT(*) FROM dbo.DimAccount)   = 10
            THEN 'PASS' ELSE 'FAIL' END;
GO

/* ---- 5: referential integrity, checked rather than assumed -------- */
INSERT INTO #Results
SELECT 5, 'No orphan rows on any FK',
       CAST(
         (SELECT COUNT(*) FROM dbo.DimUser u
           WHERE NOT EXISTS (SELECT 1 FROM dbo.DimGeography g
                              WHERE g.GeoID = u.RegisteredGeoID)) +
         (SELECT COUNT(*) FROM dbo.DimAccount a
           WHERE NOT EXISTS (SELECT 1 FROM dbo.DimUser u
                              WHERE u.UserID = a.UserID)) +
         (SELECT COUNT(*) FROM dbo.FactUserEvent e
           WHERE NOT EXISTS (SELECT 1 FROM dbo.DimUser u
                              WHERE u.UserID = e.UserID)) +
         (SELECT COUNT(*) FROM dbo.FactPayment f
           WHERE NOT EXISTS (SELECT 1 FROM dbo.DimAccount a
                              WHERE a.AccountID = f.AccountID)) +
         (SELECT COUNT(*) FROM dbo.FactSubscription s
           WHERE NOT EXISTS (SELECT 1 FROM dbo.DimAccount a
                              WHERE a.AccountID = s.AccountID))
         AS VARCHAR),
       '0',
       CASE WHEN
         (SELECT COUNT(*) FROM dbo.DimUser u
           WHERE NOT EXISTS (SELECT 1 FROM dbo.DimGeography g
                              WHERE g.GeoID = u.RegisteredGeoID)) +
         (SELECT COUNT(*) FROM dbo.DimAccount a
           WHERE NOT EXISTS (SELECT 1 FROM dbo.DimUser u
                              WHERE u.UserID = a.UserID)) +
         (SELECT COUNT(*) FROM dbo.FactUserEvent e
           WHERE NOT EXISTS (SELECT 1 FROM dbo.DimUser u
                              WHERE u.UserID = e.UserID)) +
         (SELECT COUNT(*) FROM dbo.FactPayment f
           WHERE NOT EXISTS (SELECT 1 FROM dbo.DimAccount a
                              WHERE a.AccountID = f.AccountID)) +
         (SELECT COUNT(*) FROM dbo.FactSubscription s
           WHERE NOT EXISTS (SELECT 1 FROM dbo.DimAccount a
                              WHERE a.AccountID = s.AccountID)) = 0
            THEN 'PASS' ELSE 'FAIL' END;
GO

/* ---- 6: view 1 returns a row per active day, and DAU never exceeds
          the rolling thirty-day count it is divided by ------------- */
INSERT INTO #Results
SELECT 6, 'vwDailyActiveUsers sane',
       CAST(COUNT(*) AS VARCHAR) + ' days, ' +
       CAST(SUM(CASE WHEN DAU > Rolling30DayMAU THEN 1 ELSE 0 END)
            AS VARCHAR) + ' bad',
       '>0 days, 0 bad',
       CASE WHEN COUNT(*) > 0
             AND SUM(CASE WHEN DAU > Rolling30DayMAU
                          THEN 1 ELSE 0 END) = 0
            THEN 'PASS' ELSE 'FAIL' END
  FROM dbo.vwDailyActiveUsers;
GO

/* ---- 7: view 2 covers both sides of the paid split ---------------- */
INSERT INTO #Results
SELECT 7, 'vwFreeVsPaidValue has both sides',
       CAST(COUNT(DISTINCT IsPaid) AS VARCHAR), '2',
       CASE WHEN COUNT(DISTINCT IsPaid) = 2 THEN 'PASS' ELSE 'FAIL' END
  FROM dbo.vwFreeVsPaidValue;
GO

/* ---- 8: view 3 restricts. The point is not that it returns rows but
          that it returns FEWER than the unrestricted join, which is
          what proves the WHERE clause is doing work. -------------- */
INSERT INTO #Results
SELECT 8, 'vwSuspiciousTransactions restricts',
       CAST((SELECT COUNT(*) FROM dbo.vwSuspiciousTransactions)
            AS VARCHAR) + ' of ' +
       CAST((SELECT COUNT(*) FROM dbo.FactPayment) AS VARCHAR),
       'fewer, and > 0',
       CASE WHEN (SELECT COUNT(*) FROM dbo.vwSuspiciousTransactions)
                  BETWEEN 1 AND
                  (SELECT COUNT(*) FROM dbo.FactPayment) - 1
            THEN 'PASS' ELSE 'FAIL' END;
GO

/* ---- 9: the trigger caught all three operations ------------------- */
INSERT INTO #Results
SELECT 9, 'Audit caught INSERT, UPDATE, DELETE',
       CAST(COUNT(DISTINCT ChangeType) AS VARCHAR), '3',
       CASE WHEN COUNT(DISTINCT ChangeType) = 3
             AND SUM(CASE WHEN ChangedAt IS NULL THEN 1 ELSE 0 END) = 0
            THEN 'PASS' ELSE 'FAIL' END
  FROM dbo.DimPlanAudit
 WHERE PlanID = 99;
GO

/* ---- 10: the function, against a distance that can be checked.
           Phoenix (GeoID 1) to London (GeoID 4) is about 8,400 km. -- */
INSERT INTO #Results
SELECT 10, 'fnGeoDistanceKm Phoenix to London',
       CAST(dbo.fnGeoDistanceKm(1, 4) AS VARCHAR), '8300-8500 km',
       CASE WHEN dbo.fnGeoDistanceKm(1, 4) BETWEEN 8300 AND 8500
            THEN 'PASS' ELSE 'FAIL' END;
GO

/* ---- 11: the procedure returns the months it should --------------- */
DROP TABLE IF EXISTS #Mau;
CREATE TABLE #Mau (
    ActivityYear   INT,
    ActivityMonth  INT,
    MAU            INT,
    NewUsers       INT,
    ReturningUsers INT,
    NetRevenueUSD  DECIMAL(10,2),
    ArpuUSD        DECIMAL(10,2)
);
INSERT INTO #Mau EXEC dbo.spMonthlyActiveUsers @Year = 2026;

INSERT INTO #Results
SELECT 11, 'spMonthlyActiveUsers returns months',
       CAST(COUNT(*) AS VARCHAR), '2',
       CASE WHEN COUNT(*) = 2 AND MIN(MAU) > 0
            THEN 'PASS' ELSE 'FAIL' END
  FROM #Mau;
GO

/* ---- 12: and rejects arguments it cannot answer. A bad year has to
            raise 50001, not come back empty. ---------------------- */
DECLARE @Err INT = 0;
BEGIN TRY
    EXEC dbo.spMonthlyActiveUsers @Year = 1850;
END TRY
BEGIN CATCH
    SET @Err = ERROR_NUMBER();
END CATCH;

INSERT INTO #Results
SELECT 12, 'spMonthlyActiveUsers rejects bad year',
       CAST(@Err AS VARCHAR), '50001',
       CASE WHEN @Err = 50001 THEN 'PASS' ELSE 'FAIL' END;
GO

/* ---- 13: the transactional tables sit inside the 20-50 the
          assignment asks for. This is a requirement, not a detail,
          so it is asserted rather than eyeballed. ---------------- */
INSERT INTO #Results
SELECT 13, 'Fact rows within 20-50',
       CAST((SELECT COUNT(*) FROM dbo.FactUserEvent)    AS VARCHAR) + '/' +
       CAST((SELECT COUNT(*) FROM dbo.FactPayment)      AS VARCHAR) + '/' +
       CAST((SELECT COUNT(*) FROM dbo.FactSubscription) AS VARCHAR),
       'each 20-50',
       CASE WHEN (SELECT COUNT(*) FROM dbo.FactUserEvent)
                     BETWEEN 20 AND 50
             AND (SELECT COUNT(*) FROM dbo.FactPayment)
                     BETWEEN 20 AND 50
             AND (SELECT COUNT(*) FROM dbo.FactSubscription)
                     BETWEEN 20 AND 50
            THEN 'PASS' ELSE 'FAIL' END;
GO

/* ---- the results -------------------------------------------------- */
PRINT '== Test results';
SELECT Seq, Test, Got, Want, Result
  FROM #Results
 ORDER BY Seq;

SELECT CAST(SUM(CASE WHEN Result = 'PASS' THEN 1 ELSE 0 END) AS VARCHAR)
       + ' PASS, ' +
       CAST(SUM(CASE WHEN Result = 'FAIL' THEN 1 ELSE 0 END) AS VARCHAR)
       + ' FAIL' AS Summary
  FROM #Results;
GO

DROP TABLE IF EXISTS #Results;
DROP TABLE IF EXISTS #Mau;
GO

PRINT '== Script complete';
GO
