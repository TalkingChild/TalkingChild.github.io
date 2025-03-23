-- Makes sure that the server collation is case insensitive
DECLARE @db sysname, @collation sysname--, @collation2 sysname, @collation3 sysname
SELECT @db=db_name()

SELECT @collation = CAST(DATABASEPROPERTYEX(@db, 'Collation') AS sysname)
--SELECT @collation2 = CAST(DATABASEPROPERTYEX('master', 'Collation') AS sysname)
--SELECT @collation3 = CAST(DATABASEPROPERTYEX('tempdb', 'Collation') AS sysname)

IF @collation LIKE '%_CS_%' -- OR @collation2 LIKE '%_CS_%' OR @collation3 LIKE '%_CS_%'
BEGIN
	DECLARE @message nvarchar(4000)
	SET @message = 'Updates will not work on a SQL Server instance that uses a case sensitive collation. Your instance uses ' + @collation +'. You must move the ' + @db + ' database to a SQL Server instance that uses a case INSENSITIVE collation, preferrably SQL_Latin1_General_CP1_CI_AS. Using Microsoft SQL Server Management Studio, you can check the collation settings on any installed instances. Case insenstive collations include _CI_ in their names (instead of _CS_). If no currently-installed instances are case insensitive then you must install a new instance and move the database.'
	RAISERROR(@message,16,1)
END
GO
-- Settings to support indexed views
DECLARE @db sysname
SELECT @db=db_name()
EXEC dbo.sp_dboption @db, 'quoted identifier', 'on'
EXEC dbo.sp_dboption @db, 'concat null yields null', 'on'
EXEC dbo.sp_dboption @db, 'ansi null default', 'on'
EXEC dbo.sp_dboption @db, 'ansi nulls', 'on'
EXEC dbo.sp_dboption @db, 'ansi padding', 'on'
EXEC dbo.sp_dboption @db, 'ansi warnings', 'on'
EXEC dbo.sp_dboption @db, 'arithabort', 'on'
EXEC dbo.sp_dboption @db, 'numeric roundabort', 'off'
GO
ALTER PROC dbo.spPermissionGetOnPeopleForCurrentUser
	@batch_id int
AS
IF IS_MEMBER('db_owner') = 1 UPDATE TempPersonPermission SET [Permission Mask] = 0x7FFFFFFF WHERE BatchID = @batch_id
ELSE UPDATE TempPersonPermission SET [Permission Mask] = 0 WHERE BatchID = @batch_id
GO
IF OBJECT_ID('dbo.CheckPeriodOnEmployeeCompensation') IS NOT NULL DROP TRIGGER dbo.CheckPeriodOnEmployeeCompensation
GO
IF OBJECT_ID('dbo.spAdminDropDefault') IS NULL EXEC sp_executesql N'CREATE PROC dbo.spAdminDropDefault AS'
GO
ALTER PROC dbo.spAdminDropDefault @table sysname, @column sysname AS
DECLARE @sql nvarchar(4000)
SELECT TOP 1 @sql = OBJECT_NAME(O.id) from sysconstraints D
INNER JOIN syscolumns COL ON D.id=object_id(@table) AND COL.colid = D.colid AND COL.[name] = @column
INNER JOIN sysobjects O ON D.constid = O.id AND O.Type = 'D'
SELECT @sql = 'ALTER TABLE ' + @table + ' DROP CONSTRAINT ' + @sql
EXEC sp_executesql @sql
GO
IF OBJECT_ID('dbo.vwEmployeeCompensation') IS NULL EXEC sp_executesql N'CREATE VIEW dbo.vwEmployeeCompensation AS SELECT A=0'
GO
ALTER VIEW dbo.vwEmployeeCompensation
AS
SELECT
CompensationID=0,
EmployeeID=0,
PeriodID=0,
EmploymentStatusID=0,
[Start Day past 1900]=0,
[Stop Day past 1900]=NULL,
Note=CAST('' AS varchar(4000)),
PositionID=0,
[Base Pay]=CAST(0 AS money),
[Other Compensation]=CAST('' AS varchar(4000)),
Budgeted=CAST(0 AS bit),
PayStepID=0,
StartEventID=0,
StopEventID=NULL, 
Employee = CAST('' AS varchar(400)),
[Employee Full Name] = CAST('' AS varchar(400)),
[Annualized Pay Range] = CAST('' AS varchar(400)),
[Annualized Pay] = CAST(0 AS money),
[Annualized Adjustment Min] = CAST(0 AS money),
[Annualized Adjustment Max] = CAST(0 AS money),
[Annualized Employer Premiums] = CAST(0 AS money),
[Employer Premiums] = CAST(0 AS money),
[Hourly Pay] = CAST(0 AS money),
[Job Title] = CAST('' AS varchar(400)),
[Start] = CAST('Jan 1 2000' AS datetime),
[FLSA Exempt]=CAST(1 AS bit),
Period = CAST('' AS varchar(50)),
Status = CAST('' AS varchar(50)),
[Receives Other Compensation] = CAST(1 AS bit),
[Employment Status] = CAST('' AS varchar(50)),
FTE = CAST(0 AS numeric(9,4)),
CategoryID = 1,
Category = CAST('' AS varchar(50)),
[Pay Step] = 1,
[FLSA Status] = CAST('' AS varchar(50)),
[Report Row] = 1,
FTE40 = CAST(0 AS numeric(9,4)),
[Seconds per Week] = 0,
[Start Event] = CAST('' AS varchar(50)),
[Stop Event] = CAST('' AS varchar(50)),
[Start Event Flags] = 0,
[Stop Event Flags] = 0,
[Position Number] = CAST('' AS varchar(50)),
[Pay Grade] = CAST('' AS varchar(50))
GO
IF OBJECT_ID('dbo.vwEmployeeLeaveUsedItemApproved') IS NOT NULL DROP VIEW dbo.vwEmployeeLeaveUsedItemApproved
GO
CREATE VIEW dbo.vwEmployeeLeaveUsedItemApproved
AS
SELECT [Day past 1900]=0, Seconds=0, [Date]=Convert(datetime,'20000101',112), [Extended Type Mask]=0, TypeID=0, EmployeeID=0, ReasonID=0
GO
IF OBJECT_ID('dbo.vwEmployeeLeaveUsedItem') IS NOT NULL DROP VIEW dbo.vwEmployeeLeaveUsedItem
GO
CREATE VIEW dbo.vwEmployeeLeaveUsedItem AS
SELECT ItemID=0, LeaveID=0, TypeID=0, [Day past 1900]=0, Seconds=0, [Advanced Type Mask]=0, [Date]=Convert(datetime,'20000101',112),
[Extended Type Mask]=0, EmployeeID=0, ReasonID=0, [Status]=0, [PPE Day past 1900]=0, PPE=Convert(datetime,'20000101',112), [Type]='',
Paid=CAST(0 as bit), [OT Eligible]=CAST(0 as bit), [Order]=0, Abbreviation=''
GO
ALTER VIEW dbo.vwEmployeeTime
AS
SELECT
ItemID=0,
EmployeeID=0,
[In]=Convert(datetime,'20000101',112),
Seconds=0,
ProjectID=0,
TaskID=0,
StatusID=0,
[Employee Comment]='',
[Manager Comment]='',
[Pay Rate]=CAST(0 AS money),
[Billing Rate]=CAST(0 AS money),
TypeID=0,
[Odometer Start]=0,
[Odometer Stop]=0,
[Created Day past 1900]=0,
[Last Updated Day past 1900]=0,
[Fixed Billing]=CAST(0 AS money),
[Fixed Pay]=CAST(0 AS money),
SourceIn='',
SourceOut='',
[PPE Day past 1900]=0,
[Type]='',
[Order]=0,
Abbreviation='',
[OT Eligible]=CAST(0 AS bit),
CompLeaveTypeID=0,
[Comp Leave Type]=0,
Employee=0,
[Status]=0,
Hours=CAST(0 AS numeric(9,5)),
Task='',
Project='',
ProjectClassID = 0,
Mileage = 0,
[Out] = Convert(datetime,'20000101',112), 
[In Day Past 1900] = Convert(datetime,'20000101',112),
[Out Day Past 1900] = 0,
[Project Class] = '',
Regular = CAST(0 AS bit),
[Project Number] = '',
PPE = 0,
OT = CAST(0 as bit),
Flags = 0,
[OT Disable] = CAST(0 as bit),
[GMT+Hours] = NULL,
[Time Flags] = 0,
[Payroll Delay]=0
GO
IF OBJECT_id('dbo.CompensationAdjustment') IS NULL
BEGIN
CREATE TABLE dbo.CompensationAdjustment (
	[AdjustmentID] [int] IDENTITY (1, 1) NOT NULL ,
	[Adjustment] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[PeriodID] [int] NULL 
) ON [PRIMARY]

ALTER TABLE dbo.CompensationAdjustment WITH NOCHECK ADD 
	CONSTRAINT [PK_CompensationAdjustment] PRIMARY KEY  CLUSTERED 
	(
		[AdjustmentID]
	)  ON [PRIMARY] 

ALTER TABLE dbo.CompensationAdjustment ADD 
	CONSTRAINT [IX_CompensationAdjustment_Unique] UNIQUE  NONCLUSTERED 
	(
		[Adjustment]
	)  ON [PRIMARY] ,
	CONSTRAINT [CK_CompensationAdjustment_Blank] CHECK (len([Adjustment]) > 0)
END
GO
IF OBJECT_id('dbo.EmployeeCompensationAdjustment') IS NULL
BEGIN
CREATE TABLE dbo.EmployeeCompensationAdjustment (
	[ItemID] [int] IDENTITY (1, 1) NOT NULL ,
	[AdjustmentID] [int] NOT NULL ,
	[CompensationID] [int] NOT NULL ,
	[Minimum Adjustment] [money] NOT NULL ,
	[Maximum Adjustment] [money] NOT NULL 
) ON [PRIMARY]


ALTER TABLE dbo.[EmployeeCompensationAdjustment] WITH NOCHECK ADD 
	CONSTRAINT [PK_EmployeeCompensationAdjustment] PRIMARY KEY  CLUSTERED 
	(
		[ItemID]
	)  ON [PRIMARY] 


ALTER TABLE dbo.[EmployeeCompensationAdjustment] ADD 
	CONSTRAINT [CK_EmployeeCompensationAdjustment_MaxLessThanMin] CHECK ([Maximum Adjustment] >= [Minimum Adjustment])

ALTER TABLE dbo.[EmployeeCompensationAdjustment] ADD 
	CONSTRAINT [FK_EmployeeCompensationAdjustment_CompensationAdjustment] FOREIGN KEY 
	(
		[AdjustmentID]
	) REFERENCES dbo.CompensationAdjustment (
		[AdjustmentID]
	) ON DELETE CASCADE ,
	CONSTRAINT [FK_EmployeeCompensationAdjustment_EmployeeCompensation] FOREIGN KEY 
	(
		[CompensationID]
	) REFERENCES dbo.[EmployeeCompensation] (
		[CompensationID]
	) ON DELETE CASCADE 
END
GO
IF OBJECT_id('dbo.PK_PermissionObject') IS NOT NULL ALTER TABLE dbo.PermissionObject DROP PK_PermissionObject
DELETE PermissionObjectX
DELETE PermissionObject

ALTER TABLE dbo.[PermissionObject] WITH NOCHECK ADD 
	CONSTRAINT [PK_PermissionObject] PRIMARY KEY CLUSTERED 
	(
		[ObjectID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
GO




DELETE ColumnGrid WHERE FieldID = 57
GO
UPDATE Constant SET DefaultLeaveRatePeriodID = 22530 WHERE DefaultLeaveRatePeriodID NOT IN
(
	SELECT PeriodID FROM LeaveRatePeriod
)

IF OBJECT_id('dbo.FK_Constant_LeaveRatePeriod') IS NULL ALTER TABLE dbo.[Constant] ADD 
CONSTRAINT [FK_Constant_LeaveRatePeriod] FOREIGN KEY 
(
	[DefaultLeaveRatePeriodID]
) REFERENCES dbo.[LeaveRatePeriod] (
	[PeriodID]
)

IF OBJECT_id('dbo.FK_EmployeeCompensation_Position') IS NULL 
BEGIN
	DELETE EmployeeCompensation WHERE PositionID NOT IN (SELECT PositionID FROM Position)
	ALTER TABLE dbo.[EmployeeCompensation] ADD 
	CONSTRAINT [FK_EmployeeCompensation_Position] FOREIGN KEY 
	(
		[PositionID]
	) REFERENCES dbo.[Position] (
		[PositionID]
	)
END
GO
IF OBJECT_id('dbo.vwEmployeeEffectiveSecondsPerDay') IS NULL EXEC sp_executesql N'CREATE VIEW dbo.vwEmployeeEffectiveSecondsPerDay AS SELECT A=0'
GO
ALTER VIEW dbo.vwEmployeeEffectiveSecondsPerDay
AS
SELECT EmployeeID = 0,
[Effective Seconds per Day] = 0,
[Shift Seconds per Day] = 0,
[Seconds per Day Override] = 0,
[Days On] = 0,
[Days Off] = 0,
ShiftID = 0,
[Leave Accrual Multiplier] = CAST(0 as numeric(9,4)),
[Shift FTE] = CAST(0 as numeric(9,4)),
DaysOn2 = 0,
DaysOff2 = 0
GO
ALTER PROC dbo.spTDRPGetName
	@tdrp_id int,
	@tdrp varchar(50) out
AS
SET NOCOUNT ON

SELECT @tdrp = ''
SELECT @tdrp = TDRP FROM TDRP WHERE TDRPID = @tdrp_id
GO
ALTER PROC dbo.spLeavePlanAutoCreate
	@plan varchar(50),
	@description varchar(4000),
	@primary_id int,
	@primary_start_month int,
	@primary_seconds int,
	@period_id int,
	@bump1_start_month int,
	@bump1_seconds int,
	@bump2_start_month int,
	@bump2_seconds int,
	@secondary_id int,
	@secondary_seconds int,
	@tertiary_id int,
	@tertiary_seconds int,
	@fte numeric(9,4),
	@requires_6_months bit,
	@plan_id int OUT
AS
SET NOCOUNT ON

INSERT LeavePlan([Plan], [Description], FTE)
VALUES (@plan, @description, @fte)
SELECT @plan_id = SCOPE_IDENTITY()

DECLARE @stop_month int

-- Primary
IF @primary_id IS NOT NULL
BEGIN
	IF @requires_6_months = 1 AND @primary_start_month = 0 AND (@bump1_start_month IS NULL OR @bump1_start_month > 6) AND  (@bump2_start_month IS NULL OR @bump2_start_month > 6)
	BEGIN
		INSERT LeaveRate(PlanID, TypeID, [Start Month], [Stop Month], Seconds, PeriodID)
		SELECT @plan_id, @primary_id, 0, 5, @primary_seconds * @fte *  (7488000.0 / P.Seconds) / 2, 63492
		FROM Period P WHERE P.PeriodID = @period_id & 1023

		SET @primary_start_month = 6
	END

	IF @primary_start_month IS NOT NULL AND @primary_seconds IS NOT NULL
	BEGIN
		SELECT @stop_month = CASE 
			WHEN @bump1_start_month IS NOT NULL THEN @bump1_start_month - 1
			WHEN @bump2_start_month IS NOT NULL THEN @bump2_start_month - 1
			ELSE 0x7FFFFFFF
		END

		INSERT LeaveRate(PlanID, TypeID, [Start Month], [Stop Month], Seconds, PeriodID)
		VALUES(@plan_id, @primary_id, @primary_start_month, @stop_month, @primary_seconds * @fte, @period_id)
	END

	IF @bump1_start_month IS NOT NULL AND @bump1_seconds IS NOT NULL
	BEGIN
		SELECT @stop_month = CASE 
			WHEN @bump2_start_month IS NOT NULL THEN @bump2_start_month - 1
			ELSE 0x7FFFFFFF
		END

		INSERT LeaveRate(PlanID, TypeID, [Start Month], [Stop Month], Seconds, PeriodID)
		VALUES(@plan_id, @primary_id, @bump1_start_month, @stop_month, @bump1_seconds * @fte, @period_id)
	END

	IF @bump2_start_month IS NOT NULL AND @bump2_seconds IS NOT NULL
	BEGIN
		INSERT LeaveRate(PlanID, TypeID, [Start Month], [Stop Month], Seconds, PeriodID)
		VALUES(@plan_id, @primary_id, @bump2_start_month, 0x7FFFFFFF, @bump2_seconds * @fte, @period_id)
	END
END

-- Secondary
IF @secondary_id IS NOT NULL AND @secondary_seconds IS NOT NULL
BEGIN
	INSERT LeaveRate(PlanID, TypeID, [Start Month], [Stop Month], Seconds, PeriodID)
	VALUES(@plan_id, @secondary_id, 0, 0x7FFFFFFF, @secondary_seconds * @fte, 32770)
END

-- Tertiary
IF @tertiary_id IS NOT NULL AND @tertiary_seconds IS NOT NULL
BEGIN
	INSERT LeaveRate(PlanID, TypeID, [Start Month], [Stop Month], Seconds, PeriodID)
	VALUES(@plan_id, @tertiary_id, 0, 0x7FFFFFFF, @tertiary_seconds * @fte, 32770)
END

-- Advanced leave
INSERT LeaveRate(PlanID, TypeID, [Start Month], [Stop Month], Seconds, PeriodID)
SELECT @plan_id, TypeID, 0, 0x7FFFFFFF, [Initial Seconds] * @fte, InitialPeriodID FROM LeaveType WHERE [Initial Seconds] IS NOT NULL  AND InitialPeriodID IS NOT NULL
GO
ALTER PROC dbo.spLeaveTypeDelete
	@type_id int,
	@new_type_id int
AS
DECLARE @error int

SET NOCOUNT ON
SELECT @error = 0

BEGIN TRAN

IF @new_type_id IS NULL 
BEGIN
	DELETE EmployeeLeaveUsedItem WHERE @type_id = TypeID
END
ELSE
BEGIN
	UPDATE EmployeeLeaveUsedItem SET TypeID = @new_type_id WHERE TypeID = @type_id
	UPDATE EmployeeLeaveUsed SET [Advanced Type Mask] = [Advanced Type Mask] | @new_type_id WHERE ([Advanced Type Mask] &  @type_id) != 0

END

SELECT @error = @@ERROR

IF @error = 0 
BEGIN
	UPDATE EmployeeLeaveUsed SET [Advanced Type Mask] = [Advanced Type Mask] & (~@type_id)
	SELECT @error = @@ERROR
END

IF @error = 0
BEGIN
	UPDATE Constant SET CarryoverSourceLeaveTypeID = NULL, CarryoverTargetLeaveTypeID = NULL WHERE @type_id IN  (CarryoverSourceLeaveTypeID, CarryoverTargetLeaveTypeID)
	SELECT @error = @@ERROR
END


IF @error = 0 
BEGIN
	DELETE LeaveRate WHERE @type_id = TypeID
	SELECT @error = @@ERROR
END


IF @error = 0 
BEGIN
	DELETE EmployeeLeaveUnused WHERE @type_id = TypeID
	SELECT @error = @@ERROR
END

IF @error = 0 
BEGIN
	DELETE EmployeeLeaveEarned WHERE @type_id = TypeID
	SELECT @error = @@ERROR
END

IF @error = 0 
BEGIN
	DELETE EmployeeLeaveUsedItem WHERE @type_id = TypeID
	SELECT @error = @@ERROR
END

IF @error = 0 
BEGIN
	DELETE LeaveLimit WHERE @type_id = TypeID
	SELECT @error = @@ERROR
END

IF @error = 0 
BEGIN
	DELETE EmployeeLeaveUsedItem WHERE @type_id = TypeID
	SELECT @error = @@ERROR
END

IF @error = 0 
BEGIN
	DELETE LeaveType WHERE @type_id = TypeID
	SELECT @error = @@ERROR
END

IF @error = 0 COMMIT TRAN
ELSE IF @@TRANCOUNT > 0 ROLLBACK
GO
ALTER PROC dbo.spLeaveTypeCount
	@advanced bit,
	@count int OUT
AS
SET NOCOUNT ON

SELECT @count = COUNT(*) FROM LeaveType WHERE @advanced IS NULL OR Advanced = @advanced
GO
ALTER PROC dbo.spReportTemplateUpdate
	@template_id int,
	@template_name varchar(50),
	@advanced_bit bit,
	@manager_id int,
	@department_id int,
	@division_id int,
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
	LocationID = @location_id,
	NoManager = @no_manager

WHERE TemplateID = @template_id

IF @advanced_bit = 0 DELETE ReportTemplateAdvanced WHERE TemplateID = @template_id
GO
UPDATE ListTitle SET Title = 'Miss' WHERE TitleID = 7

GO
ALTER PROC dbo.spPersonXSkillUpdate
	@skill varchar(50),
	@person_id int,	
	@skill_id int,
	@level int
AS
DECLARE @authorized bit
DECLARE @was_null bit

SET NOCOUNT ON

-- Requires permission to change skill setting for person
EXEC dbo.spPermissionInsureForCurrentUserOnPerson @person_id, 2097152, 2, @authorized out
IF @authorized = 1
BEGIN
	-- Insures user has permission to change skill text for all employees
	IF EXISTS(SELECT * FROM Skill WHERE SkillID = @skill_id AND Skill <> @skill)  AND(PERMISSIONS(OBJECT_id('dbo.[spSkillUpdate]')) & 32) = 0 EXEC dbo.spErrorRaise 50025
	ELSE 
	BEGIN
		SELECT @was_null = 0 FROM PersonXSkill WHERE PersonID = @person_id AND SkillID = @skill_id
		IF @@ROWCOUNT = 0 SELECT @was_null = 1

		BEGIN TRAN

		UPDATE Skill SET Skill = @skill WHERE SkillID = @skill_id AND Skill <> @skill

		IF @was_null = 1 
		BEGIN
			IF @level != 0
			INSERT PersonXSkill (PersonID,SkillID, [Level])
			VALUES (@person_id,@skill_id,@level)
		END
		ELSE IF @level = 0
			DELETE PersonXSkill WHERE PersonID = @person_id AND SkillID = @skill_id
		ELSE
			UPDATE PersonXSkill SET [Level] = @level
			WHERE PersonID = @person_id AND SkillID = @skill_id

		COMMIT TRAN
	END
END
GO

DELETE ListState
GO
ALTER PROC dbo.spDepartmentInsert
	@department varchar(50),
	@department_id int OUT
AS
SET NOCOUNT ON

INSERT Department(Department) 
VALUES(@department)
SELECT @department_id = SCOPE_IDENTITY()
GO

ALTER PROC dbo.spLocationListAsListItems
	@exclude_empty bit = 0
AS
SET NOCOUNT ON

IF @exclude_empty = 1
	SELECT LocationID, [List As] FROM Location
	WHERE LocationID IN
	(
		SELECT DISTINCT LocationID FROM Employee
	)
	ORDER BY [List As]
ELSE
	SELECT LocationID, [List As] FROM Location ORDER BY [List As]


GO
-- Will throw error if insufficient typeids available
ALTER PROC dbo.spLeaveTypeAddStateFML
	@state_id int
AS
SET NOCOUNT ON

DECLARE @next_type_id int, @next_order int, @error int
SELECT @next_type_id = ISNULL(MAX(TypeID) * 2, 1) FROM LeaveType
SELECT @next_order = ISNULL(MAX([Order]) + 1, 1) FROM LeaveType

BEGIN TRAN

INSERT LeaveType(TypeID, Advanced, [Type], Paid, [Order], InitialPeriodID, [Initial Seconds])
SELECT TypeID * @next_type_id , 1, [Type], 0, [Order] + @next_order, PeriodID, Seconds FROM StateFMLType WHERE StateID = @state_id
SELECT @error = @@ERROR

IF @error = 0
BEGIN
	INSERT LeaveRate(PlanID, TypeID, Seconds, [Start Month], [Stop Month], PeriodID)
	SELECT P.PlanID, F.TypeID * @next_type_id, F.Seconds * P.FTE, 0, 0x7FFFFFFF, F.PeriodID
	FROM StateFMLType F
	CROSS JOIN LeavePlan P
	WHERE F.StateID = @state_id
	SELECT @error = @@ERROR
END

IF @error = 0
BEGIN
	
	DECLARE @ptrSrc binary(16), @ptrTarget binary(16)

	SELECT @ptrSrc = TEXTPTR([Leave Note]) FROM StateFML WHERE StateID = @state_id
	SELECT @ptrTarget = TEXTPTR([Leave Note]) FROM dbo.Constant
	
	DECLARE @nl varchar(2000)
	SELECT @nl = CHAR(13) + CHAR(10) + '===========================================' + CHAR(13) + CHAR(10) +
		'DISCLAIMER: The accuracy of the documentation that Apex Software provides about federal and state law is deemed reliable but not guaranteed. Apex recommends that you thoroughly understand how this software will credit and debit leave before you incorporate it into your family and medical leave procedures and that you consult a specialist in family and medical law. You may need to modify the leave accrual plans in this software, changing the types and amounts of automatically credited family leave. Apex assumes no liability for damages sought regarding tracking, accruing, approving, or denying leave. By using this software, you and/or your employer accept full responsibility and liability.' + CHAR(13) + CHAR(10) +
		'===========================================' + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10)
	UPDATETEXT Constant.[Leave Note] @ptrTarget NULL NULL @nl
	SELECT @error = @@ERROR

	IF @error = 0
	BEGIN
		UPDATETEXT Constant.[Leave Note] @ptrTarget NULL NULL StateFML.[Leave Note] @ptrSrc
		SELECT @error = @@ERROR
	END
END

IF @error = 0 COMMIT TRAN
ELSE IF @@ROWCOUNT > 0 ROLLBACK
GO


IF EXISTS(SELECT * FROM syscolumns WHERE [name] = 'Budgeted' AND [id] = OBJECT_id('Position'))
ALTER TABLE Position DROP COLUMN Budgeted
GO
IF EXISTS(SELECT * FROM sysobjects WHERE [name] = 'IX_Report_ReportID' AND [id] = OBJECT_id('dbo.TempXYZ'))
ALTER TABLE dbo.TempXYZ DROP CONSTRAINT IX_Report_ReportID
GO
ALTER PROC dbo.spEmployeeLeavePlanClearAndSetAll_2
	@batch_id int,
	@start_day int
AS
SET NOCOUNT ON

CREATE TABLE #ET(EmployeeID int, TypeID int, [Day past 1900] int, Seconds int)
INSERT #ET
SELECT [ID], X, Y, Z FROM TempXYZ WHERE BatchID = @batch_id

UPDATE #ET SET Seconds = Seconds - ISNULL((
	SELECT TOP 1 U.Unused FROM EmployeeLeaveUnused U WHERE U.EmployeeID = #ET.EmployeeID AND U.TypeID = #ET.TypeID AND U.[Day past 1900] <= @start_day ORDER BY [Day past 1900] DESC
), 0) FROM #ET

DECLARE @rows int
SELECT @rows = 1

-- There's a constraint that insures that there are not two adjustments for the same type/employee/day
-- This loop makes sure that the constraint will not be violated
WHILE @rows > 0
BEGIN
	UPDATE #ET SET [Day past 1900] = #ET.[Day past 1900] - 1
	FROM #ET INNER JOIN
	EmployeeLeaveEarned E ON #ET.EmployeeID = E.EmployeeID AND #ET.TypeID = E.TypeID AND E.[Day past 1900] = #ET.[Day past 1900] AND #ET.Seconds != 0

	SELECT @rows = @@ROWCOUNT
END

INSERT EmployeeLeaveEarned(EmployeeID, TypeID,  Seconds, [Day past 1900], [Auto], Note)
SELECT #ET.EmployeeID, #ET.TypeID, #ET.Seconds, #ET.[Day past 1900], 0, 'Preserves prior unused leave. Automatically created entry.'
FROM #ET WHERE Seconds != 0

DELETE TempXYZ WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1

GO

If NOT EXISTS(SELECT * FROM sysobjects WHERE [name] = 'CK_Position_FTE' AND [parent_obj] = OBJECT_id('dbo.Position'))
BEGIN
	UPDATE Position SET FTE = 0.01 WHERE FTE < 0.01
	UPDATE Position SET FTE = 2 WHERE FTE > 2

	ALTER TABLE dbo.[Position] ADD CONSTRAINT [CK_Position_FTE] CHECK ([FTE] >= 0.01 and [FTE] <= 2)
END

UPDATE Error SET Error ='An entry in the compensation history is invalid. The period for one entry overlaps the period for another entry. This problem is usually caused by failing to click and specify the stop date for either this entry or a prior entry. Check the start and stop dates and try again.' WHERE ErrorID = 50009
GO
GRANT EXEC ON dbo.spPermissionDoesDBOwnerContainUsers TO public
GO
ALTER PROCEDURE dbo.spLeavePlanInsert
	@plan varchar(50),
	@description varchar(4000),
	@fte numeric(9,4),
	@plan_id int OUT
AS
SET NOCOUNT ON

INSERT LeavePlan([Plan], [Description], [FTE]) VALUES(@plan, @description, @fte)
SELECT @plan_id = SCOPE_IDENTITY()

INSERT LeaveRate(PlanID, TypeID, [Start Month], [Stop Month], Seconds, PeriodID)
SELECT @plan_id, TypeID, 0, 2147483647, [Initial Seconds] * @fte, InitialPeriodID FROM LeaveType WHERE [Initial Seconds] IS NOT NULL AND InitialPeriodID IS NOT NULL
GO
ALTER PROC dbo.spEmploymentStatusDelete
	@status_id int
AS
SET NOCOUNT ON

DELETE EmploymentStatus WHERE StatusID = @status_id
GO
IF NOT EXISTS(SELECT * FROM Error WHERE ErrorID = 50034)
BEGIN
	INSERT Error(ErrorID, Error)
	VALUES(50034, 'You cannot delete the last department.')

	INSERT Error(ErrorID, Error)
	VALUES(50035, 'You cannot delete the last division.')

	INSERT Error(ErrorID, Error)
	VALUES(50036, 'You cannot delete the last location.')

	INSERT Error(ErrorID, Error)
	VALUES(50037, 'You cannot delete the last shift.')
END
GO
ALTER PROC dbo.spPositionListFillingEmployees
	@batch_id int
AS
DECLARE @today int

SET NOCOUNT ON

EXEC dbo.spPermissionGetOnPeopleForCurrentUser2 @batch_id, 1024

CREATE TABLE #P(PositionID int, Employees varchar(8000) COLLATE SQL_Latin1_General_CP1_CI_AS)

SELECT @today = DATEDIFF(d, 0, GETDATE())

DECLARE p_cursor CURSOR LOCAL FAST_FORWARD FOR 
SELECT EC.PositionID, E.[Full Name]
FROM EmployeeCompensation EC
INNER JOIN TempX X ON X.BatchID = @batch_id AND X.[ID] = EC.EmployeeID AND (X.X & 1) = 1
INNER JOIN vwPersonCalculated E ON EC.EmployeeID = E.PersonID AND @today BETWEEN EC.[Start Day past 1900] AND ISNULL(EC.[Stop Day past 1900], 2147483647)
ORDER BY EC.PositionID, E.[Full Name]

OPEN p_cursor

DECLARE @last_position_id int, @position_id int, @employee varchar(400), @employees varchar(8000)
FETCH NEXT FROM p_cursor INTO @position_id, @employee

WHILE @@FETCH_STATUS = 0
BEGIN
	IF @last_position_id IS NULL
		SET @employees = ''
	ELSE IF @position_id != @last_position_id
	BEGIN
		INSERT #P VALUES (@last_position_id, @employees)
		SET @employees = ''
	END

	IF LEN(@employees) > 0 SET @employees = @employees + ', '
	SELECT @employees = @employees + @employee, @last_position_id = @position_id

	FETCH NEXT FROM p_cursor INTO @position_id, @employee
END

IF @last_position_id IS NOT NULL 
INSERT #P VALUES (@last_position_id, @employees)

CLOSE p_cursor
DEALLOCATE p_cursor

SELECT #P.PositionID, P.[Job Title], #P.Employees
FROM Position P
INNER JOIN #P ON P.PositionID = #P.PositionID AND LEN(#P.Employees) > 0
ORDER BY P.[Job Title]

DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1
GO
ALTER VIEW dbo.vwEmployeeLeave
AS
SELECT [Limit Adjustment] = CAST(CASE WHEN E.Auto = 2 THEN 1 ELSE 0 END AS bit), E.[Day past 1900], E.Seconds, [Date] = DATEADD(d, 0, E.[Day past 1900]), [Extended Type Mask] = E.TypeID, E.TypeID, E.EmployeeID FROM EmployeeLeaveEarned E
UNION
SELECT 0, I.[Day past 1900], -I.Seconds, I.[Date], I.[Extended Type Mask], I.TypeID, I.EmployeeID FROM vwEmployeeLeaveUsedItem I
GO
ALTER PROC dbo.spEmployeeLeaveGetScheduled
	@employee_id int,
	@type_id int,
	@day int,
	@seconds int out
AS
DECLARE @authorized bit
SET NOCOUNT ON

EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 10003, 1, @authorized out
IF @authorized = 1
BEGIN
	SELECT @seconds = ISNULL(SUM(Seconds), 0) FROM vwEmployeeLeaveUsedItemApproved WHERE ([Extended Type Mask] & @type_id) != 0 AND EmployeeID = @employee_id AND [Day past 1900] >= @day
END
GO
ALTER PROC dbo.spEmployeeLeaveGetUsed
	@employee_id int,
	@type_id int,
	@day int,
	@seconds int out
AS
DECLARE @authorized bit
SET NOCOUNT ON

EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 10003, 1, @authorized out
IF @authorized = 1
BEGIN
	SELECT @seconds = ISNULL(SUM(Seconds), 0) FROM vwEmployeeLeaveUsedItemApproved WHERE ([Extended Type Mask] & @type_id) != 0 AND EmployeeID = @employee_id AND [Day past 1900] = @day
END
GO
IF OBJECT_ID('dbo.GetDateFromDaysPast1900') IS NULL
EXEC sp_executesql N'CREATE FUNCTION dbo.GetDateFromDaysPast1900 (@days int) 
RETURNS datetime
AS
BEGIN
	DECLARE @d datetime

	IF @days IS NULL SET @d = NULL
	ELSE IF @days <= -53690 SET @d = CONVERT(datetime, ''17530101'', 112)
	ELSE IF @days >= 2958463 SET @d = CONVERT(datetime, ''99991231'', 112)
	ELSE SET @d = DATEADD(dd, @days, 0)

	RETURN @d
END'
GO
ALTER PROC dbo.spEmployeeLeaveUsedCalculateFilter
	@batch_id int,
 	@start_date datetime,
 	@group_by smallint,
	@work_week int,
	@work_week_year int
AS
DECLARE @stop_date datetime

SET NOCOUNT ON

-- Each row requires read permission on Employee Leave and Tardiness Summaries
EXEC dbo.spPermissionGetOnPeopleForCurrentUser2 @batch_id, 10003

IF @group_by = 0
	SELECT @stop_date = DATEADD(d,14,@start_date)
ELSE IF @group_by = 1
BEGIN
	IF (DATEPART(wk, dbo.GetDateFromMDY(12, 31, @work_week_year)) < @work_week)
	-- @work_week might be 53 or 54, but the max week in @work_week_year is only 52 or 53 (less than given @work_week number)
		RETURN
	SELECT @start_date = dbo.GetDateFromMDY(1, 1, @work_week_year)
	SELECT @start_date = DATEADD(wk,@work_week-1,DATEADD(d,1-DATEPART(dw,@start_date),@start_date))
	SELECT @stop_date = DATEADD(wk,14,@start_date)
END
ELSE IF @group_by = 2
BEGIN
	DECLARE @group_id int
	SELECT @group_id = GroupID FROM LeaveRatePeriod WHERE Payroll = 1 AND PeriodID = (SELECT CurrentPayrollPeriodID FROM dbo.Constant)

	IF @group_id = 8
		SELECT @stop_date = DATEADD(m,2*14,@start_date)
	ELSE IF @group_id = 16
		SELECT @stop_date = DATEADD(m,14,@start_date)
	ELSE IF @group_id = 32
		SELECT @stop_date = DATEADD(m,14/2,@start_date)
	ELSE IF @group_id = 64
		SELECT @stop_date = DATEADD(wk,2*14,@start_date)
	ELSE IF @group_id = 128
		SELECT @stop_date = DATEADD(wk,14,@start_date)

END
ELSE IF @group_by = 3
	SELECT @stop_date = DATEADD(m,12,@start_date)


DECLARE @start_day int, @stop_day int

SELECT @start_day = DATEDIFF(d, 0, @start_date), @stop_day = DATEDIFF(d, 0, @stop_date)

SELECT EI.EmployeeID, [Work day]=dbo.GetDateFromDaysPast1900(EI.[Day past 1900]),Duration=CAST(CAST(EI.Seconds AS decimal)/3600 AS numeric(9,2)), PayrollPeriod = 0, T.TypeID 
INTO #ET 
FROM TempX X
INNER JOIN vwEmployeeLeaveUsedItemApproved EI ON X.BatchID = @batch_id AND X.[ID] = EI.EmployeeID AND (X.[X] & 1) = 1 AND EI.[Day past 1900] BETWEEN @start_day AND @stop_day
CROSS JOIN LeaveType T
WHERE (T.TypeID & EI.[Extended Type Mask]) != 0



-- SUM the duration of the work day that has 2 or more entries depending on the group by
IF @group_by = 0
-- day
BEGIN
	SELECT P.PersonID, Employee=P.[List As],
		Day0 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 0), 0),
		Day1 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 1), 0),
		Day2 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 2), 0),
		Day3 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 3), 0),
		Day4 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 4), 0),
		Day5 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 5), 0),
		Day6 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 6), 0),
		Day7 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 7), 0),
		Day8 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 8), 0),
		Day9 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 9), 0),
		Day10 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 10), 0),
		Day11 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 11), 0),
		Day12 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 12), 0),
		Day13 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 13), 0),
	Type = 'Total', TypeID = 0
	FROM dbo.vwPersonListAs P
	WHERE P.PersonID IN
	(
		SELECT EmployeeID FROM #ET
	)

	UNION

	SELECT P.PersonID, Employee=P.[List As],
		Day0 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 0 AND #ET.TypeID = LT.TypeID),0) ,
		Day1 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 1 AND #ET.TypeID = LT.TypeID),0) ,
		Day2 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 2 AND #ET.TypeID = LT.TypeID),0) ,
		Day3 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 3 AND #ET.TypeID = LT.TypeID),0) ,
		Day4 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 4 AND #ET.TypeID = LT.TypeID),0) ,
		Day5 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 5 AND #ET.TypeID = LT.TypeID),0) ,
		Day6 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 6 AND #ET.TypeID = LT.TypeID),0) ,
		Day7 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 7 AND #ET.TypeID = LT.TypeID),0) ,
		Day8 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 8 AND #ET.TypeID = LT.TypeID),0) ,
		Day9 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 9 AND #ET.TypeID = LT.TypeID),0) ,
		Day10 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 10 AND #ET.TypeID = LT.TypeID),0) ,
		Day11 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 11 AND #ET.TypeID = LT.TypeID),0) ,
		Day12 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 12 AND #ET.TypeID = LT.TypeID),0) ,
		Day13 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 13 AND #ET.TypeID = LT.TypeID),0) ,
	LT.Type, LT.TypeID
	FROM dbo.vwPersonListAs P CROSS JOIN LeaveType LT
	WHERE P.PersonID IN
	(
		SELECT EmployeeID FROM #ET
	)
	
	ORDER BY PersonID,TypeID

--GROUP BY Type, PersonID,[List As]
END

ELSE IF @group_by = 1
-- Work week
BEGIN
	UPDATE #ET SET [Work day]=DATEADD(d,1-DATEPART(dw,[work day]),[work day])

	DECLARE @first_ww datetime
	SELECT @first_ww = CAST('01/01/' + CAST(@work_week_year as varchar(50)) AS datetime)
	SELECT @first_ww = DATEADD(wk,@work_week,@first_ww)
	SELECT @first_ww = DATEADD(d, 1 - DATEPART(dw,@first_ww),@first_ww)
	IF DAY(@first_ww) <> 1 SELECT @first_ww = DATEADD(d, -7,@first_ww)



	SELECT P.PersonID, Employee=P.[List As],
		WW0 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 0 AND 6), 0),
		WW1 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 7 AND 13), 0),
		WW2 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 14 AND 20), 0),
		WW3 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 21 AND 27), 0),
		WW4 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 28 AND 34), 0),
		WW5 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 35 AND 41), 0),
		WW6 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 42 AND 48), 0),
		WW7 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 49 AND 55), 0),
		WW8 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 56 AND 62), 0),
		WW9 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 63 AND 69), 0),
		WW10 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 70 AND 76), 0),
		WW11 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 77 AND 83), 0),
		WW12 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 84 AND 90), 0),
		WW13 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 91 AND 97), 0),
	Type = 'Total', TypeID = 0
	FROM dbo.vwPersonListAs P CROSS JOIN LeaveType LT
	WHERE P.PersonID IN
	(
		SELECT EmployeeID FROM #ET
	)

	UNION

	SELECT P.PersonID, Employee=P.[List As],
		WW0 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 0 AND 6 AND #ET.TypeID = LT.TypeID), 0),
		WW1 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 7 AND 13 AND #ET.TypeID = LT.TypeID), 0),
		WW2 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 14 AND 20 AND #ET.TypeID = LT.TypeID), 0),
		WW3 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 21 AND 27 AND #ET.TypeID = LT.TypeID), 0),
		WW4 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 28 AND 34 AND #ET.TypeID = LT.TypeID), 0),
		WW5 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 35 AND 41 AND #ET.TypeID = LT.TypeID), 0),
		WW6 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 42 AND 48 AND #ET.TypeID = LT.TypeID), 0),
		WW7 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 49 AND 55 AND #ET.TypeID = LT.TypeID), 0),
		WW8 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 56 AND 62 AND #ET.TypeID = LT.TypeID), 0),
		WW9 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 63 AND 69 AND #ET.TypeID = LT.TypeID), 0),
		WW10 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 70 AND 76 AND #ET.TypeID = LT.TypeID), 0),
		WW11 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 77 AND 83 AND #ET.TypeID = LT.TypeID), 0),
		WW12 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 84 AND 90 AND #ET.TypeID = LT.TypeID), 0),
		WW13 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 91 AND 97 AND #ET.TypeID = LT.TypeID), 0),
	LT.Type, LT.TypeID
	FROM dbo.vwPersonListAs P CROSS JOIN LeaveType LT
	WHERE P.PersonID IN
	(
		SELECT EmployeeID FROM #ET
	)

	ORDER BY PersonID,TypeID
END

ELSE IF @group_by = 2
-- payroll
BEGIN
	DECLARE @first_payroll_period int
	SELECT @first_payroll_period = dbo.GetPayrollPeriodNumber(@start_date)
	UPDATE #ET SET [PayrollPeriod]=dbo.GetPayrollPeriodNumber(#ET.[Work day])

	SELECT P.PersonID, Employee=P.[List As],
		Payroll0 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 0),0),
		Payroll1 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 1),0),
		Payroll2 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 2),0),
		Payroll3 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 3),0),
		Payroll4 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 4),0),
		Payroll5 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 5),0),
		Payroll6 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 6),0),
		Payroll7 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 7),0),
		Payroll8 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 8),0),
		Payroll9 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 9),0),
		Payroll10 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 10),0),
		Payroll11 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 11),0),
		Payroll12 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 12),0),
		Payroll13 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 13),0),
	Type = 'Total', TypeID = 0
	FROM dbo.vwPersonListAs P CROSS JOIN LeaveType LT
	WHERE P.PersonID IN
	(
		SELECT EmployeeID FROM #ET
	)

	UNION

	SELECT P.PersonID, Employee=P.[List As],
		Payroll0 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 0 AND #ET.TypeID = LT.TypeID),0),
		Payroll1 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 1 AND #ET.TypeID = LT.TypeID),0),
		Payroll2 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 2 AND #ET.TypeID = LT.TypeID),0),
		Payroll3 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 3 AND #ET.TypeID = LT.TypeID),0),
		Payroll4 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 4 AND #ET.TypeID = LT.TypeID),0),
		Payroll5 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 5 AND #ET.TypeID = LT.TypeID),0),
		Payroll6 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 6 AND #ET.TypeID = LT.TypeID),0),
		Payroll7 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 7 AND #ET.TypeID = LT.TypeID),0),
		Payroll8 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 8 AND #ET.TypeID = LT.TypeID),0),
		Payroll9 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 9 AND #ET.TypeID = LT.TypeID),0),
		Payroll10 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 10 AND #ET.TypeID = LT.TypeID),0),
		Payroll11 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 11 AND #ET.TypeID = LT.TypeID),0),
		Payroll12 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 12 AND #ET.TypeID = LT.TypeID),0),
		Payroll13 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 13 AND #ET.TypeID = LT.TypeID),0),
	LT.Type, LT.TypeID
	FROM dbo.vwPersonListAs P CROSS JOIN LeaveType LT
	WHERE P.PersonID IN
	(
		SELECT EmployeeID FROM #ET
	)

	ORDER BY PersonID,TypeID
END

ELSE IF @group_by = 3
-- month
BEGIN
	UPDATE #ET SET [Work day]=DATEADD(d,1-DAY([Work day]),[Work day])

	SELECT P.PersonID, Employee=P.[List As],
		Month0 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 0), 0),
		Month1 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 1), 0),
		Month2 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 2), 0),
		Month3 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 3), 0),
		Month4 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 4), 0),
		Month5 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 5), 0),
		Month6 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 6), 0),
		Month7 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 7), 0),
		Month8 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 8), 0),
		Month9 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 9), 0),
		Month10 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 10), 0),
		Month11 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 11), 0),
	Type = 'Total', TypeID = 0
	FROM dbo.vwPersonListAs P CROSS JOIN LeaveType LT
	WHERE P.PersonID IN
	(
		SELECT EmployeeID FROM #ET
	)

	UNION

	SELECT P.PersonID, Employee=P.[List As],
		Month0 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 0 AND #ET.TypeID = LT.TypeID), 0),
		Month1 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 1 AND #ET.TypeID = LT.TypeID), 0),
		Month2 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 2 AND #ET.TypeID = LT.TypeID), 0),
		Month3 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 3 AND #ET.TypeID = LT.TypeID), 0),
		Month4 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 4 AND #ET.TypeID = LT.TypeID), 0),
		Month5 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 5 AND #ET.TypeID = LT.TypeID), 0),
		Month6 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 6 AND #ET.TypeID = LT.TypeID), 0),
		Month7 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 7 AND #ET.TypeID = LT.TypeID), 0),
		Month8 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 8 AND #ET.TypeID = LT.TypeID), 0),
		Month9 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 9 AND #ET.TypeID = LT.TypeID), 0),
		Month10 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 10 AND #ET.TypeID = LT.TypeID), 0),
		Month11 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 11 AND #ET.TypeID = LT.TypeID), 0),
	LT.Type, LT.TypeID
	FROM dbo.vwPersonListAs P CROSS JOIN LeaveType LT
	WHERE P.PersonID IN
	(
		SELECT EmployeeID FROM #ET
	)

	ORDER BY PersonID,TypeID
END

GO
ALTER PROC dbo.spLeaveAnalysisByEmployee
	@type_or_mask int,
	@ongoing bit,
	@batch_id int,
	@sort tinyint,
	@total bit = 0,
	@authorized bit OUT
AS
SET NOCOUNT ON

DECLARE @start int, @stop int, @today smalldatetime, @null_id int

SELECT @today = GETDATE()
SELECT @stop = DATEDIFF(d, 0, @today)
SELECT @start = DATEDIFF(d, 0, DATEADD(yy, -1, @today))

EXEC dbo.spPermissionGetOnPeopleForCurrentUser2 @batch_id, 10003
DELETE TempX WHERE BatchID = @batch_id AND (X & 1) = 0
SELECT @authorized = CASE WHEN @@ROWCOUNT = 0 THEN 1 ELSE 0 END

CREATE TABLE #E(EmployeeID int, [Seniority Begins] smalldatetime, ShiftID int, Incidents int, [Lost Days] numeric(18,4),  [Lost Hours] numeric(18,4), [Bradford Factor] numeric(18,4), [Working Hours] numeric(18,4))

INSERT #E
SELECT E.EmployeeID, dbo.GetDateFromDaysPast1900([Seniority Begins Day past 1900]), E.ShiftID, 0, 0, 0, 0, 0
FROM Employee E WHERE (@ongoing IS NULL OR E.[Ongoing Condition] = @ongoing) AND E.[Terminated Day past 1900] IS NULL

UPDATE #E SET Incidents = 
	(SELECT COUNT(*) FROM EmployeeLeaveUsed U WHERE U.EmployeeID = #E.EmployeeID AND U.Status = 2 AND U.LeaveID IN
	(
		SELECT DISTINCT I.LeaveID FROM vwEmployeeLeaveUsedItem I WHERE I.Status = 2 AND I.[Day past 1900] BETWEEN @start AND @stop AND
		(@type_or_mask = 0x7FFFFFFF OR (I.[Extended Type Mask] & @type_or_mask) <> 0)
	)) +
	+
	(SELECT COUNT(*) FROM EmployeeLeaveEarned E WHERE E.EmployeeID = #E.EmployeeID AND (E.[Day past 1900] BETWEEN @start AND @stop) AND (@type_or_mask = 0x7FFFFFFF OR (E.TypeID & @type_or_mask) <> 0) AND E.Seconds < 0)
,
[Lost Days] = ISNULL((
	SELECT SUM(U.Seconds /  CAST(S.[Effective Seconds per Day] AS numeric(18,4))) FROM vwEmployeeLeaveUsedItemApproved U
	INNER JOIN vwEmployeeEffectiveSecondsPerDay S ON U.EmployeeID = #E.EmployeeID AND U.[Day past 1900] BETWEEN @start AND @stop AND (U.[Extended Type Mask] & @type_or_mask) <> 0 AND #E.ShiftID = S.ShiftID
), 0),
[Lost Hours] = ISNULL((
	SELECT SUM(U.Seconds) / 3600.0 FROM vwEmployeeLeaveUsedItemApproved U WHERE U.EmployeeID = #E.EmployeeID AND U.[Day past 1900] BETWEEN @start AND @stop AND (U.[Extended Type Mask] & @type_or_mask) <> 0
), 0),
[Working Hours] = dbo.BoundInt(0, DATEDIFF(d, #E.[Seniority Begins], GETDATE()), 365) * S.[Effective Seconds per day] / 3600 * CAST((S.[Days On] + S.DaysOn2) AS numeric(18,4)) / CAST(S.[Days On] + S.[Days Off] + S.DaysOn2 + S.DaysOff2 AS numeric(18,4))

FROM #E INNER JOIN vwEmployeeEffectiveSecondsPerDay S ON #E.EmployeeID = S.EmployeeID



UPDATE #E SET [Bradford Factor] = Incidents * Incidents * [Lost Days]
	
SELECT
[Order] = 0,
E2.EmployeeID,
Employee = E.[List As],
E2.[Employee Number],
[Percent Working Time Lost] = CAST(CASE WHEN [Working Hours]= 0 THEN 0 ELSE 100 * #E.[Lost Hours] / #E.[Working Hours] END AS numeric(18,4)),
[Lost Hours per Week] = CAST(#E.[Lost Hours] / 52 AS numeric(18,4)),
[Avg Hours per Incident] = CAST(CASE WHEN #E.Incidents = 0 THEN 0 ELSE #E.[Lost Hours] / #E.Incidents END AS numeric(18,4)),
#E.[Incidents],
#E.[Bradford Factor] 
INTO #R
FROM #E
INNER JOIN dbo.vwPersonListAs E ON #E.EmployeeID = E.PersonID
INNER JOIN Employee E2 ON #E.EmployeeID = E2.EmployeeID
INNER JOIN TempX X ON X.BatchID = @batch_id AND X.[ID] = E2.EmployeeID AND (@ongoing IS NULL OR E2.[Ongoing Condition] = @ongoing)

IF @total = 1
INSERT #R
SELECT
ISNULL(MIN(#E.EmployeeID), 0)  - 1,
1,
'Total Company',
'',
CASE WHEN SUM(#E.[Working Hours]) = 0 THEN 0 ELSE 100 * SUM(#E.[Lost Hours]) / SUM(#E.[Working Hours]) END,
SUM(#E.[Lost Hours]) / 52,
CASE WHEN SUM(#E.Incidents) = 0 THEN 0 ELSE SUM(#E.[Lost Hours]) / SUM(#E.Incidents) END,
SUM(#E.Incidents),
NULL
FROM #E


SELECT Employee,
EmployeeID,
[Employee Number],
[Percent Working Time Lost],
[Lost Hours per Week],
[Avg Hours per Incident],
Incidents,
[Bradford Factor]
FROM #R
WHERE [Order] = 1 OR Incidents != 0
ORDER BY [Order], CASE WHEN @sort IN (1, 2, 3) THEN '' ELSE Employee END,
CASE @sort
	WHEN 1 THEN [Lost Hours per Week]
	WHEN 2 THEN [Incidents]
	WHEN 3 THEN [Bradford Factor]
	ELSE 0
END DESC

DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1
GO
ALTER PROC dbo.spLeaveAnalysisByDepartment
	@type_or_mask int,
	@ongoing bit,
	@sort tinyint,
	@department_id int,
	@authorized bit OUT
AS
SET NOCOUNT ON

DECLARE @start int, @stop int, @batch_id int, @today smalldatetime

SELECT @today = GETDATE()
SELECT @stop = DATEDIFF(d, 0, @today)
SELECT @start = DATEDIFF(d, 0, DATEADD(yy, -1, @today))
SELECT @batch_id = RAND() * 2147483647

CREATE TABLE #E(EmployeeID int, DepartmentID int, ShiftID int, Incidents int, [Lost Days] numeric(18,4), B numeric(18,4))

INSERT #E
SELECT E.EmployeeID, E.DepartmentID, E.ShiftID, 0, 0, 0
FROM Employee E WHERE (@ongoing IS NULL OR E.[Ongoing Condition] = @ongoing) AND [Terminated Day past 1900] IS NULL

UPDATE #E SET Incidents = 
	(SELECT COUNT(*) FROM EmployeeLeaveUsed U
	INNER JOIN Employee E ON U.EmployeeID = E.EmployeeID AND E.EmployeeID = #E.EmployeeID AND U.Status = 2 AND U.LeaveID IN
	(
		SELECT DISTINCT I.LeaveID FROM dbo.vwEmployeeLeaveUsedItem I WHERE I.[Day past 1900] BETWEEN @start AND @stop AND
		(@type_or_mask = 0x7FFFFFFF OR (I.[Extended Type Mask] & @type_or_mask) <> 0) AND I.Status = 2
	))
	+
	(SELECT COUNT(*) FROM EmployeeLeaveEarned E WHERE E.EmployeeID = #E.EmployeeID AND (E.[Day past 1900] BETWEEN @start AND @stop) AND (@type_or_mask = 0x7FFFFFFF OR (E.TypeID & @type_or_mask) <> 0) AND E.Seconds < 0)
,
[Lost Days] = ISNULL((
	SELECT SUM(U.Seconds /  CAST(S.[Effective Seconds per Day] AS numeric(18,4))) FROM dbo.vwEmployeeLeaveUsedItemApproved U
	INNER JOIN Employee E ON U.EmployeeID = E.EmployeeID AND U.[Day past 1900] BETWEEN @start AND @stop AND E.EmployeeID = #E.EmployeeID AND E.[Terminated Day past 1900] IS NULL AND (U.[Extended Type Mask] & @type_or_mask) <> 0
	INNER JOIN vwEmployeeEffectiveSecondsPerDay S ON E.EmployeeID = S.EmployeeID
), 0)

UPDATE #E SET B = Incidents * Incidents * [Lost Days]

CREATE TABLE #D (DepartmentID int, Incidents numeric(18,4), [Lost Hours] numeric(18,4), People int, [Working Hours] numeric(18,4))
INSERT #D
SELECT DepartmentID, 0, 0, 0, 0
FROM Department

UPDATE #D SET Incidents = ISNULL((
	SELECT COUNT(*) FROM EmployeeLeaveUsed U
	INNER JOIN #E ON U.EmployeeID = #E.EmployeeID AND 
	#E.DepartmentID = #D.DepartmentID AND 
	dbo.DoRaysIntersect(U.[Start Day past 1900], U.[Stop Day past 1900], @start, @stop) = 1 AND 
	U.Status = 2 AND U.LeaveID IN
	(
		SELECT DISTINCT I.LeaveID FROM EmployeeLeaveUsedItem I WHERE I.[Day past 1900] BETWEEN @start AND @stop AND
		(@type_or_mask = 0x7FFFFFFF OR (I.TypeID & @type_or_mask) <> 0 OR (U.[Advanced Type Mask] & @type_or_mask) <> 0)
	)
), 0),
[Lost Hours] = ISNULL((
	SELECT SUM(U.Seconds) / 3600.0 FROM vwEmployeeLeaveUsedItemApproved U
	INNER JOIN #E ON U.EmployeeID = #E.EmployeeID AND U.[Day past 1900] BETWEEN @start AND @stop AND #E.DepartmentID = #D.DepartmentID AND (U.[Extended Type Mask] & @type_or_mask) <> 0
), 0),
People = ISNULL((
	SELECT COUNT(*) FROM #E WHERE #E.DepartmentID = #D.DepartmentID
), 0),
[Working Hours] = ISNULL((
	SELECT SUM(dbo.BoundInt(0, DATEDIFF(d, E.[Seniority Begins Day past 1900], GETDATE()) , 365) * S.[Effective Seconds per day] / 3600 * CAST((S.[Days On] + S.DaysOn2) AS numeric(18,4)) / CAST(S.[Days On] + S.[Days Off] + S.DaysOn2 + S.DaysOff2 AS numeric(18,4)))
	FROM vwEmployeeEffectiveSecondsPerDay S INNER JOIN #E ON #E.EmployeeID = S.EmployeeID AND #E.DepartmentID = #D.DepartmentID
	INNER JOIN Employee E ON #E.EmployeeID = E.EmployeeID
), 0)



	
SELECT
Total = 0,
D.DepartmentID,
D.Department, 
[Percent Working Time Lost] = CAST(CASE WHEN [Working Hours]= 0 THEN 0 ELSE 100 * #D.[Lost Hours] / #D.[Working Hours] END AS numeric(18,4)),
[Lost Hours per Week] = CAST(#D.[Lost Hours] / 52 AS numeric(18,4)),
[Avg Hours per Incident] = CAST(CASE WHEN #D.Incidents = 0 THEN 0 ELSE #D.[Lost Hours] / #D.Incidents END AS numeric(18,4)),
[Avg Hours per Person] = CAST(CASE WHEN #D.People = 0 THEN 0 ELSE #D.[Lost Hours] / #D.People END AS numeric(18,4)),
#D.[Incidents],
[Incidents per Person] = CAST(CASE WHEN #D.People = 0 THEN 0 ELSE #D.Incidents / #D.People END AS numeric(18,4)),
[Max Bradford Factor] = ISNULL((
	SELECT MAX(#E.B) FROM #E WHERE #E.DepartmentID = #D.DepartmentID
), 0)
INTO #R
FROM #D
INNER JOIN Department D ON #D.DepartmentID = D.DepartmentID

INSERT #R
SELECT
1,
0,
'Total Company',
CASE WHEN SUM([Working Hours]) = 0 THEN 0 ELSE 100 * SUM([Lost Hours]) / SUM([Working Hours]) END,
SUM([Lost Hours]) / 52,
CASE WHEN SUM(Incidents) = 0 THEN 0 ELSE SUM([Lost Hours]) / SUM(Incidents) END,
CASE WHEN SUM(People) = 0 THEN 0 ELSE SUM([Lost Hours]) / SUM(People) END,
SUM(Incidents),
CASE WHEN SUM(People) = 0 THEN 0 ELSE SUM(Incidents) / SUM(People) END,
ISNULL(( SELECT MAX(#E.B) FROM #E), 0)
FROM #D

-- Weeds out departments that the user does not have permisison to see and departments that have 0 incidents
INSERT TempX(BatchID, [ID])
SELECT @batch_id, EmployeeID FROM Employee WHERE [Terminated Day past 1900] IS NULL AND (@department_id IS NULL OR DepartmentID = @department_id)

EXEC dbo.spPermissionGetOnPeopleForCurrentUser2 @batch_id, 10003
DELETE TempX WHERE BatchID = @batch_id AND (X & 1) = 0
SELECT @authorized = CASE WHEN @@ROWCOUNT = 0 THEN 1 ELSE 0 END

SELECT Department,
[Percent Working Time Lost],
[Lost Hours per Week],
[Avg Hours per Incident],
[Avg Hours per Person],
Incidents,
[Incidents per Person],
[Max Bradford Factor]
FROM #R
WHERE Total = 1 OR (Incidents != 0 AND (@department_id IS NULL OR DepartmentID = @department_id) AND EXISTS(
	SELECT * FROM Employee E
	INNER JOIN TempX X ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID AND E.DepartmentID = #R.DepartmentID
))
ORDER BY Total, CASE WHEN @sort IN (1, 2, 3) THEN '' ELSE Department END,
CASE @sort
	WHEN 1 THEN [Lost Hours per Week]
	WHEN 2 THEN [Incidents per Person]
	WHEN 3 THEN [Max Bradford Factor]
	ELSE 0
END DESC

DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1
GO
ALTER PROC dbo.spEmployeeMostAbsent
	@top int,
	@start_day int,
	@stop_day int,
	@batch_id int
AS
SET NOCOUNT ON

EXEC dbo.spPermissionGetOnPeopleForCurrentUser2 @batch_id, 10003

DELETE TempX WHERE (X & 1) = 0 OR [ID] NOT IN (
	SELECT DISTINCT I.EmployeeID FROM vwEmployeeLeaveUsedItemApproved I WHERE I.[Day past 1900] BETWEEN @start_day AND @stop_day
)

SELECT EmployeeID = P.PersonID, Employee = P.[List As],
Absent = (SELECT COUNT(*) FROM vwEmployeeLeaveUsedItemApproved X	
	WHERE X.EmployeeID = P.PersonID AND X.[Day past 1900] BETWEEN @start_day AND @stop_day)
INTO #U
FROM dbo.vwPersonListAs P
INNER JOIN TempX T ON T.BatchID = @batch_id AND T.[ID] = P.PersonID

DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1

SET ROWCOUNT @top
SELECT *,
Paid = ISNULL(
	(SELECT SUM(A.Seconds) FROM vwEmployeeLeaveUsedItemApproved A
	INNER JOIN LeaveType T ON A.EmployeeID = #U.EmployeeID AND A.[Day past 1900] BETWEEN @start_day AND @stop_day AND A.TypeID = T.TypeID AND T.Paid = 1
), 0) / 3600.00,
Unpaid = ISNULL(
	(SELECT SUM(A.Seconds) FROM vwEmployeeLeaveUsedItemApproved A
	INNER JOIN LeaveType T ON A.EmployeeID = #U.EmployeeID AND A.[Day past 1900] BETWEEN @start_day AND @stop_day AND A.TypeID = T.TypeID AND T.Paid = 0
), 0) / 3600.00
FROM #U ORDER BY Absent DESC

DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1
GO
ALTER TRIGGER dbo.CheckSIDOnEmployeeInsertUpdate ON dbo.Employee 
FOR INSERT, UPDATE
AS
DECLARE @result int
DECLARE @description varchar(800)
DECLARE @dup_employee_id int

SET @result = 0

IF UPDATE(SID) 
BEGIN
	SELECT TOP 1 @dup_employee_id = E.EmployeeID FROM inserted I
	INNER JOIN Employee E ON I.SID IS NOT NULL AND I.SID = E.SID AND I.EmployeeID != E.EmployeeID

	IF @dup_employee_id IS NOT NULL SET @result = 50005
END

IF @result = 0 AND UPDATE([Employee Number])
BEGIN
	SELECT TOP 1 @dup_employee_id = E.EmployeeID FROM inserted I
	INNER JOIN Employee E ON LEN(I.[Employee Number]) > 0 AND I.[Employee Number] = E.[Employee Number] AND I.EmployeeID != E.EmployeeID

	IF @dup_employee_id IS NOT NULL SET @result = 50033
END

IF @result <> 0
BEGIN
	SELECT @description = [Error] FROM Error WHERE ErrorID = @result
	SELECT @description = @description + ' The record for ' + [Full Name] + ' contains the duplicate.'
	FROM vwPersonCalculated WHERE PersonID = @dup_employee_id

	RAISERROR (@description, 16, 1)

	IF @@TRANCOUNT > 0 ROLLBACK TRAN
END
GO
GRANT EXEC ON dbo.spDenialReasonList TO public
GRANT EXEC ON dbo.spDenialReasonSelect TO public
GRANT EXEC ON dbo.spStandardTaskList TO public
GO
IF (SELECT [Server Version] FROM dbo.Constant) < 14
BEGIN
CREATE TABLE dbo.Tmp_I9Status
	(
	StatusID int NOT NULL IDENTITY (1, 1),
	Status varchar(50) NOT NULL,
	[Natural] bit NOT NULL
	)  ON [PRIMARY]


SET IDENTITY_INSERT dbo.Tmp_I9Status ON
IF EXISTS(SELECT * FROM dbo.I9Status)
	 EXEC('INSERT INTO dbo.Tmp_I9Status (StatusID, Status, [Natural])
		SELECT StatusID, Status, [Natural] FROM dbo.I9Status TABLOCKX')

SET IDENTITY_INSERT dbo.Tmp_I9Status OFF

ALTER TABLE dbo.PersonX
	DROP CONSTRAINT FK_PersonX_I9Status

DROP TABLE dbo.I9Status


declare @P1 int
set @P1=0
declare @P2 int
set @P2=16388
declare @P3 int
set @P3=8193
declare @P4 int
set @P4=0
EXEC dbo.sp_cursoropen @P1 output, N'EXECUTE sp_rename N''dbo.Tmp_I9Status'', N''I9Status'', ''OBJECT''
', @P2 output, @P3 output, @P4 output
select @P1, @P2, @P3, @P4

ALTER TABLE dbo.I9Status ADD CONSTRAINT
	PK_I9Status PRIMARY KEY CLUSTERED 
	(
	StatusID
	) WITH FILLFACTOR = 90 ON [PRIMARY]



ALTER TABLE dbo.I9Status ADD CONSTRAINT
	IX_I9Status_Status UNIQUE NONCLUSTERED 
	(
	Status
	) WITH FILLFACTOR = 90 ON [PRIMARY]



ALTER TABLE dbo.I9Status WITH NOCHECK ADD CONSTRAINT
	CK_I9Status_StatusNotBlank CHECK ((len([Status]) > 0))



ALTER TABLE dbo.PersonX WITH NOCHECK ADD CONSTRAINT
	FK_PersonX_I9Status FOREIGN KEY
	(
	I9StatusID
	) REFERENCES dbo.I9Status
	(
	StatusID
	) ON DELETE CASCADE
END
GO
IF OBJECT_id('dbo.UpdateLastOut') IS NOT NULL DROP TRIGGER dbo.UpdateLastOut
IF OBJECT_id('dbo.AddMonthsToDY') IS NOT NULL DROP FUNCTION dbo.AddMonthsToDY
IF OBJECT_id('AddMonthsToDY') IS NOT NULL DROP FUNCTION AddMonthsToDY
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
ALTER TABLE dbo.[LeaveLimit] DROP CONSTRAINT [CK_LeaveLimit_InvalidPeriod]
ALTER TABLE dbo.[LeaveLimit] ADD CONSTRAINT [CK_LeaveLimit_InvalidPeriod] CHECK ([PeriodID] >= 0 and [PeriodID] <= 4)
GO
IF OBJECT_id('dbo.vwEmployeeLeaveApproved') IS NULL EXEC sp_executesql N'CREATE VIEW dbo.vwEmployeeLeaveApproved AS SELECT A=0'
GO
ALTER VIEW dbo.vwEmployeeLeaveApproved
AS
SELECT [Limit Adjustment] = CAST (0 AS bit),
[Day past 1900] = 0,
Seconds = 0, 
[Date] = CAST('1/1/2000' AS datetime),
[Extended Type Mask] = 0,
TypeID = 0,
EmployeeID = 0, 
[Type] = CAST('' AS varchar(50)),
Abbreviation = CAST('' AS varchar(4)),
Paid = CAST(0 AS bit),
[Order] = 0,
Bank = CAST(0 AS bit),
[OT Eligible] = CAST(0 AS bit),
[Payroll Delay] = 0
FROM EmployeeLeaveEarned E
INNER JOIN LeaveType T ON E.TypeID = T.TypeID
GO
UPDATE Constant SET [Server Version] = 17
GO
IF OBJECT_id('dbo.AddMonthsToDY') IS NOT NULL DROP FUNCTION dbo.AddMonthsToDY
IF OBJECT_id('AddMonthsToDY') IS NOT NULL DROP FUNCTION AddMonthsToDY
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
REVOKE EXEC ON dbo.spPermissionUpdateForUserScopeOnAttribute TO public

IF OBJECT_id('CK_EmployeeCommunication_LenOfNote') IS NOT NULL
ALTER TABLE dbo.EmployeeCommunication DROP CONSTRAINT CK_EmployeeCommunication_LenOfNote
GO
IF OBJECT_ID('CK_EmployeeLeaveUsed_ApprovalRequiresType') IS NOT NULL
ALTER TABLE dbo.EmployeeLeaveUsed DROP CONSTRAINT CK_EmployeeLeaveUsed_ApprovalRequiresType
UPDATE EmployeeLeaveUsed SET ApprovalTypeID = NULL WHERE Status = 4 AND ApprovalTypeID IS NOT NULL

ALTER TABLE dbo.EmployeeLeaveUsed ADD CONSTRAINT CK_EmployeeLeaveUsed_ApprovalRequiresType CHECK ([Status] IN (1,4) or ([ApprovalTypeID] is not null and [Status] = 2))
GO
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

IF OBJECT_id('IX_MaritalStatus_Status') IS NULL
ALTER TABLE dbo.[PersonX] ADD 
	CONSTRAINT [FK_PersonX_MaritalStatus] FOREIGN KEY 
	(
		[MaritalStatusID]
	) REFERENCES dbo.[MaritalStatus] (
		[StatusID]
	)
GO

ALTER PROC dbo.spEmployeeLeaveCalcForEmployee
	@employee_id int,
	@start int = -2147483648
AS
DECLARE @carryover_target_type_id int
DECLARE @type_id int

-- Excludes carryover target because calling spEmployeeLeaveCalcForEmployeeType on the source will automatically apply limits on the target
SELECT @carryover_target_type_id = CarryoverTargetLeaveTypeID FROM dbo.Constant
DECLARE t_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT TypeID FROM LeaveType WHERE @carryover_target_type_id IS NULL OR TypeID <> @carryover_target_type_id

IF @carryover_target_type_id IS NOT NULL EXEC dbo.spEmployeeLeaveAccrue @employee_id, @carryover_target_type_id, @start

OPEN t_cursor
FETCH t_cursor INTO @type_id
WHILE @@FETCH_STATUS = 0
BEGIN
	EXEC dbo.spEmployeeLeaveCalcForEmployeeType @employee_id, @type_id, @start

	FETCH t_cursor INTO @type_id
END
GO

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID] = OBJECT_id('dbo.Constant') AND [name] = 'Reminder E-mail Suppress Days')
BEGIN
	ALTER TABLE dbo.Constant ADD [Reminder E-mail Suppress Days] int NULL
	ALTER TABLE dbo.Constant ADD [Reminder E-mail Subject] varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL DEFAULT('Reminders')
	ALTER TABLE dbo.Constant ADD [Reminder E-mail Sender] varchar(4000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL DEFAULT('')
	ALTER TABLE dbo.Constant ADD [Reminder E-mail Last Result] varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL DEFAULT('Never e-mailed')
	ALTER TABLE dbo.Constant ADD [Reminder E-mail Repeat Days] int NOT NULL DEFAULT(7)
	ALTER TABLE dbo.Constant ADD [Reminder E-mail Ignore Days] int NOT NULL DEFAULT(14)
END
GO
IF OBJECT_id('dbo.vwCompensationAdjustment') IS NOT NULL DROP VIEW dbo.vwCompensationAdjustment
IF OBJECT_id('vwCompensationAdjustment') IS NOT NULL DROP VIEW vwCompensationAdjustment
GO
CREATE VIEW dbo.vwCompensationAdjustment
AS
SELECT A.*, Period = ISNULL(P.Period, ''), P.Seconds
FROM CompensationAdjustment A
LEFT JOIN Period P ON A.PeriodID = P.PeriodID
GO


IF NOT EXISTS(SELECT * FROM Error WHERE ErrorID = 50038)
INSERT Error(ErrorID, Error)
VALUES (50038, 'Permission denied. Cannot change the name of the compensation adjustment.')

IF NOT EXISTS(SELECT * FROM Error WHERE ErrorID = 50039)
INSERT Error(ErrorID, Error)
VALUES (50039, 'Permission denied. Cannot insert a compensation adjustment.')
GO
IF OBJECT_id('dbo.spDivisionGetDivisionFromDivisionID') IS NOT NULL DROP PROC dbo.spDivisionGetDivisionFromDivisionID
GO
CREATE PROC dbo.spDivisionGetDivisionFromDivisionID
	@division_id int,
	@division varchar(50)
AS
SELECT @division = ''
SELECT @division = Division FROM Division WHERE DivisionID = @division_id
GO
GRANT EXEC ON dbo.spDivisionGetDivisionFromDivisionID TO public
IF OBJECT_id('dbo.spLocationGetListAs') IS NOT NULL DROP PROC dbo.spLocationGetListAs
GO
CREATE PROC dbo.spLocationGetListAs
	@location_id int,
	@list_as varchar(50)
AS
SELECT @list_as = ''
SELECT @list_as = [List As] FROM Location WHERE LocationID = @location_id
GO
GRANT EXEC ON dbo.spLocationGetListAs TO public
IF OBJECT_id('dbo.spDepartmentGetDepartmentFromDepartmentID') IS NOT NULL DROP PROC dbo.spDepartmentGetDepartmentFromDepartmentID
GO
CREATE PROC dbo.spDepartmentGetDepartmentFromDepartmentID
	@department_id int,
	@department varchar(50)
AS
SELECT @department = ''
SELECT @department = Department FROM Department WHERE DepartmentID = @department_id
GO
GRANT EXEC ON dbo.spDepartmentGetDepartmentFromDepartmentID TO public
IF OBJECT_id('dbo.spShiftGetShiftFromShiftID') IS NOT NULL DROP PROC dbo.spShiftGetShiftFromShiftID
GO
CREATE PROC dbo.spShiftGetShiftFromShiftID
	@shift_id int,
	@shift varchar(50)
AS
SELECT @shift = ''
SELECT @shift = Shift FROM Shift WHERE ShiftID = @shift_id
GO
GRANT EXEC ON dbo.spShiftGetShiftFromShiftID TO public
IF OBJECT_id('dbo.spEmploymentStatusGetStatusFromStatusID') IS NOT NULL DROP PROC dbo.spEmploymentStatusGetStatusFromStatusID
GO
CREATE PROC dbo.spEmploymentStatusGetStatusFromStatusID
	@status_id int,
	@status varchar(50)
AS
SELECT @status = ''
SELECT @status = Status FROM EmploymentStatus WHERE StatusID = @status_id
GO
GRANT EXEC ON dbo.spEmploymentStatusGetStatusFromStatusID TO public
IF OBJECT_id('dbo.spPositionStatusGetStatusFromStatusID') IS NOT NULL DROP PROC dbo.spPositionStatusGetStatusFromStatusID
GO
CREATE PROC dbo.spPositionStatusGetStatusFromStatusID
	@status_id int,
	@status varchar(50)
AS
SELECT @status = ''
SELECT @status = Status FROM PositionStatus WHERE StatusID = @status_id
GO
GRANT EXEC ON dbo.spPositionStatusGetStatusFromStatusID TO public
GO
IF OBJECT_id('dbo.spLocationCount') IS NOT NULL DROP PROC dbo.spLocationCount
GO
CREATE PROC dbo.spLocationCount
	@count int out
AS
SELECT @count = COUNT(*) FROM Location
GO
GRANT EXEC ON dbo.spLocationCount TO public
IF OBJECT_id('dbo.spEmployeeListWithPStatus') IS NOT NULL DROP PROC dbo.spEmployeeListWithPStatus
GO
CREATE PROC dbo.spEmployeeListWithPStatus
	@status_id int,
	@active bit
AS
SELECT P.[List As], P.PersonID
FROM dbo.vwPersonListAs P
INNER JOIN Employee E ON P.PersonID = E.EmployeeID
INNER JOIN EmployeeCompensation C ON E.LastCompensationID = C.CompensationID
INNER JOIN Position POS ON C.PositionID = POS.PositionID AND POS.StatusID = @status_id
GO
GRANT EXEC ON dbo.spEmployeeListWithPStatus TO public
IF OBJECT_id('dbo.spEmployeeListWithEStatus') IS NOT NULL DROP PROC dbo.spEmployeeListWithEStatus
GO
CREATE PROC dbo.spEmployeeListWithEStatus
	@status_id int,
	@active bit
AS
SELECT P.[List As], P.PersonID
FROM dbo.vwPersonListAs P
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
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [id] = OBJECT_id('ReportTemplate') AND [name] = 'EmploymentStatusID')
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
ALTER PROC dbo.spLeaveGetUseOrLoseDay
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
UPDATE Constant SET CarryoverSourceLeaveTypeID = NULL, CarryoverTargetLeaveTypeID = NULL
WHERE CarryoverSourceLeaveTypeID NOT IN (SELECT TypeID FROM LeaveType) OR CarryoverTargetLeaveTypeID NOT IN (SELECT TypeID FROM LeaveType)


IF OBJECT_id('FK_Constant_CarryoverSourceLeaveTypeID') IS NULL
ALTER TABLE dbo.[Constant] ADD CONSTRAINT [FK_Constant_CarryoverSourceLeaveTypeID] FOREIGN KEY 
(
	[CarryoverSourceLeaveTypeID]
) REFERENCES dbo.[LeaveType] (
	[TypeID]
)

IF OBJECT_id('FK_Constant_CarryoverTargetLeaveTypeID') IS NULL
ALTER TABLE dbo.[Constant] ADD CONSTRAINT [FK_Constant_CarryoverTargetLeaveTypeID] FOREIGN KEY 
(
	[CarryoverTargetLeaveTypeID]
) REFERENCES dbo.[LeaveType] (
	[TypeID]
)
GO
IF OBJECT_id('dbo.FK_Position_PositionStatus') IS NOT NULL ALTER TABLE dbo.[Position] DROP CONSTRAINT FK_Position_PositionStatus

SELECT * INTO #PS FROM PositionStatus

DROP TABLE PositionStatus

CREATE TABLE dbo.[PositionStatus] (
	[StatusID] [int] IDENTITY (1, 1) NOT NULL ,
	[Status] varchar (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL 
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
IF OBJECT_id('dbo.BuildListAsOnLocationChange') IS NOT NULL DROP TRIGGER dbo.BuildListAsOnLocationChange
IF OBJECT_id('dbo.spLocationGetListAs2') IS NOT NULL DROP PROC dbo.spLocationGetListAs2
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
IF OBJECT_id('dbo.spLocationGetFirst') IS NOT NULL DROP PROC dbo.spLocationGetFirst
GO
CREATE PROC dbo.spLocationGetFirst
	@location_id int out
AS
SET NOCOUNT ON

SELECT TOP 1 @location_id = LocationID FROM Location ORDER BY [List As]
GO
GRANT EXEC ON dbo.spLocationGetFirst TO public
IF OBJECT_id('dbo.spLocationFind') IS NOT NULL DROP PROC dbo.spLocationFind
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
SELECT @list_as = [List As] FROM Location WHERE LocationID = @location_id
GO

IF OBJECT_id('dbo.spEmployeeLeaveForefeited') IS NOT NULL DROP PROC dbo.spEmployeeLeaveForefeited
GO
CREATE PROC dbo.spEmployeeLeaveForefeited
	@start_day int, 
	@stop_day int, 
	@batch_id int,
	@authorized bit OUT
AS
SET NOCOUNT ON

EXEC dbo.spPermissionGetOnPeopleForCurrentUser2 @batch_id, 10003
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
INNER JOIN dbo.vwPersonListAs P ON #E.EmployeeID = P.PersonID
CROSS JOIN #T
INNER JOIN LeaveType T ON #T.TypeID = T.TypeID
LEFT JOIN #Forfeited F ON F.TypeID = #T.TypeID AND F.EmployeeID = #E.EmployeeID
ORDER BY P.[List As], T.[Order]

DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1
GO
GRANT EXEC ON dbo.spEmployeeLeaveForefeited TO public
GO

IF OBJECT_id('dbo.[Language]') IS NULL
BEGIN
	CREATE TABLE dbo.[Language] (
		[LanguageID] [int] NOT NULL ,
		[Language] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL 
	) ON [PRIMARY]
	
	ALTER TABLE dbo.[Language] WITH NOCHECK ADD 
		CONSTRAINT [PK_Language] PRIMARY KEY  CLUSTERED 
		(
			[LanguageID]
		) WITH  FILLFACTOR = 90  ON [PRIMARY] 
	
	ALTER TABLE dbo.[Language] ADD 
		CONSTRAINT [IX_Language_Language] UNIQUE  NONCLUSTERED 
		(
			[Language]
		) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
		CONSTRAINT [CK_Language_LanguageNotBlank] CHECK (len([Language]) > 0),
		CONSTRAINT [CK_Language_InvalidLanguageID] CHECK ([LanguageID] = 0x40000000 or ([LanguageID] = 0x20000000 or ([LanguageID] = 0x10000000 or ([LanguageID] = 0x08000000 or ([LanguageID] = 0x04000000 or ([LanguageID] = 0x02000000 or ([LanguageID] = 0x01000000 or ([LanguageID] = 0x800000 or ([LanguageID] = 0x400000 or ([LanguageID] = 0x200000 or ([LanguageID] = 0x100000 or ([LanguageID] = 0x080000 or ([LanguageID] = 0x040000 or ([LanguageID] = 0x020000 or ([LanguageID] = 0x010000 or ([LanguageID] = 0x8000 or ([LanguageID] = 0x4000 or ([LanguageID] = 0x2000 or ([LanguageID] = 0x1000 or ([LanguageID] = 0x0800 or ([LanguageID] = 0x0400 or ([LanguageID] = 0x0200 or ([LanguageID] = 0x0100 or ([LanguageID] = 0x80 or ([LanguageID] = 0x40 or ([LanguageID] = 0x20 or ([LanguageID] = 0x10 or ([LanguageID] = 8 or ([LanguageID] = 4 or ([LanguageID] = 2 or [LanguageID] = 1))))))))))))))))))))))))))))))


	INSERT Language(LanguageID, Language) VALUES(1, 'English')

	ALTER TABLE dbo.[PersonX] ADD PrimaryLanguageID int, [Secondary Language Mask] int DEFAULT 0 NOT NULL
	ALTER TABLE dbo.[PersonX] ADD CONSTRAINT [FK_PersonX_Language] FOREIGN KEY 
	(
		[PrimaryLanguageID]
	) REFERENCES dbo.[Language] (
		[LanguageID]
	)	
END
GO
IF NOT EXISTS(SELECT * FROM Error WHERE ErrorID = 50045)
INSERT Error(ErrorID, Error)
VALUES (50045, 'This language cannot be added because the system can only track 31 languages.')

IF OBJECT_id('dbo.spLanguageInsert') IS NOT NULL DROP PROC dbo.spLanguageInsert
IF OBJECT_id('dbo.spLanguageUpdate') IS NOT NULL DROP PROC dbo.spLanguageUpdate
IF OBJECT_id('dbo.spLanguageDelete') IS NOT NULL DROP PROC dbo.spLanguageDelete
IF OBJECT_id('dbo.spLanguageList') IS NOT NULL DROP PROC dbo.spLanguageList
IF OBJECT_id('dbo.spLanguageGetLanguageFromLanguageID') IS NOT NULL DROP PROC dbo.spLanguageGetLanguageFromLanguageID
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
	EXEC dbo.spErrorRaise 50045
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
IF NOT EXISTS(SELECT ErrorID FROM Error WHERE ErrorID = 50046) INSERT dbo.Error(ErrorID, Error) VALUES(50046, '')
UPDATE dbo.Error SET Error = 'Your client is out of date. Please close this application and update your client by running http://iHRsoftware.com/ftp/apexsetup_nomsi.exe . See http://iHRsoftware.com/updateHistory.aspx for more information.' WHERE ErrorID = 50046
GO
IF OBJECT_id('dbo.PayTable') IS NULL
BEGIN
	BEGIN TRAN

	-- Creates pay tables
	CREATE TABLE dbo.[PayTable] (
		[PayTableID] [int] IDENTITY (1, 1) NOT NULL,
		[Pay Table] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
	) ON [PRIMARY]
	
	ALTER TABLE dbo.[PayTable] WITH NOCHECK ADD 
		CONSTRAINT [PK_PayTable] PRIMARY KEY  CLUSTERED 
		(
			[PayTableID]
		)  ON [PRIMARY] 
	
	ALTER TABLE dbo.[PayTable] ADD 
		CONSTRAINT [IX_PayTable_Duplicate] UNIQUE  NONCLUSTERED 
		(
			[Pay Table]
		)  ON [PRIMARY] ,
		CONSTRAINT [CK_PayTable_BlankPayTable] CHECK (len([Pay Table]) > 0)
	
	INSERT PayTable([Pay Table]) VALUES ('General Schedule')
	
	-- Creates pay steps
	CREATE TABLE dbo.[PayStep] (
		[PayStepID] [int] IDENTITY (1, 1) NOT NULL ,
		[PayTableID] [int] NOT NULL ,
		[Pay Step] [varchar] (15) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[Seniority Months] [int] NULL ,
		[Order] [int] NOT NULL 
	) ON [PRIMARY]
	
	ALTER TABLE dbo.[PayStep] WITH NOCHECK ADD 
		CONSTRAINT [PK_PayStep] PRIMARY KEY  CLUSTERED 
		(
			[PayStepID]
		)  ON [PRIMARY] 
	
	ALTER TABLE dbo.[PayStep] ADD 
		CONSTRAINT [CK_PayStep_BlankStep] CHECK (len([Pay Step]) > 0)
	
	CREATE  INDEX [IX_PayStep] ON dbo.[PayStep]([PayTableID]) ON [PRIMARY]

	SELECT * INTO #PayGrade FROM PayGrade
	ALTER TABLE dbo.Position DROP CONSTRAINT FK_Position_PayGrade
	DROP TABLE PayGrade

	-- Alters pay grade table
	CREATE TABLE dbo.[PayGrade] (
		[PayGradeID] [int] IDENTITY (1, 1) NOT NULL ,
		[PayTableID] [int] NOT NULL ,
		[Pay Grade] [varchar] (15) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[Order] [int] NOT NULL 
	) ON [PRIMARY]
	
	
	ALTER TABLE dbo.[PayGrade] WITH NOCHECK ADD 
		CONSTRAINT [PK_PayGrade] PRIMARY KEY  CLUSTERED 
		(
			[PayGradeID]
		)  ON [PRIMARY] 
	
	
	ALTER TABLE dbo.[PayGrade] ADD 
		CONSTRAINT [IX_PayGrade_NameNotUnique] UNIQUE  NONCLUSTERED 
		(
			[Pay Grade]
		)  ON [PRIMARY] ,
		CONSTRAINT [CK_PayGrade_NameRequired] CHECK (len([Pay Grade]) > 0)
	
	
	CREATE  INDEX [IX_PayGrade] ON dbo.[PayGrade]([PayTableID]) ON [PRIMARY]
	
	
	ALTER TABLE dbo.[PayGrade] ADD 
		CONSTRAINT [FK_PayGrade_PayTable] FOREIGN KEY 
		(
			[PayTableID]
		) REFERENCES dbo.[PayTable] (
			[PayTableID]
		) ON DELETE CASCADE 
	
	

	CREATE TABLE dbo.[Pay] (
		[PayID] [int] IDENTITY (1, 1) NOT NULL ,
		[PayGradeID] [int] NOT NULL ,
		[PayStepID] [int] NOT NULL ,
		[Hourly Rate] [money] NOT NULL 
	) ON [PRIMARY]


	ALTER TABLE dbo.[Pay] ADD 
	CONSTRAINT [PK_Pay] PRIMARY KEY  CLUSTERED 
	(
		[PayID]
	)  ON [PRIMARY] 

	-- Creates pay table
	ALTER TABLE dbo.[Pay] ADD 
	CONSTRAINT [FK_Pay_PayGrade] FOREIGN KEY 
	(
		[PayGradeID]
	) REFERENCES dbo.[PayGrade] (
		[PayGradeID]
	) ON DELETE CASCADE ,
	CONSTRAINT [FK_Pay_PayStep] FOREIGN KEY 
	(
		[PayStepID]
	) REFERENCES dbo.[PayStep] (
		[PayStepID]
	) ON DELETE CASCADE 




	DECLARE p_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT PayGradeID, [Pay Grade], [Minimum Hourly Pay], [Maximum Hourly Pay], [Pay Step Increase] FROM #PayGrade
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
	ALTER TABLE dbo.[Position] ADD 
	CONSTRAINT [FK_Position_PayGrade] FOREIGN KEY 
	(
		[PayGradeID]
	) REFERENCES dbo.[PayGrade] (
		[PayGradeID]
	)

	-- Alter EmployeeCompensation table to reference PayStepID
	ALTER TABLE dbo.EmployeeCompensation ADD PayStepID int
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
SELECT 
PositionID=0,
[Job Title]='',
Active = CAST(0 AS bit),
PayGradeID=0,
CategoryID=0,
StatusID=0,
FTE=CAST(0 AS numeric(9,4)),
[Workers Comp Code]='',
[Note]='',
[Other Compensation]='',
[Job Description]='',
FLSAID=0,
[Seconds Per Week]=0,
[FLSA Exempt] = CAST(0 as bit),
[FLSA Status] = '',
[Pay Grade]=0,
Category='',
[Status]='',
[Pay Grade Order] = 0,
[Pay Table] = '',
PayTableID='',
[Annualized Pay Range] = '', 
[Report Row] = 0,
FTE40 = CAST(0 as numeric(9,4)),
[Position Number]=''
GO
IF OBJECT_id('FK_EmployeeCompensation_PayStep') IS NULL
BEGIN
	EXEC sp_executesql N'UPDATE EmployeeCompensation SET PayStepID = 1'

	ALTER TABLE dbo.[EmployeeCompensation] ADD 
	CONSTRAINT [FK_EmployeeCompensation_PayStep] FOREIGN KEY 
	(
		[PayStepID]
	) REFERENCES dbo.[PayStep] (
		[PayStepID]
	)

	EXEC sp_executesql N'UPDATE EmployeeCompensation SET PayStepID =
	ISNULL((
		SELECT TOP 1 PayStep.PayStepID FROM PayStep WHERE PayStep.[Pay Step] = EmployeeCompensation.[Pay Step]
	), 1)'

	ALTER TABLE dbo.[EmployeeCompensation] DROP COLUMN [Pay Step]
	ALTER TABLE dbo.[EmployeeCompensation] ALTER COLUMN PayStepID int NOT NULL
END
GO
ALTER PROC dbo.spPayGradeDelete
	@pay_grade_id int = NULL, -- hack for backward compatibility
	@grade_id int = NULL
AS
SET NOCOUNT ON

DELETE PayGrade WHERE PayGradeID = @pay_grade_id OR PayGradeID = @grade_id
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
	EXEC dbo.spErrorRaise 50046
END
ELSE
BEGIN
	SELECT @employee_id = EmployeeID FROM EmployeeCompensation WHERE CompensationID = @compensation_id
	EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 1024, 2, @authorized out
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
IF OBJECT_id('dbo.spPayTableInsert') IS NOT NULL DROP PROC dbo.spPayTableInsert
IF OBJECT_id('dbo.spPayTableList') IS NOT NULL DROP PROC dbo.spPayTableList
IF OBJECT_id('dbo.spPayTableSelect') IS NOT NULL DROP PROC dbo.spPayTableSelect
IF OBJECT_id('dbo.spPayTableUpdate') IS NOT NULL DROP PROC dbo.spPayTableUpdate
IF OBJECT_id('dbo.spPayStepCount') IS NOT NULL DROP PROC dbo.spPayStepCount
IF OBJECT_id('dbo.spPayStepDelete') IS NOT NULL DROP PROC dbo.spPayStepDelete
IF OBJECT_id('dbo.spPayStepInsert') IS NOT NULL DROP PROC dbo.spPayStepInsert
IF OBJECT_id('dbo.spPayStepUpdate') IS NOT NULL DROP PROC dbo.spPayStepUpdate
IF OBJECT_id('dbo.spPayStepList') IS NOT NULL DROP PROC dbo.spPayStepList
IF OBJECT_id('dbo.spPayStepSelect') IS NOT NULL DROP PROC dbo.spPayStepSelect
IF OBJECT_id('dbo.spPayGradeCount') IS NOT NULL DROP PROC dbo.spPayGradeCount
IF OBJECT_id('dbo.spPayList') IS NOT NULL DROP PROC dbo.spPayList
IF OBJECT_id('dbo.spPayUpdate') IS NOT NULL DROP PROC dbo.spPayUpdate
IF OBJECT_id('dbo.spPayStepGetFirst') IS NOT NULL DROP PROC dbo.spPayStepGetFirst
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
EXEC dbo.spErrorRaise 50046
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

IF @table_id IS NULL EXEC dbo.spErrorRaise 50046
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
IF @grade_id IS NULL EXEC dbo.spErrorRaise 50046
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
EXEC dbo.spErrorRaise 50046
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

IF @step_id IS NULL EXEC dbo.spErrorRaise 50046
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



IF OBJECT_id('dbo.spPayGradeGetFirst') IS NOT NULL DROP PROC dbo.spPayGradeGetFirst
IF OBJECT_id('dbo.spJobCategoryGetFirst') IS NOT NULL DROP PROC dbo.spJobCategoryGetFirst
IF OBJECT_id('dbo.spPositionStatusGetFirst') IS NOT NULL DROP PROC dbo.spPositionStatusGetFirst
IF OBJECT_id('dbo.spEmployeeUpdateActive') IS NOT NULL DROP PROC dbo.spEmployeeUpdateActive
IF OBJECT_id('dbo.spEmploymentStatusGetFullTime') IS NOT NULL DROP PROC dbo.spEmploymentStatusGetFullTime
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
GO
UPDATE Constant SET [Server Version] = 27
GO
IF EXISTS(SELECT * FROM syscolumns WHERE [name] = '[Expires Day past 1900]' AND [id] = OBJECT_id('dbo.EmployeeBenefit')) ALTER TABLE dbo.EmployeeBenefit DROP COLUMN [Expires Day past 1900]

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [name] = 'Note' AND [id] = OBJECT_id('Benefit'))
ALTER TABLE Benefit ADD Note varchar(4000) NOT NULL DEFAULT ''
IF OBJECT_id('dbo.vwBenefit') IS NOT NULL DROP VIEW dbo.vwBenefit
GO
IF OBJECT_id('dbo.BenefitPremium') IS NULL
BEGIN
	-- Predefined premiums
	CREATE TABLE dbo.[BenefitPremium] (
		[PremiumID] [int] IDENTITY (1, 1) NOT NULL ,
		[BenefitID] [int] NOT NULL ,
		[Provider] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[Plan] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[Coverage] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[Employee Premium] [money] NOT NULL ,
		[Employer Premium] [money] NOT NULL ,
		[Home ZIP] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL 
	) ON [PRIMARY]
	
	ALTER TABLE dbo.[BenefitPremium] WITH NOCHECK ADD 
		CONSTRAINT [PK_BenefitPremium] PRIMARY KEY  CLUSTERED 
		(
			[PremiumID]
		)  ON [PRIMARY] 


	ALTER TABLE dbo.[BenefitPremium] ADD 
		CONSTRAINT [FK_BenefitPremium_Benefit] FOREIGN KEY 
		(
			[BenefitID]
		) REFERENCES dbo.[Benefit] (
			[BenefitID]
		) ON DELETE CASCADE 
END
GO
ALTER PROC dbo.spBenefitInsert
	@benefit varchar(50),
	@note varchar(4000) = '',
	@benefit_id int out

AS
SET NOCOUNT ON

INSERT Benefit(Benefit, Note)
VALUES (@benefit, @note)

SELECT @benefit_id = SCOPE_IDENTITY()
GO
ALTER PROC dbo.spBenefitUpdate
	@benefit_id int,
	@note varchar(4000) = '',
	@benefit varchar(50)
AS
SET NOCOUNT ON

UPDATE Benefit SET Benefit = @benefit, Note = @note
WHERE BenefitID = @benefit_id
GO
CREATE VIEW dbo.vwBenefit AS SELECT * FROM Benefit
GO
ALTER PROC dbo.spBenefitList
AS
SELECT * FROM vwBenefit
ORDER BY Benefit
GO
ALTER PROC dbo.spBenefitListUniqueCoverages
	@benefit_id int = NULL
AS
SET NOCOUNT ON

SELECT Coverage FROM EmployeeBenefit WHERE Coverage != '' AND (@benefit_id IS NULL OR BenefitID = @benefit_id) 
UNION
SELECT Coverage FROM BenefitPremium WHERE Coverage !='' AND (@benefit_id IS NULL OR BenefitID = @benefit_id)
ORDER BY Coverage
GO
ALTER PROC dbo.spBenefitListUniquePlans
AS
SET NOCOUNT ON

SELECT [Plan] FROM EmployeeBenefit WHERE [Plan] != ''
UNION
SELECT [Plan] FROM BenefitPremium WHERE [Plan] != '' 
ORDER BY [Plan]
GO
ALTER PROC dbo.spBenefitListUniqueProviders
AS
SET NOCOUNT ON

SELECT [Provider] FROM EmployeeBenefit WHERE [Provider] != ''
UNION
SELECT [Provider] FROM BenefitPremium WHERE [Provider] != ''
ORDER BY [Provider]
GO
ALTER PROC dbo.spBenefitListPremiums
	@benefit_id int = NULL,
	@provider varchar(50),
	@plan varchar(50),
	@coverage varchar(50)
AS

CREATE TABLE #Premium
(
	PremiumID int PRIMARY KEY IDENTITY(1,1),
	Provider varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS,
	[Plan] varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS,
	[Coverage] varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS,
	[Employee Premium] money,
	[Employer Premium] money,
	[Home Zip] varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS DEFAULT '',
	[Min Zip] varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS DEFAULT '',
	[Max Zip] varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS DEFAULT '',
)

-- All premiums for provider/plan/coverage
INSERT #Premium(Provider, [Plan], Coverage, [Employee Premium], [Employer Premium])
SELECT DISTINCT EB.Provider, EB.[Plan], EB.Coverage, EB.[Employee Premium], EB.[Employer Premium]
FROM EmployeeBenefit EB
INNER JOIN Employee E ON (@benefit_id IS NULL OR EB.BenefitID = @benefit_id) AND EB.EmployeeID = E.EmployeeID AND E.[Active Employee] = 1 AND EB.Provider = @provider AND EB.[Plan] = @plan AND EB.Coverage = @coverage AND (EB.[Employee Premium] > 0 OR EB.[Employer Premium] > 0)
ORDER BY [Employee Premium]

-- If no match, all premiums for provider/plan
IF @@ROWCOUNT = 0
BEGIN
	INSERT #Premium(Provider, [Plan], Coverage, [Employee Premium], [Employer Premium])
	SELECT DISTINCT EB.Provider, EB.[Plan], EB.Coverage, EB.[Employee Premium], EB.[Employer Premium] FROM EmployeeBenefit EB 
	INNER JOIN Employee E ON EB.EmployeeID = E.EmployeeID AND E.[Active Employee] = 1 AND EB.Provider = @provider AND EB.[Plan] = @plan AND (EB.[Employee Premium] > 0 OR EB.[Employer Premium] > 0)
	ORDER BY EB.[Employee Premium]

	IF @@ROWCOUNT = 0
	BEGIN
		-- If no match, all premiums for provider
		INSERT #Premium(Provider, [Plan], Coverage, [Employee Premium], [Employer Premium])
		SELECT DISTINCT EB.Provider, EB.[Plan], EB.Coverage, EB.[Employee Premium], EB.[Employer Premium] FROM EmployeeBenefit EB 
		INNER JOIN Employee E ON (@benefit_id IS NULL OR EB.BenefitID = @benefit_id) AND EB.EmployeeID = E.EmployeeID AND E.[Active Employee] = 1 AND EB.Provider = @provider AND (EB.[Employee Premium] > 0 OR EB.[Employer Premium] > 0)
		ORDER BY EB.[Plan], EB.[Coverage], [Employee Premium]

		IF @@ROWCOUNT = 0
		BEGIN
			-- If no match, all premiums
			INSERT #Premium(Provider, [Plan], Coverage, [Employee Premium], [Employer Premium])
			SELECT DISTINCT EB.Provider, EB.[Plan], EB.Coverage, EB.[Employee Premium], EB.[Employer Premium] FROM EmployeeBenefit EB 
			INNER JOIN Employee E ON (@benefit_id IS NULL OR EB.BenefitID = @benefit_id) AND EB.EmployeeID = E.EmployeeID AND E.[Active Employee] = 1 AND EB.[Employee Premium] > 0 OR EB.[Employer Premium] > 0
			ORDER BY EB.Provider, EB.[Plan], EB.[Coverage], EB.[Employee Premium]
		END
	END
END

-- Gets the home zip codes of employees with specific premiums
UPDATE #Premium SET [Min ZIP] =
ISNULL((
	SELECT MIN(Person.[Home ZIP]) FROM EmployeeBenefit EB
	INNER JOIN Person ON  EB.[Employee Premium] = P.[Employee Premium] AND EB.[Employer Premium] = P.[Employer Premium] AND EB.EmployeeID = Person.PersonID AND LEN(P.[Home ZIP]) > 0
), ''),
[Max ZIP] =
ISNULL((
	SELECT MAX(Person.[Home ZIP]) FROM EmployeeBenefit EB
	INNER JOIN Person ON  EB.[Employee Premium] = P.[Employee Premium] AND EB.[Employer Premium] = P.[Employer Premium] AND EB.EmployeeID = Person.PersonID AND LEN(P.[Home ZIP]) > 0
), '')
FROM #Premium P

UPDATE #Premium SET [Home Zip] = CASE WHEN
	LEN([Min ZIP]) = 0 THEN ''
	WHEN [Min ZIP] = [Max ZIP] THEN [Min ZIP]
	ELSE 'Multiple'
END
FROM #Premium

-- Insert explicitly defined premiums
INSERT #Premium(Provider, [Plan], Coverage, [Employee Premium], [Employer Premium], [Home ZIP])
SELECT Provider, [Plan], Coverage, [Employee Premium], [Employer Premium], [Home ZIP] FROM BenefitPremium WHERE @benefit_id IS NULL OR BenefitID = @benefit_id

SELECT DISTINCT Provider, [Plan], Coverage, [Employee Premium], [Employer Premium], [Home Zip] FROM #Premium
GO
UPDATE Constant SET [Server Version]= 29
GO

IF OBJECT_id('CK_Subfolder_BadCharacters') IS NULL
BEGIN
	UPDATE Subfolder SET Subfolder = REPLACE(Subfolder, '\', '_')
	UPDATE Subfolder SET Subfolder = REPLACE(Subfolder, '/', '_')
	UPDATE Subfolder SET Subfolder = REPLACE(Subfolder, ':', '_')
	UPDATE Subfolder SET Subfolder = REPLACE(Subfolder, '*', '_')
	UPDATE Subfolder SET Subfolder = REPLACE(Subfolder, '?', '_')
	UPDATE Subfolder SET Subfolder = REPLACE(Subfolder, '"', '_')
	UPDATE Subfolder SET Subfolder = REPLACE(Subfolder, '<', '_')
	UPDATE Subfolder SET Subfolder = REPLACE(Subfolder, '>', '_')
	UPDATE Subfolder SET Subfolder = REPLACE(Subfolder, '|', '_')

	ALTER TABLE dbo.[Subfolder] ADD 
	CONSTRAINT [CK_Subfolder_BadCharacters] CHECK (charindex('\',[Subfolder]) <= 0 and charindex('/',[Subfolder]) <= 0 and charindex(':',[Subfolder]) <= 0 and charindex('*',[Subfolder]) <= 0 and charindex('?',[Subfolder]) <= 0 and charindex('"',[Subfolder]) <= 0 and charindex('<',[Subfolder]) <= 0 and charindex('>',[Subfolder]) <= 0 and charindex('|',[Subfolder]) <= 0)
END
GO
IF OBJECT_id('dbo.Filter') IS NULL
BEGIN
	CREATE TABLE dbo.[Filter] (
		[FilterID] [int] IDENTITY (1, 1) NOT NULL ,
		[Filter] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[Stream] [image] NOT NULL ,
		[Active] [bit] NULL 
	) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
	
	ALTER TABLE dbo.[Filter] WITH NOCHECK ADD CONSTRAINT [PK_Filter] PRIMARY KEY CLUSTERED ([FilterID])  ON [PRIMARY] 
	ALTER TABLE dbo.[Filter] WITH NOCHECK ADD CONSTRAINT [IX_Filter_Name] UNIQUE  NONCLUSTERED ([Filter])  ON [PRIMARY] ,
		CONSTRAINT [CK_Filter_NameRequired] CHECK (len([Filter]) > 0)
END
GO
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [name] = 'OT Comp' AND [id] = OBJECT_id('dbo.LeaveType'))
ALTER TABLE LeaveType ADD [OT Comp] bit NOT NULL DEFAULT 0

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [name] = 'OT Eligible' AND [id] = OBJECT_id('dbo.LeaveType'))
ALTER TABLE LeaveType ADD [OT Eligible] bit NOT NULL DEFAULT 1

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [name] = 'Active Role Mask' AND [id] = OBJECT_id('dbo.Person'))
BEGIN
	ALTER TABLE Person ADD [Active Role Mask] int NOT NULL DEFAULT 0

	EXEC sp_executesql N'UPDATE Person SET [Active Role Mask] = [Role Mask]'
	EXEC sp_executesql N'UPDATE Person SET [Active Role Mask] = [Active Role Mask] & 0x7FFFFFFE FROM Person INNER JOIN Employee ON Person.PersonID = Employee.EmployeeID AND Employee.[Active Employee] = 0'
END

IF NOT EXISTS(SELECT * FROM ColumnGrid WHERE FieldID = 1029)
BEGIN
	INSERT ColumnGrid(FieldID, [Table], [Key], colid, AttributeID, Field, Label, Importable, Reportable, [Order])
	SELECT 1029, [Table], [Key], colid, AttributeID, Field, 'Superior', 0, 0, 521 FROM ColumnGrid WHERE FieldID = 52

	INSERT ColumnGrid(FieldID, [Table], [Key], colid, AttributeID, Field, Label, Importable, Reportable, [Order])
	SELECT 99, 'Employee', 'EmployeeID', 0, 536870912, 'COBRA Eligibility & Enrollment', 'COBRA Eligibility & Enrollment', 0, 1, 719

	INSERT ColumnGrid(FieldID, [Table], [Key], colid, AttributeID, Field, Label, Importable, Reportable, [Order])
	SELECT 70 + colid, 'Employee', 'EmployeeID', colid, 536870912, [name], REPLACE([name], ' Day past 1900', ''), 1, 1, 700 + colid
	FROM syscolumns WHERE [ID] = OBJECT_id('dbo.Employee') AND [name] LIKE '%COBRA%'
END

IF OBJECT_id('dbo.spTempXDelete') IS NOT NULL DROP PROC dbo.spTempXDelete
IF OBJECT_id('dbo.spTempXList') IS NOT NULL DROP PROC dbo.spTempXList
IF OBJECT_id('dbo.vwLeaveType') IS NOT NULL DROP VIEW dbo.vwLeaveType
IF OBJECT_id('dbo.ChangePersonRoleMaskOnEmployeeUpdate') IS NOT NULL DROP TRIGGER ChangePersonRoleMaskOnEmployeeUpdate
IF OBJECT_id('dbo.spFilterSelect') IS NOT NULL DROP PROC dbo.spFilterSelect
IF OBJECT_id('dbo.spFilterList') IS NOT NULL DROP PROC dbo.spFilterList
GO
IF OBJECT_id('dbo.spFilterInsert') IS NULL EXEC sp_executesql N'CREATE PROC dbo.spFilterInsert AS'
GO
ALTER PROC dbo.spFilterInsert
	@filter varchar(50),
	@active bit,
	@stream image,
	@filter_id int OUT
AS
INSERT Filter(Filter, Active, Stream)
VALUES (@filter, @active, @stream)

SET @filter_id = SCOPE_IDENTITY()
GO
IF OBJECT_id('dbo.spFilterUpdate') IS NULL EXEC sp_executesql N'CREATE PROC dbo.spFilterUpdate AS'
GO
ALTER PROC dbo.spFilterUpdate
	@filter varchar(50),
	@active bit,
	@stream image,
	@filter_id int
AS
UPDATE Filter SET 
Filter = @filter,
Active = @active,
Stream = @stream
WHERE FilterID = @filter_id
GO
IF OBJECT_id('dbo.spFilterDelete') IS NULL EXEC sp_executesql N'CREATE PROC dbo.spFilterDelete AS'
GO
ALTER PROC dbo.spFilterDelete
	@filter_id int
AS
DELETE Filter WHERE FilterID = @filter_id
GO
CREATE PROC dbo.spFilterSelect
	@filter_id int
AS
SET NOCOUNT ON

SELECT * FROM Filter WHERE FilterID = @filter_id
GO
GRANT EXEC ON dbo.spFilterSelect TO public
GO
CREATE PROC dbo.spFilterList
AS
SET NOCOUNT ON
SELECT Filter, FilterID FROM Filter ORDER BY Filter
GO
GRANT EXEC ON dbo.spFilterList TO public
GO
ALTER VIEW dbo.vwPerson
AS
SELECT P.*,
[List As],
Initials,
[Full Name],
[Formal Name],
[IsEmployee],
[IsApplicant],
[IsRecruiter],
[IsPhysician],
[IsEmergencyContact]
FROM dbo.Person P INNER JOIN dbo.vwPersonCalculated V ON P.PersonID = V.PersonID
GO
CREATE TRIGGER dbo.ChangePersonRoleMaskOnEmployeeUpdate ON dbo.Employee 
FOR UPDATE
AS
SET NOCOUNT ON

IF UPDATE([Active Employee])
BEGIN
	UPDATE P SET [Active Role Mask] = [Active Role Mask] | 1
	FROM Person P
	INNER JOIN inserted E
	ON P.PersonID = E.EmployeeID AND E.[Active Employee] = 1

	UPDATE P SET [Active Role Mask] = [Active Role Mask] & 0x7FFFFFFE
	FROM Person P
	INNER JOIN inserted E
	ON P.PersonID = E.EmployeeID AND E.[Active Employee] = 0
END
GO
ALTER TRIGGER dbo.ChangePersonRoleMaskOnEmployeeDelete ON dbo.Employee 
FOR DELETE 
AS
SET NOCOUNT ON

UPDATE P SET [Role Mask] = [Role Mask] & 0x7FFFFFFE, [Active Role Mask] = [Active Role Mask] & 0x7FFFFFFE
FROM Person P
INNER JOIN deleted E
ON P.PersonID = E.EmployeeID
GO
ALTER TRIGGER dbo.ChangePersonRoleMaskOnEmployeeInsert ON dbo.Employee 
FOR INSERT
AS
SET NOCOUNT ON

DECLARE @company varchar(50)

UPDATE P SET [Role Mask] = [Role Mask] | 1, [Active Role Mask] = [Active Role Mask] | CASE WHEN E.[Active Employee] = 1 THEN 1 ELSE 0 END
FROM Person P
INNER JOIN inserted E
ON P.PersonID = E.EmployeeID
GO
CREATE VIEW dbo.vwLeaveType
AS
SELECT TypeID=1, [Type]='', Paid=CAST(1 AS bit), Advanced=CAST(1 AS bit), [Order]=0, InitialPeriodID=0, [Initial Seconds]=0, [OT Eligible]=CAST(1 AS bit), Abbreviation='', Flags=0, Bank=CAST(1 AS bit), [Holiday Concurrent]=CAST(1 AS bit), [Suspend Accrual]=CAST(0 AS bit)
GO
ALTER PROC dbo.spLeaveTypeList
	@advanced bit
AS
SET NOCOUNT ON

SELECT T.* FROM vwLeaveType T
WHERE @advanced IS NULL OR T.Advanced = @advanced 
ORDER BY T.[Order]
GO
ALTER PROC dbo.spLeaveTypeListAccrued
AS
SET NOCOUNT ON

SELECT T.* FROM vwLeaveType T
WHERE TypeID IN
(
	SELECT DISTINCT TypeID FROM LeaveRate
)
ORDER BY T.[Order]
GO
ALTER  PROC dbo.spDivisionGetDivisionFromDivisionID
	@division_id int,
	@division varchar(50) OUT
AS
SELECT @division = ''
SELECT @division = Division FROM Division WHERE DivisionID = @division_id
GO
ALTER  PROC dbo.spEmploymentStatusGetStatusFromStatusID
	@status_id int,
	@status varchar(50) OUT
AS
SELECT @status = ''
SELECT @status = Status FROM EmploymentStatus WHERE StatusID = @status_id
GO
ALTER  PROC dbo.spPositionStatusGetStatusFromStatusID
	@status_id int,
	@status varchar(50) OUT
AS
SELECT @status = ''
SELECT @status = Status FROM PositionStatus WHERE StatusID = @status_id
GO
ALTER  PROC dbo.spShiftGetShiftFromShiftID
	@shift_id int,
	@shift varchar(50) OUT
AS
SELECT @shift = ''
SELECT @shift = Shift FROM Shift WHERE ShiftID = @shift_id
GO
ALTER PROC dbo.spEmployeeUpdateAccount
	@employee_id int,
	@account varchar(50)
AS
DECLARE @sid varbinary(85)
DECLARE @authorized bit

SET NOCOUNT ON

SELECT @authorized = 1
IF @account = '' OR @account IS NULL SELECT @sid = NULL
ELSE
BEGIN
	SELECT @sid = SUSER_SID(@account)
	IF @sid IS NULL
	BEGIN
		DECLARE @msg varchar(4000)
		SELECT @msg = Error + ' (' + @account + ')' FROM Error WHERE ErrorID = 50001

		RAISERROR (@msg, 16, 1)
		SELECT @authorized = 0
	END
END

IF @authorized = 1 EXEC dbo.spEmployeeUpdateAccount2 @employee_id, @sid
GO
ALTER  PROC dbo.spDepartmentGetDepartmentFromDepartmentID
	@department_id int,
	@department varchar(50) OUT
AS
SELECT @department = ''
SELECT @department = Department FROM Department WHERE DepartmentID = @department_id
GO
ALTER PROC dbo.spEmployeeCountBySection
	@manager bit,
	@department bit,
	@division bit,
	@location bit
AS
DECLARE @division_label varchar(50)

SET NOCOUNT ON

SELECT @division_label = [Division Label] FROM dbo.Constant

SELECT [Section] = 'Department', [ID] = E.DepartmentID, [Text] = D.Department, [Count]=COUNT(*) FROM Employee E INNER JOIN Department D
ON E.DepartmentID = D.DepartmentID AND E.[Active Employee] = 1 AND @department = 1
GROUP BY E.[DepartmentID], D.Department

UNION

SELECT @division_label, E.DivisionID,D.Division,[Count]=COUNT(*) FROM Employee E INNER JOIN Division D
ON E.DivisionID = D.DivisionID AND E.[Active Employee] = 1 AND @division = 1
GROUP BY E.[DivisionID], D.Division

UNION

SELECT 'Location', E.LocationID,Location=L.[List As],[Count]=COUNT(*) FROM Employee E INNER JOIN Location L
ON E.LocationID = L.LocationID AND E.[Active Employee] = 1 AND @location = 1
GROUP BY E.LocationID, L.[List As]

UNION

SELECT 'Manager', ManagerID=ISNULL(E.ManagerID,'0'),Manager=ISNULL(V.[List As],'<No Manager>'), [Count]=COUNT(*)
FROM Employee E
LEFT JOIN dbo.vwPersonListAs V 
ON E.ManagerID = V.PersonID
WHERE E.[Active Employee] = 1 AND @manager = 1
GROUP BY E.ManagerID, V.[List As]

ORDER BY [Section] DESC, [Text]
GO
ALTER PROC dbo.spPersonUpdate
	@person_id int,
	@title varchar(50),
	@first_name varchar(50),
	@middle_name varchar(50),
	@last_name varchar(50),
	@suffix varchar(50),
	@male bit,
	@work_email varchar(50),
	@work_phone varchar(50),
	@extension varchar(50),
	@work_phone_note varchar(50),
	@home_office_phone varchar(50),
	@toll_free_phone varchar(50),
	@mobile_phone varchar(50),
	@work_fax varchar(50),
	@pager varchar(50),
	@note varchar(4000) = NULL, -- Note update is optional
	@work_address varchar(50),
	@work_address2 varchar(50),
	@work_city varchar(50),
	@work_state varchar(50),
	@work_zip varchar(50),
	@work_country varchar(50),
	@credentials varchar(50)
AS
DECLARE @result int

DECLARE @authorized bit

EXEC dbo.spPermissionInsureForCurrentUserOnPerson @person_id, 2, 2, @authorized out
IF @authorized = 1 
BEGIN
	UPDATE Person SET
	Title = @title,
	Credentials = @credentials,
	[First Name] = @first_name,
	[Middle Name] = @middle_name,
	[Last Name] = @last_name,
	[Home Office Phone] = @home_office_phone,
	Suffix = @suffix,
	Male = @male,
	[Work E-mail] = @work_email,
	[Work Phone] = @work_phone,
	Extension = @extension,
	[Work Phone Note] = @work_phone_note,
	[Toll Free Phone] = @toll_free_phone,
	[Mobile Phone] = @mobile_phone,
	[Work Fax] = @work_fax,
	Pager = @pager,
	[Work Address] = @work_address,
	[Work Address (cont.)] = @work_address2,
	[Work City] = @work_city,
	[Work State] = @work_state,
	[Work Zip] = @work_zip,
	[Work Country] = @work_country,
	Note = CASE WHEN @note IS NULL THEN Note ELSE @note END
	WHERE PersonID = @person_id
END
GO
CREATE PROC dbo.spTempXDelete
	@batch_id int
AS
DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1
GO
CREATE PROC dbo.spTempXList
	@batch_id int,
	@alphabetize bit
AS
SET NOCOUNT ON

IF @alphabetize = 1
SELECT X.[ID], X.X 
FROM TempX X
INNER JOIN dbo.vwPersonListAs P ON X.[ID] = P.PersonID AND X.BatchID = @batch_id ORDER BY P.[List As]
ELSE
SELECT [ID], X FROM TempX WHERE BatchID = @batch_id
GO
GRANT EXEC ON dbo.spTempXDelete TO public
GRANT EXEC ON dbo.spTempXList TO public
GRANT EXEC ON dbo.spFilterSelect TO public
GRANT EXEC ON dbo.spFilterList TO public
GO

UPDATE Constant SET [Server Version] = 33
GO
IF NOT EXISTS (SELECT * FROM Error WHERE ErrorID = 50041)
INSERT Error(ErrorID, Error)
SELECT 50041, 'You cannot delete the last leave approval type.'

IF NOT EXISTS (SELECT * FROM Error WHERE ErrorID = 50042)
INSERT Error(ErrorID, Error)
SELECT 50042, 'You cannot delete the last leave denial type.'

IF OBJECT_id('dbo.spEmployeeUpdateNumber') IS NOT NULL DROP PROC dbo.spEmployeeUpdateNumber
GO
ALTER PROC dbo.spLeaveApprovalTypeDelete
	@type_id int
AS
IF EXISTS(SELECT * FROM LeaveApprovalType WHERE TypeID != @type_id)
DELETE LeaveApprovalType WHERE TypeID = @type_id
ELSE EXEC dbo.spErrorRaise 50041
GO
ALTER PROCEDURE dbo.spDenialReasonDelete
	@denial_reason_id int
AS
IF EXISTS(SELECT * FROM DenialReason WHERE DenialReasonID != @denial_reason_id)
DELETE DenialReason WHERE DenialReasonID = @denial_reason_id
ELSE EXEC dbo.spErrorRaise 50042
GO
CREATE PROC dbo.spEmployeeUpdateNumber
	@employee_id int,
	@employee_number varchar(50)
AS
DECLARE @authorized bit

SET NOCOUNT ON

EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 8, 2, @authorized out
IF @authorized = 1 
UPDATE Employee SET [Employee Number] = @employee_number
WHERE EmployeeID = @employee_id
GO
GRANT EXEC ON dbo.spEmployeeUpdateNumber TO public

UPDATE Constant SET [Server Version] = 35
GO
UPDATE Constant SET [Server Version] = 36
GO
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID]=OBJECT_id('LeaveRatePeriod') AND [name]='Weekday')
ALTER TABLE LeaveRatePeriod ADD Weekday int NOT NULL DEFAULT(0)
GO
UPDATE LeaveRatePeriod SET Weekday=1 WHERE PeriodID=200768
UPDATE LeaveRatePeriod SET Weekday=2 WHERE PeriodID=202816
UPDATE LeaveRatePeriod SET Weekday=3 WHERE PeriodID=204864
UPDATE LeaveRatePeriod SET Weekday=4 WHERE PeriodID=206912
UPDATE LeaveRatePeriod SET Weekday=5 WHERE PeriodID=208960
UPDATE LeaveRatePeriod SET Weekday=6 WHERE PeriodID=211008
UPDATE LeaveRatePeriod SET Weekday=7 WHERE PeriodID=213056
UPDATE LeaveRatePeriod SET Weekday=1 WHERE PeriodID=215104
UPDATE LeaveRatePeriod SET Weekday=2 WHERE PeriodID=217152
UPDATE LeaveRatePeriod SET Weekday=3 WHERE PeriodID=219200
UPDATE LeaveRatePeriod SET Weekday=4 WHERE PeriodID=221248
UPDATE LeaveRatePeriod SET Weekday=5 WHERE PeriodID=223296
UPDATE LeaveRatePeriod SET Weekday=6 WHERE PeriodID=225344
UPDATE LeaveRatePeriod SET Weekday=7 WHERE PeriodID=227392
UPDATE LeaveRatePeriod SET Weekday=1 WHERE PeriodID=258176
UPDATE LeaveRatePeriod SET Weekday=2 WHERE PeriodID=260224
UPDATE LeaveRatePeriod SET Weekday=3 WHERE PeriodID=262272
UPDATE LeaveRatePeriod SET Weekday=4 WHERE PeriodID=264320
UPDATE LeaveRatePeriod SET Weekday=5 WHERE PeriodID=266368
UPDATE LeaveRatePeriod SET Weekday=6 WHERE PeriodID=268416
UPDATE LeaveRatePeriod SET Weekday=7 WHERE PeriodID=270464
GO
IF OBJECT_id('dbo.LeaveNote') IS NULL
BEGIN
CREATE TABLE dbo.[LeaveNote] (
	[NoteID] [int] NOT NULL IDENTITY(1,1),
	[Jurisdiction] varchar (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Note] [text] COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL 
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]


INSERT LeaveNote(Jurisdiction, Note)
SELECT 'Federal', [Leave Note] FROM dbo.Constant
END
GO
IF OBJECT_id('dbo.TimeType') IS NULL
BEGIN
	BEGIN TRAN

	CREATE TABLE dbo.TimeType
	(
		TypeID int PRIMARY KEY NOT NULL,
		[Type] varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
		Abbreviation varchar(4) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
		[Order] int NOT NULL,
		CompLeaveTypeID int NULL,
		[Pay Rate] smallmoney NULL,
		PayRateM smallmoney NOT NULL,
		PayRateB smallmoney NOT NULL,
		[Billing Rate] smallmoney NULL,
		BillingRateM smallmoney NOT NULL,
		BillingRateB smallmoney NOT NULL,
		[Fixed Pay] [smallmoney] NULL,
		[Fixed Billing] [smallmoney] NULL,
		Flags int NOT NULL DEFAULT (0),
		[Comp Rate] smallmoney DEFAULT(1)
	)

	ALTER TABLE dbo.[TimeType] ADD 
	CONSTRAINT [FK_TimeType_LeaveType] FOREIGN KEY 
	(
		[CompLeaveTypeID]
	) REFERENCES dbo.[LeaveType] (
		[TypeID]
	),
	CONSTRAINT [IX_TimeType_DuplicateType] UNIQUE NONCLUSTERED 
	(
		[Type]
	),
	CONSTRAINT [IX_TimeType_DuplicateAbbreviation] UNIQUE NONCLUSTERED 
	(
		[Abbreviation]
	),
	CONSTRAINT [CK_TimeType_Blank] CHECK ([Type] <> ''),
	CONSTRAINT [CK_TimeType_BlankAbbr] CHECK ([Abbreviation] <> ''),
	CONSTRAINT [CK_TimeType_TypeID] CHECK ([TypeID] = 0x40000000 or ([TypeID] = 0x20000000 or ([TypeID] = 0x10000000 or ([TypeID] = 0x08000000 or ([TypeID] = 0x04000000 or ([TypeID] = 0x02000000 or ([TypeID] = 0x01000000 or ([TypeID] = 0x800000 or ([TypeID] = 0x400000 or ([TypeID] = 0x200000 or ([TypeID] = 0x100000 or ([TypeID] = 0x080000 or ([TypeID] = 0x040000 or ([TypeID] = 0x020000 or ([TypeID] = 0x010000 or ([TypeID] = 0x8000 or ([TypeID] = 0x4000 or ([TypeID] = 0x2000 or ([TypeID] = 0x1000 or ([TypeID] = 0x0800 or ([TypeID] = 0x0400 or ([TypeID] = 0x0200 or ([TypeID] = 0x0100 or ([TypeID] = 0x80 or ([TypeID] = 0x40 or ([TypeID] = 0x20 or ([TypeID] = 0x10 or ([TypeID] = 8 or ([TypeID] = 4 or ([TypeID] = 2 or [TypeID] = 1))))))))))))))))))))))))))))))

	-- Flags column may not exist in existing TimeType table which would throw an error
	EXEC sp_executesql N'INSERT TimeType(TypeID, Type, Abbreviation, [Order], CompLeaveTypeID, [Pay Rate], PayRateM, PayRateB, [Billing Rate], BillingRateM, BillingRateB, [Flags])
	SELECT 1, [Type] = ''Regular'', ''REG'', [Order] = 1, NULL, NULL, 1, 0, NULL, 1, 0, 5
	UNION
	SELECT 2, ''OT Ineligible'', ''NoOT'', 2, NULL, NULL, 1, 0, NULL, 1, 0, 0
	UNION
	SELECT 4, ''Overtime'', ''OT'', 3, NULL, NULL, 1.5, 0, NULL, 1, 0, 2
	UNION
	SELECT 8, ''Holiday'', ''HOL'', 4, NULL, NULL, 1, 0, NULL, 1, 0, 18
	UNION
	SELECT 16, ''Weekend'', ''WKND'', 5, NULL, NULL, 1, 0, NULL, 1, 0, 4
	ORDER BY [Order]'

	COMMIT TRAN
END
GO
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [id]=OBJECT_id('dbo.TimeType') AND [name]='Comp Rate')
BEGIN
	ALTER TABLE dbo.TimeType ADD [Comp Rate] smallmoney NOT NULL DEFAULT(1)
END
GO
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [id]=OBJECT_id('dbo.TimeType') AND [name]='Flags')
BEGIN
	ALTER TABLE dbo.TimeType ADD Flags int NOT NULL DEFAULT(0)
	EXEC sp_executesql N'UPDATE dbo.TimeType SET Flags=5 WHERE TypeID=1'
	EXEC sp_executesql N'UPDATE dbo.TimeType SET Flags=2 WHERE TypeID=4'
	EXEC sp_executesql N'IF NOT EXISTS(SELECT * FROM TimeType WHERE Flags=2) UPDATE TimeType SET Flags=2 WHERE Type=''Overtime'''
END
GO
IF EXISTS(SELECT * FROM syscolumns WHERE [id]=OBJECT_id('dbo.TimeType') AND [name]='Regular')
BEGIN
	EXEC dbo.spAdminDropDefault 'dbo.TimeType', 'Regular'
	EXEC sp_executesql N'UPDATE dbo.TimeType SET Flags=Flags | 1 WHERE Regular=1'
	EXEC sp_executesql N'ALTER TABLE dbo.TimeType DROP COLUMN Regular'
END
GO
IF EXISTS(SELECT * FROM syscolumns WHERE [id]=OBJECT_id('dbo.TimeType') AND [name]='OT Eligible')
BEGIN
	EXEC dbo.spAdminDropDefault 'dbo.TimeType', 'OT Eligible'
	EXEC sp_executesql N'UPDATE TimeType SET Flags=Flags | 4 WHERE [OT Eligible]=1'
	EXEC sp_executesql N'ALTER TABLE dbo.TimeType DROP COLUMN [OT Eligible]'
END
GO
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID]=OBJECT_id('TimeType') AND [name]='Fixed Pay')
ALTER TABLE TimeType ADD [Fixed Pay] [smallmoney] NULL

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID]=OBJECT_id('TimeType') AND [name]='Fixed Billing')
ALTER TABLE TimeType ADD [Fixed Billing] [smallmoney] NULL
GO
-- New field, Constant.OTTimeTypeID, WeekendTimeTypeID, HolidayTimeTypeID
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [name] = 'OTTimeTypeID' AND [id] = OBJECT_id('dbo.Constant'))
BEGIN
	ALTER TABLE dbo.Constant ADD [OTTimeTypeID] int NULL DEFAULT 'OTTimeTypeID'
	ALTER TABLE dbo.Constant
	ADD CONSTRAINT [FK_Constant_OTTimeType] FOREIGN KEY 
	(
		[OTTimeTypeID]
	) REFERENCES dbo.[TimeType] (
		[TypeID]
	)

	EXEC sp_executesql N'IF EXISTS(SELECT * FROM TimeType WHERE TypeID=2) UPDATE Constant SET OTTimeTypeID=2'
END


IF NOT EXISTS(SELECT * FROM syscolumns WHERE [name] = 'HolidayTimeTypeID' AND [id] = OBJECT_id('dbo.Constant'))
BEGIN
	ALTER TABLE dbo.Constant ADD [HolidayTimeTypeID] int NULL DEFAULT 'HolidayTimeTypeID'
	ALTER TABLE dbo.Constant
	ADD CONSTRAINT [FK_Constant_HolidayTimeTypeID] FOREIGN KEY 
	(
		[HolidayTimeTypeID]
	) REFERENCES dbo.[TimeType] (
		[TypeID]
	)

	EXEC sp_executesql N'IF EXISTS(SELECT * FROM TimeType WHERE TypeID=8) UPDATE Constant SET HolidayTimeTypeID=8'
END

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [name] = 'WeekendTimeTypeID' AND [id] = OBJECT_id('dbo.Constant'))
BEGIN
	ALTER TABLE dbo.Constant ADD [WeekendTimeTypeID] int NULL DEFAULT 'WeekendTimeTypeID'
	ALTER TABLE dbo.Constant
	ADD CONSTRAINT [FK_Constant_WeekendTimeType] FOREIGN KEY 
	(
		[WeekendTimeTypeID]
	) REFERENCES dbo.[TimeType] (
		[TypeID]
	)

	EXEC sp_executesql N'IF EXISTS(SELECT * FROM TimeType WHERE TypeID=16) UPDATE Constant SET WeekendTimeTypeID=16'
END

GO
DECLARE @default int
SELECT @default = cdefault FROM syscolumns WHERE [id] = object_id('LeaveType') AND [name] = 'OT Comp'

IF @default IS NOT NULL
BEGIN
	DECLARE @t nvarchar(400)
	DECLARE @d sysname
	SELECT @d = [name] FROM sysobjects WHERE [id] = @default
	
	SET @t = 'ALTER TABLE LeaveType DROP CONSTRAINT [' + @d + ']'
	EXEC sp_executesql @t

	ALTER TABLE LeaveType DROP COLUMN [OT Comp]
END
GO
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [name] = 'Abbreviation' AND [id] = OBJECT_id('dbo.LeaveType'))
BEGIN
	ALTER TABLE LeaveType ADD Abbreviation varchar(4) DEFAULT ''
	EXEC sp_executesql N'UPDATE LeaveType SET Abbreviation = UPPER(SUBSTRING([Type], 1, 4))'
END
GO
ALTER PROC dbo.spTurnover
	@batch_id int
AS
DECLARE @y int

SET NOCOUNT ON

SELECT @y = YEAR(GETDATE())

SELECT Y = -2
INTO #Y
UNION SELECT Y = -1
UNION SELECT Y = 0

SELECT E = 0 --, Header = 'Employment'
INTO #E
UNION SELECT E = 2 --, Text = 'Hires'
UNION SELECT E = 3 --, Text = 'Separations'

SELECT M = 1, MMM = CAST('Jan' as varchar(10))
INTO #M
UNION SELECT M = 2, MMM = 'Feb'
UNION SELECT M = 3, MMM = 'Mar'
UNION SELECT M = 4, MMM = 'Apr'
UNION SELECT M = 5, MMM = 'May'
UNION SELECT M = 6, MMM = 'Jun'
UNION SELECT M = 7, MMM = 'Jul'
UNION SELECT M = 8, MMM = 'Aug'
UNION SELECT M = 9, MMM = 'Sep'
UNION SELECT M = 10, MMM = 'Oct'
UNION SELECT M = 11, MMM = 'Nov'
UNION SELECT M = 12, MMM = 'Dec'

-- Builds the table, leaving counts initialized to 0
SELECT [Relative Year] = Y, [Month] = M, MMM, Start = dbo.GetDateFromMDY(M, 1, @y + Y), [Next] = dbo.GetDateFromMDY(M + 1, 1, @y + Y), [CategoryID] = E, [Count] = 0, [Start Days] = NULL, [Stop Days] = NULL
INTO #Table
FROM #Y
CROSS JOIN #E
CROSS JOIN #M

INSERT #Table
SELECT Y, 13, 'Year', dbo.GetDateFromMDY(1, 1, @y + Y), dbo.GetDateFromMDY(1, 1, @y + Y + 1), E, 0, NULL, NULL
FROM #Y
CROSS JOIN #E

UPDATE #Table SET [Start Days] = DATEDIFF(d, 0, Start), [Stop Days] = DATEDIFF(d, 0, [Next] - 1)

SELECT EmployeeID = [ID], Start = EC.[Start Day past 1900], Stop = ISNULL(EC.[Stop Day past 1900], 2147483647)
INTO #EC
FROM TempX X
INNER JOIN EmployeeCompensation EC ON X.BatchID = @batch_id AND EC.EmployeeID = X.[ID]

INSERT #EC(EmployeeID, Start, Stop)
SELECT EmployeeID, [Seniority Begins Day past 1900], ISNULL([Terminated Day past 1900], 2147483647)
FROM Employee E
INNER JOIN TempX X ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID AND E.EmployeeID NOT IN
(
	SELECT EmployeeID FROM #EC
)

SELECT EmployeeID, Start = MIN(Start), Stop = MAX(Stop)
INTO #E2
FROM #EC GROUP BY EmployeeID

-- Updates employment count
UPDATE #Table SET [Count] = (
	SELECT COUNT(*) FROM #EC WHERE dbo.DoRaysIntersect(#EC.Start, #EC.Stop, #Table.[Start Days], #Table.[Stop Days]) = 1
)
FROM #Table WHERE CategoryID = 0

-- Updates hires count
UPDATE #Table SET [Count] = (
	SELECT COUNT(*) FROM #E2
	WHERE #E2.Start BETWEEN #Table.[Start Days] AND #Table.[Stop Days]
)
FROM #Table WHERE CategoryID = 2

-- Updates separations count
UPDATE #Table SET [Count] = (
	SELECT COUNT(*) FROM #E2
	WHERE #E2.Stop BETWEEN #Table.[Start Days] AND #Table.[Stop Days]
)
FROM #Table WHERE CategoryID = 3

SELECT [Month], MMM, [Relative Year], [CategoryID], [Count]
FROM #Table
ORDER BY [Month], [CategoryID], [Relative Year] 

DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1
GO
IF OBJECT_id('dbo.DoesRayContain') IS NOT NULL DROP FUNCTION dbo.DoesRayContain
GO
CREATE FUNCTION dbo.DoesRayContain(@start int, @stop int, @point int)
RETURNS bit
AS
BEGIN
	DECLARE @intersects bit

	SELECT @intersects = CASE
		WHEN @point IS NULL THEN 0
		WHEN @start IS NULL AND @stop IS NULL THEN 1
		WHEN @start IS NULL AND @point <= @stop THEN 1
		WHEN @stop IS NULL AND @point >= @start THEN 1
		WHEN @point BETWEEN @start AND @stop THEN 1
		ELSE 0 
	END

	RETURN @intersects
END
GO

-- New error messages
IF NOT EXISTS (SELECT * FROM Error WHERE ErrorID = 50028)
INSERT Error(ErrorID, Error)
SELECT 50028, 'You cannot delete the last pay step in a pay table.'

IF NOT EXISTS (SELECT * FROM Error WHERE ErrorID = 50048)
INSERT Error(ErrorID, Error)
SELECT 50048, 'You cannot delete the last leave note.'

IF NOT EXISTS (SELECT * FROM Error WHERE ErrorID = 50029)
INSERT Error(ErrorID, Error)
SELECT 50029, 'You cannot delete the last pay grade in a pay table.'

IF NOT EXISTS (SELECT * FROM Error WHERE ErrorID = 50040)
INSERT Error(ErrorID, Error)
SELECT 50040, 'You cannot delete the last pay table.'

IF NOT EXISTS (SELECT * FROM Error WHERE ErrorID = 50047)
INSERT Error(ErrorID, Error)
SELECT 50047, 'You cannot delete the last project class.'



-- Spelling error
UPDATE MilitaryBranch SET Branch = REPLACE(Branch, 'Gaurd', 'Guard')

-- Extra fields
IF NOT EXISTS(SELECT * FROM ColumnGrid WHERE FieldID=71)
INSERT ColumnGrid(FieldID, [Table], [Key], colid, AttributeID, Field, Label, Importable, Reportable, [Order])
SELECT 71, 'Employee', 'EmployeeID', colid, 8, 'Active Employee', 'Active', 0, 0, 55
 FROM syscolumns WHERE [id] = OBJECT_id('Employee') AND [name] = 'Active Employee'

UPDATE dbo.ColumnGrid SET Label = 'Race' WHERE FieldID = 32

IF NOT EXISTS(SELECT * FROM ColumnGrid WHERE FieldID=72)
INSERT ColumnGrid(FieldID, [Table], [Key], colid, AttributeID, Field, Label, Importable, Reportable, [Order])
SELECT 72, 'Employee', 'EmployeeID', colid, 64, 'Salaried', 'Salaried', 0, 0, 55
FROM syscolumns WHERE [id] = OBJECT_id('Employee') AND [name] = 'Salaried'

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID] = OBJECT_id('dbo.Filter') AND [name] = 'TypeID')
ALTER TABLE Filter ADD TypeID int DEFAULT(1)




-- New field, Employee.[Billing Rate]
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [name] = 'Billing Rate' AND [id] = OBJECT_id('dbo.Employee'))
ALTER TABLE Employee ADD [Billing Rate] smallmoney NOT NULL DEFAULT(0)

-- New field, Employee.[DefaultTimeTypeID]
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [name] = 'DefaultTimeTypeID' AND [id] = OBJECT_id('dbo.Employee'))
BEGIN
	BEGIN TRAN

	ALTER TABLE Employee ADD [DefaultTimeTypeID] int NULL

	CONSTRAINT [FK_Employee_TimeType] FOREIGN KEY 
	(
		[DefaultTimeTypeID]
	) REFERENCES dbo.[TimeType] (
		[TypeID]
	)

	EXEC sp_executesql N'UPDATE Employee SET DefaultTimeTypeID = (SELECT TOP 1 TypeID FROM TimeType ORDER BY [ORDER])'
	
	ALTER TABLE Employee ALTER COLUMN [DefaultTimeTypeID] int NOT NULL

	COMMIT TRAN
END

-- New field, Employee.[Direct Deposit Account Number]
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [name] = 'Direct Deposit Account Number' AND [id] = OBJECT_id('dbo.Employee'))
BEGIN
	BEGIN TRAN
	ALTER TABLE Employee ADD [Direct Deposit Account Number] varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	EXEC sp_executesql N'UPDATE Employee SET [Direct Deposit Account Number]='''''
	ALTER TABLE Employee ALTER COLUMN [Direct Deposit Account Number] varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
	COMMIT TRAN
END

-- New field, Employee.[Payroll Delay]
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [name] = 'Payroll Delay' AND [id] = OBJECT_id('dbo.Employee'))
BEGIN
	BEGIN TRAN
	ALTER TABLE Employee ADD [Payroll Delay] int NULL
	EXEC sp_executesql N'UPDATE Employee SET [Payroll Delay]=0'
	ALTER TABLE Employee ALTER COLUMN [Payroll Delay] int NOT NULL
	COMMIT TRAN
END
GO
-- New field, Constant.[Project Label]
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [name] = 'Project Label' AND [id] = OBJECT_id('dbo.Constant'))
ALTER TABLE dbo.Constant ADD [Project Label] varchar(7) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL DEFAULT 'Project'

-- New field, Constant.TODOption
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [name] = 'TODOption' AND [id] = OBJECT_id('dbo.Constant'))
ALTER TABLE dbo.Constant ADD TODOption int NOT NULL DEFAULT 0
GO
-- New field, EmployeeLeaveUsedItem.[Created Day past 1900]
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [name] = 'Created Day Past 1900' AND [id] = OBJECT_id('dbo.EmployeeLeaveUsedItem'))
ALTER TABLE dbo.EmployeeLeaveUsedItem ADD [Created Day past 1900] int NOT NULL DEFAULT DATEDIFF(d, 0, GETDATE())

-- New field, EmployeeLeaveUsed.[Created Day past 1900]
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [name] = 'Created Day Past 1900' AND [id] = OBJECT_id('dbo.EmployeeLeaveUsed'))
ALTER TABLE dbo.EmployeeLeaveUsed ADD [Created Day past 1900] int NOT NULL DEFAULT DATEDIFF(d, 0, GETDATE())

-- New field, EmployeeLeaveEarned.[Created Day past 1900]
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [name] = 'Created Day Past 1900' AND [id] = OBJECT_id('dbo.EmployeeLeaveEarned'))
ALTER TABLE dbo.EmployeeLeaveEarned ADD [Created Day past 1900] int NOT NULL DEFAULT DATEDIFF(d, 0, GETDATE())

-- New field, EmployeeTime.[Created Day past 1900]
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [name] = 'Created Day Past 1900' AND [id] = OBJECT_id('dbo.EmployeeTime'))
ALTER TABLE dbo.EmployeeTime ADD [Created Day past 1900] int NOT NULL DEFAULT DATEDIFF(d, 0, GETDATE())
GO
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID]=OBJECT_id('dbo.EmployeeTime') AND [name]='PPE Day past 1900')
BEGIN
	ALTER TABLE dbo.EmployeeTime ADD [PPE Day past 1900] int NOT NULL DEFAULT(0)
	EXEC sp_executesql N'UPDATE EmployeeTime SET [PPE Day past 1900] = DATEDIFF(d,0,[In])'
END

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID]=OBJECT_id('dbo.EmployeeLeaveEarned') AND [name]='PPE Day past 1900')
BEGIN
	ALTER TABLE dbo.EmployeeLeaveEarned ADD [PPE Day past 1900] int NOT NULL DEFAULT(0)
	EXEC sp_executesql N'UPDATE EmployeeLeaveEarned SET [PPE Day past 1900] = [Day past 1900]'
END

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID]=OBJECT_id('dbo.EmployeeLeaveUsedItem') AND [name]='PPE Day past 1900')
BEGIN
	ALTER TABLE dbo.EmployeeLeaveUsedItem ADD [PPE Day past 1900] int NOT NULL DEFAULT(0)
	EXEC sp_executesql N'UPDATE EmployeeLeaveUsedItem SET [PPE Day past 1900] = [Day past 1900]'
END

-- New field, EmployeeLeaveUsed.[PPE Start Day past 1900]
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [name] = 'PPE Start Day past 1900' AND [id] = OBJECT_id('dbo.EmployeeLeaveUsed'))
BEGIN
	ALTER TABLE dbo.EmployeeLeaveUsed ADD [PPE Start Day past 1900] int NOT NULL DEFAULT DATEDIFF(d, 0, GETDATE())
	EXEC sp_executesql N'UPDATE U SET [PPE Start Day past 1900] = ISNULL((SELECT MIN(I.[PPE Day past 1900]) FROM EmployeeLeaveUsedItem I WHERE I.LeaveID=U.LeaveID), U.[Start Day past 1900]) FROM EmployeeLeaveUsed U'
END

-- New field, EmployeeLeaveUsed.[PPE Stop Day past 1900]
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [name] = 'PPE Stop Day past 1900' AND [id] = OBJECT_id('dbo.EmployeeLeaveUsed'))
BEGIN
	ALTER TABLE dbo.EmployeeLeaveUsed ADD [PPE Stop Day past 1900] int NOT NULL DEFAULT DATEDIFF(d, 0, GETDATE())
	EXEC sp_executesql N'UPDATE U SET [PPE Stop Day past 1900] = ISNULL((SELECT MAX(I.[PPE Day past 1900]) FROM EmployeeLeaveUsedItem I WHERE I.LeaveID=U.LeaveID), U.[Stop Day past 1900]) FROM EmployeeLeaveUsed U'
END
GO
-- New field, EmployeeLeaveUsed.[Created Start Day past 1900]
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [name] = 'Created Start Day past 1900' AND [id] = OBJECT_id('dbo.EmployeeLeaveUsed'))
BEGIN
	ALTER TABLE dbo.EmployeeLeaveUsed ADD [Created Start Day past 1900] int NOT NULL DEFAULT DATEDIFF(d, 0, GETDATE())
	EXEC sp_executesql N'UPDATE U SET [Created Start Day past 1900] = ISNULL((SELECT MIN(I.[Created Day past 1900]) FROM EmployeeLeaveUsedItem I WHERE I.LeaveID=U.LeaveID), U.[Created Day past 1900]) FROM EmployeeLeaveUsed U'
END
GO
-- New field, EmployeeLeaveUsed.[Created Stop Day past 1900]
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [name] = 'Created Stop Day past 1900' AND [id] = OBJECT_id('dbo.EmployeeLeaveUsed'))
BEGIN
	ALTER TABLE dbo.EmployeeLeaveUsed ADD [Created Stop Day past 1900] int NOT NULL DEFAULT DATEDIFF(d, 0, GETDATE())
	EXEC sp_executesql N'UPDATE U SET [Created Stop Day past 1900] = ISNULL((SELECT MAX(I.[Created Day past 1900]) FROM EmployeeLeaveUsedItem I WHERE I.LeaveID=U.LeaveID), U.[Created Day past 1900]) FROM EmployeeLeaveUsed U'
END
GO
ALTER VIEW dbo.vwEmployeeLeaveEarned
AS
SELECT L.*, Effective = dbo.GetDateFromDaysPast1900(L.[Day past 1900]), Employee = E.[List As], [Employee Full Name] = E.[Full Name],
Calculated = CAST(CASE WHEN [Auto] > 0 THEN 1 ELSE 0 END AS bit),
Accrual = CAST(CASE WHEN [Auto] = 1 THEN 1 ELSE 0 END AS bit),
[Limit Adjustment] = CAST(CASE WHEN [Auto] = 2 THEN 1 ELSE 0 END AS bit),
Carryover = CAST(CASE WHEN [Auto] = 3 THEN 1 ELSE 0 END AS bit)
FROM EmployeeLeaveEarned L
INNER JOIN vwPerson E ON L.EmployeeID = E.PersonID
GO
ALTER PROC dbo.spPayStepDelete
	@step_id int
AS
IF EXISTS(SELECT * FROM PayStep WHERE PayStepID != @step_id) 
DELETE PayStep WHERE PayStepID = @step_id
ELSE EXEC dbo.spErrorRaise 50028
GO
ALTER PROC dbo.spPayGradeDelete
	@pay_grade_id int = NULL, -- hack for backward compatibility
	@grade_id int = NULL
AS
SET NOCOUNT ON

IF @grade_id IS NULL AND @pay_grade_id IS NOT NULL SET @grade_id = @pay_grade_id

DELETE PayGrade WHERE PayGradeID = @pay_grade_id OR PayGradeID = @grade_id

IF EXISTS(SELECT * FROM PayGrade WHERE PayGradeID != @grade_id)
DELETE PayGrade WHERE PayGradeID = @pay_grade_id
ELSE EXEC dbo.spErrorRaise 50029
GO
IF OBJECT_id('dbo.Project') IS NULL
BEGIN
	BEGIN TRAN

	CREATE TABLE dbo.ProjectClass (
		ClassID int IDENTITY (1, 1) NOT NULL ,
		Class varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS
	)

	ALTER TABLE dbo.ProjectClass ADD 
		CONSTRAINT [PK_ProjectClass] PRIMARY KEY  CLUSTERED 
		(
			[ClassID]
		)  ON [PRIMARY] 
	


	CREATE TABLE dbo.Project (
		[ProjectID] [int] IDENTITY (1, 1) NOT NULL ,
		[Project] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[ProjectManagerID] [int] NULL ,
		LocationID int NOT NULL,
		[Active] [bit] NOT NULL ,
		[Pay Rate] smallmoney,
		[Billing Rate] smallmoney,
		Note varchar(4000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL DEFAULT(''),
		ClassID int NOT NULL,
	) ON [PRIMARY]
	
	
	
	ALTER TABLE dbo.Project ADD 
		CONSTRAINT [PK_Project] PRIMARY KEY  CLUSTERED 
		(
			[ProjectID]
		)  ON [PRIMARY] 
	
	
	ALTER TABLE dbo.Project ADD 
		CONSTRAINT [FK_Project_Employee] FOREIGN KEY 
		(
			[ProjectManagerID]
		) REFERENCES dbo.[Employee] (
			[EmployeeID]
		)

	ALTER TABLE dbo.Project ADD 
		CONSTRAINT [FK_Project_Location] FOREIGN KEY 
		(
			[LocationID]
		) REFERENCES dbo.[Location] (
			[LocationID]
		)

	ALTER TABLE dbo.Project ADD 
		CONSTRAINT [FK_Project_Class] FOREIGN KEY 
		(
			[ClassID]
		) REFERENCES dbo.[ProjectClass] (
			[ClassID]
		)
	
	CREATE TABLE dbo.[ProjectTask] (
		[TaskID] [int] IDENTITY (1, 1) NOT NULL PRIMARY KEY,
		[ProjectID] [int] NOT NULL ,
		[ParentTaskID] [int] NULL ,
		[Task] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL 
	) ON [PRIMARY]
	
	ALTER TABLE dbo.[ProjectTask] ADD 
	CONSTRAINT [FK_ProjectTask_Project] FOREIGN KEY 
	(
		[ProjectID]
	) REFERENCES dbo.Project (
		[ProjectID]
	),
	CONSTRAINT [FK_ProjectTask_ProjectTask] FOREIGN KEY 
	(
		[ParentTaskID]
	) REFERENCES dbo.[ProjectTask] (
		[TaskID]
	)

	COMMIT TRAN

END
GO
IF OBJECT_id('dbo.EmployeeProject') IS NULL
BEGIN
	CREATE TABLE dbo.[EmployeeProject] (
		[ItemID] [int] IDENTITY (1, 1) NOT NULL ,
		[EmployeeID] [int] NOT NULL ,
		[ProjectID] [int] NOT NULL ,
		[Billing Rate] [smallmoney] NULL ,
		[Pay Rate] [smallmoney] NULL ,
		[Start Day past 1900] [int] NOT NULL ,
		[Stop Day past 1900] [int] NULL ,
		[Percent of Time Allocated] [int] NOT NULL,
		Comment varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
	) ON [PRIMARY]

	ALTER TABLE dbo.[EmployeeProject] WITH NOCHECK ADD 
	CONSTRAINT [PK_EmployeeProject] PRIMARY KEY  CLUSTERED 
	(
		[ItemID]
	)  ON [PRIMARY] 


	ALTER TABLE dbo.EmployeeProject ADD 
	CONSTRAINT [FK_EmployeeProject_Employee] FOREIGN KEY 
	(
		[EmployeeID]
	) REFERENCES dbo.[Employee] (
		[EmployeeID]
	) ON DELETE CASCADE,
	CONSTRAINT [FK_EmployeeProject_Project] FOREIGN KEY 
	(
		[ProjectID]
	) REFERENCES dbo.Project (
		[ProjectID]
	)
END
GO
IF OBJECT_id('dbo.TimeSchema') IS NULL
BEGIN
	BEGIN TRAN



	

	CREATE TABLE dbo.TimeSchema (
		[TimeSchemaID] [int] NOT NULL IDENTITY(1,1),
		[Schema] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
		[Column Mask] [int] NOT NULL,
		Created datetime NOT NULL DEFAULT GETDATE(),
		Creator varbinary(85) NOT NULL DEFAULT SUSER_SID()
	) ON [PRIMARY]
	
	
	ALTER TABLE dbo.TimeSchema WITH NOCHECK ADD 
		CONSTRAINT PK_TimeSchema PRIMARY KEY   CLUSTERED 
		(
			[TimeSchemaID]
		)  ON [PRIMARY] 
	
	ALTER TABLE dbo.TimeSchema ADD CONSTRAINT [CK_TimeSchema_Required] CHECK (len([Schema]) <> 0)

	INSERT TimeSchema([Schema], [Column Mask])
	
	
	SELECT 'Date/Hours', 0x11
	UNION
	SELECT 'Factory Floor', 0x7
	UNION
	SELECT 'In Time/Out Time', 0
	UNION
	SELECT 'Shift Differential', 0x59
	UNION
	SELECT 'Universal', 0x7FFFFBFF
	

	ALTER TABLE dbo.Constant ADD DefaultTimeSchemaID int NULL
	EXEC sp_executesql N'UPDATE Constant SET DefaultTimeSchemaID = 3'
	ALTER TABLE dbo.Constant ALTER COLUMN DefaultTimeSchemaID int NOT NULL

	ALTER TABLE dbo.Constant ADD 
	CONSTRAINT FK_Constant_TimeSchemaID FOREIGN KEY 
	(
		DefaultTimeSchemaID
	) REFERENCES dbo.TimeSchema (
		TimeSchemaID
	)

	ALTER TABLE dbo.Employee ADD TimeSchemaID int NULL
	EXEC sp_executesql N'UPDATE Employee SET TimeSchemaID = 3'
	ALTER TABLE dbo.Employee ALTER COLUMN TimeSchemaID int NOT NULL

	ALTER TABLE dbo.Employee ADD 
	CONSTRAINT FK_Employee_TimeSchemaID FOREIGN KEY 
	(
		TimeSchemaID
	) REFERENCES dbo.TimeSchema (
		TimeSchemaID
	)

	CREATE TABLE dbo.[EmployeeTimeStatus] (
		[StatusID] [int] NOT NULL ,
		[Status] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[Order] [int] NOT NULL 
	) ON [PRIMARY]
	
	
	ALTER TABLE dbo.[EmployeeTimeStatus] WITH NOCHECK ADD 
		CONSTRAINT [PK_EmployeeTimeStatus] PRIMARY KEY  CLUSTERED 
		(
			[StatusID]
		)  ON [PRIMARY] 
	
	INSERT EmployeeTimeStatus
	VALUES(1, 'Approved', 1)
	
	INSERT EmployeeTimeStatus
	VALUES(2, 'Denied', 3)
	
	INSERT EmployeeTimeStatus
	VALUES(5, 'Approved with Changes', 2)
	
	INSERT EmployeeTimeStatus
	VALUES(8, 'Pending', 0)
	
	
	IF OBJECT_id('UpdateLastOut') IS NOT NULL DROP TRIGGER UpdateLastOut
	IF OBJECT_id('CK_EmployeeTime_InLessThanOut') IS NOT NULL ALTER TABLE EmployeeTime DROP CONSTRAINT CK_EmployeeTime_InLessThanOut
	IF OBJECT_id('CK_EmployeeTime_OutMinusInExceeds1Day') IS NOT NULL ALTER TABLE EmployeeTime DROP CONSTRAINT CK_EmployeeTime_OutMinusInExceeds1Day
	IF OBJECT_id('FK_EmployeeTime_Employee') IS NOT NULL ALTER TABLE EmployeeTime DROP CONSTRAINT FK_EmployeeTime_Employee

	EXEC dbo.sp_rename 'dbo.EmployeeTime', 'EmployeeTimeOld'

	CREATE TABLE dbo.EmployeeTime(
		ItemID int IDENTITY(1,1) PRIMARY KEY,
		EmployeeID int,
		[In] smalldatetime,
		Seconds int,
		ProjectID int NULL,
		TaskID int NULL,
		StatusID int NOT NULL DEFAULT(8),
		[Employee Comment] varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL DEFAULT '',
		[Manager Comment] varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL DEFAULT '',
		[Pay Rate] smallmoney DEFAULT 0,
		[Billing Rate] smallmoney DEFAULT 0,
		TypeID int,
		[Odometer Start] int NOT NULL DEFAULT(0),
		[Odometer Stop] int NOT NULL DEFAULT(0),
		[Created Day past 1900] int NOT NULL DEFAULT DATEDIFF(d, 0, GETDATE()),
		[Last Updated Day past 1900] int NOT NULL DEFAULT DATEDIFF(d, 0, GETDATE()),
		[Last Updated User] sysname NOT NULL DEFAULT SUSER_SNAME(),
		SourceIn varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL DEFAULT(''),
		SourceOut varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL DEFAULT(''),
		[Fixed Billing] [smallmoney] NOT NULL DEFAULT (0),
		[Fixed Pay] [smallmoney] NOT NULL DEFAULT (0),
	)
	
	ALTER TABLE dbo.[EmployeeTime] WITH NOCHECK ADD 
	CONSTRAINT [FK_EmployeeTime_EmployeeTimeStatus] FOREIGN KEY 
	(
		[StatusID]
	) REFERENCES dbo.[EmployeeTimeStatus] (
		[StatusID]
	),
	CONSTRAINT FK_EmployeeTime_Employee FOREIGN KEY
	(
		EmployeeID
	) REFERENCES dbo.Employee (
		EmployeeID
	) ON DELETE CASCADE,
	CONSTRAINT [FK_EmployeeTime_Project] FOREIGN KEY 
	(
		[ProjectID]
	) REFERENCES dbo.Project (
		[ProjectID]
	),

	CONSTRAINT [FK_EmployeeTime_Task] FOREIGN KEY 
	(
		[TaskID]
	) REFERENCES dbo.[ProjectTask] (
		[TaskID]
	),

	CONSTRAINT [FK_EmployeeTime_Type] FOREIGN KEY (TypeID) REFERENCES dbo.TimeType(TypeID)

	COMMIT TRAN
END
GO
IF OBJECT_id('EmployeeTimeOld') IS NOT NULL AND OBJECT_id('dbo.EmployeeTimeOld') IS NULL
EXEC dbo.sp_changeobjectowner 'EmployeeTimeOld', 'dbo'
GO
IF OBJECT_id('dbo.EmployeeTimeOld') IS NOT NULL
BEGIN

BEGIN TRAN

SET IDENTITY_INSERT dbo.EmployeeTime ON

INSERT EmployeeTime(ItemID, EmployeeID, [In], Seconds, TypeID, StatusID, [Pay Rate])
SELECT T.ItemID, T.EmployeeID, T.[In], CASE WHEN T.[Out] IS NULL THEN 0 ELSE DATEDIFF(s, T.[In], T.[Out]) END, 1, 1,
ISNULL((3600.0/P.Seconds) * C.[Base Pay], 0)
FROM EmployeeTimeOld T
LEFT JOIN EmployeeCompensation C ON T.EmployeeID = C.EmployeeID AND 
(
	(C.[Stop Day past 1900] IS NULL AND C.[Start Day past 1900] <= DATEDIFF(d, 0, T.[In])) OR
	(DATEDIFF(d, 0, [In]) BETWEEN C.[Start Day past 1900] AND C.[Stop Day past 1900])
)
LEFT JOIN Period P ON C.PeriodID = P.PeriodID

SET IDENTITY_INSERT dbo.EmployeeTime OFF

DROP TABLE dbo.EmployeeTimeOld

COMMIT TRAN

END
GO

IF NOT EXISTS(SELECT * FROM sysindexes WHERE name='IX_EmployeeTime_EmployeeID')
CREATE  INDEX [IX_EmployeeTime_EmployeeID] ON dbo.[EmployeeTime]([EmployeeID]) WITH  FILLFACTOR = 90 ON [PRIMARY]

IF NOT EXISTS(SELECT * FROM sysindexes WHERE name='IX_EmployeeTime_EmployeeID_TypeID')
CREATE  INDEX [IX_EmployeeTime_EmployeeID_TypeID] ON dbo.[EmployeeTime]([EmployeeID], [TypeID]) WITH  FILLFACTOR = 90 ON [PRIMARY]

IF NOT EXISTS(SELECT * FROM sysindexes WHERE name='IX_EmployeeTime_In')
CREATE  INDEX [IX_EmployeeTime_In] ON dbo.[EmployeeTime]([In]) WITH  FILLFACTOR = 90 ON [PRIMARY]

GO
IF OBJECT_id('dbo.vwLeaveNote') IS NOT NULL DROP VIEW dbo.vwLeaveNote
IF OBJECT_id('dbo.spLeaveNoteSelect') IS NOT NULL DROP PROC dbo.spLeaveNoteSelect
IF OBJECT_id('dbo.spLeaveNoteInsert') IS NOT NULL DROP PROC dbo.spLeaveNoteInsert
IF OBJECT_id('dbo.spLeaveNoteUpdate') IS NOT NULL DROP PROC dbo.spLeaveNoteUpdate
IF OBJECT_id('dbo.spLeaveNoteDelete') IS NOT NULL DROP PROC dbo.spLeaveNoteDelete
IF OBJECT_id('dbo.spLeaveNoteList') IS NOT NULL DROP PROC dbo.spLeaveNoteList
IF OBJECT_id('dbo.spLeaveNoteListJurisdictions') IS NOT NULL DROP PROC dbo.spLeaveNoteListJurisdictions
IF OBJECT_id('dbo.spConstantSelectTimePolicy') IS NOT NULL DROP PROC dbo.spConstantSelectTimePolicy
IF OBJECT_id('dbo.spConstantUpdateTimePolicy') IS NOT NULL DROP PROC dbo.spConstantUpdateTimePolicy
IF OBJECT_id('CK_Employee_OT_Basis') IS NOT NULL ALTER TABLE dbo.Employee DROP CONSTRAINT CK_Employee_OT_Basis
IF OBJECT_id('dbo.spTrainingGetTrainingFromTrainingID') IS NOT NULL DROP PROC dbo.spTrainingGetTrainingFromTrainingID
IF OBJECT_id('dbo.spRaceGetRaceFromRaceID') IS NOT NULL DROP PROC dbo.spRaceGetRaceFromRaceID
IF OBJECT_id('dbo.spEmployeeClassifyPrepare') IS NOT NULL DROP PROC dbo.spEmployeeClassifyPrepare
IF OBJECT_id('dbo.spEmployeeExists') IS NOT NULL DROP PROC dbo.spEmployeeExists
IF OBJECT_id('dbo.spEmployeeProjectDelete') IS NOT NULL DROP PROC dbo.spEmployeeProjectDelete
IF OBJECT_id('dbo.spEmployeeProjectList') IS NOT NULL DROP PROC dbo.spEmployeeProjectList
IF OBJECT_id('spUsedLeaveCountIncidents') IS NOT NULL DROP PROC spUsedLeaveCountIncidents
IF OBJECT_id('dbo.vwProject') IS NOT NULL DROP VIEW dbo.vwProject
IF OBJECT_id('dbo.vwTimeSchema') IS NOT NULL DROP VIEW dbo.vwTimeSchema
IF OBJECT_id('dbo.spEmployeeTimeStatusList') IS NOT NULL DROP PROC dbo.spEmployeeTimeStatusList
IF OBJECT_id('dbo.spTimeSchemaSelect') IS NOT NULL DROP PROC dbo.spTimeSchemaSelect
IF OBJECT_id('dbo.spTimeSchemaSelectDefault') IS NOT NULL DROP PROC dbo.spTimeSchemaSelectDefault
IF OBJECT_id('dbo.spTimeSchemaList') IS NOT NULL DROP PROC dbo.spTimeSchemaList
IF OBJECT_id('dbo.spTimeSchemaInsert') IS NOT NULL DROP PROC dbo.spTimeSchemaInsert
IF OBJECT_id('dbo.spTimeSchemaUpdate') IS NOT NULL DROP PROC dbo.spTimeSchemaUpdate
IF OBJECT_id('dbo.spEmployeeTimeListHolidayCredits') IS NOT NULL DROP PROC dbo.spEmployeeTimeListHolidayCredits
IF OBJECT_id('dbo.spEmployeeGetTimeSchemaID') IS NOT NULL DROP PROC dbo.spEmployeeGetTimeSchemaID
IF OBJECT_id('dbo.spEmployeeUpdateTimeSchemaID') IS NOT NULL DROP PROC dbo.spEmployeeUpdateTimeSchemaID
IF OBJECT_id('dbo.spTimeSchemaValidateSchemaID') IS NOT NULL DROP PROC dbo.spTimeSchemaValidateSchemaID
IF OBJECT_id('dbo.spTimeSchemaSetDefault') IS NOT NULL DROP PROC dbo.spTimeSchemaSetDefault
IF OBJECT_id('dbo.spTimeSchemaGetDefault') IS NOT NULL DROP PROC dbo.spTimeSchemaGetDefault
IF OBJECT_id('dbo.spEmployeeBillingRateUpdate') IS NOT NULL DROP PROC dbo.spEmployeeBillingRateUpdate
IF OBJECT_id('dbo.spEmployeeBillingRateGet') IS NOT NULL DROP PROC dbo.spEmployeeBillingRateGet
IF OBJECT_id('dbo.vwProjectClass') IS NOT NULL DROP VIEW dbo.vwProjectClass
IF OBJECT_id('dbo.spProjectClassSelect') IS NOT NULL DROP PROC dbo.spProjectClassSelect
IF OBJECT_id('dbo.spProjectClassInsert') IS NOT NULL DROP PROC dbo.spProjectClassInsert
IF OBJECT_id('dbo.spProjectClassUpdate') IS NOT NULL DROP PROC dbo.spProjectClassUpdate
IF OBJECT_id('dbo.spProjectClassDelete') IS NOT NULL DROP PROC dbo.spProjectClassDelete
IF OBJECT_id('dbo.spProjectClassList') IS NOT NULL DROP PROC dbo.spProjectClassList
IF OBJECT_id('dbo.spEmployeeUpdatePayStep2') IS NOT NULL DROP PROC dbo.spEmployeeUpdatePayStep2
IF OBJECT_id('dbo.spPeriodGetPayrollPeriodNumber') IS NOT NULL DROP PROC dbo.spPeriodGetPayrollPeriodNumber
IF OBJECT_id('dbo.GetFirstPayroll') IS NOT NULL DROP FUNCTION dbo.GetFirstPayroll
GO
CREATE VIEW dbo.vwProject AS 
SELECT 
ProjectID=0,Project='',ProjectManagerID=NULL,LocationID=0,Active=CAST(0 AS bit),[Pay Rate]=CAST(0 AS money),[Billing Rate]=CAST(0 as money),Note='',ClassID=0,[Fixed Pay]=CAST(0 as money),[Fixed Billing]=CAST(0 AS money),[Number]='',[Order]=0,DefaultTimeTypeID=NULL
, [Project Manager] = '', Location = '', [Class] = '', [Default Time Type] = ''
GO
CREATE VIEW dbo.vwTimeSchema AS SELECT * FROM TimeSchema
GO
CREATE PROC dbo.spTimeSchemaSelect
	@schema_id int
AS
SET NOCOUNT ON
SELECT * FROM vwTimeSchema WHERE TimeSchemaID = @schema_id
GO
CREATE PROC dbo.spTimeSchemaSelectDefault
AS
SET NOCOUNT ON
SELECT S.* FROM vwTimeSchema S
INNER JOIN Constant C ON S.TimeSchemaID = C.DefaultTimeSchemaID
GO
CREATE PROC dbo.spTimeSchemaList
AS
SET NOCOUNT ON
SELECT * FROM vwTimeSchema ORDER BY [Schema]
GO
CREATE PROC dbo.spTimeSchemaUpdate
	@schema_id int,
	@schema varchar(50),
	@column_mask int
AS
UPDATE TimeSchema SET [Schema] = @schema, [Column Mask] = @column_mask WHERE TimeSchemaID = @schema_id
GO
CREATE PROC dbo.spTimeSchemaInsert
	@schema varchar(50),
	@column_mask int,
	@schema_id int OUT
AS
INSERT TimeSchema([Schema], [Column Mask])
VALUES(@schema, @column_mask)

SET @schema_id = SCOPE_IDENTITY()
GO
CREATE PROC dbo.spEmployeeTimeStatusList
AS
SET NOCOUNT ON
SELECT StatusID, Status FROM EmployeeTimeStatus ORDER BY [Order]
GO
ALTER PROC dbo.spFilterList
	@type_id int = 1
AS
SET NOCOUNT ON
SELECT Filter, FilterID FROM Filter WHERE TypeID = @type_id ORDER BY Filter

GO
ALTER PROC dbo.spFilterInsert
	@filter varchar(50),
	@active bit,
	@stream image,
	@type_id int = 1,
	@filter_id int OUT
AS
INSERT Filter(Filter, Active, Stream, TypeID)
VALUES (@filter, @active, @stream, @type_id)

SET @filter_id = SCOPE_IDENTITY()
GO
CREATE PROC dbo.spTrainingGetTrainingFromTrainingID
	@training varchar(50) OUT,
	@training_id int
AS
SET @training = ''
SELECT @training = Training FROM Training WHERE TrainingID = @training_id
GO
CREATE PROC dbo.spRaceGetRaceFromRaceID
	@race varchar(50) OUT,
	@race_id int
AS
SET @race = ''
SELECT @race = Race FROM Race WHERE RaceID = @race_id
GO
CREATE PROCEDURE dbo.spEmployeeExists
	@employee_id int,
	@exists bit OUT
AS
SET NOCOUNT ON

SELECT @exists = 0
SELECT @exists = 1 FROM Employee WHERE EmployeeID = @employee_id
GO
CREATE PROC dbo.spEmployeeGetTimeSchemaID
	@employee_id int,
	@schema_id int OUT
AS
SELECT @schema_id = TimeSchemaID FROM Employee WHERE EmployeeID = @employee_id
GO
CREATE PROC dbo.spEmployeeUpdateTimeSchemaID
	@employee_id int,
	@schema_id int
AS
DECLARE @authorized bit
EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 10008, 2, @authorized out
IF @authorized = 1 UPDATE Employee SET TimeSchemaID = @schema_id WHERE EmployeeID = @employee_id
GO
CREATE PROC dbo.spTimeSchemaValidateSchemaID
	@schema_id int out
AS
IF NOT EXISTS(SELECT * FROM TimeSchema WHERE TimeSchemaID = @schema_id)
SELECT @schema_id = DefaultTimeSchemaID FROM dbo.Constant
GO
CREATE PROC dbo.spTimeSchemaGetDefault
	@schema_id int out
AS
SELECT @schema_id = DefaultTimeSchemaID FROM dbo.Constant
GO
CREATE PROC dbo.spTimeSchemaSetDefault
	@schema_id int out
AS
UPDATE Constant SET DefaultTimeSchemaID = @schema_id
GO
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [id]=OBJECT_id('Project') AND [name]='Fixed Pay')
ALTER TABLE Project ADD [Fixed Pay] [smallmoney] NULL

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [id]=OBJECT_id('Project') AND [name]='Fixed Billing')
ALTER TABLE Project ADD [Fixed Billing] [smallmoney] NULL
GO
IF OBJECT_id('dbo.vwEmployeeProject') IS NULL EXEC sp_executesql N'CREATE VIEW dbo.vwEmployeeProject AS SELECT A=0'
GO
ALTER VIEW dbo.vwEmployeeProject
AS
SELECT 
ItemID=0,
EmployeeID=0,
ProjectID=0,
[Billing Rate]=CAST(0 as smallmoney),
[Pay Rate]=CAST(0 as smallmoney),
[Start Day past 1900]=0,
[Stop Day past 1900]=0,
[Percent of Time Allocated]=0,
Comment='',
[Fixed Pay]=CAST(0 as smallmoney),
[Fixed Billing]=CAST(0 as smallmoney),
Flags=0, 
Employee = '',
Project='',
ProjectManagerID=0,
Active=CAST(0 as bit),
Start = DATEADD(d,0,0),
Stop = DATEADD(d,0,0),
[Inherited Billing Rate] = CAST(0 as smallmoney),
[Inherited Fixed Billing] = CAST(0 as smallmoney),
[Inherited Pay Rate] = CAST(0 as smallmoney),
[Inherited Fixed Pay] = CAST(0 as smallmoney),
IsDefined = CAST(0 as bit)
GO
CREATE PROC dbo.spEmployeeProjectList
	@batch_id int,
	@project_id int,
			
	@open_as_of int,
	@closed_between_min int,
	@closed_between_max int,
	
	@project_manager_id_not_null bit,
	@project_manager_id int,

	@percent_min int,
	@percent_max int,

	@pay_rate_not_null bit,
	@pay_rate_min smallmoney,
	@pay_rate_max smallmoney,

	@billing_rate_not_null bit,
	@billing_rate_min smallmoney,
	@billing_rate_max smallmoney,

	@inherited_pay_rate_min smallmoney,
	@inherited_pay_rate_max smallmoney,

	@inherited_billing_rate_min smallmoney,
	@inherited_billing_rate_max smallmoney,

	@authorized bit out
AS
SET NOCOUNT ON

EXEC dbo.spPermissionGetOnPeopleForCurrentUser2 @batch_id, 262144

DELETE TempX WHERE BatchID = @batch_id AND (X & 1) = 0
SELECT @authorized = CASE WHEN @@ROWCOUNT = 0 THEN 1 ELSE 0 END

SELECT P.* FROM vwEmployeeProject P
INNER JOIN TempX X ON X.BatchID = @batch_id AND X.[ID] = P.EmployeeID AND
(@project_id IS NULL OR ProjectID = @project_id) AND
(@open_as_of IS NULL OR ([Stop Day past 1900] IS NULL AND [Start Day past 1900] < @open_as_of) OR @open_as_of BETWEEN [Start Day past 1900] AND [Stop Day past 1900]) AND
(@closed_between_min IS NULL OR [Stop Day past 1900] BETWEEN @closed_between_min AND @closed_between_max) AND
(@project_manager_id_not_null IS NULL OR 
	(@project_manager_id_not_null = 0 AND ProjectManagerID IS NULL) OR 
	(@project_manager_id_not_null = 1 AND @project_manager_id IS NULL AND ProjectManagerID IS NOT NULL) OR
	(@project_manager_id_not_null = 1 AND ProjectManagerID = @project_manager_id)
) AND
([Percent of Time Allocated] BETWEEN @percent_min AND @percent_max) AND
(@pay_rate_not_null IS NULL OR
	(@pay_rate_not_null = 0 AND [Pay Rate] IS NULL) OR
	(@pay_rate_not_null = 1 AND @pay_rate_min IS NULL AND [Pay Rate] IS NOT NULL) OR
	(@pay_rate_not_null = 1 AND [Pay Rate] BETWEEN @pay_rate_min AND @pay_rate_max)
) AND
(@billing_rate_not_null IS NULL OR
	(@billing_rate_not_null = 0 AND [Billing Rate] IS NULL) OR
	(@billing_rate_not_null = 1 AND @billing_rate_min IS NULL AND [Billing Rate] IS NOT NULL) OR
	(@billing_rate_not_null = 1 AND [Billing Rate] BETWEEN @billing_rate_min AND @billing_rate_max)
) AND
([Inherited Pay Rate] BETWEEN @inherited_pay_rate_min AND @inherited_pay_rate_max) AND
([Inherited Billing Rate] BETWEEN @inherited_billing_rate_min AND @inherited_billing_rate_max)

ORDER BY Employee, Active DESC, Project

DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1
GO
CREATE PROC dbo.spEmployeeProjectDelete
	@item_id int
AS
DECLARE @authorized bit, @employee_id int
SELECT @employee_id = EmployeeID FROM EmployeeProject WHERE ItemID = @item_id
EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 262144, 8, @authorized out

IF @authorized=1
DELETE EmployeeProject WHERE ItemID = @item_id
GO
CREATE PROC dbo.spEmployeeBillingRateUpdate
	@employee_id int,
	@billing_rate smallmoney
AS
DECLARE @authorized bit
EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 262144, 2, @authorized out

UPDATE Employee SET [Billing Rate] = @billing_rate WHERE EmployeeID = @employee_id
GO
CREATE PROC dbo.spEmployeeBillingRateGet
	@employee_id int,
	@billing_rate smallmoney out
AS
DECLARE @authorized bit
EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 262144, 1, @authorized out

SELECT @billing_rate = 0
SELECT @billing_rate = [Billing Rate] FROM Employee WHERE EmployeeID = @employee_id
GO
CREATE VIEW dbo.vwProjectClass AS SELECT * FROM ProjectClass
GO
CREATE PROC dbo.spProjectClassSelect
	@class_id int
AS
SET NOCOUNT ON
SELECT * FROM vwProjectClass WHERE ClassID = @class_id
GO
CREATE PROC dbo.spProjectClassInsert
	@class varchar(50),
	@class_id int out
AS
INSERT ProjectClass(Class)
VALUES(@class)
SELECT @class_id = SCOPE_IDENTITY()
GO
CREATE PROC dbo.spProjectClassUpdate
	@class varchar(50),
	@class_id int
AS
UPDATE ProjectClass SET Class = @class WHERE ClassID = @class_id
GO
CREATE PROC dbo.spProjectClassDelete
	@class_id int
AS
IF EXISTS(SELECT * FROM ProjectClass WHERE ClassID != @class_id)
DELETE ProjectClass WHERE ClassID = @class_id
ELSE EXEC dbo.spErrorRaise 50047
GO
CREATE PROC dbo.spProjectClassList
AS
SELECT * FROM vwProjectClass ORDER BY [Class]
GO
CREATE PROC dbo.spPeriodGetPayrollPeriodNumber
	@start_date datetime,
	@payroll_period int out,
	@basis datetime out
AS
SELECT @basis = dbo.GetFirstPayroll()
SELECT @payroll_period = dbo.GetPayrollPeriodNumber(@start_date)
GO
ALTER PROC dbo.spEmployeeUpdatePayStep
	@employee_id int,
	@filing_status_id int,
	@salaried bit,
	@ot_basis tinyint,
	@fit_exemptions int,
	@ot_pay_multiplier numeric(9,4),
	@holiday_pay_multiplier numeric(9,4),
	@weekend_pay_multiplier numeric(9,4)
AS
EXEC dbo.spErrorRaise 50046
GO
CREATE PROC dbo.spEmployeeUpdatePayStep2
	@employee_id int,
	@filing_status_id int,
	@salaried bit,
	@ot_basis tinyint,
	@fit_exemptions int,
	@default_time_type_id int,
	@direct_deposit_account_number varchar(50),
	@payroll_delay int
AS
DECLARE @authorized bit

SET NOCOUNT ON

EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 0x40, 2, @authorized out
IF @authorized = 1 UPDATE Employee SET 
	FilingStatusID = @filing_status_id,
	Salaried = @salaried,
	[OT Basis] = @ot_basis,
	[Direct Deposit Account Number] = @direct_deposit_account_number,
	[FIT Exemptions] = @fit_exemptions,
	[Payroll Delay] = @payroll_delay
WHERE EmployeeID = @employee_id
GO
ALTER PROCEDURE dbo.spLeaveTypeSelect
	@type_id int
AS
SET NOCOUNT ON

SELECT * FROM vwLeaveType WHERE TypeID = @type_id
GO
ALTER PROC dbo.spLeaveTypeSelectPrimary
AS
SET NOCOUNT ON

DECLARE @type_id int

SET @type_id = NULL

SELECT TOP 1 @type_id = TypeID FROM LeaveType T
WHERE TypeID IN
(
	SELECT DISTINCT TypeID FROM LeaveRate
)
ORDER BY T.[Order]

IF @type_id IS NULL SELECT TOP 1 @type_id = TypeID FROM LeaveType WHERE Advanced = 1 ORDER BY [Order]
IF @type_id IS NULL SELECT TOP 1 @type_id = TypeID FROM LeaveType ORDER BY [Order]

SELECT * FROM vwLeaveType WHERE TypeID = @type_id
GO
-- Will throw error if insufficient typeids available
ALTER PROC dbo.spLeaveTypeAddStateFML
	@state_id int
AS
SET NOCOUNT ON

DECLARE @next_type_id int, @next_order int, @error int
SELECT @next_type_id = ISNULL(MAX(TypeID) * 2, 1) FROM LeaveType
SELECT @next_order = ISNULL(MAX([Order]) + 1, 1) FROM LeaveType

BEGIN TRAN

INSERT LeaveType(TypeID, Advanced, [Type], Abbreviation, Paid, [Order], InitialPeriodID, [Initial Seconds])
SELECT TypeID * @next_type_id , 1, [Type], UPPER(SUBSTRING([Type], 1, 4)), 0, [Order] + @next_order, PeriodID, Seconds FROM StateFMLType WHERE StateID = @state_id
SELECT @error = @@ERROR

IF @error = 0
BEGIN
	INSERT LeaveRate(PlanID, TypeID, Seconds, [Start Month], [Stop Month], PeriodID)
	SELECT P.PlanID, F.TypeID * @next_type_id, F.Seconds * P.FTE, 0, 0x7FFFFFFF, F.PeriodID
	FROM StateFMLType F
	CROSS JOIN LeavePlan P
	WHERE F.StateID = @state_id
	SELECT @error = @@ERROR
END

IF @error = 0
BEGIN
	
	DECLARE @ptrSrc binary(16), @ptrTarget binary(16)

	SELECT @ptrSrc = TEXTPTR([Leave Note]) FROM StateFML WHERE StateID = @state_id
	SELECT @ptrTarget = TEXTPTR([Leave Note]) FROM dbo.Constant
	
	DECLARE @nl varchar(2000)
	SELECT @nl = CHAR(13) + CHAR(10) + '===========================================' + CHAR(13) + CHAR(10) +
		'DISCLAIMER: The accuracy of the documentation that Apex Software provides about federal and state law is deemed reliable but not guaranteed. Apex recommends that you thoroughly understand how this software will credit and debit leave before you incorporate it into your family and medical leave procedures and that you consult a specialist in family and medical law. You may need to modify the leave accrual plans in this software, changing the types and amounts of automatically credited family leave. Apex assumes no liability for damages sought regarding tracking, accruing, approving, or denying leave. By using this software, you and/or your employer accept full responsibility and liability.' + CHAR(13) + CHAR(10) +
		'===========================================' + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10)
	UPDATETEXT Constant.[Leave Note] @ptrTarget NULL NULL @nl
	SELECT @error = @@ERROR

	IF @error = 0
	BEGIN
		UPDATETEXT Constant.[Leave Note] @ptrTarget NULL NULL StateFML.[Leave Note] @ptrSrc
		SELECT @error = @@ERROR
	END
END

IF @error = 0 COMMIT TRAN
ELSE IF @@ROWCOUNT > 0 ROLLBACK
GO
CREATE PROC dbo.spConstantUpdateTimePolicy
	@ot_time_type_id int,
	@weekend_time_type_id int,
	@holiday_time_type_id int
AS
UPDATE Constant SET OTTimeTypeID = @ot_time_type_id,
WeekendTimeTypeID = @weekend_time_type_id,
HolidayTimeTypeID = @holiday_time_type_id
GO
CREATE PROC dbo.spConstantSelectTimePolicy
AS
SET NOCOUNT ON
SELECT OTTimeTypeID, WeekendTimeTypeID, HolidayTimeTypeID FROM dbo.Constant
GO
CREATE FUNCTION dbo.GetFirstPayroll()
RETURNS datetime
BEGIN
	DECLARE @wk0 datetime -- first Jan 1 after 1900 that falls on the first day of the week
	SELECT @wk0 = '19101231'

	DECLARE @payroll_period_id int, @week_day int
	SELECT @payroll_period_id = CurrentPayrollPeriodID FROM dbo.Constant

	SELECT @week_day = [WeekDay] FROM LeaveRatePeriod WHERE PeriodID = @payroll_period_id
	SELECT @wk0 = DATEADD(d, @week_day, @wk0)

	RETURN @wk0
END
GO
CREATE VIEW dbo.vwLeaveNote AS SELECT * FROM LeaveNote
GO
CREATE PROC dbo.spLeaveNoteSelect
	@note_id int
AS
SET NOCOUNT ON
SELECT * FROM vwLeaveNote WHERE NoteID = @note_id
GO
CREATE PROC dbo.spLeaveNoteListJurisdictions
AS
SET NOCOUNT ON
SELECT NoteID, Jurisdiction FROM LeaveNote ORDER BY Jurisdiction
GO
CREATE PROC dbo.spLeaveNoteList
AS
SET NOCOUNT ON
SELECT * FROM vwLeaveNote ORDER BY Jurisdiction
GO
CREATE PROC dbo.spLeaveNoteInsert
	@jurisdiction varchar(50),
	@note text,
	@note_id int OUT
AS
INSERT LeaveNote(Jurisdiction, Note)
VALUES(@jurisdiction, @note)
SET @note_id = SCOPE_IDENTITY()
GO
CREATE PROC dbo.spLeaveNoteDelete
	@note_id int
AS
IF EXISTS(SELECT * FROM LeaveNote WHERE NoteID != @note_id) 
DELETE LeaveNote WHERE NoteID = @note_id
ELSE EXEC dbo.spErrorRaise 50048
GO
CREATE PROC dbo.spLeaveNoteUpdate
	@jurisdiction varchar(50),
	@note_id int,
	@note text
AS
UPDATE LeaveNote SET Jurisdiction = @jurisdiction, Note = @note WHERE NoteID = @note_id
GO
GRANT EXEC ON dbo.spConstantSelectTimePolicy TO public
GRANT EXEC ON dbo.GetFirstPayroll TO public
GRANT EXEC ON dbo.spPeriodGetPayrollPeriodNumber TO public
GRANT EXEC ON dbo.spTrainingGetTrainingFromTrainingID TO public
GRANT EXEC ON dbo.spRaceGetRaceFromRaceID TO public
GRANT EXEC ON dbo.spEmployeeTimeStatusList TO public
GRANT EXEC ON dbo.spEmployeeExists TO public
GRANT EXEC ON dbo.spTimeSchemaSelectDefault TO public
GRANT EXEC ON dbo.spTimeSchemaSelect TO public
GRANT EXEC ON dbo.spEmployeeGetTimeSchemaID TO public
GRANT EXEC ON dbo.spEmployeeUpdateTimeSchemaID TO public
GRANT EXEC ON dbo.spTimeSchemaValidateSchemaID TO public
GRANT EXEC ON dbo.spTimeSchemaGetDefault TO public
GRANT EXEC ON dbo.spEmployeeProjectList TO public
GRANT EXEC ON dbo.spEmployeeProjectDelete TO public
GRANT EXEC ON dbo.spEmployeeBillingRateUpdate TO public
GRANT EXEC ON dbo.spEmployeeBillingRateGet TO public
GRANT EXEC ON dbo.spProjectClassList TO public
GRANT EXEC ON dbo.spProjectClassSelect TO public
GRANT EXEC ON dbo.spEmployeeUpdatePayStep2 TO public
GRANT EXEC ON dbo.spLeaveNoteSelect TO public
GRANT EXEC ON dbo.spLeaveNoteList TO public
GRANT EXEC ON dbo.spLeaveNoteListJurisdictions TO public
GO
UPDATE Constant SET [Server Version] = 38
GO
GRANT EXEC ON dbo.spTimeSchemaList TO public
GO
ALTER PROC dbo.spBackup
	@file varchar(128)
AS
DECLARE @db sysname
DECLARE @t nvarchar(512)

SELECT @db = DB_NAME(), @t = 'BACKUP DATABASE @db TO DISK = @file WITH INIT, SKIP'
EXEC sp_executesql @t, N'@db sysname, @file varchar(128)', @db, @file
GO
ALTER TABLE dbo.LeaveType ALTER COLUMN Abbreviation varchar(50) NOT NULL

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [name] = 'Bank' AND [ID] = OBJECT_id('dbo.LeaveType'))
BEGIN

BEGIN TRAN

ALTER TABLE dbo.LeaveType ADD Bank bit NOT NULL DEFAULT 1

EXEC sp_executesql
N'UPDATE LeaveType SET Bank = 0 FROM LeaveType V WHERE Type IN (''Paid Leave'', ''Unpaid Leave'')'

COMMIT TRAN

END
GO
IF OBJECT_id('dbo.spLeaveTypeListAffected') IS NOT NULL DROP PROC dbo.spLeaveTypeListAffected
GO
CREATE PROC dbo.spLeaveTypeListAffected
	@type_id int
AS
SET NOCOUNT ON

SELECT [List As], PersonID FROM dbo.vwPersonListAs WHERE PersonID IN
(
	SELECT DISTINCT EmployeeID FROM dbo.vwEmployeeLeaveApproved
) ORDER BY [List As]
GO
GRANT EXEC ON dbo.spLeaveTypeListAffected TO public
GO

GO
-- UPDATE Constant SET [Server Version] = 42





IF OBJECT_id('FK_EmployeeTime_Employee') IS NOT NULL ALTER TABLE dbo.EmployeeTime DROP CONSTRAINT FK_EmployeeTime_Employee

ALTER TABLE dbo.[EmployeeTime] ADD 
	CONSTRAINT [FK_EmployeeTime_Employee] FOREIGN KEY 
	(
		[EmployeeID]
	) REFERENCES dbo.[Employee] (
		[EmployeeID]
	) ON DELETE CASCADE
GO
IF OBJECT_id('dbo.spConstantBeginServerUpdate') IS NOT NULL DROP PROC dbo.spConstantBeginServerUpdate
IF OBJECT_id('dbo.spConstantEndServerUpdate') IS NOT NULL DROP PROC dbo.spConstantEndServerUpdate
IF OBJECT_id('dbo.spConstantIsServerUpdating') IS NOT NULL DROP PROC dbo.spConstantIsServerUpdating
GO
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [name] = 'Server Update Began' AND [ID] = OBJECT_id('dbo.Constant'))
ALTER TABLE dbo.Constant ADD [Server Update Began] smalldatetime NULL
GO
CREATE PROC dbo.spConstantBeginServerUpdate
AS
UPDATE Constant SET [Server Update Began] = GETDATE()
GO
CREATE PROC dbo.spConstantEndServerUpdate
AS
UPDATE Constant SET [Server Update Began] = NULL
GO
CREATE PROC dbo.spConstantIsServerUpdating
	@updating bit OUT
AS
DECLARE @began smalldatetime

SELECT @began = [Server Update Began] FROM dbo.Constant
IF @began IS NULL OR DATEDIFF(mi, @began, GETDATE()) > 5 SET @updating = 0 -- If more than 5 mins passed then update should be done
ELSE SET @updating = 1
GO
GRANT EXEC ON dbo.spConstantBeginServerUpdate TO public
GRANT EXEC ON dbo.spConstantEndServerUpdate TO public
GRANT EXEC ON dbo.spConstantIsServerUpdating TO public
GO

UPDATE Constant SET [Server Version] = 43

GO
IF OBJECT_id('dbo.spTimeTypeGetFirst') IS NOT NULL DROP PROC dbo.spTimeTypeGetFirst
GO
CREATE PROC dbo.spTimeTypeGetFirst
	@type_id int out
AS
SELECT TOP 1 @type_id = TypeID FROM TimeType ORDER BY [Order]
GO
GRANT EXEC ON dbo.spTimeTypeGetFirst TO public
GO
ALTER PROC dbo.spEmployeeLeaveGetUsed
	@employee_id int,
	@type_id int,
	@day int,
	@seconds int out
AS
DECLARE @authorized bit
SET NOCOUNT ON

EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 10003, 1, @authorized out

SET @seconds = 0
IF @authorized = 1
BEGIN
	SELECT @seconds = ISNULL(SUM(Seconds), 0) FROM vwEmployeeLeaveUsedItemApproved WHERE ([Extended Type Mask] & @type_id) != 0 AND EmployeeID = @employee_id AND [Day past 1900] >= @day 
END
GO
IF OBJECT_id('IX_Person_FirstNameMiddleLastSuffixMustBeUnique') IS NOT NULL
ALTER TABLE Person DROP CONSTRAINT IX_Person_FirstNameMiddleLastSuffixMustBeUnique
GO
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID] = OBJECT_id('dbo.Constant') AND [name] = 'BenefitPremiumPeriodID')
ALTER TABLE dbo.Constant ADD BenefitPremiumPeriodID int NULL
GO
IF OBJECT_id('FK_Constant_BenefitPremiumPeriod') IS NULL
BEGIN
	BEGIN TRAN

	UPDATE Constant SET BenefitPremiumPeriodID = CurrentPayrollPeriodID & 2047
	ALTER TABLE dbo.Constant ALTER COLUMN BenefitPremiumPeriodID int NOT NULL

	ALTER TABLE dbo.Constant ADD CONSTRAINT [FK_Constant_BenefitPremiumPeriod] FOREIGN KEY 
	(
		[BenefitPremiumPeriodID]
	) REFERENCES [Period] (
		[PeriodID]
	) 

	COMMIT TRAN
END
GO
DECLARE @default sysname, @t nvarchar(400)

UPDATE dbo.EmployeeTime SET [Pay Rate]=0 WHERE [Pay Rate] IS NULL
SELECT @default = [name] FROM sysobjects WHERE [parent_obj] = OBJECT_id('EmployeeTime') AND status=6 AND [info] = 10
IF @@ROWCOUNT = 1
BEGIN
	SELECT @t = N'ALTER TABLE dbo.EmployeeTime DROP CONSTRAINT [' + @default + ']'
	EXEC sp_executesql @t
	ALTER TABLE dbo.EmployeeTime ALTER COLUMN [Pay Rate] smallmoney NOT NULL
END

GO
DECLARE @default sysname, @t nvarchar(400)

UPDATE dbo.EmployeeTime SET [Billing Rate]=0 WHERE [Billing Rate] IS NULL
SELECT @default = [name] FROM sysobjects WHERE [parent_obj] = OBJECT_id('EmployeeTime') AND status=6 AND [info] = 11
IF @@ROWCOUNT = 1
BEGIN
	SELECT @t = N'ALTER TABLE dbo.EmployeeTime DROP CONSTRAINT [' + @default + ']'
	EXEC sp_executesql @t
	ALTER TABLE dbo.EmployeeTime ALTER COLUMN [Billing Rate] smallmoney NOT NULL
END

GO
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID] = OBJECT_id('EmployeeTime') AND [name]='Fixed Billing')
ALTER TABLE dbo.EmployeeTime ADD [Fixed Billing] smallmoney NOT NULL DEFAULT(0), [Fixed Pay] smallmoney NOT NULL DEFAULT(0)
GO
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID]=OBJECT_id('Project') AND [name]='Fixed Pay')
ALTER TABLE dbo.Project ADD [Fixed Pay] [smallmoney] NULL

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID]=OBJECT_id('Project') AND [name]='Fixed Billing')
ALTER TABLE dbo.Project ADD [Fixed Billing] [smallmoney] NULL

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID]=OBJECT_id('EmployeeProject') AND [name]='Fixed Pay')
ALTER TABLE dbo.EmployeeProject ADD [Fixed Pay] [smallmoney] NULL

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID]=OBJECT_id('EmployeeProject') AND [name]='Fixed Billing')
ALTER TABLE dbo.EmployeeProject ADD [Fixed Billing] [smallmoney] NULL
GO
ALTER PROC dbo.spEmployeeTimeListCreditsForHourlyEmployees
	@day int
AS
DECLARE @date datetime

SET NOCOUNT ON

SELECT @date = dbo.GetDateFromDaysPast1900(@day)

SELECT E.EmployeeID, HH = 9, S.[Effective Seconds per Day], TimeTypeID = E.DefaultTimeTypeID
INTO #E
FROM Employee E 
INNER JOIN vwEmployeeEffectiveSecondsPerDay S ON E.Salaried = 0 AND E.[Terminated Day past 1900] IS NULL AND E.[Active Employee] = 1 AND E.EmployeeID = S.EmployeeID
INNER JOIN dbo.vwPersonListAs P ON E.EmployeeID = P.PersonID ORDER BY P.[List As]

UPDATE #E SET HH = ISNULL((
	SELECT AVG(DATEPART(hh, DATEADD(n, 15, T.[In]))) FROM EmployeeTime T WHERE T.EmployeeID = #E.EmployeeID
), 9)

UPDATE #E SET HH = 0 WHERE 24.0 - HH < [Effective Seconds per Day] / 3600.0

SELECT #E.EmployeeID, [In] = DATEADD(hh, #E.HH, @date), [Out] = DATEADD(hh, #E.HH, DATEADD(s, #E.[Effective Seconds per Day], @date)), #E.TimeTypeID
FROM #E
GO
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID]=OBJECT_id('EmployeeTDRP') AND [name]='Employee Fixed')
ALTER TABLE dbo.EmployeeTDRP ADD [Employee Fixed] smallmoney NOT NULL DEFAULT (0)

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID]=OBJECT_id('EmployeeTDRP') AND [name]='Employer Fixed')
ALTER TABLE dbo.EmployeeTDRP ADD [Employer Fixed] smallmoney NOT NULL DEFAULT (0)

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID]=OBJECT_id('EmployeeTDRP') AND [name]='Catch Up')
ALTER TABLE dbo.EmployeeTDRP ADD [Catch Up] smallmoney NOT NULL DEFAULT (0)

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID]=OBJECT_id('EmployeeTDRP') AND [name]='Loan Repay')
ALTER TABLE dbo.EmployeeTDRP ADD [Loan Repay] smallmoney NOT NULL DEFAULT (0)
GO
ALTER PROC dbo.spEmployeeTDRPUpdate
	@tdrp_id int,
	@employee_id int,
	@eligible_day_past_1900 int,
	@expires_day_past_1900 int,
	@notified_day_past_1900 int,
	@first_enrolled_day_past_1900 int,
	@last_enrolled_day_past_1900 int,
	@declined_day_past_1900 int,
	@note varchar(4000),
	@employee_contribution numeric(9,4),
	@employer_contribution numeric(9,4),
	@employee_fixed smallmoney = 0,
	@employer_fixed smallmoney = 0,
	@catch_up smallmoney = 0,
	@loan_repay smallmoney = 0
AS
DECLARE @existed bit
DECLARE @exists bit
DECLARE @authorized bit

SET NOCOUNT ON

EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 536870912, 2, @authorized out

IF @authorized = 1 
BEGIN
	SELECT @exists = 0, @existed = 0

	SELECT @exists = 1 WHERE @eligible_day_past_1900 IS NOT NULL OR @notified_day_past_1900  IS NOT NULL
	OR @first_enrolled_day_past_1900 IS NOT NULL OR @last_enrolled_day_past_1900 IS NOT NULL OR @declined_day_past_1900 IS NOT NULL 
	OR LEN(@note) > 0 OR @employee_contribution > 0 OR @employer_contribution > 0 OR @employee_fixed > 0 OR @employer_fixed > 0 
	OR @catch_up > 0 OR @loan_repay > 0 

	SELECT @existed = 1 FROM EmployeeTDRP WHERE EmployeeID = @employee_id AND TDRPID = @tdrp_id

	IF @exists = 1 AND @existed = 0
		INSERT EmployeeTDRP(EmployeeID,TDRPID,[Eligible Day past 1900],[Notified Day past 1900],[First Enrolled Day past 1900],
		[Last Enrolled Day past 1900], [Declined Day past 1900], Note, [Employee Contribution], [Employer Contribution],
		[Loan Repay], [Catch up], [Employee Fixed], [Employer Fixed]) 
		VALUES (@employee_id,@tdrp_id,@eligible_day_past_1900,@notified_day_past_1900,@first_enrolled_day_past_1900,
		@last_enrolled_day_past_1900, @declined_day_past_1900,@note,@employee_contribution, @employer_contribution,
		@loan_repay, @catch_up, @employee_fixed, @employer_fixed)
	ELSE IF @exists = 1 AND @existed = 1
		UPDATE EmployeeTDRP SET
		TDRPID = @tdrp_id,
		[Expires Day past 1900] = @expires_day_past_1900,
		[Eligible Day past 1900] = @eligible_day_past_1900,
		[Notified Day past 1900] = @notified_day_past_1900,
		[First Enrolled Day past 1900] = @first_enrolled_day_past_1900,
		[Last Enrolled Day past 1900] = @last_enrolled_day_past_1900,
		[Declined Day past 1900] = @declined_day_past_1900,
		Note = @note,
		[Employee Contribution] = @employee_contribution,
		[Employer Contribution] = @employer_contribution,
		[Catch Up] = @catch_up,
		[Employee Fixed] = @employee_fixed,
		[Loan Repay] = @loan_repay,
		[Employer Fixed] = @employer_fixed
		WHERE EmployeeID = @employee_id AND TDRPID = @tdrp_id
	ELSE IF @existed = 1
		DELETE EmployeeTDRP WHERE EmployeeID = @employee_id AND TDRPID = @tdrp_id
END
GO
ALTER VIEW dbo.vwEmployeeTDRP
AS
SELECT T.TDRP, Employee = E.[List As],
Eligible = dbo.GetDateFromDaysPast1900([Eligible Day past 1900]),
Notified = dbo.GetDateFromDaysPast1900([Notified Day past 1900]),
Expires = dbo.GetDateFromDaysPast1900([Expires Day past 1900]),
[First Enrolled] = dbo.GetDateFromDaysPast1900([First Enrolled Day past 1900]),
[Last Enrolled] = dbo.GetDateFromDaysPast1900([Last Enrolled Day past 1900]),
Declined = dbo.GetDateFromDaysPast1900([Declined Day past 1900]),
Enrollment = CASE 
	WHEN ET.[Declined Day past 1900] IS NOT NULL THEN
		CASE WHEN ET.[First Enrolled Day past 1900] IS NULL THEN 'Declined ' ELSE 'Discontinued ' END + CAST(dbo.GetDateFromDaysPast1900(ET.[Declined Day past 1900]) AS varchar(11))
	WHEN ET.[Expires Day past 1900] IS NOT NULL THEN 'Enrolled. Expires ' + CAST(dbo.GetDateFromDaysPast1900(ET.[Expires Day past 1900]) AS varchar(11))
	WHEN ET.[Last Enrolled Day past 1900] IS NOT NULL THEN 'Enrolled ' + CAST(dbo.GetDateFromDaysPast1900(ET.[Last Enrolled Day past 1900]) AS varchar(11))
	WHEN ET.[First Enrolled Day past 1900] IS NOT NULL THEN 'Enrolled ' + CAST(dbo.GetDateFromDaysPast1900(ET.[First Enrolled Day past 1900]) AS varchar(11))
	WHEN ET.[Eligible Day past 1900] IS NOT NULL THEN 'Eligible ' + CAST(dbo.GetDateFromDaysPast1900(ET.[Eligible Day past 1900]) AS varchar(11))
	ELSE ''
END,
[Active] = CAST(CASE 
	WHEN ET.[Declined Day past 1900] IS NULL AND (ET.[First Enrolled Day past 1900]  IS NOT NULL OR ET.[Last Enrolled Day past 1900]  IS NOT NULL) THEN 1
	ELSE 0
END AS bit),
ET.* FROM EmployeeTDRP ET
INNER JOIN TDRP T ON ET.TDRPID = T.TDRPID
INNER JOIN dbo.vwPersonListAs E ON ET.EmployeeID = E.PersonID
GO
ALTER PROC dbo.spEmployeeTDRPList
	@employee_id int
AS
DECLARE @authorized bit

SET NOCOUNT ON

EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 536870912, 1, @authorized out

IF @authorized = 1
BEGIN
	DECLARE @write_permission bit, @employee varchar(400)
	EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 536870912, 2, @write_permission out

	SELECT @employee = [List As] FROM dbo.vwPersonListAs WHERE PersonID = @employee_id

	SELECT
	T.TDRPID,
	T.TDRP,
	EmployeeID = @employee_id,
	Employee = ISNULL(@employee, '<Deleted>'),
	ET.Eligible, ET.[Eligible Day past 1900],
	ET.Notified, ET.[Notified Day past 1900],
	ET.Expires, ET.[Expires Day past 1900],
	ET.[First Enrolled], ET.[First Enrolled Day past 1900],
	ET.[Last Enrolled], ET.[Last Enrolled Day past 1900],
	ET.Declined, ET.[Declined Day past 1900],
	Enrollment = ISNULL(ET.Enrollment, ''),
	[Employee Contribution] = ISNULL(ET.[Employee Contribution], 0),
	[Employer Contribution] = ISNULL(ET.[Employer Contribution], 0),
	Note = ISNULL(ET.Note, ''),
	[Catch Up] = ISNULL(ET.[Catch Up], 0), 
	[Loan Repay] = ISNULL(ET.[Loan Repay], 0), 
	[Employee Fixed] = ISNULL(ET.[Employee Fixed], 0), 
	[Employer Fixed] = ISNULL(ET.[Employer Fixed], 0),
	[Write Permission] = @write_permission 
	FROM TDRP T
	LEFT JOIN vwEmployeeTDRP ET ON ET.TDRPID = T.TDRPID AND ET.EmployeeID = @employee_id ORDER BY T.TDRP
END
GO
ALTER PROC dbo.spEmployeeTDRPSelect
	@employee_id int,
	@tdrp_id int
AS
DECLARE @authorized bit

SET NOCOUNT ON

EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 536870912, 1, @authorized out

IF @authorized = 1 
BEGIN
	DECLARE @write_permission bit, @employee varchar(400)
	EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 536870912, 2, @write_permission out

	SELECT @employee = [Full Name] FROM vwPersonCalculated WHERE PersonID = @employee_id

	SELECT
	T.TDRPID,
	T.TDRP,
	EmployeeID = @employee_id,
	Employee = @employee,
	ET.Eligible, ET.[Eligible Day past 1900],
	ET.Notified, ET.[Notified Day past 1900],
	ET.Expires, ET.[Expires Day past 1900],
	ET.[First Enrolled], ET.[First Enrolled Day past 1900],
	ET.[Last Enrolled], ET.[Last Enrolled Day past 1900],
	ET.Declined, ET.[Declined Day past 1900],
	Enrollment = ISNULL(ET.Enrollment, ''),
	[Employee Contribution] = ISNULL(ET.[Employee Contribution], 0),
	[Employer Contribution] = ISNULL(ET.[Employer Contribution], 0),
	Note = ISNULL(ET.Note, ''),
	[Catch Up] = ISNULL(ET.[Catch Up], 0), 
	[Loan Repay] = ISNULL(ET.[Loan Repay], 0), 
	[Employee Fixed] = ISNULL(ET.[Employee Fixed], 0), 
	[Employer Fixed] = ISNULL(ET.[Employer Fixed], 0),
	[Write Permission] = @write_permission 
	FROM TDRP T
	LEFT JOIN vwEmployeeTDRP ET ON ET.TDRPID = T.TDRPID AND ET.EmployeeID = @employee_id
	WHERE T.TDRPID = @tdrp_id
END
GO
ALTER PROC dbo.spEmployeeTDRPList2
	@tdrp_id int,
	@exclude_inactive bit
AS
DECLARE @batch_id int

SET NOCOUNT ON

SELECT @batch_id = RAND() * 2147483647

INSERT TempX(BatchID, [ID])
SELECT @batch_id, EmployeeID FROM Employee

EXEC dbo.spPermissionGetOnPeopleForCurrentUser2 @batch_id, 536870912

SELECT
	T.TDRPID,
	T.TDRP,
	EmployeeID = P.PersonID,
	Employee = P.[List As],
	ET.Eligible, ET.[Eligible Day past 1900],
	ET.Notified, ET.[Notified Day past 1900],
	ET.Expires, ET.[Expires Day past 1900],
	ET.[First Enrolled], ET.[First Enrolled Day past 1900],
	ET.[Last Enrolled], ET.[Last Enrolled Day past 1900],
	ET.Declined, ET.[Declined Day past 1900],
	Enrollment = ISNULL(ET.Enrollment, ''),
	[Employee Contribution] = ISNULL(ET.[Employee Contribution], 0),
	[Employer Contribution] = ISNULL(ET.[Employer Contribution], 0),
	Note = ISNULL(ET.Note, ''),
	[Catch Up] = ISNULL(ET.[Catch Up], 0), 
	[Loan Repay] = ISNULL(ET.[Loan Repay], 0), 
	[Employee Fixed] = ISNULL(ET.[Employee Fixed], 0), 
	[Employer Fixed] = ISNULL(ET.[Employer Fixed], 0),
	[Write Permission] = CAST(CASE WHEN (X & 2) = 2 THEN 1 ELSE 0 END AS bit)
	FROM dbo.vwPersonListAs P
	INNER JOIN TempX X ON X.BatchID = @batch_id AND X.[ID] = P.PersonID AND (X & 1) = 1
	CROSS JOIN TDRP T
	LEFT JOIN vwEmployeeTDRP ET ON ET.TDRPID = T.TDRPID AND ET.EmployeeID = P.PersonID
	WHERE T.TDRPID = @tdrp_id AND (ET.Active = 1 OR @exclude_inactive = 0)

DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1
GO
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID] = OBJECT_id('dbo.Constant') AND [name]='Custom')
ALTER TABLE dbo.Constant ADD [Custom] int NOT NULL DEFAULT(0)
GO
IF OBJECT_id('dbo.spCompanyGetCustom') IS NOT NULL DROP PROC dbo.spCompanyGetCustom
GO
CREATE PROC dbo.spCompanyGetCustom
	@custom int out
AS
SELECT @custom = Custom FROM dbo.Constant
GO
GRANT EXEC ON dbo.spCompanyGetCustom TO public
GO
IF OBJECT_id('dbo.spLeaveApprovalTypeSelectFirst') IS NOT NULL DROP PROC dbo.spLeaveApprovalTypeSelectFirst
GO
CREATE PROC dbo.spLeaveApprovalTypeSelectFirst
	@type_id int out
AS
SET NOCOUNT ON

SELECT @type_id = NULL
SELECT TOP 1 @type_id = TypeID FROM LeaveApprovalType
GO
GRANT EXEC ON dbo.spLeaveApprovalTypeSelectFirst TO public
GO
UPDATE Constant SET [Server Version] = 52
GO
-- Fixes nullable columns in EmployeeTime that should be nonnullable
UPDATE EmployeeTime SET Seconds=0 WHERE Seconds IS NULL
DELETE EmployeeTime WHERE EmployeeID IS NULL OR [In] IS NULL
UPDATE EmployeeTime SET TypeID = (SELECT TOP 1 TypeID FROM TimeType) WHERE TypeID IS NULL
UPDATE EmployeeTime SET [Pay Rate]=0 WHERE [Pay Rate] IS NULL
UPDATE EmployeeTime SET [Billing Rate]=0 WHERE [Billing Rate] IS NULL

ALTER TABLE dbo.EmployeeTime ALTER COLUMN Seconds int NOT NULL

IF EXISTS(SELECT * FROM sysindexes WHERE [ID] = OBJECT_id('EmployeeTime') AND [name] = 'IX_EmployeeTime_In') DROP INDEX dbo.EmployeeTime.[IX_EmployeeTime_In]
ALTER TABLE dbo.EmployeeTime ALTER COLUMN [In] smalldatetime NOT NULL
CREATE INDEX IX_EmployeeTime_In ON dbo.[EmployeeTime]([In]) WITH  FILLFACTOR = 90

IF EXISTS(SELECT * FROM sysindexes WHERE [ID] = OBJECT_id('EmployeeTime') AND [name] = 'IX_EmployeeTime_EmployeeID') DROP INDEX dbo.EmployeeTime.[IX_EmployeeTime_EmployeeID]
IF EXISTS(SELECT * FROM sysindexes WHERE [ID] = OBJECT_id('EmployeeTime') AND [name] = 'IX_EmployeeTime_EmployeeID_TypeID') DROP INDEX dbo.EmployeeTime.[IX_EmployeeTime_EmployeeID_TypeID]
ALTER TABLE dbo.EmployeeTime ALTER COLUMN EmployeeID int NOT NULL
ALTER TABLE dbo.EmployeeTime ALTER COLUMN TypeID int NOT NULL
CREATE INDEX [IX_EmployeeTime_EmployeeID_TypeID] ON dbo.[EmployeeTime]([EmployeeID], [TypeID]) WITH  FILLFACTOR = 90 ON [PRIMARY]
CREATE INDEX [IX_EmployeeTime_EmployeeID] ON dbo.[EmployeeTime]([EmployeeID]) WITH  FILLFACTOR = 90 ON [PRIMARY]

ALTER TABLE dbo.EmployeeTime ALTER COLUMN [Pay Rate] smallmoney NOT NULL
ALTER TABLE dbo.EmployeeTime ALTER COLUMN [Billing Rate] smallmoney NOT NULL
GO
UPDATE dbo.Project SET [Note] = '' WHERE [Note] IS NULL
ALTER TABLE dbo.Project ALTER COLUMN [Note] varchar(4000) NOT NULL
GO
IF OBJECT_id('dbo.spLeaveTypeListAccrued') IS NOT NULL DROP PROC dbo.spLeaveTypeListAccrued
GO
CREATE PROC dbo.spLeaveTypeListAccrued
	@employee_id int = NULL
AS
SET NOCOUNT ON

IF @employee_id IS NULL
SELECT T.* FROM vwLeaveType T WHERE T.Bank = 1 
ORDER BY T.[Order]

ELSE
SELECT T.* FROM vwLeaveType T WHERE T.Bank = 1 AND EXISTS
(
	SELECT R.* FROM LeaveRate R
	INNER JOIN EmployeeLeavePlan P ON R.TypeID = T.TypeID AND P.PlanID = R.PlanID AND P.EmployeeID = @employee_id
)
ORDER BY T.[Order]

GO
GRANT EXEC ON dbo.spLeaveTypeListAccrued TO public
GO

IF OBJECT_id('dbo.Ledger') IS NOT NULL DROP TABLE dbo.Ledger
IF OBJECT_id('dbo.LedgerTransaction') IS NOT NULL DROP TABLE dbo.LedgerTransaction
IF OBJECT_id('dbo.LedgerTransactionBatch') IS NOT NULL DROP TABLE dbo.LedgerTransactionBatch
IF OBJECT_id('dbo.SetMinAndBaseOnLedgerAccountDCRateChange') IS NOT NULL DROP TRIGGER dbo.SetMinAndBaseOnLedgerAccountDCRateChange
GO
IF OBJECT_id('GLAccount') IS NOT NULL AND OBJECT_id('dbo.GLAccount') IS NULL
EXEC dbo.sp_changeobjectowner 'GLAccount', 'dbo'
GO
IF OBJECT_id('dbo.GLAccount') IS NULL
BEGIN
	BEGIN TRAN

	DELETE EmployeeLevy
	DELETE EmployeeTax
	DELETE TaxGraduated
	DELETE TaxFixed
	DELETE Tax
	UPDATE LedgerAccount SET ParentAccountID = NULL
	DELETE LedgerAccount
	

	CREATE TABLE dbo.[GLAccount] (
		[AccountID] [int] IDENTITY (1, 1) NOT NULL PRIMARY KEY,
		[Number] [int] NOT NULL ,
		[ParentAccountID] [int] NULL ,
		[Account] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
		Flags int NOT NULL
	) ON [PRIMARY]
	
	CREATE  UNIQUE  INDEX [IX_GLAccount_Number] ON dbo.[GLAccount]([Number]) WITH  FILLFACTOR = 90 ON [PRIMARY]
	
	ALTER TABLE dbo.[GLAccount] ADD CONSTRAINT [FK_GLAccount_Parent] FOREIGN KEY 
	(
		[ParentAccountID]
	) REFERENCES dbo.[GLAccount] (
		[AccountID]
	)

	INSERT GLAccount([Number], ParentAccountID, Account, Flags) VALUES (1000, NULL, 'Assets', 1)
	INSERT GLAccount([Number], ParentAccountID, Account, Flags) VALUES (2000, NULL, 'Liabilities', 2)
	INSERT GLAccount([Number], ParentAccountID, Account, Flags) VALUES (3000, NULL, 'Equity', 4)
	INSERT GLAccount([Number], ParentAccountID, Account, Flags) VALUES (4000, NULL, 'Expenses', 8)
	INSERT GLAccount([Number], ParentAccountID, Account, Flags) VALUES (5000, NULL, 'Revenue', 16)

	INSERT GLAccount([Number], ParentAccountID, Account, Flags) VALUES (1100, 1, 'Accounts Receivable', 1)
	INSERT GLAccount([Number], ParentAccountID, Account, Flags) VALUES (2500, 2, 'Premiums Payable', 2)
	INSERT GLAccount([Number], ParentAccountID, Account, Flags) VALUES (1200, 1, 'Trust Bank Account', 33)

	COMMIT TRAN
END
GO
IF OBJECT_id('dbo.NoteClass') IS NULL
BEGIN
	CREATE TABLE dbo.NoteClass
	(
		ClassID int NOT NULL IDENTITY(1,1) Primary Key,
		Class varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
	)

END
GO
IF OBJECT_id('dbo.Note') IS NULL
BEGIN
	BEGIN TRAN

	CREATE TABLE dbo.Note
	(
		NoteID int NOT NULL IDENTITY(1,1) Primary Key,
		InvoiceID int NULL,
		PaymentID int NULL,
		PersonID int NULL,
		ClassID int NULL,
		Subject varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
		Note text NOT NULL,
		[Day past 1900] int NOT NULL,
		[Created Day past 1900] int NOT NULL DEFAULT(DATEDIFF(d,0,GETDATE())),
		[Created By] varchar(128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL DEFAULT(SUSER_SNAME()),
		[Last Updated Day past 1900] int NOT NULL DEFAULT(DATEDIFF(d,0,GETDATE())),
		[Last Updated By] varchar(128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL DEFAULT(SUSER_SNAME())
	)

	ALTER TABLE dbo.Note ADD CONSTRAINT [FK_Note_Person] FOREIGN KEY
	(
		PersonID
	) REFERENCES Person (
		PersonID
	) ON DELETE CASCADE, CONSTRAINT [FK_Note_Class] FOREIGN KEY
	(
		ClassID
	) REFERENCES NoteClass (
		ClassID
	),
	CONSTRAINT [CK_Note_RegardingRequired] CHECK (case when ([InvoiceID] is null) then 0 else 2 end + case when ([PaymentID] is null) then 0 else 2 end + case when ([PersonID] is null) then 0 else 2 end = 2)



	COMMIT TRAN
END
GO
UPDATE PermissionScopeAttribute SET [Permission Mask] = [Permission Mask] | 1 WHERE AttributeID=47
GO
BEGIN TRANSACTION
	DELETE TempPersonPermission
	DROP INDEX TempPersonPermission.IX_TempPersonPermission_BatchPersonAttribute
	ALTER TABLE TempPersonPermission ALTER COLUMN [AttributeID] int NOT NULL
	CREATE INDEX IX_TempPersonPermission_BatchPersonAttribute ON TempPersonPermission(BatchID,PersonID,AttributeID)
	ALTER TABLE TempPersonPermission  ALTER COLUMN PersonID int NULL
COMMIT TRANSACTION
GO
IF OBJECT_id('dbo.vwNote') IS NOT NULL DROP VIEW dbo.vwNote
IF OBJECT_id('dbo.spNoteInsurePermission') IS NOT NULL DROP PROC dbo.spNoteInsurePermission
IF OBJECT_id('dbo.spNoteInsert') IS NOT NULL DROP PROC dbo.spNoteInsert
IF OBJECT_id('dbo.spNoteUpdate') IS NOT NULL DROP PROC dbo.spNoteUpdate
IF OBJECT_id('dbo.spNoteDelete') IS NOT NULL DROP PROC dbo.spNoteDelete
IF OBJECT_id('dbo.spNoteSelect') IS NOT NULL DROP PROC dbo.spNoteSelect
IF OBJECT_id('dbo.spNoteList') IS NOT NULL DROP PROC dbo.spNoteList
IF OBJECT_id('dbo.spNoteListDistinctSubjects') IS NOT NULL DROP PROC dbo.spNoteListDistinctSubjects
GO
CREATE PROC dbo.spNoteListDistinctSubjects
AS
SET NOCOUNT ON
SELECT DISTINCT Subject FROM Note WHERE LEN(Subject) > 0 ORDER BY Subject
GO
CREATE VIEW dbo.vwNote
AS
SELECT N.NoteID,N.InvoiceID,N.PaymentID,N.PersonID,N.ClassID,N.Subject,N.Note,N.[Created Day past 1900],N.[Created By],N.[Last Updated Day past 1900],N.[Last Updated By], 
[Class] = ISNULL(C.[Class], ''), [Day past 1900] = DATEADD(d, 0, N.[Day past 1900]), [Day] = N.[Day past 1900],
[Created] = DATEADD(d, 0,N. [Created Day past 1900]),
[Last Updated] = DATEADD(d, 0, N.[Last Updated Day past 1900]),
RegardingPersonID = N.PersonID,
[Regarding Person] = CASE
	WHEN N.PersonID IS NOT NULL THEN V.[List As]
	ELSE CAST('' AS varchar(400))
END,
Regarding = CASE
	WHEN N.PersonID IS NOT NULL THEN V.[List As]
	WHEN N.InvoiceID IS NOT NULL THEN CAST(N.InvoiceID AS varchar(400))
	WHEN N.PaymentID IS NOT NULL THEN '' -- CAST(P.[Transaction Number] AS varchar(400))
END,
PayerID = 0,
Payer = '',
CommunicationID=NoteID, EmployeeID=N.PersonID, Employee=V.[List As], [Employee Full Name]=V.[List As] -- Legacy

FROM Note N
LEFT JOIN NoteClass C ON N.ClassID = C.ClassID
LEFT JOIN dbo.vwPersonListAs V ON N.PersonID = V.PersonID
GO
CREATE PROC dbo.spNoteInsurePermission
	@note_id int,
	@permission_required int,
	@authorized bit OUT
AS
DECLARE @attribute_id int, @person_id int
SELECT @person_id=RegardingPersonID,@attribute_id = CASE 
	WHEN SUSER_SNAME() <> [Created By] THEN 131072
	WHEN [Created Day Past 1900]+3 > DATEDIFF(d,0,GETDATE()) THEN 47
	ELSE 48
END
FROM vwNote WHERE NoteID = @note_id
EXEC dbo.spPermissionInsureForCurrentUserOnPerson @person_id, @attribute_id, @permission_required, @authorized OUT
GO
CREATE PROC dbo.spNoteSelect
	@note_id int
AS
SET NOCOUNT ON
DECLARE @authorized bit
EXEC dbo.spNoteInsurePermission @note_id, 1, @authorized OUT
IF @authorized = 1 SELECT * FROM vwNote WHERE NoteID = @note_id
GO
CREATE PROC dbo.spNoteList
	@invoice_id int,
	@payment_id int,
	@person_id int,
	@class_id int,
	@payer_id int,
	@day_min int,
	@day_max int
AS
GO
CREATE PROC dbo.spNoteInsert
	@invoice_id int,
	@payment_id int,
	@person_id int,
	@class_id int,
	@subject varchar(50),
	@note text,
	@day_past_1900 int,
	@note_id int OUT
AS
DECLARE @authorized bit
EXEC dbo.spPermissionInsureForCurrentUserOnPerson @person_id, 47, 4, @authorized OUT
IF @authorized = 1
BEGIN
	INSERT Note(InvoiceID, PaymentID, PersonID, ClassID, Subject, Note, [Day past 1900])
	VALUES (@invoice_id, @payment_id, @person_id, @class_id, @subject, @note, @day_past_1900)
	SET @note_id = SCOPE_IDENTITY()
END
GO
CREATE PROC dbo.spNoteUpdate
	@note_id int,
	@invoice_id int,
	@payment_id int,
	@person_id int,
	@class_id int,
	@subject varchar(50),
	@note text,
	@day_past_1900 int
AS
DECLARE @authorized bit
EXEC dbo.spNoteInsurePermission @note_id, 2, @authorized OUT
IF @authorized = 1 UPDATE Note
SET ClassID = @class_id,
InvoiceID = @invoice_id,
PaymentID = @payment_id,
PersonID = @person_id,
Subject = @subject,
Note = @note,
[Last Updated Day past 1900] = DATEDIFF(d,0,GETDATE()),
[Last Updated By] = SUSER_SNAME(),
[Day past 1900] = @day_past_1900
WHERE NoteID = @note_id
GO
CREATE PROC dbo.spNoteDelete
	@note_id int
AS
DECLARE @authorized bit
EXEC dbo.spNoteInsurePermission @note_id, 8, @authorized OUT
IF @authorized = 1 DELETE Note WHERE NoteID = @note_id
GO
GRANT EXEC ON dbo.spNoteSelect TO public
GRANT EXEC ON dbo.spNoteInsert TO public
GRANT EXEC ON dbo.spNoteUpdate TO public
GRANT EXEC ON dbo.spNoteDelete TO public
GRANT EXEC ON dbo.spNoteList TO public
GRANT EXEC ON dbo.spNoteListDistinctSubjects TO public
GO




IF OBJECT_id('dbo.vwNoteClass') IS NOT NULL DROP VIEW dbo.vwNoteClass
IF OBJECT_id('dbo.spNoteClassInsert') IS NOT NULL DROP PROC dbo.spNoteClassInsert
IF OBJECT_id('dbo.spNoteClassUpdate') IS NOT NULL DROP PROC dbo.spNoteClassUpdate
IF OBJECT_id('dbo.spNoteClassDelete') IS NOT NULL DROP PROC dbo.spNoteClassDelete
IF OBJECT_id('dbo.spNoteClassList') IS NOT NULL DROP PROC dbo.spNoteClassList
IF OBJECT_id('dbo.spNoteClassGetClassFromClassID') IS NOT NULL DROP PROC dbo.spNoteClassGetClassFromClassID
GO
CREATE VIEW dbo.vwNoteClass AS SELECT * FROM NoteClass
GO
CREATE PROC dbo.spNoteClassInsert @class varchar(50), @class_id int OUT AS
INSERT NoteClass(Class) VALUES (@class) SET @class_id = SCOPE_IDENTITY()
GO
CREATE PROC dbo.spNoteClassUpdate @class varchar(50), @class_id int AS
UPDATE NoteClass SET Class=@class WHERE ClassID=@class_id
GO
CREATE PROC dbo.spNoteClassDelete @class_id int AS
DELETE NoteClass WHERE ClassID=@class_id
GO
CREATE PROC dbo.spNoteClassList AS SET NOCOUNT ON
SELECT * FROM vwNoteClass ORDER BY [Class]
GO
CREATE PROC dbo.spNoteClassGetClassFromClassID @class varchar(50), @class_id int AS
SELECT @class=[Class] FROM NoteClass WHERE ClassID=@class_id
GO
GRANT EXEC ON dbo.spNoteClassInsert TO public
GRANT EXEC ON dbo.spNoteClassUpdate TO public
GRANT EXEC ON dbo.spNoteClassDelete TO public
GRANT EXEC ON dbo.spNoteClassList TO public
GRANT EXEC ON dbo.spNoteClassGetClassFromClassID TO public














GO
--Legacy
ALTER PROC dbo.spEmployeeCommunicationDelete @communication_id int AS EXEC dbo.spNoteDelete @communication_id
GO
--Legacy
ALTER PROC dbo.spEmployeeCommunicationInsert
	@employee_id int,
	@day_past_1900 int,
	@note varchar(4000),
	@subject varchar(50),
	@communication_id int OUT
AS
EXEC dbo.spNoteInsert
	NULL,
	NULL,
	@employee_id,
	NULL,
	@subject,
	@note,
	@day_past_1900,
	@communication_id OUT
GO
--Legacy
ALTER PROC dbo.spEmployeeCommunicationList
	@employee_id int,
	@start_date datetime,
	@stop_date datetime
AS
DECLARE @day_min int, @day_max int
SET NOCOUNT ON
SELECT @day_min=DATEDIFF(dd,0,@start_date), @day_max=DATEDIFF(dd,0,@stop_date)
EXEC dbo.spNoteList
	NULL,
	NULL,
	@employee_id,
	NULL,
	NULL,
	@day_min,
	@day_max
GO
-- Legacy
ALTER PROC dbo.spEmployeeCommunicationListDistinctSubjects AS EXEC dbo.spNoteListDistinctSubjects
GO
-- Legacy
ALTER PROC dbo.spEmployeeCommunicationSelect
	@communication_id int
AS
EXEC dbo.spNoteSelect @communication_id
GO
-- Legacy
ALTER PROC dbo.spEmployeeCommunicationUpdate
	@day_past_1900 int,
	@note varchar(4000),
	@subject varchar(50),
	@communication_id int
AS
DECLARE @person_id int
SELECT @person_id = PersonID FROM Note WHERE NoteID=@communication_id
EXEC dbo.spNoteUpdate
	@communication_id,
	NULL,
	NULL,
	@person_id,
	NULL,
	@subject,
	@note,
	@day_past_1900
GO
IF OBJECT_id('dbo.EmployeeCommunication') IS NOT NULL
BEGIN
BEGIN TRAN
	INSERT Note(PersonID, Subject, [Note], [Day past 1900])
	SELECT EmployeeID, Subject, [Note], [Day past 1900] FROM dbo.EmployeeCommunication

	DROP TABLE dbo.EmployeeCommunication
COMMIT TRAN
END
GO
-- Moves benefits notes to searchable notes object
IF EXISTS(SELECT * FROM Employee WHERE DATALENGTH([Benefit Note]) > 0) 
BEGIN
BEGIN TRAN
	INSERT Note(PersonID, [Day past 1900], [Subject], Note)
	SELECT EmployeeID, DATEDIFF(d,0,GETDATE()),'Benefits', [Benefit Note] FROM Employee WHERE DATALENGTH([Benefit Note]) > 0

	UPDATE Employee SET [Benefit Note] = '' WHERE DATALENGTH([Benefit Note]) > 0
COMMIT TRAN
END
GO
ALTER PROC dbo.spLeaveRatePeriodList
	@group_id int,
	@payroll bit
AS
SET NOCOUNT ON

IF @group_id = 2 OR @group_id = 64 SELECT * INTO #Temp FROM LeaveRatePeriod WHERE GroupID = @group_id AND (@payroll IS NULL OR Payroll = @payroll) ORDER BY [Order]

IF @group_id = 2
BEGIN
	DECLARE @i int
	DECLARE @y int

	SELECT @i = 0, @y = YEAR(GETDATE())
	WHILE @i < 3
	BEGIN
		IF @i > 0 UPDATE #Temp SET Example = Example + '; ' WHERE PeriodID IN (43010, 26626, 40962, 47106, 28674, 45058)

		UPDATE #Temp SET Example = Example + CAST(dbo.GetDateFromMDY(C.[Administrative Year Start Month], C.[Administrative Year Start Day], @y) as varchar(11))
		FROM #Temp CROSS JOIN Constant C WHERE #Temp.PeriodID = 43010

		UPDATE #Temp SET Example = Example + CAST(dbo.GetDateFromMDY(C.[Fiscal Year Start Month], C.[Fiscal Year Start Day], @y) as varchar(11))
		FROM #Temp CROSS JOIN Constant C WHERE #Temp.PeriodID = 26626

		UPDATE #Temp SET Example = Example + CAST(dbo.GetDateFromMDY(C.[Operational Year Start Month], C.[Operational Year Start Day], @y) as varchar(11))
		FROM #Temp CROSS JOIN Constant C WHERE #Temp.PeriodID = 40962

		UPDATE #Temp SET Example = Example + CAST(dbo.GetDateFromMDY(C.[Administrative Year Start Month], C.[Administrative Year Start Day] - 1, @y) as varchar(11))
		FROM #Temp CROSS JOIN Constant C WHERE #Temp.PeriodID = 47106

		UPDATE #Temp SET Example = Example + CAST(dbo.GetDateFromMDY(C.[Fiscal Year Start Month], C.[Fiscal Year Start Day] - 1, @y) as varchar(11))
		FROM #Temp CROSS JOIN Constant C WHERE #Temp.PeriodID = 28674

		UPDATE #Temp SET Example = Example + CAST(dbo.GetDateFromMDY(C.[Operational Year Start Month], C.[Operational Year Start Day] - 1, @y) as varchar(11))
		FROM #Temp CROSS JOIN Constant C WHERE #Temp.PeriodID = 45058

		SELECT @y = @y + 1, @i = @i + 1
	END
	UPDATE #Temp SET Example = Example + ' ..' WHERE PeriodID IN (43010, 26626, 40962, 47106, 28674, 45058)

	SELECT * FROM #Temp
END
ELSE IF @group_id = 64
BEGIN
	IF @payroll = 1 OR @payroll IS NULL
	BEGIN
		DECLARE @wk0 datetime, @wk int
		SELECT @wk0 = CONVERT(datetime, '20040101', 112)
		SELECT @wk0 = DATEADD(d,1 - DATEPART(dw, @wk0), @wk0)

		-- Go to first occurence of the week, with ref point 01/01/04
		SELECT @wk = DATEDIFF(wk, @wk0, GETDATE()) / 2
		SELECT @wk0 = DATEADD(wk, @wk * 2, @wk0)

		CREATE TABLE #P(PeriodID int, DD int)

		INSERT #P
		SELECT PeriodID, DD = CASE PeriodID 
			WHEN 200768 THEN 0
			WHEN 202816 THEN 1
			WHEN 204864 THEN 2
			WHEN 206912 THEN 3
			WHEN 208960 THEN 4
			WHEN 211008 THEN 5
			WHEN 213056 THEN 6
	
			WHEN 215104 THEN 7
			WHEN 217152 THEN 8
			WHEN 219200 THEN 9
			WHEN 221248 THEN 10
			WHEN 223296 THEN 11
			WHEN 225344 THEN 12
			ELSE 13
		END
		FROM LeaveRatePeriod WHERE GroupID = 64

		UPDATE #Temp SET Example = '' WHERE Payroll = 1
		
		SELECT @wk = 0
		WHILE @wk < 4
		BEGIN
			UPDATE #Temp SET Example = Example + CASE WHEN LEN([Example]) = 0 THEN '' ELSE ', ' END + CAST(DATEADD(d, #P.DD, @wk0) AS char(6))
			FROM #Temp INNER JOIN #P ON #Temp.PeriodID = #P.PeriodID

			SELECT @wk = @wk + 1, @wk0 = DATEADD(wk, 2, @wk0)
		END
	END

	SELECT * FROM #Temp
END
ELSE
SELECT * FROM LeaveRatePeriod WHERE GroupID = @group_id AND (@payroll IS NULL OR Payroll = @payroll) ORDER BY [Order]
GO
ALTER FUNCTION dbo.GetFirstPayroll()
RETURNS datetime
BEGIN
	DECLARE @wk0 datetime -- first Jan 1 after 1900 that falls on the first day of the week
	SELECT @wk0 = CONVERT(datetime, '19101231', 112)

	DECLARE @payroll_period_id int, @week_day int
	SELECT @payroll_period_id = CurrentPayrollPeriodID FROM dbo.Constant

	SELECT @week_day = [WeekDay] FROM LeaveRatePeriod WHERE PeriodID = @payroll_period_id
	SELECT @wk0 = DATEADD(d, @week_day, @wk0)

	RETURN @wk0
END
GO
IF OBJECT_id('dbo.EmployeeDependent') IS NULL
BEGIN
BEGIN TRAN

	CREATE TABLE dbo.[EmployeeDependent] (
		[ContactID] [int] IDENTITY (1, 1) NOT NULL ,
		[EmployeeID] [int] NOT NULL ,
		[PersonID] [int] NOT NULL ,
		[Relationship] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL 
	) ON [PRIMARY]
	
	ALTER TABLE dbo.[EmployeeDependent] WITH NOCHECK ADD 
		CONSTRAINT [PK_EmployeeDependent] PRIMARY KEY  CLUSTERED 
		(
			[ContactID]
		) WITH  FILLFACTOR = 90  ON [PRIMARY] 
	
	ALTER TABLE dbo.[EmployeeDependent] ADD 
		CONSTRAINT [DF_EmployeeDependent_Relationship] DEFAULT ('') FOR [Relationship],
		CONSTRAINT [IX_EmployeeDependent] UNIQUE  NONCLUSTERED 
		(
			[EmployeeID],
			[PersonID]
		) WITH  FILLFACTOR = 90  ON [PRIMARY] 
	
	CREATE  INDEX [IX_EmployeeDependent_Employee] ON dbo.[EmployeeDependent]([EmployeeID]) WITH  FILLFACTOR = 90 ON [PRIMARY]
	
	ALTER TABLE dbo.[EmployeeDependent] ADD 
		CONSTRAINT [FK_EmployeeDependent_Employee] FOREIGN KEY 
		(
			[EmployeeID]
		) REFERENCES dbo.[Employee] (
			[EmployeeID]
		) ON DELETE CASCADE ,
		CONSTRAINT [FK_EmployeeDependent_Person] FOREIGN KEY 
		(
			[PersonID]
		) REFERENCES dbo.[Person] (
			[PersonID]
		)

COMMIT TRAN
END
GO
IF OBJECT_id('dbo.UpdateDependentRoleOnEmployeeDependent') IS NOT NULL DROP TRIGGER dbo.UpdateDependentRoleOnEmployeeDependent
GO
CREATE TRIGGER dbo.UpdateDependentRoleOnEmployeeDependent ON dbo.[EmployeeDependent] 
FOR INSERT, UPDATE, DELETE
AS
SET NOCOUNT ON

-- Set dependent role on people associated with inserted dependent
UPDATE P SET [Role Mask] = [Role Mask] | 0x20
FROM Person P INNER JOIN inserted C ON P.PersonID = C.PersonID

-- Remove dependent role on people associated with deleted dependent
UPDATE P SET [Role Mask] = [Role Mask] & 0x7FFFFFDF
FROM Person P INNER JOIN deleted C ON P.PersonID = C.PersonID AND P.PersonID NOT IN
(
	SELECT DISTINCT PersonID FROM EmployeeDependent
)

GO


IF OBJECT_id('dbo.spEmployeeDependentCheckPermission') IS NOT NULL DROP PROC dbo.spEmployeeDependentCheckPermission
IF OBJECT_id('dbo.spEmployeeDependentDelete') IS NOT NULL DROP PROC dbo.spEmployeeDependentDelete
IF OBJECT_id('dbo.spEmployeeDependentGetRelationship') IS NOT NULL DROP PROC dbo.spEmployeeDependentGetRelationship
IF OBJECT_id('dbo.spEmployeeDependentInsert2') IS NOT NULL DROP PROC dbo.spEmployeeDependentInsert2
IF OBJECT_id('dbo.spEmployeeDependentList') IS NOT NULL DROP PROC dbo.spEmployeeDependentList
IF OBJECT_id('dbo.spEmployeeDependentSelectHome') IS NOT NULL DROP PROC dbo.spEmployeeDependentSelectHome
IF OBJECT_id('dbo.spEmployeeDependentUpdateHome') IS NOT NULL DROP PROC dbo.spEmployeeDependentUpdateHome
IF OBJECT_id('dbo.spEmployeeDependentUpdateWork') IS NOT NULL DROP PROC dbo.spEmployeeDependentUpdateWork
IF OBJECT_id('dbo.spEmployeeDependentSelectWork') IS NOT NULL DROP PROC dbo.spEmployeeDependentSelectWork
IF OBJECT_id('dbo.spEmployeeDependentUpdateRelationship') IS NOT NULL DROP PROC dbo.spEmployeeDependentUpdateRelationship
GO
CREATE PROC dbo.spEmployeeDependentCheckPermission
	@contact_id int,
	@work_permission int out,
	@home_permission int out,
	@contact_permission int out
AS
DECLARE @person_id int
DECLARE @employee_id int

SET NOCOUNT ON

SELECT @person_id = PersonID, @employee_id = EmployeeID FROM EmployeeDependent WHERE ContactID = @contact_id
EXEC dbo.spPermissionGetOnPersonForCurrentUser @employee_id, 134217728, @contact_permission out

-- If dependant is an employee then check contact read work permission
IF EXISTS(SELECT EmployeeID FROM Employee WHERE EmployeeID = @person_id)
BEGIN
	EXEC dbo.spPermissionGetOnPersonForCurrentUser @person_id, 1, @home_permission out
	EXEC dbo.spPermissionGetOnPersonForCurrentUser @person_id, 2, @work_permission out
END
ELSE SELECT @home_permission = @contact_permission, @work_permission = @contact_permission
GO
-- Deletes dependent
-- Deletes associated person if person is not referenced anywhere else (people with roles will not be deleted)
CREATE PROC dbo.spEmployeeDependentDelete
	@contact_id int
AS
DECLARE @person_id int
DECLARE @employee_id int
DECLARE @authorized bit

SET NOCOUNT ON

SELECT @person_id = PersonID, @employee_id = EmployeeID FROM EmployeeDependent WHERE ContactID = @contact_id

EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 134217728, 8, @authorized out
IF @authorized = 1
BEGIN
	-- Don't delete person if referenced in other dependents or dependents
	BEGIN TRAN

	-- Delete dependent
	DELETE EmployeeDependent WHERE ContactID = @contact_id

	-- Maybe delete person
	DELETE Person WHERE PersonID = @person_id AND [Role Mask] = 0

	COMMIT TRAN
END
GO
CREATE PROC dbo.spEmployeeDependentGetRelationship
	@contact_id int,
	@relationship varchar(50) out
AS
SET NOCOUNT ON

SELECT @relationship = Relationship FROM EmployeeDependent WHERE ContactID = @contact_id
GO
CREATE PROC dbo.spEmployeeDependentInsert2
	@employee_id int,
	@person_id int,
	@contact_id int out
AS
SET NOCOUNT ON
DECLARE @authorized bit


EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 134217728, 4, @authorized out

IF @authorized = 1
INSERT EmployeeDependent(EmployeeID, PersonID)
VALUES(@employee_id, @person_id)
SELECT @contact_id = SCOPE_IDENTITY()
GO
CREATE PROC dbo.spEmployeeDependentList
	@employee_id int
AS

DECLARE @authorized bit

SET NOCOUNT ON

EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 134217728, 1, @authorized out

IF @authorized = 1 
SELECT L.ContactID, L.PersonID, V.[List As], V.[Full Name], P.[Work Phone],
P.[Home Phone], P.[Mobile Phone], L.Relationship
FROM EmployeeDependent L
INNER JOIN Person P ON L.EmployeeID = @employee_id AND L.PersonID = P.PersonID
INNER JOIN vwPersonCalculated V ON P.PersonID = V.PersonID
GO
CREATE PROC dbo.spEmployeeDependentSelectHome
	@contact_id int
AS
DECLARE @authorized bit
DECLARE @person_id int
DECLARE @employee_id int

SET NOCOUNT ON

SELECT @authorized = 1
SELECT @person_id = PersonID, @employee_id = EmployeeID FROM EmployeeDependent WHERE ContactID = @contact_id

-- If dependent is an employee then check contact read home permission
IF EXISTS(SELECT EmployeeID FROM Employee WHERE EmployeeID = @person_id)
	EXEC dbo.spPermissionInsureForCurrentUserOnPerson @person_id, 1, 1, @authorized out
-- Else check user's permission on employee's dependents
ELSE 
	EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 134217728, 1, @authorized out

IF @authorized = 1 SELECT * FROM vwPersonHome WHERE PersonID = @person_id

GO
CREATE PROC dbo.spEmployeeDependentSelectWork
	@contact_id int
AS
DECLARE @authorized bit
DECLARE @person_id int
DECLARE @employee_id int

SET NOCOUNT ON

SELECT @authorized = 1
SELECT @person_id = PersonID, @employee_id = EmployeeID FROM EmployeeDependent WHERE ContactID = @contact_id

-- If dependent is an employee then check contact read work permission
IF EXISTS(SELECT EmployeeID FROM Employee WHERE EmployeeID = @person_id)
	EXEC dbo.spPermissionInsureForCurrentUserOnPerson @person_id, 2, 1, @authorized out
-- Else check user's permission on employee's dependents
ELSE 
	EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 134217728, 1, @authorized out

IF @authorized = 1 SELECT * FROM dbo.vwPersonWork WHERE PersonID = @person_id

GO
CREATE PROC dbo.spEmployeeDependentUpdateHome
	@contact_id int,
	@home_email varchar(50),
	@home_phone varchar(50),
	@home_fax varchar(50),
	@home_address varchar(50),
	@home_address2 varchar(50),
	@home_city varchar(50),
	@home_state varchar(50),
	@home_zip varchar(50),
	@home_country varchar(50)
AS
DECLARE @work_permission int
DECLARE @home_permission int
DECLARE @contact_permission int

SET NOCOUNT ON

EXEC dbo.spEmployeeDependentCheckPermission
	@contact_id,
	@work_permission out,
	@home_permission out,
	@contact_permission out

IF @home_permission & 2 = 0 RAISERROR('You lack write permission on this dependent''s home information.', 16, 1)
ELSE
UPDATE P SET
	[Home E-mail] = @home_email,
	[Home Phone] = @home_phone,
	[Home Fax] = @home_fax,
	[Home Address] = @home_address,
	[Home Address (Cont.)] = @home_address2,
	[Home City] = @home_city,
	[Home State] = @home_state,
	[Home Zip] = @home_zip,
	[Home Country] = @home_country
FROM Person P
INNER JOIN EmployeeDependent C ON C.ContactID = @contact_id AND C.PersonID = P.PersonID

GO
CREATE PROC dbo.spEmployeeDependentUpdateRelationship
	@contact_id int,
	@relationship varchar(50)
AS
DECLARE @employee_id int
DECLARE @authorized bit

SET NOCOUNT ON

SELECT @employee_id = EmployeeID FROM EmployeeDependent WHERE ContactID = @contact_id
EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 134217728, 2, @authorized out

IF @authorized = 1
UPDATE EmployeeDependent SET Relationship = @relationship WHERE ContactID = @contact_id

GO
CREATE PROC dbo.spEmployeeDependentUpdateWork
	@contact_id int,
	@title varchar(50),
	@first_name varchar(50),
	@middle_name varchar(50),
	@last_name varchar(50),
	@suffix varchar(50),
	@male bit,
	@work_email varchar(50),
	@work_phone varchar(50),
	@extension varchar(50),
	@work_phone_note varchar(50),
	@home_office_phone varchar(50),
	@toll_free_phone varchar(50),
	@mobile_phone varchar(50),
	@work_fax varchar(50),
	@pager varchar(50),
	@note varchar(4000),
	@work_address varchar(50),
	@work_address2 varchar(50),
	@work_city varchar(50),
	@work_state varchar(50),
	@work_zip varchar(50),
	@work_country varchar(50),
	@credentials varchar(50)
AS
DECLARE @work_permission int
DECLARE @home_permission int
DECLARE @contact_permission int

SET NOCOUNT ON

EXEC dbo.spEmployeeDependentCheckPermission
	@contact_id,
	@work_permission out,
	@home_permission out,
	@contact_permission out

IF @work_permission & 2 = 0 RAISERROR('You lack write permission on this dependent''s work information.', 16, 1)
ELSE
UPDATE P SET
	Title = @title,
	Credentials = @credentials,
	[First Name] = @first_name,
	[Middle Name] = @middle_name,
	[Last Name] = @last_name,
	[Home Office Phone] = @home_office_phone,
	Suffix = @suffix,
	Male = @male,
	[Work E-mail] = @work_email,
	[Work Phone] = @work_phone,
	Extension = @extension,
	[Work Phone Note] = @work_phone_note,
	[Toll Free Phone] = @toll_free_phone,
	[Mobile Phone] = @mobile_phone,
	[Work Fax] = @work_fax,
	Pager = @pager,
	Note = @note,
	[Work Address] = @work_address,
	[Work Address (cont.)] = @work_address2,
	[Work City] = @work_city,
	[Work State] = @work_state,
	[Work Zip] = @work_zip,
	[Work Country] = @work_country
FROM Person P
INNER JOIN EmployeeDependent C ON C.ContactID = @contact_id AND C.PersonID = P.PersonID
GO
GRANT EXEC ON dbo.spEmployeeDependentCheckPermission TO public
GRANT EXEC ON dbo.spEmployeeDependentDelete TO public
GRANT EXEC ON dbo.spEmployeeDependentGetRelationship TO public
GRANT EXEC ON dbo.spEmployeeDependentInsert2 TO public
GRANT EXEC ON dbo.spEmployeeDependentList TO public
GRANT EXEC ON dbo.spEmployeeDependentSelectHome TO public
GRANT EXEC ON dbo.spEmployeeDependentUpdateHome TO public
GRANT EXEC ON dbo.spEmployeeDependentUpdateWork TO public
GRANT EXEC ON dbo.spEmployeeDependentSelectWork TO public
GRANT EXEC ON dbo.spEmployeeDependentUpdateRelationship TO public
GO









-- Deletes dependent
-- Deletes associated person if person is not referenced anywhere else (people with roles will not be deleted)
ALTER PROC dbo.spEmergencyContactDelete
	@contact_id int
AS
DECLARE @person_id int
DECLARE @employee_id int
DECLARE @authorized bit

SET NOCOUNT ON

SELECT @person_id = PersonID, @employee_id = EmployeeID FROM EmployeeEmergencyContact WHERE ContactID = @contact_id

EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 134217728, 8, @authorized out
IF @authorized = 1
BEGIN
	BEGIN TRAN

	-- Delete emergency contact
	DELETE EmployeeEmergencyContact WHERE ContactID = @contact_id

	-- Maybe delete person
	DELETE Person WHERE PersonID = @person_id AND [Role Mask] = 0

	COMMIT TRAN
END
GO
IF OBJECT_id('COBRAQE') IS NULL
BEGIN
BEGIN TRAN

	CREATE TABLE dbo.COBRAQE (
		EventID int NOT NULL PRIMARY KEY IDENTITY(1,1),
		Event varchar(50),
		Termination bit,
		[Months Coverage] int
	)

	ALTER TABLE dbo.COBRAQE ADD 
	CONSTRAINT [IX_COBRAQE_DuplicateEvent] UNIQUE  NONCLUSTERED 
	(
		[Event]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [CK_COBRAQE_Required] CHECK (LEN([Event]) > 0)

	INSERT COBRAQE(Event, [Months Coverage], Termination) SELECT 'Employee Voluntary Term', 18, 1
	INSERT COBRAQE(Event, [Months Coverage], Termination) SELECT 'Employee Involuntary Term', 18, 1
	INSERT COBRAQE(Event, [Months Coverage], Termination) SELECT 'Employee Reduction in Hours', 18, 0
	INSERT COBRAQE(Event, [Months Coverage], Termination) SELECT 'Spouse Voluntary Term', 18, 1
	INSERT COBRAQE(Event, [Months Coverage], Termination) SELECT 'Spouse Involuntary Term', 18, 1
	INSERT COBRAQE(Event, [Months Coverage], Termination) SELECT 'Spouse Reduction in Hours', 18, 0
	INSERT COBRAQE(Event, [Months Coverage], Termination) SELECT 'Spouse Medicare Entitlement', 18, 0
	INSERT COBRAQE(Event, [Months Coverage], Termination) SELECT 'Spouse Divorce/Separation', 36, 0
	INSERT COBRAQE(Event, [Months Coverage], Termination) SELECT 'Spouse Death', 18, 0
	INSERT COBRAQE(Event, [Months Coverage], Termination) SELECT 'Dependent Loss of Status', 18, 0
	INSERT COBRAQE(Event, [Months Coverage], Termination) SELECT 'Dependent Voluntary Term', 18, 1
	INSERT COBRAQE(Event, [Months Coverage], Termination) SELECT 'Dependent Involuntary Term', 18, 1
	INSERT COBRAQE(Event, [Months Coverage], Termination) SELECT 'Dependent Reduction in Hours', 18, 0
	INSERT COBRAQE(Event, [Months Coverage], Termination) SELECT 'Dependent Medicare Entitlement', 18, 0
	INSERT COBRAQE(Event, [Months Coverage], Termination) SELECT 'Dependent Divorce/Separation', 18, 0
	INSERT COBRAQE(Event, [Months Coverage], Termination) SELECT 'Dependent Death', 18, 0

	ALTER TABLE dbo.Employee ADD COBRAFirstQualifyingEventID int NULL
	ALTER TABLE dbo.Employee ADD [COBRA First Qualifying Event Day Past 1900] int NULL
	ALTER TABLE dbo.Employee ADD COBRALastQualifyingEventID int NULL
	ALTER TABLE dbo.Employee ADD [COBRA Last Qualifying Event Day Past 1900] int NULL

	ALTER TABLE dbo.Employee ADD CONSTRAINT FK_Employee_COBRAQE1 FOREIGN KEY (COBRAFirstQualifyingEventID) REFERENCES dbo.COBRAQE (EventID)
	ALTER TABLE dbo.Employee ADD CONSTRAINT FK_Employee_COBRAQE2 FOREIGN KEY (COBRALastQualifyingEventID) REFERENCES dbo.COBRAQE (EventID)

COMMIT TRAN
END
GO
IF OBJECT_id('dbo.vwCOBRAQE') IS NOT NULL DROP VIEW dbo.vwCOBRAQE
IF OBJECT_id('dbo.spCOBRAQEList') IS NOT NULL DROP PROC dbo.spCOBRAQEList
IF OBJECT_id('dbo.spCOBRAQEInsert') IS NOT NULL DROP PROC dbo.spCOBRAQEInsert
IF OBJECT_id('dbo.spCOBRAQEUpdate') IS NOT NULL DROP PROC dbo.spCOBRAQEUpdate
IF OBJECT_id('dbo.spCOBRAQEDelete') IS NOT NULL DROP PROC dbo.spCOBRAQEDelete
IF OBJECT_id('dbo.spCOBRAQESelect') IS NOT NULL DROP PROC dbo.spCOBRAQESelect
GO
CREATE VIEW dbo.vwCOBRAQE AS SELECT * FROM COBRAQE
GO
CREATE PROC dbo.spCOBRAQEList AS SET NOCOUNT ON SELECT * FROM vwCOBRAQE ORDER BY Event
GO
CREATE PROC dbo.spCOBRAQEInsert
	@event varchar(50),
	@months_coverage int,
	@termination bit,
	@event_id int OUT
AS
SET NOCOUNT ON
INSERT COBRAQE(Event, [Months Coverage], Termination) SELECT @event, @months_coverage, @termination
SELECT @event_id=SCOPE_IDENTITY()
GO
CREATE PROC dbo.spCOBRAQEUpdate
	@event varchar(50),
	@months_coverage int,
	@termination bit,
	@event_id int
AS
UPDATE COBRAQE SET Event=@event, Termination=@termination, [Months Coverage]=@months_coverage WHERE EventID=@event_id
GO
CREATE PROC dbo.spCOBRAQEDelete @event_id int AS DELETE COBRAQE WHERE EventID=@event_id
GO
CREATE PROC dbo.spCOBRAQESelect @event_id int AS SET NOCOUNT ON SELECT * FROM vwCOBRAQE WHERE EventID=@event_id
GO
GRANT EXEC ON dbo.spCOBRAQEList TO public
GRANT EXEC ON dbo.spCOBRAQESelect TO public
GO
ALTER PROC dbo.spEmployeeCOBRAUpdate
	@employee_id int,
	@track bit,
	@first_payment_due_day_past_1900 int,
	@next_payment_due_day_past_1900 int,
	@eligible_day_past_1900 int,
	@notified_day_past_1900 int,
	@first_enrolled_day_past_1900 int,
	@last_enrolled_day_past_1900 int,
	@declined_day_past_1900 int,
	@expires_day_past_1900 int,
	@note varchar(4000) = NULL, -- legacy
	@first_qe_id int = NULL,
	@first_qe_day int = NULL,
	@last_qe_id int = NULL,
	@last_qe_day int = NULL

AS
DECLARE @authorized bit

SET NOCOUNT ON

EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 536870912, 2, @authorized out

IF @authorized = 1
UPDATE Employee SET
	[Track COBRA] = @track,
	[First Payment Due Day past 1900] = @first_payment_due_day_past_1900,
	[Next Payment Due Day past 1900] = @next_payment_due_day_past_1900,
	[COBRA Eligible Day past 1900] = @eligible_day_past_1900,
	[COBRA Notified Day past 1900] = @notified_day_past_1900,
	[COBRA First Enrolled Day past 1900] = @first_enrolled_day_past_1900,
	[COBRA Last Enrolled Day past 1900] = @last_enrolled_day_past_1900,
	[COBRA Declined Day past 1900] = @declined_day_past_1900,
	[COBRA Expires Day past 1900] = @expires_day_past_1900,
	COBRAFirstQualifyingEventID = @first_qe_id,
	[COBRA First Qualifying Event Day past 1900] = @first_qe_day,
	COBRALastQualifyingEventID = @last_qe_id,
	[COBRA Last Qualifying Event Day past 1900] = @last_qe_day
WHERE EmployeeID = @employee_id
GO
IF OBJECT_id('dbo.spPermissionObjectInsert') IS NOT NULL DROP PROC dbo.spPermissionObjectInsert
IF OBJECT_id('dbo.spPermissionObjectXInsert') IS NOT NULL DROP PROC dbo.spPermissionObjectXInsert
GO
CREATE PROC dbo.spPermissionObjectInsert
	@object_id int,
	@object  varchar(50),
	@select_object sysname,
	@update_object sysname,
	@insert_object sysname,
	@delete_object sysname,
	@permission_mask int
AS
DECLARE @msg nvarchar(400)
DECLARE @selectid int, @updateid int, @insertid int, @deleteid int
SELECT @selectid=0,@updateid=0,@insertid=0,@deleteid=0,@msg='Stored proc does not exist: %s'

IF @select_object IS NOT NULL 
BEGIN
	SET @selectid=OBJECT_id(@select_object)
	IF @selectid IS NULL BEGIN RAISERROR(@msg,16,1,@select_object) RETURN END
END

IF @update_object IS NOT NULL 
BEGIN
	SET @updateid=OBJECT_id(@update_object)
	IF @updateid IS NULL BEGIN RAISERROR(@msg,16,1,@update_object) RETURN END
END

IF @insert_object IS NOT NULL 
BEGIN
	SET @insertid=OBJECT_id(@insert_object)
	IF @insertid IS NULL BEGIN RAISERROR(@msg,16,1,@insert_object) RETURN END
END

IF @delete_object IS NOT NULL 
BEGIN
	SET @deleteid=OBJECT_id(@delete_object)
	IF @deleteid IS NULL BEGIN RAISERROR(@msg,16,1,@delete_object) RETURN END
END

INSERT dbo.PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(@object_id, @object, @selectid, @updateid, @insertid, @deleteid, @permission_mask)
GO
CREATE PROC dbo.spPermissionObjectXInsert
	@object_id int,
	@permission int,
	@proc sysname
AS
DECLARE @procid int
SELECT @procid=OBJECT_id(@proc)
IF @procid IS NULL BEGIN RAISERROR('Stored proc does not exist: %s',16,1,@proc) RETURN END
INSERT dbo.PermissionObjectX(ObjectID, Permission, StoredProcID)
SELECT @object_id, @permission, @procid
GO
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [id] = OBJECT_id('Project') AND colstat=1)
BEGIN
	-- Makes Project.ProjectID an identity column
	BEGIN TRAN
	ALTER TABLE dbo.Project DROP CONSTRAINT FK_Project_Class
	ALTER TABLE dbo.Project DROP CONSTRAINT FK_Project_Location
	ALTER TABLE dbo.Project DROP CONSTRAINT FK_Project_Employee
	
	CREATE TABLE dbo.Tmp_Project
		(
		ProjectID int NOT NULL IDENTITY (1, 1),
		Project varchar(50) NOT NULL,
		ProjectManagerID int NULL,
		LocationID int NOT NULL,
		Active bit NOT NULL,
		[Pay Rate] smallmoney NULL,
		[Billing Rate] smallmoney NULL,
		Note varchar(4000) NOT NULL,
		ClassID int NOT NULL,
		[Fixed Pay] smallmoney NULL,
		[Fixed Billing] smallmoney NULL
		)  ON [PRIMARY]
	
	SET IDENTITY_INSERT dbo.Tmp_Project ON
	
	IF EXISTS(SELECT * FROM dbo.Project)
		 EXEC('INSERT INTO dbo.Tmp_Project (ProjectID, Project, ProjectManagerID, LocationID, Active, [Pay Rate], [Billing Rate], Note, ClassID, [Fixed Pay], [Fixed Billing])
			SELECT ProjectID, Project, ProjectManagerID, LocationID, Active, [Pay Rate], [Billing Rate], Note, ClassID, [Fixed Pay], [Fixed Billing] FROM dbo.Project (HOLDLOCK TABLOCKX)')
	
	SET IDENTITY_INSERT dbo.Tmp_Project OFF
	
	ALTER TABLE dbo.EmployeeProject DROP CONSTRAINT FK_EmployeeProject_Project
	ALTER TABLE dbo.ProjectTask DROP CONSTRAINT FK_ProjectTask_Project
	ALTER TABLE dbo.EmployeeTime DROP CONSTRAINT FK_EmployeeTime_Project
	DROP TABLE dbo.Project
	EXECUTE sp_rename N'dbo.Tmp_Project', N'Project', 'OBJECT'
	IF OBJECT_id('Project') IS NOT NULL AND OBJECT_id('dbo.Project') IS NULL
	EXEC dbo.sp_changeobjectowner 'Project', 'dbo'
	
	ALTER TABLE dbo.Project ADD CONSTRAINT PK_Project PRIMARY KEY CLUSTERED (ProjectID) ON [PRIMARY]
	ALTER TABLE dbo.Project WITH NOCHECK ADD CONSTRAINT FK_Project_Employee FOREIGN KEY (ProjectManagerID) REFERENCES dbo.Employee(EmployeeID)
	ALTER TABLE dbo.Project WITH NOCHECK ADD CONSTRAINT FK_Project_Location FOREIGN KEY (LocationID) REFERENCES dbo.Location(LocationID)
	ALTER TABLE dbo.Project WITH NOCHECK ADD CONSTRAINT FK_Project_Class FOREIGN KEY(ClassID) REFERENCES dbo.ProjectClass(ClassID)
	ALTER TABLE dbo.EmployeeTime WITH NOCHECK ADD CONSTRAINT FK_EmployeeTime_Project FOREIGN KEY(ProjectID) REFERENCES dbo.Project(ProjectID)
	ALTER TABLE dbo.ProjectTask WITH NOCHECK ADD CONSTRAINT FK_ProjectTask_Project FOREIGN KEY(ProjectID) REFERENCES dbo.Project(ProjectID)
	ALTER TABLE dbo.EmployeeProject WITH NOCHECK ADD CONSTRAINT FK_EmployeeProject_Project FOREIGN KEY(ProjectID) REFERENCES dbo.Project(ProjectID)
	COMMIT TRAN
END
GO
UPDATE Constant SET [Server Version]=56
GO
IF NOT EXISTS(SELECT * FROM dbo.syscolumns WHERE [name]='PreapprovedEmployeeID' AND [id]=OBJECT_id('dbo.EmployeeLeaveUsed'))
BEGIN
BEGIN TRAN

	ALTER TABLE dbo.EmployeeLeaveUsed ADD PreapprovedEmployeeID int NULL
	ALTER TABLE dbo.EmployeeLeaveUsed ADD [Preapproved Day Past 1900] int NULL

	ALTER TABLE dbo.EmployeeLeaveUsed WITH NOCHECK ADD CONSTRAINT FK_EmployeeLeaveUsed_PreapprovalEmployee FOREIGN KEY(PreapprovedEmployeeID) REFERENCES dbo.Employee(EmployeeID)
COMMIT TRAN
END
GO
IF OBJECT_id('dbo.spEmployeeLeaveUsedPreApprove') IS NOT NULL DROP PROC dbo.spEmployeeLeaveUsedPreApprove
GO
CREATE PROC dbo.spEmployeeLeaveUsedPreApprove
	@leave_id int
AS
DECLARE @employee_id int
SELECT @employee_id=EmployeeID FROM Employee WHERE SID=SUSER_SID()
IF @@ROWCOUNT=0 RETURN
UPDATE EmployeeLeaveUsed SET [Preapproved Day Past 1900]=DATEDIFF(d,0,GETDATE()),PreapprovedEmployeeID=@employee_id WHERE LeaveID=@leave_id AND PreapprovedEmployeeID IS NULL
GO
GRANT EXEC ON dbo.spEmployeeLeaveUsedPreApprove TO public
GO
IF OBJECT_id('dbo.InOutStatus') IS NULL
BEGIN
	BEGIN TRAN

	CREATE TABLE dbo.InOutStatus (
		StatusID int NOT NULL IDENTITY(1,1) PRIMARY KEY,
		Status varchar(50) NOT NULL,
		[In] bit,
		Color int,
		[Order] int
	)
	
	INSERT InOutStatus(Status,[In],Color,[Order]) VALUES('In', 1, 0x00FF00, 1)
	INSERT InOutStatus(Status,[In],Color,[Order]) VALUES('Gone for Day', 0, 0xFF0000, 2)
	INSERT InOutStatus(Status,[In],Color,[Order]) VALUES('Out to Lunch', 0, 0xFF0000, 3)
	INSERT InOutStatus(Status,[In],Color,[Order]) VALUES('On Leave', 0, 0xFF0000, 4)
	INSERT InOutStatus(Status,[In],Color,[Order]) VALUES('Offsite', 0, 0xFF0000, 5)
	INSERT InOutStatus(Status,[In],Color,[Order]) VALUES('On Call', 0, 0xFF0000, 6)


	COMMIT TRAN
END
GO
IF OBJECT_id('dbo.vwInOutStatus') IS NOT NULL DROP VIEW dbo.vwInOutStatus
IF OBJECT_id('vwInOutStatus') IS NOT NULL DROP VIEW vwInOutStatus
IF OBJECT_id('dbo.spInOutStatusDelete') IS NOT NULL DROP PROC dbo.spInOutStatusDelete
IF OBJECT_id('dbo.spInOutStatusInsert') IS NOT NULL DROP PROC dbo.spInOutStatusInsert
IF OBJECT_id('dbo.spInOutStatusUpdate') IS NOT NULL DROP PROC dbo.spInOutStatusUpdate
IF OBJECT_id('dbo.spInOutStatusSelect') IS NOT NULL DROP PROC dbo.spInOutStatusSelect
IF OBJECT_id('dbo.spInOutStatusList') IS NOT NULL DROP PROC dbo.spInOutStatusList
IF OBJECT_id('dbo.spInOutStatusMoveDown') IS NOT NULL DROP PROC dbo.spInOutStatusMoveDown
IF OBJECT_id('dbo.spInOutStatusMoveUp') IS NOT NULL DROP PROC dbo.spInOutStatusMoveUp
IF OBJECT_id('dbo.spInOutStatusStraighten') IS NOT NULL DROP PROC dbo.spInOutStatusStraighten
IF OBJECT_id('dbo.spInOutStatusGetFirst') IS NOT NULL DROP PROC dbo.spInOutStatusGetFirst
GO
CREATE VIEW dbo.vwInOutStatus AS SELECT * FROM InOutStatus
GO
CREATE PROC dbo.spInOutStatusGetFirst
	@in bit,
	@status_id int OUT
AS
SET @status_id = NULL
SELECT TOP 1 @status_id=StatusID FROM InOutStatus WHERE [In] = @in ORDER BY [Order]
GO
-- Ensures that InOutStatus.Order is unique
CREATE PROC dbo.spInOutStatusStraighten
AS
DECLARE @status_id int

SET NOCOUNT ON

SELECT TOP 1 @status_id = MIN(StatusID) FROM InOutStatus GROUP BY [Order] HAVING COUNT(*) > 1
WHILE @@ROWCOUNT > 0
BEGIN
	UPDATE [InOutStatus] SET [Order] = [Order] + 1 WHERE StatusID = @status_id
	SELECT TOP 1 @status_id = MIN(StatusID) FROM InOutStatus GROUP BY [Order] HAVING COUNT(*) > 1
END
GO
CREATE PROC dbo.spInOutStatusMoveDown
	@status_id int
AS
DECLARE @next_Status_id int
DECLARE @order int, @next_order int

SET NOCOUNT ON

SELECT @order = [Order] FROM InOutStatus WHERE StatusID = @status_id
SELECT TOP 1 @next_Status_id = StatusID FROM InOutStatus WHERE [Order] > @order ORDER BY [Order]
SELECT @next_order = [Order] FROM InOutStatus WHERE StatusID = @next_Status_id

IF @next_order IS NOT NULL
BEGIN
	UPDATE InOutStatus SET [Order] = @next_order WHERE StatusID = @status_id
	UPDATE InOutStatus SET [Order] = @order WHERE StatusID = @next_Status_id
END
EXEC dbo.spInOutStatusStraighten

GO
CREATE PROC dbo.spInOutStatusMoveUp
	@status_id int
AS
DECLARE @previous_requirement_id int
DECLARE @order int, @previous_order int

SET NOCOUNT ON

SELECT @order = [Order] FROM InOutStatus WHERE StatusID = @status_id
SELECT TOP 1 @previous_requirement_id = StatusID FROM InOutStatus WHERE [Order] < @order ORDER BY [Order] DESC
SELECT @previous_order = [Order] FROM InOutStatus WHERE StatusID = @previous_requirement_id

IF @previous_order IS NOT NULL
BEGIN
	UPDATE InOutStatus SET [Order] = @previous_order WHERE StatusID = @status_id
	UPDATE InOutStatus SET [Order] = @order WHERE StatusID = @previous_requirement_id
END
EXEC dbo.spInOutStatusStraighten

GO
CREATE PROC dbo.spInOutStatusDelete @status_id int AS DELETE InOutStatus WHERE StatusID=@status_id
GO
CREATE PROC dbo.spInOutStatusInsert
	@status varchar(50),
	@in bit,
	@color int,
	@status_id int OUT
AS
DECLARE @order int
SET @order = ISNULL((SELECT MAX([Order]) FROM InOutStatus), 0) + 1
INSERT InOutStatus(Status,[In],Color,[Order]) VALUES(@status,@in,@color,@order)
SELECT @status_id=SCOPE_IDENTITY()
GO
CREATE PROC dbo.spInOutStatusUpdate
	@status varchar(50),
	@in bit,
	@color int,
	@status_id int
AS
UPDATE InOutStatus SET Status=@status,[In]=@in,Color=@color WHERE StatusID=@status_id
GO
CREATE PROC dbo.spInOutStatusList AS SET NOCOUNT ON SELECT * FROM vwInOutStatus ORDER BY [Order]
GO
CREATE PROC dbo.spInOutStatusSelect @status_id int AS SET NOCOUNT ON SELECT * FROM vwInOutStatus WHERE StatusID=@status_id
GO
GRANT EXEC ON dbo.spInOutStatusGetFirst TO public
GRANT EXEC ON dbo.spInOutStatusMoveUp TO public
GRANT EXEC ON dbo.spInOutStatusMoveDown TO public
GRANT EXEC ON dbo.spInOutStatusStraighten TO public
GRANT EXEC ON dbo.spInOutStatusDelete TO public
GRANT EXEC ON dbo.spInOutStatusInsert TO public
GRANT EXEC ON dbo.spInOutStatusUpdate TO public
GRANT EXEC ON dbo.spInOutStatusSelect TO public
GRANT EXEC ON dbo.spInOutStatusList TO public
GO
IF NOT EXISTS(SELECT * FROM dbo.syscolumns WHERE [id] = OBJECT_id('Project') AND colstat=1)
BEGIN
	-- Makes Project.ProjectID an identity column
	BEGIN TRAN
	ALTER TABLE dbo.Project DROP CONSTRAINT FK_Project_Class
	ALTER TABLE dbo.Project DROP CONSTRAINT FK_Project_Location
	ALTER TABLE dbo.Project DROP CONSTRAINT FK_Project_Employee
	
	CREATE TABLE dbo.Tmp_Project
		(
		ProjectID int NOT NULL IDENTITY (1, 1),
		Project varchar(50) NOT NULL,
		ProjectManagerID int NULL,
		LocationID int NOT NULL,
		Active bit NOT NULL,
		[Pay Rate] smallmoney NULL,
		[Billing Rate] smallmoney NULL,
		Note varchar(4000) NOT NULL,
		ClassID int NOT NULL,
		[Fixed Pay] smallmoney NULL,
		[Fixed Billing] smallmoney NULL
		)  ON [PRIMARY]
	
	SET IDENTITY_INSERT dbo.Tmp_Project ON
	
	IF EXISTS(SELECT * FROM dbo.Project)
		 EXEC('INSERT INTO dbo.Tmp_Project (ProjectID, Project, ProjectManagerID, LocationID, Active, [Pay Rate], [Billing Rate], Note, ClassID, [Fixed Pay], [Fixed Billing])
			SELECT ProjectID, Project, ProjectManagerID, LocationID, Active, [Pay Rate], [Billing Rate], Note, ClassID, [Fixed Pay], [Fixed Billing] FROM dbo.Project (HOLDLOCK TABLOCKX)')
	
	SET IDENTITY_INSERT dbo.Tmp_Project OFF
	
	ALTER TABLE dbo.EmployeeProject DROP CONSTRAINT FK_EmployeeProject_Project
	ALTER TABLE dbo.ProjectTask DROP CONSTRAINT FK_ProjectTask_Project
	ALTER TABLE dbo.EmployeeTime DROP CONSTRAINT FK_EmployeeTime_Project
	DROP TABLE dbo.Project
	EXECUTE sp_rename N'dbo.Tmp_Project', N'Project', 'OBJECT'
	IF OBJECT_id('Project') IS NOT NULL AND OBJECT_id('dbo.Project') IS NULL EXEC dbo.sp_changeobjectowner 'Project', 'dbo'
	
	ALTER TABLE dbo.Project ADD CONSTRAINT PK_Project PRIMARY KEY CLUSTERED (ProjectID)
	ALTER TABLE dbo.Project WITH NOCHECK ADD CONSTRAINT FK_Project_Employee FOREIGN KEY (ProjectManagerID) REFERENCES dbo.Employee(EmployeeID)
	ALTER TABLE dbo.Project WITH NOCHECK ADD CONSTRAINT FK_Project_Location FOREIGN KEY (LocationID) REFERENCES dbo.Location(LocationID)
	ALTER TABLE dbo.Project WITH NOCHECK ADD CONSTRAINT FK_Project_Class FOREIGN KEY(ClassID) REFERENCES dbo.ProjectClass(ClassID)
	ALTER TABLE dbo.EmployeeTime WITH NOCHECK ADD CONSTRAINT FK_EmployeeTime_Project FOREIGN KEY(ProjectID) REFERENCES dbo.Project(ProjectID)
	ALTER TABLE dbo.ProjectTask WITH NOCHECK ADD CONSTRAINT FK_ProjectTask_Project FOREIGN KEY(ProjectID) REFERENCES dbo.Project(ProjectID)
	ALTER TABLE dbo.EmployeeProject WITH NOCHECK ADD CONSTRAINT FK_EmployeeProject_Project FOREIGN KEY(ProjectID) REFERENCES dbo.Project(ProjectID)
	COMMIT TRAN
END
GO
IF OBJECT_id('dbo.spEmployeeDependentGetEmployeeID') IS NOT NULL DROP PROC dbo.spEmployeeDependentGetEmployeeID
GO
CREATE PROC dbo.spEmployeeDependentGetEmployeeID
	@contact_id int,
	@employee_id int OUT
AS
SELECT @employee_id = NULL
SELECT @employee_id = EmployeeID FROM EmployeeDependent WHERE ContactID = @contact_id
GO
ALTER PROC dbo.spPermissionObjectInsert
	@object_id int,
	@object  varchar(50),
	@select_object sysname,
	@update_object sysname,
	@insert_object sysname,
	@delete_object sysname,
	@permission_mask int
AS
DECLARE @msg nvarchar(400)
DECLARE @selectid int, @updateid int, @insertid int, @deleteid int
SELECT @selectid=0,@updateid=0,@insertid=0,@deleteid=0,@msg='Stored proc does not exist: %s'

IF @select_object IS NOT NULL 
BEGIN
	SET @selectid=OBJECT_id(@select_object)
	IF @selectid IS NULL BEGIN RAISERROR(@msg,16,1,@select_object) RETURN END
END

IF @update_object IS NOT NULL 
BEGIN
	SET @updateid=OBJECT_id(@update_object)
	IF @updateid IS NULL BEGIN RAISERROR(@msg,16,1,@update_object) RETURN END
END

IF @insert_object IS NOT NULL 
BEGIN
	SET @insertid=OBJECT_id(@insert_object)
	IF @insertid IS NULL BEGIN RAISERROR(@msg,16,1,@insert_object) RETURN END
END

IF @delete_object IS NOT NULL 
BEGIN
	SET @deleteid=OBJECT_id(@delete_object)
	IF @deleteid IS NULL BEGIN RAISERROR(@msg,16,1,@delete_object) RETURN END
END

IF EXISTS(SELECT * FROM PermissionObject WHERE ObjectID=@object_id)
BEGIN
	UPDATE dbo.PermissionObject SET Object=@object,SelectObjectID=@selectid,UpdateObjectID=@updateid,InsertObjectID=@insertid,DeleteObjectID=@deleteid,[Permission Possible Mask]=@permission_mask WHERE ObjectID=@object_id
	DELETE PermissionObjectX WHERE ObjectID=@object_id
END
ELSE
	INSERT dbo.PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
	VALUES(@object_id, @object, @selectid, @updateid, @insertid, @deleteid, @permission_mask)
GO
EXEC dbo.spPermissionObjectInsert 48,'Time In Out Choices',NULL,'dbo.spInOutStatusUpdate','dbo.spInOutStatusInsert','dbo.spInOutStatusDelete',14
EXEC dbo.spPermissionObjectXInsert 48, 2, 'dbo.spInOutStatusMoveUp'
EXEC dbo.spPermissionObjectXInsert 48, 2, 'dbo.spInOutStatusMoveDown'
GO
UPDATE Error SET Error='An employee can only have one accrual plan that does not specify a stop date. Enter a stop date for the first plan and try again.' WHERE ErrorID=50022




IF NOT EXISTS(SELECT * FROM Error WHERE ErrorID=50049) INSERT Error(ErrorID,Error) VALUES(50049,'The employee does not exists in the database.')
IF OBJECT_id('dbo.spErrorRaiseNoEmployee') IS NOT NULL DROP PROC dbo.spErrorRaiseNoEmployee
GO
CREATE PROC dbo.spErrorRaiseNoEmployee
	@employee_id int
AS
DECLARE @description varchar(400)
SELECT @description = [Error] + ' (EmployeeID %d).' FROM Error WHERE ErrorID = 50049
RAISERROR (@description, 16, 1, @employee_id)
GO
ALTER PROC dbo.spEmployeeGetTimeSchemaID
	@employee_id int,
	@schema_id int OUT
AS
SELECT @schema_id = TimeSchemaID FROM Employee WHERE EmployeeID = @employee_id
IF @@ROWCOUNT=0 EXEC dbo.spErrorRaiseNoEmployee @employee_id
GO
ALTER TABLE dbo.Constant ALTER COLUMN [Reminder E-mail Sender] varchar(50) NOT NULL
ALTER TABLE dbo.Constant ALTER COLUMN [Reminder E-mail Last Result] varchar(4000) NOT NULL
GO


IF NOT EXISTS(SELECT * FROM Error WHERE ErrorID=50049) INSERT Error(ErrorID,Error) VALUES(50049,'The employee does not exists in the database.')
IF OBJECT_id('dbo.spErrorRaiseNoEmployee') IS NOT NULL DROP PROC dbo.spErrorRaiseNoEmployee
IF OBJECT_id('dbo.NormalizeSSN') IS NOT NULL DROP FUNCTION dbo.NormalizeSSN
GO
CREATE FUNCTION dbo.NormalizeSSN(@ssn varchar(50)) RETURNS varchar(50) AS
BEGIN
	SET @ssn = RTRIM(LTRIM(@ssn))
	IF LEN(@ssn) = 9 SET @ssn=SUBSTRING(@ssn,0,3)+'-'+SUBSTRING(@ssn,3,2)+'-'+SUBSTRING(@ssn,5,4)
	RETURN @ssn
END
GO
CREATE PROC dbo.spErrorRaiseNoEmployee
	@employee_id int
AS
DECLARE @description varchar(400)
SELECT @description = [Error] + ' (EmployeeID %d).' FROM Error WHERE ErrorID = 50049
RAISERROR (@description, 16, 1, @employee_id)
GO
ALTER PROC dbo.spEmployeeHire
	@employee_id int,
	@doh int
AS
DECLARE @authorized bit

SET NOCOUNT ON

-- Requires update permission on org and termination
EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 8, 2, @authorized out
IF @authorized = 1 EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 0x1000000, 2, @authorized out

IF @authorized = 1 UPDATE Employee SET [Seniority Begins Day past 1900] = @doh, [Terminated Day past 1900] = NULL, [Active Employee] = 1 WHERE EmployeeID = @employee_id
GO
ALTER PROC dbo.spEmployeeGetTimeSchemaID
	@employee_id int,
	@schema_id int OUT
AS
SELECT @schema_id = TimeSchemaID FROM Employee WHERE EmployeeID = @employee_id
IF @@ROWCOUNT=0 EXEC dbo.spErrorRaiseNoEmployee @employee_id
GO
ALTER PROC dbo.spPersonXGetPersonIDFromSSN
	@ssn varchar(50),
	@person_id int out
AS
SELECT @person_id = PersonID FROM PersonX WHERE SSN = dbo.NormalizeSSN(@ssn)
GO
GO
-- Adds new fields to equipment
IF NOT EXISTS(SELECT * FROM dbo.syscolumns WHERE [name]='ReturnedByEmployeeID' AND [id]=OBJECT_id('dbo.Equipment'))
BEGIN
BEGIN TRAN
	ALTER TABLE dbo.Equipment ADD ReturnedByEmployeeID int NULL
	ALTER TABLE dbo.Equipment ADD CheckedOutByEmployeeID int NULL
	ALTER TABLE dbo.Equipment ADD [Returned Day past 1900] int NULL
	ALTER TABLE dbo.Equipment ADD [Last Price] money NULL
	ALTER TABLE dbo.Equipment ADD [Last Price Day past 1900] int NULL
	ALTER TABLE dbo.Equipment WITH NOCHECK ADD CONSTRAINT FK_Equipment_Returned_By FOREIGN KEY(ReturnedByEmployeeID) REFERENCES dbo.Employee(EmployeeID)
	ALTER TABLE dbo.Equipment WITH NOCHECK ADD CONSTRAINT FK_Equipment_Checked_Out_By FOREIGN KEY(CheckedOutByEmployeeID) REFERENCES dbo.Employee(EmployeeID)
COMMIT TRAN
END
GO
IF OBJECT_id('dbo.EmployeeTimeAcroprintQ') IS NULL
CREATE TABLE dbo.EmployeeTimeAcroprintQ (
	[ItemID] [int] IDENTITY (1, 1) NOT NULL PRIMARY KEY,
	[Badge] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Terminal] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Time] [char] (6) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Date] [char] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Created] [smalldatetime] NOT NULL DEFAULT GETDATE(),
	[Imported] [smalldatetime] NULL,
	EmployeeID int NULL
)
GO
IF OBJECT_id('dbo.spPositionDeleteAll') IS NULL EXEC sp_executesql N'CREATE PROC dbo.spPositionDeleteAll AS'
GO
ALTER PROC dbo.spPositionDeleteAll
AS
UPDATE EmployeeCompensation SET PositionID = (SELECT TOP 1 PositionID FROM Position)
DELETE Position WHERE PositionID NOT IN (SELECT PositionID FROM EmployeeCompensation)

UPDATE Position SET [Job Title] = 'Edit Me'
GO
ALTER PROC dbo.spLeaveGetUseOrLoseDay
	@employee_id int,
	@type_id int,
	@day_in int,
	@date datetime out
AS
DECLARE @day_out int
SELECT @day_out = ISNULL(MIN([Day past 1900]), 0x7FFFFFFF) FROM vwEmployeeLeaveEarned WHERE [Limit Adjustment] = 1 AND EmployeeID = @employee_id AND TypeID = @type_id AND [Day past 1900] >= @day_in
SET @date = dbo.GetDateFromDaysPast1900(@day_out)
GO
IF OBJECT_id('CK_EmployeeLeaveUsedItem_SecondsExceedOneDay') IS NOT NULL
ALTER TABLE EmployeeLeaveUsedItem DROP CONSTRAINT CK_EmployeeLeaveUsedItem_SecondsExceedOneDay
GO
ALTER PROC dbo.spEmployeeTDRPList
	@employee_id int
AS
DECLARE @authorized bit

SET NOCOUNT ON

EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 536870912, 1, @authorized out

IF @authorized = 1
BEGIN
	DECLARE @write_permission bit, @employee varchar(400)
	EXEC dbo.spPermissionGetOnPersonForCurrentUser2 @employee_id, 536870912, 2, @write_permission out

	SELECT @employee = [List As] FROM dbo.vwPersonListAs WHERE PersonID = @employee_id

	SELECT
	T.TDRPID,
	T.TDRP,
	EmployeeID = @employee_id,
	Employee = ISNULL(@employee, '<Deleted>'),
	ET.Eligible, ET.[Eligible Day past 1900],
	ET.Notified, ET.[Notified Day past 1900],
	ET.Expires, ET.[Expires Day past 1900],
	ET.[First Enrolled], ET.[First Enrolled Day past 1900],
	ET.[Last Enrolled], ET.[Last Enrolled Day past 1900],
	ET.Declined, ET.[Declined Day past 1900],
	Enrollment = ISNULL(ET.Enrollment, ''),
	[Employee Contribution] = ISNULL(ET.[Employee Contribution], 0),
	[Employer Contribution] = ISNULL(ET.[Employer Contribution], 0),
	Note = ISNULL(ET.Note, ''),
	[Catch Up] = ISNULL(ET.[Catch Up], 0), 
	[Loan Repay] = ISNULL(ET.[Loan Repay], 0), 
	[Employee Fixed] = ISNULL(ET.[Employee Fixed], 0), 
	[Employer Fixed] = ISNULL(ET.[Employer Fixed], 0),
	[Write Permission] = @write_permission 
	FROM TDRP T
	LEFT JOIN vwEmployeeTDRP ET ON ET.TDRPID = T.TDRPID AND ET.EmployeeID = @employee_id ORDER BY T.TDRP
END
GO
IF OBJECT_id('dbo.spEmployeeLeaveUsedGetForAdoption') IS NOT NULL DROP PROC dbo.spEmployeeLeaveUsedGetForAdoption
GO
CREATE PROC dbo.spEmployeeLeaveUsedGetForAdoption
	@employee_id int,
	@advanced_type_mask int,
	@reference_day int,
	@plus_minus int,
	@leave_id int OUT
AS
DECLARE @authorized bit

EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 10001, 1, @authorized out

IF @authorized = 1 
BEGIN
	SET @leave_id = NULL

	SELECT TOP 1 @leave_id = LeaveID FROM EmployeeLeaveUsed WHERE Status = 2 AND EmployeeID = @employee_id AND [Advanced Type Mask] = @advanced_type_mask AND @reference_day BETWEEN [Start Day past 1900] AND [Stop Day past 1900]
	ORDER BY [Stop Day past 1900] DESC

	IF @leave_id IS NULL
	SELECT TOP 1 @leave_id = LeaveID FROM EmployeeLeaveUsed WHERE Status = 2 AND EmployeeID = @employee_id AND [Advanced Type Mask] = @advanced_type_mask AND [Stop Day past 1900] >= @reference_day - @plus_minus
	ORDER BY [Stop Day past 1900] DESC

	IF @leave_id IS NULL
	SELECT TOP 1 @leave_id = LeaveID FROM EmployeeLeaveUsed WHERE Status = 2 AND  EmployeeID = @employee_id AND [Advanced Type Mask] = @advanced_type_mask AND [Start Day past 1900] <= @reference_day + @plus_minus
	ORDER BY [Stop Day past 1900] DESC
END
GO
GRANT EXEC ON dbo.spEmployeeLeaveUsedGetForAdoption TO public
GO
IF OBJECT_id('dbo.spEmployeeGetEmployeeIDFromSAM') IS NOT NULL DROP PROC dbo.spEmployeeGetEmployeeIDFromSAM
GO
CREATE PROC dbo.spEmployeeGetEmployeeIDFromSAM
	@sam sysname,
	@employee_id int out
AS
SELECT @employee_id=NULL
SELECT @employee_id=EmployeeID FROM Employee WHERE SID = SUSER_SID(@sam)
GO
GRANT EXEC ON dbo.spEmployeeGetEmployeeIDFromSAM TO public
GO
IF NOT EXISTS (SELECT * FROM syscolumns WHERE [name]='Advanced Type Mask' AND [id] = OBJECT_id('dbo.EmployeeLeaveUsedItem'))
BEGIN
	ALTER TABLE dbo.EmployeeLeaveUsedItem ADD [Advanced Type Mask] int NOT NULL DEFAULT(0)
	EXEC ('UPDATE I SET [Advanced Type Mask]=U.[Advanced Type Mask] FROM EmployeeLeaveUsed U INNER JOIN EmployeeLeaveUsedItem I ON U.LeaveID=I.LeaveID')
END
GO
UPDATE dbo.ColumnGrid SET [Order]=100 WHERE FieldID=1
UPDATE dbo.ColumnGrid SET [Order]=200 WHERE FieldID=2
UPDATE dbo.ColumnGrid SET [Order]=300 WHERE FieldID=3
UPDATE dbo.ColumnGrid SET [Order]=400 WHERE FieldID=4
UPDATE dbo.ColumnGrid SET [Order]=500 WHERE FieldID=5
UPDATE dbo.ColumnGrid SET [Order]=600 WHERE FieldID=6
UPDATE dbo.ColumnGrid SET [Order]=700 WHERE FieldID=84
UPDATE dbo.ColumnGrid SET [Order]=800 WHERE FieldID=71
UPDATE dbo.ColumnGrid SET [Order]=900 WHERE FieldID=72
UPDATE dbo.ColumnGrid SET [Order]=1000 WHERE FieldID=61
UPDATE dbo.ColumnGrid SET [Order]=1100 WHERE FieldID=56
UPDATE dbo.ColumnGrid SET [Order]=1200 WHERE FieldID=100
UPDATE dbo.ColumnGrid SET [Order]=1300 WHERE FieldID=101
UPDATE dbo.ColumnGrid SET [Order]=1400 WHERE FieldID=83
UPDATE dbo.ColumnGrid SET [Order]=1500 WHERE FieldID=8
UPDATE dbo.ColumnGrid SET [Order]=1600 WHERE FieldID=9
UPDATE dbo.ColumnGrid SET [Order]=1700 WHERE FieldID=7
UPDATE dbo.ColumnGrid SET [Order]=1800 WHERE FieldID=10
UPDATE dbo.ColumnGrid SET [Order]=1900 WHERE FieldID=11
UPDATE dbo.ColumnGrid SET [Order]=2000 WHERE FieldID=12
UPDATE dbo.ColumnGrid SET [Order]=2100 WHERE FieldID=13
UPDATE dbo.ColumnGrid SET [Order]=2200 WHERE FieldID=14
UPDATE dbo.ColumnGrid SET [Order]=2300 WHERE FieldID=15
UPDATE dbo.ColumnGrid SET [Order]=2400 WHERE FieldID=16
UPDATE dbo.ColumnGrid SET [Order]=2500 WHERE FieldID=1028
UPDATE dbo.ColumnGrid SET [Order]=2600 WHERE FieldID=17
UPDATE dbo.ColumnGrid SET [Order]=2700 WHERE FieldID=18
UPDATE dbo.ColumnGrid SET [Order]=2800 WHERE FieldID=19
UPDATE dbo.ColumnGrid SET [Order]=2900 WHERE FieldID=20
UPDATE dbo.ColumnGrid SET [Order]=3000 WHERE FieldID=21
UPDATE dbo.ColumnGrid SET [Order]=3100 WHERE FieldID=22
UPDATE dbo.ColumnGrid SET [Order]=3200 WHERE FieldID=23
UPDATE dbo.ColumnGrid SET [Order]=3300 WHERE FieldID=24
UPDATE dbo.ColumnGrid SET [Order]=3400 WHERE FieldID=25
UPDATE dbo.ColumnGrid SET [Order]=3500 WHERE FieldID=1027
UPDATE dbo.ColumnGrid SET [Order]=3600 WHERE FieldID=26
UPDATE dbo.ColumnGrid SET [Order]=3700 WHERE FieldID=27
UPDATE dbo.ColumnGrid SET [Order]=3800 WHERE FieldID=28
UPDATE dbo.ColumnGrid SET [Order]=3900 WHERE FieldID=29
UPDATE dbo.ColumnGrid SET [Order]=4000 WHERE FieldID=30
UPDATE dbo.ColumnGrid SET [Order]=4100 WHERE FieldID=31
UPDATE dbo.ColumnGrid SET [Order]=1010 WHERE FieldID=33
UPDATE dbo.ColumnGrid SET [Order]=4300 WHERE FieldID=34
UPDATE dbo.ColumnGrid SET [Order]=4400 WHERE FieldID=32
UPDATE dbo.ColumnGrid SET [Order]=4500 WHERE FieldID=35
UPDATE dbo.ColumnGrid SET [Order]=4600 WHERE FieldID=36
UPDATE dbo.ColumnGrid SET [Order]=4700 WHERE FieldID=37
UPDATE dbo.ColumnGrid SET [Order]=4800 WHERE FieldID=39
UPDATE dbo.ColumnGrid SET [Order]=4900 WHERE FieldID=40
UPDATE dbo.ColumnGrid SET [Order]=5000 WHERE FieldID=41
UPDATE dbo.ColumnGrid SET [Order]=5100 WHERE FieldID=42
UPDATE dbo.ColumnGrid SET [Order]=5200 WHERE FieldID=43
UPDATE dbo.ColumnGrid SET [Order]=5300 WHERE FieldID=44
UPDATE dbo.ColumnGrid SET [Order]=5400 WHERE FieldID=45
UPDATE dbo.ColumnGrid SET [Order]=5500 WHERE FieldID=46
UPDATE dbo.ColumnGrid SET [Order]=5600 WHERE FieldID=47
UPDATE dbo.ColumnGrid SET [Order]=5700 WHERE FieldID=48
UPDATE dbo.ColumnGrid SET [Order]=5800 WHERE FieldID=49
UPDATE dbo.ColumnGrid SET [Order]=5900 WHERE FieldID=50
UPDATE dbo.ColumnGrid SET [Order]=6000 WHERE FieldID=51
UPDATE dbo.ColumnGrid SET [Order]=6100 WHERE FieldID=52
UPDATE dbo.ColumnGrid SET [Order]=6200 WHERE FieldID=1029
UPDATE dbo.ColumnGrid SET [Order]=6300 WHERE FieldID=53
UPDATE dbo.ColumnGrid SET [Order]=6400 WHERE FieldID=54
UPDATE dbo.ColumnGrid SET [Order]=6500 WHERE FieldID=55
UPDATE dbo.ColumnGrid SET [Order]=6600 WHERE FieldID=58
UPDATE dbo.ColumnGrid SET [Order]=6700 WHERE FieldID=60
UPDATE dbo.ColumnGrid SET [Order]=6800 WHERE FieldID=59
UPDATE dbo.ColumnGrid SET [Order]=6900 WHERE FieldID=62
UPDATE dbo.ColumnGrid SET [Order]=7000 WHERE FieldID=63
UPDATE dbo.ColumnGrid SET [Order]=1350 WHERE FieldID=64
UPDATE dbo.ColumnGrid SET [Order]=7200 WHERE FieldID=65
UPDATE dbo.ColumnGrid SET [Order]=7300 WHERE FieldID=66
UPDATE dbo.ColumnGrid SET [Order]=7400 WHERE FieldID=67
UPDATE dbo.ColumnGrid SET [Order]=7500 WHERE FieldID=68
UPDATE dbo.ColumnGrid SET [Order]=7600 WHERE FieldID=69
UPDATE dbo.ColumnGrid SET [Order]=7700 WHERE FieldID=70
UPDATE dbo.ColumnGrid SET [Order]=7800 WHERE FieldID=99
UPDATE dbo.ColumnGrid SET [Order]=7900 WHERE FieldID=90
UPDATE dbo.ColumnGrid SET [Order]=8000 WHERE FieldID=93
UPDATE dbo.ColumnGrid SET [Order]=8100 WHERE FieldID=94
UPDATE dbo.ColumnGrid SET [Order]=8200 WHERE FieldID=95
UPDATE dbo.ColumnGrid SET [Order]=8300 WHERE FieldID=96
UPDATE dbo.ColumnGrid SET [Order]=8400 WHERE FieldID=97
UPDATE dbo.ColumnGrid SET [Order]=8500 WHERE FieldID=98
UPDATE dbo.ColumnGrid SET [Order]=8600 WHERE FieldID=1001
UPDATE dbo.ColumnGrid SET [Order]=8700 WHERE FieldID=1002
UPDATE dbo.ColumnGrid SET [Order]=8800 WHERE FieldID=1003
UPDATE dbo.ColumnGrid SET [Order]=8900 WHERE FieldID=1004
UPDATE dbo.ColumnGrid SET [Order]=9000 WHERE FieldID=1013
UPDATE dbo.ColumnGrid SET [Order]=9100 WHERE FieldID=1014
UPDATE dbo.ColumnGrid SET [Order]=9200 WHERE FieldID=1015
UPDATE dbo.ColumnGrid SET [Order]=9300 WHERE FieldID=1016
UPDATE dbo.ColumnGrid SET [Order]=9400 WHERE FieldID=1017
UPDATE dbo.ColumnGrid SET [Order]=9500 WHERE FieldID=1018
UPDATE dbo.ColumnGrid SET [Order]=9600 WHERE FieldID=1019
UPDATE dbo.ColumnGrid SET [Order]=9700 WHERE FieldID=1021
UPDATE dbo.ColumnGrid SET [Order]=9800 WHERE FieldID=1023
UPDATE dbo.ColumnGrid SET [Order]=9900 WHERE FieldID=1024

UPDATE dbo.ColumnGrid SET Importable=1 WHERE FieldID=71
UPDATE dbo.ColumnGrid SET [Table]='', [Label]='Annualized Pay', Importable=1 WHERE FieldID=64
UPDATE dbo.ColumnGrid SET Importable=1, [Order]=1005 WHERE FieldID=1003

IF NOT EXISTS(SELECT * FROM ColumnGrid WHERE FieldID=103)
INSERT ColumnGrid(FieldID,[Table],[Key],colid,AttributeID,Field,Label,Importable,Reportable,[Order])
SELECT 103,'','',0,1,'Hourly Pay','Hourly Pay',1,1,1360

IF NOT EXISTS(SELECT * FROM ColumnGrid WHERE FieldID=100)
INSERT ColumnGrid(FieldID,[Table],[Key],colid,AttributeID,Field,Label,Importable,Reportable,[Order])
SELECT 100,'Employee','',0,1,'Pay Grade','Pay Grade',0,1,1200

IF NOT EXISTS(SELECT * FROM ColumnGrid WHERE FieldID=101)
INSERT ColumnGrid(FieldID,[Table],[Key],colid,AttributeID,Field,Label,Importable,Reportable,[Order])
SELECT 101,'Employee','',0,1,'Pay Step','Pay Step',0,1,1300

IF NOT EXISTS(SELECT * FROM ColumnGrid WHERE FieldID=102)
INSERT ColumnGrid(FieldID,[Table],[Key],colid,AttributeID,Field,Label,Importable,Reportable,[Order])
SELECT 102,'Employee','',0,1,'DOH','Date of Hire',0,1,6610
GO
CREATE PROC dbo.spEmployeeTimeListHolidayCredits
	@day int,
	@batch_id int
AS
DECLARE @date datetime
SET NOCOUNT ON
SELECT @date = dbo.GetDateFromDaysPast1900(@day)
SELECT E.EmployeeID, HH = 9, S.[Effective Seconds per Day], E.[Employee Number], TimeTypeID = E.DefaultTimeTypeID
INTO #E
FROM Employee E 
INNER JOIN TempX X ON X.BatchID = @batch_id AND E.EmployeeID = X.[ID]
INNER JOIN vwEmployeeEffectiveSecondsPerDay S ON E.EmployeeID = S.EmployeeID
INNER JOIN dbo.vwPersonListAs P ON E.EmployeeID = P.PersonID ORDER BY P.[List As]

-- Payroll delay
UPDATE #E SET HH = ISNULL((
 SELECT AVG(DATEPART(hh, DATEADD(n, 15, T.[In]))) FROM EmployeeTime T WHERE T.EmployeeID = #E.EmployeeID AND DATEPART(hh, T.[In]) BETWEEN 0 AND 10
), 9)
UPDATE #E SET HH = 0 WHERE 24.0 - HH < [Effective Seconds per Day] / 3600.0
SELECT #E.EmployeeID, #E.[Employee Number], [In] = DATEADD(hh, #E.HH, @date), Seconds = #E.[Effective Seconds per Day], #E.TimeTypeID
FROM #E

DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1
GO
GRANT EXEC ON dbo.spEmployeeTimeListHolidayCredits TO public
GO
ALTER PROC dbo.spLeaveStats
	@employee_id int,
	@requested_day int,
	@location_size int out,
	@employment_days int out,
	@seconds_worked_status int out,
	@seconds_worked_time_cards int out
AS
DECLARE @location_id int
DECLARE @authorized bit
DECLARE @now int
DECLARE @requested datetime

SET NOCOUNT ON

SELECT @location_id = 0, @location_size = 0
SELECT @requested = dbo.GetDateFromDaysPast1900(@requested_day)
SELECT @employment_days = 0, @seconds_worked_status = 0
SELECT @seconds_worked_time_cards = 0

EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 10003, 1, @authorized out
IF @authorized = 1 
BEGIN
	SELECT @location_id = LocationID FROM Employee WHERE EmployeeID = @employee_id
	SELECT @location_size = COUNT(*) FROM Employee WHERE LocationID = @location_id AND [Active Employee] = 1
	SELECT @employment_days = ISNULL(SUM(
		CASE 
			WHEN [Stop Day past 1900] > @requested_day THEN @requested_day 
			WHEN [Stop Day past 1900] IS NULL THEN @requested_day
			ELSE [Stop Day past 1900] 
		END - [Start Day past 1900] + 1
	), (SELECT @requested_day - [Seniority Begins Day past 1900] FROM Employee WHERE EmployeeID = @employee_id))
	 FROM EmployeeCompensation WHERE EmployeeID = @employee_id AND [Start Day past 1900] <= @requested_day

		
	/* SELECT @seconds_worked_status =  ISNULL(ROUND(
		(CASE WHEN @employment_days >= 365 THEN 365 ELSE @employment_days END) *
		CAST([Days On] AS decimal)/CAST([Days On]+[Days Off] AS decimal) *
		[Seconds per day]
	,0),0)
	FROM Shift S INNER JOIN Employee E ON S.ShiftID = E.ShiftID AND E.EmployeeID = @employee_id */

	SELECT @seconds_worked_time_cards =  ISNULL(SUM(Seconds), 0) FROM EmployeeTime WHERE EmployeeID = @employee_id AND (StatusID & 1) = 1 AND [In] BETWEEN DATEADD(yy,-1,@requested) AND @requested
	SELECT @seconds_worked_status = @seconds_worked_time_cards - ISNULL(SUM(L.Seconds), 0) FROM dbo.vwEmployeeLeaveApproved L
	INNER JOIN vwLeaveType T ON L.Seconds < 0 AND L.EmployeeID = @employee_id AND (L.[Date] BETWEEN DATEADD(yy,-1,@requested) AND @requested) AND L.TypeID = T.TypeID AND T.Paid = 1
END

GO
IF OBJECT_id('dbo.spEmployeeLeaveUsedGetForAdoption') IS NOT NULL DROP PROC dbo.spEmployeeLeaveUsedGetForAdoption
GO
CREATE PROC dbo.spEmployeeLeaveUsedGetForAdoption
	@employee_id int,
	@advanced_type_mask int,
	@reference_day int,
	@plus_minus int,
	@leave_id int OUT
AS
DECLARE @authorized bit

SET @leave_id = NULL
EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 10001, 1, @authorized out

IF @authorized = 1 
SELECT TOP 1 @leave_id = LeaveID FROM EmployeeLeaveUsed WHERE Status = 2 AND EmployeeID = @employee_id AND [Advanced Type Mask] = @advanced_type_mask AND @reference_day BETWEEN [Start Day past 1900] - @plus_minus AND [Stop Day past 1900] + @plus_minus
ORDER BY [Stop Day past 1900] DESC
GO
GRANT EXEC ON dbo.spEmployeeLeaveUsedGetForAdoption TO public
GO

UPDATE Constant SET [Server Version] = 62
GO
IF NOT EXISTS(SELECT * FROM LeaveRatePeriod WHERE PeriodID=281088)
INSERT LeaveRatePeriod (PeriodID,GroupID,Period,Example,Payroll,[Order],[Weekday])
VALUES (281088,512,'Leave per Hour Worked','Periodically click "Leave > Enter Timecards or Leave for Many Employees" to apply credits',0,30000,0)

IF NOT EXISTS(SELECT * FROM Period WHERE PeriodID=1024)
INSERT Period(PeriodID,Period,Seconds) VALUES(1024,'Quarterly',1872000)

IF NOT EXISTS(SELECT * FROM LeaveRatePeriod WHERE PeriodID=281600)
INSERT LeaveRatePeriod(PeriodID,GroupID,Period,Example,Payroll,[Order],[Weekday]) 
VALUES(281600,1024,'Quarterly I','Jan 1, Apr 1, Jul 1, Oct 1 ..',0,6500,0)

IF NOT EXISTS(SELECT * FROM LeaveRatePeriod WHERE PeriodID=283648)
INSERT LeaveRatePeriod(PeriodID,GroupID,Period,Example,Payroll,[Order],[Weekday]) 
VALUES(283648,1024,'Quarterly II','Mar 31, Jun 30, Sep 30, Dec 31 ..',0,6510,0)

IF NOT EXISTS(SELECT * FROM LeaveRatePeriod WHERE PeriodID=285696)
INSERT LeaveRatePeriod(PeriodID,GroupID,Period,Example,Payroll,[Order],[Weekday]) 
VALUES(285696,1024,'Every 3 Months of Seniority I','If seniority starts Jan 3 then credit Jan 3, Apr 3, Jul 3 ..',0,6530,0)

IF NOT EXISTS(SELECT * FROM LeaveRatePeriod WHERE PeriodID=287744)
INSERT LeaveRatePeriod(PeriodID,GroupID,Period,Example,Payroll,[Order],[Weekday]) 
VALUES(287744,1024,'Every 3 Months of Seniority II','If seniority starts Jan 3 then credit Jan 3, Apr 2, Jul 2 ..',0,6540,0)

IF NOT EXISTS(SELECT * FROM LeaveRatePeriod WHERE PeriodID=289792)
INSERT LeaveRatePeriod(PeriodID,GroupID,Period,Example,Payroll,[Order],[Weekday]) 
VALUES(289792,1024,'Every 3 Months of Seniority III','If seniority starts Jan 3 then credit Apr 3, Jul 3, Oct 3 ..',0,6550,0)

IF NOT EXISTS(SELECT * FROM LeaveRatePeriod WHERE PeriodID=291840)
INSERT LeaveRatePeriod(PeriodID,GroupID,Period,Example,Payroll,[Order],[Weekday]) 
VALUES(291840,1024,'Every 3 Months of Seniority IV','If seniority starts Jan 3 then credit Apr 2, Jul 2, Oct 2 ..',0,6560,0)
GO
IF OBJECT_id('dbo.spLeaveTypeListComp') IS NOT NULL DROP PROC dbo.spLeaveTypeListComp
IF OBJECT_id('dbo.spLeaveTypeSelectPrimaryComp') IS NOT NULL DROP PROC dbo.spLeaveTypeSelectPrimaryComp
IF OBJECT_id('dbo.spLeaveDedupBatchCredits') IS NOT NULL DROP PROC dbo.spLeaveDedupBatchCredits
GO
ALTER PROCEDURE dbo.spPeriodListAsListItems
AS SET NOCOUNT ON
SELECT PeriodID, Period FROM Period WHERE PeriodID BETWEEN 2 AND 512
GO
ALTER PROC dbo.spPeriodList
AS SET NOCOUNT ON
SELECT * FROM Period WHERE PeriodID BETWEEN 2 AND 512
GO
ALTER PROC dbo.spLeaveRatePeriodGroupList @payroll bit
AS SET NOCOUNT ON
SELECT GroupID = PeriodID, [Group] = Period FROM Period WHERE PeriodID IN
(
	SELECT GroupID FROM LeaveRatePeriod WHERE @payroll IS NULL OR Payroll = @payroll
) ORDER BY [Seconds] DESC
GO
ALTER PROC dbo.spLeavePlanAutoCreate
	@plan varchar(50),
	@description varchar(4000),
	@primary_id int,
	@primary_start_month int,
	@primary_seconds int,
	@period_id int,
	@bump1_start_month int,
	@bump1_seconds int,
	@bump2_start_month int,
	@bump2_seconds int,
	@secondary_id int,
	@secondary_seconds int,
	@tertiary_id int,
	@tertiary_seconds int,
	@fte numeric(9,4),
	@requires_6_months bit = 0,
	@requires_3_months bit = 0,
	@plan_id int OUT
AS
SET NOCOUNT ON

INSERT LeavePlan([Plan], [Description], FTE)
VALUES (@plan, @description, @fte)
SELECT @plan_id = SCOPE_IDENTITY()

DECLARE @stop_month int

-- Primary
IF @primary_id IS NOT NULL
BEGIN
	IF @requires_6_months = 1 AND @primary_start_month = 0 AND (@bump1_start_month IS NULL OR @bump1_start_month > 6) AND  (@bump2_start_month IS NULL OR @bump2_start_month > 6)
	BEGIN
		INSERT LeaveRate(PlanID, TypeID, [Start Month], [Stop Month], Seconds, PeriodID)
		SELECT @plan_id, @primary_id, 0, 5, @primary_seconds * @fte *  (7488000.0 / P.Seconds) / 2, 63492
		FROM Period P WHERE P.PeriodID = @period_id & 1023

		SET @primary_start_month = 6
	END
	ELSE IF @requires_3_months = 1 AND @primary_start_month = 0 AND (@bump1_start_month IS NULL OR @bump1_start_month > 3) AND  (@bump2_start_month IS NULL OR @bump2_start_month > 3)
	BEGIN
		INSERT LeaveRate(PlanID, TypeID, [Start Month], [Stop Month], Seconds, PeriodID)
		SELECT @plan_id, @primary_id, 0, 2, @primary_seconds * @fte *  (7488000.0 / P.Seconds) / 4, 291840
		FROM Period P WHERE P.PeriodID = @period_id & 1023

		SET @primary_start_month = 3
	END

	IF @primary_start_month IS NOT NULL AND @primary_seconds IS NOT NULL
	BEGIN
		SELECT @stop_month = CASE 
			WHEN @bump1_start_month IS NOT NULL THEN @bump1_start_month - 1
			WHEN @bump2_start_month IS NOT NULL THEN @bump2_start_month - 1
			ELSE 0x7FFFFFFF
		END

		INSERT LeaveRate(PlanID, TypeID, [Start Month], [Stop Month], Seconds, PeriodID)
		VALUES(@plan_id, @primary_id, @primary_start_month, @stop_month, @primary_seconds * @fte, @period_id)
	END

	IF @bump1_start_month IS NOT NULL AND @bump1_seconds IS NOT NULL
	BEGIN
		SELECT @stop_month = CASE 
			WHEN @bump2_start_month IS NOT NULL THEN @bump2_start_month - 1
			ELSE 0x7FFFFFFF
		END

		INSERT LeaveRate(PlanID, TypeID, [Start Month], [Stop Month], Seconds, PeriodID)
		VALUES(@plan_id, @primary_id, @bump1_start_month, @stop_month, @bump1_seconds * @fte, @period_id)
	END

	IF @bump2_start_month IS NOT NULL AND @bump2_seconds IS NOT NULL
	BEGIN
		INSERT LeaveRate(PlanID, TypeID, [Start Month], [Stop Month], Seconds, PeriodID)
		VALUES(@plan_id, @primary_id, @bump2_start_month, 0x7FFFFFFF, @bump2_seconds * @fte, @period_id)
	END
END

-- Secondary
IF @secondary_id IS NOT NULL AND @secondary_seconds IS NOT NULL
BEGIN
	INSERT LeaveRate(PlanID, TypeID, [Start Month], [Stop Month], Seconds, PeriodID)
	VALUES(@plan_id, @secondary_id, 0, 0x7FFFFFFF, @secondary_seconds * @fte, 32770)
END

-- Tertiary
IF @tertiary_id IS NOT NULL AND @tertiary_seconds IS NOT NULL
BEGIN
	INSERT LeaveRate(PlanID, TypeID, [Start Month], [Stop Month], Seconds, PeriodID)
	VALUES(@plan_id, @tertiary_id, 0, 0x7FFFFFFF, @tertiary_seconds * @fte, 32770)
END

-- Advanced leave
INSERT LeaveRate(PlanID, TypeID, [Start Month], [Stop Month], Seconds, PeriodID)
SELECT @plan_id, TypeID, 0, 0x7FFFFFFF, [Initial Seconds] * @fte, InitialPeriodID FROM LeaveType WHERE [Initial Seconds] IS NOT NULL  AND InitialPeriodID IS NOT NULL
GO
CREATE PROC dbo.spLeaveDedupBatchCredits
	@batch_id int,
	@type_id int,
	@day int,
	@seconds int
AS
DELETE T 
FROM TempX T
INNER JOIN EmployeeLeaveEarned L 
ON T.BatchID=@batch_id AND L.EmployeeID=T.[ID] AND L.TypeID=@type_id AND L.[Day past 1900]=@day AND L.Seconds=@seconds
GO
CREATE PROC dbo.spLeaveTypeSelectPrimaryComp
AS
SELECT * FROM vwLeaveType WHERE TypeID IN
(
	SELECT CompLeaveTypeID FROM TimeType
) ORDER BY [Order]
GO
CREATE PROC dbo.spLeaveTypeListComp
AS
SELECT * FROM vwLeaveType WHERE TypeID IN
(
	SELECT CompLeaveTypeID FROM TimeType
) ORDER BY [Order]
GO
GRANT EXEC ON dbo.spLeaveTypeListComp TO public
GRANT EXEC ON dbo.spLeaveTypeSelectPrimaryComp TO public
GRANT EXEC ON dbo.spLeaveDedupBatchCredits TO public
GRANT EXEC ON dbo.spStandardTaskSelect TO public
GO
ALTER PROC dbo.spPersonXCertificationList3
	@active bit
AS 
DECLARE @batch_id int

SET NOCOUNT ON

SELECT @batch_id = RAND() * 2147483647

INSERT TempX(BatchID, [ID])
SELECT DISTINCT @batch_id, PersonID FROM vwPersonXCertification WHERE [Nonterminated Employee] = 1

EXEC dbo.spPermissionGetOnPeopleForCurrentUser2 @batch_id, 65536

DELETE TempX WHERE BatchID = @batch_id AND (X & 1) = 0


SELECT P.PersonID, Certifications = CAST('' AS varchar(400)) INTO #EC FROM PersonX P
INNER JOIN TempX X ON X.BatchID = @batch_id AND X.[ID] = P.PersonID

DECLARE @certification_id int
DECLARE @certification varchar(50)

DECLARE CertificationCursor CURSOR LOCAL FAST_FORWARD FOR
	SELECT CertificationID, Certification FROM Certification

OPEN CertificationCursor

FETCH NEXT From CertificationCursor INTO @certification_id, @certification
WHILE @@FETCH_STATUS = 0
BEGIN
	IF @active = 1
	BEGIN
		UPDATE #EC
		SET Certifications = SUBSTRING(
		Certifications + 
		CASE WHEN
			ISNULL((SELECT TOP 1 @certification FROM PersonXCertification PC WHERE
			PC.CertificationID = @certification_id AND PC.PersonID = #EC.PersonID AND PC.[Expires day past 1900] > DATEDIFF(d,0,GETDATE())
			),'')
			= '' THEN '' ELSE 
				CASE WHEN Certifications <> '' THEN ', ' ELSE '' END
		END +
		ISNULL((SELECT TOP 1 @certification FROM PersonXCertification PC WHERE
		PC.CertificationID = @certification_id AND PC.PersonID = #EC.PersonID AND PC.[Expires day past 1900] > DATEDIFF(d,0,GETDATE())),'')
		, 1 ,400)
	END
	ELSE
	BEGIN
		UPDATE #EC
		SET Certifications = SUBSTRING(
		Certifications + 
		CASE WHEN
			ISNULL(( SELECT TOP 1 @certification FROM PersonXCertification PC WHERE
			PC.CertificationID = @certification_id AND PC.PersonID = #EC.PersonID
			),'')
			= '' THEN '' ELSE 
				CASE WHEN Certifications <> '' THEN ', ' ELSE '' END
		END +
		ISNULL((SELECT TOP 1 @certification FROM PersonXCertification PC WHERE
		PC.CertificationID = @certification_id AND PC.PersonID = #EC.PersonID),'')
		,1 , 400)
	END
	
	FETCH NEXT From CertificationCursor INTO @certification_id, @certification
END

CLOSE CertificationCursor

DEALLOCATE CertificationCursor

DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1

SELECT #EC.*, Person = V.[List As] FROM #EC
INNER JOIN vwPersonCalculated V ON Certifications <> '' AND #EC.PersonID = V.PersonID
ORDER BY V.[List As]
GO
ALTER PROC dbo.spPersonXLicenseList3
	@active bit
AS 
DECLARE @batch_id int

SET NOCOUNT ON

SELECT @batch_id = RAND() * 2147483647

INSERT TempX(BatchID, [ID])
SELECT DISTINCT @batch_id, PersonID FROM vwPersonXLicense WHERE [Nonterminated Employee] = 1

EXEC dbo.spPermissionGetOnPeopleForCurrentUser2 @batch_id, 65536

DELETE TempX WHERE BatchID = @batch_id AND (X & 1) = 0


SELECT P.PersonID, Licenses = CAST('' AS varchar(400)) INTO #EC FROM PersonX P
INNER JOIN TempX X ON X.BatchID = @batch_id AND X.[ID] = P.PersonID

DECLARE @license_id int
DECLARE @license varchar(50)

DECLARE LicenseCursor CURSOR LOCAL FAST_FORWARD FOR
	SELECT LicenseID, License FROM License

OPEN LicenseCursor

FETCH NEXT From LicenseCursor INTO @license_id, @license
WHILE @@FETCH_STATUS = 0
BEGIN
	IF @active = 1
	BEGIN
		UPDATE #EC
		SET Licenses = SUBSTRING(
		Licenses + 
		CASE WHEN
			ISNULL((SELECT TOP 1 @license FROM PersonXLicense PC WHERE
			PC.LicenseID = @license_id AND PC.PersonID = #EC.PersonID AND PC.[Expires day past 1900] > DATEDIFF(d,0,GETDATE())
			),'')
			= '' THEN '' ELSE 
				CASE WHEN Licenses <> '' THEN ', ' ELSE '' END
		END +
		ISNULL((SELECT TOP 1 @license FROM PersonXLicense PC WHERE
		PC.LicenseID = @license_id AND PC.PersonID = #EC.PersonID AND PC.[Expires day past 1900] > DATEDIFF(d,0,GETDATE())),'')
		, 1 ,400)
	END
	ELSE
	BEGIN
		UPDATE #EC
		SET Licenses = SUBSTRING(
		Licenses + 
		CASE WHEN
			ISNULL(( SELECT TOP 1 @license FROM PersonXLicense PC WHERE
			PC.LicenseID = @license_id AND PC.PersonID = #EC.PersonID
			),'')
			= '' THEN '' ELSE 
				CASE WHEN Licenses <> '' THEN ', ' ELSE '' END
		END +
		ISNULL((SELECT TOP 1 @license FROM PersonXLicense PC WHERE
		PC.LicenseID = @license_id AND PC.PersonID = #EC.PersonID),'')
		,1 , 400)
	END
	
	FETCH NEXT From LicenseCursor INTO @license_id, @license
END

CLOSE LicenseCursor

DEALLOCATE LicenseCursor

DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1

SELECT #EC.*, Person = V.[List As] FROM #EC
INNER JOIN vwPersonCalculated V ON Licenses <> '' AND #EC.PersonID = V.PersonID
ORDER BY V.[List As]
GO

-- Will throw error if insufficient typeids available
ALTER PROC dbo.spLeaveTypeAddStateFML
	@state_id int
AS
DECLARE @next_type_id int, @next_order int, @error int
SELECT @next_type_id = ISNULL(MAX(TypeID) * 2, 1) FROM LeaveType
SELECT @next_order = ISNULL(MAX([Order]) + 1, 1) FROM LeaveType

BEGIN TRAN

INSERT LeaveType(TypeID, Advanced, Bank, [Type], Abbreviation, Paid, [Order], InitialPeriodID, [Initial Seconds])
SELECT TypeID * @next_type_id , 1, 1, [Type], UPPER(SUBSTRING([Type], 1, 4)), 0, [Order] + @next_order, PeriodID, Seconds FROM StateFMLType WHERE StateID = @state_id
SELECT @error = @@ERROR

IF @error = 0
BEGIN
	INSERT LeaveRate(PlanID, TypeID, Seconds, [Start Month], [Stop Month], PeriodID)
	SELECT P.PlanID, F.TypeID * @next_type_id, F.Seconds * P.FTE, 0, 0x7FFFFFFF, F.PeriodID
	FROM StateFMLType F
	CROSS JOIN LeavePlan P
	WHERE F.StateID = @state_id
	SELECT @error = @@ERROR
END

IF @error = 0
BEGIN
	
	DECLARE @ptrSrc binary(16), @ptrTarget binary(16)

	SELECT @ptrSrc = TEXTPTR([Leave Note]) FROM StateFML WHERE StateID = @state_id
	SELECT @ptrTarget = TEXTPTR([Leave Note]) FROM dbo.Constant
	
	DECLARE @nl varchar(2000)
	SELECT @nl = CHAR(13) + CHAR(10) + '===========================================' + CHAR(13) + CHAR(10) +
		'DISCLAIMER: The accuracy of the documentation that Apex Software provides about federal and state law is deemed reliable but not guaranteed. Apex recommends that you thoroughly understand how this software will credit and debit leave before you incorporate it into your family and medical leave procedures and that you consult a specialist in family and medical law. You may need to modify the leave accrual plans in this software, changing the types and amounts of automatically credited family leave. Apex assumes no liability for damages sought regarding tracking, accruing, approving, or denying leave. By using this software, you and/or your employer accept full responsibility and liability.' + CHAR(13) + CHAR(10) +
		'===========================================' + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10)
	UPDATETEXT Constant.[Leave Note] @ptrTarget NULL NULL @nl
	SELECT @error = @@ERROR

	IF @error = 0
	BEGIN
		UPDATETEXT Constant.[Leave Note] @ptrTarget NULL NULL StateFML.[Leave Note] @ptrSrc
		SELECT @error = @@ERROR
	END
END

IF @error = 0 COMMIT TRAN
ELSE IF @@ROWCOUNT > 0 ROLLBACK
GO
ALTER PROC dbo.spEmployeeLeaveGetUsed
	@employee_id int,
	@type_id int,
	@day int,
	@seconds int out
AS
DECLARE @authorized bit
SET NOCOUNT ON

EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 10003, 1, @authorized out

SET @seconds = 0
IF @authorized = 1
BEGIN
	SELECT @seconds = ISNULL(SUM(Seconds), 0) FROM vwEmployeeLeaveUsedItemApproved WHERE ([Extended Type Mask] & @type_id) != 0 AND EmployeeID = @employee_id AND [Day past 1900] >= @day AND [Day past 1900] <= DATEDIFF(d,0,GETDATE())
END
GO
UPDATE EmployeeCompensation SET [Base Pay]=0 WHERE [Base Pay]<0
UPDATE EmployeeCompensation SET [Base Pay]=10000000000 WHERE [Base Pay]>10000000000

IF OBJECT_id('CK_EmployeeCompensation_BasePayOutOfRange') IS NULL
ALTER TABLE dbo.EmployeeCompensation ADD CONSTRAINT CK_EmployeeCompensation_BasePayOutOfRange CHECK ([Base Pay] BETWEEN 0 AND 1000000000)
GO
IF OBJECT_id('dbo.GetYearStart') IS NULL EXEC sp_executesql N'CREATE FUNCTION dbo.GetYearStart(@year int) RETURNS datetime AS BEGIN RETURN dbo.GetDateFromMDY(1, 1, @year) END'
GO
UPDATE Constant SET [Server Version]=65
GO
IF NOT EXISTS (SELECT * FROM syscolumns WHERE [name]='Advanced Type Mask' AND [id] = OBJECT_id('dbo.EmployeeLeaveUsedItem'))
BEGIN
	ALTER TABLE dbo.EmployeeLeaveUsedItem ADD [Advanced Type Mask] int NOT NULL DEFAULT(0)
	EXEC ('UPDATE I SET [Advanced Type Mask]=U.[Advanced Type Mask] FROM EmployeeLeaveUsed U INNER JOIN EmployeeLeaveUsedItem I ON U.LeaveID=I.LeaveID')
END
GO
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID]=OBJECT_id('dbo.Constant') AND name='Audit Purge Days')
ALTER TABLE dbo.Constant ADD [Audit Purge Days] int DEFAULT(750)
GO
IF OBJECT_id('dbo.AuditSetting') IS NULL
BEGIN
	CREATE TABLE dbo.AuditSetting(ObjectID int NOT NULL PRIMARY KEY, Object varchar(50) NOT NULL, [Possible Event Mask] int NOT NULL, [Audit Event Mask] int NOT NULL)
	CREATE INDEX IX_AuditSetting_ObjectID ON dbo.AuditSetting(ObjectID)
END
GO
IF OBJECT_id('dbo.spAuditSettingList') IS NOT NULL DROP PROC dbo.spAuditSettingList
IF OBJECT_id('dbo.spAuditSettingUpdate') IS NOT NULL DROP PROC dbo.spAuditSettingUpdate
IF OBJECT_id('dbo.spAuditSettingUpdatePurge') IS NOT NULL DROP PROC dbo.spAuditSettingUpdatePurge
IF OBJECT_id('dbo.spAuditSettingGetPurge') IS NOT NULL DROP PROC dbo.spAuditSettingGetPurge
IF OBJECT_id('dbo.vwAuditSetting') IS NOT NULL DROP VIEW dbo.vwAuditSetting
GO
CREATE VIEW dbo.vwAuditSetting AS SELECT * FROM AuditSetting
GO
CREATE PROC dbo.spAuditSettingUpdatePurge @days int AS
UPDATE Constant SET [Audit Purge Days]=@days
GO
CREATE PROC dbo.spAuditSettingGetPurge @days int OUT AS
SELECT @days=[Audit Purge Days] FROM dbo.Constant
GO
CREATE PROC dbo.spAuditSettingUpdate
	@object_id int,
	@audit_event_mask int
AS
UPDATE AuditSetting SET [Audit Event Mask] = @audit_event_mask WHERE ObjectID = @object_id
GO
CREATE PROC dbo.spAuditSettingList AS SELECT * FROM vwAuditSetting
GO
IF OBJECT_id('dbo.spLeaveSummaryEmployeeEarned') IS NOT NULL DROP PROC dbo.spLeaveSummaryEmployeeEarned
GO
CREATE PROC dbo.spLeaveSummaryEmployeeEarned
	@start_day int,
	@stop_day int,
	@batch_id int,
	@authorized bit OUT,
	@days bit = 0
AS
SET NOCOUNT ON

EXEC dbo.spPermissionGetOnPeopleForCurrentUser2 @batch_id, 10003
DELETE TempX WHERE BatchID = @batch_id AND X & 1 = 0
SELECT @authorized = CASE WHEN @@ROWCOUNT = 0 THEN 1 ELSE 0 END

SELECT E.Seconds, E.EmployeeID, E.TypeID
INTO #L
FROM EmployeeLeaveEarned E
INNER JOIN TempX X ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID AND E.[Day past 1900] BETWEEN @start_day AND @stop_day AND E.Seconds > 0

DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1

SELECT DISTINCT EmployeeID INTO #UE FROM #L
SELECT DISTINCT T.TypeID INTO #UT FROM LeaveType T
INNER JOIN #L ON #L.TypeID = T.TypeID

CREATE TABLE #H(EmployeeID int, TypeID int NULL, Type varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS, [Order] int, Hrs numeric(9,4))

INSERT #H
SELECT #UE.EmployeeID, #UT.TypeID, T.[Type], T.[Order], Hrs = ISNULL((
	SELECT SUM(#L.Seconds) / 
	CAST(CASE WHEN @days=0 THEN 3600.00 ELSE S.[Effective Seconds per Day] END AS numeric(9,4))
	FROM #L WHERE #L.EmployeeID = #UE.EmployeeID AND #L.TypeID = #UT.TypeID
), 0)
FROM #UT
INNER JOIN LeaveType T ON #UT.TypeID = T.TypeID
CROSS JOIN #UE
INNER JOIN Employee E ON #UE.EmployeeID=E.EmployeeID
INNER JOIN vwEmployeeEffectiveSecondsPerDay S ON E.EmployeeID=S.EmployeeID

IF (SELECT COUNT(*) FROM LeaveType T INNER JOIN #UT ON T.TypeID = #UT.TypeID AND T.Paid = 0 AND T.Advanced = 0) > 1
BEGIN
	INSERT #H
	SELECT #UE.EmployeeID, NULL, 'Total Unpaid', 0x7FFFFFFE, ISNULL((
		SELECT SUM(#H.Hrs) FROM #H INNER JOIN LeaveType T ON #H.TypeID = T.TypeID AND #H.EmployeeID = #UE.EmployeeID AND T.Paid = 0 AND T.Advanced = 0
	), 0)
	FROM #UE
END

IF (SELECT COUNT(*) FROM LeaveType T INNER JOIN #UT ON T.TypeID = #UT.TypeID AND T.Paid = 1 AND T.Advanced = 0) > 1
BEGIN
	INSERT #H
	SELECT #UE.EmployeeID, NULL, 'Total Paid', 0x7FFFFFFF, ISNULL((
		SELECT SUM(#H.Hrs) FROM #H INNER JOIN LeaveType T ON #H.TypeID = T.TypeID AND #H.EmployeeID = #UE.EmployeeID AND T.Paid = 1 AND T.Advanced = 0
	), 0)
	FROM #UE
END

SELECT #H.EmployeeID, Employee = P.[List As], #H.[Type], #H.Hrs
FROM #H
INNER JOIN dbo.vwPersonListAs P ON #H.EmployeeID = P.PersonID
ORDER BY P.[List As], #H.EmployeeID, #H.[Order]
GO
GRANT EXEC ON dbo.spLeaveSummaryEmployeeEarned TO public
GO



GO
UPDATE Constant SET [Server Version]=66
GO
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID]=OBJECT_id('EmployeeLeaveUsed') AND [name]='Expected Departure Day past 1900')
ALTER TABLE EmployeeLeaveUsed ADD [Expected Departure Day past 1900] int NULL

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID]=OBJECT_id('EmployeeLeaveUsed') AND [name]='Expected Return Day past 1900')
ALTER TABLE EmployeeLeaveUsed ADD [Expected Return Day past 1900] int NULL

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID]=OBJECT_id('EmployeeLeaveUsed') AND [name]='Reconciled Day past 1900')
ALTER TABLE EmployeeLeaveUsed ADD [Reconciled Day past 1900] int NULL

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID]=OBJECT_id('EmployeeLeaveUsed') AND [name]='Pay Began Day past 1900')
ALTER TABLE EmployeeLeaveUsed ADD [Pay Began Day past 1900] int null

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID]=OBJECT_id('EmployeeLeaveUsed') AND [name]='Pay Ended Day past 1900')
ALTER TABLE EmployeeLeaveUsed ADD [Pay Ended Day past 1900] int null

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID]=OBJECT_id('EmployeeLeaveUsed') AND [name]='Last MD Note Day past 1900')
ALTER TABLE EmployeeLeaveUsed ADD [Last MD Note Day past 1900] int null

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID]=OBJECT_id('Employee') AND [name]='LastLeaveID')
ALTER TABLE Employee ADD [LastLeaveID] int null

DROP INDEX TempXYZ.IX_Report_ReportID
CREATE INDEX IX_Report_ReportID ON TempXYZ(BatchID,[ID])
GO
IF NOT EXISTS(SELECT * FROM Employee WHERE LastLeaveID IS NOT NULL)
UPDATE Employee SET LastLeaveID = (
	SELECT TOP 1 LeaveID FROM EmployeeLeaveUsed U WHERE E.EmployeeID=U.EmployeeID ORDER BY [Stop Day past 1900] DESC
) FROM Employee E
GO
IF OBJECT_id('dbo.spTempXYZInsert') IS NOT NULL DROP PROC dbo.spTempXYZInsert
GO
CREATE PROC dbo.spTempXYZInsert @batch_id int, @id int, @x int, @y int, @z int
AS INSERT TempXYZ(BatchID, [ID], X, Y, Z) VALUES(@batch_id, @id, @x, @y, @z)
GO
GRANT EXEC ON dbo.spTempXYZInsert TO public
GO
IF NOT EXISTS(SELECT * FROM Error WHERE ErrorID=50050) INSERT Error VALUES(50050,'You cannot delete the last exempt/non-exempt FLSA status.')
GO
IF OBJECT_id('dbo.FLSA') IS NULL
BEGIN
	BEGIN TRAN
	CREATE TABLE dbo.FLSA (
		FLSAID int NOT NULL PRIMARY KEY IDENTITY(1,1),
		Status varchar(50) NOT NULL,
		Exempt bit NOT NULL,
		[Order] int NOT NULL
	)
	ALTER TABLE FLSA ADD CONSTRAINT [IX_FLSA_Status] UNIQUE NONCLUSTERED (Status),
	CONSTRAINT [CK_FLSA_Blank] CHECK ([Status] <> '')

	INSERT FLSA(Status,Exempt,[Order]) VALUES('Non-Exempt',0,0)
	INSERT FLSA(Status,Exempt,[Order]) VALUES('Administrative Exempt',1,1)
	INSERT FLSA(Status,Exempt,[Order]) VALUES('Executive Exempt',1,2)
	INSERT FLSA(Status,Exempt,[Order]) VALUES('Professional Exempt',1,3)
	INSERT FLSA(Status,Exempt,[Order]) VALUES('Combination Exempt',1,4)
	COMMIT TRAN
END
GO
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID]=OBJECT_id('dbo.Position') AND [name]='FLSAID')
BEGIN
	BEGIN TRAN
	UPDATE dbo.Position SET [Job Description]=SUBSTRING([Job Description],1,2000)
	ALTER TABLE dbo.Position ADD [FLSAID] int NOT NULL DEFAULT 1
	ALTER TABLE dbo.Position ALTER COLUMN [Job Description] varchar(2000) NOT NULL

	EXEC sp_executesql N'UPDATE dbo.Position SET [FLSAID] = 2 WHERE [FLSA Exempt] = 1'

	ALTER TABLE dbo.Position DROP COLUMN [FLSA Exempt]
	COMMIT TRAN
END
GO
IF OBJECT_id('FK_Position_FLSA') IS NULL
ALTER TABLE Position ADD CONSTRAINT [FK_Position_FLSA] FOREIGN KEY (FLSAID) REFERENCES FLSA (FLSAID) 

IF EXISTS(SELECT * FROM sysindexes WHERE name='IX_Postion_FLSA')
drop index dbo.Position.IX_Postion_FLSA

IF NOT EXISTS(SELECT * FROM sysindexes WHERE name='IX_Position_FLSA')
CREATE INDEX IX_Position_FLSA ON dbo.Position(FLSAID)
GO
IF OBJECT_id('dbo.vwFLSA') IS NOT NULL DROP VIEW dbo.vwFLSA
IF OBJECT_id('dbo.spFLSAList') IS NOT NULL DROP PROC dbo.spFLSAList
IF OBJECT_id('dbo.spFLSASelect') IS NOT NULL DROP PROC dbo.spFLSASelect
IF OBJECT_id('dbo.spFLSAGetFirst') IS NOT NULL DROP PROC dbo.spFLSAGetFirst
IF OBJECT_id('dbo.spFLSADelete') IS NOT NULL DROP PROC dbo.spFLSADelete
IF OBJECT_id('dbo.spFLSAInsert') IS NOT NULL DROP PROC dbo.spFLSAInsert
IF OBJECT_id('dbo.spFLSAUpdate') IS NOT NULL DROP PROC dbo.spFLSAUpdate
GO
CREATE VIEW dbo.vwFLSA AS SELECT * FROM FLSA
GO
CREATE PROC dbo.spFLSAList @exempt bit AS SET NOCOUNT ON SELECT * FROM vwFLSA WHERE @exempt IS NULL OR Exempt=@exempt ORDER BY [Order]
GO
CREATE PROC dbo.spFLSASelect @flsa_id int AS SET NOCOUNT ON SELECT * FROM vwFLSA WHERE FLSAID=@flsa_id
GO
CREATE PROC dbo.spFLSAGetFirst @exempt bit, @flsa_id int OUT AS SELECT TOP 1 @flsa_id=FLSAID FROM FLSA WHERE @exempt IS NULL OR Exempt=@exempt ORDER BY [Order]
GO
CREATE PROC dbo.spFLSADelete @flsa_id int AS 
IF EXISTS(SELECT * FROM FLSA WHERE FLSAID != @flsa_id AND Exempt=0) AND EXISTS(SELECT * FROM FLSA WHERE FLSAID != @flsa_id AND Exempt=1)
DELETE FLSA WHERE FLSAID=@flsa_id
ELSE EXEC dbo.spErrorRaise 50050
GO
CREATE PROC dbo.spFLSAInsert
	@status varchar(50),
	@order int,
	@exempt bit,
	@flsa_id int out
AS
INSERT FLSA(Status,Exempt,[Order]) VALUES(@status,@exempt,@order)
SELECT @flsa_id = SCOPE_IDENTITY()
GO
CREATE PROC dbo.spFLSAUpdate
	@status varchar(50),
	@order int,
	@exempt bit,
	@flsa_id int out
AS
UPDATE FLSA SET Status=@status, Exempt=@exempt, [Order]=@order WHERE FLSAID=@flsa_id
GO
GRANT EXEC ON dbo.spFLSAGetFirst TO public
GRANT EXEC ON dbo.spFLSASelect TO public
GRANT EXEC ON dbo.spFLSAList TO public
GO
IF (SELECT [Server Version] FROM dbo.Constant) < 67 AND NOT EXISTS(SELECT * FROM EmployeeLeaveUsedItem WHERE [Advanced Type Mask] > 0)
UPDATE I SET I.[Advanced Type Mask]=U.[Advanced Type Mask]
FROM EmployeeLeaveUsedItem I
INNER JOIN EmployeeLeaveUsed U ON I.LeaveID=U.LeaveID
GO
UPDATE Constant SET [Server Version]=67
GO
IF EXISTS(SELECT * FROM syscolumns WHERE [id]=OBJECT_id('dbo.ReportTemplate2') AND [name]='Filter Stream')
DROP TABLE dbo.ReportTemplate2

IF OBJECT_id('dbo.ReportTemplate2') IS NULL
CREATE TABLE dbo.ReportTemplate2(
	TemplateID int NOT NULL PRIMARY KEY CLUSTERED IDENTITY(1,1),
	Template varchar(50) NOT NULL,
	[Fields Stream] image NOT NULL,
	CONSTRAINT [CK_ReportTemplate2_TemplateNotBlank] CHECK (Template <> ''),
	CONSTRAINT [IX_ReportTemplate2_Template] UNIQUE NONCLUSTERED (Template)
)

UPDATE dbo.ColumnGrid SET Reportable=1, [Order]=5290 WHERE FieldID=1019
GO
IF OBJECT_id('dbo.spReportTemplate2Insert') IS NOT NULL DROP PROC dbo.spReportTemplate2Insert
IF OBJECT_id('dbo.spReportTemplate2Update') IS NOT NULL DROP PROC dbo.spReportTemplate2Update
IF OBJECT_id('dbo.spReportTemplate2Delete') IS NOT NULL DROP PROC dbo.spReportTemplate2Delete
IF OBJECT_id('dbo.spReportTemplate2List') IS NOT NULL DROP PROC dbo.spReportTemplate2List
IF OBJECT_id('dbo.spReportTemplate2Select') IS NOT NULL DROP PROC dbo.spReportTemplate2Select
GO
CREATE PROC dbo.spReportTemplate2List AS SET NOCOUNT ON SELECT TemplateID,Template FROM ReportTemplate2 ORDER BY Template
GO
CREATE PROC dbo.spReportTemplate2Update @template_id int, @template varchar(50), @fields_stream image
AS UPDATE ReportTemplate2 SET Template=@template,[Fields Stream]=@fields_stream WHERE TemplateID=@template_id
GO
CREATE PROC dbo.spReportTemplate2Insert @template_id int OUT, @template varchar(50), @fields_stream image
AS INSERT ReportTemplate2(Template,[Fields Stream]) VALUES(@template,@fields_stream) SELECT @template_id=SCOPE_IDENTITY()
GO
CREATE PROC dbo.spReportTemplate2Select @template_id int AS SET NOCOUNT ON SELECT * FROM ReportTemplate2 WHERE TemplateID=@template_id
GO
CREATE PROC dbo.spReportTemplate2Delete @template_id int AS DELETE ReportTemplate2 WHERE TemplateID=@template_id
GO
GRANT EXEC ON dbo.spReportTemplate2List TO public
GRANT EXEC ON dbo.spReportTemplate2Select TO public
GO
ALTER PROC dbo.spReportTemplateDelete @template_id int AS DELETE ReportTemplate WHERE TemplateID = @template_id
GO
ALTER PROC dbo.spEmployeeLeaveUsedCalculateFilter
	@batch_id int,
 	@start_date datetime,
 	@group_by smallint,
	@work_week int,
	@work_week_year int
AS
DECLARE @stop_date datetime

SET NOCOUNT ON

-- Each row requires read permission on Employee Leave and Tardiness Summaries
EXEC dbo.spPermissionGetOnPeopleForCurrentUser2 @batch_id, 10003

IF @group_by = 0
	SELECT @stop_date = DATEADD(d,14,@start_date)
ELSE IF @group_by = 1
BEGIN
	IF (DATEPART(wk, dbo.GetDateFromMDY(12, 31, @work_week_year)) < @work_week)
	-- @work_week might be 53 or 54, but the max week in @work_week_year is only 52 or 53 (less than given @work_week number)
		RETURN
	SELECT @start_date = dbo.GetDateFromMDY(1, 1, @work_week_year)
	SELECT @start_date = DATEADD(wk,@work_week-1,DATEADD(d,1-DATEPART(dw,@start_date),@start_date))
	SELECT @stop_date = DATEADD(wk,14,@start_date)
END
ELSE IF @group_by = 2
BEGIN
	DECLARE @group_id int
	SELECT @group_id = GroupID FROM LeaveRatePeriod WHERE Payroll = 1 AND PeriodID = (SELECT CurrentPayrollPeriodID FROM dbo.Constant)

	IF @group_id = 8
		SELECT @stop_date = DATEADD(m,2*14,@start_date)
	ELSE IF @group_id = 16
		SELECT @stop_date = DATEADD(m,14,@start_date)
	ELSE IF @group_id = 32
		SELECT @stop_date = DATEADD(m,14/2,@start_date)
	ELSE IF @group_id = 64
		SELECT @stop_date = DATEADD(wk,2*14,@start_date)
	ELSE IF @group_id = 128
		SELECT @stop_date = DATEADD(wk,14,@start_date)

END
ELSE IF @group_by = 3
	SELECT @stop_date = DATEADD(m,12,@start_date)


DECLARE @start_day int, @stop_day int

SELECT @start_day = DATEDIFF(d, 0, @start_date), @stop_day = DATEDIFF(d, 0, @stop_date)

SELECT EI.EmployeeID, [Work day]=dbo.GetDateFromDaysPast1900(EI.[Day past 1900]),Duration=CAST(CAST(EI.Seconds AS decimal)/3600 AS numeric(9,2)), PayrollPeriod = 0, T.TypeID 
INTO #ET 
FROM TempX X
INNER JOIN vwEmployeeLeaveUsedItemApproved EI ON X.BatchID = @batch_id AND X.[ID] = EI.EmployeeID AND (X.[X] & 1) = 1 AND EI.[Day past 1900] BETWEEN @start_day AND @stop_day
CROSS JOIN LeaveType T
WHERE (T.TypeID & EI.[Extended Type Mask]) != 0 AND EI.Seconds <> 0

DELETE TempX WHERE BatchID=@batch_id OR DATEDIFF(hour,Created,GETDATE()) > 0

CREATE INDEX ET_EmployeeID_0407 ON #ET(EmployeeID)
CREATE INDEX ET_EmployeeIDTypeID_0407 ON #ET(EmployeeID,TypeID)

SELECT EmployeeID, TypeID INTO #Y FROM #ET GROUP BY EmployeeID, TypeID

CREATE INDEX Y_EmployeeID_0407 ON #Y(EmployeeID)
CREATE INDEX Y_EmployeeIDTypeID_0407 ON #Y(EmployeeID,TypeID)

SELECT EmployeeID, Types=ISNULL((SELECT COUNT(*) FROM #Y Y2 WHERE #Y.EmployeeID=Y2.EmployeeID ), 0)
INTO #E FROM #Y GROUP BY EmployeeID


-- SUM the duration of the work day that has 2 or more entries depending on the group by
IF @group_by = 0
-- day
BEGIN
	SELECT P.PersonID, Employee=P.[List As],
		Day0 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 0), 0),
		Day1 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 1), 0),
		Day2 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 2), 0),
		Day3 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 3), 0),
		Day4 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 4), 0),
		Day5 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 5), 0),
		Day6 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 6), 0),
		Day7 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 7), 0),
		Day8 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 8), 0),
		Day9 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 9), 0),
		Day10 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 10), 0),
		Day11 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 11), 0),
		Day12 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 12), 0),
		Day13 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 13), 0),
		Total = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID), 0),
	Type = 'Total', TypeID = 0, [Order] = -2147483648
	FROM #E INNER JOIN dbo.vwPersonListAs P ON P.PersonID=#E.EmployeeID AND #E.Types > 1

	UNION

	SELECT P.PersonID, Employee=P.[List As],
		Day0 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 0 AND #ET.TypeID = LT.TypeID),0) ,
		Day1 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 1 AND #ET.TypeID = LT.TypeID),0) ,
		Day2 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 2 AND #ET.TypeID = LT.TypeID),0) ,
		Day3 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 3 AND #ET.TypeID = LT.TypeID),0) ,
		Day4 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 4 AND #ET.TypeID = LT.TypeID),0) ,
		Day5 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 5 AND #ET.TypeID = LT.TypeID),0) ,
		Day6 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 6 AND #ET.TypeID = LT.TypeID),0) ,
		Day7 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 7 AND #ET.TypeID = LT.TypeID),0) ,
		Day8 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 8 AND #ET.TypeID = LT.TypeID),0) ,
		Day9 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 9 AND #ET.TypeID = LT.TypeID),0) ,
		Day10 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 10 AND #ET.TypeID = LT.TypeID),0) ,
		Day11 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 11 AND #ET.TypeID = LT.TypeID),0) ,
		Day12 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 12 AND #ET.TypeID = LT.TypeID),0) ,
		Day13 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(dd, @start_date, #ET.[Work day]) = 13 AND #ET.TypeID = LT.TypeID),0) ,
		Total = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.TypeID = LT.TypeID),0) ,
	LT.Abbreviation, LT.TypeID, LT.[Order]
	FROM #Y INNER JOIN dbo.vwPersonListAs P ON P.PersonID=#Y.EmployeeID
	INNER JOIN LeaveType LT ON #Y.TypeId=LT.TypeID ORDER BY P.[List As], P.PersonID, LT.[Order]

END

ELSE IF @group_by = 1
-- Work week
BEGIN
	UPDATE #ET SET [Work day]=DATEADD(d,1-DATEPART(dw,[work day]),[work day])

	DECLARE @first_ww datetime
	SELECT @first_ww = CAST('01/01/' + CAST(@work_week_year as varchar(50)) AS datetime)
	SELECT @first_ww = DATEADD(wk,@work_week,@first_ww)
	SELECT @first_ww = DATEADD(d, 1 - DATEPART(dw,@first_ww),@first_ww)
	IF DAY(@first_ww) <> 1 SELECT @first_ww = DATEADD(d, -7,@first_ww)



	SELECT P.PersonID, Employee=P.[List As],
		WW0 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 0 AND 6), 0),
		WW1 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 7 AND 13), 0),
		WW2 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 14 AND 20), 0),
		WW3 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 21 AND 27), 0),
		WW4 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 28 AND 34), 0),
		WW5 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 35 AND 41), 0),
		WW6 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 42 AND 48), 0),
		WW7 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 49 AND 55), 0),
		WW8 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 56 AND 62), 0),
		WW9 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 63 AND 69), 0),
		WW10 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 70 AND 76), 0),
		WW11 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 77 AND 83), 0),
		WW12 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 84 AND 90), 0),
		WW13 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 91 AND 97), 0),
		Total = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID), 0),
	Type = 'Total', TypeID = 0, [Order] = -2147483648
	FROM #E INNER JOIN dbo.vwPersonListAs P ON P.PersonID=#E.EmployeeID AND #E.Types > 1

	UNION

	SELECT P.PersonID, Employee=P.[List As],
		WW0 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 0 AND 6 AND #ET.TypeID = LT.TypeID), 0),
		WW1 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 7 AND 13 AND #ET.TypeID = LT.TypeID), 0),
		WW2 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 14 AND 20 AND #ET.TypeID = LT.TypeID), 0),
		WW3 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 21 AND 27 AND #ET.TypeID = LT.TypeID), 0),
		WW4 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 28 AND 34 AND #ET.TypeID = LT.TypeID), 0),
		WW5 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 35 AND 41 AND #ET.TypeID = LT.TypeID), 0),
		WW6 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 42 AND 48 AND #ET.TypeID = LT.TypeID), 0),
		WW7 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 49 AND 55 AND #ET.TypeID = LT.TypeID), 0),
		WW8 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 56 AND 62 AND #ET.TypeID = LT.TypeID), 0),
		WW9 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 63 AND 69 AND #ET.TypeID = LT.TypeID), 0),
		WW10 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 70 AND 76 AND #ET.TypeID = LT.TypeID), 0),
		WW11 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 77 AND 83 AND #ET.TypeID = LT.TypeID), 0),
		WW12 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 84 AND 90 AND #ET.TypeID = LT.TypeID), 0),
		WW13 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(d, @first_ww, #ET.[Work day]) BETWEEN 91 AND 97 AND #ET.TypeID = LT.TypeID), 0),
		Total = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.TypeID = LT.TypeID), 0),
	LT.Abbreviation, LT.TypeID, LT.[Order]
	FROM #Y INNER JOIN dbo.vwPersonListAs P ON P.PersonID=#Y.EmployeeID
	INNER JOIN LeaveType LT ON #Y.TypeId=LT.TypeID ORDER BY P.[List As], P.PersonID, LT.[Order]
END

ELSE IF @group_by = 2
-- payroll
BEGIN
	DECLARE @first_payroll_period int
	SELECT @first_payroll_period = dbo.GetPayrollPeriodNumber(@start_date)
	UPDATE #ET SET [PayrollPeriod]=dbo.GetPayrollPeriodNumber(#ET.[Work day])

	SELECT P.PersonID, Employee=P.[List As],
		Payroll0 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 0),0),
		Payroll1 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 1),0),
		Payroll2 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 2),0),
		Payroll3 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 3),0),
		Payroll4 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 4),0),
		Payroll5 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 5),0),
		Payroll6 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 6),0),
		Payroll7 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 7),0),
		Payroll8 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 8),0),
		Payroll9 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 9),0),
		Payroll10 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 10),0),
		Payroll11 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 11),0),
		Payroll12 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 12),0),
		Payroll13 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 13),0),
		Total = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID),0),
	Type = 'Total', TypeID = 0, [Order] = -2147483648
	FROM #E INNER JOIN dbo.vwPersonListAs P ON P.PersonID=#E.EmployeeID AND #E.Types > 1

	UNION

	SELECT P.PersonID, Employee=P.[List As],
		Payroll0 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 0 AND #ET.TypeID = LT.TypeID),0),
		Payroll1 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 1 AND #ET.TypeID = LT.TypeID),0),
		Payroll2 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 2 AND #ET.TypeID = LT.TypeID),0),
		Payroll3 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 3 AND #ET.TypeID = LT.TypeID),0),
		Payroll4 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 4 AND #ET.TypeID = LT.TypeID),0),
		Payroll5 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 5 AND #ET.TypeID = LT.TypeID),0),
		Payroll6 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 6 AND #ET.TypeID = LT.TypeID),0),
		Payroll7 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 7 AND #ET.TypeID = LT.TypeID),0),
		Payroll8 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 8 AND #ET.TypeID = LT.TypeID),0),
		Payroll9 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 9 AND #ET.TypeID = LT.TypeID),0),
		Payroll10 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 10 AND #ET.TypeID = LT.TypeID),0),
		Payroll11 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 11 AND #ET.TypeID = LT.TypeID),0),
		Payroll12 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 12 AND #ET.TypeID = LT.TypeID),0),
		Payroll13 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.[PayrollPeriod] - @first_payroll_period = 13 AND #ET.TypeID = LT.TypeID),0),
		Total = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND #ET.TypeID = LT.TypeID),0),
	LT.Abbreviation, LT.TypeID, LT.[Order]
	FROM #Y INNER JOIN dbo.vwPersonListAs P ON P.PersonID=#Y.EmployeeID
	INNER JOIN LeaveType LT ON #Y.TypeId=LT.TypeID ORDER BY P.[List As], P.PersonID, LT.[Order]
END

ELSE IF @group_by = 3
-- month
BEGIN
	UPDATE #ET SET [Work day]=DATEADD(d,1-DAY([Work day]),[Work day])

	SELECT P.PersonID, Employee=P.[List As],
		Month0 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 0), 0),
		Month1 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 1), 0),
		Month2 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 2), 0),
		Month3 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 3), 0),
		Month4 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 4), 0),
		Month5 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 5), 0),
		Month6 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 6), 0),
		Month7 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 7), 0),
		Month8 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 8), 0),
		Month9 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 9), 0),
		Month10 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 10), 0),
		Month11 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 11), 0),
		Total = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID), 0),
	Type = 'Total', TypeID = 0, [Order] = -2147483648
	FROM #E INNER JOIN dbo.vwPersonListAs P ON P.PersonID=#E.EmployeeID AND #E.Types > 1

	UNION

	SELECT P.PersonID, Employee=P.[List As],
		Month0 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 0 AND #ET.TypeID = LT.TypeID), 0),
		Month1 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 1 AND #ET.TypeID = LT.TypeID), 0),
		Month2 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 2 AND #ET.TypeID = LT.TypeID), 0),
		Month3 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 3 AND #ET.TypeID = LT.TypeID), 0),
		Month4 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 4 AND #ET.TypeID = LT.TypeID), 0),
		Month5 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 5 AND #ET.TypeID = LT.TypeID), 0),
		Month6 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 6 AND #ET.TypeID = LT.TypeID), 0),
		Month7 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 7 AND #ET.TypeID = LT.TypeID), 0),
		Month8 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 8 AND #ET.TypeID = LT.TypeID), 0),
		Month9 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 9 AND #ET.TypeID = LT.TypeID), 0),
		Month10 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 10 AND #ET.TypeID = LT.TypeID), 0),
		Month11 = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID AND DATEDIFF(m, @start_date, #ET.[Work day]) = 11 AND #ET.TypeID = LT.TypeID), 0),
		Total = ISNULL((SELECT SUM(Duration) FROM #ET WHERE #ET.EmployeeID = P.PersonID), 0),

	LT.Abbreviation, LT.TypeID, LT.[Order]
	FROM #Y INNER JOIN dbo.vwPersonListAs P ON P.PersonID=#Y.EmployeeID
	INNER JOIN LeaveType LT ON #Y.TypeId=LT.TypeID ORDER BY P.[List As], P.PersonID, LT.[Order]
END
GO
IF OBJECT_id('dbo.spPersonListSecondaryFields') IS NOT NULL DROP PROC dbo.spPersonListSecondaryFields
IF OBJECT_id('dbo.spPersonListSecondaryText') IS NOT NULL DROP PROC dbo.spPersonListSecondaryText
GO
CREATE PROC dbo.spPersonListSecondaryFields
AS
SET NOCOUNT ON
SELECT TypeID=1,FieldID=F.FieldID,[Column Name]=F.Field FROM CustomField F
GO
CREATE PROC dbo.spPersonListSecondaryText
	@batch_id int
AS
SET NOCOUNT ON
EXEC dbo.spPermissionGetOnPeopleForCurrentUser2 @batch_id, 4194304

SELECT TypeID=1, PF.FieldID, Permission=X.X, Value = CASE WHEN (X.X&1)=1 THEN PF.Value ELSE '' END
FROM PersonCustomField PF
INNER JOIN CustomField F ON PF.FieldID=F.FieldID
INNER JOIN TempX X ON X.BatchID=@batch_id AND X.[ID]=PF.PersonID
GO
GRANT EXEC ON dbo.spPersonListSecondaryFields TO public
GRANT EXEC ON dbo.spPersonListSecondaryText TO public

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [id]=OBJECT_id('dbo.Constant') AND [name]='Timecard Authorization')
ALTER TABLE dbo.Constant ADD [Timecard Authorization] varchar(50) NOT NULL DEFAULT('')
GO
if not exists (select * from dbo.sysobjects where id = object_id(N'dbo.[ExpenseAccount]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
BEGIN
	CREATE TABLE dbo.[ExpenseAccount] (
		[AccountID] [int] IDENTITY (1, 1) NOT NULL ,
		[Account] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
		ExpenseGLAccount int NOT NULL DEFAULT(0),
		LiabilityGLAccount int NOT NULL DEFAULT(0),
		Note varchar(1000) NOT NULL,
		Flags int NOT NULL -- 1=Reimbursable,2=Accumulated,4=Project Tracking,8=Requires Approval
	) ON [PRIMARY]

	ALTER TABLE dbo.[ExpenseAccount] WITH NOCHECK ADD CONSTRAINT [PK_ExpenseAccount] PRIMARY KEY CLUSTERED ([AccountID]) ON [PRIMARY],
	CONSTRAINT [IX_ExpenseAccount_Account] UNIQUE NONCLUSTERED ([Account]) ON [PRIMARY],
	CONSTRAINT [CK_ExpenseAccount_Blank] CHECK ([Account] <> '')

	INSERT ExpenseAccount([Account],Note,Flags) VALUES('HRA','',3)
	INSERT ExpenseAccount([Account],Note,Flags) VALUES('Commissions/Draws','',2)
	INSERT ExpenseAccount([Account],Note,Flags) VALUES('Training Expenses','',3)
END
GO
if NOT EXISTS (select * from dbo.sysobjects where id = object_id(N'dbo.[ExpenseStatus]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
BEGIN
	CREATE TABLE dbo.[ExpenseStatus] (
		[StatusID] [int] NOT NULL ,
		[Status] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[Order] [int] NOT NULL 
	) ON [PRIMARY]
	
	ALTER TABLE dbo.[ExpenseStatus] WITH NOCHECK ADD 
	CONSTRAINT [PK_ExpenseStatus] PRIMARY KEY CLUSTERED ([StatusID])  ON [PRIMARY] 

	INSERT ExpenseStatus VALUES(1,'Approved',1)
	INSERT ExpenseStatus VALUES(2,'Denied',3)
	INSERT ExpenseStatus VALUES(5,'Approved with Changes',2)
	INSERT ExpenseStatus VALUES(8,'Pending',0)
END
GO
if not exists (select * from dbo.sysobjects where id = object_id(N'dbo.[EmployeeExpense]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
BEGIN
	CREATE TABLE dbo.EmployeeExpense (
		[ItemID] [int] NOT NULL IDENTITY(1,1),
		AccountID int NOT NULL,
		StatusID int NOT NULL,
		ProjectID int NULL,
		[EmployeeID] [int] NOT NULL,
		[Day past 1900] [int] NOT NULL,
		[Amount] money NOT NULL,
		[Day Reimbursed] [int] NULL,
		[Employee Comment] varchar(400) NOT NULL,
		[Manager Comment] varchar(400) NOT NULL
	) ON [PRIMARY]
	
	ALTER TABLE dbo.[EmployeeExpense] WITH NOCHECK ADD CONSTRAINT [PK_EmployeeExpense] PRIMARY KEY CLUSTERED ([ItemID]) ON [PRIMARY] 
	
	CREATE  INDEX [IX_EmployeeExpense_EmployeeID] ON dbo.[EmployeeExpense]([EmployeeID],AccountID) ON [PRIMARY]
	CREATE  INDEX [IX_EmployeeExpense_EmployeeDay] ON dbo.[EmployeeExpense]([EmployeeID], AccountID, [Day past 1900]) ON [PRIMARY]
	
	ALTER TABLE dbo.[EmployeeExpense] ADD CONSTRAINT [FK_EmployeeExpense_Employee] FOREIGN KEY ([EmployeeID]) REFERENCES dbo.[Employee] ([EmployeeID]) ON DELETE CASCADE
	ALTER TABLE dbo.[EmployeeExpense] ADD CONSTRAINT FK_EmployeeExpense_Status FOREIGN KEY (StatusID) REFERENCES dbo.ExpenseStatus(StatusID)
	ALTER TABLE dbo.[EmployeeExpense] ADD CONSTRAINT FK_EmployeeExpense_Account FOREIGN KEY (AccountID) REFERENCES dbo.ExpenseAccount(AccountID)
	ALTER TABLE dbo.[EmployeeExpense] ADD CONSTRAINT FK_EmployeeExpense_Project FOREIGN KEY (ProjectID) REFERENCES dbo.Project(ProjectID)
END
GO
IF OBJECT_id('dbo.spTempXList2') IS NOT NULL DROP PROC dbo.spTempXList2
IF OBJECT_id('dbo.spTempXCount') IS NOT NULL DROP PROC dbo.spTempXCount
GO
-- Rips out people from TempX who the current user is not authorized to read, update, insert or delete.
-- Sets @hidden = 1 if any of the people where removed from the temporary list.
-- Caller must fill TempX.[ID] with the ids of the people of interest and TempX.X with 0.
ALTER PROC dbo.spPermissionInsureForCurrentUserOnPeople
	@batch_id int,
	@attribute_id int,
	@permission_required int,
	@hidden bit = NULL out 
AS
SET NOCOUNT ON

IF IS_MEMBER('db_owner') = 0
	SELECT @hidden = 0
ELSE
BEGIN
	EXEC dbo.spPermissionGetOnPeopleForCurrentUser2 @batch_id, @attribute_id
	DELETE TempX WHERE BatchID = @batch_id AND (X & @permission_required) = 0
	SELECT @hidden = CASE WHEN @@ROWCOUNT = 0 THEN 0 ELSE 1 END
END

GO
CREATE PROC dbo.spTempXList2 @batch_id int
AS SET NOCOUNT ON
SELECT PersonID=X.[ID], P.[List As] FROM TempX X INNER JOIN dbo.vwPersonListAs P ON X.[ID] = P.PersonID AND X.BatchID = @batch_id ORDER BY P.[List As]
GO
CREATE PROC dbo.spTempXCount @batch_id int, @count int OUT AS SELECT @count=COUNT(*) FROM TempX WHERE BatchID=@batch_id
GO
GRANT EXEC ON dbo.spTempXList2 TO public
GRANT EXEC ON dbo.spTempXCount TO public
GO
IF OBJECT_id('dbo.vwExpenseAccount') IS NOT NULL DROP VIEW dbo.vwExpenseAccount
IF OBJECT_id('dbo.spExpenseAccountInsert') IS NOT NULL DROP PROC dbo.spExpenseAccountInsert
IF OBJECT_id('dbo.spExpenseAccountUpdate') IS NOT NULL DROP PROC dbo.spExpenseAccountUpdate
IF OBJECT_id('dbo.spExpenseAccountDelete') IS NOT NULL DROP PROC dbo.spExpenseAccountDelete
IF OBJECT_id('dbo.spExpenseAccountSelect') IS NOT NULL DROP PROC dbo.spExpenseAccountSelect
IF OBJECT_id('dbo.spExpenseAccountGetAccountFromAccountID') IS NOT NULL DROP PROC dbo.spExpenseAccountGetAccountFromAccountID
IF OBJECT_id('dbo.spExpenseAccountList') IS NOT NULL DROP PROC dbo.spExpenseAccountList
GO
CREATE VIEW dbo.vwExpenseAccount
AS
SELECT A.AccountID, A.Account, A.ExpenseGLAccount, A.LiabilityGLAccount, A.Note, A.Flags,
[Reimbursable]=CAST(CASE WHEN A.Flags&1=1 THEN 1 ELSE 0 END AS bit),
[Accumulated]=CAST(CASE WHEN A.Flags&2=2 THEN 1 ELSE 0 END AS bit),
[Project Tracking]=CAST(CASE WHEN A.Flags&4=4 THEN 1 ELSE 0 END AS bit),
[Requires Approval]=CAST(CASE WHEN A.Flags&8=8 THEN 1 ELSE 0 END AS bit)
FROM dbo.ExpenseAccount A
GO
CREATE PROC dbo.spExpenseAccountGetAccountFromAccountID
	@account_id int, @account varchar(50) out
AS
SELECT @account=''
SELECT @account=Account FROM ExpenseAccount WHERE AccountID=@account_id
GO
CREATE PROC dbo.spExpenseAccountInsert
	@account varchar(50),
	@note varchar(1000),
	@flags int,
	@account_id int OUT
AS
INSERT ExpenseAccount(Account,Note,Flags)
VALUES(@account,@note,@flags)
SELECT @account_id=SCOPE_IDENTITY()
GO
CREATE PROC dbo.spExpenseAccountUpdate
	@account varchar(50),
	@note varchar(1000),
	@flags int,
	@account_id int
AS
UPDATE dbo.ExpenseAccount SET Account=@account,Note=@note,Flags=@flags WHERE AccountID=@account_id
GO
CREATE PROC dbo.spExpenseAccountDelete @account_id int AS DELETE ExpenseAccount WHERE AccountID=@account_id
GO
CREATE PROC dbo.spExpenseAccountSelect @account_id int AS SELECT * FROM vwExpenseAccount WHERE AccountID=@account_id
GO
CREATE PROC dbo.spExpenseAccountList AS SELECT * FROM dbo.vwExpenseAccount ORDER BY Account
GO
GRANT EXEC ON dbo.spExpenseAccountList TO public
GRANT EXEC ON dbo.spExpenseAccountSelect TO public
GRANT EXEC ON dbo.spExpenseAccountGetAccountFromAccountID TO public
GO










GO
UPDATE dbo.ColumnGrid SET [Label]='SSN' WHERE FieldID=33 AND [Label]='S S N'
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [id]=OBJECT_id('dbo.Constant') AND [name]='Localization Stream')
ALTER TABLE dbo.Constant ADD [Localization Stream] text DEFAULT('')
IF OBJECT_id('dbo.spConstantLocalizationGet') IS NOT NULL DROP PROC dbo.spConstantLocalizationGet
IF OBJECT_id('dbo.spConstantLocalizationSet') IS NOT NULL DROP PROC dbo.spConstantLocalizationSet
GO
CREATE PROC dbo.spConstantLocalizationGet AS SET NOCOUNT ON SELECT [Localization Stream] FROM dbo.Constant
GO
CREATE PROC dbo.spConstantLocalizationSet @stream text AS SET NOCOUNT ON UPDATE Constant SET [Localization Stream]=@stream
GO














GO

if not exists (select * from dbo.sysobjects where id = object_id(N'dbo.[OccurrenceType]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
BEGIN
CREATE TABLE dbo.[OccurrenceType] (
	[TypeID] [int] IDENTITY (1, 1) NOT NULL ,
	[Type] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	Abbreviation varchar(5) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]

ALTER TABLE dbo.[OccurrenceType] WITH NOCHECK ADD 
	CONSTRAINT [PK_OccurrenceType] PRIMARY KEY  CLUSTERED 
	(
		[TypeID]
	)  ON [PRIMARY]

ALTER TABLE dbo.OccurrenceType ADD CONSTRAINT CK_OccurrenceTypeBlank CHECK ([Type]<>'' AND Abbreviation<>'')
ALTER TABLE dbo.[OccurrenceType] ADD CONSTRAINT [IX_OccurrenceType_Abbreviation] UNIQUE NONCLUSTERED([Abbreviation])
ALTER TABLE dbo.[OccurrenceType] ADD CONSTRAINT [IX_OccurrenceType_Type] UNIQUE NONCLUSTERED([Type])

INSERT OccurrenceType(Type,Abbreviation) VALUES ('Tardiness Excused','TRDEX')
INSERT OccurrenceType(Type,Abbreviation) VALUES ('Tardiness Unexcused','TRDUN')

END
GO
if not exists (select * from dbo.sysobjects where id = object_id(N'dbo.[Occurrence]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
BEGIN

BEGIN TRAN

CREATE TABLE dbo.[Occurrence] (
	[OccurrenceID] [int] IDENTITY (1, 1) NOT NULL ,
	EmployeeID int NOT NULL,
	[TypeID] [int] NOT NULL ,
	[Day past 1900] [int] NOT NULL ,
	[Weight] [decimal](9, 4) NOT NULL ,
	[Expires Day past 1900] [int] NULL ,
	[Note] [varchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL 
) ON [PRIMARY]

ALTER TABLE dbo.[Occurrence] WITH NOCHECK ADD CONSTRAINT [PK_Occurrence] PRIMARY KEY  CLUSTERED ([OccurrenceID])  ON [PRIMARY] 
ALTER TABLE dbo.[Occurrence] ADD CONSTRAINT [FK_Occurrence_OccurrenceType] FOREIGN KEY ([TypeID]) REFERENCES dbo.[OccurrenceType] ([TypeID])
ALTER TABLE dbo.[Occurrence] ADD CONSTRAINT [FK_Occurrence_Employee] FOREIGN KEY ([EmployeeID]) REFERENCES dbo.[Employee] ([EmployeeID]) ON DELETE CASCADE

COMMIT TRAN

END
GO
IF OBJECT_id('dbo.EmployeeTardy') IS NOT NULL
BEGIN

BEGIN TRAN

INSERT Occurrence(EmployeeID, TypeID, [Day past 1900], Weight, Note)
SELECT EmployeeID, 1, [Day past 1900], 1, Note FROM EmployeeTardy WHERE Excused=1

INSERT Occurrence(EmployeeID, TypeID, [Day past 1900], Weight, Note)
SELECT EmployeeID, 2, [Day past 1900], 1, Note FROM EmployeeTardy WHERE Excused=0

IF OBJECT_id('dbo.vwEmpoyeeTardy') IS NOT NULL DROP VIEW dbo.vwEmpoyeeTardy
DROP TABLE dbo.EmployeeTardy

COMMIT TRAN

END
GO
IF OBJECT_id('dbo.spOccurrenceInsert') IS NOT NULL DROP PROC dbo.spOccurrenceInsert
IF OBJECT_id('dbo.spOccurrenceUpdate') IS NOT NULL DROP PROC dbo.spOccurrenceUpdate
IF OBJECT_id('dbo.spOccurrenceDelete') IS NOT NULL DROP PROC dbo.spOccurrenceDelete


IF OBJECT_id('dbo.spOccurrenceSummarize') IS NOT NULL DROP PROC dbo.spOccurrenceSummarize
IF OBJECT_id('dbo.spOccurrenceSummarize2') IS NOT NULL DROP PROC dbo.spOccurrenceSummarize2


IF OBJECT_id('dbo.vwOccurrenceType') IS NOT NULL DROP VIEW dbo.vwOccurrenceType
IF OBJECT_id('dbo.spOccurrenceTypeSelect') IS NOT NULL DROP PROC dbo.spOccurrenceTypeSelect
IF OBJECT_id('dbo.spOccurrenceTypeList') IS NOT NULL DROP PROC dbo.spOccurrenceTypeList
IF OBJECT_id('dbo.spOccurrenceTypeGetTypeFromTypeID') IS NOT NULL DROP PROC dbo.spOccurrenceTypeGetTypeFromTypeID
GO
CREATE VIEW dbo.vwOccurrenceType AS SELECT * FROM OccurrenceType
GO
CREATE PROC dbo.spOccurrenceTypeGetTypeFromTypeID @type_id int, @type varchar(50) out AS
SELECT @type=''
SELECT @type=Type FROM OccurrenceType WHERE TypeID=@type_id
GO
CREATE PROC dbo.spOccurrenceDelete @occurrence_id int AS 
DECLARE @employee_id int, @authorized bit
SELECT @employee_id = EmployeeID FROM Occurrence WHERE OccurrenceID = @occurrence_id
EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 10012, 8, @authorized out
IF @authorized=1 DELETE Occurrence WHERE OccurrenceID=@occurrence_id
GO
CREATE PROC dbo.spOccurrenceUpdate 
	@occurrence_id int,
	@type_id int,
	@employee_id int,
	@weight numeric(9,4),
	@day int,
	@expires_day int,
	@note varchar(4000)
AS
DECLARE @authorized bit
EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 10012, 2, @authorized out
IF @authorized=1 UPDATE Occurrence SET
TypeID=@type_id,
EmployeeID=@employee_id,
Weight=@weight,
[Day Past 1900]=@day,
[Expires Day past 1900]=@expires_day,
Note=@note
WHERE OccurrenceID=@occurrence_id
GO
CREATE PROC dbo.spOccurrenceInsert
	@occurrence_id int OUT,
	@type_id int,
	@employee_id int,
	@weight numeric(9,4),
	@day int,
	@expires_day int,
	@note varchar(4000)
AS
DECLARE @authorized bit
EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 10012, 4, @authorized out
IF @authorized=1 INSERT Occurrence(TypeID,EmployeeID,Weight,[Day past 1900],[Expires Day past 1900],Note)
VALUES (@type_id,@employee_id,@weight,@day,@expires_day,@note)

SELECT @occurrence_id=SCOPE_IDENTITY()
GO
CREATE PROC dbo.spOccurrenceSummarize2
	@type_id int,
	@batch_id int,
	@day int,
	@balance_min decimal(9,4),
	@balance_max decimal(9,4),
	@authorized bit OUT
AS
SET NOCOUNT ON

EXEC dbo.spPermissionGetOnPeopleForCurrentUser2 @batch_id, 10012
DELETE TempX WHERE BatchID = @batch_id AND (X & 1) = 0
SELECT @authorized = CASE WHEN @@ROWCOUNT=0 THEN 1 ELSE 0 END

SELECT DISTINCT O.TypeID, O.EmployeeID, OldestOccurrenceID=NULL, LastOccurrenceID=NULL, Balance = CAST(0 AS decimal(9,4))
INTO #T FROM Occurrence O
INNER JOIN TempX X ON X.BatchID=@batch_id AND X.[ID]=O.EmployeeID AND (@type_id IS NULL OR TypeID=@type_id) -- AND [Expires Day past 1900] >= @day

UPDATE #T SET OldestOccurrenceID=(
	SELECT TOP 1 OccurrenceID FROM Occurrence O
	WHERE O.EmployeeID=#T.EmployeeID AND O.TypeID=#T.TypeID AND 
	(O.[Expires Day past 1900] IS NULL OR O.[Expires Day past 1900] >= @day)
	ORDER BY [Day past 1900]
), LastOccurrenceID=(
	SELECT TOP 1 OccurrenceID FROM Occurrence O
	WHERE O.EmployeeID=#T.EmployeeID AND O.TypeID=#T.TypeID AND
	O.[Day past 1900] <= @day
	ORDER BY [Day past 1900] DESC
), Balance = ISNULL((
	SELECT SUM(Weight) FROM Occurrence R WHERE R.EmployeeID=#T.EmployeeID AND R.TypeID=#T.TypeID AND
	(R.[Expires Day past 1900] IS NULL OR R.[Expires Day past 1900] > @day) AND R.[Day past 1900]<=@day 
), 0.0000)


DELETE dbo.TempX WHERE BatchID=@batch_id OR DATEDIFF(minute, Created, GETDATE()) > 30

SELECT Employee=P.[List As], T.Abbreviation,
#T.EmployeeID, #T.TypeID, #T.Balance,
[Oldest Expires] = (
	SELECT dbo.GetDateFromDaysPast1900([Expires Day past 1900]) FROM Occurrence WHERE OccurrenceID=#T.OldestOccurrenceID
),
[Last Date] = (
	SELECT dbo.GetDateFromDaysPast1900([Day past 1900]) FROM Occurrence WHERE OccurrenceID=#T.LastOccurrenceID
)
FROM #T
INNER JOIN dbo.vwPersonListAs P ON #T.EmployeeID=P.PersonID AND #T.Balance BETWEEN @balance_min AND @balance_max
INNER JOIN OccurrenceType T ON #T.TypeID=T.TypeID
ORDER BY P.[List As], T.Abbreviation
GO
CREATE PROC dbo.spOccurrenceSummarize
	@type_id int,
	@employee_id int,
	@day int
AS
SET NOCOUNT ON

DECLARE @authorized bit

EXEC dbo.spPermissionInsureForCurrentUserOnPerson @employee_id, 10012, 1, @authorized out
IF @authorized=0 RETURN

DECLARE @oldest_occurrence_id int, @last_occurrence_id int

SELECT TOP 1 @oldest_occurrence_id=OccurrenceID FROM Occurrence
WHERE TypeID=@type_id AND EmployeeID=@employee_id AND [Expires Day past 1900] >= @day
ORDER BY [Day past 1900]

SELECT TOP 1 @last_occurrence_id=OccurrenceID FROM Occurrence
WHERE TypeID=@type_id AND EmployeeID=@employee_id AND [Day past 1900] <= @day ORDER BY [Day past 1900] DESC

SELECT Balance = ISNULL((
	SELECT SUM(Weight) FROM Occurrence R WHERE R.EmployeeID=@employee_id AND R.TypeID=@type_id AND
	(R.[Expires Day past 1900] IS NULL OR R.[Expires Day past 1900] > @day) AND R.[Day past 1900]<=@day 
), 0.0000),
[Oldest Expires] = (
	SELECT TOP 1 dbo.GetDateFromDaysPast1900([Expires Day past 1900]) FROM Occurrence WHERE OccurrenceID=@oldest_occurrence_id ORDER BY [Day past 1900]
),
[Last Date] = (
	SELECT TOP 1 dbo.GetDateFromDaysPast1900([Day past 1900]) FROM Occurrence WHERE OccurrenceID=@last_occurrence_id
)
GO
GRANT EXEC ON dbo.spOccurrenceInsert TO public
GRANT EXEC ON dbo.spOccurrenceUpdate TO public
GRANT EXEC ON dbo.spOccurrenceDelete TO public
GRANT EXEC ON dbo.spOccurrenceSummarize TO public
GRANT EXEC ON dbo.spOccurrenceSummarize2 TO public
GO




GO
CREATE PROC dbo.spOccurrenceTypeSelect @type_id int AS SET NOCOUNT ON SELECT * FROM vwOccurrenceType WHERE TypeID=@type_id
GO
CREATE PROC dbo.spOccurrenceTypeList AS SET NOCOUNT ON SELECT * FROM vwOccurrenceType ORDER BY Type
GO
IF OBJECT_id('dbo.spOccurrenceTypeUpdate') IS NULL EXEC sp_executesql N'CREATE PROC dbo.spOccurrenceTypeUpdate AS'
GO
ALTER PROC dbo.spOccurrenceTypeUpdate @type_id int, @type varchar(50), @abbreviation varchar(5) AS UPDATE OccurrenceType SET Type=@type,Abbreviation=@abbreviation WHERE TypeID=@type_id
GO
IF OBJECT_id('dbo.spOccurrenceTypeDelete') IS NULL EXEC sp_executesql N'CREATE PROC dbo.spOccurrenceTypeDelete AS'
GO
ALTER PROC dbo.spOccurrenceTypeDelete @type_id int AS DELETE OccurrenceType WHERE TypeID=@type_id
GO
IF OBJECT_id('dbo.spOccurrenceTypeInsert') IS NULL EXEC sp_executesql N'CREATE PROC dbo.spOccurrenceTypeInsert AS'
GO
ALTER PROC dbo.spOccurrenceTypeInsert @type_id int OUT, @type varchar(50), @abbreviation varchar(5) AS
INSERT OccurrenceType(Type, Abbreviation) VALUES(@type, @abbreviation)
SELECT @type_id=SCOPE_IDENTITY()
GO
ALTER PROC dbo.spEmployeeTardyDelete @tardy_id int AS EXEC dbo.spOccurrenceDelete @tardy_id
GO
ALTER PROC dbo.spEmployeeTardyInsert
	@date int,
	@employee_id int,
	@excused bit,
	@note varchar(4000),
	@tardy_id int out
AS
DECLARE @type_id int, @day int
SELECT @type_id = CASE WHEN @excused=1 THEN 1 ELSE 2 END
SELECT @day = DATEDIFF(d,0,@date)
EXEC dbo.spOccurrenceInsert @tardy_id OUT, @type_id, @employee_id, 1, @day, NULL, @note
GO
ALTER PROC dbo.spEmployeeTardyUpdate
	@date int,	
	@employee_id int,
	@excused bit,
	@note varchar(4000),
	@tardy_id int
AS
DECLARE @type_id int, @day int
SELECT @type_id = CASE WHEN @excused=1 THEN 1 ELSE 2 END
SELECT @day = DATEDIFF(d,0,@date)
EXEC dbo.spOccurrenceUpdate @tardy_id, @type_id, @employee_id, 1, @day, NULL, @note
GO
ALTER PROC dbo.spEmployeeTardyList
	@batch_id int,
	@start_day int,
	@stop_day int
AS
SET NOCOUNT ON

EXEC dbo.spPermissionGetOnPeopleForCurrentUser2 @batch_id, 10012

SELECT T.EmployeeID, Employee = P.[List As], 
[ID] = T.OccurrenceID, 
Attributes = 2 | CASE WHEN T.TypeID=1 THEN 256 ELSE 0 END, 
[Type Mask] = 1073741824,
Type = 'Tardiness',
Types = 'Tardiness',
[Start Day past 1900] = T.[Day past 1900], 
[Start] = dbo.GetDateFromDaysPast1900(T.[Day past 1900]),
Note = SUBSTRING(T.Note, 1, 400),
Excused=CAST(CASE WHEN T.TypeID=1 THEN 1 ELSE 0 END AS bit)
FROM TempX X
INNER JOIN Occurrence T ON X.BatchID = @batch_id AND X.[ID] = T.EmployeeID AND (X.X & 1) = 1 AND [Day past 1900] >= @start_day AND [Day past 1900] <= @stop_day AND T.TypeID IN (1,2)
INNER JOIN dbo.vwPersonListAs P ON T.EmployeeID = P.PersonID
ORDER BY T.[Day past 1900]

DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hour, Created, GETDATE()) > 1
GO
ALTER PROC dbo.spEmployeeMostTruant
	@top int,
	@start_day int,
	@stop_day int,
	@batch_id int
AS
SET NOCOUNT ON

EXEC dbo.spPermissionGetOnPeopleForCurrentUser2 @batch_id, 10003

SET ROWCOUNT @top

DELETE TempX WHERE (X & 1) = 0 OR [ID] NOT IN (
	SELECT DISTINCT EmployeeID FROM Occurrence WHERE [Day past 1900] BETWEEN @start_day AND @stop_day AND TypeID IN (1,2)
)

SELECT EmployeeID = P.PersonID, Employee = P.[List As],
Excused=(SELECT COUNT(*) FROM Occurrence WHERE TypeID = 1 AND EmployeeID = P.PersonID AND [Day past 1900] BETWEEN @start_day AND @stop_day),
UnExcused=(SELECT COUNT(*) FROM Occurrence WHERE TypeID = 2 AND EmployeeID = P.PersonID AND [Day past 1900] BETWEEN @start_day AND @stop_day)
INTO #T
FROM  dbo.vwPersonListAs P
INNER JOIN TempX X ON X.BatchID = @batch_id AND X.[ID] = P.PersonID
ORDER BY (SELECT COUNT(*) FROM Occurrence WHERE EmployeeID = P.PersonID AND [Day past 1900] BETWEEN @start_day AND @stop_day) DESC, P.[List As]

SELECT * FROM #T WHERE Excused != 0 OR Unexcused != 0

DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hour, Created, GETDATE()) > 1
GO
GRANT EXEC ON dbo.spOccurrenceTypeGetTypeFromTypeID TO public
GRANT EXEC ON dbo.spOccurrenceTypeList TO public
GRANT EXEC ON dbo.spOccurrenceTypeSelect To public
GO
ALTER PROC dbo.spEmployeeReviewSummary
	@batch_id int,
	@authorized bit OUT,
	@rating_id int = NULL,
	@type_id int = NULL,
	@next_review bit = NULL,
	@next_review_min int = -2147483648,
	@next_review_max int = 2147483647,
	@reviewed bit = NULL,
	@reviewed_min int = -2147483648,
	@reviewed_max int = 2147483647
AS
SET NOCOUNT ON

EXEC dbo.spPermissionGetOnPeopleForCurrentUser2 @batch_id, 16384
DELETE TempX WHERE BatchID = @batch_id AND X & 1 = 0
SELECT @authorized = CASE WHEN @@ROWCOUNT = 0 THEN 1 ELSE 0 END

SELECT EmployeeID = X.[ID], ReviewID = (
	SELECT TOP 1 ReviewID FROM EmployeeReview ER WHERE ER.EmployeeID = X.[ID] ORDER BY ER.[Day past 1900] DESC
)
INTO #ER
FROM TempX X WHERE X.BatchID = @batch_id

DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1

SELECT 
Employee = P.[List As],
[Next Performance Review] = dbo.GetDateFromDaysPast1900(E.[Next Performance Review Day past 1900]),
[Last Performance Review] = dbo.GetDateFromDaysPast1900(ER.[Day past 1900]),
[Reviewed by] = RB.[List As],
T.[Type],
R.Rating,
Comment = ISNULL(ER.[Comment],'')
FROM #ER
INNER JOIN Employee E ON #ER.EmployeeID = E.EmployeeID
INNER JOIN dbo.vwPersonListAs P ON E.EmployeeID = P.PersonID
LEFT JOIN EmployeeReview ER ON #ER.ReviewID = ER.ReviewID
LEFT JOIN dbo.vwPersonListAs RB ON ER.ReviewedByEmployeeID = RB.PersonID
LEFT JOIN EmployeeReviewType T ON ER.TypeID = T.TypeID
LEFT JOIN EmployeeReviewRating R ON ER.RatingID = R.RatingID
WHERE
(@type_id IS NULL OR @type_id=ER.TypeID) AND
(@rating_id IS NULL OR @rating_id=ER.RatingID) AND
(
	(@reviewed IS NULL) OR
	(@reviewed=0 AND #ER.ReviewID IS NULL) OR
	(@reviewed=1 AND #ER.ReviewID IS NOT NULL AND ER.[Day past 1900] BETWEEN @reviewed_min AND @reviewed_max)
) AND
(
	(@next_review IS NULL) OR
	(@next_review=0 AND E.[Next Performance Review Day past 1900] IS NULL) OR
	(@next_review=1 AND E.[Next Performance Review Day past 1900] IS NOT NULL AND E.[Next Performance Review Day past 1900] BETWEEN @next_review_min AND @next_review_max)
)
ORDER BY P.[List As]
GO
UPDATE Constant SET [Server Version]=74
GO
IF NOT EXISTS(SELECT * FROM ColumnGrid WHERE FieldID=1033)
INSERT ColumnGrid(FieldID, [Table], [Key], colid, AttributeID, Field, Label, Importable, Reportable, [Order])
SELECT 1033, '', '', 0, 8, 'Job Category', 'Job Category', 0, 1, 1105
GO
IF OBJECT_id('dbo.spCertificationListEmployeesWithout') IS NOT NULL DROP PROC dbo.spCertificationListEmployeesWithout
GO
CREATE PROC dbo.spCertificationListEmployeesWithout
	@batch_id int,
	@certification_id int,
	@as_of int,
	@authorized bit OUT
AS
DELETE TempX WHERE BatchID=@batch_id AND [ID] IN (
	SELECT PersonID FROM PersonXCertification WHERE CertificationID=@certification_id AND [Completed Day past 1900] <= @as_of AND ([Expires day past 1900] IS NULL OR [Expires day past 1900] > @as_of)
)

EXEC dbo.spPermissionGetOnPeopleForCurrentUser2 @batch_id, 65536
DELETE TempX WHERE BatchID=@batch_id AND (X & 1) = 0
SELECT @authorized = CASE WHEN @@ROWCOUNT=0 THEN 1 ELSE 0 END

SELECT P.PersonID, Certifications = CAST('' AS varchar(400)), Certification = CAST('' AS varchar(50)) INTO #EC FROM PersonX P
INNER JOIN TempX X ON X.BatchID = @batch_id AND X.[ID] = P.PersonID

DECLARE @certification varchar(50)

DECLARE CertificationCursor CURSOR LOCAL FAST_FORWARD FOR
	SELECT CertificationID, Certification FROM Certification

OPEN CertificationCursor

FETCH CertificationCursor INTO @certification_id, @certification
WHILE @@FETCH_STATUS = 0
BEGIN
	UPDATE #EC SET Certification = ISNULL(
		(SELECT TOP 1 @certification FROM PersonXCertification PC WHERE
		PC.CertificationID = @certification_id AND PC.PersonID = #EC.PersonID AND PC.[Completed Day past 1900] <= @as_of AND (PC.[Expires day past 1900] IS NULL OR PC.[Expires day past 1900] > @as_of)
	),'')
		
	
	UPDATE #EC SET Certifications = SUBSTRING(Certifications + ', ' + Certification, 1, 400)
	WHERE Certification <> '' AND Certifications <> ''

	UPDATE #EC SET Certifications = Certification
	WHERE Certification <> '' AND Certifications = ''
	
	FETCH CertificationCursor INTO @certification_id, @certification
END

CLOSE CertificationCursor

DEALLOCATE CertificationCursor

DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1

SELECT #EC.PersonID, Employee = V.[List As], #EC.Certifications FROM #EC
INNER JOIN vwPersonCalculated V ON #EC.PersonID = V.PersonID
ORDER BY V.[List As]
GO
GRANT EXEC ON dbo.spCertificationListEmployeesWithout TO public
GO
ALTER PROC dbo.spNoteInsurePermission
	@note_id int,
	@permission_required int,
	@authorized bit OUT
AS
DECLARE @attribute_id int, @person_id int
SELECT @person_id=RegardingPersonID,@attribute_id = CASE 
	WHEN SUSER_SNAME() <> [Created By] THEN 131072
	WHEN [Created Day Past 1900]+3 > DATEDIFF(d,0,GETDATE()) THEN 47
	ELSE 48
END
FROM vwNote WHERE NoteID = @note_id
IF @attribute_id IN (47 ,48) AND @permission_required=1 SET @authorized=1
ELSE EXEC dbo.spPermissionInsureForCurrentUserOnPerson @person_id, @attribute_id, @permission_required, @authorized OUT
GO
ALTER PROC dbo.[spPersonUpdate]
	@person_id int,
	@title varchar(50),
	@first_name varchar(50),
	@middle_name varchar(50),
	@last_name varchar(50),
	@suffix varchar(50),
	@male bit,
	@work_email varchar(50),
	@work_phone varchar(50),
	@extension varchar(50),
	@work_phone_note varchar(50),
	@home_office_phone varchar(50),
	@toll_free_phone varchar(50),
	@mobile_phone varchar(50),
	@work_fax varchar(50),
	@pager varchar(50),
	@note varchar(4000) = NULL, -- Note update is optional
	@work_address varchar(50),
	@work_address2 varchar(50),
	@work_city varchar(50),
	@work_state varchar(50),
	@work_zip varchar(50),
	@work_country varchar(50),
	@credentials varchar(50)
AS
DECLARE @result int

DECLARE @authorized bit

EXEC dbo.spPermissionInsureForCurrentUserOnPerson @person_id, 2, 2, @authorized out
IF @authorized = 1 
BEGIN
	UPDATE Person SET
	Title = RTRIM(LTRIM(@title)),
	Credentials = RTRIM(LTRIM(@credentials)),
	[First Name] = RTRIM(LTRIM(@first_name)),
	[Middle Name] = RTRIM(LTRIM(@middle_name)),
	[Last Name] = RTRIM(LTRIM(@last_name)),
	[Home Office Phone] = RTRIM(LTRIM(@home_office_phone)),
	Suffix = RTRIM(LTRIM(@suffix)),
	Male = @male,
	[Work E-mail] = RTRIM(LTRIM(@work_email)),
	[Work Phone] = RTRIM(LTRIM(@work_phone)),
	Extension = RTRIM(LTRIM(@extension)),
	[Work Phone Note] = RTRIM(LTRIM(@work_phone_note)),
	[Toll Free Phone] = RTRIM(LTRIM(@toll_free_phone)),
	[Mobile Phone] = RTRIM(LTRIM(@mobile_phone)),
	[Work Fax] = RTRIM(LTRIM(@work_fax)),
	Pager = RTRIM(LTRIM(@pager)),
	[Work Address] = RTRIM(LTRIM(@work_address)),
	[Work Address (cont.)] = RTRIM(LTRIM(@work_address2)),
	[Work City] = RTRIM(LTRIM(@work_city)),
	[Work State] = RTRIM(LTRIM(@work_state)),
	[Work Zip] = RTRIM(LTRIM(@work_zip)),
	[Work Country] = RTRIM(LTRIM(@work_country)),
	Note = CASE WHEN @note IS NULL THEN Note ELSE RTRIM(LTRIM(@note)) END
	WHERE PersonID = @person_id
END
GO
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID]=OBJECT_id('dbo.TempXYZ') AND name='I')
BEGIN
BEGIN TRAN
	ALTER TABLE dbo.TempXYZ ADD [I] int NULL
	CREATE INDEX IX_TempXYZ_I ON TempXYZ(BatchID,I)
	CREATE INDEX IX_TempXYZ_ItemID ON TempXYZ(ItemID)
COMMIT TRAN
END
GO
IF NOT EXISTS(SELECT * FROM Error WHERE ErrorID=50051)
INSERT Error(ErrorID,Error) VALUES(50051,'This item cannot be added because the system can only track 31 items.')
GO
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID]=OBJECT_id('dbo.JobCategory') AND name='Report Row')
BEGIN
BEGIN TRAN
	ALTER TABLE dbo.JobCategory ADD [Report Row] int NOT NULL DEFAULT(-1)
	EXEC sp_executesql N'UPDATE JobCategory SET [Report Row]=CategoryID WHERE CategoryID BETWEEN 1 AND 9'
	IF NOT EXISTS(SELECT * FROM JobCategory WHERE [Category]='Executives') EXEC sp_executesql N'INSERT JobCategory(Category,[Report Row]) VALUES(''Executives'', 0)'
COMMIT TRAN
END
GO
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [ID]=OBJECT_id('dbo.Race') AND name='Report Column')
BEGIN
BEGIN TRAN

SELECT RaceID, Race, [Report Column]=-1 INTO #RaceTemp FROM dbo.Race
UPDATE #RaceTemp SET [Report Column]=0 WHERE RaceID=3 -- 0 Hispanic/Latino
UPDATE #RaceTemp SET [Report Column]=1 WHERE RaceID=1 -- 1 White
UPDATE #RaceTemp SET [Report Column]=2 WHERE RaceID=2 -- 2 Black/African American
UPDATE #RaceTemp SET [Report Column]=3 WHERE RaceID=4 -- 3 Native Hawaiian/Other Pacific Islander
UPDATE #RaceTemp SET [Report Column]=5 WHERE RaceID=5 -- 5 American Indian/Alaskan

ALTER TABLE dbo.[LocationRaceEEO] DROP CONSTRAINT [FK_LocationRaceEEO_Race]
ALTER TABLE dbo.[PersonX] DROP CONSTRAINT [FK_PersonX_Race]
DROP TABLE dbo.Race

CREATE TABLE dbo.[Race](
	[RaceID] [int] NOT NULL IDENTITY(1,1),
	[Race] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Report Column] [int] NOT NULL DEFAULT (-1),
 CONSTRAINT [PK_Race] PRIMARY KEY NONCLUSTERED 
(
	[RaceID] ASC
),
 CONSTRAINT [IX_Race_Race] UNIQUE CLUSTERED 
(
	[Race] ASC
)
)

ALTER TABLE dbo.[Race] ADD CONSTRAINT [CK_Race_RaceNotBlank] CHECK ([Race]<>'')

SET IDENTITY_INSERT dbo.Race ON
EXEC sp_executesql N'INSERT Race(RaceID,Race,[Report Column])
SELECT RaceID, Race, [Report Column] FROM #RaceTemp'
SET IDENTITY_INSERT dbo.Race OFF

IF NOT EXISTS(SELECT * FROM Race WHERE Race='Asian') EXEC sp_executesql N'INSERT Race(Race,[Report Column]) VALUES (''Asian'', 4)'
IF NOT EXISTS(SELECT * FROM Race WHERE Race='Two or More') EXEC sp_executesql N'INSERT Race(Race,[Report Column]) VALUES (''Two or More'', 6)'
IF NOT EXISTS(SELECT * FROM Race WHERE Race='Native Hawaiian/Other Pacific Islander') UPDATE Race SET Race='Native Hawaiian/Other Pacific Islander' WHERE RaceID=4

ALTER TABLE dbo.[PersonX] ADD CONSTRAINT [FK_PersonX_Race] FOREIGN KEY([RaceID])
REFERENCES dbo.[Race] ([RaceID])

ALTER TABLE dbo.[LocationRaceEEO] ADD CONSTRAINT [FK_LocationRaceEEO_Race] FOREIGN KEY([RaceID])
REFERENCES dbo.[Race] ([RaceID])
ON DELETE CASCADE

COMMIT TRAN
END
GO
IF OBJECT_id('dbo.[Break]') IS NULL
BEGIN
	CREATE TABLE dbo.[Break](
		[ItemID] [int] IDENTITY(1,1) NOT NULL PRIMARY KEY,
		[Start] [int] NOT NULL,
		[Seconds] [int] NOT NULL,
		[Break Start] [int] NOT NULL,
		[Break Seconds] [int] NOT NULL,
	 )

	ALTER TABLE dbo.[Break] ADD CONSTRAINT CK_Break_Seconds CHECK (([Seconds]>(0) AND [Break Seconds]>(0)))
	ALTER TABLE dbo.[Break] ADD CONSTRAINT CK_Break_Start CHECK (([Start]>=(0) AND [Start]<=(86400) AND ([Break Start]>=(0) AND [Break Start]<=(86400))))
END
GO
IF OBJECT_id('FK_PersonX_MaritalStatus') IS NULL
BEGIN
	SET IDENTITY_INSERT MaritalStatus ON

	INSERT MaritalStatus(StatusID,Status)
	SELECT MaritalStatusID, 'Deleted' FROM PersonX WHERE MaritalStatusID NOT IN
	(SELECT StatusID FROM MaritalStatus)

	ALTER TABLE dbo.PersonX WITH NOCHECK ADD CONSTRAINT FK_PersonX_MaritalStatus FOREIGN KEY(MaritalStatusID)
	REFERENCES dbo.MaritalStatus (StatusID)

	SET IDENTITY_INSERT MaritalStatus OFF
END
GO
IF NOT EXISTS(SELECT * FROM syscolumns WHERE id=OBJECT_id('dbo.Constant') AND [name]='Timecard Flags')
ALTER TABLE dbo.Constant ADD [Timecard Flags] int NOT NULL DEFAULT(0)
GO
IF OBJECT_id('CK_ExpenseAccount_InvalidAccountID') IS NOT NULL ALTER TABLE dbo.ExpenseAccount DROP CONSTRAINT CK_ExpenseAccount_InvalidAccountID

IF OBJECT_id('dbo.spLeaveTypeGetTypeID') IS NOT NULL DROP PROC dbo.spLeaveTypeGetTypeID

GO
CREATE PROC dbo.spLeaveTypeGetTypeID
	@type varchar(50),
	@advanced bit,
	@type_id int out
AS
SELECT @type = RTRIM(LTRIM(@type)), @type_id=NULL

IF ISNUMERIC(@type)=1 SELECT @type_id=TypeID FROM LeaveType WHERE TypeID=CAST(@type AS int) AND (@advanced IS NULL OR Advanced=@advanced)
IF @type_id IS NULL SELECT @type_id=TypeID FROM LeaveType WHERE Abbreviation=@type AND (@advanced IS NULL OR Advanced=@advanced)
IF @type_id IS NULL SELECT @type_id=TypeID FROM LeaveType WHERE Type=@type AND (@advanced IS NULL OR Advanced=@advanced)
GO

GRANT EXEC ON dbo.spLeaveTypeGetTypeID TO public
GO
IF NOT EXISTS(SELECT * FROM ColumnGrid WHERE FieldID=108)
INSERT ColumnGrid(FieldID,[Table],[Key],colid,AttributeID,Field,Label,Importable,Reportable,[Order])
VALUES(108,'Employee','EmployeeID',38,16777216,'Reason for Termination','Termination Reason',1,0,6750)

IF NOT EXISTS(SELECT * FROM ColumnGrid WHERE FieldID=1032)
INSERT ColumnGrid(FieldID,[Table],[Key],colid,AttributeID,Field,Label,Importable,Reportable,[Order])
VALUES(1032,'','',0,0,'Union','Union',1,0,1105)
GO
ALTER PROCEDURE dbo.[spUnionList] AS SELECT * FROM [Union] ORDER BY [Union]
GO
ALTER VIEW dbo.[vwPersonXUnion]
As
SELECT PU.*, Joined = dbo.GetDateFromDaysPast1900([Joined Day past 1900]), U.[Union], Person = P.[List As] FROM PersonXUnion PU
INNER JOIN [Union] U ON PU.UnionID = U.UnionID
INNER JOIN dbo.vwPersonListAs P ON PU.PersonID = P.PersonID
GO
IF OBJECT_id('dbo.spPersonXUnionInsertUpdate') IS NOT NULL DROP PROC dbo.spPersonXUnionInsertUpdate
GO
CREATE PROCEDURE dbo.spPersonXUnionInsertUpdate
	@union_id int,
	@person_id int
AS
DECLARE @item_id int

DECLARE @joined int
SELECT @joined=[Seniority Begins Day past 1900] FROM Employee WHERE EmployeeID=@person_id
IF @@ROWCOUNT=0 SELECT @joined=DATEDIFF(d,0,GETDATE())

SELECT TOP 1 @item_id=ItemID FROM PersonXUnion WHERE PersonID=@person_id ORDER BY [Joined Day past 1900] DESC

IF @@ROWCOUNT=1 EXEC dbo.spPersonXUnionUpdate @union_id, @joined, @item_id
ELSE EXEC dbo.spPersonXUnionInsert @person_id, @union_id, @joined, 0
GO
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [id]=OBJECT_id('dbo.Subfolder') AND [name]='Options')
ALTER TABLE Subfolder ADD Options int DEFAULT(0) NOT NULL
GO
IF OBJECT_id('dbo.vwSubfolder') IS NOT NULL DROP VIEW dbo.vwSubfolder
IF OBJECT_id('dbo.vwJobCategory') IS NOT NULL DROP VIEW dbo.vwJobCategory
GO
CREATE VIEW dbo.vwJobCategory AS SELECT * FROM JobCategory
GO
ALTER PROCEDURE dbo.[spJobCategorySelect] @category_id int AS SELECT * FROM JobCategory WHERE CategoryID = @category_id
GO
ALTER PROCEDURE dbo.[spJobCategoryList] AS SET NOCOUNT ON SELECT * FROM vwJobCategory ORDER BY Category
GO
ALTER PROC dbo.[spJobCategoryInsert]
	@category varchar(50),
	@category_id int OUT,
	@report_row int = -1
AS
INSERT JobCategory(Category, [Report Row]) VALUES(@category, @report_row)
SELECT @category_id = SCOPE_IDENTITY()
GO
ALTER PROC dbo.[spJobCategoryUpdate]
	@category varchar(50),
	@category_id int,
	@report_row int = NULL
AS
UPDATE JobCategory SET Category = @category, [Report Row]=ISNULL(@report_row, [Report Row]) WHERE CategoryID = @category_id
GO
CREATE VIEW dbo.vwSubfolder AS SELECT * FROM Subfolder
GO
ALTER PROC dbo.spSubfolderList @options_mask int=0 AS
SET NOCOUNT ON SELECT * FROM vwSubfolder WHERE (@options_mask=0 OR (Options & @options_mask) != 0) ORDER BY Subfolder
GO
ALTER PROC dbo.spSubfolderSelect @subfolder_id int AS
SET NOCOUNT ON SELECT * FROM Subfolder WHERE SubfolderID = @subfolder_id
GO
ALTER PROC dbo.spSubfolderInsert @subfolder varchar(50), @subfolder_id int OUT, @options int=0 AS
INSERT Subfolder(Subfolder,Options) VALUES(@subfolder,@options) SELECT @subfolder_id = SubfolderID FROM Subfolder
GO
ALTER PROC dbo.spSubfolderUpdate @subfolder varchar(50), @subfolder_id int, @options int=NULL AS
UPDATE Subfolder SET Subfolder = @subfolder, Options=CASE WHEN @options IS NULL THEN Options ELSE @options END WHERE SubfolderID = @subfolder_id
GO
IF OBJECT_id('dbo.spPersonUpdateColumnDate') IS NOT NULL DROP PROC dbo.spPersonUpdateColumnDate
GO
-- Checks permissions for person on field and performs update if authorized. @authorized = 0 indicates no update because of lack of permission
CREATE PROC dbo.spPersonUpdateColumnDate
	@person_id int,
	@field_id int,
	@value datetime,
	@authorized bit = NULL out
AS
DECLARE @error int
DECLARE @sql nvarchar(4000)

SET NOCOUNT ON

EXEC dbo.spPersonUpdateColumnBase @person_id, @field_id, NULL, NULL, @sql out, @authorized out, @error out
IF @error = 0 AND @authorized = 1 EXEC sp_executesql @sql, N'@value datetime, @person_id int', @value, @person_id
IF @error <>0 EXEC dbo.spErrorRaise @error
GO
GRANT EXEC ON dbo.spPersonUpdateColumnDate TO public
GO
IF NOT EXISTS(SELECT * FROM LeaveRatePeriod WHERE PeriodID=65540)
INSERT LeaveRatePeriod(PeriodID, GroupID, Period, Example, Payroll, [Order])
SELECT 65540, 4, 'Jan 2, Aug 2', 'Jan 2, Aug 2', 0, 3860
GO
ALTER  PROCEDURE spPersonXUnionUpdate
	@union_id int,
	@joined int,
	@item_id int
AS
DECLARE @person_id int
DECLARE @authorized bit

SELECT @person_id = PersonID FROM PersonXUnion WHERE ItemID = @item_id

EXEC dbo.spPermissionInsureForCurrentUserOnPerson @person_id, 32768, 2, @authorized out

IF @authorized = 1 UPDATE PersonXUnion SET
	UnionID = @union_id,
	[Joined Day past 1900] = @joined
WHERE ItemID = @item_id
GO


UPDATE dbo.ColumnGrid SET Importable=1 WHERE FieldID IN (32, 41, 54)

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [id]=OBJECT_id('dbo.CustomField') AND [name]='TypeID')
ALTER TABLE dbo.CustomField ADD TypeID int NOT NULL DEFAULT(167)

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [id]=OBJECT_id('dbo.CustomField') AND [name]='CopyItemsFromFieldID')
ALTER TABLE dbo.CustomField ADD CopyItemsFromFieldID int NULL

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [id]=OBJECT_id('dbo.CustomField') AND [name]='LocationID')
ALTER TABLE dbo.CustomField ADD LocationID int NOT NULL DEFAULT(0)

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [id]=OBJECT_id('dbo.CustomField') AND [name]='Order')
ALTER TABLE dbo.CustomField ADD [Order] int NOT NULL DEFAULT(0)

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [id]=OBJECT_id('dbo.CustomField') AND [name]='Attributes')
BEGIN
	ALTER TABLE dbo.CustomField ADD [Attributes] int NOT NULL DEFAULT(0)
	EXEC sp_executesql N'UPDATE dbo.CustomField SET [Attributes]=1 WHERE [Textarea]=1'
	ALTER TABLE dbo.CustomField DROP COLUMN Textarea
END



IF OBJECT_id('dbo.spPersonCustomFieldInsert') IS NOT NULL DROP PROC dbo.spPersonCustomFieldInsert
IF OBJECT_id('dbo.vwCustomField') IS NOT NULL DROP VIEW dbo.vwCustomField
GO
DELETE CustomField WHERE [Role Mask]=0 AND FieldID NOT IN (SELECT FieldID FROM PersonCustomField)
GO
CREATE VIEW dbo.vwCustomField
AS
SELECT *, Textarea=CAST(CASE WHEN (Attributes&1)=1 THEN 1 ELSE 0 END AS bit) FROM CustomField
GO
ALTER PROC dbo.spCustomFieldList @rolemask int AS 
SET NOCOUNT ON
SELECT C.* FROM vwCustomField C WHERE [Role Mask] = 0 OR ([Role Mask] & @rolemask != 0) ORDER BY C.[Order],C.Field
GO
ALTER PROC dbo.spCustomFieldSelect @field_id int AS
SET NOCOUNT ON
SELECT * FROM vwCustomField WHERE FieldID = @field_id;
GO
IF OBJECT_id('CustomFieldList') IS NOT NULL DROP TABLE dbo.[CustomFieldList]
GO
IF OBJECT_id('dbo.CustomFieldItem') IS NULL
BEGIN
BEGIN TRAN

CREATE TABLE dbo.[CustomFieldItem] (
	[ItemID] [int] NOT NULL IDENTITY(1,1),
	[FieldID] [int] NOT NULL ,
	[Value] [int] NOT NULL ,
	[Text] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL 
) ON [PRIMARY]

ALTER TABLE dbo.[CustomFieldItem] WITH NOCHECK ADD 
	CONSTRAINT [PK_CustomFieldItem] PRIMARY KEY  CLUSTERED 
	(
		[ItemID]
	)  ON [PRIMARY] 

ALTER TABLE dbo.[CustomFieldItem] ADD 
	CONSTRAINT [FK_CustomFieldItem_CustomField] FOREIGN KEY 
	(
		[FieldID]
	) REFERENCES dbo.[CustomField] (
		[FieldID]
	) ON DELETE CASCADE 

CREATE UNIQUE NONCLUSTERED INDEX [IX_CustomFieldItem] ON dbo.[CustomFieldItem] ([FieldID],[Value])

COMMIT TRAN
END
GO
ALTER PROC dbo.spPersonCustomFieldUpdate
	@person_id int,	
	@field_id int,
	@value sql_variant
AS
DECLARE @authorized bit

EXEC dbo.spPermissionInsureForCurrentUserOnPerson @person_id, 4194304, 2, @authorized out

IF @authorized = 1
BEGIN
	DECLARE @type_id int
	SELECT @type_id=TypeID FROM CustomField WHERE FieldID=@field_id

	IF @type_id=1 UPDATE dbo.PersonCustomField SET Value = CAST(@value AS int) WHERE PersonID = @person_id AND FieldID = @field_id
	ELSE IF @type_id=2
	BEGIN
		DECLARE @t varchar(50)
		SET @t = CAST(@value AS varchar(50))
		IF @t LIKE '%,%%%' SET @t = REPLACE(CAST(@t AS varchar(50)), ',', '')
		UPDATE dbo.PersonCustomField SET Value = CAST(@t AS decimal(29,6)) WHERE PersonID = @person_id AND FieldID = @field_id
	END
	ELSE IF @type_id=3
	BEGIN
		IF @value IS NULL SET @value = 0
		UPDATE dbo.PersonCustomField SET Value = CAST(@value AS bit) WHERE PersonID = @person_id AND FieldID = @field_id
	END
	ELSE IF @type_id=5 UPDATE dbo.PersonCustomField SET Value = CAST(@value AS datetime) WHERE PersonID = @person_id AND FieldID = @field_id
	ELSE UPDATE dbo.PersonCustomField SET Value = CAST(@value AS varchar(4000)) WHERE PersonID = @person_id AND FieldID = @field_id

	
END
GO
ALTER PROC dbo.spCustomFieldInsert
	@field varchar(50),
	@textarea bit=NULL,
	@rolemask int,
	@field_id int OUT,
	@type_id int=167,
	@location_id int=0,
	@attributes int=0,
	@copy_field_id int=NULL
AS
IF @textarea IS NOT NULL SET @attributes=@textarea

DECLARE @order int

SELECT @order = ISNULL(MAX([Order]), 0) + 1 FROM CustomField WHERE FieldID=@field_id
INSERT CustomField(Field, Attributes, [Role Mask], TypeID, LocationID, [Order], CopyItemsFromFieldID)
VALUES(@field,@attributes,@rolemask,@type_id,@location_id,@order,@copy_field_id)

SELECT @field_id = SCOPE_IDENTITY()
GO
GRANT EXEC ON dbo.spReportTemplateFieldDelete TO public
GRANT EXEC ON dbo.spReportTemplateFieldInsert TO public
GRANT EXEC ON dbo.spReportTemplateUpdate TO public
GRANT EXEC ON dbo.spReportTemplateInsert TO public
GRANT EXEC ON dbo.spReportTemplateDelete TO public
GO
ALTER PROCEDURE dbo.spReportTemplateFieldDelete
	@template_id int
AS
IF PERMISSIONS(OBJECT_id('dbo.spReportTemplateUpdate')) & 32 = 32 OR 
	PERMISSIONS(OBJECT_id('dbo.spReportTemplateInsert')) & 32 = 32 OR
	PERMISSIONS(OBJECT_id('dbo.spReportTemplateDelete')) & 32 = 32
DELETE ReportTemplateField WHERE TemplateID = @template_id
GO
ALTER PROCEDURE dbo.[spReportTemplateFieldInsert]
	@template_id int,
	@field_id int
AS
IF PERMISSIONS(OBJECT_id('dbo.spReportTemplateUpdate')) & 32 = 32 OR 
	PERMISSIONS(OBJECT_id('dbo.spReportTemplateInsert')) & 32 = 32 OR
	PERMISSIONS(OBJECT_id('dbo.spReportTemplateDelete')) & 32 = 32
INSERT ReportTemplateField(TemplateID,FieldID) VALUES (@template_id,@field_id)
GO
ALTER PROC dbo.spPermissionUpdateUserComment
	@uid int,
	@permissions varchar(4000)
AS
SET NOCOUNT ON

IF LEN(@permissions) = 0 DELETE UserPermissionComment WHERE UID = @uid
ELSE
BEGIN
	UPDATE UserPermissionComment SET [Permissions] = @permissions WHERE UID = @uid
	IF @@ROWCOUNT = 0 INSERT UserPermissionComment(UID, [Permissions]) VALUES(@uid, @permissions)
END
GO
IF OBJECT_id('dbo.ReportCustom') IS NOT NULL AND NOT EXISTS(SELECT * FROM syscolumns WHERE [name]='Other Parameters' AND [id]=OBJECT_id('dbo.ReportCustom'))
DROP TABLE dbo.ReportCustom
GO
IF OBJECT_id('dbo.ReportCustom') IS NULL
CREATE TABLE dbo.ReportCustom (
	ReportID int IDENTITY(1,1) PRIMARY KEY NOT NULL,
	Report varchar(50) NOT NULL,
	[Order] int NOT NULL,
	[RPT Relative Path] varchar(400) NOT NULL,
	[Stored Proc] sysname NOT NULL,
	[Filter Form Mask] int NOT NULL, -- 1=batch_id 2=person_id 4=date 8=period 16=other
	[Other Parameters] varchar(400) NOT NULL,
	Instructions varchar(400) NOT NULL
)
GO
IF OBJECT_id('dbo.spReportCustomList') IS NOT NULL DROP PROC dbo.spReportCustomList
IF OBJECT_id('dbo.spReportCustomSelect') IS NOT NULL DROP PROC dbo.spReportCustomSelect
IF OBJECT_id('dbo.vwReportCustom') IS NOT NULL DROP VIEW dbo.vwReportCustom
GO
CREATE VIEW dbo.vwReportCustom AS SELECT * FROM dbo.ReportCustom
GO
CREATE PROC dbo.spReportCustomList AS SELECT * FROM vwReportCustom ORDER BY [Order]
GO
CREATE PROC dbo.spReportCustomSelect @report_id int AS SELECT * FROM vwReportCustom WHERE ReportID=@report_id ORDER BY [Report]
GO
GRANT EXEC ON dbo.spReportCustomList TO public
GRANT EXEC ON dbo.spReportCustomSelect TO public

GO
IF OBJECT_id('dbo.spEmployeeLeaveCalcForType') IS NOT NULL DROP PROC dbo.spEmployeeLeaveCalcForType
GO
CREATE PROC dbo.spEmployeeLeaveCalcForType
	@type_id int
AS
DECLARE @employee_id int

DECLARE e_cursor CURSOR LOCAL FAST_FORWARD FOR 
SELECT E.EmployeeID FROM Employee E WHERE E.EmployeeID IN 
(SELECT U.EmployeeID FROM EmployeeLeaveUsed U WHERE ((U.[Type Mask] | U.[Advanced Type Mask]) & @type_id) != 0) OR E.EmployeeID IN
(SELECT U.EmployeeID FROM EmployeeLeaveUsedItem I INNER JOIN EmployeeLeaveUsed U ON I.LeaveID=U.LeaveID AND I.TypeID=@type_id)

OPEN e_cursor
FETCH e_cursor INTO @employee_id
WHILE @@FETCH_STATUS = 0
BEGIN
	EXEC dbo.spEmployeeLeaveCalcForEmployeeType @employee_id, @type_id, -2147483648

	FETCH e_cursor INTO @employee_id
END
GO
GRANT EXEC ON dbo.spEmployeeLeaveCalcForType TO public
GO
ALTER PROC dbo.spLeaveTypeDeleteCheck
	@type_id int,
	@exists bit out
AS
SELECT @exists = 0

SELECT @exists = 1 FROM EmployeeLeaveUsedItem WHERE @type_id = TypeID
--IF @exists = 0 SELECT @exists = 1 FROM LeaveRate WHERE @type_id = TypeID
--IF @exists = 0 SELECT @exists = 1 FROM EmployeeLeaveUsedCompCost WHERE @type_id = TypeID
IF @exists = 0 SELECT @exists = 1 FROM EmployeeLeaveUnused WHERE @type_id = TypeID
IF @exists = 0 SELECT @exists = 1 FROM EmployeeLeaveEarned WHERE @type_id = TypeID
IF @exists = 0 SELECT @exists = 1 FROM EmployeeLeaveUsedItem WHERE @type_id = TypeID
IF @exists = 0 SELECT @exists = 1 FROM LeaveLimit WHERE @type_id = TypeID
IF @exists = 0 SELECT @exists = 1 FROM EmployeeLeaveUsedItem WHERE @type_id = TypeID
IF @exists = 0 SELECT @exists = 1 FROM EmployeeLeaveUsed WHERE (([Type Mask] | [Advanced Type Mask]) & @type_id) != 0
GO
ALTER PROC dbo.spLeaveTypeDelete
	@type_id int,
	@new_type_id int
AS
DECLARE @error int, @source_type_id int

SELECT @error = 0, @source_type_id = NULL

BEGIN TRAN

SELECT @source_type_id=CarryoverSourceLeaveTypeID FROM dbo.Constant WHERE CarryoverTargetLeaveTypeID=@type_id
UPDATE Constant SET CarryoverSourceLeaveTypeID = NULL, CarryoverTargetLeaveTypeID = NULL WHERE @type_id IN (CarryoverSourceLeaveTypeID, CarryoverTargetLeaveTypeID)
DELETE LeaveRate WHERE @type_id = TypeID
--DELETE EmployeeLeaveUsedCompCost WHERE @type_id = TypeID
DELETE EmployeeLeaveUnused WHERE @type_id = TypeID
DELETE EmployeeLeaveEarned WHERE @type_id = TypeID
DELETE LeaveLimit WHERE @type_id = TypeID

IF @new_type_id IS NULL 
BEGIN
	DELETE EmployeeLeaveUsedItem WHERE @type_id = TypeID
	DELETE U FROM EmployeeLeaveUsed U WHERE ((U.[Type Mask] | U.[Advanced Type Mask]) & @type_id) != 0 AND
	(SELECT COUNT(*) FROM EmployeeLeaveUsedItem I WHERE I.LeaveID=U.LeaveID) = 0
	EXEC dbo.spEmployeeLeaveCalcForType @type_id

	UPDATE L SET 
	[Advanced Type Mask] = [Advanced Type Mask] & ~@type_id,
	[Type Mask] = ISNULL((SELECT SUM(I.TypeID) FROM vwEmployeeLeaveUsedItemDistinctTypes I WHERE I.LeaveID = L.LeaveID), 0),
	Seconds = ISNULL((
		SELECT SUM(Seconds) FROM EmployeeLeaveUsedItem I WHERE I.LeaveID = L.LeaveID
	), 0)
	FROM EmployeeLeaveUsed L WHERE ((L.[Type Mask] | L.[Advanced Type Mask]) & @type_id) != 0
END
ELSE
BEGIN
	UPDATE EmployeeLeaveUsedItem SET TypeID = @new_type_id WHERE TypeID = @type_id
	UPDATE EmployeeLeaveUsed SET 
	[Advanced Type Mask] = ([Advanced Type Mask] | @new_type_id) & ~@type_id,
	[Type Mask] = ([Type Mask] | @new_type_id) & ~@type_id
	WHERE (([Type Mask] | [Advanced Type Mask]) &  @type_id) != 0
	
	EXEC dbo.spEmployeeLeaveCalcForType @new_type_id
END

DELETE LeaveType WHERE @type_id = TypeID
IF @source_type_id IS NOT NULL EXEC dbo.spEmployeeLeaveCalcForType @source_type_id

COMMIT TRAN
GO
ALTER PROC dbo.spEmployeeCountEEO @start int, @stop int, @location_id int AS EXEC dbo.spErrorRaise 50046
GO
IF OBJECT_id('dbo.vwCustomFieldItem') IS NOT NULL DROP VIEW dbo.vwCustomFieldItem
IF OBJECT_id('dbo.spCustomFieldItemDelete') IS NOT NULL DROP PROC dbo.spCustomFieldItemDelete
IF OBJECT_id('dbo.spCustomFieldItemInsert') IS NOT NULL DROP PROC dbo.spCustomFieldItemInsert
IF OBJECT_id('dbo.spCustomFieldItemUpdate') IS NOT NULL DROP PROC dbo.spCustomFieldItemUpdate
IF OBJECT_id('dbo.spCustomFieldItemList') IS NOT NULL DROP PROC dbo.spCustomFieldItemList
IF OBJECT_id('dbo.spCustomFieldMoveUp') IS NOT NULL DROP PROC dbo.spCustomFieldMoveUp
IF OBJECT_id('dbo.spCustomFieldMoveDown') IS NOT NULL DROP PROC dbo.spCustomFieldMoveDown
IF OBJECT_id('dbo.spCustomFieldStraighten') IS NOT NULL DROP PROC dbo.spCustomFieldStraighten
GO
CREATE VIEW dbo.vwCustomFieldItem AS SELECT * FROM CustomFieldItem
GO
CREATE PROC dbo.spCustomFieldStraighten
AS
DECLARE @field_id int

SELECT TOP 1 @field_id = MIN(FieldID) FROM CustomField GROUP BY [Order] HAVING COUNT(*) > 1
WHILE @@ROWCOUNT > 0
BEGIN
	UPDATE [CustomField] SET [Order] = [Order] + 1 WHERE FieldID = @field_id
	SELECT TOP 1 @field_id = MIN(FieldID) FROM CustomField GROUP BY [Order] HAVING COUNT(*) > 1
END
GO
CREATE PROC dbo.spCustomFieldMoveDown
	@field_id int
AS
DECLARE @next_type_id int
DECLARE @order int, @next_order int

SELECT @order = [Order] FROM CustomField WHERE FieldID = @field_id
SELECT TOP 1 @next_type_id = FieldID FROM CustomField WHERE [Order] > @order ORDER BY [Order]
SELECT @next_order = [Order] FROM CustomField WHERE FieldID = @next_type_id

IF @next_order IS NOT NULL
BEGIN
	UPDATE CustomField SET [Order] = @next_order WHERE FieldID = @field_id
	UPDATE CustomField SET [Order] = @order WHERE FieldID = @next_type_id
END
EXEC dbo.spCustomFieldStraighten
GO
CREATE PROC dbo.[spCustomFieldMoveUp]
	@field_id int
AS
DECLARE @previous_requirement_id int
DECLARE @order int, @previous_order int

SELECT @order = [Order] FROM CustomField WHERE FieldID = @field_id
SELECT TOP 1 @previous_requirement_id = FieldID FROM CustomField WHERE [Order] < @order ORDER BY [Order] DESC
SELECT @previous_order = [Order] FROM CustomField WHERE FieldID = @previous_requirement_id

IF @previous_order IS NOT NULL
BEGIN
	UPDATE CustomField SET [Order] = @previous_order WHERE FieldID = @field_id
	UPDATE CustomField SET [Order] = @order WHERE FieldID = @previous_requirement_id
END
EXEC dbo.spCustomFieldStraighten
GO
CREATE PROC dbo.spCustomFieldItemDelete @item_id int AS DELETE CustomFieldItem WHERE ItemID=@item_id
GO
CREATE PROC dbo.spCustomFieldItemUpdate
	@item_id int,
	@text varchar(50)
AS
UPDATE CustomFieldItem SET [Text]=@text WHERE ItemID=@item_id
GO
CREATE PROC dbo.spCustomFieldItemList @field_id int AS SELECT * FROM vwCustomFieldItem WHERE FieldID=@field_id ORDER BY [Text]
GO
CREATE PROC dbo.spCustomFieldItemInsert
	@field_id int,
	@text varchar(50),
	@value int = null OUT,
	@item_id int OUT
AS
DECLARE @continue int, @error bit
SELECT @value = 1, @continue = 0, @error = 0
SELECT @continue = 1 FROM CustomFieldItem WHERE FieldID=@field_id AND ItemID=@value
WHILE @continue = 1
BEGIN
	SELECT @value = @value * 2, @continue = 0
	IF @value = 0x40000000 SELECT @error = 1 FROM CustomFieldItem WHERE FieldID=@field_id AND [Value]=@value
	ELSE SELECT @continue = 1 FROM CustomFieldItem WHERE FieldID=@field_id AND [Value]=@value
END
IF @error = 1 EXEC dbo.spErrorRaise 50051
ELSE
BEGIN
	INSERT CustomFieldItem(FieldID, [Value], [Text])
	VALUES(@field_id, @value, @text)

	SET @item_id=SCOPE_IDENTITY()
END
GO
GRANT EXEC ON dbo.spCustomFieldItemList TO public
GO
UPDATE Constant SET [Server Version]=79
GO