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
   SECTION 2: DROP EVERY OBJECT THIS SCRIPT CREATES

   This is what makes the script re-runnable. Order matters: programmable
   objects first, then tables child-first, because a table cannot be
   dropped while a foreign key still points at it.

   DROP ... IF EXISTS rather than a guard on OBJECT_ID. Both work; this
   one is a single statement and cannot be fooled by an object of the
   wrong type sharing the name.
   ====================================================================== */

DROP VIEW     IF EXISTS dbo.vwDailyActiveUsers;
DROP VIEW     IF EXISTS dbo.vwFreeVsPaidValue;
DROP VIEW     IF EXISTS dbo.vwSuspiciousTransactions;
GO

DROP PROCEDURE IF EXISTS dbo.spMonthlyActiveUsers;
GO

DROP FUNCTION IF EXISTS dbo.fnGeoDistanceKm;
GO

DROP TRIGGER  IF EXISTS dbo.TR_DimPlan_Audit;
GO

/* Children first, then parents. FactUserEvent and the two revenue facts
   point at DimUser and DimAccount; DimAccount points at DimUser; DimUser
   points at DimGeography and DimCampaign. Nothing points at
   DimPlanAudit, by design, so it can go in any order. */
DROP TABLE IF EXISTS dbo.FactUserEvent;
DROP TABLE IF EXISTS dbo.FactPayment;
DROP TABLE IF EXISTS dbo.FactSubscription;
DROP TABLE IF EXISTS dbo.DimPlanAudit;
DROP TABLE IF EXISTS dbo.DimAccount;
DROP TABLE IF EXISTS dbo.DimUser;
DROP TABLE IF EXISTS dbo.DimCampaign;
DROP TABLE IF EXISTS dbo.DimProduct;
DROP TABLE IF EXISTS dbo.DimPlan;
DROP TABLE IF EXISTS dbo.DimGeography;
GO
