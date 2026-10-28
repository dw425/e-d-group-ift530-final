# Data dictionary — `E_D_Group`

Generated from the live database by `tools/dbdoc.py`, reading `sys.tables`, `sys.columns` and the constraint catalog views. It describes what SQL Server actually built, not what the script says it should have.

## Objects

| Object | Count |
|---|---|
| Tables | 10 |
| Views | 3 |
| Primary keys | 10 |
| Unique constraints | 3 |
| Foreign keys | 15 |
| Check constraints | 32 |
| Default constraints | 7 |
| Nonclustered indexes | 6 |
| Stored procedures | 1 |
| Scalar functions | 1 |
| Triggers | 1 |


## Row counts

| Table | Rows |
|---|---|
| DimAccount | 10 |
| DimCampaign | 10 |
| DimGeography | 10 |
| DimPlan | 10 |
| DimPlanAudit | 3 |
| DimProduct | 10 |
| DimUser | 10 |
| FactPayment | 30 |
| FactSubscription | 23 |
| FactUserEvent | 48 |


## Tables


### `DimAccount`

| Column | Type | Size | Null | Identity | Default |
|---|---|---|---|---|---|
| AccountID | int | 4 | NOT NULL |  |  |
| UserID | int | 4 | NOT NULL |  |  |
| AccountNumber | varchar | 20 | NOT NULL |  |  |
| PlanID | int | 4 | NOT NULL |  |  |
| AccountStatus | varchar | 12 | NOT NULL |  |  |
| OpenedDate | date | 3 | NOT NULL |  |  |
| ClosedDate | date | 3 | NULL |  |  |
| IsAutoRenew | bit | 1 | NOT NULL |  | ((1)) |
| BillingGeoID | int | 4 | NOT NULL |  |  |


**Constraints**

| Kind | Name | Column | References / rule |
|---|---|---|---|
| CHECK | CK_Account_Dates |  | ([ClosedDate] IS NULL OR [ClosedDate]>=[OpenedDate]) |
| CHECK | CK_Account_Status |  | ([AccountStatus]='Suspended' OR [AccountStatus]='Cancelled' OR [AccountStatus]='PastDue' OR [AccountStatus]='Active' OR [AccountStatus]='Trial') |
| FK | FK_Account_BillGeo | BillingGeoID | DimGeography.GeoID |
| FK | FK_Account_Plan | PlanID | DimPlan.PlanID |
| FK | FK_Account_User | UserID | DimUser.UserID |
| PK | PK_Account | AccountID |  |
| PK | UQ_Account_Number | AccountNumber |  |


### `DimCampaign`

| Column | Type | Size | Null | Identity | Default |
|---|---|---|---|---|---|
| CampaignID | int | 4 | NOT NULL |  |  |
| CampaignName | varchar | 60 | NOT NULL |  |  |
| Channel | varchar | 30 | NOT NULL |  |  |
| CostModel | varchar | 10 | NOT NULL |  |  |
| StartDate | date | 3 | NOT NULL |  |  |
| EndDate | date | 3 | NULL |  |  |
| BudgetUSD | decimal | 10,2 | NOT NULL |  |  |


**Constraints**

| Kind | Name | Column | References / rule |
|---|---|---|---|
| CHECK | CK_Campaign_Budget |  | ([BudgetUSD]>=(0)) |
| CHECK | CK_Campaign_Channel |  | ([Channel]='Organic' OR [Channel]='Email' OR [Channel]='Influencer' OR [Channel]='Social' OR [Channel]='Paid Search') |
| CHECK | CK_Campaign_CostModel |  | ([CostModel]='CPI' OR [CostModel]='CPM' OR [CostModel]='CPC') |
| CHECK | CK_Campaign_Dates |  | ([EndDate] IS NULL OR [EndDate]>=[StartDate]) |
| PK | PK_Campaign | CampaignID |  |


### `DimGeography`

| Column | Type | Size | Null | Identity | Default |
|---|---|---|---|---|---|
| GeoID | int | 4 | NOT NULL |  |  |
| CountryCode | char | 2 | NOT NULL |  |  |
| CountryName | varchar | 60 | NOT NULL |  |  |
| Region | varchar | 40 | NOT NULL |  |  |
| City | varchar | 60 | NOT NULL |  |  |
| Latitude | decimal | 9,6 | NOT NULL |  |  |
| Longitude | decimal | 9,6 | NOT NULL |  |  |
| RiskTier | varchar | 10 | NOT NULL |  |  |


**Constraints**

| Kind | Name | Column | References / rule |
|---|---|---|---|
| CHECK | CK_Geo_Latitude |  | ([Latitude]>=(-90) AND [Latitude]<=(90)) |
| CHECK | CK_Geo_Longitude |  | ([Longitude]>=(-180) AND [Longitude]<=(180)) |
| CHECK | CK_Geo_Region |  | ([Region]='LATAM' OR [Region]='APAC' OR [Region]='EMEA' OR [Region]='North America') |
| CHECK | CK_Geo_RiskTier |  | ([RiskTier]='High' OR [RiskTier]='Medium' OR [RiskTier]='Low') |
| PK | PK_Geography | GeoID |  |


### `DimPlan`

| Column | Type | Size | Null | Identity | Default |
|---|---|---|---|---|---|
| PlanID | int | 4 | NOT NULL |  |  |
| PlanName | varchar | 30 | NOT NULL |  |  |
| PriceUSD | decimal | 6,2 | NOT NULL |  |  |
| BillingPeriod | varchar | 10 | NOT NULL |  |  |
| IsPaid | bit | 1 | NOT NULL |  | ((0)) |
| TrialDays | int | 4 | NOT NULL |  |  |
| AdsEnabled | bit | 1 | NOT NULL |  | ((1)) |
| EffectiveDate | date | 3 | NOT NULL |  |  |


**Constraints**

| Kind | Name | Column | References / rule |
|---|---|---|---|
| CHECK | CK_Plan_Period |  | ([BillingPeriod]='None' OR [BillingPeriod]='Annual' OR [BillingPeriod]='Monthly') |
| CHECK | CK_Plan_Price |  | ([PriceUSD]>=(0)) |
| CHECK | CK_Plan_Trial |  | ([TrialDays]>=(0)) |
| PK | PK_Plan | PlanID |  |
| PK | UQ_Plan_Name | PlanName |  |


### `DimPlanAudit`

| Column | Type | Size | Null | Identity | Default |
|---|---|---|---|---|---|
| AuditID | int | 4 | NOT NULL | IDENTITY |  |
| PlanID | int | 4 | NOT NULL |  |  |
| ChangeType | varchar | 6 | NOT NULL |  |  |
| OldPlanName | varchar | 30 | NULL |  |  |
| NewPlanName | varchar | 30 | NULL |  |  |
| OldPriceUSD | decimal | 6,2 | NULL |  |  |
| NewPriceUSD | decimal | 6,2 | NULL |  |  |
| OldIsPaid | bit | 1 | NULL |  |  |
| NewIsPaid | bit | 1 | NULL |  |  |
| ChangedBy | varchar | 128 | NOT NULL |  | (suser_sname()) |
| ChangedAt | datetime2 | 8 | NOT NULL |  | (sysdatetime()) |


**Constraints**

| Kind | Name | Column | References / rule |
|---|---|---|---|
| CHECK | CK_Audit_ChangeType |  | ([ChangeType]='DELETE' OR [ChangeType]='UPDATE' OR [ChangeType]='INSERT') |
| PK | PK_PlanAudit | AuditID |  |


### `DimProduct`

| Column | Type | Size | Null | Identity | Default |
|---|---|---|---|---|---|
| ProductID | int | 4 | NOT NULL |  |  |
| ProductName | varchar | 60 | NOT NULL |  |  |
| ProductCategory | varchar | 20 | NOT NULL |  |  |
| ListPriceUSD | decimal | 6,2 | NOT NULL |  |  |
| IsActive | bit | 1 | NOT NULL |  | ((1)) |
| ReleaseDate | date | 3 | NOT NULL |  |  |


**Constraints**

| Kind | Name | Column | References / rule |
|---|---|---|---|
| CHECK | CK_Product_Category |  | ([ProductCategory]='Subscription' OR [ProductCategory]='BattlePass' OR [ProductCategory]='Cosmetic' OR [ProductCategory]='Currency') |
| CHECK | CK_Product_Price |  | ([ListPriceUSD]>(0)) |
| PK | PK_Product | ProductID |  |


### `DimUser`

| Column | Type | Size | Null | Identity | Default |
|---|---|---|---|---|---|
| UserID | int | 4 | NOT NULL |  |  |
| Username | varchar | 30 | NOT NULL |  |  |
| Email | varchar | 100 | NOT NULL |  |  |
| SignupDate | date | 3 | NOT NULL |  |  |
| RegisteredGeoID | int | 4 | NOT NULL |  |  |
| LastSeenGeoID | int | 4 | NULL |  |  |
| LastSeenAt | datetime2 | 8 | NULL |  |  |
| AgeBand | varchar | 10 | NOT NULL |  |  |
| PreferredDevice | varchar | 20 | NOT NULL |  |  |
| LifecycleStage | varchar | 12 | NOT NULL |  |  |
| AcqCampaignID | int | 4 | NULL |  |  |
| AcqCostUSD | decimal | 8,2 | NULL |  |  |


**Constraints**

| Kind | Name | Column | References / rule |
|---|---|---|---|
| CHECK | CK_User_AcqCost |  | ([AcqCostUSD]>=(0)) |
| CHECK | CK_User_AgeBand |  | ([AgeBand]='50+' OR [AgeBand]='35-49' OR [AgeBand]='25-34' OR [AgeBand]='18-24' OR [AgeBand]='13-17') |
| CHECK | CK_User_Device |  | ([PreferredDevice]='Console' OR [PreferredDevice]='PC' OR [PreferredDevice]='Android' OR [PreferredDevice]='iOS') |
| CHECK | CK_User_Lifecycle |  | ([LifecycleStage]='Banned' OR [LifecycleStage]='Churned' OR [LifecycleStage]='AtRisk' OR [LifecycleStage]='Active' OR [LifecycleStage]='New') |
| FK | FK_User_Campaign | AcqCampaignID | DimCampaign.CampaignID |
| FK | FK_User_LastGeo | LastSeenGeoID | DimGeography.GeoID |
| FK | FK_User_RegGeo | RegisteredGeoID | DimGeography.GeoID |
| PK | PK_User | UserID |  |
| PK | UQ_User_Username | Username |  |


**Indexes**

| Index | Columns |
|---|---|
| IX_User_Lifecyc | LifecycleStage |


### `FactPayment`

| Column | Type | Size | Null | Identity | Default |
|---|---|---|---|---|---|
| PaymentID | int | 4 | NOT NULL | IDENTITY |  |
| AccountID | int | 4 | NOT NULL |  |  |
| ProductID | int | 4 | NULL |  |  |
| CampaignID | int | 4 | NULL |  |  |
| GeoID | int | 4 | NOT NULL |  |  |
| PaymentTS | datetime2 | 8 | NOT NULL |  |  |
| AmountUSD | decimal | 8,2 | NOT NULL |  |  |
| PaymentType | varchar | 12 | NOT NULL |  |  |
| PaymentMethod | varchar | 20 | NOT NULL |  |  |
| IsFlagged | bit | 1 | NOT NULL |  | ((0)) |
| SourceSystem | varchar | 30 | NOT NULL |  |  |


**Constraints**

| Kind | Name | Column | References / rule |
|---|---|---|---|
| CHECK | CK_Payment_Amount |  | ([AmountUSD]>(0)) |
| CHECK | CK_Payment_Method |  | ([PaymentMethod]='GooglePlay' OR [PaymentMethod]='AppStore' OR [PaymentMethod]='PayPal' OR [PaymentMethod]='Card') |
| CHECK | CK_Payment_Source |  | ([SourceSystem]='PlayStore' OR [SourceSystem]='AppStore' OR [SourceSystem]='BillingAPI') |
| CHECK | CK_Payment_Type |  | ([PaymentType]='Refund' OR [PaymentType]='Subscription' OR [PaymentType]='OneTime') |
| FK | FK_Payment_Account | AccountID | DimAccount.AccountID |
| FK | FK_Payment_Campaign | CampaignID | DimCampaign.CampaignID |
| FK | FK_Payment_Geo | GeoID | DimGeography.GeoID |
| FK | FK_Payment_Product | ProductID | DimProduct.ProductID |
| PK | PK_Payment | PaymentID |  |


**Indexes**

| Index | Columns |
|---|---|
| IX_Payment_TS | PaymentTS |
| IX_Payment_Acct | AccountID |


### `FactSubscription`

| Column | Type | Size | Null | Identity | Default |
|---|---|---|---|---|---|
| SubEventID | int | 4 | NOT NULL | IDENTITY |  |
| AccountID | int | 4 | NOT NULL |  |  |
| PlanID | int | 4 | NOT NULL |  |  |
| PrevPlanID | int | 4 | NULL |  |  |
| EventType | varchar | 12 | NOT NULL |  |  |
| EventDate | date | 3 | NOT NULL |  |  |
| MRRDeltaUSD | decimal | 8,2 | NOT NULL |  |  |
| TermMonths | int | 4 | NULL |  |  |
| CancelReason | varchar | 40 | NULL |  |  |
| SourceSystem | varchar | 30 | NOT NULL |  |  |


**Constraints**

| Kind | Name | Column | References / rule |
|---|---|---|---|
| CHECK | CK_Sub_EventType |  | ([EventType]='Expire' OR [EventType]='Cancel' OR [EventType]='Downgrade' OR [EventType]='Upgrade' OR [EventType]='Renew' OR [EventType]='Start') |
| CHECK | CK_Sub_Source |  | ([SourceSystem]='PlayStore' OR [SourceSystem]='AppStore' OR [SourceSystem]='BillingAPI') |
| CHECK | CK_Sub_Term |  | ([TermMonths]>(0)) |
| FK | FK_Sub_Account | AccountID | DimAccount.AccountID |
| FK | FK_Sub_Plan | PlanID | DimPlan.PlanID |
| FK | FK_Sub_PrevPlan | PrevPlanID | DimPlan.PlanID |
| PK | PK_Subscription | SubEventID |  |


**Indexes**

| Index | Columns |
|---|---|
| IX_Sub_Account | AccountID |


### `FactUserEvent`

| Column | Type | Size | Null | Identity | Default |
|---|---|---|---|---|---|
| EventID | int | 4 | NOT NULL | IDENTITY |  |
| UserID | int | 4 | NOT NULL |  |  |
| SessionID | int | 4 | NOT NULL |  |  |
| GeoID | int | 4 | NOT NULL |  |  |
| EventType | varchar | 20 | NOT NULL |  |  |
| EventTS | datetime2 | 8 | NOT NULL |  |  |
| LevelNumber | int | 4 | NULL |  |  |
| Outcome | varchar | 10 | NULL |  |  |
| DeviceType | varchar | 20 | NOT NULL |  |  |
| SourceSystem | varchar | 30 | NOT NULL |  |  |


**Constraints**

| Kind | Name | Column | References / rule |
|---|---|---|---|
| CHECK | CK_Event_Device |  | ([DeviceType]='Console' OR [DeviceType]='PC' OR [DeviceType]='Android' OR [DeviceType]='iOS') |
| CHECK | CK_Event_Level |  | ([LevelNumber]>=(1) AND [LevelNumber]<=(10)) |
| CHECK | CK_Event_Outcome |  | ([Outcome]='Abandon' OR [Outcome]='Loss' OR [Outcome]='Win') |
| CHECK | CK_Event_Source |  | ([SourceSystem]='WebClient' OR [SourceSystem]='MobileSDK' OR [SourceSystem]='GameClient') |
| CHECK | CK_Event_Type |  | ([EventType]='AdWatched' OR [EventType]='ItemUsed' OR [EventType]='LevelFail' OR [EventType]='LevelComplete' OR [EventType]='LevelStart' OR [EventType]='SessionEnd' OR [EventType]='SessionStart') |
| FK | FK_Event_Geo | GeoID | DimGeography.GeoID |
| FK | FK_Event_User | UserID | DimUser.UserID |
| PK | PK_UserEvent | EventID |  |


**Indexes**

| Index | Columns |
|---|---|
| IX_Event_TS | EventTS |
| IX_Event_User | UserID |


## Views, procedures, functions and triggers

| Name | Type |
|---|---|
| fnGeoDistanceKm | Scalar function |
| spMonthlyActiveUsers | Stored procedure |
| TR_DimPlan_Audit | Trigger |
| vwDailyActiveUsers | View |
| vwFreeVsPaidValue | View |
| vwSuspiciousTransactions | View |


The full text of each is in `parts/`, and in the combined script `IFT530_EDGroup_FinalProject.sql`.
