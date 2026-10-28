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
