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
   SECTION 7: THE AUDIT TRIGGER, AND A TEST OF ALL THREE OPERATIONS

   DimPlan is the lookup table being audited. It is the right choice
   because its rows are the ones that genuinely change: a price rise, a
   plan being made free, a plan being retired. Every one of those is a
   change somebody will later have to account for, and none of them
   leaves a trace in the table itself.

   One trigger covers all three operations. SQL Server gives a trigger
   two pseudo-tables, inserted and deleted, and which of them has rows
   is what the operation is:

       rows in inserted, none in deleted   -> INSERT
       rows in both                        -> UPDATE
       rows in deleted, none in inserted   -> DELETE

   So the three cases are three statements against those tables rather
   than three separate triggers. The trigger is set-based: it handles a
   statement that changes ten rows as correctly as one that changes one,
   which a trigger written with variables would not.
   ====================================================================== */

DROP TRIGGER IF EXISTS dbo.TR_DimPlan_Audit;
GO

CREATE TRIGGER dbo.TR_DimPlan_Audit
ON dbo.DimPlan
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    /* UPDATE: a row on both sides, keyed on PlanID. */
    INSERT INTO dbo.DimPlanAudit
        (PlanID, ChangeType, OldPlanName, NewPlanName,
         OldPriceUSD, NewPriceUSD, OldIsPaid, NewIsPaid)
    SELECT  i.PlanID, 'UPDATE',
            d.PlanName, i.PlanName,
            d.PriceUSD, i.PriceUSD,
            d.IsPaid,   i.IsPaid
      FROM  inserted AS i
      JOIN  deleted  AS d ON d.PlanID = i.PlanID;

    /* INSERT: in inserted, with no matching row in deleted. */
    INSERT INTO dbo.DimPlanAudit
        (PlanID, ChangeType, OldPlanName, NewPlanName,
         OldPriceUSD, NewPriceUSD, OldIsPaid, NewIsPaid)
    SELECT  i.PlanID, 'INSERT',
            NULL, i.PlanName,
            NULL, i.PriceUSD,
            NULL, i.IsPaid
      FROM  inserted AS i
     WHERE  NOT EXISTS (SELECT 1 FROM deleted AS d
                         WHERE d.PlanID = i.PlanID);

    /* DELETE: in deleted, with no matching row in inserted. */
    INSERT INTO dbo.DimPlanAudit
        (PlanID, ChangeType, OldPlanName, NewPlanName,
         OldPriceUSD, NewPriceUSD, OldIsPaid, NewIsPaid)
    SELECT  d.PlanID, 'DELETE',
            d.PlanName, NULL,
            d.PriceUSD, NULL,
            d.IsPaid,   NULL
      FROM  deleted AS d
     WHERE  NOT EXISTS (SELECT 1 FROM inserted AS i
                         WHERE i.PlanID = d.PlanID);
END;
GO

/* ----------------------------------------------------------------------
   The test the assignment asks for: insert, modify, delete, and show
   what landed in the audit table.

   PlanID 99 is used throughout and removed at the end, so the test
   leaves DimPlan exactly as it found it and the script stays
   re-runnable. The three audit rows it produces are deliberately NOT
   cleaned up: they are the evidence the trigger fired, and an audit
   trail that tidies itself away is not one. They do not accumulate
   across runs, because section 2 drops the audit table with everything
   else - a real deployment would create this table once and never drop
   it, which is the one way this script differs from how it would ship.

   No account is ever pointed at plan 99, so the delete is not blocked
   by DimAccount's foreign key. That is the only reason a plan can be
   deleted at all here, and it is worth saying out loud: in production
   a plan in use would be retired with a flag, not deleted.
   ---------------------------------------------------------------------- */

PRINT '== Audit test: starting state';
SELECT COUNT(*) AS AuditRowsBefore FROM dbo.DimPlanAudit;
GO

/* 1 of 3 - INSERT a new plan. */
PRINT '== Audit test 1: INSERT plan 99';
INSERT INTO dbo.DimPlan
    (PlanID, PlanName, PriceUSD, BillingPeriod, IsPaid,
     TrialDays, AdsEnabled, EffectiveDate)
VALUES
    (99, 'Audit Test Plan', 7.99, 'Monthly', 1, 7, 0, '2026-10-26');
GO

/* 2 of 3 - UPDATE it: a price rise and the ad flag turned back on,
   which is the kind of change this audit table exists to capture. */
PRINT '== Audit test 2: UPDATE the price of plan 99';
UPDATE  dbo.DimPlan
   SET  PriceUSD   = 9.99,
        AdsEnabled = 1
 WHERE  PlanID = 99;
GO

/* 3 of 3 - DELETE it. */
PRINT '== Audit test 3: DELETE plan 99';
DELETE FROM dbo.DimPlan
 WHERE PlanID = 99;
GO

PRINT '== Audit test: what the trigger recorded';
SELECT  AuditID,
        PlanID,
        ChangeType,
        OldPlanName,
        NewPlanName,
        OldPriceUSD,
        NewPriceUSD,
        OldIsPaid,
        NewIsPaid,
        ChangedBy,
        ChangedAt
  FROM  dbo.DimPlanAudit
 WHERE  PlanID = 99
 ORDER BY AuditID;
GO
