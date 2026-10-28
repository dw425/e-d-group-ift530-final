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
   IFT 530: Advanced Database Management Systems
   Final Project - E & D Group
   Ethan Oxley, Daniel Warren

   A player analytics database for a live, free-to-play online game.
   Ten tables: six dimensions describing the customer from different
   angles, three fact tables recording what happened, and one audit
   table holding the change history of the plan lookup.

   The design question behind it is that this kind of game earns nothing
   when somebody installs it. It earns weeks later, from a fraction of
   players who decide it is worth paying for, and it only reaches those
   players by buying their attention first. So the useful questions span
   areas usually kept apart: who the customer is, what they did, what
   they pay, and whether the payment should be trusted.

   Sections, in the order they run:

     1. Create the database
     2. Drop every object this script creates
     3. Create the ten tables and their indexes
     4. Populate them
     5. A user defined function and a stored procedure
     6. Three queries, each also saved as a view
     7. The audit table's trigger, with an insert/update/delete test
     8. A cursor
     9. Tests

   The function comes before the views because the suspicious
   transaction view in section 6 calls it.

   Re-runnable. Section 2 drops every view, procedure, function, trigger
   and table before section 3 creates them, so a second run replaces the
   database rather than failing with "there is already an object named".
   The database itself is created only if it does not already exist and
   is never dropped. Running this file three times in a row produces the
   same objects, the same row counts and the same test results.

   On line width: every hand-written line here stays at or under 78
   characters so the report can reproduce it as a Courier New 9 pt
   listing without wrapping. The generated data rows in section 4 run to
   86, which is what still fits in a 6.5 inch column at that size.

   The test queries are at the bottom, under SECTION 9: TESTS.
   ====================================================================== */

/* ======================================================================
   SECTION 1: CREATE THE DATABASE

   Named for the group, as the assignment requires. The group is
   E & D Group; the database is E_D_Group, because a SQL Server
   identifier cannot carry spaces or an ampersand without being
   bracketed at every single reference. Created only when it
   is missing, and never dropped. Dropping a database needs every other
   connection to it closed first, which a script cannot guarantee, and
   it would force a reconnect in the middle of this one. Re-runnability
   is handled a level down, by dropping and rebuilding the objects
   inside it, which section 2 does.
   ====================================================================== */

IF DB_ID('E_D_Group') IS NULL
    CREATE DATABASE E_D_Group;
GO

USE E_D_Group;
GO

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

/* ======================================================================
   SECTION 3: CREATE THE TEN TABLES

   Parent-first, so every foreign key points at a table that already
   exists:

       DimGeography, DimPlan, DimProduct, DimCampaign   (no outbound FKs)
         -> DimUser
              -> DimAccount
                   -> FactUserEvent, FactPayment, FactSubscription

   There are no circular references. The four tables on the first line
   have no foreign keys of their own, so nothing closes a loop and the
   drop order in section 2 is simply this order reversed.

   Dimension keys are supplied explicitly, so section 4 can reference
   them in foreign keys deterministically. Fact keys are IDENTITY,
   because at the volume this schema is designed for nothing should be
   assigning keys by hand.
   ====================================================================== */

/* ----------------------------------------------------------------------
   DimGeography - every place the system knows about.

   This is a role-playing dimension: five columns across four tables
   point at it. A user has a registered location and a last known one,
   an account has a billing location, and every event and every payment
   records where it came from. One table, so any two of those can be
   compared directly - which is the whole basis of section 5's
   suspicious transaction view.
   ---------------------------------------------------------------------- */
CREATE TABLE dbo.DimGeography (
    GeoID       INT          NOT NULL,
    CountryCode CHAR(2)      NOT NULL,
    CountryName VARCHAR(60)  NOT NULL,
    Region      VARCHAR(40)  NOT NULL,
    City        VARCHAR(60)  NOT NULL,
    Latitude    DECIMAL(9,6) NOT NULL,
    Longitude   DECIMAL(9,6) NOT NULL,
    RiskTier    VARCHAR(10)  NOT NULL,
    CONSTRAINT PK_Geography PRIMARY KEY (GeoID),
    CONSTRAINT CK_Geo_Region CHECK
        (Region IN ('North America', 'EMEA', 'APAC', 'LATAM')),
    CONSTRAINT CK_Geo_Latitude  CHECK (Latitude  BETWEEN  -90 AND  90),
    CONSTRAINT CK_Geo_Longitude CHECK (Longitude BETWEEN -180 AND 180),
    CONSTRAINT CK_Geo_RiskTier CHECK
        (RiskTier IN ('Low', 'Medium', 'High'))
);
GO

/* ----------------------------------------------------------------------
   DimPlan - the subscription plans. This is the lookup table the audit
   requirement is built on: price and perks are exactly the reference
   data that changes and that somebody later has to account for.
   ---------------------------------------------------------------------- */
CREATE TABLE dbo.DimPlan (
    PlanID        INT          NOT NULL,
    PlanName      VARCHAR(30)  NOT NULL,
    PriceUSD      DECIMAL(6,2) NOT NULL,
    BillingPeriod VARCHAR(10)  NOT NULL,
    IsPaid        BIT          NOT NULL CONSTRAINT DF_Plan_IsPaid DEFAULT 0,
    TrialDays     INT          NOT NULL,
    AdsEnabled    BIT          NOT NULL CONSTRAINT DF_Plan_Ads DEFAULT 1,
    EffectiveDate DATE         NOT NULL,
    CONSTRAINT PK_Plan PRIMARY KEY (PlanID),
    CONSTRAINT UQ_Plan_Name UNIQUE (PlanName),
    CONSTRAINT CK_Plan_Price  CHECK (PriceUSD  >= 0),
    CONSTRAINT CK_Plan_Trial  CHECK (TrialDays >= 0),
    CONSTRAINT CK_Plan_Period CHECK
        (BillingPeriod IN ('Monthly', 'Annual', 'None'))
);
GO

/* ----------------------------------------------------------------------
   DimProduct - the store catalog behind one-time sales. Separate from
   the sale itself so a price change does not rewrite history.
   ---------------------------------------------------------------------- */
CREATE TABLE dbo.DimProduct (
    ProductID       INT          NOT NULL,
    ProductName     VARCHAR(60)  NOT NULL,
    ProductCategory VARCHAR(20)  NOT NULL,
    ListPriceUSD    DECIMAL(6,2) NOT NULL,
    IsActive        BIT          NOT NULL
                                 CONSTRAINT DF_Product_Active DEFAULT 1,
    ReleaseDate     DATE         NOT NULL,
    CONSTRAINT PK_Product PRIMARY KEY (ProductID),
    CONSTRAINT CK_Product_Price CHECK (ListPriceUSD > 0),
    CONSTRAINT CK_Product_Category CHECK
        (ProductCategory IN ('Currency', 'Cosmetic', 'BattlePass',
                             'Subscription'))
);
GO

/* ----------------------------------------------------------------------
   DimCampaign - what marketing ran and what it was budgeted. Without
   the budget there is no way to say whether a channel paid for itself.
   ---------------------------------------------------------------------- */
CREATE TABLE dbo.DimCampaign (
    CampaignID   INT           NOT NULL,
    CampaignName VARCHAR(60)   NOT NULL,
    Channel      VARCHAR(30)   NOT NULL,
    CostModel    VARCHAR(10)   NOT NULL,
    StartDate    DATE          NOT NULL,
    EndDate      DATE          NULL,
    BudgetUSD    DECIMAL(10,2) NOT NULL,
    CONSTRAINT PK_Campaign PRIMARY KEY (CampaignID),
    CONSTRAINT CK_Campaign_Budget CHECK (BudgetUSD >= 0),
    CONSTRAINT CK_Campaign_Channel CHECK
        (Channel IN ('Paid Search', 'Social', 'Influencer', 'Email',
                     'Organic')),
    CONSTRAINT CK_Campaign_CostModel CHECK
        (CostModel IN ('CPC', 'CPM', 'CPI')),
    /* NULL EndDate means still running, so the check has to allow it. */
    CONSTRAINT CK_Campaign_Dates CHECK
        (EndDate IS NULL OR EndDate >= StartDate)
);
GO

/* ----------------------------------------------------------------------
   DimUser - one row per person, and the table customer analysis slices
   on: age band, device, lifecycle stage, signup cohort, acquiring
   campaign, acquisition cost, and both geography columns.

   RegisteredGeoID and LastSeenGeoID are two foreign keys to the same
   table. That is deliberate and it is what the fraud work depends on:
   the pair of them, with LastSeenAt, is what makes a login from
   somewhere new visible at all.
   ---------------------------------------------------------------------- */
CREATE TABLE dbo.DimUser (
    UserID          INT          NOT NULL,
    Username        VARCHAR(30)  NOT NULL,
    Email           VARCHAR(100) NOT NULL,
    SignupDate      DATE         NOT NULL,
    RegisteredGeoID INT          NOT NULL,
    LastSeenGeoID   INT          NULL,
    LastSeenAt      DATETIME2    NULL,
    AgeBand         VARCHAR(10)  NOT NULL,
    PreferredDevice VARCHAR(20)  NOT NULL,
    LifecycleStage  VARCHAR(12)  NOT NULL,
    AcqCampaignID   INT          NULL,
    AcqCostUSD      DECIMAL(8,2) NULL,
    CONSTRAINT PK_User PRIMARY KEY (UserID),
    CONSTRAINT UQ_User_Username UNIQUE (Username),
    CONSTRAINT FK_User_RegGeo FOREIGN KEY (RegisteredGeoID)
        REFERENCES dbo.DimGeography (GeoID),
    CONSTRAINT FK_User_LastGeo FOREIGN KEY (LastSeenGeoID)
        REFERENCES dbo.DimGeography (GeoID),
    CONSTRAINT FK_User_Campaign FOREIGN KEY (AcqCampaignID)
        REFERENCES dbo.DimCampaign (CampaignID),
    CONSTRAINT CK_User_AcqCost CHECK (AcqCostUSD >= 0),
    CONSTRAINT CK_User_AgeBand CHECK
        (AgeBand IN ('13-17', '18-24', '25-34', '35-49', '50+')),
    CONSTRAINT CK_User_Device CHECK
        (PreferredDevice IN ('iOS', 'Android', 'PC', 'Console')),
    CONSTRAINT CK_User_Lifecycle CHECK
        (LifecycleStage IN ('New', 'Active', 'AtRisk', 'Churned',
                            'Banned'))
);
GO

/* ----------------------------------------------------------------------
   DimAccount - the billing entity. Separate from the person because a
   person can close an account and open another, and because plan,
   status and billing address belong to the account rather than to them.
   ---------------------------------------------------------------------- */
CREATE TABLE dbo.DimAccount (
    AccountID     INT         NOT NULL,
    UserID        INT         NOT NULL,
    AccountNumber VARCHAR(20) NOT NULL,
    PlanID        INT         NOT NULL,
    AccountStatus VARCHAR(12) NOT NULL,
    OpenedDate    DATE        NOT NULL,
    ClosedDate    DATE        NULL,
    IsAutoRenew   BIT         NOT NULL
                              CONSTRAINT DF_Account_Renew DEFAULT 1,
    BillingGeoID  INT         NOT NULL,
    CONSTRAINT PK_Account PRIMARY KEY (AccountID),
    CONSTRAINT UQ_Account_Number UNIQUE (AccountNumber),
    CONSTRAINT FK_Account_User FOREIGN KEY (UserID)
        REFERENCES dbo.DimUser (UserID),
    CONSTRAINT FK_Account_Plan FOREIGN KEY (PlanID)
        REFERENCES dbo.DimPlan (PlanID),
    CONSTRAINT FK_Account_BillGeo FOREIGN KEY (BillingGeoID)
        REFERENCES dbo.DimGeography (GeoID),
    CONSTRAINT CK_Account_Dates CHECK
        (ClosedDate IS NULL OR ClosedDate >= OpenedDate),
    CONSTRAINT CK_Account_Status CHECK
        (AccountStatus IN ('Trial', 'Active', 'PastDue', 'Cancelled',
                           'Suspended'))
);
GO

/* ----------------------------------------------------------------------
   FactUserEvent - one row per action, session boundaries included.

   The busiest table in the database, so it carries nothing but integer
   keys, one timestamp and a few short coded columns; everything
   descriptive is reached by a join.

   SessionID is a degenerate dimension. It groups events into one
   sitting and needs no table of its own, because a session has nothing
   to say beyond which events belong to it and its length is the span of
   those events.
   ---------------------------------------------------------------------- */
CREATE TABLE dbo.FactUserEvent (
    EventID      INT         IDENTITY(1,1) NOT NULL,
    UserID       INT         NOT NULL,
    SessionID    INT         NOT NULL,
    GeoID        INT         NOT NULL,
    EventType    VARCHAR(20) NOT NULL,
    EventTS      DATETIME2   NOT NULL,
    LevelNumber  INT         NULL,
    Outcome      VARCHAR(10) NULL,
    DeviceType   VARCHAR(20) NOT NULL,
    SourceSystem VARCHAR(30) NOT NULL,
    CONSTRAINT PK_UserEvent PRIMARY KEY (EventID),
    CONSTRAINT FK_Event_User FOREIGN KEY (UserID)
        REFERENCES dbo.DimUser (UserID),
    CONSTRAINT FK_Event_Geo FOREIGN KEY (GeoID)
        REFERENCES dbo.DimGeography (GeoID),
    CONSTRAINT CK_Event_Level CHECK (LevelNumber BETWEEN 1 AND 10),
    CONSTRAINT CK_Event_Type CHECK
        (EventType IN ('SessionStart', 'SessionEnd', 'LevelStart',
                       'LevelComplete', 'LevelFail', 'ItemUsed',
                       'AdWatched')),
    CONSTRAINT CK_Event_Outcome CHECK
        (Outcome IN ('Win', 'Loss', 'Abandon')),
    CONSTRAINT CK_Event_Device CHECK
        (DeviceType IN ('iOS', 'Android', 'PC', 'Console')),
    CONSTRAINT CK_Event_Source CHECK
        (SourceSystem IN ('GameClient', 'MobileSDK', 'WebClient'))
);
GO

/* ----------------------------------------------------------------------
   FactPayment - store sales, subscription charges and refunds.

   GeoID is where the transaction originated, and it is the fraud hook.
   A payment from a country the person never registered in, or one too
   far from where they were last seen for the time that has passed, is
   the thing worth reviewing. IsFlagged stores that verdict rather than
   recomputing it, so a decision made once is not re-litigated.
   ---------------------------------------------------------------------- */
CREATE TABLE dbo.FactPayment (
    PaymentID     INT          IDENTITY(1,1) NOT NULL,
    AccountID     INT          NOT NULL,
    ProductID     INT          NULL,
    CampaignID    INT          NULL,
    GeoID         INT          NOT NULL,
    PaymentTS     DATETIME2    NOT NULL,
    AmountUSD     DECIMAL(8,2) NOT NULL,
    PaymentType   VARCHAR(12)  NOT NULL,
    PaymentMethod VARCHAR(20)  NOT NULL,
    IsFlagged     BIT          NOT NULL
                               CONSTRAINT DF_Payment_Flag DEFAULT 0,
    SourceSystem  VARCHAR(30)  NOT NULL,
    CONSTRAINT PK_Payment PRIMARY KEY (PaymentID),
    CONSTRAINT FK_Payment_Account FOREIGN KEY (AccountID)
        REFERENCES dbo.DimAccount (AccountID),
    CONSTRAINT FK_Payment_Product FOREIGN KEY (ProductID)
        REFERENCES dbo.DimProduct (ProductID),
    CONSTRAINT FK_Payment_Campaign FOREIGN KEY (CampaignID)
        REFERENCES dbo.DimCampaign (CampaignID),
    CONSTRAINT FK_Payment_Geo FOREIGN KEY (GeoID)
        REFERENCES dbo.DimGeography (GeoID),
    CONSTRAINT CK_Payment_Amount CHECK (AmountUSD > 0),
    CONSTRAINT CK_Payment_Type CHECK
        (PaymentType IN ('OneTime', 'Subscription', 'Refund')),
    CONSTRAINT CK_Payment_Method CHECK
        (PaymentMethod IN ('Card', 'PayPal', 'AppStore', 'GooglePlay')),
    CONSTRAINT CK_Payment_Source CHECK
        (SourceSystem IN ('BillingAPI', 'AppStore', 'PlayStore'))
);
GO

/* ----------------------------------------------------------------------
   FactSubscription - the subscription lifecycle.

   Separate from payments because the events that matter most to
   retention, a downgrade and a cancellation, move no money at all and
   would have nowhere to live otherwise.

   PrevPlanID is a second foreign key to DimPlan. It is what makes an
   upgrade and a downgrade distinguishable without comparing prices in
   the application.
   ---------------------------------------------------------------------- */
CREATE TABLE dbo.FactSubscription (
    SubEventID   INT          IDENTITY(1,1) NOT NULL,
    AccountID    INT          NOT NULL,
    PlanID       INT          NOT NULL,
    PrevPlanID   INT          NULL,
    EventType    VARCHAR(12)  NOT NULL,
    EventDate    DATE         NOT NULL,
    MRRDeltaUSD  DECIMAL(8,2) NOT NULL,
    TermMonths   INT          NULL,
    CancelReason VARCHAR(40)  NULL,
    SourceSystem VARCHAR(30)  NOT NULL,
    CONSTRAINT PK_Subscription PRIMARY KEY (SubEventID),
    CONSTRAINT FK_Sub_Account FOREIGN KEY (AccountID)
        REFERENCES dbo.DimAccount (AccountID),
    CONSTRAINT FK_Sub_Plan FOREIGN KEY (PlanID)
        REFERENCES dbo.DimPlan (PlanID),
    CONSTRAINT FK_Sub_PrevPlan FOREIGN KEY (PrevPlanID)
        REFERENCES dbo.DimPlan (PlanID),
    CONSTRAINT CK_Sub_Term CHECK (TermMonths > 0),
    CONSTRAINT CK_Sub_EventType CHECK
        (EventType IN ('Start', 'Renew', 'Upgrade', 'Downgrade',
                       'Cancel', 'Expire')),
    CONSTRAINT CK_Sub_Source CHECK
        (SourceSystem IN ('BillingAPI', 'AppStore', 'PlayStore'))
);
GO

/* ----------------------------------------------------------------------
   DimPlanAudit - the change history of DimPlan, written only by the
   trigger in section 6.

   There is deliberately no foreign key to DimPlan. A DELETE audit row
   has to outlive the row it describes; a foreign key would either block
   the delete or cascade the history away, and either defeats the point
   of keeping an audit trail at all.
   ---------------------------------------------------------------------- */
CREATE TABLE dbo.DimPlanAudit (
    AuditID     INT          IDENTITY(1,1) NOT NULL,
    PlanID      INT          NOT NULL,
    ChangeType  VARCHAR(6)   NOT NULL,
    OldPlanName VARCHAR(30)  NULL,
    NewPlanName VARCHAR(30)  NULL,
    OldPriceUSD DECIMAL(6,2) NULL,
    NewPriceUSD DECIMAL(6,2) NULL,
    OldIsPaid   BIT          NULL,
    NewIsPaid   BIT          NULL,
    ChangedBy   VARCHAR(128) NOT NULL
                             CONSTRAINT DF_Audit_By DEFAULT SUSER_SNAME(),
    ChangedAt   DATETIME2    NOT NULL
                             CONSTRAINT DF_Audit_At DEFAULT SYSDATETIME(),
    CONSTRAINT PK_PlanAudit PRIMARY KEY (AuditID),
    CONSTRAINT CK_Audit_ChangeType CHECK
        (ChangeType IN ('INSERT', 'UPDATE', 'DELETE'))
);
GO

/* ----------------------------------------------------------------------
   Indexes beyond the keys.

   The primary keys give a clustered index each and the foreign keys
   give none, so these cover the columns the queries in sections 5 to 8
   actually filter and join on. At ten users the optimizer will ignore
   them and scan every time; they are here because the schema is
   designed for a hundred thousand, where the two timestamp columns are
   what every time-series query ranges over.
   ---------------------------------------------------------------------- */
CREATE INDEX IX_Event_TS      ON dbo.FactUserEvent (EventTS);
CREATE INDEX IX_Event_User    ON dbo.FactUserEvent (UserID);
CREATE INDEX IX_Payment_TS    ON dbo.FactPayment (PaymentTS);
CREATE INDEX IX_Payment_Acct  ON dbo.FactPayment (AccountID);
CREATE INDEX IX_Sub_Account   ON dbo.FactSubscription (AccountID);
CREATE INDEX IX_User_Lifecyc  ON dbo.DimUser (LifecycleStage);
GO
/* ======================================================================
   SECTION 4: POPULATE

   Rows are literal INSERT statements so the script is self-contained,
   but they were produced by tools/gendata.py with a fixed seed, which
   is why the data is reproducible and why the numbers below are stable.

   Volumes follow the assignment: 10 rows in every dimension table, and
   20-50 rows in each transactional table.

   Window: 2026-09-26 to 2026-10-25 (30 days), which
   spans two calendar months so the monthly procedure has more than one
   row to return.

   DimGeography 10, DimPlan 10, DimProduct 10, DimCampaign 10,
   DimUser 10, DimAccount 10, FactUserEvent 48,
   FactPayment 30, FactSubscription 23.

   No deletes are needed here: section 2 drops every table and section
   3 rebuilds them, so this section always loads into empty tables.
   Inserts run parent-first, because a foreign key is checked per row.
   ====================================================================== */

/* ---- DimGeography: every place, and how risky it is ---------------- */
INSERT INTO dbo.DimGeography
    (GeoID, CountryCode, CountryName, Region, City,
     Latitude, Longitude, RiskTier)
VALUES
  (1,'US','United States','North America','Phoenix',33.448377,-112.074037,'Low'),
  (2,'US','United States','North America','Seattle',47.606209,-122.332071,'Low'),
  (3,'CA','Canada','North America','Toronto',43.653226,-79.383184,'Low'),
  (4,'GB','United Kingdom','EMEA','London',51.507351,-0.127758,'Low'),
  (5,'DE','Germany','EMEA','Berlin',52.520007,13.404954,'Low'),
  (6,'BR','Brazil','LATAM','Sao Paulo',-23.55052,-46.633309,'Medium'),
  (7,'IN','India','APAC','Mumbai',19.075984,72.877656,'Medium'),
  (8,'PH','Philippines','APAC','Manila',14.599512,120.984219,'Medium'),
  (9,'NG','Nigeria','EMEA','Lagos',6.524379,3.379206,'High'),
  (10,'RU','Russia','EMEA','Moscow',55.755826,37.6173,'High');
GO

/* ---- DimPlan: the audited lookup table ----------------------------- */
INSERT INTO dbo.DimPlan
    (PlanID, PlanName, PriceUSD, BillingPeriod, IsPaid,
     TrialDays, AdsEnabled, EffectiveDate)
VALUES
  (1,'Free',0.00,'None',0,0,1,'2026-01-01'),
  (2,'Plus Monthly',4.99,'Monthly',1,7,0,'2026-01-01'),
  (3,'Plus Annual',49.99,'Annual',1,14,0,'2026-01-01'),
  (4,'Premium Monthly',9.99,'Monthly',1,7,0,'2026-01-01'),
  (5,'Premium Annual',99.99,'Annual',1,14,0,'2026-01-01'),
  (6,'Student Monthly',2.99,'Monthly',1,30,0,'2026-02-01'),
  (7,'Family Monthly',14.99,'Monthly',1,14,0,'2026-03-01'),
  (8,'Founders Annual',19.99,'Annual',1,0,0,'2026-01-01'),
  (9,'Trial',0.00,'None',0,14,1,'2026-01-01'),
  (10,'Legacy Basic',2.99,'Monthly',1,0,1,'2025-06-01');
GO

/* ---- DimProduct: the store catalog --------------------------------- */
INSERT INTO dbo.DimProduct
    (ProductID, ProductName, ProductCategory, ListPriceUSD,
     IsActive, ReleaseDate)
VALUES
  (1,'Small Gem Pack','Currency',1.99,1,'2026-01-15'),
  (2,'Medium Gem Pack','Currency',4.99,1,'2026-01-15'),
  (3,'Large Gem Pack','Currency',19.99,1,'2026-01-15'),
  (4,'Starter Bundle','Currency',9.99,1,'2026-02-01'),
  (5,'Shadow Skin','Cosmetic',3.99,1,'2026-03-10'),
  (6,'Dragon Armor','Cosmetic',7.99,1,'2026-04-01'),
  (7,'Emote Pack','Cosmetic',2.99,0,'2026-02-20'),
  (8,'Season 1 Battle Pass','BattlePass',9.99,0,'2026-05-01'),
  (9,'Season 2 Battle Pass','BattlePass',9.99,1,'2026-08-01'),
  (10,'Premium Upgrade','Subscription',9.99,1,'2026-01-15');
GO

/* ---- DimCampaign: what marketing ran, and what it cost ------------- */
INSERT INTO dbo.DimCampaign
    (CampaignID, CampaignName, Channel, CostModel,
     StartDate, EndDate, BudgetUSD)
VALUES
  (1,'Launch Search US','Paid Search','CPC','2026-07-01',NULL,25000.00),
  (2,'Launch Search EU','Paid Search','CPC','2026-07-01','2026-09-30',15000.00),
  (3,'Summer Social Push','Social','CPM','2026-07-15','2026-09-15',18000.00),
  (4,'Influencer Wave 1','Influencer','CPI','2026-08-01','2026-09-30',30000.00),
  (5,'Influencer Wave 2','Influencer','CPI','2026-09-15',NULL,22000.00),
  (6,'Email Winback Q3','Email','CPC','2026-08-15',NULL,5000.00),
  (7,'Retargeting APAC','Social','CPM','2026-08-01',NULL,12000.00),
  (8,'Video Preroll','Social','CPM','2026-07-20','2026-10-01',20000.00),
  (9,'App Store Feature','Paid Search','CPI','2026-09-01',NULL,8000.00),
  (10,'Referral Boost','Email','CPC','2026-10-01',NULL,3000.00);
GO

/* ---- DimUser: the customer profile every report slices on ---------- */
INSERT INTO dbo.DimUser
    (UserID, Username, Email, SignupDate, RegisteredGeoID,
     LastSeenGeoID, LastSeenAt, AgeBand, PreferredDevice,
     LifecycleStage, AcqCampaignID, AcqCostUSD)
VALUES
  (1,'player001','player001@example.com','2026-03-12',
   1,1,'2026-10-20 22:37:13','25-34',
   'PC','Active',1,6.40),
  (2,'player002','player002@example.com','2026-05-04',
   2,2,'2026-10-12 11:39:09','18-24',
   'iOS','Active',3,2.15),
  (3,'player003','player003@example.com','2026-06-18',
   3,3,'2026-09-29 17:29:55','35-49',
   'Console','AtRisk',NULL,NULL),
  (4,'player004','player004@example.com','2026-07-02',
   4,4,'2026-10-05 14:17:31','25-34',
   'Android','AtRisk',2,4.80),
  (5,'player005','player005@example.com','2026-08-11',
   5,4,'2026-10-12 07:58:31','50+',
   'PC','Active',8,3.25),
  (6,'player006','player006@example.com','2026-09-01',
   6,6,'2026-10-09 20:35:15','18-24',
   'Android','AtRisk',4,11.90),
  (7,'player007','player007@example.com','2026-09-20',
   7,7,'2026-10-12 12:46:30','13-17',
   'iOS','Active',7,1.35),
  (8,'player008','player008@example.com','2026-10-02',
   8,8,'2026-10-17 20:42:17','18-24',
   'Android','Active',5,9.60),
  (9,'player009','player009@example.com','2026-10-08',
   9,9,'2026-10-23 08:52:55','25-34',
   'iOS','New',9,14.20),
  (10,'player010','player010@example.com','2026-10-14',
   10,NULL,NULL,'35-49',
   'PC','New',10,2.75);
GO

/* ---- DimAccount: the billing entity -------------------------------- */
INSERT INTO dbo.DimAccount
    (AccountID, UserID, AccountNumber, PlanID, AccountStatus,
     OpenedDate, ClosedDate, IsAutoRenew, BillingGeoID)
VALUES
  (1,1,'ACC-00001',4,'Active','2026-03-14',NULL,1,1),
  (2,1,'ACC-00002',2,'Cancelled','2025-11-01','2026-03-10',0,1),
  (3,2,'ACC-00003',1,'Active','2026-05-05',NULL,0,2),
  (4,3,'ACC-00004',5,'Active','2026-06-20',NULL,1,3),
  (5,4,'ACC-00005',1,'Active','2026-07-03',NULL,0,4),
  (6,5,'ACC-00006',2,'Active','2026-08-12',NULL,1,5),
  (7,6,'ACC-00007',2,'Active','2026-09-02',NULL,1,6),
  (8,7,'ACC-00008',6,'PastDue','2026-09-21',NULL,1,7),
  (9,8,'ACC-00009',1,'Active','2026-10-03',NULL,0,8),
  (10,9,'ACC-00010',5,'Active','2026-10-09',NULL,1,9);
GO

/* ---- FactUserEvent: sessions and in-game actions, one stream ------- */
INSERT INTO dbo.FactUserEvent
    (UserID, SessionID, GeoID, EventType, EventTS,
     LevelNumber, Outcome, DeviceType, SourceSystem)
VALUES
  (1,1,1,'SessionStart','2026-09-27 14:50:38',NULL,NULL,'iOS','MobileSDK'),
  (1,1,1,'LevelComplete','2026-09-27 14:59:43',1,'Win','iOS','MobileSDK'),
  (1,1,1,'LevelComplete','2026-09-27 15:10:08',2,'Win','iOS','MobileSDK'),
  (1,1,1,'SessionEnd','2026-09-27 15:17:18',NULL,NULL,'iOS','MobileSDK'),
  (3,2,3,'SessionStart','2026-09-29 16:54:47',NULL,NULL,'Console','MobileSDK'),
  (3,2,3,'LevelComplete','2026-09-29 17:09:05',1,'Win','Console','MobileSDK'),
  (3,2,3,'LevelComplete','2026-09-29 17:23:54',3,'Win','Console','MobileSDK'),
  (3,2,3,'SessionEnd','2026-09-29 17:29:55',NULL,NULL,'Console','MobileSDK'),
  (2,3,2,'SessionStart','2026-10-02 12:26:56',NULL,NULL,'iOS','GameClient'),
  (2,3,2,'LevelFail','2026-10-02 12:29:57',2,'Loss','iOS','GameClient'),
  (2,3,2,'ItemUsed','2026-10-02 12:36:43',2,NULL,'iOS','GameClient'),
  (2,3,2,'SessionEnd','2026-10-02 12:41:56',NULL,NULL,'iOS','GameClient'),
  (1,4,1,'SessionStart','2026-10-05 07:11:28',NULL,NULL,'PC','MobileSDK'),
  (1,4,1,'LevelComplete','2026-10-05 07:14:06',3,'Win','PC','MobileSDK'),
  (1,4,1,'LevelComplete','2026-10-05 07:29:04',4,'Win','PC','MobileSDK'),
  (1,4,1,'SessionEnd','2026-10-05 07:38:56',NULL,NULL,'PC','MobileSDK'),
  (4,5,4,'SessionStart','2026-10-05 13:49:24',NULL,NULL,'Android','GameClient'),
  (4,5,4,'LevelComplete','2026-10-05 13:56:36',1,'Win','Android','GameClient'),
  (4,5,4,'LevelFail','2026-10-05 14:08:44',4,'Loss','Android','GameClient'),
  (4,5,4,'SessionEnd','2026-10-05 14:17:31',NULL,NULL,'Android','GameClient'),
  (6,6,6,'SessionStart','2026-10-09 20:16:37',NULL,NULL,'PC','GameClient'),
  (6,6,6,'LevelFail','2026-10-09 20:28:30',5,'Loss','PC','GameClient'),
  (6,6,6,'AdWatched','2026-10-09 20:31:32',NULL,NULL,'PC','GameClient'),
  (6,6,6,'SessionEnd','2026-10-09 20:35:15',NULL,NULL,'PC','GameClient'),
  (2,7,2,'SessionStart','2026-10-12 11:10:50',NULL,NULL,'iOS','GameClient'),
  (2,7,2,'LevelComplete','2026-10-12 11:23:41',2,'Win','iOS','GameClient'),
  (2,7,2,'LevelFail','2026-10-12 11:34:24',5,'Loss','iOS','GameClient'),
  (2,7,2,'SessionEnd','2026-10-12 11:39:09',NULL,NULL,'iOS','GameClient'),
  (5,8,4,'SessionStart','2026-10-12 07:28:36',NULL,NULL,'PC','WebClient'),
  (5,8,4,'LevelComplete','2026-10-12 07:42:47',4,'Win','PC','WebClient'),
  (5,8,4,'LevelComplete','2026-10-12 07:56:12',5,'Win','PC','WebClient'),
  (5,8,4,'SessionEnd','2026-10-12 07:58:31',NULL,NULL,'PC','WebClient'),
  (7,9,7,'SessionStart','2026-10-12 12:20:39',NULL,NULL,'iOS','GameClient'),
  (7,9,7,'LevelFail','2026-10-12 12:35:02',3,'Abandon','iOS','GameClient'),
  (7,9,7,'LevelFail','2026-10-12 12:39:13',5,'Loss','iOS','GameClient'),
  (7,9,7,'SessionEnd','2026-10-12 12:46:30',NULL,NULL,'iOS','GameClient'),
  (8,10,8,'SessionStart','2026-10-17 20:27:32',NULL,NULL,'Android','WebClient'),
  (8,10,8,'LevelComplete','2026-10-17 20:32:52',1,'Win','Android','WebClient'),
  (8,10,8,'LevelComplete','2026-10-17 20:34:57',6,'Win','Android','WebClient'),
  (8,10,8,'SessionEnd','2026-10-17 20:42:17',NULL,NULL,'Android','WebClient'),
  (1,11,1,'SessionStart','2026-10-20 22:22:51',NULL,NULL,'PC','GameClient'),
  (1,11,1,'LevelFail','2026-10-20 22:33:59',4,'Loss','PC','GameClient'),
  (1,11,1,'ItemUsed','2026-10-20 22:36:11',4,NULL,'PC','GameClient'),
  (1,11,1,'SessionEnd','2026-10-20 22:37:13',NULL,NULL,'PC','GameClient'),
  (9,12,9,'SessionStart','2026-10-23 08:24:52',NULL,NULL,'iOS','GameClient'),
  (9,12,9,'LevelFail','2026-10-23 08:35:10',6,'Abandon','iOS','GameClient'),
  (9,12,9,'AdWatched','2026-10-23 08:50:08',NULL,NULL,'iOS','GameClient'),
  (9,12,9,'SessionEnd','2026-10-23 08:52:55',NULL,NULL,'iOS','GameClient');
GO

/* ---- FactPayment: sales, subscription charges and refunds ---------- */
INSERT INTO dbo.FactPayment
    (AccountID, ProductID, CampaignID, GeoID, PaymentTS,
     AmountUSD, PaymentType, PaymentMethod, IsFlagged, SourceSystem)
VALUES
  (6,2,8,5,'2026-09-27 16:01',4.99,'OneTime','AppStore',0,'PlayStore'),
  (1,2,1,1,'2026-09-28 09:17',4.99,'OneTime','GooglePlay',0,'PlayStore'),
  (4,3,NULL,10,'2026-09-29 18:24',89.99,'OneTime','Card',0,'BillingAPI'),
  (4,3,NULL,3,'2026-09-29 23:28',19.99,'OneTime','Card',0,'PlayStore'),
  (3,1,3,2,'2026-10-02 15:16',1.99,'OneTime','GooglePlay',0,'AppStore'),
  (5,1,2,4,'2026-10-05 08:19',1.99,'OneTime','GooglePlay',0,'PlayStore'),
  (1,5,1,1,'2026-10-06 11:38',3.99,'OneTime','Card',0,'BillingAPI'),
  (4,6,NULL,3,'2026-10-08 09:38',7.99,'OneTime','Card',0,'PlayStore'),
  (7,4,4,6,'2026-10-09 08:09',9.99,'OneTime','Card',0,'PlayStore'),
  (1,5,1,1,'2026-10-09 14:39',3.99,'Refund','PayPal',0,'BillingAPI'),
  (10,NULL,9,9,'2026-10-09 15:49',99.99,'Subscription','GooglePlay',0,'BillingAPI'),
  (8,1,7,7,'2026-10-12 10:39',1.99,'OneTime','GooglePlay',0,'BillingAPI'),
  (3,4,3,2,'2026-10-12 12:02',6.99,'OneTime','Card',0,'BillingAPI'),
  (6,NULL,8,5,'2026-10-12 13:01',4.99,'Subscription','Card',0,'BillingAPI'),
  (6,9,8,5,'2026-10-12 19:50',9.99,'OneTime','PayPal',0,'BillingAPI'),
  (7,4,4,6,'2026-10-13 17:52',9.99,'Refund','Card',0,'BillingAPI'),
  (1,NULL,1,1,'2026-10-14 18:43',9.99,'Subscription','AppStore',0,'BillingAPI'),
  (5,5,2,4,'2026-10-15 16:15',3.99,'OneTime','GooglePlay',0,'AppStore'),
  (7,NULL,4,6,'2026-10-16 04:27',4.99,'Subscription','AppStore',0,'BillingAPI'),
  (9,3,5,8,'2026-10-17 09:05',19.99,'OneTime','AppStore',0,'PlayStore'),
  (9,9,NULL,9,'2026-10-17 21:52',119.99,'OneTime','PayPal',0,'BillingAPI'),
  (7,5,4,6,'2026-10-18 11:44',3.99,'OneTime','GooglePlay',0,'PlayStore'),
  (3,2,3,2,'2026-10-19 20:59',4.99,'OneTime','GooglePlay',0,'BillingAPI'),
  (8,2,7,7,'2026-10-20 18:37',4.99,'OneTime','Card',0,'AppStore'),
  (1,3,NULL,9,'2026-10-20 23:17',149.99,'OneTime','Card',0,'BillingAPI'),
  (8,NULL,7,7,'2026-10-21 06:31',2.99,'Subscription','Card',0,'BillingAPI'),
  (1,9,1,1,'2026-10-21 18:47',9.99,'OneTime','PayPal',0,'AppStore'),
  (6,1,8,5,'2026-10-22 21:42',1.99,'OneTime','AppStore',0,'BillingAPI'),
  (10,9,9,9,'2026-10-23 12:39',9.99,'OneTime','AppStore',0,'AppStore'),
  (9,6,5,8,'2026-10-23 19:40',7.99,'OneTime','PayPal',0,'BillingAPI');
GO

/* ---- FactSubscription: the lifecycle, including the free moves ----- */
INSERT INTO dbo.FactSubscription
    (AccountID, PlanID, PrevPlanID, EventType, EventDate,
     MRRDeltaUSD, TermMonths, CancelReason, SourceSystem)
VALUES
  (2,2,NULL,'Start','2025-11-01',4.99,1,NULL,'AppStore'),
  (2,2,NULL,'Cancel','2026-03-10',-4.99,NULL,'Too expensive','BillingAPI'),
  (1,4,NULL,'Start','2026-03-14',9.99,1,NULL,'PlayStore'),
  (1,4,NULL,'Renew','2026-04-14',0.00,1,NULL,'PlayStore'),
  (3,1,NULL,'Start','2026-05-05',0.00,NULL,NULL,'AppStore'),
  (1,4,NULL,'Renew','2026-05-14',0.00,1,NULL,'BillingAPI'),
  (1,4,NULL,'Renew','2026-06-14',0.00,1,NULL,'BillingAPI'),
  (4,3,NULL,'Start','2026-06-20',4.17,12,NULL,'BillingAPI'),
  (5,1,NULL,'Start','2026-07-03',0.00,NULL,NULL,'AppStore'),
  (1,4,NULL,'Renew','2026-07-14',0.00,1,NULL,'AppStore'),
  (6,7,NULL,'Start','2026-08-12',14.99,1,NULL,'BillingAPI'),
  (1,4,NULL,'Renew','2026-08-14',0.00,1,NULL,'PlayStore'),
  (4,5,3,'Upgrade','2026-08-20',4.17,12,NULL,'PlayStore'),
  (7,9,NULL,'Start','2026-09-02',0.00,NULL,NULL,'AppStore'),
  (6,7,NULL,'Renew','2026-09-12',0.00,1,NULL,'AppStore'),
  (1,4,NULL,'Renew','2026-09-14',0.00,1,NULL,'PlayStore'),
  (8,6,NULL,'Start','2026-09-21',2.99,1,NULL,'AppStore'),
  (9,1,NULL,'Start','2026-10-03',0.00,NULL,NULL,'BillingAPI'),
  (10,5,NULL,'Start','2026-10-09',8.33,12,NULL,'PlayStore'),
  (6,2,7,'Downgrade','2026-10-12',-10.00,1,NULL,'BillingAPI'),
  (1,4,NULL,'Renew','2026-10-14',0.00,1,NULL,'BillingAPI'),
  (7,2,9,'Upgrade','2026-10-16',4.99,1,NULL,'PlayStore'),
  (8,6,NULL,'Renew','2026-10-21',0.00,1,NULL,'AppStore');
GO

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
   minutes after they were last seen" is not something a traveler can
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

/* ======================================================================
   SECTION 8: A CURSOR

   What it does: walks the ten levels in play order and prints a
   difficulty line for each one, comparing the difficulty the designers
   assigned against the failure rate the event data actually shows, and
   flagging any level players lose more often than they win.

   Why a cursor is defensible here, when set-based SQL is almost always
   the right answer: the output is a printed report, one PRINT per level
   with running commentary, and PRINT is not something a set-based
   statement can do per row. A result set would be the better choice for
   anything a program consumes; this is for a person reading a log.

   On "create and drop script for cursor": a cursor has no CREATE or
   DROP in T-SQL. It is DECLARE ... CURSOR and DEALLOCATE. Declaring it
   GLOBAL makes those two genuinely separate statements against a named
   object that outlives its batch, which is as close to create and drop
   as a cursor gets, and it means the DEALLOCATE below is a real drop
   rather than a formality.
   ====================================================================== */

/* If a previous run failed between OPEN and DEALLOCATE the name is
   still taken, and DECLARE would fail with "a cursor with the name
   already exists". This clears it first, which is what keeps section 8
   re-runnable. */
IF CURSOR_STATUS('global', 'curLevelDifficulty') >= -1
BEGIN
    CLOSE curLevelDifficulty;
    DEALLOCATE curLevelDifficulty;
END;
GO

/* ---- create the cursor -------------------------------------------- */
DECLARE curLevelDifficulty CURSOR GLOBAL
FOR
    SELECT  e.LevelNumber,
            COUNT(*) AS Attempts,
            SUM(CASE WHEN e.Outcome = 'Win'  THEN 1 ELSE 0 END) AS Wins,
            SUM(CASE WHEN e.Outcome = 'Loss' THEN 1 ELSE 0 END) AS Losses,
            SUM(CASE WHEN e.Outcome = 'Abandon'
                     THEN 1 ELSE 0 END) AS Abandons
      FROM  dbo.FactUserEvent AS e
     WHERE  e.LevelNumber IS NOT NULL
       AND  e.Outcome     IS NOT NULL
     GROUP BY e.LevelNumber
     ORDER BY e.LevelNumber;

OPEN curLevelDifficulty;

DECLARE @Level    INT,
        @Attempts INT,
        @Wins     INT,
        @Losses   INT,
        @Abandons INT,
        @WinPct   DECIMAL(5,2),
        @Line     VARCHAR(200),
        @Flagged  INT = 0;

PRINT '== Level difficulty report';
PRINT 'Level  Attempts   Wins  Losses  Aband   Win%  Verdict';
PRINT '-----  --------  -----  ------  -----  -----  -------';

FETCH NEXT FROM curLevelDifficulty
 INTO @Level, @Attempts, @Wins, @Losses, @Abandons;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @WinPct = CAST(100.0 * @Wins / NULLIF(@Attempts, 0)
                       AS DECIMAL(5,2));

    SET @Line =
        RIGHT(SPACE(12) + CAST(@Level    AS VARCHAR(12)),  5) +
        RIGHT(SPACE(12) + CAST(@Attempts AS VARCHAR(12)), 10) +
        RIGHT(SPACE(12) + CAST(@Wins     AS VARCHAR(12)),  7) +
        RIGHT(SPACE(12) + CAST(@Losses   AS VARCHAR(12)),  8) +
        RIGHT(SPACE(12) + CAST(@Abandons AS VARCHAR(12)),  7) +
        RIGHT(SPACE(12) + CAST(@WinPct   AS VARCHAR(12)),  7) +
        '  ' +
        CASE WHEN @WinPct < 50.0 THEN 'CHURN RISK - lost more than won'
             WHEN @WinPct < 60.0 THEN 'hard'
             ELSE                     'ok' END;

    PRINT @Line;

    IF @WinPct < 50.0
        SET @Flagged = @Flagged + 1;

    FETCH NEXT FROM curLevelDifficulty
     INTO @Level, @Attempts, @Wins, @Losses, @Abandons;
END;

PRINT '-----  --------  -----  ------  -----  -----  -------';
PRINT 'Levels flagged as churn risks: ' + CAST(@Flagged AS VARCHAR(5));

/* ---- drop the cursor ----------------------------------------------- */
CLOSE curLevelDifficulty;
DEALLOCATE curLevelDifficulty;
GO

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
