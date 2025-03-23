IF OBJECT_ID('dbo.AddMonthsToDY') IS NOT NULL DROP FUNCTION dbo.AddMonthsToDY
IF OBJECT_ID('AddMonthsToDY') IS NOT NULL DROP FUNCTION AddMonthsToDY
GO
-- Adds @x months to 1/@d/@y
-- If @d is to large, sets @d to last day of the month
CREATE FUNCTION dbo.AddMonthsToDY(@m int, @d int, @y int)
RETURNS datetime
AS
BEGIN 
DECLARE @maxd int

SET @m = @m - 1
SELECT @y = @y + @m / 12
SELECT @m = @m % 12 + 1

SELECT @maxd = dbo.GetLastDayOfMonth(@m, @y)

IF @d > @maxd SET @d = @maxd

RETURN dbo.GetDateFromMDY(@m, @d, @y)
END
GO
REVOKE EXEC ON dbo.spPermissionUpdateUserComment TO public
REVOKE EXEC ON dbo.spPermissionUpdateObjectStoredProcsForUID TO public
REVOKE EXEC ON dbo.spPermissionUpdateForUserScopeOnAttribute TO public

IF OBJECT_ID('CK_EmployeeCommunication_LenOfNote') IS NOT NULL
ALTER TABLE dbo.EmployeeCommunication DROP CONSTRAINT CK_EmployeeCommunication_LenOfNote
GO
ALTER TABLE dbo.EmployeeLeaveUsed DROP CONSTRAINT CK_EmployeeLeaveUsed_ApprovalRequiresType
UPDATE EmployeeLeaveUsed SET ApprovalTypeID = NULL WHERE Status = 4 AND ApprovalTypeID IS NOT NULL
ALTER TABLE dbo.EmployeeLeaveUsed ADD CONSTRAINT CK_EmployeeLeaveUsed_ApprovalRequiresType CHECK ([Status] IN (1,4) or ([ApprovalTypeID] is not null and [Status] = 2))
GO
IF OBJECT_iD('dbo.spPersonXTrainingListNot') IS NOT NULL DROP PROC dbo.spPersonXTrainingListNot
GO
CREATE PROC dbo.spPersonXTrainingListNot
	@batch_id int,
	@training_id int,
	@exclude_incomplete bit,
	@authorized bit OUT
AS
SET NOCOUNT ON

EXEC spPermissionGetOnPeopleForCurrentUser2 @batch_id, 4096
DELETE TempX WHERE BatchID = @batch_id AND X & 1 = 0
SELECT @authorized = CASE WHEN @@ROWCOUNT = 0 THEN 1 ELSE 0 END

CREATE TABLE #PT(PersonID int, ItemID int, [Completed Day past 1900] int, Training varchar(50), Courses varchar(4000))

INSERT #PT
SELECT X.[ID], NULL, NULL, '', ''
FROM TempX X
INNER JOIN Employee E ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID 
AND E.EmployeeID NOT IN
(
	SELECT PersonXTraining.PersonID FROM PersonXTraining WHERE PersonXTraining.TrainingID = @training_id AND ([Completed Day past 1900] IS NOT NULL OR @exclude_incomplete = 0)
)



DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1



-- Only works if Training.Training has a unique constraint and has a 0 length check constraint
WHILE @@ROWCOUNT > 0
BEGIN
	UPDATE #PT SET ItemID = (
		SELECT TOP 1 PT.ItemID FROM PersonXTraining PT
		INNER JOIN Training C ON 
		(PT.[Completed Day past 1900] IS NOT NULL OR @exclude_incomplete = 0) AND -- PT.[Began Day past 1900] BETWEEN @began_start AND @began_stop AND
		PT.PersonID = #PT.PersonID AND PT.TrainingID = C.TrainingID AND (
			ISNULL(PT.[Completed Day past 1900], -2147483648) > ISNULL(#PT.[Completed Day past 1900], -2147483648) OR 
			(ISNULL(PT.[Completed Day past 1900], -2147483648) = ISNULL(#PT.[Completed Day past 1900], -2147483648) AND C.Training > #PT.Training)
		)
		ORDER BY PT.[Completed Day Past 1900], C.Training
	)

	UPDATE #PT SET Training = C.Training, [Completed Day Past 1900] = PT.[Completed Day past 1900],
		Courses = SUBSTRING(
			Courses + 
			CASE WHEN LEN(#PT.Courses) = 0 THEN '' ELSE ', ' END + 
			C.Training +
			CASE WHEN PT.[Completed Day past 1900] IS NULL THEN '' ELSE ' (' + CAST(DATEADD(d, PT.[Completed Day past 1900], 0) AS char(11)) + ')' END
		, 1, 4000)
	FROM #PT 
	INNER JOIN PersonXTraining PT ON #PT.ItemID = PT.ItemID
	INNER JOIN Training C ON PT.TrainingID = C.TrainingID

END

SELECT Person = P.[List As], #PT.Courses
FROM #PT
INNER JOIN vwPersonListAs P ON #PT.PersonID = P.PersonID AND LEN(#PT.Courses) > 0
ORDER BY P.[List As]
GO
GRANT EXEC ON dbo.spPersonXTrainingListNot TO public
IF (SELECT COUNT(*) FROM MaritalStatus) = 0
BEGIN
	INSERT MaritalStatus(Status) VALUES('Unspecified')
	UPDATE PersonX SET MaritalStatusID = SCOPE_IDENTITY()
END

UPDATE PersonX SET MaritalStatusID =
(
	SELECT TOP 1 StatusID FROM MaritalStatus
) 
WHERE MaritalStatusID NOT IN
(
	SELECT StatusID FROM MaritalStatus
)

IF OBJECT_ID('IX_MaritalStatus_Status') IS NULL
ALTER TABLE [dbo].[PersonX] ADD 
	CONSTRAINT [FK_PersonX_MaritalStatus] FOREIGN KEY 
	(
		[MaritalStatusID]
	) REFERENCES [dbo].[MaritalStatus] (
		[StatusID]
	)
GO
if OBJECT_ID('[dbo].[TaskEmail]') IS NULL
BEGIN
	CREATE TABLE [dbo].[TaskEmail] (
		[EmailID] [int] NOT NULL ,
		[Recipient] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[Reminder] [bit] NOT NULL ,
		[ID] [int] NOT NULL ,
		[Sent] [smalldatetime] NOT NULL DEFAULT GETDATE()
	) ON [PRIMARY]
	
	
	ALTER TABLE [dbo].[TaskEmail] WITH NOCHECK ADD 
		CONSTRAINT [PK_TaskEmail] PRIMARY KEY  CLUSTERED 
		(
			[EmailID]
		)  ON [PRIMARY] 
	CREATE  INDEX [IX_TaskEmail_Sent] ON [dbo].[TaskEmail]([Sent]) ON [PRIMARY]
	
	
	CREATE  INDEX [IX_TaskEmail] ON [dbo].[TaskEmail]([Recipient], [ID]) ON [PRIMARY]
END
GO
IF OBJECT_ID('dbo.spTaskEmailInsertOrUpdate') IS NOT NULL DROP PROC dbo.spTaskEmailInsertOrUpdate
GO
CREATE PROC dbo.spTaskEmailInsertOrUpdate
	@recipient varchar(50),
	@reminder bit,
	@id int
AS
DECLARE @email_id int

SET NOCOUNT ON

SELECT @email_id = EmailID FROM TaskEmail WHERE Recipient = @recipient AND [ID] = @id AND Reminder = @reminder 
IF @@ROWCOUNT = 0
	INSERT TaskEmail(Recipient, Reminder, [ID])
	VALUES(@recipient, @reminder, @id)
ELSE
	UPDATE TaskEmail
	SET Recipient = @recipient, Reminder = @reminder, [ID] = @id
	WHERE EmailID = @email_id

DELETE TaskEmail WHERE Sent < DATEADD(d, -30, GETDATE())
GO
GRANT EXEC ON dbo.spTaskEmailInsertOrUpdate TO public
GO
IF OBJECT_ID('dbo.spTaskEmailGetSent') IS NOT NULL DROP PROC dbo.spTaskEmailGetSent
GO
CREATE PROC dbo.spTaskEmailGetSent
	@recipient varchar(50),
	@reminder bit,
	@id int,
	@sent smalldatetime 
AS
SET NOCOUNT ON

SELECT @sent = Sent FROM TaskEmail WHERE Recipient = @recipient AND [ID] = @id AND Reminder = @reminder 
GO
GRANT EXEC ON dbo.spTaskEmailGetSent TO public
GO
ALTER PROC dbo.spEmployeeLeaveCalcForEmployee
	@employee_id int,
	@start int = -2147483648
AS
DECLARE @carryover_target_type_id int
DECLARE @type_id int

-- Excludes carryover target because calling spEmployeeLeaveCalcForEmployeeType on the source will automatically apply limits on the target
SELECT @carryover_target_type_id = CarryoverTargetLeaveTypeID FROM Constant
DECLARE t_cursor CURSOR LOCAL STATIC FOR SELECT TypeID FROM LeaveType WHERE @carryover_target_type_id IS NULL OR TypeID <> @carryover_target_type_id

IF @carryover_target_type_id IS NOT NULL EXEC spEmployeeLeaveAccrue @employee_id, @carryover_target_type_id, @start

OPEN t_cursor
FETCH t_cursor INTO @type_id
WHILE @@FETCH_STATUS = 0
BEGIN
	EXEC spEmployeeLeaveCalcForEmployeeType @employee_id, @type_id, @start

	FETCH t_cursor INTO @type_id
END
GO

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID] = OBJECT_ID('dbo.Constant') AND [name] = 'Reminder E-mail Suppress Days')
BEGIN
	ALTER TABLE Constant ADD [Reminder E-mail Suppress Days] int NULL
	ALTER TABLE Constant ADD [Reminder E-mail Subject] varchar(50) NOT NULL DEFAULT('Reminders')
	ALTER TABLE Constant ADD [Reminder E-mail Sender] varchar(4000) NOT NULL DEFAULT('')
	ALTER TABLE Constant ADD [Reminder E-mail Last Result] varchar(50) NOT NULL DEFAULT('Never e-mailed')
	ALTER TABLE Constant ADD [Reminder E-mail Repeat Days] int NOT NULL DEFAULT(7)
	ALTER TABLE Constant ADD [Reminder E-mail Ignore Days] int NOT NULL DEFAULT(14)
END
GO
IF OBJECT_ID('dbo.spConstantUpdateLastResult') IS NOT NULL DROP PROC dbo.spConstantUpdateLastResult
GO
CREATE PROC dbo.spConstantUpdateLastResult
	@result varchar(4000)
AS
SET NOCOUNT ON

UPDATE Constant SET [Reminder E-mail Last Result] = @result
GO
GRANT EXEC ON dbo.spConstantUpdateLastResult TO public
GO
IF OBJECT_ID('dbo.spConstantUpdateReminderEmail') IS NOT NULL DROP PROC dbo.spConstantUpdateReminderEmail
GO
CREATE PROC dbo.spConstantUpdateReminderEmail
	@suppress_days int,
	@subject varchar(50),
	@sender varchar(50),
	@repeat_days int,
	@ignore_days int
AS
SET NOCOUNT ON

UPDATE Constant SET [Reminder E-mail Suppress Days] = @suppress_days,
[Reminder E-mail Subject] = @subject,
[Reminder E-mail Sender] = @sender,
[Reminder E-mail Repeat Days] = @repeat_days,
[Reminder E-mail Ignore Days] = @ignore_days
GO
ALTER PROC dbo.spCompanySelect
AS
SET NOCOUNT ON

SELECT
C.Currency,C.CheckNoVisible,C.CheckNoX,C.CheckNoY,C.DateX,C.DateY,C.ToX,C.ToY,C.AddressVisible,C.AddressX,C.AddressY, [Division Label],
C.AmountX,C.AmountY,C.WrittenAmountX,C.WrittenAmountY,C.ItemizationX,C.ItemizationY,C.HeadquartersID,C.Company,C.EmployerID,
C.DUNS,C.EEOCompany,C.NAICS,C.SIC,[Headquarters] = L.[List As], C.[Root Path], [Server Version], C.[Timecard Rounding], C.CurrentPayrollPeriodID,
C.[Fiscal Year Start Month], C.[Fiscal Year Start Day],
C.[Operational Year Start Month], C.[Operational Year Start Day],
C.[Administrative Year Start Month], C.[Administrative Year Start Day],
C.[Reminder E-mail Suppress Days],
C.[Reminder E-mail Subject],
C.[Reminder E-mail Sender],
C.[Reminder E-mail Last Result],
C.[Reminder E-mail Repeat Days],
C.[Reminder E-mail Ignore Days]
FROM Constant C
INNER JOIN Location L ON L.LocationID = C.HeadquartersID
GO
ALTER TRIGGER UpdateLastOut ON dbo.EmployeeTime
FOR INSERT, UPDATE, DELETE 
AS
DECLARE @batch_id int
DECLARE @error int
DECLARE @error_msg varchar(400)
DECLARE @item_id int, @dup_item_id int

SET NOCOUNT ON

IF (SELECT [Enable Timecard Trigger] FROM Constant)  = 0 RETURN

SELECT @error = 0, @batch_id = RAND() * 2147483647, @error_msg = '', @dup_item_id = NULL, @item_id = NULL

-- Selects the affected employees into Temp.[ID]
IF EXISTS(SELECT * FROM inserted)
BEGIN
	INSERT [TempX] (BatchID, [ID])
	SELECT DISTINCT @batch_id, EmployeeID FROM inserted
END
ELSE
BEGIN
	INSERT [TempX] (BatchID, [ID])
	SELECT DISTINCT @batch_id, EmployeeID FROM deleted
END

-- Checks period integrity if start or stop was inserted or updated
IF (UPDATE([EmployeeID]) OR UPDATE([In]) OR UPDATE([Out])) AND EXISTS(SELECT TOP 1 ItemID FROM inserted)
BEGIN
	-- Ensures only the last out time is left open
	/* SELECT TOP 1 @error = 50014 FROM EmployeeTime Et
	INNER JOIN [TempX] T ON T.BatchID = @batch_id AND T.[ID] = Et.EmployeeID AND Et.[Out] IS NULL
	INNER JOIN EmployeeTime Et2 ON Et.EmployeeID = Et2.EmployeeID AND Et.ItemID <> Et2.ItemID AND Et2.[In] >= Et.[In] */


	-- Ensures periods for the same employee do not overlap upon insert and update
	IF @error = 0 
	BEGIN
		SELECT TOP 1 @dup_item_id = Et2.ItemID, @item_id = Et.ItemID FROM inserted Et
		INNER JOIN [TempX] T ON T.BatchID = @batch_id AND T.[ID] = Et.EmployeeID
		INNER JOIN EmployeeTime Et2 ON Et.ItemID <> Et2.ItemID  AND Et.EmployeeID = Et2.EmployeeID AND Et.[In] >= Et2.[In] AND Et.[In] <= ISNULL(Et2.[Out], '6/6/2079')
	
		IF @@ROWCOUNT > 0
		BEGIN
			SELECT @error_msg = 'The timecard entry for ' + P.[First Name] + ' (' + CAST(ET.[In] AS varchar(50)) + CASE WHEN ET.[Out] Is NULL THEN '' ELSE ' to ' +  CAST(ET.[Out] AS varchar(50)) END + ') overlaps the entry for '
			FROM EmployeeTime ET
			INNER JOIN Person P ON ET.ItemID = @item_id AND ET.EmployeeID = P.PersonID

			
			SELECT @error_msg = @error_msg  + P.[First Name] + ' (' + CAST(ET.[In] AS varchar(50)) + CASE WHEN ET.[Out] Is NULL THEN '' ELSE ' to ' +  CAST(ET.[Out] AS varchar(50)) END + '. Please fix the entry and try again.'
			FROM EmployeeTime ET
			INNER JOIN Person P ON ET.ItemID = @dup_item_id AND ET.EmployeeID = P.PersonID
		END
	END
END

DELETE [TempX] WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1

IF LEN(@error_msg) > 0 RAISERROR (@error_msg, 16, 1)
ELSE IF @error <> 0 EXEC spErrorRaise @error
IF (@error <> 0 OR LEN(@error_msg) > 0) AND @@TRANCOUNT > 0 ROLLBACK
GO


IF OBJECT_ID('dbo.ReportTemplate2') IS NULL
BEGIN
CREATE TABLE [dbo].[ReportTemplate2] (
	[TemplateID] [int] NOT NULL ,
	[Template] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[SortByFieldID] [int] NOT NULL ,
	[Fields Stream] [image] NOT NULL ,
	[Filter Stream] [image] NOT NULL 
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

ALTER TABLE [dbo].[ReportTemplate2] WITH NOCHECK ADD 
	CONSTRAINT [PK_ReportTemplate2] PRIMARY KEY  CLUSTERED 
	(
		[TemplateID]
	)  ON [PRIMARY] 

ALTER TABLE [dbo].[ReportTemplate2] ADD CONSTRAINT [CK_ReportTemplate2_Blank] CHECK (len([Template]) > 0)
END
GO



IF OBJECT_ID('dbo.CompensationAdjustment') IS NULL
BEGIN
CREATE TABLE [dbo].[CompensationAdjustment] (
	[AdjustmentID] [int] IDENTITY (1, 1) NOT NULL ,
	[Adjustment] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[PeriodID] [int] NULL 
) ON [PRIMARY]

ALTER TABLE [dbo].[CompensationAdjustment] WITH NOCHECK ADD 
	CONSTRAINT [PK_CompensationAdjustment] PRIMARY KEY  CLUSTERED 
	(
		[AdjustmentID]
	)  ON [PRIMARY] 

ALTER TABLE [dbo].[CompensationAdjustment] ADD 
	CONSTRAINT [IX_CompensationAdjustment_Unique] UNIQUE  NONCLUSTERED 
	(
		[Adjustment]
	)  ON [PRIMARY] ,
	CONSTRAINT [CK_CompensationAdjustment_Blank] CHECK (len([Adjustment]) > 0)
END
GO
IF OBJECT_ID('dbo.EmployeeCompensationAdjustment') IS NULL
BEGIN
CREATE TABLE [dbo].[EmployeeCompensationAdjustment] (
	[ItemID] [int] IDENTITY (1, 1) NOT NULL ,
	[AdjustmentID] [int] NOT NULL ,
	[CompensationID] [int] NOT NULL ,
	[Minimum Adjustment] [money] NOT NULL ,
	[Maximum Adjustment] [money] NOT NULL 
) ON [PRIMARY]


ALTER TABLE [dbo].[EmployeeCompensationAdjustment] WITH NOCHECK ADD 
	CONSTRAINT [PK_EmployeeCompensationAdjustment] PRIMARY KEY  CLUSTERED 
	(
		[ItemID]
	)  ON [PRIMARY] 


ALTER TABLE [dbo].[EmployeeCompensationAdjustment] ADD 
	CONSTRAINT [CK_EmployeeCompensationAdjustment_MaxLessThanMin] CHECK ([Maximum Adjustment] >= [Minimum Adjustment])

ALTER TABLE [dbo].[EmployeeCompensationAdjustment] ADD 
	CONSTRAINT [FK_EmployeeCompensationAdjustment_CompensationAdjustment] FOREIGN KEY 
	(
		[AdjustmentID]
	) REFERENCES [dbo].[CompensationAdjustment] (
		[AdjustmentID]
	) ON DELETE CASCADE ,
	CONSTRAINT [FK_EmployeeCompensationAdjustment_EmployeeCompensation] FOREIGN KEY 
	(
		[CompensationID]
	) REFERENCES [dbo].[EmployeeCompensation] (
		[CompensationID]
	) ON DELETE CASCADE 
END
GO



IF OBJECT_ID('dbo.vwEmployeeCompensationAdjustment') IS NOT NULL DROP VIEW dbo.vwEmployeeCompensationAdjustment
GO
CREATE VIEW dbo.vwEmployeeCompensationAdjustment
AS
SELECT EA.*, A.Adjustment, P.[List As], P.Initials, P.[Full Name], C.EmployeeID, C.[Start Day past 1900], C.[Stop Day past 1900], A.PeriodID, Period = ISNULL(Period.Period, ''), Period.Seconds
FROM EmployeeCompensationAdjustment EA
INNER JOIN EmployeeCompensation C ON EA.CompensationID = C.CompensationID
INNER JOIN vwPersonCalculated P ON C.EmployeeID = P.PersonID
INNER JOIN CompensationAdjustment A ON EA.AdjustmentID = A.AdjustmentID
LEFT JOIN Period ON A.PeriodID = Period.PeriodID
GO
ALTER VIEW vwEmployeeCompensation
AS
SELECT EC.*, Employee = PSN.[List As], [Employee Full Name] = PSN.[Full Name], POS.[Annualized Pay Range],
[Annualized Pay] = (7488000.0 / P.Seconds) * EC.[Base Pay] * CASE WHEN EC.PeriodID = 512 THEN POS.FTE ELSE 1 END, -- Takes FTE into account for hourly positions

[Annualized Adjustment Min] = ISNULL(
(SELECT SUM(CASE WHEN A.PeriodID IS NULL THEN 0 ELSE [Minimum Adjustment] * (7488000.0 / AP.Seconds) END) FROM vwEmployeeCompensationAdjustment A 
LEFT JOIN Period AP ON AP.PeriodID = A.PeriodID WHERE A.CompensationID = EC.CompensationID),
0),

[Annualized Adjustment Max] = ISNULL(
(SELECT SUM(CASE WHEN A.PeriodID IS NULL THEN 0 ELSE [Maximum Adjustment] * (7488000.0 / AP.Seconds) END) FROM vwEmployeeCompensationAdjustment A 
LEFT JOIN Period AP ON AP.PeriodID = A.PeriodID WHERE A.CompensationID = EC.CompensationID),
0),

[Annualized Employer Premiums] = ISNULL(
	(SELECT SUM(EB.[Employer Premium] * (7488000.0 / P.Seconds)) 
	FROM Constant C
	INNER JOIN Period P ON (C.CurrentPayrollPeriodID & 2047) = P.PeriodID
	CROSS JOIN EmployeeBenefit EB 
	WHERE EB.EmployeeID = EC.EmployeeID
	
), 0),

[Employer Premiums] = ISNULL(
	(SELECT SUM(EB.[Employer Premium]) 
	FROM EmployeeBenefit EB WHERE EB.EmployeeID = EC.EmployeeID
), 0),

[Hourly Pay] = (3600.0 / P.Seconds) * EC.[Base Pay], POS.[Job Title],
[Start] = dbo.GetDateFromDaysPast1900(EC.[Start Day past 1900]), [Stop]=dbo.GetDateFromDaysPast1900(EC.[Stop Day past 1900]),
POS.[FLSA Exempt], P.Period,
POS.Status,
[Receives Other Compensation] = CAST(CASE WHEN LEN(EC.[Other Compensation]) > 0 THEN 1 ELSE 0 END AS bit),
[Employment Status] = CASE WHEN E.[Terminated Day past 1900] IS NULL THEN ES.Status ELSE 'Terminated' END,
POS.FTE,
POS.CategoryID,
POS.Category
FROM EmployeeCompensation EC
INNER JOIN Period P ON EC.PeriodID = P.PeriodID
INNER JOIN vwPersonCalculated PSN ON EC.EmployeeID = PSN.PersonID
INNER JOIN vwPosition POS ON EC.PositionID = POS.PositionID
INNER JOIN EmploymentStatus ES ON EC.EmploymentStatusID = ES.StatusID
INNER JOIN Employee E ON EC.EmployeeID = E.EmployeeID
GO
IF OBJECT_ID('dbo.spCompensationAdjustmentInsert') IS NOT NULL DROP PROC dbo.spCompensationAdjustmentInsert
GO
CREATE PROC dbo.spCompensationAdjustmentInsert
	@adjustment varchar(50),
	@period_id int,
	@adjustment_id int OUT
AS
INSERT CompensationAdjustment(Adjustment, PeriodID)
VALUES (@adjustment, @period_id)
SET @adjustment_id = SCOPE_IDENTITY()
GO

IF OBJECT_ID('dbo.spCompensationAdjustmentUpdate') IS NOT NULL DROP PROC dbo.spCompensationAdjustmentUpdate
GO
CREATE PROC dbo.spCompensationAdjustmentUpdate
	@adjustment varchar(50),
	@period_id int,
	@adjustment_id int
AS
UPDATE CompensationAdjustment
SET Adjustment = @adjustment, PeriodID = @period_id WHERE AdjustmentID = @adjustment_id
GO
IF OBJECT_ID('dbo.spCompensationAdjustmentDelete') IS NOT NULL DROP PROC dbo.spCompensationAdjustmentDelete
GO
CREATE PROC dbo.spCompensationAdjustmentDelete
	@adjustment_id int
AS
DELETE CompensationAdjustment WHERE AdjustmentID = @adjustment_id
GO

IF OBJECT_ID('dbo.spCompensationAdjustmentSelect') IS NOT NULL DROP PROC dbo.spCompensationAdjustmentSelect
GO
CREATE PROC dbo.spCompensationAdjustmentSelect
	@adjustment_id int
AS
SELECT * FROM CompensationAdjustment WHERE AdjustmentID = @adjustment_id
GO
GRANT EXEC ON dbo.spCompensationAdjustmentSelect TO public
IF OBJECT_ID('dbo.vwCompensationAdjustment') IS NOT NULL DROP VIEW dbo.vwCompensationAdjustment
IF OBJECT_ID('vwCompensationAdjustment') IS NOT NULL DROP VIEW vwCompensationAdjustment
GO
CREATE VIEW dbo.vwCompensationAdjustment
AS
SELECT A.*, Period = ISNULL(P.Period, ''), P.Seconds
FROM CompensationAdjustment A
LEFT JOIN Period P ON A.PeriodID = P.PeriodID
GO
IF OBJECT_ID('dbo.spCompensationAdjustmentList') IS NOT NULL DROP PROC dbo.spCompensationAdjustmentList
GO
CREATE PROC dbo.spCompensationAdjustmentList
	@one_time bit
AS
SELECT * FROM vwCompensationAdjustment 
WHERE (@one_time IS NULL) OR (@one_time = 0 AND PeriodID IS NOT NULL) OR (@one_time = 1 AND PeriodID IS NULL)
ORDER BY Adjustment
GO
GRANT EXEC ON dbo.spCompensationAdjustmentList TO public

IF OBJECT_ID('dbo.spEmployeeCompensationAdjustmentUpdate') IS NOT NULL DROP PROC dbo.spEmployeeCompensationAdjustmentUpdate

IF NOT EXISTS(SELECT * FROM Error WHERE ErrorID = 50038)
INSERT Error(ErrorID, Error)
VALUES (50038, 'Permission denied. Cannot change the name of the compensation adjustment.')

IF NOT EXISTS(SELECT * FROM Error WHERE ErrorID = 50039)
INSERT Error(ErrorID, Error)
VALUES (50039, 'Permission denied. Cannot insert a compensation adjustment.')
GO
CREATE PROC dbo.spEmployeeCompensationAdjustmentUpdate
	@compensation_id int,	
	@adjustment_id int,
	@max money,
	@min money
AS
DECLARE @employee_id int
DECLARE @authorized bit
DECLARE @was_null bit

SET NOCOUNT ON

-- Requires permission to change adjustment for employee
SELECT @employee_id = EmployeeID FROM EmployeeCompensation WHERE CompensationID = @compensation_id
EXEC spPermissionInsureForCurrentUserOnPerson @employee_id, 1024, 2, @authorized out

IF @authorized = 1
BEGIN
	SELECT @was_null = 0 FROM EmployeeCompensationAdjustment WHERE CompensationID = @compensation_id AND AdjustmentID = @adjustment_id
	IF @@ROWCOUNT = 0 SELECT @was_null = 1

	IF @was_null = 1 
	BEGIN
		IF @max != 0 OR @min != 0
		INSERT EmployeeCompensationAdjustment (CompensationID, AdjustmentID, [Minimum Adjustment], [Maximum Adjustment])
		VALUES (@compensation_id, @adjustment_id, @min, @max)
	END
	ELSE IF @max = 0 AND @min = 0
		DELETE EmployeeCompensationAdjustment WHERE CompensationID = @compensation_id AND AdjustmentID = @adjustment_id
	ELSE
		UPDATE EmployeeCompensationAdjustment SET [Minimum Adjustment] = @min, [Maximum Adjustment] = @max
		WHERE CompensationID = @compensation_id AND AdjustmentID = @adjustment_id
END

GO
GRANT EXEC ON dbo.spEmployeeCompensationAdjustmentUpdate TO public
IF OBJECT_ID('dbo.spEmployeeCompensationAdjustmentSelect') IS NOT NULL DROP PROC dbo.spEmployeeCompensationAdjustmentSelect
GO
CREATE PROC dbo.spEmployeeCompensationAdjustmentSelect
	@item_id int
AS
DECLARE @authorized bit, @employee_id int

SET NOCOUNT ON

SELECT @employee_id = C.EmployeeID FROM EmployeeCompensationAdjustment A
INNER JOIN EmployeeCompensation C ON A.ItemID = @item_id AND A.CompensationID = C.CompensationID
EXEC spPermissionInsureForCurrentUserOnPerson @employee_id, 1024, 1, @authorized out

IF @authorized = 1
SELECT * FROM vwEmployeeCompensationAdjustment WHERE ItemID = @item_id
GO

GRANT EXEC ON dbo.spEmployeeCompensationAdjustmentSelect TO public

IF OBJECT_ID('dbo.spEmployeeCompensationAdjustmentList') IS NOT NULL DROP PROC dbo.spEmployeeCompensationAdjustmentList
GO
CREATE PROC dbo.spEmployeeCompensationAdjustmentList
	@compensation_id int
AS
DECLARE @authorized bit, @employee_id int

SET NOCOUNT ON

SELECT @employee_id = EmployeeID FROM EmployeeCompensation WHERE CompensationID = @compensation_id
EXEC spPermissionInsureForCurrentUserOnPerson @employee_id, 1024, 1, @authorized out

IF @authorized = 1
SELECT C.CompensationID, -- Nullable
A.AdjustmentID,
[Minimum Adjustment] = ISNULL(C.[Minimum Adjustment], 0),
[Maximum Adjustment] = ISNULL(C.[Maximum Adjustment], 0),
A.Adjustment,
A.PeriodID,
Period = ISNULL(C.Period,''),
[List As] = ISNULL(C.[List As], '')
FROM CompensationAdjustment A
LEFT JOIN vwEmployeeCompensationAdjustment C ON C.CompensationID = @compensation_id AND A.AdjustmentID = C.AdjustmentID
ORDER BY A.[Adjustment]
GO
GRANT EXEC ON dbo.spEmployeeCompensationAdjustmentList TO public
IF OBJECT_ID('dbo.spEmployeeCompensationAdjustmentList2') IS NOT NULL DROP PROC dbo.spEmployeeCompensationAdjustmentList2
GO
CREATE PROC dbo.spEmployeeCompensationAdjustmentList2
	@effective_day int,
	@batch_id int,
	@period_id int,
	@one_time bit
AS
SET NOCOUNT ON

EXEC spPermissionGetOnPeopleForCurrentUser2 @batch_id, 1024
DELETE TempX WHERE BatchID = @batch_id AND (X & 1) = 0

DECLARE @seconds decimal

SELECT @seconds = Seconds FROM Period WHERE PeriodID = @period_id

SELECT CA.CompensationID, -- Nullable
A.AdjustmentID,
[Minimum Adjustment] = CASE WHEN CA.Seconds IS NULL THEN 1 ELSE @seconds / CA.Seconds END * ISNULL(CA.[Minimum Adjustment], 0),
[Maximum Adjustment] = CASE WHEN CA.Seconds IS NULL THEN 1 ELSE @seconds / CA.Seconds END * ISNULL(CA.[Maximum Adjustment], 0),
A.Adjustment,
[List As] = E.[List As],
EmployeeID = E.PersonID,
A.PeriodID
FROM vwPersonListAs E
INNER JOIN TempX T ON T.BatchID = @batch_id AND T.[ID] = E.PersonID
CROSS JOIN CompensationAdjustment A
LEFT JOIN vwEmployeeCompensationAdjustment CA ON @effective_day >= CA.[Start Day past 1900] AND (CA.[Stop Day past 1900] IS NULL OR @effective_day <= CA.[Stop Day past 1900]) AND CA.EmployeeID = E.PersonID AND A.AdjustmentID = CA.AdjustmentID
WHERE (@one_time IS NULL) OR (@one_time = 0 AND A.PeriodID IS NOT NULL) OR (@one_time = 1 AND A.PeriodID IS NULL)
ORDER BY E.[List As], A.[Adjustment]

/*SELECT C.EmployeeID, C.Employee, C.[Annualized Pay], C.[Base Pay], C.[Other Compensation],  P.Period
FROM vwEmployeeCompensation C
INNER JOIN TempX T ON T.BatchID = @batch_id AND T.[ID] = C.EmployeeID AND @effective_day >= C.[Start Day past 1900] AND (C.[Stop Day past 1900] IS NULL OR @effective_day <= C.[Stop Day past 1900])
INNER JOIN Period P ON P.PeriodID = C.PeriodID ORDER BY Employee*/

DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1
GO
GRANT EXEC ON dbo.spEmployeeCompensationAdjustmentList2 TO public
IF OBJECT_ID('dbo.spCompensationSummary2') IS NOT NULL DROP PROC dbo.spCompensationSummary2
GO
CREATE PROC dbo.spCompensationSummary2
	@effective_day int,
	@batch_id int,
	@period_id int
AS
SET NOCOUNT ON

EXEC spPermissionGetOnPeopleForCurrentUser2 @batch_id, 1024
DELETE TempX WHERE BatchID = @batch_id AND (X & 1) = 0

DECLARE @rate numeric(9, 1)
SELECT @rate = 7488000.0 / Seconds FROM Period WHERE PeriodID = @period_id

SELECT EmployeeID = E.PersonID, Employee = E.[List As], [Other Compensation] = ISNULL(C.[Other Compensation], ''), Period = ISNULL(P.Period, ''),
Note = ISNULL(C.Note, ''),
[Employer Premiums] = ISNULL(C.[Annualized Employer Premiums] /  @rate, 0),
[Adjustment Min] =ISNULL( [Annualized Adjustment Min] / @rate, 0),
[Adjustment Max] = ISNULL([Annualized Adjustment Max] / @rate, 0),
Pay = ISNULL(CASE WHEN @period_id = 512 THEN [Hourly Pay] ELSE [Annualized Pay] / @rate END, 0)
FROM TempX T
INNER JOIN vwPersonListAs E ON T.BatchID = @batch_id AND T.[ID] = E.PersonID
LEFT JOIN vwEmployeeCompensation C ON C.EmployeeID = E.PersonID AND @effective_day >= C.[Start Day past 1900] AND (C.[Stop Day past 1900] IS NULL OR @effective_day <= C.[Stop Day past 1900])
LEFT JOIN Period P ON P.PeriodID = C.PeriodID ORDER BY Employee

DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1
GO
GRANT EXEC ON dbo.spCompensationSummary2 TO public
IF OBJECT_ID('dbo.spDivisionGetDivisionFromDivisionID') IS NOT NULL DROP PROC dbo.spDivisionGetDivisionFromDivisionID
GO
CREATE PROC dbo.spDivisionGetDivisionFromDivisionID
	@division_id int,
	@division varchar(50)
AS
SELECT @division = ''
SELECT @division = Division FROM Division WHERE DivisionID = @division_id
GO
GRANT EXEC ON dbo.spDivisionGetDivisionFromDivisionID TO public
IF OBJECT_ID('dbo.spLocationGetListAs') IS NOT NULL DROP PROC dbo.spLocationGetListAs
GO
CREATE PROC dbo.spLocationGetListAs
	@location_id int,
	@list_as varchar(50)
AS
SELECT @list_as = ''
SELECT @list_as = [List As] FROM Location WHERE LocationID = @Location_id
GO
GRANT EXEC ON dbo.spLocationGetListAs TO public
IF OBJECT_ID('dbo.spDepartmentGetDepartmentFromDepartmentID') IS NOT NULL DROP PROC dbo.spDepartmentGetDepartmentFromDepartmentID
GO
CREATE PROC dbo.spDepartmentGetDepartmentFromDepartmentID
	@Department_id int,
	@Department varchar(50)
AS
SELECT @department = ''
SELECT @department = Department FROM Department WHERE DepartmentID = @department_id
GO
GRANT EXEC ON dbo.spDepartmentGetDepartmentFromDepartmentID TO public
IF OBJECT_ID('dbo.spShiftGetShiftFromShiftID') IS NOT NULL DROP PROC dbo.spShiftGetShiftFromShiftID
GO
CREATE PROC dbo.spShiftGetShiftFromShiftID
	@shift_id int,
	@shift varchar(50)
AS
SELECT @shift = ''
SELECT @shift = Shift FROM Shift WHERE ShiftID = @shift_id
GO
GRANT EXEC ON dbo.spShiftGetShiftFromShiftID TO public
IF OBJECT_ID('dbo.spEmploymentStatusGetStatusFromStatusID') IS NOT NULL DROP PROC dbo.spEmploymentStatusGetStatusFromStatusID
GO
CREATE PROC dbo.spEmploymentStatusGetStatusFromStatusID
	@status_id int,
	@status varchar(50)
AS
SELECT @status = ''
SELECT @status = Status FROM EmploymentStatus WHERE StatusID = @status_id
GO
GRANT EXEC ON dbo.spEmploymentStatusGetStatusFromStatusID TO public
IF OBJECT_ID('dbo.spPositionStatusGetStatusFromStatusID') IS NOT NULL DROP PROC dbo.spPositionStatusGetStatusFromStatusID
GO
CREATE PROC dbo.spPositionStatusGetStatusFromStatusID
	@status_id int,
	@status varchar(50)
AS
SELECT @status = ''
SELECT @status = Status FROM PositionStatus WHERE StatusID = @status_id
GO
GRANT EXEC ON dbo.spPositionStatusGetStatusFromStatusID TO public
IF OBJECT_ID('dbo.spPositionGetPositionFromPositionID') IS NOT NULL DROP PROC dbo.spPositionGetPositionFromPositionID
GO
CREATE PROC dbo.spPositionGetPositionFromPositionID
	@position_id int,
	@position varchar(50)
AS
SELECT @position = ''
SELECT @position = [Job Title] FROM Position WHERE PositionID = @position_id
GO
GRANT EXEC ON dbo.spPositionGetPositionFromPositionID TO public
IF OBJECT_ID('dbo.spPositionGetPositionFromPositionID') IS NOT NULL DROP PROC dbo.spPositionGetPositionFromPositionID
IF OBJECT_ID('dbo.spPersonListPrepareBatch3') IS NOT NULL DROP PROC dbo.spPersonListPrepareBatch3
GO
CREATE PROC dbo.spPersonListPrepareBatch3
	@batch_id int,
	@and bit, -- or=0 and=1
	@field_id int, -- ColumnGrid.FieldID
	@operation int,
	@value sql_variant
AS
DECLARE @t varchar(50)
DECLARE @i int
DECLARE @f bit
DECLARE @type sysname

SET NOCOUNT ON

SELECT @type = CAST(SQL_VARIANT_PROPERTY ( @value, 'BaseType' ) AS sysname), @t = null, @i= null, @f = null

IF @type = 'varchar' SELECT @t = '%' + CAST(@value AS varchar(50)) + '%'
ELSE IF @type = 'int' SELECT @i = CAST(@value AS int)
ELSE IF @type = 'bit' SELECT @f = CAST(@value AS bit)


/* Active Employee
Location
Department
Shift
Division
Manager
CurrentPosition
EmploymentStatus
PositionStatus

Is
IsNot
Like
NotLike */

IF @and=0 -- OR
BEGIN
	-- Active Employee
	IF @field_id = 1013 INSERT TempX(BatchID, [ID])
	SELECT @batch_id, E.EmployeeID FROM Employee E WHERE 
	@f IS NULL OR (@operation=0 AND E.[Active Employee] = @f) OR (@operation=1 AND E.[Active Employee] <> @f)

	-- PersonID
	IF @field_id=1003 INSERT TempX(BatchID, [ID])
	VALUES(@batch_id, @i)

	-- Location
	ELSE IF @field_id=54 INSERT TempX(BatchID, [ID])
	SELECT @batch_id, E.EmployeeID FROM Employee E
	INNER JOIN Location L ON E.LocationID = L.LocationID AND
	(
		(@operation=0 AND E.LocationID = @i) OR (@operation=1 AND E.LocationID <> @i) OR
		(@operation=2 AND L.[List As] LIKE @t) OR (@operation=3 AND L.[List As] NOT LIKE @t)
	)

	-- Department
	ELSE IF @field_id=55	INSERT TempX(BatchID, [ID])
	SELECT @batch_id, E.EmployeeID FROM Employee E
	INNER JOIN Department D ON E.DepartmentID = D.DepartmentID AND 
	(
		(@operation=0 AND E.DepartmentID = @i) OR (@operation=1 AND E.DepartmentID <> @i) OR
		(@operation=2 AND D.Department LIKE @t) OR (@operation=3 AND D.Department NOT LIKE @t)
	)

	-- Division
	ELSE IF @field_id=53 INSERT TempX(BatchID, [ID])
	SELECT @batch_id, E.EmployeeID FROM Employee E
	INNER JOIN Division V ON E.DivisionID = V.DivisionID AND
	(
		(@operation=0 AND E.DivisionID = @i) OR (@operation=1 AND E.DivisionID <> @i) OR
		(@operation=2 AND V.Division LIKE @t) OR (@operation=3 AND V.Division NOT LIKE @t)
	)

	-- Shift
	ELSE IF @field_id=51
	INSERT TempX(BatchID, [ID])
	SELECT @batch_id, E.EmployeeID FROM Employee E
	INNER JOIN Shift S ON E.ShiftID = S.ShiftID AND
	(
		(@operation=0 AND E.ShiftID = @i) OR (@operation=1 AND E.ShiftID <> @i) OR
		(@operation=2 AND S.Shift LIKE @t) OR (@operation=3 AND S.Shift NOT LIKE @t)
	)

	-- Manager
	ELSE IF @field_id=52
	INSERT TempX(BatchID, [ID])
	SELECT @batch_id, E.EmployeeID FROM Employee E
	INNER JOIN vwPersonCalculated M ON E.ManagerID = M.PersonID AND
	(
		(@operation=0 AND E.ManagerID = @i) OR (@operation=1 AND E.ManagerID <> @i) OR
		(@operation=2 AND M.[Full Name] LIKE @t) OR (@operation=3 AND M.[Full Name] NOT LIKE @t)
	)

	-- Current Position
	ELSE IF @field_id=56
	INSERT TempX(BatchID, [ID])
	SELECT @batch_id, E.EmployeeID FROM Employee E
	INNER JOIN EmployeeComensation EC ON E.LastCompensationID = EC.CompensationID
	INNER JOIN Postion P ON EC.PositionID = P.PositionID AND
	(
		(@operation=0 AND EC.PositionID = @i) OR (@operation=1 AND EC.PositionID <> @i) OR
		(@operation=2 AND P.[Job Title] LIKE @t) OR (@operation=3 AND P.[Job Title] NOT LIKE @t)
	)

	-- Employment Status
	ELSE IF @field_id=90
	INSERT TempX(BatchID, [ID])
	SELECT @batch_id, E.EmployeeID FROM Employee E
	INNER JOIN EmployeeComensation EC ON E.LastCompensationID = EC.CompensationID
	INNER JOIN EmploymentStatus ES ON EC.EmploymentStatusID = ES.StatusID AND
	(
		(@operation=0 AND EC.StatusID = @i) OR (@operation=1 AND EC.StatusID <> @i) OR
		(@operation=2 AND ES.Status LIKE @t) OR (@operation=3 AND ES.Status NOT LIKE @t)
	)

	-- Position Status
	ELSE IF @field_id=91
	INSERT TempX(BatchID, [ID])
	SELECT @batch_id, E.EmployeeID FROM Employee E
	INNER JOIN EmployeeComensation EC ON E.LastCompensationID = EC.CompensationID
	INNER JOIN Postion P ON EC.PositionID = P.PositionID
	INNER JOIN PositionStatus PS ON P.PositionStatusID = PS.StatusID AND
	(
		(@operation=0 AND P.StatusID = @i) OR (@operation=1 AND P.StatusID <> @i) OR
		(@operation=2 AND PS.Status LIKE @t) OR (@operation=3 AND PS.Status NOT LIKE @t)
	)
END





ELSE -- And
BEGIN 
	-- Active Employee
	IF @field_id = 1013 DELETE TempX
	FROM TempX X INNER JOIN Employee E
	ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID AND
	((@operation=1 AND E.[Active Employee] = @f) OR (@operation=0 AND E.[Active Employee] <> @f))

	-- Location
	IF @field_id=54 DELETE TempX
	FROM TempX X INNER JOIN Employee E
	ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID 
	INNER JOIN Location L ON E.LocationID = L.LocationID AND
	(
		(@operation=1 AND E.LocationID = @i) OR (@operation=0 AND E.LocationID <> @i) OR
		(@operation=3 AND L.[List As] LIKE @t) OR (@operation=2 AND L.[List As] NOT LIKE @t)
	)

	-- Department
	ELSE IF @field_id=55 DELETE TempX
	FROM TempX X INNER JOIN Employee E
	ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID 
	INNER JOIN Department D ON E.DepartmentID = D.DepartmentID AND 
	(
		(@operation=1 AND E.DepartmentID = @i) OR (@operation=0 AND E.DepartmentID <> @i) OR
		(@operation=3 AND D.Department LIKE @t) OR (@operation=2 AND D.Department NOT LIKE @t)
	)

	-- Division
	ELSE IF @field_id=53 DELETE TempX
	FROM TempX X INNER JOIN Employee E
	ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID 
	INNER JOIN Division V ON E.DivisionID = V.DivisionID AND
	(
		(@operation=1 AND E.DivisionID = @i) OR (@operation=0 AND E.DivisionID <> @i) OR
		(@operation=3 AND V.Division LIKE @t) OR (@operation=2 AND V.Division NOT LIKE @t)
	)

	-- Shift
	ELSE IF @field_id=51 DELETE TempX
	FROM TempX X INNER JOIN Employee E
	ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID 
	INNER JOIN Shift S ON E.ShiftID = S.ShiftID AND
	(
		(@operation=1 AND E.ShiftID = @i) OR (@operation=0 AND E.ShiftID <> @i) OR
		(@operation=3 AND S.Shift LIKE @t) OR (@operation=2 AND S.Shift NOT LIKE @t)
	)

	-- Manager
	ELSE IF @field_id=52 DELETE TempX
	FROM TempX X INNER JOIN Employee E
	ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID 
	INNER JOIN vwPersonCalculated M ON E.ManagerID = M.PersonID AND
	(
		(@operation=1 AND E.ManagerID = @i) OR (@operation=0 AND E.ManagerID <> @i) OR
		(@operation=3 AND M.[Full Name] LIKE @t) OR (@operation=2 AND M.[Full Name] NOT LIKE @t)
	)

	-- Current Position
	ELSE IF @field_id=56 DELETE TempX
	FROM TempX X INNER JOIN Employee E
	ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID 
	INNER JOIN EmployeeComensation EC ON E.LastCompensationID = EC.CompensationID
	INNER JOIN Postion P ON EC.PositionID = P.PositionID AND
	(
		(@operation=1 AND EC.PositionID = @i) OR (@operation=0 AND EC.PositionID <> @i) OR
		(@operation=3 AND P.[Job Title] LIKE @t) OR (@operation=2 AND P.[Job Title] NOT LIKE @t)
	)

	-- Employment Status
	ELSE IF @field_id=90 DELETE TempX
	FROM TempX X INNER JOIN Employee E
	ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID 
	INNER JOIN EmployeeComensation EC ON E.LastCompensationID = EC.CompensationID
	INNER JOIN EmploymentStatus ES ON EC.EmploymentStatusID = ES.StatusID AND
	(
		(@operation=1 AND EC.StatusID = @i) OR (@operation=0 AND EC.StatusID <> @i) OR
		(@operation=3 AND ES.Status LIKE @t) OR (@operation=2 AND ES.Status NOT LIKE @t)
	)

	-- Position Status
	ELSE IF @field_id=91 DELETE TempX
	FROM TempX X INNER JOIN Employee E
	ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID 
	INNER JOIN EmployeeComensation EC ON E.LastCompensationID = EC.CompensationID
	INNER JOIN Postion P ON EC.PositionID = P.PositionID
	INNER JOIN PositionStatus PS ON P.PositionStatusID = PS.StatusID AND
	(
		(@operation=1 AND P.StatusID = @i) OR (@operation=0 AND P.StatusID <> @i) OR
		(@operation=3 AND PS.Status LIKE @t) OR (@operation=2 AND PS.Status NOT LIKE @t)
	)
END
GO
GRANT EXEC ON dbo.spPersonListPrepareBatch3 TO public
IF OBJECT_ID('dbo.spLocationCount') IS NOT NULL DROP PROC dbo.spLocationCount
GO
CREATE PROC dbo.spLocationCount
	@count int out
AS
SELECT @count = COUNT(*) FROM Location
GO
GRANT EXEC ON dbo.spLocationCount TO public
IF OBJECT_ID('dbo.spEmployeeListWithPStatus') IS NOT NULL DROP PROC dbo.spEmployeeListWithPStatus
GO
CREATE PROC dbo.spEmployeeListWithPStatus
	@status_id int,
	@active bit
AS
SELECT P.[List As], P.PersonID
FROM vwPersonListAs P
INNER JOIN Employee E ON P.PersonID = E.EmployeeID
INNER JOIN EmployeeCompensation C ON E.LastCompensationID = C.CompensationID
INNER JOIN Position POS ON C.PositionID = POS.PositionID AND POS.StatusID = @status_id
GO
GRANT EXEC ON dbo.spEmployeeListWithPStatus TO public
IF OBJECT_ID('dbo.spEmployeeListWithEStatus') IS NOT NULL DROP PROC dbo.spEmployeeListWithEStatus
GO
CREATE PROC dbo.spEmployeeListWithEStatus
	@status_id int,
	@active bit
AS
SELECT P.[List As], P.PersonID
FROM vwPersonListAs P
INNER JOIN Employee E ON P.PersonID = E.EmployeeID
INNER JOIN EmployeeCompensation C ON E.LastCompensationID = C.CompensationID AND C.[EmploymentStatusID] = @status_id
GO
GRANT EXEC ON dbo.spEmployeeListWithEStatus TO public
GO
ALTER PROC dbo.spEmploymentStatusList
	@exclude_unused bit = 0
AS
SET NOCOUNT ON

IF @exclude_unused = 1
SELECT * FROM EmploymentStatus WHERE StatusID IN
(
	SELECT DISTINCT EmploymentStatusID FROM EmployeeCompensation
)
ORDER BY Status

ELSE
SELECT * FROM EmploymentStatus ORDER BY Status
GO
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [id] = OBJECT_ID('ReportTemplate') AND [name] = 'EmploymentStatusID')
ALTER TABLE ReportTemplate ADD EmploymentStatusID int NULL
GO
ALTER PROC dbo.spReportTemplateInsert
	@template_name varchar(50),
	@advanced_bit bit,
	@manager_id int,
	@department_id int,
	@division_id int,
	@shift_id int,
	@location_id int,
	@employment_status_id int = NULL,
	@no_manager bit,
	@template_id int OUT
AS
SET NOCOUNT ON 

INSERT ReportTemplate(TemplateName,Advanced,ManagerID,DepartmentID,DivisionID,ShiftID,LocationID,EmploymentStatusID,NoManager)
VALUES(@template_name,@advanced_bit,@manager_id,@department_id,@division_id,@shift_id,@location_id,@employment_status_id,@no_manager)

SELECT @template_id = SCOPE_IDENTITY()
GO
ALTER PROC dbo.spReportTemplateUpdate
	@template_id int,
	@template_name varchar(50),
	@advanced_bit bit,
	@manager_id int,
	@department_id int,
	@division_id int,
	@employment_status_id int = NULL,
	@shift_id int,
	@location_id int,
	@no_manager bit
AS
SET NOCOUNT ON 

UPDATE ReportTemplate
SET	TemplateName = @template_name,
	Advanced = @advanced_bit,
	ManagerID = @manager_id,
	DepartmentID = @department_id,
	DivisionID =@division_id,
	ShiftID = @shift_id,
	EmploymentStatusID = @employment_status_id,
	LocationID = @location_id,
	NoManager = @no_manager

WHERE TemplateID = @template_id

IF @advanced_bit = 0 DELETE ReportTemplateAdvanced WHERE TemplateID = @template_id
GO
ALTER PROC spLeaveGetUseOrLoseDay
	@employee_id int,
	@type_id int,
	@day_in int,
	@date datetime out
AS
DECLARE @day_out int

SET NOCOUNT ON

SET @day_out = 0x7FFFFFFF
SELECT @day_out = [Day past 1900] FROM vwEmployeeLeaveEarned WHERE [Limit Adjustment] = 1 AND EmployeeID = @employee_id AND TypeID = @type_id AND [Day past 1900] >= @day_in
SELECT @day_out = [Day past 1900] FROM vwEmployeeLeaveEarned WHERE [Accrual] = 1 AND EmployeeID = @employee_id AND TypeID = @type_id AND [Day past 1900] BETWEEN @day_in AND @day_out

SET @date = dbo.GetDateFromDaysPast1900(@day_out)
GO
ALTER PROC dbo.spPersonListPrepareBatch2
	@batch_id int,
	@manager_id int,
	@no_manager bit,
	@department_id int,
	@division_id int,
	@shift_id int,
	@location_id int,
	@employment_status_id int = NULL,
	@active bit = NULL,
	@employee_id int = NULL
AS
SET NOCOUNT ON

INSERT TempX(BatchID, [ID])
SELECT @batch_id, EmployeeID FROM Employee WHERE
(@employee_id IS NULL OR EmployeeID = @employee_id) AND
((@manager_id IS NULL OR ManagerID = @manager_id) OR (@no_manager = 1 AND @manager_id IS NULL)) AND
(@department_id IS NULL OR DepartmentID = @department_id) AND
(@division_id IS NULL OR DivisionID = @division_id) AND
(@employment_status_id IS NULL OR EXISTS(
	SELECT * FROM EmployeeCompensation EC WHERE EC.EmployeeID = Employee.EmployeeID AND Employee.LastCompensationID = EC.CompensationID AND EC.EmploymentStatusID = @employment_status_id
)) AND
(@shift_id IS NULL OR ShiftID = @shift_id) AND
(@location_id IS NULL OR LocationID = @location_id) AND
(@active IS NULL OR [Active Employee] = @active)
GO
IF (SELECT [Server Version] FROM Constant) < 20
BEGIN
	DECLARE @template_id int

	INSERT ReportTemplate([TemplateName], EmploymentStatusID)
	VALUES('Contractors', 7)

	SET @template_id = SCOPE_IDENTITY()

	INSERT ReportTemplateField(TemplateID, FieldID) VALUES(@template_id, 2)
	INSERT ReportTemplateField(TemplateID, FieldID) VALUES(@template_id, 4)
	INSERT ReportTemplateField(TemplateID, FieldID) VALUES(@template_id, 83)
	INSERT ReportTemplateField(TemplateID, FieldID) VALUES(@template_id, 7)
	INSERT ReportTemplateField(TemplateID, FieldID) VALUES(@template_id, 13)
	INSERT ReportTemplateField(TemplateID, FieldID) VALUES(@template_id, 52)
	INSERT ReportTemplateField(TemplateID, FieldID) VALUES(@template_id, 54)
	INSERT ReportTemplateField(TemplateID, FieldID) VALUES(@template_id, 58)
END
GO
UPDATE Constant SET CarryoverSourceLeaveTypeID = NULL, CarryoverTargetLeaveTypeID = NULL
WHERE CarryoverSourceLeaveTypeID NOT IN (SELECT TypeID FROM LeaveType) OR CarryoverTargetLeaveTypeID NOT IN (SELECT TypeID FROM LeaveType)


IF OBJECT_ID('FK_Constant_CarryoverSourceLeaveTypeID') IS NULL
ALTER TABLE [dbo].[Constant] ADD CONSTRAINT [FK_Constant_CarryoverSourceLeaveTypeID] FOREIGN KEY 
(
	[CarryoverSourceLeaveTypeID]
) REFERENCES [dbo].[LeaveType] (
	[TypeID]
)

IF OBJECT_ID('FK_Constant_CarryoverTargetLeaveTypeID') IS NULL
ALTER TABLE [dbo].[Constant] ADD CONSTRAINT [FK_Constant_CarryoverTargetLeaveTypeID] FOREIGN KEY 
(
	[CarryoverTargetLeaveTypeID]
) REFERENCES [dbo].[LeaveType] (
	[TypeID]
)
GO
ALTER PROCEDURE dbo.spEmployeeLeaveApplyLimits
	@employee_id int,
	@type_id int, -- type of leave (not type of limit)
	@start_day int,
	@stop_day int,
	@limit_id int
AS
DECLARE @day int,
	@seconds int,
	@year int,
	@unused int,
	@max_seconds int,
	@period_id int,
	@adjustment int,
	@leave_id int,
	@month int, 
	@seniority_day int,
	@rows int,
	@current datetime,
	@target_type_id int,
	@start smalldatetime, 
	@stop smalldatetime,
	@current_day int

SET NOCOUNT ON

SELECT @target_type_id = NULL, @max_seconds = 0x7FFFFFFF -- Defaults to no limit

SELECT @max_seconds = [Max Seconds], @period_id = PeriodID FROM LeaveLimit WHERE LimitID = @limit_id
SELECT @target_type_id = CarryoverTargetLeaveTypeID FROM Constant WHERE CarryoverSourceLeaveTypeID = @type_id
SELECT @start = dbo.GetDateFromDaysPast1900(@start_day), @stop = dbo.GetDateFromDaysPast1900(@stop_day)

IF @limit_id IS NOT NULL
BEGIN
	IF (@period_id = 0)
	BEGIN
		SELECT @rows = 1
	
		WHILE @rows > 0
		BEGIN
			SELECT TOP 1 @day = [Day past 1900], @unused = Unused FROM EmployeeLeaveUnused 
			WHERE EmployeeID = @employee_id AND TypeID = @type_id AND Unused > @max_seconds AND [Day past 1900] BETWEEN @start_day AND @stop_day ORDER BY [Day past 1900]
			SELECT @rows = @@ROWCOUNT

			IF @rows > 0
			BEGIN
				SELECT @adjustment = @max_seconds - @unused
				EXEC spEmployeeLeaveInsertAdjustment @employee_id, @type_id, @adjustment, @day, @target_type_id
			END
		END
	END
	ELSE IF (@period_id = 4)
	BEGIN
		SELECT @month = MONTH(@start), @year = YEAR(@start)
		SELECT @day = [Day]
		FROM LeaveLimit
		WHERE TypeID = @type_id AND LimitID = @limit_id

		IF @day < DAY(@start) SET @month = @month + 1
	
		SET @start = dbo.AddMonthsToDY(@month, @day, @year)

		WHILE @start <= @stop
		BEGIN
			SET @current_day = DATEDIFF(dd, 0, @start)
			SELECT TOP 1 @unused = Unused FROM EmployeeLeaveUnused WHERE EmployeeID = @employee_id AND TypeID = @type_id AND [Day past 1900] <= @current_day ORDER BY [Day past 1900] DESC
		
			IF @unused > @max_seconds
			BEGIN
				SELECT @adjustment = @max_seconds - @unused
				EXEC spEmployeeLeaveInsertAdjustment @employee_id, @type_id, @adjustment, @current_day, @target_type_id
			END

			SET @month = @month + 1
			SET @start = dbo.AddMonthsToDY(@month, @day, @year)
		END
	END
	ELSE
	BEGIN

		IF (@period_id = 1)
		BEGIN
			SELECT @day = [Day], @month = [Month]
			FROM LeaveLimit
			WHERE TypeID = @type_id AND LimitID = @limit_id
		END

		ELSE IF (@period_id = 2 OR @period_id = 3)
		BEGIN
			SELECT @seniority_day = [Seniority Begins Day past 1900]
			FROM Employee
			WHERE EmployeeID = @employee_id

			IF @period_id = 3 SET @seniority_day = @seniority_day - 1

			SET @day = DAY(@seniority_day)
			SET @month = MONTH(@seniority_day)
		END
	
		DECLARE @stop_year int
	
		SELECT @start = dbo.GetDateFromDaysPast1900(@start_day), @stop = dbo.GetDateFromDaysPast1900(@stop_day)
		SELECT @year = YEAR(@start), @stop_year = YEAR(@stop)
	
		if DAY(@start) + MONTH(@start) * 31 > @day + @month * 31 
			SELECT @year = @year  + 1

		if DAY(@stop) + MONTH(@stop) * 31 < @day + @month * 31 
			SELECT @stop_year = @stop_year  - 1

	
		WHILE @year <= @stop_year
		BEGIN
			SELECT @current = dbo.GetDateFromMDY(@month, @day, @year)
			SELECT @current_day = DATEDIFF(dd, 0, @current)

			SELECT TOP 1 @unused = Unused FROM EmployeeLeaveUnused WHERE EmployeeID = @employee_id AND TypeID = @type_id AND [Day past 1900] <= @current_day ORDER BY [Day past 1900] DESC
		
			IF @unused > @max_seconds
			BEGIN
				SELECT @adjustment = @max_seconds - @unused
				EXEC spEmployeeLeaveInsertAdjustment @employee_id, @type_id, @adjustment, @current_day, @target_type_id
			END

			SELECT @year = @year + 1
		END
	END
END
GO
IF OBJECT_ID('dbo.FK_Position_PositionStatus') IS NOT NULL ALTER TABLE dbo.[Position] DROP CONSTRAINT FK_Position_PositionStatus

SELECT * INTO #PS FROM PositionStatus

DROP TABLE PositionStatus

CREATE TABLE [dbo].[PositionStatus] (
	[StatusID] [int] IDENTITY (1, 1) NOT NULL ,
	[Status] [varchar] (50) NOT NULL 
) ON [PRIMARY]

SET IDENTITY_INSERT dbo.PositionStatus ON
INSERT dbo.PositionStatus(StatusID, Status) SELECT StatusID, Status FROM #PS
SET IDENTITY_INSERT dbo.PositionStatus OFF

DROP TABLE #PS

ALTER TABLE dbo.PositionStatus ADD CONSTRAINT
	PK_PositionStatus PRIMARY KEY CLUSTERED 
	(
	StatusID
	) WITH FILLFACTOR = 90 ON [PRIMARY]

ALTER TABLE dbo.[Position] WITH NOCHECK ADD CONSTRAINT
	FK_Position_PositionStatus FOREIGN KEY
	(
	StatusID
	) REFERENCES dbo.PositionStatus
	(
	StatusID
	)
GO
IF OBJECT_ID('dbo.BuildListAsOnLocationChange') IS NOT NULL DROP TRIGGER dbo.BuildListAsOnLocationChange
IF OBJECT_ID('dbo.spLocationGetListAs2') IS NOT NULL DROP PROC dbo.spLocationGetListAs2
GO
CREATE PROC dbo.spLocationGetListAs2
	@city varchar(50),
	@state varchar(50),
	@zip varchar(50),
	@address varchar(50),
	@list_as varchar(50) OUT
AS
DECLARE @unique_state bit
DECLARE @unique_city bit
DECLARE @unique_city_state  bit
DECLARE @unique_city_state_zip bit

SET NOCOUNT ON

SELECT @unique_state = 1
SELECT @unique_state = 0 FROM Location GROUP BY State HAVING COUNT(*) > 1
SELECT @unique_state = 0 FROM Location WHERE State = @state

SELECT @unique_city = 1
SELECT @unique_city = 0 FROM Location GROUP BY City HAVING COUNT(*) > 1
SELECT @unique_city = 0 FROM Location WHERE City = @city

SELECT @unique_city_state = 1
SELECT @unique_city_state = 0 FROM Location GROUP BY City, State HAVING COUNT(*) > 1
SELECT @unique_city_state = 0 FROM Location WHERE City = @city AND State = @state

SELECT @unique_city_state_zip = 1
SELECT @unique_city_state_zip = 0 FROM Location GROUP BY City, State, Zip HAVING COUNT(*) > 1
SELECT @unique_city_state_zip = 0 FROM Location WHERE City = @city AND State = @state AND ZIP = @zip

IF @unique_city = 1 SET @list_as = @city
ELSE IF @unique_state = 1 SET @list_as = @state
ELSE IF @unique_city_state = 1 SET @list_as = SUBSTRING(@city + ' ' + @state, 1, 50)
ELSE IF @unique_city_state_zip = 1 SET @list_as = SUBSTRING(@city + ' ' + @state + ' ' + @zip, 1, 50)
ELSE SET @list_as = SUBSTRING(@city + ' ' + @state + ' ' + @address, 1, 50)
GO
GRANT EXEC ON dbo.spLocationGetListAs2 TO public
GO
ALTER PROC dbo.spLocationUpdate
	@assistant varchar(50),
	@phone varchar(50),
	@address varchar(50),
	@address2 varchar(50),
	@city varchar(50),
	@county varchar(50),
	@state varchar(50),
	@zip varchar(50),
	@country varchar(50),
	@eeo_unit varchar(50),
	@description varchar(4000),
	@location_id int,
	@list_as varchar(50) = NULL
AS
SET NOCOUNT ON

IF @list_as IS NULL OR LEN(@list_as) = 0 EXEC dbo.spLocationGetListAs2 @city, @state, @zip, @address, @list_as OUT

UPDATE Location SET 
	Assistant = @assistant,
	Phone = @phone,
	Address = @address,
	[Address (cont.)] = @address2,
	City = @city,
	County = @county,
	State = @state,
	ZIP = @zip,
	Country = @country,
	[Description] = @description,
	[EEO Unit] = @eeo_unit,
	[List As] = @list_as
WHERE LocationID = @location_id
GO
ALTER PROC dbo.spLocationInsert
	@assistant varchar(50),
	@phone varchar(50),
	@address varchar(50),
	@address2 varchar(50),
	@city varchar(50),
	@county varchar(50),
	@state varchar(50),
	@zip varchar(50),
	@country varchar(50),
	@eeo_unit varchar(50),
	@description varchar(4000),
	@location_id int OUT,
	@list_as varchar(50) = NULL
AS
SET NOCOUNT ON

IF @list_as IS NULL OR LEN(@list_as) = 0 EXEC dbo.spLocationGetListAs2 @city, @state, @zip, @address, @list_as OUT

INSERT Location(Assistant,Phone,Address,[Address (cont.)],City,County,State,ZIP,Country,[EEO Unit],[Description], [List As]) 
VALUES(@assistant,@phone,@address, @address2, @city, @county, @state, @zip, @country,@eeo_unit,@description, @list_as)
SELECT @location_id = SCOPE_IDENTITY()
GO
IF OBJECT_ID('dbo.spLocationGetFirst') IS NOT NULL DROP PROC dbo.spLocationGetFirst
GO
CREATE PROC dbo.spLocationGetFirst
	@location_id int out
AS
SET NOCOUNT ON

SELECT TOP 1 @location_id = LocationID FROM Location ORDER BY [List As]
GO
GRANT EXEC ON dbo.spLocationGetFirst TO public
IF OBJECT_ID('dbo.spLocationFind') IS NOT NULL DROP PROC dbo.spLocationFind
GO
CREATE PROC dbo.spLocationFind
	@text varchar(50)
AS
DECLARE @t varchar(51)

SET NOCOUNT ON

SET @t = '%' + @text + '%'

SELECT * FROM Location WHERE 
[List As] LIKE @t OR
[State] LIKE @t OR
[City] LIKE @t OR
[Address] LIKE @t OR
[Address (cont.)] LIKE @t
ORDER BY [List As]
GO
GRANT EXEC ON dbo.spLocationFind TO public
GO
ALTER PROC dbo.spLocationGetListAs
	@location_id int,
	@list_as varchar(50) OUT
AS
SELECT @list_as = ''
SELECT @list_as = [List As] FROM Location WHERE LocationID = @Location_id
GO

IF OBJECT_ID('dbo.spEmployeeLeaveForefeited') IS NOT NULL DROP PROC dbo.spEmployeeLeaveForefeited
GO
CREATE PROC dbo.spEmployeeLeaveForefeited
	@start_day int, 
	@stop_day int, 
	@batch_id int,
	@authorized bit OUT
AS
SET NOCOUNT ON

EXEC spPermissionGetOnPeopleForCurrentUser2 @batch_id, 10003
DELETE TempX WHERE BatchID = @batch_id AND (X & 1) = 0
SELECT @authorized = CASE WHEN @@ROWCOUNT = 0 THEN 1 ELSE 0 END

SELECT EmployeeID, TypeID, Seconds = -SUM(Seconds)
INTO #Forfeited
FROM EmployeeLeaveEarned L
INNER JOIN TempX X ON L.[Auto] = 2 AND X.BatchID = @batch_id AND L.EmployeeID = X.[ID] AND L.[Day past 1900] BETWEEN @start_day AND @stop_day
GROUP BY EmployeeID, TypeID


SELECT DISTINCT TypeID INTO #T FROM #Forfeited
SELECT DISTINCT EmployeeID INTO #E FROM #Forfeited

SELECT #E.EmployeeID, Employee = P.[List As], #T.TypeID, T.Type, Hrs = ISNULL(F.Seconds / 3600.0, 0)
FROM #E
INNER JOIN vwPersonListAs P ON #E.EmployeeID = P.PersonID
CROSS JOIN #T
INNER JOIN LeaveType T ON #T.TypeID = T.TypeID
LEFT JOIN #Forfeited F ON F.TypeID = #T.TypeID AND F.EmployeeID = #E.EmployeeID
ORDER BY P.[List As], T.[Order]

DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1
GO
GRANT EXEC ON dbo.spEmployeeLeaveForefeited TO public
GO
ALTER PROC dbo.spPositionStatusDelete
	@status_id int
AS
SET NOCOUNT ON

DELETE PositionStatus WHERE StatusID = @status_id
GO

IF OBJECT_ID('[dbo].[Language]') IS NULL
BEGIN
	CREATE TABLE [dbo].[Language] (
		[LanguageID] [int] NOT NULL ,
		[Language] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL 
	) ON [PRIMARY]
	
	ALTER TABLE [dbo].[Language] WITH NOCHECK ADD 
		CONSTRAINT [PK_Language] PRIMARY KEY  CLUSTERED 
		(
			[LanguageID]
		) WITH  FILLFACTOR = 90  ON [PRIMARY] 
	
	ALTER TABLE [dbo].[Language] ADD 
		CONSTRAINT [IX_Language_Language] UNIQUE  NONCLUSTERED 
		(
			[Language]
		) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
		CONSTRAINT [CK_Language_LanguageNotBlank] CHECK (len([Language]) > 0),
		CONSTRAINT [CK_Language_InvalidLanguageID] CHECK ([LanguageID] = 0x40000000 or ([LanguageID] = 0x20000000 or ([LanguageID] = 0x10000000 or ([LanguageID] = 0x08000000 or ([LanguageID] = 0x04000000 or ([LanguageID] = 0x02000000 or ([LanguageID] = 0x01000000 or ([LanguageID] = 0x800000 or ([LanguageID] = 0x400000 or ([LanguageID] = 0x200000 or ([LanguageID] = 0x100000 or ([LanguageID] = 0x080000 or ([LanguageID] = 0x040000 or ([LanguageID] = 0x020000 or ([LanguageID] = 0x010000 or ([LanguageID] = 0x8000 or ([LanguageID] = 0x4000 or ([LanguageID] = 0x2000 or ([LanguageID] = 0x1000 or ([LanguageID] = 0x0800 or ([LanguageID] = 0x0400 or ([LanguageID] = 0x0200 or ([LanguageID] = 0x0100 or ([LanguageID] = 0x80 or ([LanguageID] = 0x40 or ([LanguageID] = 0x20 or ([LanguageID] = 0x10 or ([LanguageID] = 8 or ([LanguageID] = 4 or ([LanguageID] = 2 or [LanguageID] = 1))))))))))))))))))))))))))))))


	INSERT Language(LanguageID, Language) VALUES(1, 'English')

	ALTER TABLE [dbo].[PersonX] ADD PrimaryLanguageID int, [Secondary Language Mask] int DEFAULT 0 NOT NULL
	ALTER TABLE [dbo].[PersonX] ADD CONSTRAINT [FK_PersonX_Language] FOREIGN KEY 
	(
		[PrimaryLanguageID]
	) REFERENCES [dbo].[Language] (
		[LanguageID]
	)	

	INSERT PermissionAttribute(AttributeID, Attribute, [Scope Possible Mask], [Permission Possible Mask])
	VALUES(10007, 'Languages Known', 255, 3)
END
GO
IF OBJECT_ID('dbo.vwPersonXLanguages') IS NOT NULL DROP VIEW dbo.vwPersonXLanguages
GO
CREATE VIEW dbo.vwPersonXLanguages
AS
SELECT P.PersonID, [Primary Language] = ISNULL(L.Language, ''), PrimaryLanguageID, P.[Secondary Language Mask], [Language Mask] = P.[Secondary Language Mask] | ISNULL(P.PrimaryLanguageID, 0)
FROM PersonX P LEFT JOIN Language L ON P.PrimaryLanguageID = L.LanguageID
GO
ALTER VIEW dbo.vwPersonX
AS
SELECT 
P.PersonID, P. RaceID, P. I9StatusID, P. SSN, P. [Renew I9 Status Day past 1900], P. [Country of Citizenship], P. Visa, P. [Visa Expires Day past 1900], P. Passport, P. [Passport Expires Day past 1900], P. [DOB Day past 1900], P. [Driver License], P. [Driver License State], P.
[Driver License Expires Day past 1900], P. [Driver Insurance Expires Day past 1900], P. MilitaryBranchID, P. Reserves, P. [Commercial Driver License], P. MaritalStatusID, P. Dependents, P. Disabled, P. Smoker, P. Spouse, P. Children,
R.Race, [I9 Status] = I.Status,
[Marital Status] = S.Status,
DOB = dbo.GetDateFromDaysPast1900([DOB Day past 1900]),
[Driver License Expires] = dbo.GetDateFromDaysPast1900([Driver License Expires Day past 1900]),
[Driver Insurance Expires] = dbo.GetDateFromDaysPast1900([Driver Insurance Expires Day past 1900]),
[Renew I9 Status] = dbo.GetDateFromDaysPast1900([Renew I9 Status Day past 1900]),
[Visa Expires] = dbo.GetDateFromDaysPast1900([Visa Expires Day past 1900]),
[Passport Expires] = dbo.GetDateFromDaysPast1900([Passport Expires Day past 1900]),
[Military Service] = CASE WHEN P.MilitaryBranchID IS NULL THEN '' ELSE
	B.Branch + CASE WHEN P.[Reserves] = 1 AND B.[Reserves Apply] = 1 THEN ' Reserves' ELSE '' END
END,
[Birth Day past 1900] = dbo.GetBirthdayFromDOB([DOB Day past 1900], GETDATE())
FROM PersonX P
INNER JOIN MaritalStatus S ON  P.MaritalStatusID = S.StatusID
INNER JOIN Race R ON P.RaceID = R.RaceID
INNER JOIN I9Status I ON P.I9StatusID = I.StatusID
LEFT JOIN MilitaryBranch B ON P.MilitaryBranchID = B.BranchID
GO
IF NOT EXISTS(SELECT * FROM Error WHERE ErrorID = 50045)
INSERT Error(ErrorID, Error)
VALUES (50045, 'This language cannot be added because the system can only track 31 languages.')

IF OBJECT_ID('dbo.spPersonXUpdateLanguages') IS NOT NULL DROP PROC dbo.spPersonXUpdateLanguages
IF OBJECT_ID('dbo.spPersonXSelectLanguages') IS NOT NULL DROP PROC dbo.spPersonXSelectLanguages
GO
CREATE PROC dbo.spPersonXUpdateLanguages
	@person_id int,
	@primary_language_id int,
	@secondary_language_mask int
AS
DECLARE @authorized bit

SET NOCOUNT ON

EXEC spPermissionInsureForCurrentUserOnPerson @person_id, 10007, 2, @authorized out
IF @authorized = 1 UPDATE PersonX SET PrimaryLanguageID = @primary_language_id, [Secondary Language Mask] = @secondary_language_mask WHERE PersonID = @person_id
GO
CREATE PROC dbo.spPersonXSelectLanguages
	@person_id int
AS
DECLARE @authorized bit

SET NOCOUNT ON

EXEC spPermissionInsureForCurrentUserOnPerson @person_id, 10007, 1, @authorized out
IF @authorized = 1 SELECT * FROM vwPersonXLanguages WHERE PersonID = @person_id
GO
GRANT EXEC ON dbo.spPersonXUpdateLanguages TO public
GRANT EXEC ON dbo.spPersonXSelectLanguages TO public

IF OBJECT_ID('dbo.spLanguageInsert') IS NOT NULL DROP PROC dbo.spLanguageInsert
IF OBJECT_ID('dbo.spLanguageUpdate') IS NOT NULL DROP PROC dbo.spLanguageUpdate
IF OBJECT_ID('dbo.spLanguageDelete') IS NOT NULL DROP PROC dbo.spLanguageDelete
IF OBJECT_ID('dbo.spLanguageList') IS NOT NULL DROP PROC dbo.spLanguageList
IF OBJECT_ID('dbo.spLanguageGetLanguageFromLanguageID') IS NOT NULL DROP PROC dbo.spLanguageGetLanguageFromLanguageID
GO
CREATE PROC dbo.spLanguageInsert
	@language varchar(50),
	@language_id int OUT
AS
SET NOCOUNT ON

DECLARE @continue bit
DECLARE @error bit
DECLARE @order int

SET NOCOUNT ON

SELECT @language_id = 1, @continue = 0, @error = 0

SELECT @continue = 1 FROM Language WHERE LanguageID = @language_id

WHILE @continue = 1
BEGIN
	SELECT @language_id = @language_id * 2, @continue = 0

	IF @language_id = 0x40000000
		SELECT @error = 1 FROM Language WHERE LanguageID = @language_id
	ELSE
		SELECT @continue = 1 FROM Language WHERE LanguageID = @language_id
END

IF @error = 1
	EXEC spErrorRaise 50045
ELSE
BEGIN
	INSERT Language(LanguageID, Language)
	VALUES(@language_id, @language)
END
GO
CREATE PROC dbo.spLanguageUpdate
	@language_id int,
	@language varchar(50)
AS
SET NOCOUNT ON
UPDATE Language SET Language = @language WHERE LanguageID = @language_id
GO
CREATE PROC dbo.spLanguageDelete
	@language_id int
AS
SET NOCOUNT ON
DELETE Language WHERE LanguageID = @language_id
GO
CREATE PROC dbo.spLanguageList
AS
SET NOCOUNT ON
SELECT * FROM Language ORDER BY Language
GO
CREATE PROC dbo.spLanguageGetLanguageFromLanguageID
	@language_id int,
	@language varchar(50) OUT
AS
SET NOCOUNT ON

SELECT @language = Language FROM Language WHERE LanguageID = @language_id
GO
GRANT EXEC ON dbo.spLanguageList TO public
GRANT EXEC ON dbo.spLanguageGetLanguageFromLanguageID TO public
GO
ALTER PROC dbo.spPermissionAssociateIDsForStoredProcsWithAffectedTable
AS
SET NOCOUNT ON

DELETE PermissionObjectX
DELETE PermissionObject

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(1, 'Organizational Departments', 
0,  
OBJECT_ID(N'dbo.spDepartmentUpdate'), 
OBJECT_ID(N'dbo.spDepartmentInsert'), 
OBJECT_ID(N'dbo.spDepartmentDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(2, 'Organizational Divisions', 
0,  
OBJECT_ID(N'dbo.spDivisionUpdate'), 
OBJECT_ID(N'dbo.spDivisionInsert'), 
OBJECT_ID(N'dbo.spDivisionDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(3, 'Job Categories',
0,
OBJECT_ID(N'dbo.spJobCategoryUpdate'), 
OBJECT_ID(N'dbo.spJobCategoryInsert'), 
OBJECT_ID(N'dbo.spJobCategoryDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(4, 'Certifications', 
0, 
OBJECT_ID(N'dbo.spCertificationUpdate'), 
OBJECT_ID(N'dbo.spCertificationInsert'), 
OBJECT_ID(N'dbo.spCertificationDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(5, 'Unions', 
0,  
OBJECT_ID(N'dbo.spUnionUpdate'), 
OBJECT_ID(N'dbo.spUnionInsert'), 
OBJECT_ID(N'dbo.spUnionDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(6, 'Organizational Locations', 
0,  
OBJECT_ID(N'dbo.spLocationUpdate'), 
OBJECT_ID(N'dbo.spLocationInsert'), 
OBJECT_ID(N'dbo.spLocationDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(7, 'Employee Review Rating Choices',  
0, 
OBJECT_ID(N'dbo.spEmployeeReviewRatingUpdate'), 
OBJECT_ID(N'dbo.spEmployeeReviewRatingInsert'), 
OBJECT_ID(N'dbo.spEmployeeReviewRatingDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(8, 'Employee Review Type Choices',  
0, 
OBJECT_ID(N'dbo.spEmployeeReviewTypeUpdate'), 
OBJECT_ID(N'dbo.spEmployeeReviewTypeInsert'), 
OBJECT_ID(N'dbo.spEmployeeReviewTypeDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(9, 'Employment Summary Reports',  
OBJECT_ID(N'dbo.spTurnover'),
0,
0,
0,
1)


INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(10, 'Tests',  
0, 
OBJECT_ID(N'dbo.spTestUpdate'), 
OBJECT_ID(N'dbo.spTestInsert'), 
OBJECT_ID(N'dbo.spTestDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(11, 'Training Courses',  
0, 
OBJECT_ID(N'dbo.spTrainingUpdate'), 
OBJECT_ID(N'dbo.spTrainingInsert'), 
OBJECT_ID(N'dbo.spTrainingDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(12, 'Employee Successor Stages',  
0, 
OBJECT_ID(N'dbo.spEmployeeSuccessorStageUpdate'), 
OBJECT_ID(N'dbo.spEmployeeSuccessorStageInsert'), 
OBJECT_ID(N'dbo.spEmployeeSuccessorStageDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(13, 'Positions',  
OBJECT_ID(N'dbo.spPositionSelect'), 
OBJECT_ID(N'dbo.spPositionUpdate'), 
OBJECT_ID(N'dbo.spPositionInsert'), 
OBJECT_ID(N'dbo.spPositionDelete'),
15)

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(13, 1, OBJECT_ID(N'spPositionList'))

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(14, 'Custom Fields',  
0, 
OBJECT_ID(N'dbo.spCustomFieldUpdate'), 
OBJECT_ID(N'dbo.spCustomFieldInsert'), 
OBJECT_ID(N'dbo.spCustomFieldDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(15, 'Form I9 Choices',  
0, 
OBJECT_ID(N'dbo.spI9StatusUpdate'), 
OBJECT_ID(N'dbo.spI9StatusInsert'), 
OBJECT_ID(N'dbo.spI9StatusDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(16, 'Marital Status',  
0, 
OBJECT_ID(N'dbo.spMaritalStatusUpdate'), 
OBJECT_ID(N'dbo.spMaritalStatusInsert'), 
OBJECT_ID(N'dbo.spMaritalStatusDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(17, 'Races',  
0, 
OBJECT_ID(N'dbo.spRaceUpdate'), 
OBJECT_ID(N'dbo.spRaceInsert'), 
OBJECT_ID(N'dbo.spRaceDelete'),
14)


INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(19, 'Injury Results',  
0, 
OBJECT_ID(N'dbo.spInjuryResultUpdate'), 
OBJECT_ID(N'dbo.spInjuryResultInsert'), 
OBJECT_ID(N'dbo.spInjuryResultDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(20, 'Skills',  
0, 
OBJECT_ID(N'dbo.spSkillUpdate'), 
OBJECT_ID(N'dbo.spSkillInsert'), 
OBJECT_ID(N'dbo.spSkillDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(21, 'Organizational Shifts',  
0, 
OBJECT_ID(N'dbo.spShiftUpdate'), 
OBJECT_ID(N'dbo.spShiftInsert'), 
OBJECT_ID(N'dbo.spShiftDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(22, 'Employee Creation\Deletion',
0,  
0, 
OBJECT_ID(N'dbo.spEmployeeInsert'), 
OBJECT_ID(N'dbo.spEmployeeDelete'),
12)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(23, 'Checklist for Termination',  
0, 
OBJECT_ID(N'dbo.spChecklistExitInterviewUpdate'), 
OBJECT_ID(N'dbo.spChecklistExitInterviewInsert'), 
OBJECT_ID(N'dbo.spChecklistExitInterviewDelete'),
14)


INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(24, 'Benefits',  
0, 
OBJECT_ID(N'dbo.spBenefitUpdate'), 
OBJECT_ID(N'dbo.spBenefitInsert'), 
OBJECT_ID(N'dbo.spBenefitDelete'),
14)


INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(24, 2, OBJECT_ID(N'spBenefitUpdate'))
INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(24, 2, OBJECT_ID(N'spTDRPUpdate'))
INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(24, 2, OBJECT_ID(N'spTDRPMatchingUpdate'))

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(24, 4, OBJECT_ID(N'spBenefitInsert'))
INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(24, 4, OBJECT_ID(N'spTDRPInsert'))
INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(24, 4, OBJECT_ID(N'spTDRPMatchingInsert'))

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(24, 8, OBJECT_ID(N'spTDRPMatchingDelete'))


INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(25, 'Equipment',  
OBJECT_ID(N'dbo.spEquipmentSelect'), 
OBJECT_ID(N'dbo.spEquipmentUpdate'), 
OBJECT_ID(N'dbo.spEquipmentInsert'), 
OBJECT_ID(N'dbo.spEquipmentDelete'),
15)

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(25, 1, OBJECT_ID(N'spEquipmentListCheckedIn'))


INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(25, 1, OBJECT_ID(N'spEquipmentListCheckedOut'))


INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(25, 1, OBJECT_ID(N'spEquipmentListForEmployee'))




INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(26, 'Leave Plans',  
0, 
OBJECT_ID(N'dbo.spLeavePlanUpdate'), 
OBJECT_ID(N'dbo.spLeavePlanInsert'), 
OBJECT_ID(N'dbo.spLeavePlanDelete'),
14)


INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(26, 4, OBJECT_ID(N'spLeavePlanAutoCreate'))

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(26, 2, OBJECT_ID(N'spLeaveRateInsert'))

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(26, 2, OBJECT_ID(N'spCompanyUpdateCarryover'))





INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(26, 1, OBJECT_ID(N'spLeaveRateList'))

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(26, 2, OBJECT_ID(N'spLeaveRateClear'))

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(26, 1, OBJECT_ID(N'spLeaveLimitList'))

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(26, 1, OBJECT_ID(N'spLeaveLimitSelect'))

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(26, 2, OBJECT_ID(N'spLeaveLimitUnlimit'))

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(26, 2, OBJECT_ID(N'spLeaveLimitUpdate'))

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(27, 'Holidays',  
0, 
OBJECT_ID(N'dbo.spHolidayUpdate'), 
OBJECT_ID(N'dbo.spHolidayInsert'), 
OBJECT_ID(N'dbo.spHolidayDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(28, 'Leave Denial Reasons',  
0, 
OBJECT_ID(N'dbo.spDenialReasonUpdate'), 
OBJECT_ID(N'dbo.spDenialReasonInsert'), 
OBJECT_ID(N'dbo.spDenialReasonDelete'),
14)


INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(30, 'Standard Tasks',  
0, 
OBJECT_ID(N'dbo.spStandardTaskUpdate'), 
OBJECT_ID(N'dbo.spStandardTaskInsert'), 
OBJECT_ID(N'dbo.spStandardTaskDelete'),
14)




INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(32, 'Licensing', 
0, 
OBJECT_ID(N'dbo.spLicenseUpdate'), 
OBJECT_ID(N'dbo.spLicenseInsert'), 
OBJECT_ID(N'dbo.spLicenseDelete'),
14)



INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(33, 'Pay Grades', 
OBJECT_ID(N'dbo.spPayGradeList'), 
OBJECT_ID(N'dbo.spPayGradeUpdate'), 
OBJECT_ID(N'dbo.spPayGradeInsert'), 
OBJECT_ID(N'dbo.spPayGradeDelete'),
15)

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(33, 1, OBJECT_ID(N'dbo.spPayGradeList2'))

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(34, 'Leave, ''About Extended Leave'' Note', 
0, 
OBJECT_ID(N'dbo.spConstantUpdateLeaveNote'), 
0,
0,
2)


INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(35, 'Leave Types', 
0, 
OBJECT_ID(N'dbo.spLeaveTypeUpdate'), 
OBJECT_ID(N'dbo.spLeaveTypeInsert'), 
OBJECT_ID(N'dbo.spLeaveTypeDelete'),
14)

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(35, 2, OBJECT_ID(N'dbo.spLeaveTypeAddStateFML'))



INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(36, 'Position Status', 
0, 
OBJECT_ID(N'dbo.spPositionStatusUpdate'), 
OBJECT_ID(N'dbo.spPositionStatusInsert'), 
OBJECT_ID(N'dbo.spPositionStatusDelete'),
14)


INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(37, 'Employment Status', 
0, 
OBJECT_ID(N'dbo.spEmploymentStatusUpdate'), 
OBJECT_ID(N'dbo.spEmploymentStatusInsert'), 
OBJECT_ID(N'dbo.spEmploymentStatusDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(38, 'Checklist for New Hires',  
0, 
OBJECT_ID(N'dbo.spChecklistNewHireUpdate'), 
OBJECT_ID(N'dbo.spChecklistNewHireInsert'), 
OBJECT_ID(N'dbo.spChecklistNewHireDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(39, 'Leave Approval Types',  
0, 
OBJECT_ID(N'dbo.spChecklistNewHireUpdate'), 
OBJECT_ID(N'dbo.spChecklistNewHireInsert'), 
OBJECT_ID(N'dbo.spChecklistNewHireDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(40, 'Leave Web Calendar Remark',  
0, 
OBJECT_ID(N'dbo.spCalendarRemarkUpdate'), 
OBJECT_ID(N'dbo.spCalendarRemarkInsert'), 
OBJECT_ID(N'dbo.spCalendarRemarkDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(41, 'Languages',  
0, 
OBJECT_ID(N'dbo.spLanguageUpdate'), 
OBJECT_ID(N'dbo.spLanguageInsert'), 
OBJECT_ID(N'dbo.spLanguageDelete'),
14)
GO
EXEC dbo.spPermissionAssociateIDsForStoredProcsWithAffectedTable
GO
IF OBJECT_ID('dbo.spPersonXListBilingual') IS NOT NULL DROP PROC dbo.spPersonXListBilingual
IF OBJECT_ID('dbo.spPersonXListWhoSpeaks') IS NOT NULL DROP PROC dbo.spPersonXListWhoSpeaks
GO
CREATE PROC dbo.spPersonXListBilingual
	@batch_id int,
	@authorized bit OUT
AS
SET NOCOUNT ON

EXEC spPermissionGetOnPeopleForCurrentUser2 @batch_id, 10007
DELETE TempX WHERE BatchID = @batch_iD AND (X & 1) = 0
SELECT @authorized = CASE WHEN @@ROWCOUNT = 0 THEN 1 ELSE 0 END

SELECT P.[List As], L.*, [Secondary Languages] = CAST('' AS varchar(400))
INTO #L
FROM vwPersonXLanguages L
INNER JOIN TempX X ON X.BatchID = @batch_id AND L.PersonID = X.[ID] AND L.[Language Mask] NOT IN
(0,1,2,4,8,16,32,64,128,256,0x200,0x400,0x800,0x1000,0x2000,0x4000,0x8000,0x10000,0x20000,0x40000,0x80000,0x100000,0x200000,0x400000,0x800000,0x1000000,0x2000000,0x4000000,0x8000000,0x10000000,0x20000000,0x40000000)
INNER JOIN vwPersonListAs P ON L.PersonID = P.PersonID
ORDER BY P.[List As]

DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, [Created], GETDATE()) > 1

DECLARE l_cursor CURSOR FOR SELECT Language, LanguageID FROM Language ORDER BY Language

DECLARE @language varchar(50), @language_id int

OPEN l_cursor
FETCH l_cursor INTO @language, @language_id
WHILE @@FETCH_STATUS = 0
BEGIN
	UPDATE #L SET [Secondary Languages] = SUBSTRING([Secondary Languages] + CASE WHEN LEN([Secondary Languages]) > 0 THEN ', ' ELSE '' END + @language, 0, 400)
	FROM #L WHERE ([Secondary Language Mask] & @language_id) != 0
	

	FETCH l_cursor INTO @language, @language_id
END

CLOSE l_cursor
DEALLOCATE l_cursor

SELECT * FROM #L
GO
CREATE PROC dbo.spPersonXListWhoSpeaks
	@batch_id int,
	@language_id int,
	@include_secondary bit,
	@authorized bit OUT
AS
SET NOCOUNT ON

EXEC spPermissionGetOnPeopleForCurrentUser2 @batch_id, 10007
DELETE TempX WHERE BatchID = @batch_iD AND (X & 1) = 0
SELECT @authorized = CASE WHEN @@ROWCOUNT = 0 THEN 1 ELSE 0 END

SELECT P.[List As], L.*, [Secondary Languages] = CAST('' AS varchar(400))
INTO #L
FROM vwPersonXLanguages L
INNER JOIN TempX X ON X.BatchID = @batch_id AND L.PersonID = X.[ID] AND (L.PrimaryLanguageID = @language_id OR (@include_secondary = 1 AND (L.[Secondary Language Mask] & @language_id) != 0))
INNER JOIN vwPersonListAs P ON L.PersonID = P.PersonID
ORDER BY P.[List As]

DECLARE l_cursor CURSOR FOR SELECT Language, LanguageID FROM Language ORDER BY Language

DECLARE @language varchar(50)

DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, [Created], GETDATE()) > 1

OPEN l_cursor
FETCH l_cursor INTO @language, @language_id
WHILE @@FETCH_STATUS = 0
BEGIN
	UPDATE #L SET [Secondary Languages] = SUBSTRING([Secondary Languages] + CASE WHEN LEN([Secondary Languages]) > 0 THEN ', ' ELSE '' END + @language, 0, 400)
	FROM #L WHERE ([Secondary Language Mask] & @language_id) != 0
	

	FETCH l_cursor INTO @language, @language_id
END

CLOSE l_cursor
DEALLOCATE l_cursor

SELECT * FROM #L
GO
GRANT EXEC ON dbo.spPersonXListBilingual TO public
GRANT EXEC ON dbo.spPersonXListWhoSpeaks TO public
GO
ALTER PROC dbo.spEmployeeLeaveList
	@batch_id int,
	@start_day int,
	@stop_day int,
	@status_or_mask int,
	@type_or_mask int,
	@type_and_mask int,
	@approval_or_mask int,
	@approval_and_mask int,
	@earned bit,
	@authorized_preceeds_first_day_off bit = NULL,
	@authorized bit OUT
AS
SET NOCOUNT ON

EXEC spPermissionGetOnPeopleForCurrentUser2 @batch_id, 10001
DELETE TempX WHERE BatchID = @batch_id AND (X & 1) = 0
SELECT @authorized = CASE WHEN @@ROWCOUNT = 0 THEN 1 ELSE 0 END

CREATE TABLE #List0305
(
	EmployeeID int,
	Employee varchar(400),
	[ID] int,
	Attributes int,
	Seconds int,
	[Earned Seconds] int,
	[Used Seconds] int,
	[Type Mask] int,
	[Temp Type Mask] int,
	Types varchar(400),
	[Start Day past 1900] int,
	[Stop Day past 1900] int,
	Note varchar(400),
	[Status Text] varchar(400),
	Requested datetime,
	[Accumulated Seconds] int
)



IF @start_day > -2147483648 AND (@earned IS NULL OR @earned = 1)
BEGIN
	SELECT L.EmployeeID, L.TypeID, [Day] = MAX(L.[Day past 1900])
	INTO #ET
	FROM EmployeeLeaveUnused L
	INNER JOIN TempX T ON T.BatchID = @batch_id AND T.[ID] = L.EmployeeID AND L.[Day past 1900] < @start_day
		AND (@type_or_mask = 0x7FFFFFFF OR (@type_or_mask & L.TypeID) !=0 OR (@type_and_mask != 0 AND @type_and_mask = L.TypeID))
	GROUP BY EmployeeID, TypeID

	INSERT #List0305(
		EmployeeID,
		Employee,
		[ID],
		Attributes,
		Seconds,
		[Earned Seconds],
		[Used Seconds],
		[Type Mask],
		[Temp Type Mask],
		[Types],
		[Start Day past 1900],
		[Stop Day past 1900],
		Note,
		[Status Text],
		Requested,
		[Accumulated Seconds]
	)
	
	SELECT EmployeeID = #ET.EmployeeID,
	Employee = P.[List As],
	[ID] = 0,
	Attributes = 0x2D,
	L.Unused,
	[Earned Seconds] = L.Unused,
	[Used Seconds] = 0,
	[Type Mask] = #ET.TypeID,
	[Temp Type Mask] = 0,
	Types = CAST(LT.Type AS varchar(400)),
	[Start Day past 1900] = @start_day - 1,
	[Stop Day past 1900] = @start_day - 1,
	Note = 'Previously accumulated ' + CAST(LT.Type AS varchar(400)),
	'',
	NULL,
	L.Unused
	FROM #ET
	INNER JOIN vwPersonListAs P ON #ET.EmployeeID = P.PersonID
	INNER JOIN LeaveType LT ON #ET.TypeID = LT.TypeID
	INNER JOIN EmployeeLeaveUnused L ON #ET.EmployeeID = L.EmployeeID AND #ET.TypeID = L.TypeID AND #ET.[Day] = L.[Day past 1900]
END


INSERT #List0305(
	EmployeeID,
	Employee,
	[ID],
	Attributes,
	Seconds,
	[Earned Seconds],
	[Used Seconds],
	[Type Mask],
	[Temp Type Mask],
	[Types],
	[Start Day past 1900],
	[Stop Day past 1900],
	Note,
	[Status Text],
	Requested,
	[Accumulated Seconds]
)


-- Earned leave
SELECT EmployeeID = L.EmployeeID,
Employee = P.[List As],
[ID] = L.LeaveID, 
Attributes = 41 |
64 * [Limit Adjustment] |
4 * Calculated |
CASE WHEN [Limit Adjustment] = 0 AND Calculated = 1 THEN 128 ELSE 0 END,
L.Seconds,
[Earned Seconds] = CASE WHEN L.Seconds >= 0 THEN L.Seconds ELSE 0 END,
[Used Seconds] = CASE WHEN L.Seconds >= 0 THEN  0 ELSE -L.Seconds END,
[Type Mask] = L.TypeID,
[Temp Type Mask] = 0,
Types = CAST(LT.Type AS varchar(400)),
[Start Day past 1900] = L.[Day past 1900], 
[Stop Day past 1900] = L.[Day past 1900], 
Note = CAST(SUBSTRING(L.Note, 1, 400) AS varchar(400)),
'',
NULL,
ISNULL((
	SELECT TOP 1 Unused FROM EmployeeLeaveUnused UL WHERE L.EmployeeID = UL.EmployeeID AND UL.TypeID = L.TypeID AND UL.[Day past 1900] <= L.[Day past 1900] ORDER BY UL.[Day past 1900] DESC
), 0)
FROM vwEmployeeLeaveEarned L
INNER JOIN TempX T ON T.BatchID = @batch_id AND T.[ID] = L.EmployeeID AND L.[Day past 1900] BETWEEN @start_day AND @stop_day
	AND (@earned = 1 OR @earned IS NULL OR (L.Seconds < 0 AND L.[Auto] = 0))
	 AND (@type_or_mask = 0x7FFFFFFF OR (@type_or_mask & L.TypeID) !=0 OR (@type_and_mask != 0 AND @type_and_mask = L.TypeID))
INNER JOIN vwPersonListAs P ON L.EmployeeID = P.PersonID
INNER JOIN LeaveType LT ON L.TypeID = LT.TypeID


IF @earned IS NULL OR @earned = 0
BEGIN
	INSERT #List0305(
		EmployeeID,
		Employee,
		[ID],
		Attributes,
		Seconds,
		[Earned Seconds],
		[Used Seconds],
		[Type Mask],
		[Temp Type Mask],
		[Types],
		[Start Day past 1900],
		[Stop Day past 1900],
		Note,
		[Status Text],
		Requested,
		[Accumulated Seconds]
	)
	
	-- Used leave
	SELECT U.LOAEmployeeID, P.[List As], U.LOALeaveID, Attributes = 17 |
	CASE U.[LOA Status]
		WHEN 1 THEN 0x200
		WHEN 2 THEN 0x400
		ELSE 0x800
	END,
	U.[LOA Seconds], 0, U.[LOA Seconds], 
	U.[LOA Type Mask] | U.[LOA Advanced Type Mask],
	[Temp Type Mask] = U.[LOA Type Mask] | U.[LOA Advanced Type Mask],
	Types = '',
	U.[LOA Start Day past 1900], 
	U.[LOA Stop Day past 1900],
	SUBSTRING(
	CASE U.[LOA Status]
		WHEN 1 THEN 'Pending. '
		WHEN 4 THEN 'Denied. '
		ELSE ''
	END + 
	U.[LOA Note], 1, 400),
	U.[LOA Status Text],
	U.[LOA Requested],
	ISNULL((
		SELECT TOP 1 Unused FROM EmployeeLeaveUnused UL WHERE U.LOAEmployeeID = UL.EmployeeID AND UL.TypeID = U.[LOA Type Mask] | U.[LOA Advanced Type Mask] AND UL.[Day past 1900] <= U.[LOA Stop Day past 1900] ORDER BY UL.[Day past 1900] DESC
	), 0)
	
	FROM vwEmployeeLeaveUsed U
	INNER JOIN TempX T ON T.BatchID = @batch_id AND T.[ID] = U.LOAEmployeeID AND dbo.DoRaysIntersect(U.[LOA Start Day past 1900], U.[LOA Stop Day past 1900], @start_day, @stop_day) = 1 AND 
		((@authorized_preceeds_first_day_off IS NULL) OR (@authorized_preceeds_first_day_off = 1 AND U.[LOA Authorized Day past 1900] < (SELECT MIN(I.[Day past 1900]) FROM EmployeeLeaveUsedItem I WHERE I.LeaveID = U.LOALeaveID)) OR (@authorized_preceeds_first_day_off = 0 AND U.[LOA Authorized Day past 1900] >= (SELECT MIN(I.[Day past 1900]) FROM EmployeeLeaveUsedItem I WHERE I.LeaveID = U.LOALeaveID)) )

		AND

		(U.[LOA Status] & @status_or_mask) != 0 AND
		(@type_or_mask = 0x7FFFFFFF OR (@type_or_mask & (U.[LOA Type Mask] | U.[LOA Advanced Type Mask])) != 0 OR (@type_and_mask != 0 AND (@type_and_mask & (U.[LOA Type Mask] | U.[LOA Advanced Type Mask])) = @type_and_mask)) AND
		(U.[LOA Status] != 2 OR @approval_or_mask = 0x7FFFFFFF OR (@approval_or_mask & U.LOAApprovalTypeID) !=0 OR (@approval_and_mask != 0 AND @approval_and_mask = U.LOAApprovalTypeID))
	INNER JOIN vwPersonListAs P ON U.LOAEmployeeID = P.PersonID
END


-- Builds types description for used leave
DECLARE t_cursor CURSOR LOCAL FOR SELECT TypeID, Type FROM LeaveType
ORDER BY Advanced DESC, Paid DESC
OPEN t_cursor

DECLARE @type_id int, @type varchar(50)
FETCH t_cursor INTO @type_id, @type
WHILE @@FETCH_STATUS = 0
BEGIN
	UPDATE #List0305 SET Types = SUBSTRING((L.Types + CASE LEN(L.Types) WHEN 0 THEN '' ELSE ', ' END + @type), 1, 400)
	FROM #List0305 L WHERE (L.[Temp Type Mask] & @type_id) != 0 

	FETCH t_cursor INTO @type_id, @type
END

CLOSE t_cursor
DEALLOCATE t_cursor


SELECT
L.EmployeeID,
L.Employee,
L.[ID],
L.Attributes,
L.Seconds,
L.[Earned Seconds],
L.[Used Seconds],
L.[Type Mask],
L.[Types],
L.[Start Day past 1900],
L.[Stop Day past 1900],L.Note,
Start = dbo.GetDateFromDaysPast1900(L.[Start Day past 1900]), 
Stop = dbo.GetDateFromDaysPast1900(L.[Stop Day past 1900]), 
[Earned Hrs] = L.[Earned Seconds] / 3600.00,
[Used Hrs] = L.[Used Seconds] / 3600.00,
L.[Status Text],
L.[Requested],
L.[Accumulated Seconds],
[Accumulated Hrs] = L.[Accumulated Seconds] / 3600.00
FROM #List0305 L
ORDER BY 
-- [Attributes] & 0x200 DESC, -- Places pending leave at the top of the list
L.[Start Day past 1900], L.[Stop Day past 1900], L.[Types]

DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1
GO
ALTER PROC dbo.spEmployeeLeaveUsedUpdate
	@employee_id int,
	@reason_id int,
	@covering_employee_id int,
	@requested int,
	@status tinyint,
	@note varchar(4000),
	@denial_reason_id int,
	@advanced_type_mask int,
	@authorized_day_past_1900 int,
	@authorizing_employee_id int,
	@approval_type_id int,
	@leave_id int
AS
DECLARE @authorized bit
DECLARE @old_employee_id int

SET NOCOUNT ON

IF @authorized_day_past_1900 IS NULL AND @status != 1 SET @authorized_day_past_1900 = DATEDIFF(d, 0, GETDATE())

SELECT @old_employee_id = EmployeeID FROM EmployeeLeaveUsed WHERE LeaveID = @leave_id

IF @old_employee_id = @employee_id
	EXEC spPermissionInsureForCurrentUserOnPerson @old_employee_id, 10001, 2, @authorized out
ELSE
BEGIN
	-- Needs delete permission on old employee and insert permission on new employee
	EXEC spPermissionInsureForCurrentUserOnPerson @old_employee_id, 10001, 8, @authorized out
	IF @authorized = 1 EXEC spPermissionInsureForCurrentUserOnPerson @employee_id, 10001, 4, @authorized out
END

IF @authorized = 1 UPDATE EmployeeLeaveUsed SET
EmployeeID = @employee_id,
ApprovalTypeId = @approval_type_id,
ReasonID = @reason_id,
CoveringEmployeeID = @covering_employee_id,
[Requested Day past 1900] = @requested,
[Advanced Type Mask] = @advanced_type_mask,
[AuthorizingEmployeeID] = @authorizing_employee_id,
[Authorized Day past 1900] = @authorized_day_past_1900,
Status = @status,
Note = @note,
DenialReasonID = @denial_reason_id
WHERE LeaveID = @leave_id
GO
ALTER PROC dbo.spEmployeeLeavePlanClearAndSetAll_1
	@plan_id int,
	@start_day int,
	@record_unused bit,
	@batch_id int
AS
SET NOCOUNT ON

CREATE TABLE #E(EmployeeID int)

DECLARE @fte numeric(9,4)
SELECT @fte = FTE FROM LeavePlan WHERE PlanID = @plan_id


INSERT #E
SELECT E.EmployeeID FROM Employee E WHERE [Terminated Day past 1900] IS NULL AND
@fte = ISNULL((
	SELECT TOP 1 FTE FROM vwEmployeeCompensation C WHERE E.EmployeeID = C.EmployeeID ORDER BY [Start Day past 1900] DESC
), 1.0000)

CREATE TABLE #ET(EmployeeID int, TypeID int, [Day past 1900] int, Seconds int)
IF @record_unused = 1
BEGIN
	INSERT #ET
	SELECT #E.EmployeeID, T.TypeID, [Day past 1900]= @start_day - 1, Seconds = ISNULL((
		SELECT TOP 1 U.Unused FROM EmployeeLeaveUnused U WHERE U.EmployeeID = #E.EmployeeID AND U.TypeID = T.TypeID AND U.[Day past 1900] < @start_day ORDER BY [Day past 1900] DESC
	), 0)
	FROM Employee #E
	CROSS JOIN LeaveType T

	-- Balances    SELECT * FROM #ET 
	INSERT TempXYZ(BatchID, [ID], X, Y, Z)
	SELECT @batch_id, EmployeeID, TypeID, [Day past 1900], Seconds FROM #ET
END

DELETE EmployeeLeavePlan WHERE EmployeeID IN
(
	SELECT EmployeeID FROM #E
)


INSERT EmployeeLeavePlan(EmployeeID, PlanID, [Start Day past 1900])
SELECT #E.EmployeeID, @plan_id, @start_day FROM #E

SELECT #E.EmployeeID, Employee = P.[List As] FROM #E
INNER JOIN vwPersonListAs P ON #E.EmployeeID = P.PersonID
GO


IF NOT EXISTS(SELECT ErrorID FROM Error WHERE ErrorID = 50046)
INSERT Error(ErrorID, Error)
SELECT 50046, 'Your client is out of date. Please close this application and update your client by going to http://iHRsoftware.com/updateHistory.aspx'
GO
IF OBJECT_ID('dbo.PayTable') IS NULL
BEGIN
	BEGIN TRAN

	-- Creates pay tables
	CREATE TABLE [dbo].[PayTable] (
		[PayTableID] [int] IDENTITY (1, 1) NOT NULL,
		[Pay Table] [varchar] (50)
	) ON [PRIMARY]
	
	ALTER TABLE [dbo].[PayTable] WITH NOCHECK ADD 
		CONSTRAINT [PK_PayTable] PRIMARY KEY  CLUSTERED 
		(
			[PayTableID]
		)  ON [PRIMARY] 
	
	ALTER TABLE [dbo].[PayTable] ADD 
		CONSTRAINT [IX_PayTable_Duplicate] UNIQUE  NONCLUSTERED 
		(
			[Pay Table]
		)  ON [PRIMARY] ,
		CONSTRAINT [CK_PayTable_BlankPayTable] CHECK (len([Pay Table]) > 0)
	
	INSERT PayTable([Pay Table]) VALUES ('General Schedule')
	
	-- Creates pay steps
	CREATE TABLE [dbo].[PayStep] (
		[PayStepID] [int] IDENTITY (1, 1) NOT NULL ,
		[PayTableID] [int] NOT NULL ,
		[Pay Step] [varchar] (15) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[Seniority Months] [int] NULL ,
		[Order] [int] NOT NULL 
	) ON [PRIMARY]
	
	ALTER TABLE [dbo].[PayStep] WITH NOCHECK ADD 
		CONSTRAINT [PK_PayStep] PRIMARY KEY  CLUSTERED 
		(
			[PayStepID]
		)  ON [PRIMARY] 
	
	ALTER TABLE [dbo].[PayStep] ADD 
		CONSTRAINT [CK_PayStep_BlankStep] CHECK (len([Pay Step]) > 0)
	
	CREATE  INDEX [IX_PayStep] ON [dbo].[PayStep]([PayTableID]) ON [PRIMARY]

	SELECT * INTO #PayGrade FROM PayGrade
	ALTER TABLE dbo.Position DROP CONSTRAINT FK_Position_PayGrade
	DROP TABLE PayGrade

	-- Alters pay grade table
	CREATE TABLE [dbo].[PayGrade] (
		[PayGradeID] [int] IDENTITY (1, 1) NOT NULL ,
		[PayTableID] [int] NOT NULL ,
		[Pay Grade] [varchar] (15) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[Order] [int] NOT NULL 
	) ON [PRIMARY]
	
	
	ALTER TABLE [dbo].[PayGrade] WITH NOCHECK ADD 
		CONSTRAINT [PK_PayGrade] PRIMARY KEY  CLUSTERED 
		(
			[PayGradeID]
		)  ON [PRIMARY] 
	
	
	ALTER TABLE [dbo].[PayGrade] ADD 
		CONSTRAINT [IX_PayGrade_NameNotUnique] UNIQUE  NONCLUSTERED 
		(
			[Pay Grade]
		)  ON [PRIMARY] ,
		CONSTRAINT [CK_PayGrade_NameRequired] CHECK (len([Pay Grade]) > 0)
	
	
	CREATE  INDEX [IX_PayGrade] ON [dbo].[PayGrade]([PayTableID]) ON [PRIMARY]
	
	
	ALTER TABLE [dbo].[PayGrade] ADD 
		CONSTRAINT [FK_PayGrade_PayTable] FOREIGN KEY 
		(
			[PayTableID]
		) REFERENCES [dbo].[PayTable] (
			[PayTableID]
		) ON DELETE CASCADE 
	
	

	CREATE TABLE [dbo].[Pay] (
		[PayID] [int] IDENTITY (1, 1) NOT NULL ,
		[PayGradeID] [int] NOT NULL ,
		[PayStepID] [int] NOT NULL ,
		[Hourly Rate] [money] NOT NULL 
	) ON [PRIMARY]


	ALTER TABLE [dbo].[Pay] ADD 
	CONSTRAINT [PK_Pay] PRIMARY KEY  CLUSTERED 
	(
		[PayID]
	)  ON [PRIMARY] 

	-- Creates pay table
	ALTER TABLE [dbo].[Pay] ADD 
	CONSTRAINT [FK_Pay_PayGrade] FOREIGN KEY 
	(
		[PayGradeID]
	) REFERENCES [dbo].[PayGrade] (
		[PayGradeID]
	) ON DELETE CASCADE ,
	CONSTRAINT [FK_Pay_PayStep] FOREIGN KEY 
	(
		[PayStepID]
	) REFERENCES [dbo].[PayStep] (
		[PayStepID]
	) ON DELETE CASCADE 




	DECLARE p_cursor CURSOR FOR SELECT PayGradeID, [Pay Grade], [Minimum Hourly Pay], [Maximum Hourly Pay], [Pay Step Increase] FROM #PayGrade
	OPEN p_cursor

	DECLARE @pgid int, @pg varchar(50), @min numeric(19, 10), @max numeric(19, 10), @inc numeric(19, 10)
	
	FETCH p_cursor INTO @pgid, @pg, @min, @max, @inc

	

	-- Turns old paygrade table into pay steps
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET IDENTITY_INSERT PayGrade ON
		EXEC sp_executesql N'INSERT PayGrade(PayGradeID, PayTableID, [Pay Grade], [Order]) SELECT @pgid, 1, @pg, @pgid',
			N'@pgid int, @pg varchar(50), @min numeric(19, 10), @max numeric(19, 10), @inc numeric(19, 10)',
			@pgid = @pgid, @pg = @pg, @min = @min, @max = @max, @inc = @inc
		SET IDENTITY_INSERT PayGrade OFF

		
		DECLARE @order int, @step numeric(19, 10), @step_id int
		SELECT @order = 1, @step = @min

		WHILE (@step <= @max AND @order <= 15) OR (@order = 1)
		BEGIN
			SELECT @step_id = PayStepID FROM PayStep WHERE [Pay Step] = @order
			IF @@ROWCOUNT = 0
			BEGIN
				INSERT PayStep(PayTableID, [Pay Step], [Order])
				SELECT 1, @order, @order

				SET @step_id = SCOPE_IDENTITY()
			END

			SELECT @order = @order + 1, @step = @step + @inc

			INSERT Pay(PayGradeID, PayStepID, [Hourly Rate])
			VALUES(@pgid, @step_id, @step)
		END

		FETCH p_cursor INTO @pgid, @pg, @min, @max, @inc
	END

	


	CLOSE p_cursor
	DEALLOCATE p_cursor

	DROP TABLE #PayGrade

	UPDATE dbo.Position SET PayGradeID = (SELECT TOP 1 PayGradeID FROM PayGrade) WHERE PayGradeID NOT IN (SELECT PayGradeID FROM PayGrade)

	-- Restore reference to Position table
	ALTER TABLE [dbo].[Position] ADD 
	CONSTRAINT [FK_Position_PayGrade] FOREIGN KEY 
	(
		[PayGradeID]
	) REFERENCES [dbo].[PayGrade] (
		[PayGradeID]
	)

	-- Alter EmployeeCompensation table to reference PayStepID
	ALTER TABLE [dbo].[EmployeeCompensation] ADD PayStepID int
	ALTER TABLE dbo.EmployeeCompensation DROP CONSTRAINT CK_EmployeeCompensation_PayStepLessThan1

	COMMIT TRAN
END
GO
ALTER VIEW dbo.vwPayGrade
AS
SELECT G.*, 
[Minimum Hourly Rate] = ISNULL((
	SELECT MIN([Hourly Rate]) FROM Pay WHERE Pay.PayGradeID = G.PayGradeID
), 0),
[Maximum Hourly Rate] = ISNULL((
	SELECT MAX([Hourly Rate]) FROM Pay WHERE Pay.PayGradeID = G.PayGradeID
), 0),
T.[Pay Table],
[Pay Step Increase] = 0.0, [Minimum Hourly Pay] = 0.0, [Maximum Hourly Pay] = 0.0 -- Provided for compatibility with clients prior v2.0.26
FROM PayGrade G
INNER JOIN PayTable T ON G.PayTableID = T.PayTableID
GO
ALTER VIEW dbo.vwPosition
AS
SELECT P.*, G.[Pay Grade], C.Category, S.Status, [Pay Grade Order] = G.[Order], G.[Pay Table], G.PayTableID,
[Annualized Pay Range] =
CONVERT(varchar(50), (CAST(G.[Minimum Hourly Rate] * P.FTE * 2080 AS money)), 1) +
CASE WHEN G.[Minimum Hourly Rate] = G.[Maximum Hourly Rate] THEN '' ELSE
+ ' to ' + CONVERT(varchar(50), (CAST(G.[Maximum Hourly Rate] * P.FTE * 2080 AS money)), 1)
END
FROM Position P
INNER JOIN JobCategory C ON P.CategoryID = C.CategoryID
INNER JOIN PositionStatus S ON P.StatusID= S.StatusID
INNER JOIN vwPayGrade G ON P.PayGradeID = G.PayGradeID
GO
ALTER VIEW dbo.vwEmployeeCompensation
AS
SELECT *, [Start] = dbo.GetDateFromDaysPast1900([Start Day past 1900]), [Stop]=dbo.GetDateFromDaysPast1900([Stop Day past 1900]) FROM EmployeeCompensation
GO
IF OBJECT_ID('FK_EmployeeCompensation_PayStep') IS NULL
BEGIN
	EXEC sp_executesql N'UPDATE EmployeeCompensation SET PayStepID = 1'

	ALTER TABLE [dbo].[EmployeeCompensation] ADD 
	CONSTRAINT [FK_EmployeeCompensation_PayStep] FOREIGN KEY 
	(
		[PayStepID]
	) REFERENCES [dbo].[PayStep] (
		[PayStepID]
	)

	EXEC sp_executesql N'UPDATE EmployeeCompensation SET PayStepID =
	ISNULL((
		SELECT TOP 1 PayStep.PayStepID FROM PayStep WHERE PayStep.[Pay Step] = EmployeeCompensation.[Pay Step]
	), 1)'

	ALTER TABLE [dbo].[EmployeeCompensation] DROP COLUMN [Pay Step]
	ALTER TABLE [dbo].[EmployeeCompensation] ALTER COLUMN PayStepID int NOT NULL
END
GO
ALTER VIEW dbo.vwEmployeeCompensation
AS
SELECT EC.*, Employee = PSN.[List As], [Employee Full Name] = PSN.[Full Name], POS.[Annualized Pay Range],
[Annualized Pay] = (7488000.0 / P.Seconds) * EC.[Base Pay] * CASE WHEN EC.PeriodID = 512 THEN POS.FTE ELSE 1 END, -- Takes FTE into account for hourly positions

[Annualized Adjustment Min] = ISNULL(
(SELECT SUM(CASE WHEN A.PeriodID IS NULL THEN 0 ELSE [Minimum Adjustment] * (7488000.0 / AP.Seconds) END) FROM vwEmployeeCompensationAdjustment A 
LEFT JOIN Period AP ON AP.PeriodID = A.PeriodID WHERE A.CompensationID = EC.CompensationID),
0),

[Annualized Adjustment Max] = ISNULL(
(SELECT SUM(CASE WHEN A.PeriodID IS NULL THEN 0 ELSE [Maximum Adjustment] * (7488000.0 / AP.Seconds) END) FROM vwEmployeeCompensationAdjustment A 
LEFT JOIN Period AP ON AP.PeriodID = A.PeriodID WHERE A.CompensationID = EC.CompensationID),
0),

[Annualized Employer Premiums] = ISNULL(
	(SELECT SUM(EB.[Employer Premium] * (7488000.0 / P.Seconds)) 
	FROM Constant C
	INNER JOIN Period P ON (C.CurrentPayrollPeriodID & 2047) = P.PeriodID
	CROSS JOIN EmployeeBenefit EB 
	WHERE EB.EmployeeID = EC.EmployeeID
	
), 0),

[Employer Premiums] = ISNULL(
	(SELECT SUM(EB.[Employer Premium]) 
	FROM EmployeeBenefit EB WHERE EB.EmployeeID = EC.EmployeeID
), 0),

[Hourly Pay] = (3600.0 / P.Seconds) * EC.[Base Pay], POS.[Job Title],
[Start] = dbo.GetDateFromDaysPast1900(EC.[Start Day past 1900]), [Stop]=dbo.GetDateFromDaysPast1900(EC.[Stop Day past 1900]),
POS.[FLSA Exempt], P.Period,
POS.Status,
[Receives Other Compensation] = CAST(CASE WHEN LEN(EC.[Other Compensation]) > 0 THEN 1 ELSE 0 END AS bit),
[Employment Status] = CASE WHEN E.[Terminated Day past 1900] IS NULL THEN ES.Status ELSE 'Terminated' END,
POS.FTE,
POS.CategoryID,
POS.Category,

[Pay Step] = 1 -- Backward compatibility pre V26
FROM EmployeeCompensation EC
INNER JOIN Period P ON EC.PeriodID = P.PeriodID
INNER JOIN vwPersonCalculated PSN ON EC.EmployeeID = PSN.PersonID
INNER JOIN vwPosition POS ON EC.PositionID = POS.PositionID
INNER JOIN EmploymentStatus ES ON EC.EmploymentStatusID = ES.StatusID
INNER JOIN Employee E ON EC.EmployeeID = E.EmployeeID
GO
ALTER PROC dbo.spPayGradeDelete
	@pay_grade_id int = NULL, -- hack for backward compatibility
	@grade_id int = NULL
AS
SET NOCOUNT ON

DELETE PayGrade WHERE PayGradeID = @pay_grade_id OR PayGradeID = @grade_id
GO
ALTER PROC dbo.spEmployeeCompensationInsert
	@employee_id int,
	@period_id int,
	@budgeted bit,
	@employment_status_id int,
	@start_day_past_1900 int,
	@stop_day_past_1900 int,
	@note varchar(4000),
	@base_pay money,
	@other_compensation varchar(4000),
	@position_id int,
	@step_id int = NULL,
	@compensation_id int OUT,
	@pay_step int = NULL
AS
DECLARE @authorized bit

SET NOCOUNT ON

IF @step_id IS NULL
BEGIN
	SET @authorized = 0
	EXEC spErrorRaise 50046
END
ELSE EXEC spPermissionInsureForCurrentUserOnPerson @employee_id, 1024, 4, @authorized out

IF @authorized = 1
BEGIN
	BEGIN TRAN

	-- If the last compensation entry for the employee was left open then sets its stop date to one day before the start date for the new entry
	UPDATE EmployeeCompensation SET [Stop Day past 1900] = @start_day_past_1900 - 1 WHERE [Stop Day past 1900] IS NULL AND EmployeeID = @employee_id AND @start_day_past_1900 > [Start Day past 1900]

	-- If @stop is null and there is a next compensation entry for the employee then change @stop to next start - 1
	IF @stop_day_past_1900 IS NULL 
	SELECT @stop_day_past_1900 = [Start Day past 1900] - 1 FROM EmployeeCompensation WHERE EmployeeID = @employee_id AND [Start Day past 1900] > @start_day_past_1900 ORDER BY [Start Day past 1900] 
	

	INSERT EmployeeCompensation(EmployeeID, PeriodID, [Start Day past 1900], [Stop Day past 1900],Note, [Base Pay], [Other Compensation], PositionID, PayStepID, Budgeted, EmploymentStatusID)
	VALUES (@employee_id, @period_id, @start_day_past_1900, @stop_day_past_1900,@note, @base_pay, @other_compensation, @position_id, @step_id, @budgeted, @employment_status_id)
	SELECT @compensation_id = @@IDENTITY

	COMMIT TRAN
END
GO
ALTER PROC dbo.spEmployeeCompensationUpdate
	@period_id int,
	@start_day_past_1900 int,
	@stop_day_past_1900 int,
	@employment_status_id int,
	@budgeted bit,
	@note varchar(4000),
	@base_pay money,
	@other_compensation varchar(4000),
	@compensation_id int,
	@position_id int,
	@step_id int = NULL,
	@pay_step int = NULL
AS
DECLARE @employee_id int
DECLARE @authorized bit

SET NOCOUNT ON

IF @step_id IS NULL
BEGIN
	SET @authorized = 0
	EXEC spErrorRaise 50046
END
ELSE
BEGIN
	SELECT @employee_id = EmployeeID FROM EmployeeCompensation WHERE CompensationID = @compensation_id
	EXEC spPermissionInsureForCurrentUserOnPerson @employee_id, 1024, 2, @authorized out
END

IF @authorized = 1 UPDATE EmployeeCompensation SET
	PeriodID = @period_id,
	Budgeted = @budgeted,
	[Start Day past 1900] = @start_day_past_1900,
	[Stop Day past 1900] = @stop_day_past_1900,
	EmploymentStatusID = @employment_status_id,
	Note = @note,
	[Base Pay] = @base_pay,
	[Other Compensation] = @other_compensation,
	PositionID = @position_id,
	[PayStepID] = @step_id
WHERE CompensationID = @compensation_id
GO
IF OBJECT_ID('dbo.spPayTableDelete') IS NOT NULL DROP PROC dbo.spPayTableDelete
IF OBJECT_ID('dbo.spPayTableInsert') IS NOT NULL DROP PROC dbo.spPayTableInsert
IF OBJECT_ID('dbo.spPayTableList') IS NOT NULL DROP PROC dbo.spPayTableList
IF OBJECT_ID('dbo.spPayTableSelect') IS NOT NULL DROP PROC dbo.spPayTableSelect
IF OBJECT_ID('dbo.spPayTableUpdate') IS NOT NULL DROP PROC dbo.spPayTableUpdate
IF OBJECT_ID('dbo.spPayStepCount') IS NOT NULL DROP PROC dbo.spPayStepCount
IF OBJECT_ID('dbo.spPayStepDelete') IS NOT NULL DROP PROC dbo.spPayStepDelete
IF OBJECT_ID('dbo.spPayStepInsert') IS NOT NULL DROP PROC dbo.spPayStepInsert
IF OBJECT_ID('dbo.spPayStepUpdate') IS NOT NULL DROP PROC dbo.spPayStepUpdate
IF OBJECT_ID('dbo.spPayStepList') IS NOT NULL DROP PROC dbo.spPayStepList
IF OBJECT_ID('dbo.spPayStepSelect') IS NOT NULL DROP PROC dbo.spPayStepSelect
IF OBJECT_ID('dbo.spPayGradeCount') IS NOT NULL DROP PROC dbo.spPayGradeCount
IF OBJECT_ID('dbo.spPayList') IS NOT NULL DROP PROC dbo.spPayList
IF OBJECT_ID('dbo.spPayUpdate') IS NOT NULL DROP PROC dbo.spPayUpdate
IF OBJECT_ID('dbo.spEmployeeCompensationSelect2') IS NOT NULL DROP PROC dbo.spEmployeeCompensationSelect2
IF OBJECT_ID('dbo.spPayStepGetFirst') IS NOT NULL DROP PROC dbo.spPayStepGetFirst
GO
CREATE PROC dbo.spEmployeeCompensationSelect2
	@compensation_id int
AS
DECLARE @employee_id int
DECLARE @authorized bit

SET NOCOUNT ON

SELECT @employee_id = EmployeeID FROM EmployeeCompensation WHERE CompensationID = @compensation_id

EXEC spPermissionInsureForCurrentUserOnPerson @employee_id, 1024, 1, @authorized out
IF @authorized = 1 SELECT * FROM vwEmployeeCompensation WHERE CompensationID = @compensation_id
GO
CREATE PROC dbo.spPayTableDelete
	@table_id int
AS
DECLARE @result int
BEGIN TRAN
DELETE PayGrade WHERE PayTableID = @table_id
SET @result = @@ERROR

IF @result = 0
BEGIN
	DELETE PayStep WHERE PayTableID = @table_id
	SET @result = @@ERROR
END

IF @result = 0
BEGIN
	DELETE PayTable WHERE PayTableID = @table_id
	SET @result = @@ERROR
END

IF @result = 0 COMMIT TRAN
ELSE IF @@TRANCOUNT > 0  ROLLBACK TRAN
GO
CREATE PROC dbo.spPayTableInsert
	@table varchar(50),
	@table_id int OUT
AS
INSERT PayTable([Pay Table])
VALUES(@table)

SELECT @table_id = SCOPE_IDENTITY()
GO
CREATE PROC dbo.spPayTableList
AS
SET NOCOUNT ON

SELECT * FROM PayTable ORDER BY [Pay Table]
GO
CREATE PROC dbo.spPayTableSelect
	@table_id int
AS
SET NOCOUNT ON

SELECT * FROM PayTable WHERE PayTableID = @table_id
GO
CREATE PROC dbo.spPayTableUpdate
	@table varchar(50),
	@table_id int
AS

UPDATE PayTable SET [Pay Table] = @table WHERE PayTableID = @table_id
GO
CREATE PROC dbo.spPayStepCount
	@table_id int,
	@count int out
AS
SET NOCOUNT ON

SELECT @count = COUNT(*) FROM PayStep WHERE PayTableID = @table_id
GO
CREATE PROC dbo.spPayStepDelete
	@step_id int
AS
DELETE PayStep WHERE PayStepID = @step_id
GO
CREATE PROC dbo.spPayStepInsert
	@table_id int,
	@step varchar(15),
	@months int,
	@order int,
	@step_id int OUT
AS
INSERT PayStep(PayTableID, [Pay Step], [Seniority Months], [Order])
VALUES(@table_id, @step, @months, @order)

SELECT @step_id = SCOPE_IDENTITY()
GO
CREATE PROC dbo.spPayStepList
	@table_id int
AS
SET NOCOUNT ON
SELECT * FROM PayStep WHERE PayTableID = @table_id ORDER BY [Order]
GO
CREATE PROC dbo.spPayStepSelect
	@step_id int
AS
SET NOCOUNT ON
SELECT * FROM PayStep WHERE PayStepID = @step_id
GO
CREATE PROC dbo.spPayStepUpdate
	@step varchar(15),
	@months int,
	@order int,
	@step_id int
AS
UPDATE PayStep SET [Pay Step] = @step, [Seniority Months] = @months, [Order] = @order WHERE PayStepID = @step_id
GO
CREATE PROC dbo.spPayGradeCount
	@table_id int,
	@count int out
AS
SET NOCOUNT ON

SELECT @count = COUNT(*) FROM PayGrade WHERE PayTableID = @table_id
GO
ALTER PROCEDURE dbo.spEmployeeCompensationSelect
	@compensation_id int
AS
EXEC spErrorRaise 50046
GO
ALTER PROC dbo.spPayGradeInsert
	-- Old parameters for clients before version 2.0.26
	@pay_grade varchar(50) = NULL,
	@minimum numeric(19, 10) = NULL,
	@maximum numeric(19, 10) = NULL,
	@step numeric(19, 10) = NULL,
	@pay_grade_id int = NULL OUT,

	-- New parameters for clients on/after version 2.0.26
	@table_id int = NULL,
	@grade varchar(15) = NULL,
	@order int = NULL,
	@grade_id int = NULL OUT
AS
SET NOCOUNT ON

IF @table_id IS NULL EXEC spErrorRaise 50046
ELSE
BEGIN
	INSERT PayGrade([Pay Grade], PayTableID, [Order]) VALUES(@grade, @table_id, @order)
	SELECT @grade_id = SCOPE_IDENTITY()
END
GO
ALTER PROC dbo.spPayGradeUpdate
	-- Old parameters for clients before version 2.0.26
	@pay_grade_id int = NULL,
	@pay_grade varchar(50) = NULL,
	@minimum numeric(19, 10) = NULL,
	@maximum numeric(19, 10) = NULL,
	@step numeric(19, 10) = NULL,

	-- New parameters for clients on/after version 2.0.26
	@grade_id int = NULL,
	@order int = NULL,
	@grade varchar(15) = NULL
AS
IF @grade_id IS NULL EXEC spErrorRaise 50046
ELSE UPDATE PayGrade SET [Pay Grade] = @grade, [Order] = @order WHERE PayGradeID = @grade_id
GO
CREATE PROC dbo.spPayList
	@table_id int
AS
SET NOCOUNT ON

SELECT [Hourly Rate] = ISNULL((
	SELECT [Hourly Rate] FROM Pay WHERE Pay.PayGradeID = G.PayGradeID AND Pay.PayStepID = S.PayStepID
), 0),
G.PayGradeID, S.PayStepID,
G.[Pay Grade],
S.[Pay Step]
FROM PayGrade G
CROSS JOIN PayStep S
WHERE G.PayTableID = @table_id AND S.PayTableID = @table_id
ORDER BY G.[Order], S.[Order]
GO
ALTER PROC dbo.spPayGradeList2
	@pattern varchar(50),
	@pay_steps int OUT
AS
EXEC spErrorRaise 50046
GO
ALTER PROC dbo.spPayGradeList
	@table_id int = NULL
AS
SET NOCOUNT ON

SELECT * FROM vwPayGrade WHERE @table_id IS NULL OR PayTableID = @table_id ORDER BY [Pay Table], [Order]
GO
CREATE PROC dbo.spPayUpdate
	@grade_id int,
	@step_id int,
	@rate money
AS
IF @rate = 0 DELETE Pay WHERE PayGradeID = @grade_id AND PayStepID = @step_id
ELSE
BEGIN
	UPDATE Pay SET [Hourly Rate] = @rate
	WHERE PayGradeID = @grade_id AND PayStepID = @step_id

	IF @@ROWCOUNT = 0
	INSERT Pay(PayGradeID, PayStepID, [Hourly Rate])
	VALUES(@grade_id, @step_id, @rate)
END
GO
ALTER PROC dbo.spPositionGetPay
	@position_id int,
	@step_id int = NULL,
	@pay money OUT,

	@step int = NULL -- backward compatibility pre v26
AS
SET NOCOUNT ON

IF @step_id IS NULL EXEC spErrorRaise 50046
ELSE
	BEGIN
	SELECT @pay = 0
	SELECT @pay = Pay.[Hourly Rate]
	FROM Position P
	INNER JOIN Pay ON P.PositionID = @position_id AND Pay.PayGradeID = P.PayGradeID AND Pay.PayStepID = @step_id
END
GO
CREATE PROC dbo.spPayStepGetFirst
	@step_id int out
AS
SET NOCOUNT ON

SELECT @step_id = NULL
SELECT TOP 1 @step_id = PayStepID FROM PayStep
GO
GRANT EXEC ON dbo.spEmployeeCompensationSelect2 TO public
GRANT EXEC ON dbo.spPayStepCount TO public 
GRANT EXEC ON dbo.spPayTableSelect TO public 
GRANT EXEC ON dbo.spPayTableList TO public 
GRANT EXEC ON dbo.spPayStepList TO public 
GRANT EXEC ON dbo.spPayStepSelect TO public 
GRANT EXEC ON dbo.spPayGradeCount TO public 
GRANT EXEC ON dbo.spPayStepGetFirst TO public

-- Extends permission setting for paygrades
GO
ALTER PROC dbo.spPositionListAsItems
	@active bit, -- null lists all. 0 lists inactive. 1 lists active
	@position_id int
AS
DECLARE @batch_id int

SET NOCOUNT ON

SELECT PositionID, [Job Title], [Pay Grade], FTE, PayGradeID, PayTableID FROM vwPosition WHERE (@active IS NULL OR Active = @active) OR PositionID = @position_id
ORDER BY [Pay Table], [Pay Grade Order], [Job Title]
GO
GO
ALTER PROC dbo.spPermissionAssociateIDsForStoredProcsWithAffectedTable
AS
SET NOCOUNT ON

DELETE PermissionObjectX
DELETE PermissionObject

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(1, 'Organizational Departments', 
0,  
OBJECT_ID(N'dbo.spDepartmentUpdate'), 
OBJECT_ID(N'dbo.spDepartmentInsert'), 
OBJECT_ID(N'dbo.spDepartmentDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(2, 'Organizational Divisions', 
0,  
OBJECT_ID(N'dbo.spDivisionUpdate'), 
OBJECT_ID(N'dbo.spDivisionInsert'), 
OBJECT_ID(N'dbo.spDivisionDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(3, 'Job Categories',
0,
OBJECT_ID(N'dbo.spJobCategoryUpdate'), 
OBJECT_ID(N'dbo.spJobCategoryInsert'), 
OBJECT_ID(N'dbo.spJobCategoryDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(4, 'Certifications', 
0, 
OBJECT_ID(N'dbo.spCertificationUpdate'), 
OBJECT_ID(N'dbo.spCertificationInsert'), 
OBJECT_ID(N'dbo.spCertificationDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(5, 'Unions', 
0,  
OBJECT_ID(N'dbo.spUnionUpdate'), 
OBJECT_ID(N'dbo.spUnionInsert'), 
OBJECT_ID(N'dbo.spUnionDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(6, 'Organizational Locations', 
0,  
OBJECT_ID(N'dbo.spLocationUpdate'), 
OBJECT_ID(N'dbo.spLocationInsert'), 
OBJECT_ID(N'dbo.spLocationDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(7, 'Employee Review Rating Choices',  
0, 
OBJECT_ID(N'dbo.spEmployeeReviewRatingUpdate'), 
OBJECT_ID(N'dbo.spEmployeeReviewRatingInsert'), 
OBJECT_ID(N'dbo.spEmployeeReviewRatingDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(8, 'Employee Review Type Choices',  
0, 
OBJECT_ID(N'dbo.spEmployeeReviewTypeUpdate'), 
OBJECT_ID(N'dbo.spEmployeeReviewTypeInsert'), 
OBJECT_ID(N'dbo.spEmployeeReviewTypeDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(9, 'Employment Summary Reports',  
OBJECT_ID(N'dbo.spTurnover'),
0,
0,
0,
1)


INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(10, 'Tests',  
0, 
OBJECT_ID(N'dbo.spTestUpdate'), 
OBJECT_ID(N'dbo.spTestInsert'), 
OBJECT_ID(N'dbo.spTestDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(11, 'Training Courses',  
0, 
OBJECT_ID(N'dbo.spTrainingUpdate'), 
OBJECT_ID(N'dbo.spTrainingInsert'), 
OBJECT_ID(N'dbo.spTrainingDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(12, 'Employee Successor Stages',  
0, 
OBJECT_ID(N'dbo.spEmployeeSuccessorStageUpdate'), 
OBJECT_ID(N'dbo.spEmployeeSuccessorStageInsert'), 
OBJECT_ID(N'dbo.spEmployeeSuccessorStageDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(13, 'Positions',  
OBJECT_ID(N'dbo.spPositionSelect'), 
OBJECT_ID(N'dbo.spPositionUpdate'), 
OBJECT_ID(N'dbo.spPositionInsert'), 
OBJECT_ID(N'dbo.spPositionDelete'),
15)

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(13, 1, OBJECT_ID(N'spPositionList'))

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(14, 'Custom Fields',  
0, 
OBJECT_ID(N'dbo.spCustomFieldUpdate'), 
OBJECT_ID(N'dbo.spCustomFieldInsert'), 
OBJECT_ID(N'dbo.spCustomFieldDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(15, 'Form I9 Choices',  
0, 
OBJECT_ID(N'dbo.spI9StatusUpdate'), 
OBJECT_ID(N'dbo.spI9StatusInsert'), 
OBJECT_ID(N'dbo.spI9StatusDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(16, 'Marital Status',  
0, 
OBJECT_ID(N'dbo.spMaritalStatusUpdate'), 
OBJECT_ID(N'dbo.spMaritalStatusInsert'), 
OBJECT_ID(N'dbo.spMaritalStatusDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(17, 'Races',  
0, 
OBJECT_ID(N'dbo.spRaceUpdate'), 
OBJECT_ID(N'dbo.spRaceInsert'), 
OBJECT_ID(N'dbo.spRaceDelete'),
14)


INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(19, 'Injury Results',  
0, 
OBJECT_ID(N'dbo.spInjuryResultUpdate'), 
OBJECT_ID(N'dbo.spInjuryResultInsert'), 
OBJECT_ID(N'dbo.spInjuryResultDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(20, 'Skills',  
0, 
OBJECT_ID(N'dbo.spSkillUpdate'), 
OBJECT_ID(N'dbo.spSkillInsert'), 
OBJECT_ID(N'dbo.spSkillDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(21, 'Organizational Shifts',  
0, 
OBJECT_ID(N'dbo.spShiftUpdate'), 
OBJECT_ID(N'dbo.spShiftInsert'), 
OBJECT_ID(N'dbo.spShiftDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(22, 'Employee Creation\Deletion',
0,  
0, 
OBJECT_ID(N'dbo.spEmployeeInsert'), 
OBJECT_ID(N'dbo.spEmployeeDelete'),
12)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(23, 'Checklist for Termination',  
0, 
OBJECT_ID(N'dbo.spChecklistExitInterviewUpdate'), 
OBJECT_ID(N'dbo.spChecklistExitInterviewInsert'), 
OBJECT_ID(N'dbo.spChecklistExitInterviewDelete'),
14)


INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(24, 'Benefits',  
0, 
OBJECT_ID(N'dbo.spBenefitUpdate'), 
OBJECT_ID(N'dbo.spBenefitInsert'), 
OBJECT_ID(N'dbo.spBenefitDelete'),
14)


INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(24, 2, OBJECT_ID(N'spBenefitUpdate'))
INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(24, 2, OBJECT_ID(N'spTDRPUpdate'))
INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(24, 2, OBJECT_ID(N'spTDRPMatchingUpdate'))

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(24, 4, OBJECT_ID(N'spBenefitInsert'))
INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(24, 4, OBJECT_ID(N'spTDRPInsert'))
INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(24, 4, OBJECT_ID(N'spTDRPMatchingInsert'))

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(24, 8, OBJECT_ID(N'spTDRPMatchingDelete'))


INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(25, 'Equipment',  
OBJECT_ID(N'dbo.spEquipmentSelect'), 
OBJECT_ID(N'dbo.spEquipmentUpdate'), 
OBJECT_ID(N'dbo.spEquipmentInsert'), 
OBJECT_ID(N'dbo.spEquipmentDelete'),
15)

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(25, 1, OBJECT_ID(N'spEquipmentListCheckedIn'))


INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(25, 1, OBJECT_ID(N'spEquipmentListCheckedOut'))


INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(25, 1, OBJECT_ID(N'spEquipmentListForEmployee'))




INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(26, 'Leave Plans',  
0, 
OBJECT_ID(N'dbo.spLeavePlanUpdate'), 
OBJECT_ID(N'dbo.spLeavePlanInsert'), 
OBJECT_ID(N'dbo.spLeavePlanDelete'),
14)


INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(26, 4, OBJECT_ID(N'spLeavePlanAutoCreate'))

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(26, 2, OBJECT_ID(N'spLeaveRateInsert'))

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(26, 2, OBJECT_ID(N'spCompanyUpdateCarryover'))





INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(26, 1, OBJECT_ID(N'spLeaveRateList'))

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(26, 2, OBJECT_ID(N'spLeaveRateClear'))

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(26, 1, OBJECT_ID(N'spLeaveLimitList'))

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(26, 1, OBJECT_ID(N'spLeaveLimitSelect'))

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(26, 2, OBJECT_ID(N'spLeaveLimitUnlimit'))

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(26, 2, OBJECT_ID(N'spLeaveLimitUpdate'))

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(27, 'Holidays',  
0, 
OBJECT_ID(N'dbo.spHolidayUpdate'), 
OBJECT_ID(N'dbo.spHolidayInsert'), 
OBJECT_ID(N'dbo.spHolidayDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(28, 'Leave Denial Reasons',  
0, 
OBJECT_ID(N'dbo.spDenialReasonUpdate'), 
OBJECT_ID(N'dbo.spDenialReasonInsert'), 
OBJECT_ID(N'dbo.spDenialReasonDelete'),
14)


INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(30, 'Standard Tasks',  
0, 
OBJECT_ID(N'dbo.spStandardTaskUpdate'), 
OBJECT_ID(N'dbo.spStandardTaskInsert'), 
OBJECT_ID(N'dbo.spStandardTaskDelete'),
14)




INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(32, 'Licensing', 
0, 
OBJECT_ID(N'dbo.spLicenseUpdate'), 
OBJECT_ID(N'dbo.spLicenseInsert'), 
OBJECT_ID(N'dbo.spLicenseDelete'),
14)






INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(33, 'Pay Grades', 
0, 
OBJECT_ID(N'dbo.spPayGradeUpdate'), 
OBJECT_ID(N'dbo.spPayGradeInsert'), 
OBJECT_ID(N'dbo.spPayGradeDelete'),
15)




INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(33, 2, OBJECT_ID(N'dbo.spPayTableUpdate'))

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(33, 4, OBJECT_ID(N'dbo.spPayTableInsert'))

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(33, 8, OBJECT_ID(N'dbo.spPayTableDelete'))




INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(33, 2, OBJECT_ID(N'dbo.spPayStepUpdate'))

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(33, 4, OBJECT_ID(N'dbo.spPayStepInsert'))

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(33, 8, OBJECT_ID(N'dbo.spPayStepDelete'))



INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(33, 1, OBJECT_ID(N'dbo.spPayList'))

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(33, 2, OBJECT_ID(N'dbo.spPayUpdate'))




INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(34, 'Leave, ''About Extended Leave'' Note', 
0, 
OBJECT_ID(N'dbo.spConstantUpdateLeaveNote'), 
0,
0,
2)


INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(35, 'Leave Types', 
0, 
OBJECT_ID(N'dbo.spLeaveTypeUpdate'), 
OBJECT_ID(N'dbo.spLeaveTypeInsert'), 
OBJECT_ID(N'dbo.spLeaveTypeDelete'),
14)

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(35, 2, OBJECT_ID(N'dbo.spLeaveTypeAddStateFML'))



INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(36, 'Position Status', 
0, 
OBJECT_ID(N'dbo.spPositionStatusUpdate'), 
OBJECT_ID(N'dbo.spPositionStatusInsert'), 
OBJECT_ID(N'dbo.spPositionStatusDelete'),
14)


INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(37, 'Employment Status', 
0, 
OBJECT_ID(N'dbo.spEmploymentStatusUpdate'), 
OBJECT_ID(N'dbo.spEmploymentStatusInsert'), 
OBJECT_ID(N'dbo.spEmploymentStatusDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(38, 'Checklist for New Hires',  
0, 
OBJECT_ID(N'dbo.spChecklistNewHireUpdate'), 
OBJECT_ID(N'dbo.spChecklistNewHireInsert'), 
OBJECT_ID(N'dbo.spChecklistNewHireDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(39, 'Leave Approval Types',  
0, 
OBJECT_ID(N'dbo.spChecklistNewHireUpdate'), 
OBJECT_ID(N'dbo.spChecklistNewHireInsert'), 
OBJECT_ID(N'dbo.spChecklistNewHireDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(40, 'Leave Web Calendar Remark',  
0, 
OBJECT_ID(N'dbo.spCalendarRemarkUpdate'), 
OBJECT_ID(N'dbo.spCalendarRemarkInsert'), 
OBJECT_ID(N'dbo.spCalendarRemarkDelete'),
14)

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(41, 'Languages',  
0, 
OBJECT_ID(N'dbo.spLanguageUpdate'), 
OBJECT_ID(N'dbo.spLanguageInsert'), 
OBJECT_ID(N'dbo.spLanguageDelete'),
14)
GO
-- Sets proper permission on PayTable, PayStep, and Pay
DECLARE @scope_id int, @uid int, @permission_mask int

DECLARE p_cursor CURSOR FOR SELECT ScopeID, UID, [Permission Mask] FROM PermissionScopeAttribute WHERE AttributeID = 33

OPEN p_cursor
FETCH p_cursor INTO @scope_id, @uid, @permission_mask
WHILE @@FETCH_STATUS = 0
BEGIN
	EXEC spPermissionUpdateForUserScopeOnAttribute @scope_id, 33, @uid, @permission_mask
	FETCH p_cursor INTO @scope_id, @uid, @permission_mask
END
CLOSE p_cursor
DEALLOCATE p_cursor
GO


IF OBJECT_ID('dbo.spPayGradeGetFirst') IS NOT NULL DROP PROC dbo.spPayGradeGetFirst
IF OBJECT_ID('dbo.spJobCategoryGetFirst') IS NOT NULL DROP PROC dbo.spJobCategoryGetFirst
IF OBJECT_ID('dbo.spPositionStatusGetFirst') IS NOT NULL DROP PROC dbo.spPositionStatusGetFirst
IF OBJECT_ID('dbo.spEmployeeUpdateActive') IS NOT NULL DROP PROC dbo.spEmployeeUpdateActive
IF OBJECT_ID('dbo.spEmploymentStatusGetFullTime') IS NOT NULL DROP PROC dbo.spEmploymentStatusGetFullTime
GO
CREATE PROC dbo.spPayGradeGetFirst
	@grade_id int out
AS
SET NOCOUNT ON

SELECT @grade_id = NULL
SELECT TOP 1 @grade_id = PayGradeID FROM PayGrade
GO
CREATE PROC dbo.spPositionStatusGetFirst
	@status_id int out
AS
SET NOCOUNT ON

SELECT @status_id = NULL
SELECT TOP 1 @status_id = StatusID FROM PositionStatus
GO
CREATE PROC dbo.spEmploymentStatusGetFullTime
	@status_id int OUT
AS
SET NOCOUNT ON

SET @status_id = NULL
SELECT @status_id = StatusID FROM EmploymentStatus WHERE Status = 'Full Time'
IF @@ROWCOUNT = 0 SELECT TOP 1 @status_id = StatusID FROM EmploymentStatus
GO
CREATE PROC dbo.spJobCategoryGetFirst
	@category_id int out
AS
SET NOCOUNT ON

SELECT @category_id = NULL
SELECT TOP 1 @category_id = CategoryID FROM JobCategory
GO
CREATE PROC dbo.spEmployeeUpdateActive
	@employee_id int,
	@active bit
AS
SET NOCOUNT ON

UPDATE Employee SET [Active Employee] = @active WHERE EmployeeID = @employee_id
GO
GRANT EXEC ON dbo.spJobCategoryGetFirst TO public
GRANT EXEC ON dbo.spPayGradeGetFirst TO public
GRANT EXEC ON dbo.spPositionStatusGetFirst TO public
GRANT EXEC ON dbo.spEmploymentStatusGetFullTime TO public
UPDATE ColumnGrid SET Importable = 1 WHERE FieldID IN ( 53, 55, 56 )
GO
IF OBJECT_ID('dbo.PermissionScopeAttributeExceptionPosition') IS NULL
BEGIN
	CREATE TABLE [dbo].[PermissionScopeAttributeExceptionPosition] (
		[ExceptionID] [int] IDENTITY (1, 1) NOT NULL ,
		[PermissionID] [int] NOT NULL ,
		[PositionID] [int] NOT NULL 
	) ON [PRIMARY]
	
	ALTER TABLE [dbo].[PermissionScopeAttributeExceptionPosition] WITH NOCHECK ADD 
	CONSTRAINT [PK_PermissionScopeAttributeExceptionPosition] PRIMARY KEY  CLUSTERED 
	(
		[ExceptionID]
	)  ON [PRIMARY] 

	CREATE  INDEX [IX_PermissionScopeAttributeExceptionPosition] ON [dbo].[PermissionScopeAttributeExceptionPosition]([PermissionID]) ON [PRIMARY]
	CREATE  UNIQUE  INDEX [IX_PermissionScopeAttributeExceptionPosition_1] ON [dbo].[PermissionScopeAttributeExceptionPosition]([PermissionID], [PositionID]) ON [PRIMARY]
	
	ALTER TABLE [dbo].[PermissionScopeAttributeExceptionPosition] ADD 
	CONSTRAINT [FK_PermissionScopeAttributeExceptionPosition_PermissionScopeAttribute] FOREIGN KEY 
	(
		[PermissionID]
	) REFERENCES [dbo].[PermissionScopeAttribute] (
		[PermissionID]
	) ON DELETE CASCADE ,
	CONSTRAINT [FK_PermissionScopeAttributeExceptionPosition_Position] FOREIGN KEY 
	(
		[PositionID]
	) REFERENCES [dbo].[Position] (
		[PositionID]
	) ON DELETE CASCADE 
END
GO
IF OBJECT_ID('dbo.PermissionScopeAttributeExceptionDepartment') IS NULL
BEGIN
	CREATE TABLE [dbo].[PermissionScopeAttributeExceptionDepartment] (
		[ExceptionID] [int] IDENTITY (1, 1) NOT NULL ,
		[PermissionID] [int] NOT NULL ,
		[DepartmentID] [int] NOT NULL 
	) ON [PRIMARY]
	
	ALTER TABLE [dbo].[PermissionScopeAttributeExceptionDepartment] WITH NOCHECK ADD 
	CONSTRAINT [PK_PermissionScopeAttributeExceptionDepartment] PRIMARY KEY  CLUSTERED 
	(
		[ExceptionID]
	)  ON [PRIMARY] 

	CREATE  INDEX [IX_PermissionScopeAttributeExceptionDepartment] ON [dbo].[PermissionScopeAttributeExceptionDepartment]([PermissionID]) ON [PRIMARY]
	CREATE  UNIQUE  INDEX [IX_PermissionScopeAttributeExceptionDepartment_1] ON [dbo].[PermissionScopeAttributeExceptionDepartment]([PermissionID], [DepartmentID]) ON [PRIMARY]
	
	ALTER TABLE [dbo].[PermissionScopeAttributeExceptionDepartment] ADD 
	CONSTRAINT [FK_PermissionScopeAttributeExceptionDepartment_PermissionScopeAttribute] FOREIGN KEY 
	(
		[PermissionID]
	) REFERENCES [dbo].[PermissionScopeAttribute] (
		[PermissionID]
	) ON DELETE CASCADE ,
	CONSTRAINT [FK_PermissionScopeAttributeExceptionDepartment_Department] FOREIGN KEY 
	(
		[DepartmentID]
	) REFERENCES [dbo].[Department] (
		[DepartmentID]
	) ON DELETE CASCADE 
END
GO
IF OBJECT_ID('dbo.PermissionScopeAttributeExceptionDivision') IS NULL
BEGIN
	CREATE TABLE [dbo].[PermissionScopeAttributeExceptionDivision] (
		[ExceptionID] [int] IDENTITY (1, 1) NOT NULL ,
		[PermissionID] [int] NOT NULL ,
		[DivisionID] [int] NOT NULL 
	) ON [PRIMARY]
	
	ALTER TABLE [dbo].[PermissionScopeAttributeExceptionDivision] WITH NOCHECK ADD 
	CONSTRAINT [PK_PermissionScopeAttributeExceptionDivision] PRIMARY KEY  CLUSTERED 
	(
		[ExceptionID]
	)  ON [PRIMARY] 

	CREATE  INDEX [IX_PermissionScopeAttributeExceptionDivision] ON [dbo].[PermissionScopeAttributeExceptionDivision]([PermissionID]) ON [PRIMARY]
	CREATE  UNIQUE  INDEX [IX_PermissionScopeAttributeExceptionDivision_1] ON [dbo].[PermissionScopeAttributeExceptionDivision]([PermissionID], [DivisionID]) ON [PRIMARY]
	
	ALTER TABLE [dbo].[PermissionScopeAttributeExceptionDivision] ADD 
	CONSTRAINT [FK_PermissionScopeAttributeExceptionDivision_PermissionScopeAttribute] FOREIGN KEY 
	(
		[PermissionID]
	) REFERENCES [dbo].[PermissionScopeAttribute] (
		[PermissionID]
	) ON DELETE CASCADE ,
	CONSTRAINT [FK_PermissionScopeAttributeExceptionDivision_Division] FOREIGN KEY 
	(
		[DivisionID]
	) REFERENCES [dbo].[Division] (
		[DivisionID]
	) ON DELETE CASCADE 
END
GO
IF OBJECT_ID('dbo.PermissionScopeAttributeExceptionPerson') IS NULL
BEGIN
	CREATE TABLE [dbo].[PermissionScopeAttributeExceptionPerson] (
		[ExceptionID] [int] IDENTITY (1, 1) NOT NULL ,
		[PermissionID] [int] NOT NULL ,
		[PersonID] [int] NOT NULL 
	) ON [PRIMARY]
	
	ALTER TABLE [dbo].[PermissionScopeAttributeExceptionPerson] WITH NOCHECK ADD 
	CONSTRAINT [PK_PermissionScopeAttributeExceptionPerson] PRIMARY KEY  CLUSTERED 
	(
		[ExceptionID]
	)  ON [PRIMARY] 

	CREATE  INDEX [IX_PermissionScopeAttributeExceptionPerson] ON [dbo].[PermissionScopeAttributeExceptionPerson]([PermissionID]) ON [PRIMARY]
	CREATE  UNIQUE  INDEX [IX_PermissionScopeAttributeExceptionPerson_1] ON [dbo].[PermissionScopeAttributeExceptionPerson]([PermissionID], [PersonID]) ON [PRIMARY]
	
	ALTER TABLE [dbo].[PermissionScopeAttributeExceptionPerson] ADD 
	CONSTRAINT [FK_PermissionScopeAttributeExceptionPerson_PermissionScopeAttribute] FOREIGN KEY 
	(
		[PermissionID]
	) REFERENCES [dbo].[PermissionScopeAttribute] (
		[PermissionID]
	) ON DELETE CASCADE ,
	CONSTRAINT [FK_PermissionScopeAttributeExceptionPerson_Person] FOREIGN KEY 
	(
		[PersonID]
	) REFERENCES [dbo].[Person] (
		[PersonID]
	) ON DELETE CASCADE 
END
GO





-- Returns the permission on a given attribute 
-- on a given person (employee\applicant...) for the current user
ALTER PROC dbo.spPermissionGetOnPersonForCurrentUser
	@person_id int,
	@attribute_id int,
	@permission int out
AS
DECLARE @employee_id int
DECLARE @department_id int
DECLARE @division_id int
DECLARE @location_id int
DECLARE @position_id int
DECLARE @sid varbinary(85)

SET NOCOUNT ON

IF IS_MEMBER('db_owner') = 1
	SELECT @permission = 0x7FFFFFFF
ELSE
BEGIN
	SELECT @permission = 0, @sid = SUSER_SID()

	SELECT @employee_id = EmployeeID, @division_id = DivisionID, @department_id = DepartmentID, @location_id = LocationID FROM Employee WHERE SID = SUSER_SID()

	-- Select permissions for people
	SELECT @permission = @permission | P.[Permission Mask]
	FROM PermissionScopeAttribute P
	INNER JOIN sysusers U ON P.ScopeID = 1 AND P.AttributeID = @attribute_id AND P.UID = U.uid AND (U.SID = @sid OR IS_MEMBER(U.[name]) = 1)

	-- Select permissions for applicant
	SELECT @permission = @permission | P.[Permission Mask]
	FROM PermissionScopeAttribute P
	INNER JOIN Applicant ON Applicant.ApplicantID = @person_id AND P.ScopeID = 128 AND P.AttributeID = @attribute_id
	INNER JOIN sysusers U ON P.UID = U.uid AND (U.SID = @sid OR IS_MEMBER(U.[name]) = 1)


	-- Select employee-level permissions
	SELECT @permission = @permission | P.[Permission Mask]
	FROM PermissionScopeAttribute P 
	INNER JOIN Employee E ON P.AttributeID = @attribute_id AND E.EmployeeID = @person_id
	INNER JOIN sysusers U ON P.UID = U.uid AND (U.SID = @sid OR IS_MEMBER(U.[name]) = 1)
		AND (
			(P.ScopeID = 2) OR					-- All employees								
			(P.ScopeID = 4 AND E.SID = @sid) OR			-- Self
			(P.ScopeID = 16 AND E.DivisionID = @division_id) OR	-- Employees in same division
			(P.ScopeID = 32 AND E.DepartmentID = @department_id) OR	-- Employees in same department
			(P.ScopeID = 64 AND E.LocationID = @location_id) OR	-- Employees in same location
			(P.ScopeID = 8 AND EXISTS(				-- Subordinates
				SELECT TOP 1 S.ItemID FROM EmployeeSuperior S WHERE S.EmployeeID = E.EmployeeID AND S.SuperiorID = @employee_id
			))
		)
		-- Exceptions
		AND NOT EXISTS (SELECT * FROM PermissionScopeAttributeExceptionDivision X WHERE X.PermissionID = P.PermissionID AND X.DivisionID = E.DivisionID)
		AND NOT EXISTS (SELECT * FROM PermissionScopeAttributeExceptionDepartment X WHERE X.PermissionID = P.PermissionID AND X.DepartmentID = E.DepartmentID)
		AND NOT EXISTS (SELECT * FROM PermissionScopeAttributeExceptionPerson X WHERE X.PermissionID = P.PermissionID AND X.PersonID = @person_id)
	LEFT JOIN EmployeeCompensation EC ON EC.CompensationID = E.LastCompensationID -- Position exception
	WHERE NOT EXISTS (SELECT * FROM PermissionScopeAttributeExceptionPosition X WHERE X.PermissionID = P.PermissionID AND X.PositionID = EC.PositionID)
END
GO


-- Returns the permission for the current user on several attributes
-- Fill TempPersonPermission with a random BatchID, the people under consideration, and the attributes in question
-- TempPersonPermission.[Permission Mask] will return the effective permissions
ALTER PROC dbo.spPermissionGetOnPeopleForCurrentUser
	@batch_id int
AS
DECLARE @employee_id int
DECLARE @department_id int
DECLARE @division_id int
DECLARE @location_id int
DECLARE @sid varbinary(85)
DECLARE @uid int

SET NOCOUNT ON

IF IS_MEMBER('db_owner') = 1
	UPDATE TempPersonPermission SET [Permission Mask] = 0x7FFFFFFF WHERE BatchID = @batch_id
ELSE
BEGIN
	SELECT @sid = SUSER_SID()
	SELECT @employee_id = EmployeeID, @division_id = DivisionID, @department_id = DepartmentID, @location_id = LocationID FROM Employee WHERE SID = @sid

	DECLARE user_cursor CURSOR LOCAL FOR 
	SELECT U.uid
	FROM sysusers U WHERE U.SID = @sid OR IS_MEMBER(U.[name]) = 1

	-- Loops for every user\account\role to which the current user belongs
	OPEN user_cursor
	FETCH NEXT FROM user_cursor INTO @uid
	WHILE @@FETCH_STATUS = 0
	BEGIN
		-- Merge permissions on all people
		UPDATE TPP SET [Permission Mask] = TPP.[Permission Mask] | P.[Permission Mask] 
		FROM TempPersonPermission TPP
		INNER JOIN PermissionScopeAttribute P ON TPP.BatchID = @batch_id AND P.ScopeID = 1 AND P.AttributeID = TPP.AttributeID AND P.UID = @uid

		-- Merge permissions on applicants
		UPDATE TPP SET [Permission Mask] = TPP.[Permission Mask] | P.[Permission Mask]
		FROM TempPersonPermission TPP
		INNER JOIN Applicant A ON TPP.BatchID = @batch_id AND TPP.PersonID = A.ApplicantID
		INNER JOIN PermissionScopeAttribute P ON P.ScopeID = 128 AND P.AttributeID = TPP.AttributeID AND P.UID = @uid
		
		-- Merge permissions on employees
		UPDATE TPP SET [Permission Mask] = TPP.[Permission Mask] | P.[Permission Mask]
		FROM TempPersonPermission TPP
		INNER JOIN Employee E ON TPP.BatchID = @batch_id AND TPP.PersonID = E.EmployeeID
		INNER JOIN PermissionScopeAttribute P ON P.ScopeID = 2 AND P.AttributeID = TPP.AttributeID AND P.UID = @uid
		LEFT JOIN PermissionScopeAttributeExceptionPerson X ON X.PermissionID = P.PermissionID AND X.PersonID = E.EmployeeID
		LEFT JOIN PermissionScopeAttributeExceptionDivision X3 ON X3.PermissionID = P.PermissionID AND X3.DivisionID = E.DivisionID
		LEFT JOIN PermissionScopeAttributeExceptionDepartment X4 ON X4.PermissionID = P.PermissionID AND X4.DepartmentID = E.DepartmentID
		LEFT JOIN EmployeeCompensation EC ON E.LastCompensationID = EC.CompensationID
		LEFT JOIN PermissionScopeAttributeExceptionPosition X2 ON X2.PermissionID = P.PermissionID AND X2.PositionID = EC.PositionID
		WHERE X.ExceptionID IS NULL AND X2.ExceptionID IS NULL AND X3.ExceptionID IS NULL AND X4.ExceptionID IS NULL

		-- Merge permissions on employees (self)
		UPDATE TPP SET [Permission Mask] = TPP.[Permission Mask] | P.[Permission Mask]
		FROM TempPersonPermission TPP
		INNER JOIN Employee E ON TPP.BatchID = @batch_id AND TPP.PersonID = E.EmployeeID AND E.SID = @sid
		INNER JOIN PermissionScopeAttribute P ON P.ScopeID = 4 AND P.AttributeID = TPP.AttributeID AND P.UID = @uid
		LEFT JOIN PermissionScopeAttributeExceptionPerson X ON X.PermissionID = P.PermissionID AND X.PersonID = E.EmployeeID
		LEFT JOIN PermissionScopeAttributeExceptionDivision X3 ON X3.PermissionID = P.PermissionID AND X3.DivisionID = E.DivisionID
		LEFT JOIN PermissionScopeAttributeExceptionDepartment X4 ON X4.PermissionID = P.PermissionID AND X4.DepartmentID = E.DepartmentID
		LEFT JOIN EmployeeCompensation EC ON E.LastCompensationID = EC.CompensationID
		LEFT JOIN PermissionScopeAttributeExceptionPosition X2 ON X2.PermissionID = P.PermissionID AND X2.PositionID = EC.PositionID
		WHERE X.ExceptionID IS NULL AND X2.ExceptionID IS NULL AND X3.ExceptionID IS NULL AND X4.ExceptionID IS NULL

		-- Merge permissions on employees (division)
		UPDATE TPP SET [Permission Mask] = TPP.[Permission Mask] | P.[Permission Mask]
		FROM TempPersonPermission TPP
		INNER JOIN Employee E ON TPP.BatchID = @batch_id AND TPP.PersonID = E.EmployeeID AND E.DivisionID = @division_id
		INNER JOIN PermissionScopeAttribute P ON P.ScopeID = 16 AND P.AttributeID = TPP.AttributeID AND P.UID = @uid
		LEFT JOIN PermissionScopeAttributeExceptionPerson X ON X.PermissionID = P.PermissionID AND X.PersonID = E.EmployeeID
		LEFT JOIN PermissionScopeAttributeExceptionDivision X3 ON X3.PermissionID = P.PermissionID AND X3.DivisionID = E.DivisionID
		LEFT JOIN PermissionScopeAttributeExceptionDepartment X4 ON X4.PermissionID = P.PermissionID AND X4.DepartmentID = E.DepartmentID
		LEFT JOIN EmployeeCompensation EC ON E.LastCompensationID = EC.CompensationID
		LEFT JOIN PermissionScopeAttributeExceptionPosition X2 ON X2.PermissionID = P.PermissionID AND X2.PositionID = EC.PositionID
		WHERE X.ExceptionID IS NULL AND X2.ExceptionID IS NULL AND X3.ExceptionID IS NULL AND X4.ExceptionID IS NULL

		-- Merge permissions on employees (department)
		UPDATE TPP SET [Permission Mask] = TPP.[Permission Mask] | P.[Permission Mask]
		FROM TempPersonPermission TPP
		INNER JOIN Employee E ON TPP.BatchID = @batch_id AND TPP.PersonID = E.EmployeeID AND E.SID = @sid AND E.DepartmentID = @department_id
		INNER JOIN PermissionScopeAttribute P ON P.ScopeID = 32 AND P.AttributeID = TPP.AttributeID AND P.UID = @uid
		LEFT JOIN PermissionScopeAttributeExceptionPerson X ON X.PermissionID = P.PermissionID AND X.PersonID = E.EmployeeID
		LEFT JOIN PermissionScopeAttributeExceptionDivision X3 ON X3.PermissionID = P.PermissionID AND X3.DivisionID = E.DivisionID
		LEFT JOIN PermissionScopeAttributeExceptionDepartment X4 ON X4.PermissionID = P.PermissionID AND X4.DepartmentID = E.DepartmentID
		LEFT JOIN EmployeeCompensation EC ON E.LastCompensationID = EC.CompensationID
		LEFT JOIN PermissionScopeAttributeExceptionPosition X2 ON X2.PermissionID = P.PermissionID AND X2.PositionID = EC.PositionID
		WHERE X.ExceptionID IS NULL AND X2.ExceptionID IS NULL AND X3.ExceptionID IS NULL AND X4.ExceptionID IS NULL

		-- Merge permissions on employees (location)
		UPDATE TPP SET [Permission Mask] = TPP.[Permission Mask] | P.[Permission Mask]
		FROM TempPersonPermission TPP
		INNER JOIN Employee E ON TPP.BatchID = @batch_id AND TPP.PersonID = E.EmployeeID AND E.LocationID = @location_id
		INNER JOIN PermissionScopeAttribute P ON P.ScopeID = 64 AND P.AttributeID = TPP.AttributeID AND P.UID = @uid
		LEFT JOIN PermissionScopeAttributeExceptionPerson X ON X.PermissionID = P.PermissionID AND X.PersonID = E.EmployeeID
		LEFT JOIN PermissionScopeAttributeExceptionDivision X3 ON X3.PermissionID = P.PermissionID AND X3.DivisionID = E.DivisionID
		LEFT JOIN PermissionScopeAttributeExceptionDepartment X4 ON X4.PermissionID = P.PermissionID AND X4.DepartmentID = E.DepartmentID
		LEFT JOIN EmployeeCompensation EC ON E.LastCompensationID = EC.CompensationID
		LEFT JOIN PermissionScopeAttributeExceptionPosition X2 ON X2.PermissionID = P.PermissionID AND X2.PositionID = EC.PositionID
		WHERE X.ExceptionID IS NULL AND X2.ExceptionID IS NULL AND X3.ExceptionID IS NULL AND X4.ExceptionID IS NULL

		-- Merge permissions on employees (subordinates)
		UPDATE TPP SET [Permission Mask] = TPP.[Permission Mask] | P.[Permission Mask]
		FROM TempPersonPermission TPP
		INNER JOIN Employee E ON TPP.BatchID = @batch_id AND TPP.PersonID = E.EmployeeID
		INNER JOIN EmployeeSuperior S ON S.EmployeeID = E.EmployeeID AND S.SuperiorID = @employee_id
		INNER JOIN PermissionScopeAttribute P ON P.ScopeID = 8 AND P.AttributeID = TPP.AttributeID AND P.UID = @uid
		LEFT JOIN PermissionScopeAttributeExceptionPerson X ON X.PermissionID = P.PermissionID AND X.PersonID = E.EmployeeID
		LEFT JOIN PermissionScopeAttributeExceptionDivision X3 ON X3.PermissionID = P.PermissionID AND X3.DivisionID = E.DivisionID
		LEFT JOIN PermissionScopeAttributeExceptionDepartment X4 ON X4.PermissionID = P.PermissionID AND X4.DepartmentID = E.DepartmentID
		LEFT JOIN EmployeeCompensation EC ON E.LastCompensationID = EC.CompensationID
		LEFT JOIN PermissionScopeAttributeExceptionPosition X2 ON X2.PermissionID = P.PermissionID AND X2.PositionID = EC.PositionID
		WHERE X.ExceptionID IS NULL AND X2.ExceptionID IS NULL AND X3.ExceptionID IS NULL AND X4.ExceptionID IS NULL

		FETCH NEXT FROM user_cursor INTO @uid
	END
	CLOSE user_cursor
	DEALLOCATE user_cursor
END


GO


-- Returns the permission for the current user on one attribute
-- Fill TempX with a random BatchID and the people under consideration
-- TempX.X will return the effective permissions
ALTER PROC dbo.spPermissionGetOnPeopleForCurrentUser2
	@batch_id int,
	@attribute_id int
AS
DECLARE @employee_id int
DECLARE @department_id int
DECLARE @division_id int
DECLARE @location_id int
DECLARE @sid varbinary(85)
DECLARE @uid int

SET NOCOUNT ON

IF IS_MEMBER('db_owner') = 1
	UPDATE TempX SET X = 0x7FFFFFFF WHERE BatchID = @batch_id
ELSE
BEGIN
	UPDATE TempX SET X = 0 WHERE BatchID = @batch_id

	SELECT @sid = SUSER_SID()
	SELECT @employee_id = EmployeeID, @division_id = DivisionID, @department_id = DepartmentID, @location_id = LocationID FROM Employee WHERE SID = @sid

	DECLARE user_cursor CURSOR LOCAL FOR 
	SELECT U.uid
	FROM sysusers U WHERE U.SID = @sid OR IS_MEMBER(U.[name]) = 1

	-- Loops for every user\account\role to which the current user belongs
	OPEN user_cursor
	FETCH NEXT FROM user_cursor INTO @uid
	WHILE @@FETCH_STATUS = 0
	BEGIN
		-- Merge permissions on all people
		UPDATE TPP SET [X] = TPP.[X] | P.[Permission Mask] 
		FROM TempX TPP
		INNER JOIN PermissionScopeAttribute P ON TPP.BatchID = @batch_id AND P.ScopeID = 1 AND P.AttributeID = @attribute_id AND P.UID = @uid

		-- Merge permissions on applicants
		UPDATE TPP SET [X] = TPP.[X] | P.[Permission Mask]
		FROM TempX TPP
		INNER JOIN Applicant A ON TPP.BatchID = @batch_id AND TPP.[ID] = A.ApplicantID
		INNER JOIN PermissionScopeAttribute P ON P.ScopeID = 128 AND P.AttributeID = @attribute_id AND P.UID = @uid
		
		-- Merge permissions on employees
		UPDATE TPP SET [X] = TPP.[X] | P.[Permission Mask]
		FROM TempX TPP
		INNER JOIN Employee E ON TPP.BatchID = @batch_id AND TPP.[ID] = E.EmployeeID
		INNER JOIN PermissionScopeAttribute P ON P.ScopeID = 2 AND P.AttributeID = @attribute_id AND P.UID = @uid
		LEFT JOIN PermissionScopeAttributeExceptionPerson X ON X.PermissionID = P.PermissionID AND X.PersonID = E.EmployeeID
		LEFT JOIN PermissionScopeAttributeExceptionDivision X3 ON X3.PermissionID = P.PermissionID AND X3.DivisionID = E.DivisionID
		LEFT JOIN PermissionScopeAttributeExceptionDepartment X4 ON X4.PermissionID = P.PermissionID AND X4.DepartmentID = E.DepartmentID
		LEFT JOIN EmployeeCompensation EC ON E.LastCompensationID = EC.CompensationID
		LEFT JOIN PermissionScopeAttributeExceptionPosition X2 ON X2.PermissionID = P.PermissionID AND X2.PositionID = EC.PositionID
		WHERE X.ExceptionID IS NULL AND X2.ExceptionID IS NULL AND X3.ExceptionID IS NULL AND X4.ExceptionID IS NULL

		-- Merge permissions on employees (self)
		UPDATE TPP SET [X] = TPP.[X] | P.[Permission Mask]
		FROM TempX TPP
		INNER JOIN Employee E ON TPP.BatchID = @batch_id AND TPP.[ID] = E.EmployeeID AND E.SID = @sid
		INNER JOIN PermissionScopeAttribute P ON P.ScopeID = 4 AND P.AttributeID = @attribute_id AND P.UID = @uid
		LEFT JOIN PermissionScopeAttributeExceptionPerson X ON X.PermissionID = P.PermissionID AND X.PersonID = E.EmployeeID
		LEFT JOIN PermissionScopeAttributeExceptionDivision X3 ON X3.PermissionID = P.PermissionID AND X3.DivisionID = E.DivisionID
		LEFT JOIN PermissionScopeAttributeExceptionDepartment X4 ON X4.PermissionID = P.PermissionID AND X4.DepartmentID = E.DepartmentID
		LEFT JOIN EmployeeCompensation EC ON E.LastCompensationID = EC.CompensationID
		LEFT JOIN PermissionScopeAttributeExceptionPosition X2 ON X2.PermissionID = P.PermissionID AND X2.PositionID = EC.PositionID
		WHERE X.ExceptionID IS NULL AND X2.ExceptionID IS NULL AND X3.ExceptionID IS NULL AND X4.ExceptionID IS NULL

		-- Merge permissions on employees (division)
		UPDATE TPP SET [X] = TPP.[X] | P.[Permission Mask]
		FROM TempX TPP
		INNER JOIN Employee E ON TPP.BatchID = @batch_id AND TPP.[ID] = E.EmployeeID AND E.DivisionID = @division_id
		INNER JOIN PermissionScopeAttribute P ON P.ScopeID = 16 AND P.AttributeID = @attribute_id AND P.UID = @uid
		LEFT JOIN PermissionScopeAttributeExceptionPerson X ON X.PermissionID = P.PermissionID AND X.PersonID = E.EmployeeID
		LEFT JOIN PermissionScopeAttributeExceptionDivision X3 ON X3.PermissionID = P.PermissionID AND X3.DivisionID = E.DivisionID
		LEFT JOIN PermissionScopeAttributeExceptionDepartment X4 ON X4.PermissionID = P.PermissionID AND X4.DepartmentID = E.DepartmentID
		LEFT JOIN EmployeeCompensation EC ON E.LastCompensationID = EC.CompensationID
		LEFT JOIN PermissionScopeAttributeExceptionPosition X2 ON X2.PermissionID = P.PermissionID AND X2.PositionID = EC.PositionID
		WHERE X.ExceptionID IS NULL AND X2.ExceptionID IS NULL AND X3.ExceptionID IS NULL AND X4.ExceptionID IS NULL

		-- Merge permissions on employees (department)
		UPDATE TPP SET [X] = TPP.[X] | P.[Permission Mask]
		FROM TempX TPP
		INNER JOIN Employee E ON TPP.BatchID = @batch_id AND TPP.[ID] = E.EmployeeID AND E.SID = @sid AND E.DepartmentID = @department_id
		INNER JOIN PermissionScopeAttribute P ON P.ScopeID = 32 AND P.AttributeID = @attribute_id AND P.UID = @uid
		LEFT JOIN PermissionScopeAttributeExceptionPerson X ON X.PermissionID = P.PermissionID AND X.PersonID = E.EmployeeID
		LEFT JOIN PermissionScopeAttributeExceptionDivision X3 ON X3.PermissionID = P.PermissionID AND X3.DivisionID = E.DivisionID
		LEFT JOIN PermissionScopeAttributeExceptionDepartment X4 ON X4.PermissionID = P.PermissionID AND X4.DepartmentID = E.DepartmentID
		LEFT JOIN EmployeeCompensation EC ON E.LastCompensationID = EC.CompensationID
		LEFT JOIN PermissionScopeAttributeExceptionPosition X2 ON X2.PermissionID = P.PermissionID AND X2.PositionID = EC.PositionID
		WHERE X.ExceptionID IS NULL AND X2.ExceptionID IS NULL AND X3.ExceptionID IS NULL AND X4.ExceptionID IS NULL

		-- Merge permissions on employees (location)
		UPDATE TPP SET [X] = TPP.[X] | P.[Permission Mask]
		FROM TempX TPP
		INNER JOIN Employee E ON TPP.BatchID = @batch_id AND TPP.[ID] = E.EmployeeID AND E.LocationID = @location_id
		INNER JOIN PermissionScopeAttribute P ON P.ScopeID = 64 AND P.AttributeID = @attribute_id AND P.UID = @uid
		LEFT JOIN PermissionScopeAttributeExceptionPerson X ON X.PermissionID = P.PermissionID AND X.PersonID = E.EmployeeID
		LEFT JOIN PermissionScopeAttributeExceptionDivision X3 ON X3.PermissionID = P.PermissionID AND X3.DivisionID = E.DivisionID
		LEFT JOIN PermissionScopeAttributeExceptionDepartment X4 ON X4.PermissionID = P.PermissionID AND X4.DepartmentID = E.DepartmentID
		LEFT JOIN EmployeeCompensation EC ON E.LastCompensationID = EC.CompensationID
		LEFT JOIN PermissionScopeAttributeExceptionPosition X2 ON X2.PermissionID = P.PermissionID AND X2.PositionID = EC.PositionID
		WHERE X.ExceptionID IS NULL AND X2.ExceptionID IS NULL AND X3.ExceptionID IS NULL AND X4.ExceptionID IS NULL

		-- Merge permissions on employees (subordinates)
		UPDATE TPP SET [X] = TPP.[X] | P.[Permission Mask]
		FROM TempX TPP
		INNER JOIN Employee E ON TPP.BatchID = @batch_id AND TPP.[ID] = E.EmployeeID
		INNER JOIN EmployeeSuperior S ON S.EmployeeID = E.EmployeeID AND S.SuperiorID = @employee_id
		INNER JOIN PermissionScopeAttribute P ON P.ScopeID = 8 AND P.AttributeID = @attribute_id AND P.UID = @uid
		LEFT JOIN PermissionScopeAttributeExceptionPerson X ON X.PermissionID = P.PermissionID AND X.PersonID = E.EmployeeID
		LEFT JOIN PermissionScopeAttributeExceptionDivision X3 ON X3.PermissionID = P.PermissionID AND X3.DivisionID = E.DivisionID
		LEFT JOIN PermissionScopeAttributeExceptionDepartment X4 ON X4.PermissionID = P.PermissionID AND X4.DepartmentID = E.DepartmentID
		LEFT JOIN EmployeeCompensation EC ON E.LastCompensationID = EC.CompensationID
		LEFT JOIN PermissionScopeAttributeExceptionPosition X2 ON X2.PermissionID = P.PermissionID AND X2.PositionID = EC.PositionID
		WHERE X.ExceptionID IS NULL AND X2.ExceptionID IS NULL AND X3.ExceptionID IS NULL AND X4.ExceptionID IS NULL

		FETCH NEXT FROM user_cursor INTO @uid
	END
	CLOSE user_cursor
	DEALLOCATE user_cursor
END
GO


IF OBJECT_ID('dbo.spEmployeeTimeList3') IS NOT NULL DROP PROC dbo.spEmployeeTimeList3
GO
CREATE PROC dbo.spEmployeeTimeList3
	@employee_id int,
	@start_day int,
	@stop_day int
AS
SET NOCOUNT ON

CREATE TABLE #ET([Day past 1900] int PRIMARY KEY, IN1 smalldatetime NULL, OUT1 smalldatetime NULL, IN2 smalldatetime NULL, OUT2 smalldatetime NULL, IN3 smalldatetime NULL, OUT3 smalldatetime NULL, [Holiday Seconds] int DEFAULT 0, [Timecard Seconds] int DEFAULT 0, [Paid Leave Seconds] int DEFAULT 0, [Payroll Start] smalldatetime, [Payroll Stop] smalldatetime)

DECLARE @authorized bit
EXEC spPermissionInsureForCurrentUserOnPerson @employee_id, 262144, 1, @authorized out

IF @authorized = 1
BEGIN
	CREATE INDEX #ET_IN1 ON #ET(IN1)
	CREATE INDEX #ET_IN2 ON #ET(IN2)
	
	INSERT #ET([Day past 1900], IN1, OUT1)
	SELECT ET.[In Day past 1900], MIN(ET.[In]), MIN(ET.[Out])
	FROM vwEmployeeTime ET WHERE ET.EmployeeID = @employee_id AND ET.[In Day past 1900] BETWEEN @start_day AND @stop_day
	GROUP BY [In Day past 1900]


	INSERT #ET([Day past 1900])
	SELECT [Day past 1900] 
	FROM vwEmployeeLeaveApproved L
	INNER JOIN LeaveType T ON L.Seconds < 0 AND L.TypeID = T.TypeID AND T.Paid = 1 AND L.EmployeeID = @employee_id AND [Day past 1900] BETWEEN @start_day AND @stop_day AND [Day past 1900] NOT IN
	(
		SELECT [Day past 1900] FROM #ET
	)
	


	
	
	UPDATE #ET SET IN2 = (
		SELECT TOP 1 ET.[In]
		FROM vwEmployeeTime ET WHERE ET.EmployeeID = @employee_id AND ET.[In Day past 1900] = #ET.[Day past 1900] AND ET.[In] > #ET.IN1
		ORDER BY ET.[In]
	),
	OUT2 = (
		SELECT TOP 1 ET.[Out]
		FROM vwEmployeeTime ET WHERE ET.EmployeeID = @employee_id AND ET.[In Day past 1900] = #ET.[Day past 1900] AND ET.[In] > #ET.IN1
		ORDER BY ET.[In]
	),
	[Timecard Seconds] = ISNULL((
		SELECT SUM(CASE WHEN ET.[Out] IS NULL THEN 0 ELSE DATEDIFF(s, ET.[In], ET.[Out]) END)
		FROM vwEmployeeTime ET WHERE ET.EmployeeID = @employee_id AND ET.[In Day past 1900] = #ET.[Day past 1900]
	), 0)
	
	UPDATE #ET SET IN3 = (
		SELECT TOP 1 ET.[In]
		FROM vwEmployeeTime ET WHERE ET.EmployeeID = @employee_id AND ET.[In Day past 1900] = #ET.[Day past 1900] AND ET.[In] > #ET.IN2
		ORDER BY ET.[In]
	),
	OUT3 = (
		SELECT TOP 1 ET.[Out]
		FROM vwEmployeeTime ET WHERE ET.EmployeeID = @employee_id AND ET.[In Day past 1900] = #ET.[Day past 1900] AND ET.[In] > #ET.IN2
		ORDER BY ET.[In]
	)
	
	
	UPDATE #ET SET [Paid Leave Seconds] =
	ISNULL((
		SELECT SUM(-L.Seconds) FROM vwEmployeeLeaveApproved L WHERE L.Seconds < 0 AND L.EmployeeID = @employee_ID AND L.[Day past 1900] = #ET.[Day past 1900]
	), 0)
	
	-- Holiday time
	UPDATE #ET SET [Holiday Seconds] = [Timecard Seconds], [Timecard Seconds] = 0, IN1 = NULL, OUT1 = NULL, IN2 = NULL, OUT2 = NULL, IN3 = NULL, OUT3 = NULL
	FROM #ET INNER JOIN Holiday H ON (H.[Year] IS NOT NULL AND dbo.GetDateFromDaysPast1900(#ET.[Day past 1900]) = dbo.GetDateFromMDY(H.[Month], H.[Day], H.[Year])) OR
	(H.[Year] IS NULL AND MONTH(dbo.GetDateFromDaysPast1900(#ET.[Day past 1900])) = H.[Month] AND DAY(dbo.GetDateFromDaysPast1900(#ET.[Day past 1900])) = H.[Day])

	-- Rounding
	DECLARE @rounding decimal
	SELECT @rounding = [Timecard Rounding] FROM Constant
	UPDATE #ET SET [Timecard Seconds] = ROUND([Timecard Seconds] / @rounding, 0) * @rounding

	-- Insert blanks for empty weekdays
	DECLARE @dt datetime, @dti int, @dts int
	SELECT TOP 1 @dti = [Day past 1900] FROM #ET ORDER BY [Day past 1900]
	SELECT TOP 1 @dts = [Day past 1900] FROM #ET ORDER BY [Day past 1900] DESC
	
	SELECT @dti = @dti + 1 - DATEPART(dw, @dti), @dts = @dts + 7 - DATEPART(dw, @dts)
	SET @dt = DATEADD(d, 0, @dti)

	IF @dts > @stop_day SET @dts = @stop_day

	WHILE @dti <= @dts
	BEGIN
		IF (DATEPART(dw, @dt) BETWEEN 2 AND 6) AND NOT EXISTS(SELECT * FROM #ET WHERE [Day past 1900] = @dti) INSERT #ET([Day past 1900]) VALUES(@dti)
		SELECT @dt = DATEADD(d, 1, @dt)	, @dti = @dti + 1
	END

	-- Calculate payroll start dates
	CREATE TABLE #T(StartDate datetime, StopDate datetime)


	WHILE EXISTS(SELECT * FROM #ET WHERE [Payroll Start] IS NULL)
	BEGIN
		SELECT TOP 1 @dt = DATEADD(d, [Day past 1900], 0) FROM #ET WHERE [Payroll Start] IS NULL

		DELETE #T
		INSERT #T
		EXEC spEmployeeTimeCalculateFilterInverse @dt, 5
	
		UPDATE #ET SET [Payroll Start] = T.StartDate, [Payroll Stop] = T.StopDate
		FROM #ET
		INNER JOIN #T T ON #ET.[Payroll Start] IS NULL AND DATEADD(d, [Day past 1900], 0) BETWEEN T.StartDate AND T.StopDate
	END
END


SELECT [Date] = DATEADD(d, 0, [Day past 1900]), [Payroll Start], [Payroll Stop],
[Week Start] = DATEADD(dd, 1 - DATEPART(dw, [Day past 1900]), [Day past 1900]),
IN1, OUT1, HOURS1 = DATEDIFF(s, IN1, OUT1) / 3600.0, 
IN2, OUT2, HOURS2 = DATEDIFF(s, IN2, OUT2) / 3600.0, 
IN3, OUT3, HOURS3 = DATEDIFF(s, IN3, OUT3) / 3600.0,
[Paid Leave Hours] = [Paid Leave Seconds] / 3600.0,
[Timecard Hours] = [Timecard Seconds] / 3600.0,
[Holiday Hours] = [Holiday Seconds] / 3600.0,
[Total Hours] = ([Holiday Seconds] + [Timecard Seconds] + [Paid Leave Seconds]) / 3600.0
FROM #ET ORDER BY [Day past 1900]

GO
GRANT EXEC ON dbo.spEmployeeTimeList3 TO public

UPDATE Constant SET [Server Version] = 27

