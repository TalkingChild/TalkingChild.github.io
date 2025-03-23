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

