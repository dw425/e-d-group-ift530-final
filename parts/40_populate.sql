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

