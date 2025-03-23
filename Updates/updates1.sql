IF OBJECT_ID('dbo.PK_PermissionObject') IS NOT NULL ALTER TABLE dbo.PermissionObject DROP PK_PermissionObject
DELETE PermissionObjectX
DELETE PermissionObject

ALTER TABLE [dbo].[PermissionObject] WITH NOCHECK ADD 
	CONSTRAINT [PK_PermissionObject] PRIMARY KEY CLUSTERED 
	(
		[ObjectID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
GO


IF OBJECT_ID('dbo.spAdminCompareCalculatedToActual') IS NULL DROP PROC dbo.spAdminCompareCalculatedToActual
IF OBJECT_ID('dbo.spEmployeeLeaveSummarizeUnusedPaidLeaveAsOfToday') IS NULL DROP PROC dbo.spEmployeeLeaveSummarizeUnusedPaidLeaveAsOfToday
DELETE ColumnGrid WHERE FieldID = 57
GO
UPDATE Constant SET DefaultLeaveRatePeriodID = 22530 WHERE DefaultLeaveRatePeriodID NOT IN
(
	SELECT PeriodID FROM LeaveRatePeriod
)

IF OBJECT_ID('dbo.FK_Constant_LeaveRatePeriod') IS NULL ALTER TABLE [dbo].[Constant] ADD 
CONSTRAINT [FK_Constant_LeaveRatePeriod] FOREIGN KEY 
(
	[DefaultLeaveRatePeriodID]
) REFERENCES [dbo].[LeaveRatePeriod] (
	[PeriodID]
)

IF OBJECT_ID('dbo.FK_EmployeeCompensation_Position') IS NULL 
BEGIN
	DELETE EmployeeCompensation WHERE PositionID NOT IN (SELECT PositionID FROM Position)
	ALTER TABLE [dbo].[EmployeeCompensation] ADD 
	CONSTRAINT [FK_EmployeeCompensation_Position] FOREIGN KEY 
	(
		[PositionID]
	) REFERENCES [dbo].[Position] (
		[PositionID]
	)
END
GO
IF OBJECT_ID('dbo.spCompanyUdpdateCarryover') IS NOT NULL DROP PROC dbo.spCompanyUdpdateCarryover
IF OBJECT_ID('dbo.spCompanyUpdateCarryover') IS NOT NULL DROP PROC dbo.spCompanyUpdateCarryover
GO
CREATE PROC dbo.spCompanyUpdateCarryover
	@source_type_id int,
	@target_type_id int
AS
SET NOCOUNT ON

UPDATE Constant SET CarryoverSourceLeaveTypeID = @source_type_id, CarryoverTargetLeaveTypeID = @target_type_id
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
ALTER PROC dbo.spLeaveCreateRandomData
AS
DECLARE @employee_id int
DECLARE @hired_day int
DECLARE @m18 int
DECLARE @day int
DECLARE @length int
DECLARE @leave_id int
DECLARE @seconds int
DECLARE @batch_id int
DECLARE @type_id int
DECLARE @types int
DECLARE @approval_type_id int

SET NOCOUNT ON

DELETE EmployeeLeaveUsed
DELETE EmployeeLeaveEarned
DELETE EmployeeLeavePlan

IF NOT EXISTS(SELECT * FROM LeaveApprovalType) INSERT LeaveApprovalType(Type) VALUES('Prearranged')

UPDATE Constant SET [Leave Note] = ''

SELECT @m18 = DATEDIFF(d, 0, GETDATE()) - 500, @batch_id = RAND() * 2147483647, @types = 0
SELECT TOP 1 @approval_type_id = TypeID FROM LeaveApprovalType


CREATE TABLE #T(Ordinal int, TypeID int)


DECLARE t_cursor CURSOR LOCAL FOR SELECT TypeID FROM LeaveType WHERE Advanced = 0
OPEN t_cursor
FETCH NEXT FROM t_cursor INTO @type_id

WHILE @@FETCH_STATUS = 0
BEGIN
	INSERT #T VALUES(@types, @type_id)
	SELECT @types = @types + 1
	FETCH NEXT FROM t_cursor INTO @type_id
END
CLOSE t_cursor
DEALLOCATE t_cursor


DECLARE t_cursor CURSOR LOCAL FOR SELECT TypeID FROM LeaveType WHERE Advanced = 1


UPDATE Employee SET [Ongoing Condition] = 0, [Recertify Condition Day past 1900] = NULL

DECLARE e_cursor CURSOR LOCAL FOR SELECT Employee.EmployeeID, Employee.[Seniority Begins Day past 1900], Shift.[Seconds per Day]  FROM Employee
INNER JOIN Shift ON Employee.ShiftID = Shift.ShiftID

OPEN e_cursor
FETCH NEXT FROM e_cursor INTO @employee_id, @hired_day, @seconds

DECLARE @interval int, @fte numeric(9,4)
SELECT @interval = 150 FROM Employee

WHILE @@FETCH_STATUS = 0
BEGIN
	SELECT @day = CASE WHEN @m18 < @hired_day THEN @hired_day ELSE @m18 END

	SELECT TOP 1 @fte = FTE FROM vwEmployeeCompensation WHERE EmployeeID = @employee_id ORDER BY [Start Day past 1900] DESC
	IF @@ROWCOUNT = 0 SELECT @fte = 1

	IF RAND() < 0.1 UPDATE Employee SET [Ongoing Condition] = 1, [Recertify Condition Day past 1900] = DATEDIFF(d, 0, GETDATE())  + 15 + RAND() * 30 WHERE EmployeeID = @employee_id

	INSERT EmployeeLeavePlan(EmployeeID, PlanID, [Start Day past 1900])
	SELECT TOP 1 @employee_id, PlanID, @day FROM LeavePlan WHERE FTE = @fte ORDER BY PlanID

	WHILE @day < @m18 + 650
	BEGIN
		DECLARE @requested int, @status int, @this_approval_type_id int, @advanced_type_mask int, @atype_id int

		SELECT @day = @day + RAND() * @interval
		SELECT @length = RAND() * 6 + 1
		SELECT @advanced_type_mask = 0
		
		-- Constructs random advanced type mask
		OPEN t_cursor
		FETCH NEXT FROM t_cursor INTO @atype_id
	
		WHILE @@FETCH_STATUS = 0
		BEGIN
			IF RAND() < 0.1 SELECT @advanced_type_mask = @advanced_type_mask | @atype_id
			FETCH NEXT FROM t_cursor INTO @atype_id
		END
		CLOSE t_cursor

		SELECT @requested = @day - RAND() * 7 + 7, @type_id = RAND() * 0.99999 * @types, @status = RAND() * 100
		SELECT @type_id = TypeID FROM #T WHERE Ordinal = @type_id
		SELECT @status = CASE WHEN @status < 10 THEN 1 WHEN @status < 20 THEN 4 ELSE 2 END
		SELECT @this_approval_type_id = CASE WHEN @status = 2 THEN @approval_type_id ELSE NULL END

		EXEC spEmployeeLeaveUsedInsert
			@employee_id = @employee_id,
			@reason_id = NULL,
			@covering_employee_id = NULL,
			@requested = @requested,
			@status = @status,
			@note = '',
			@denial_reason_id = NULL,
			@advanced_type_mask = @advanced_type_mask,
			@authorized_day_past_1900 = NULL,
			@authorizing_employee_id = NULL,
			@approval_type_id = @this_approval_type_id,
			@leave_id = @leave_id OUT

		WHILE @length > 0
		BEGIN
			IF DATEPART(dw, DATEADD(d, 0, @day)) BETWEEN 2 AND 6
			INSERT EmployeeLeaveUsedItem(LeaveID, TypeID, [Day past 1900], Seconds)
			VALUES(@leave_id, @type_id, @day, @seconds)
		
			SELECT @day = @day + 1, @length = @length - 1
		END
	END
	FETCH NEXT FROM e_cursor INTO @employee_id, @hired_day, @seconds
END
CLOSE e_cursor
DEALLOCATE e_cursor

DEALLOCATE t_cursor

DELETE EmployeeLeaveUsed WHERE LeaveID NOT IN (
	SELECT LeaveID FROM EmployeeLeaveUsedItem
)

EXEC spEmployeeLeaveCalcAll
GO
ALTER PROC dbo.spLeaveGetLastEarnedDay
	@employee_id int,
	@type_id int,
	@start_day int,
	@stop datetime out
AS
DECLARE @rolling int
DECLARE @roll int

SET NOCOUNT ON

-- Get shift length
DECLARE @shift_length int
SELECT @shift_length = S.[Seconds per Day] FROM Shift S
INNER JOIN Employee E ON E.ShiftID = S.ShiftID AND E.EmployeeID = @employee_id

DECLARE @monthNum int, @dayNum int, @yearNum int, @holidays int, @shiftOff int
DECLARE @unused_seconds int, @day int

SELECT @day = @start_day, @roll = 0


-- Special case: rolling year (38914)
-- Identify which people have plans of this type that include rolling years as of day
SELECT @rolling = R.Seconds FROM EmployeeLeavePlan EP
INNER JOIN LeaveRate R ON 
EP.EmployeeID = @employee_id AND @start_day >= EP.[Start Day past 1900] AND (@start_day <= EP.[Stop Day past 1900] OR EP.[Stop Day past 1900] IS NULL) AND
R.TypeID = @type_id AND R.PeriodID = 38914 AND EP.PlanID = R.PlanID

IF @@ROWCOUNT != 0 SELECT @roll = 364
ELSE
BEGIN
	-- Special case: rolling 24 months (2049)
	-- Identify which people have plans of this type that include rolling 24 months as of day
	SELECT @rolling = R.Seconds FROM EmployeeLeavePlan EP
	INNER JOIN LeaveRate R ON 
	EP.EmployeeID = @employee_id AND @start_day >= EP.[Start Day past 1900] AND (@start_day <= EP.[Stop Day past 1900] OR  EP.[Stop Day past 1900] IS NULL) AND
	R.TypeID = @type_id AND R.PeriodID = 2049 AND EP.PlanID = R.PlanID

	IF @@ROWCOUNT != 0 SELECT @roll = 729
END

IF @roll > 0
BEGIN
	-- Rolling year
	DECLARE @block int
	SELECT @unused_seconds = @rolling, @block = 0


	WHILE @day <= @start_day + @roll AND @unused_seconds > @shift_length
	BEGIN
		-- Skip days where employee wouldn't normally work like weekends and holidays
		SELECT @monthNum = MONTH(@day), @dayNum = DAY(@day), @yearNum = YEAR(@day), @holidays = 0, @shiftoff = 0

		SELECT @holidays = COUNT(*) From Holiday
		WHERE [Month] = @monthNum AND [Day] = @dayNum AND ([Year] IS NULL OR [Year] = @yearNum)
		GROUP BY [Month], [Day], [Year]

		SELECT @shiftOff = COUNT(*) from Shift S
		INNER JOIN Employee E ON E.ShiftID = S.ShiftID AND E.EmployeeID = @employee_id
		WHERE (@day-S.[Start Day past 1900])%(S.[Days On]+S.[Days Off]) >= S.[Days On]

		IF @holidays = 0 AND @shiftOff = 0
		BEGIN
			SELECT @block = @block + @shift_length

			SELECT @unused_seconds = @rolling - @block - ISNULL(SUM(I.[Seconds]), 0)
			FROM vwEmployeeLeaveUsedItemApproved I WHERE I.[Day past 1900] BETWEEN (@day - @roll) AND @day AND  EmployeeID = @employee_id AND TypeID = @type_id
		END

		SELECT @day = @day + 1
	END

	SELECT @stop = dbo.GetDateFromDaysPast1900(@day)
END
ELSE
BEGIN
	-- Normal, non-rolling accrual

	DECLARE @accumulated_day int, @accumulated int, @limit_day int
	
	-- Calculate Accumulated
	SELECT @accumulated_day = (
		SELECT MAX(U.[Day Past 1900]) FROM EmployeeLeaveUnused U WHERE U.[Day past 1900] <= @start_day AND U.EmployeeID =  @employee_id AND U.TypeID = @type_id
	),
	@accumulated = 0,
	@unused_seconds = NULL,
	@limit_day = NULL

	SELECT @limit_day = ISNULL(MIN(E.[Day Past 1900]), 2147483647) FROM vwEmployeeLeaveEarned E 
	WHERE E.[Day past 1900] > @start_day AND E.EmployeeID = @employee_id AND E.TypeID = @type_id AND E.[Limit Adjustment] = 1


	SELECT @accumulated = U.Unused
	FROM EmployeeLeaveUnused U WHERE U.EmployeeID = @employee_id AND U.TypeID = @type_id AND U.[Day past 1900] =  @accumulated_day

	-- Calculate available
	SELECT @unused_seconds = MIN(U.Unused) FROM EmployeeLeaveUnused U 
	WHERE U.EmployeeID = @employee_id AND U.TypeID = @type_id AND U.[Day past 1900] >= @day AND U.[Day past 1900] < @limit_day


	SELECT @unused_seconds = @accumulated WHERE @unused_seconds IS NULL OR @unused_seconds > @accumulated
PRINT '----'
PRINT @unused_seconds

	WHILE @day <= @start_day + 364 AND @unused_seconds > @shift_length
	BEGIN
		-- Skip days where employee wouldn't normally work like weekends and holidays
		SELECT @monthNum = MONTH(@day), @dayNum = DAY(@day), @yearNum = YEAR(@day), @holidays = 0, @shiftoff = 0
		SELECT @holidays = COUNT(*) From Holiday
		WHERE [Month] = @monthNum AND [Day] = @dayNum AND ([Year] IS NULL OR [Year] = @yearNum)
		GROUP BY [Month], [Day], [Year]

		SELECT @shiftOff = COUNT(*) from Shift S
		INNER JOIN Employee E ON E.ShiftID = S.ShiftID AND E.EmployeeID = @employee_id
		WHERE (@day-S.[Start Day past 1900])%(S.[Days On]+S.[Days Off])>=S.[Days On]

		IF @holidays = 0 AND @shiftOff = 0 SELECT @unused_seconds = @unused_seconds - @shift_length

		SELECT @day = @day + 1
	END

	SELECT @stop = dbo.GetDateFromDaysPast1900(@day)
END
GO
ALTER PROC dbo.spLeaveTypeDeleteCheck
	@type_id int,
	@exists bit out
AS
SET NOCOUNT ON

SELECT @exists = 0

SELECT @exists = 1 FROM EmployeeLeaveUsedItem WHERE @type_id = TypeID
--IF @exists = 0 SELECT @exists = 1 FROM LeaveRate WHERE @type_id = TypeID
IF @exists = 0 SELECT @exists = 1 FROM EmployeeLeaveUsedCompCost WHERE @type_id = TypeID
IF @exists = 0 SELECT @exists = 1 FROM EmployeeLeaveUnused WHERE @type_id = TypeID
IF @exists = 0 SELECT @exists = 1 FROM EmployeeLeaveEarned WHERE @type_id = TypeID
IF @exists = 0 SELECT @exists = 1 FROM EmployeeLeaveUsedItem WHERE @type_id = TypeID
IF @exists = 0 SELECT @exists = 1 FROM LeaveLimit WHERE @type_id = TypeID
IF @exists = 0 SELECT @exists = 1 FROM EmployeeLeaveUsedItem WHERE @type_id = TypeID
IF @exists = 0 SELECT @exists = 1 FROM EmployeeLeaveUsed WHERE ([Advanced Type Mask] & @type_id) != 0
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
	DELETE EmployeeLeaveUsedCompCost WHERE @type_id = TypeID
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
ALTER PROC dbo.spTaskList
	@owner_id int,
	@regarding_id int,
	@regarding_none bit,
	@due_start int,
	@due_stop int,
	@completed_start int,
	@completed_stop int,
	@complete bit,
	@first_task_id int
AS
DECLARE @batch_id int
DECLARE @show_reminders bit
DECLARE @todaym7 int

SET NOCOUNT ON

-- Gets permissions on tasks
SELECT @batch_id = RAND() * 2147483647

INSERT TempX(BatchID, [ID])
SELECT @batch_id, EmployeeID FROM Employee WHERE @owner_id IS NULL OR @owner_id = EmployeeID

EXEC spPermissionGetOnPeopleForCurrentUser2 @batch_id, 10005
DELETE TempX WHERE BatchID = @batch_id AND (TempX.X & 1) = 0

-- Some alerts like returning from leave are only interesting for a week
SELECT @todaym7 = DATEDIFF(d, 0, GETDATE()) - 7

SELECT @first_task_id = -2147483648 WHERE @first_task_id IS NULL
SELECT @completed_start = -2147483648 WHERE @completed_start IS NULL
SELECT @completed_stop = 0x7FFFFFFF WHERE @completed_stop IS NULL
SELECT @due_start = -2147483648 WHERE @due_start IS NULL
SELECT @due_stop = 0x7FFFFFFF WHERE @due_stop IS NULL

SELECT @show_reminders = CASE WHEN @first_task_id IS NULL OR @first_task_id = -2147483648 THEN 1 ELSE 0 END

SELECT [Reminder Type] = CAST('' AS varchar(50)), ReminderTypeID = NULL, R.OwnerEmployeeID, R.RegardingPersonID, [Text] = R.Task, 
Due = dbo.GetDateFromDaysPast1900(T.[Due Day past 1900]), R.Urgent, [Owner Initials] = O.Initials, [Regarding Initials] =  ISNULL(G.Initials, ''), 
[Owner] = O.[List As], [Regarding] = G.[List As], R.TaskID, R.CreatorEmployeeID, R.[Created Day after 1900], T.ItemID, Completed =  dbo.GetDateFromDaysPast1900(T.[Completed Day past 1900]), [Creator Initials] = C.Initials, [Creator] = C.[List As],
[To Lower] = CAST('' AS varchar(400))
FROM Task R
INNER JOIN TempX X ON X.BatchID = @batch_id AND R.OwnerEmployeeID = X.[ID] -- Filters out tasks that the current user is not allowed  to view
AND R.TaskID >= @first_task_id
INNER JOIN TaskOccurence T ON R.TaskID = T.TaskID 
/*
AND
(
	(@recurrent_status  = 2) OR
	(@recurrent_status = 1 AND (SELECT COUNT(*) FROM TaskOccurence O WHERE O.TaskID = R.TaskID) > 1) OR
	(@recurrent_status = 0 AND (SELECT COUNT(*) FROM TaskOccurence O WHERE O.TaskID = R.TaskID) = 1)
)
*/
INNER JOIN vwPersonCalculated O ON O.PersonID = R.OwnerEmployeeID AND
(T.[Due Day past 1900] >= @due_start AND T.[Due Day past 1900] <= @due_stop) AND
(
	(@complete = 0 AND T.[Completed Day past 1900] IS NULL) OR
	(@complete = 1 AND T.[Completed Day past 1900] IS NOT NULL AND T.[Completed Day past 1900] >= @completed_start AND  T.[Completed Day past 1900] <= @completed_stop) OR
	(@complete Is NULL)
) AND
(@owner_id IS NULL OR R.OwnerEmployeeID = @owner_id)
INNER JOIN vwPersonCalculated C ON C.PersonID = R.CreatorEmployeeID -- AND (@creator_id IS NULL OR R.CreatorEmployeeID =  @creator_id)
LEFT JOIN vwPersonCalculated G ON G.PersonID = R.RegardingPersonID
WHERE 
((@regarding_none = 0) AND (@regarding_id IS NULL OR R.RegardingPersonID = @regarding_id)) OR
((@regarding_none = 1) AND R.RegardingPersonID IS NULL)


UNION

--************************************** (1) ************************************************

SELECT R.[Reminder Type], R.ReminderTypeID, R.OwnerEmployeeID, RegardingPersonID = E.EmployeeID, [Text] = 'Review scheduled. ' +  V.[Full Name] + '''s next review is on ' + CAST(dbo.GetDateFromDaysPast1900([Next Performance Review Day past 1900]) AS varchar(6)),
Due = dbo.GetDateFromDaysPast1900(E.[Next Performance Review Day past 1900]), R.Urgent, R.[Owner Initials], [Regarding Initials] =  V.Initials,
R.Owner ,Regarding = V.[List As], TaskID = NULL, CreatorEmployeeID = NULL, [Created Day after 1900] = NULL, ItemID = NULL, Completed  = NULL, [Creator Initials] = 'System', Creator = 'System',
R.[To Lower]
FROM Employee E
INNER JOIN vwPersonCalculated V ON @show_reminders = 1 AND (@complete = 0 OR @complete IS NULL) AND E.EmployeeID = V.PersonID AND
	E.[Next Performance Review Day past 1900] IS NOT NULL AND E.[Active Employee] = 1 AND E.ManagerID IS NOT NULL
INNER JOIN vwReminderTypes R ON R.ReminderTypeID = 1 AND E.EmployeeID = R.EmployeeID AND 
	dbo.DoRaysIntersect(E.[Next Performance Review Day past 1900] - R.Days, E.[Next Performance Review Day past 1900],  @due_start, @due_stop) = 1 AND
	(@owner_id IS NULL OR R.OwnerEmployeeID = @owner_id) AND
	(@regarding_id IS NULL OR E.EmployeeID = @regarding_id)
INNER JOIN TempX X ON X.BatchID = @batch_id AND R.OwnerEmployeeID = X.[ID]

UNION

--************************************** (2) ************************************************

SELECT R.[Reminder Type], R.ReminderTypeID, R.OwnerEmployeeID, RegardingPersonID = E.EmployeeID, [Text] = 'No review scheduled. ' +  V.[Full Name] + ' has no reviews scheduled', Due = GETDATE(), R.Urgent, R.[Owner Initials], [Regarding Initials] = V.Initials,
R.Owner ,Regarding = V.[List As], TaskID = NULL, CreatorEmployeeID = NULL, [Created Day after 1900] = NULL, ItemID = NULL, Completed  = NULL, [Creator Initials] = 'System', Creator = 'System',
R.[To Lower]
FROM Employee E
INNER JOIN vwPersonCalculated V ON @show_reminders = 1 AND (@complete = 0 OR @complete IS NULL) AND E.EmployeeID = V.PersonID AND
	E.[Next Performance Review Day past 1900] IS NULL AND E.[Active Employee] = 1 AND E.ManagerID IS NOT NULL
INNER JOIN vwReminderTypes R ON R.ReminderTypeID = 2 AND E.EmployeeID = R.EmployeeID AND R.[Active Employee] = 1 AND
(@owner_id IS NULL OR R.OwnerEmployeeID = @owner_id) AND
(@regarding_id IS NULL OR E.EmployeeID = @regarding_id)
INNER JOIN TempX X ON X.BatchID = @batch_id AND R.OwnerEmployeeID = X.[ID]

UNION



--************************************** (3) ************************************************

SELECT R.[Reminder Type], R.ReminderTypeID, R.OwnerEmployeeID, RegardingPersonID = P.PersonID, [Text] = 'Certification expires. ' +  V.[Full Name] + '''s ' + P.Certification + ' expires on '+ CAST(dbo.GetDateFromDaysPast1900([Expires Day past 1900]) AS varchar(6)),  Due = dbo.GetDateFromDaysPast1900(P.[Expires Day past 1900]), R.Urgent, R.[Owner Initials], [Regarding Initials] = V.Initials,
R.Owner ,Regarding = V.[List As], TaskID = NULL, CreatorEmployeeID = NULL, [Created Day after 1900] = NULL, ItemID = NULL, Completed  = NULL, [Creator Initials] = 'System', Creator = 'System',
R.[To Lower]
FROM vwPersonXCertification P
INNER JOIN vwPersonCalculated V ON @show_reminders = 1 AND  (@complete = 0 OR @complete IS NULL) AND P.PersonID = V.PersonID AND 
	P.[Expires Day past 1900] IS NOT NULL
INNER JOIN vwReminderTypes R ON R.ReminderTypeID = 3 AND P.PersonID = R.EmployeeID AND R.[Active Employee] = 1 AND
	dbo.DoRaysIntersect(P.[Expires Day past 1900] - R.Days, P.[Expires Day past 1900], @due_start, @due_stop) = 1 AND
	(@owner_id IS NULL OR R.OwnerEmployeeID = @owner_id) AND
	(@regarding_id IS NULL OR P.PersonID = @regarding_id)
INNER JOIN TempX X ON X.BatchID = @batch_id AND R.OwnerEmployeeID = X.[ID]

UNION

--************************************** (4) ************************************************

SELECT R.[Reminder Type], R.ReminderTypeID, R.OwnerEmployeeID, RegardingPersonID = P.PersonID, [Text] = 'Renew I9 status . ' +  V.[Full Name] + '''s is scheduled to be renewed on '+ CAST(dbo.GetDateFromDaysPast1900([Renew I9 Status Day past 1900]) AS  varchar(6)), Due = dbo.GetDateFromDaysPast1900(P.[Renew I9 Status Day past 1900]), R.Urgent, R.[Owner Initials], [Regarding  Initials] = V.Initials,
R.Owner ,Regarding = V.[List As], TaskID = NULL, CreatorEmployeeID = NULL, [Created Day after 1900] = NULL, ItemID = NULL, Completed  = NULL, [Creator Initials] = 'System', Creator = 'System',
R.[To Lower]
FROM PersonX P
INNER JOIN vwPersonCalculated V ON @show_reminders = 1 AND  (@complete = 0 OR @complete IS NULL) AND P.PersonID = V.PersonID AND
	P.[Renew I9 Status Day past 1900] IS NOT NULL 
INNER JOIN vwReminderTypes R ON R.ReminderTypeID = 4 AND P.PersonID = R.EmployeeID AND R.[Active Employee] = 1 AND
	dbo.DoRaysIntersect(P.[Renew I9 Status Day past 1900] - R.Days, P.[Renew I9 Status Day past 1900], @due_start, @due_stop) =  1 AND
	(@owner_id IS NULL OR R.OwnerEmployeeID = @owner_id) AND
	(@regarding_id IS NULL OR P.PersonID = @regarding_id)
INNER JOIN TempX X ON X.BatchID = @batch_id AND R.OwnerEmployeeID = X.[ID]

UNION

--************************************** (5) ************************************************

SELECT R.[Reminder Type], R.ReminderTypeID, R.OwnerEmployeeID, RegardingPersonID = P.PersonID, [Text] = 'Visa expires. ' + V.[Full Name] + '''s visa expires '+ CAST(dbo.GetDateFromDaysPast1900([Visa Expires Day past 1900]) AS varchar(6)), Due =  dbo.GetDateFromDaysPast1900(P.[Visa Expires Day past 1900]), R.Urgent, R.[Owner Initials], [Regarding Initials] = V.Initials,
R.Owner ,Regarding = V.[List As], TaskID = NULL, CreatorEmployeeID = NULL, [Created Day after 1900] = NULL, ItemID = NULL, Completed  = NULL, [Creator Initials] = 'System', Creator = 'System',
R.[To Lower]
FROM PersonX P
INNER JOIN vwPersonCalculated V ON @show_reminders = 1 AND  (@complete = 0 OR @complete IS NULL) AND P.PersonID = V.PersonID AND 
	P.[Visa Expires Day past 1900] IS NOT NULL
INNER JOIN vwReminderTypes R ON R.ReminderTypeID = 5 AND P.PersonID = R.EmployeeID AND R.[Active Employee] = 1 AND
	dbo.DoRaysIntersect(P.[Visa Expires Day past 1900] - R.Days, P.[Visa Expires Day past 1900], @due_start, @due_stop) = 1 AND
	(@owner_id IS NULL OR R.OwnerEmployeeID = @owner_id) AND
	(@regarding_id IS NULL OR P.PersonID = @regarding_id)
INNER JOIN TempX X ON X.BatchID = @batch_id AND R.OwnerEmployeeID = X.[ID]

UNION

--************************************** (6) ************************************************

SELECT R.[Reminder Type], R.ReminderTypeID, R.OwnerEmployeeID, RegardingPersonID = P.PersonID, [Text] = 'Passport expires. ' +  V.[Full Name] + '''s passport expires '+ CAST(dbo.GetDateFromDaysPast1900([Passport Expires Day past 1900]) AS varchar(6)), Due =  dbo.GetDateFromDaysPast1900(P.[Passport Expires Day past 1900]), R.Urgent, R.[Owner Initials], [Regarding Initials] = V.Initials,
R.Owner ,Regarding = V.[List As], TaskID = NULL, CreatorEmployeeID = NULL, [Created Day after 1900] = NULL, ItemID = NULL, Completed  = NULL, [Creator Initials] = 'System', Creator = 'System',
R.[To Lower]
FROM PersonX P
INNER JOIN vwPersonCalculated V ON @show_reminders = 1 AND  (@complete = 0 OR @complete IS NULL) AND P.PersonID = V.PersonID AND 
	P.[Passport Expires Day past 1900] IS NOT NULL
INNER JOIN vwReminderTypes R ON R.ReminderTypeID = 6 AND P.PersonID = R.EmployeeID AND R.[Active Employee] = 1 AND
	dbo.DoRaysIntersect(P.[Passport Expires Day past 1900] - R.Days, P.[Passport Expires Day past 1900], @due_start, @due_stop)  = 1 AND
	(@owner_id IS NULL OR R.OwnerEmployeeID = @owner_id) AND
	(@regarding_id IS NULL OR P.PersonID = @regarding_id)
INNER JOIN TempX X ON X.BatchID = @batch_id AND R.OwnerEmployeeID = X.[ID]

UNION

--************************************** (7) ************************************************

SELECT R.[Reminder Type], R.ReminderTypeID, R.OwnerEmployeeID, RegardingPersonID = P.PersonID, [Text] = 'Driver license expires. ' +  V.[Full Name] + '''s driver''s license expires '+ CAST(dbo.GetDateFromDaysPast1900([Driver License Expires Day past 1900]) AS  varchar(6)), Due = dbo.GetDateFromDaysPast1900(P.[Driver License Expires Day past 1900]), R.Urgent, R.[Owner Initials], [Regarding  Initials] = V.Initials,
R.Owner ,Regarding = V.[List As], TaskID = NULL, CreatorEmployeeID = NULL, [Created Day after 1900] = NULL,  ItemID = NULL, Completed = NULL, [Creator Initials] = 'System', Creator = 'System',
R.[To Lower]
FROM PersonX P
INNER JOIN vwPersonCalculated V ON @show_reminders = 1 AND  (@complete = 0 OR @complete IS NULL) AND P.PersonID = V.PersonID AND 
	P.[Driver License Expires Day past 1900] IS NOT NULL
INNER JOIN vwReminderTypes R ON R.ReminderTypeID = 7 AND P.PersonID = R.EmployeeID AND R.[Active Employee] = 1 AND
	dbo.DoRaysIntersect(P.[Driver License Expires Day past 1900] - R.Days, P.[Driver License Expires Day past 1900], @due_start,  @due_stop) = 1 AND
	(@owner_id IS NULL OR R.OwnerEmployeeID = @owner_id) AND
	(@regarding_id IS NULL OR P.PersonID = @regarding_id)
INNER JOIN TempX X ON X.BatchID = @batch_id AND R.OwnerEmployeeID = X.[ID]


UNION


--************************************** (8) ************************************************

SELECT R.[Reminder Type], R.ReminderTypeID, R.OwnerEmployeeID, RegardingPersonID = P.PersonID, [Text] = 'Driver insurance expires. '  + V.[Full Name] + '''s insurance expires  '+ CAST(dbo.GetDateFromDaysPast1900([Driver Insurance Expires Day past 1900]) AS  varchar(6)), Due = dbo.GetDateFromDaysPast1900(P.[Driver Insurance Expires Day past 1900]), R.Urgent, R.[Owner Initials], [Regarding  Initials] = V.Initials,
R.Owner ,Regarding = V.[List As], TaskID = NULL, CreatorEmployeeID = NULL, [Created Day after 1900] = NULL, ItemID = NULL, Completed  = NULL, [Creator Initials] = 'System', Creator = 'System',
R.[To Lower]
FROM PersonX P
INNER JOIN vwPersonCalculated V ON @show_reminders = 1 AND  (@complete = 0 OR @complete IS NULL) AND P.PersonID = V.PersonID AND 
	P.[Driver Insurance Expires Day past 1900] IS NOT NULL
INNER JOIN vwReminderTypes R ON R.ReminderTypeID = 8 AND P.PersonID = R.EmployeeID AND R.[Active Employee] = 1 AND
	dbo.DoRaysIntersect(P.[Driver Insurance Expires Day past 1900] - R.Days, P.[Driver Insurance Expires Day past 1900],  @due_start, @due_stop) = 1 AND
	(@owner_id IS NULL OR R.OwnerEmployeeID = @owner_id) AND
	(@regarding_id IS NULL OR P.PersonID = @regarding_id)
INNER JOIN TempX X ON X.BatchID = @batch_id AND R.OwnerEmployeeID = X.[ID]


UNION

--************************************** (9) ************************************************

SELECT R.[Reminder Type], ReminderTypeID = 9, R.OwnerEmployeeID, RegardingPersonID = P.PersonID, [Text] = 'Birthday. ' + V.[Full Name] + '''s birthday is '+ CAST(dbo.GetDateFromDaysPast1900([DOB Day past 1900]) AS varchar(6)), Due  =DATEADD(yyyy,DATEPART(yyyy,GETDATE())-DATEPART(yyyy,P.[DOB Day past 1900]),P.[DOB Day past 1900]), R.Urgent, R.[Owner Initials],  [Regarding Initials] = V.Initials,
R.Owner ,Regarding = V.[List As], TaskID = NULL, CreatorEmployeeID = NULL, [Created Day after 1900] = NULL, ItemID = NULL, Completed  = NULL, [Creator Initials] = 'System', Creator = 'System',
R.[To Lower]
FROM vwPersonX P
INNER JOIN vwPersonCalculated V ON @show_reminders = 1 AND  (@complete = 0 OR @complete IS NULL) AND P.PersonID = V.PersonID AND 
	P.[DOB Day past 1900] IS NOT NULL
INNER JOIN vwReminderTypes R ON R.ReminderTypeID = 9 AND P.PersonID = R.EmployeeID AND R.[Active Employee] = 1 AND
	(
		(MONTH(dbo.GetDateFromDaysPast1900(P.[Birth Day past 1900])) * 100 + DAY(dbo.GetDateFromDaysPast1900(P.[Birth Day past 1900]))) BETWEEN
		MONTH(GETDATE()) * 100 + DAY(GETDATE()) AND
		MONTH(DATEADD(d, R.Days, GETDATE())) * 100 + DAY(DATEADD(d, R.Days, GETDATE()))
	) AND
	(@owner_id IS NULL OR R.OwnerEmployeeID = @owner_id) AND
	(@regarding_id IS NULL OR P.PersonID = @regarding_id)
INNER JOIN TempX X ON X.BatchID = @batch_id AND R.OwnerEmployeeID = X.[ID]

UNION


--************************************** (10) ************************************************

SELECT R.[Reminder Type], R.ReminderTypeID, R.OwnerEmployeeID, RegardingPersonID = P.PersonID, [Text] = 'License expires. ' +  V.[Full Name] + '''s ' + P.License + ' license expires on ' + CAST(dbo.GetDateFromDaysPast1900([Expires Day past 1900]) AS  varchar(6)), Due = dbo.GetDateFromDaysPast1900(P.[Expires Day past 1900]), R.Urgent, R.[Owner Initials], [Regarding Initials] =  V.Initials,
R.Owner ,Regarding = V.[List As], TaskID = NULL, CreatorEmployeeID = NULL, [Created Day after 1900] = NULL, ItemID = NULL, Completed  = NULL, [Creator Initials] = 'System', Creator = 'System',
R.[To Lower]
FROM vwPersonXLicense P
INNER JOIN vwPersonCalculated V ON @show_reminders = 1 AND  (@complete = 0 OR @complete IS NULL) AND P.PersonID = V.PersonID AND 
	P.[Expires Day past 1900] IS NOT NULL
INNER JOIN vwReminderTypes R ON R.ReminderTypeID = 10 AND P.PersonID = R.EmployeeID AND  R.[Active Employee] = 1 AND
	dbo.DoRaysIntersect(P.[Expires Day past 1900] - R.Days, P.[Expires Day past 1900], @due_start, @due_stop) = 1 AND
	(@owner_id IS NULL OR R.OwnerEmployeeID = @owner_id) AND
	(@regarding_id IS NULL OR P.PersonID = @regarding_id)
INNER JOIN TempX X ON X.BatchID = @batch_id AND R.OwnerEmployeeID = X.[ID]

UNION

--************************************** (11) ************************************************
SELECT R.[Reminder Type], R.ReminderTypeID, R.OwnerEmployeeID, RegardingPersonID = U.EmployeeID, [Text] = 'Approve or Deny Leave. '  + V.[Full Name] + ' requested leave starting ' + CAST(dbo.GetDateFromDaysPast1900(U.[Start Day past 1900]) AS varchar(6)) + ', but  the request has not been approved or denied.', Due = dbo.GetDateFromDaysPast1900(U.[Start Day past 1900]), R.Urgent, R.[Owner Initials], [Regarding Initials] = V.Initials,
R.Owner ,Regarding = V.[List As], TaskID = NULL, CreatorEmployeeID = NULL, [Created Day after 1900] = NULL, ItemID = NULL, Completed  = NULL, [Creator Initials] = 'System', Creator = 'System',
R.[To Lower]
FROM EmployeeLeaveUsed U
INNER JOIN vwPersonCalculated V ON @show_reminders = 1 AND  (@complete = 0 OR @complete IS NULL) AND U.EmployeeID = V.PersonID AND 
	U.[Status] = 0
INNER JOIN vwReminderTypes R ON R.ReminderTypeID = 11 AND U.EmployeeID = R.EmployeeID AND
	dbo.DoRaysIntersect(U.[Start Day past 1900] - R.Days, U.[Start Day past 1900], @due_start, @due_stop) = 1 AND
	(@owner_id IS NULL OR R.OwnerEmployeeID = @owner_id) AND
	(@regarding_id IS NULL OR U.EmployeeID = @regarding_id)
INNER JOIN TempX X ON X.BatchID = @batch_id AND R.OwnerEmployeeID = X.[ID]

UNION

--************************************** (12) ************************************************
SELECT R.[Reminder Type], R.ReminderTypeID, R.OwnerEmployeeID, RegardingPersonID = U.EmployeeID, [Text] = 'Returning from Leave. ' +  V.[Full Name] + ' last day on leave is ' + CAST(dbo.GetDateFromDaysPast1900(U.[Stop Day past 1900]) AS varchar(6)) + '.', Due =  dbo.GetDateFromDaysPast1900(U.[Stop Day past 1900]), R.Urgent, R.[Owner Initials], [Regarding Initials] = V.Initials,
R.Owner ,Regarding = V.[List As], TaskID = NULL, CreatorEmployeeID = NULL, [Created Day after 1900] = NULL, ItemID = NULL, Completed  = NULL, [Creator Initials] = 'System', Creator = 'System',
R.[To Lower]
FROM EmployeeLeaveUsed U
INNER JOIN vwPersonCalculated V ON @show_reminders = 1 AND  (@complete = 0 OR @complete IS NULL) AND U.EmployeeID = V.PersonID AND 
	U.[Status] = 1
INNER JOIN vwReminderTypes R ON R.ReminderTypeID = 12 AND U.EmployeeID = R.EmployeeID AND
	dbo.DoRaysIntersect(U.[Stop Day past 1900] - R.Days, U.[Stop Day past 1900], @due_start, @due_stop) = 1 AND U.[Stop Day past 1900] > @todaym7 AND
	(@owner_id IS NULL OR R.OwnerEmployeeID = @owner_id) AND
	(@regarding_id IS NULL OR U.EmployeeID = @regarding_id)
INNER JOIN TempX X ON X.BatchID = @batch_id AND R.OwnerEmployeeID = X.[ID]

UNION

--************************************** (13) ************************************************
SELECT R.[Reminder Type], R.ReminderTypeID, R.OwnerEmployeeID, RegardingPersonID = U.EmployeeID, [Text] = 'Departing for Leave. ' +  V.[Full Name] + '''s scheduled leave starts ' + CAST(dbo.GetDateFromDaysPast1900(U.[Start Day past 1900]) AS varchar(6)) + '.', Due  = dbo.GetDateFromDaysPast1900(U.[Start Day past 1900]), R.Urgent, R.[Owner Initials], [Regarding Initials] = V.Initials,
R.Owner ,Regarding = V.[List As], TaskID = NULL, CreatorEmployeeID = NULL, [Created Day after 1900] = NULL, ItemID = NULL, Completed  = NULL, [Creator Initials] = 'System', Creator = 'System',
R.[To Lower]
FROM EmployeeLeaveUsed U
INNER JOIN vwPersonCalculated V ON @show_reminders = 1 AND  (@complete = 0 OR @complete IS NULL) AND U.EmployeeID = V.PersonID AND 
	U.[Status] = 1
INNER JOIN vwReminderTypes R ON R.ReminderTypeID = 13 AND U.EmployeeID = R.EmployeeID AND
	dbo.DoRaysIntersect(U.[Start Day past 1900] - R.Days, U.[Start Day past 1900], @due_start, @due_stop) = 1 AND U.[Start Day past 1900] > @todaym7 AND
	(@owner_id IS NULL OR R.OwnerEmployeeID = @owner_id) AND
	(@regarding_id IS NULL OR U.EmployeeID = @regarding_id)
INNER JOIN TempX X ON X.BatchID = @batch_id AND R.OwnerEmployeeID = X.[ID]


UNION

-- Recertification for Ongoing Condition

--************************************** (14) ************************************************


SELECT R.[Reminder Type], R.ReminderTypeID, R.OwnerEmployeeID, RegardingPersonID = E.EmployeeID, [Text] =  'Recertification for  Ongoing Condition. ' + V.[Full Name] + '''s medical recertification is due by ' + CAST(dbo.GetDateFromDaysPast1900([Recertify Condition Day past 1900]) AS varchar(6)) + '.',
Due = dbo.GetDateFromDaysPast1900(E.[Recertify Condition Day past 1900]), R.Urgent, R.[Owner Initials], [Regarding Initials] =  V.Initials,
R.Owner ,Regarding = V.[List As], TaskID = NULL, CreatorEmployeeID = NULL, [Created Day after 1900] = NULL, ItemID = NULL, Completed  = NULL, [Creator Initials] = 'System', Creator = 'System',
R.[To Lower]
FROM Employee E
INNER JOIN vwPersonCalculated V ON @show_reminders = 1 AND (@complete = 0 OR @complete IS NULL) AND E.EmployeeID = V.PersonID AND
	E.[Recertify Condition Day past 1900] IS NOT NULL
INNER JOIN vwReminderTypes R ON R.ReminderTypeID = 14 AND E.EmployeeID = R.EmployeeID AND 
	dbo.DoRaysIntersect(E.[Recertify Condition Day past 1900] - R.Days, E.[Recertify Condition Day past 1900], @due_start, @due_stop) = 1 AND
	(@owner_id IS NULL OR R.OwnerEmployeeID = @owner_id) AND
	(@regarding_id IS NULL OR E.EmployeeID = @regarding_id)
INNER JOIN TempX X ON X.BatchID = @batch_id AND R.OwnerEmployeeID = X.[ID]



--************************************** (END) ************************************************

ORDER BY Urgent DESC, Due ASC, Completed ASC



DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1
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
ALTER PROC dbo.spEmployeeLeaveGetAvailable
	@employee_id int,
	@type_id int,
	@day int,
	@seconds int out
AS
DECLARE @d int, @accumulated int, @max int, @authorized bit

SET NOCOUNT ON

EXEC spPermissionInsureForCurrentUserOnPerson @employee_id, 10003, 1, @authorized out
IF @authorized = 1
BEGIN
	SELECT @d = MAX(U.[Day Past 1900]) FROM EmployeeLeaveUnused U WHERE U.[Day past 1900] <= @day AND U.EmployeeID =  @employee_id AND U.TypeID = @type_id
	SELECT @max = ISNULL(MIN(U.[Day past 1900]) - 1, 0x7FFFFFFF) FROM EmployeeLeaveUnused U WHERE U.[Day past 1900] > @day AND  U.EmployeeID = @employee_id AND U.TypeID = @type_id AND U.[Limit Adjustment] = 1
	SELECT @accumulated = 0
	SELECT @accumulated = U.Unused FROM EmployeeLeaveUnused U WhERE U.EmployeeID = @employee_id AND U.TypeID = @type_id AND  U.[Day past 1900] = @d
	SELECT @seconds = MIN(Unused) FROM EmployeeLeaveUnused U WHERE U.[Day past 1900] BETWEEN @day AND @max AND U.EmployeeID =  @employee_id AND U.TypeID = @type_id
	SELECT @seconds = @accumulated WHERE @seconds IS NULL OR @seconds > @accumulated
END

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
EXEC spPermissionInsureForCurrentUserOnPerson @person_id, 2097152, 2, @authorized out
IF @authorized = 1
BEGIN
	-- Insures user has permission to change skill text for all employees
	IF EXISTS(SELECT * FROM Skill WHERE SkillID = @skill_id AND Skill <> @skill)  AND(PERMISSIONS(OBJECT_ID('[dbo].[spSkillUpdate]')) & 32) = 0 EXEC spErrorRaise 50025
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

ALTER PROCEDURE spLocationListAsListItems
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
	SELECT @ptrTarget = TEXTPTR([Leave Note]) FROM Constant
	
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
IF OBJECT_ID('dbo.dbo.spEmployeePositionDelete') IS NOT NULL
DROP TABLE dbo.spEmployeePositionDelete
GO

IF EXISTS(SELECT * FROM syscolumns WHERE [name] = 'Budgeted' AND [id] = OBJECT_ID('Position'))
ALTER TABLE Position DROP COLUMN Budgeted
GO

ALTER VIEW dbo.vwPosition AS
SELECT P.*, G.[Minimum Hourly Pay], G.[Pay Step Increase], G.[Pay Grade], C.Category, S.Status,
[Annualized Pay Range] =
CONVERT(varchar(50), (CAST(G.[Minimum Hourly Pay] * P.FTE * 2080 AS money)), 1)
+ ' to ' +
CONVERT(varchar(50), (CAST(G.[Maximum Hourly Pay] * P.FTE * 2080 AS money)), 1)
FROM Position P
INNER JOIN JobCategory C ON P.CategoryID = C.CategoryID
INNER JOIN PositionStatus S ON P.StatusID= S.StatusID
INNER JOIN vwPayGrade G ON P.PayGradeID = G.PayGradeID
GO

ALTER TABLE dbo.PayGrade ALTER COLUMN [Minimum Hourly Pay] numeric(19, 10)
ALTER TABLE dbo.PayGrade ALTER COLUMN [Maximum Hourly Pay] numeric(19, 10)
ALTER TABLE dbo.PayGrade ALTER COLUMN [Pay Step Increase] numeric(19, 10)
GO

ALTER PROC dbo.spPayGradeUpdate
	@pay_grade_id int,
	@pay_grade varchar(50),
	@minimum numeric(19, 10),
	@maximum numeric(19, 10),
	@step numeric(19, 10)
AS
SET NOCOUNT ON

UPDATE PayGrade SET
[Pay Grade] = @pay_grade,
[Minimum Hourly Pay] = @minimum,
[Maximum Hourly Pay] = @maximum,
[Pay Step Increase] = @step
WHERE PayGradeID = @pay_grade_id

GO
ALTER PROC dbo.spPayGradeInsert
	@pay_grade varchar(50),
	@minimum numeric(19, 10),
	@maximum numeric(19, 10),
	@step numeric(19, 10),
	@pay_grade_id int OUT
AS
SET NOCOUNT ON

INSERT PayGrade([Pay Grade], [Minimum Hourly Pay], [Maximum Hourly Pay], [Pay Step Increase])
VALUES(@pay_grade, @minimum, @maximum, @step)

SELECT @pay_grade_id = SCOPE_IDENTITY()
GO
ALTER PROCEDURE dbo.spPositionGetPay
	@position_id int,
	@step int,
	@pay numeric(19,10) OUT
AS
SET NOCOUNT ON

SELECT @pay = 0
SELECT @pay = G.[Minimum Hourly Pay] + G.[Pay Step Increase] * (@step - 1)
FROM Position P
INNER JOIN PayGrade G ON P.PositionID = @position_id AND P.PayGradeID = G.PayGradeID
GO

IF EXISTS(SELECT * FROM sysobjects WHERE [name] = 'IX_Report_ReportID' AND [id] = OBJECT_ID('dbo.TempXYZ'))
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

If NOT EXISTS(SELECT * FROM sysobjects WHERE [name] = 'CK_Position_FTE' AND [parent_obj] = OBJECT_ID('dbo.Position'))
BEGIN
	UPDATE Position SET FTE = 0.01 WHERE FTE < 0.01
	UPDATE Position SET FTE = 2 WHERE FTE > 2

	ALTER TABLE [dbo].[Position] ADD CONSTRAINT [CK_Position_FTE] CHECK ([FTE] >= 0.01 and [FTE] <= 2)
END

UPDATE Error SET Error ='An entry in the compensation history is invalid. The period for one entry overlaps the period for another entry. This problem is usually caused by failing to click and specify the stop date for either this entry or a prior entry. Check the start and stop dates and try again.' WHERE ErrorID = 50009
GO
ALTER PROCEDURE [dbo].[spExportX1]
	@batch_id int
AS
SET NOCOUNT ON
SELECT PersonID = [ID] INTO #SelectedPeople FROM TempX WHERE BatchID = @batch_id
-- Start --
SELECT E.* FROM vwEmployeeAll E
INNER JOIN #SelectedPeople P ON E.EmployeeID = P.PersonID
-- ##Stop## --
DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1
GO
UPDATE Export SET [Show Filter] = 0 WHERE ExportID IN (2, 3)
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
-- Returns @rows rows that correspond to the payroll period stored in Constant.CurrentPayrollPeriodID
ALTER PROC dbo.spEmployeeTimeCalculateFilterInverse
	@date datetime,
	@rows int,
	@period_id int = NULL
AS
SET NOCOUNT ON

DECLARE @error_message varchar(100)
DECLARE @start datetime
DECLARE @next datetime


--DECLARE @period_id int
IF @period_id IS NULL SELECT @period_id = CurrentPayrollPeriodID FROM Constant


SELECT @error_message = 'spEmployeeTimeCalculateFilterInverse does not handle PeriodID ' + CAST(@period_id AS varchar(100)) + '.'

-- Trims seconds\minutes\ms from @date
SELECT @date = CAST(@date as char(11))
	
DECLARE @temp TABLE (StartDate datetime, StopDate datetime)

-- Weekly and Biweekly **********************************************************************
IF (@period_id & 192) != 0
BEGIN
	DECLARE @step int
	DECLARE @lastsat datetime
	DECLARE @weekday int -- Sun = 1, M = 2, T = 3, W = 4, Th = 5, F= 6, Sat = 7
	DECLARE @payday int -- weekday is current week day. payday is week day that we get paid.

	SELECT @step = CASE WHEN (@period_id & 64) = 64 THEN 2 ELSE 1 END
	SELECT @weekday = DATEPART(dw, @date)
	SELECT @lastsat = DATEADD(d, -@weekday, @date)


	-- Maps period_id to a payday (Sun = 1)
	SELECT @payday = CASE WHEN @period_id IN (200768, 215104, 258176) THEN 1
		WHEN @period_id IN (202816, 217152, 260224) THEN 2
		WHEN @period_id IN (204864, 219200, 262272) THEN 3
		WHEN @period_id IN (206912, 221248, 264320) THEN 4
		WHEN @period_id IN (208960, 223296, 266368) THEN 5
		WHEN @period_id IN (211008, 225344, 268416) THEN 6
		WHEN @period_id IN (213056, 227392, 270464) THEN 7 
	END

	IF @@ROWCOUNT = 0 RAISERROR(@error_message, 16, 1)

	SELECT @start = DATEADD(d, CASE WHEN @weekday > @payday THEN @payday + 1 ELSE @payday - 6 END, @lastsat)

	-- Shift for 1st biweekly set of periods
	If (@period_id & 64) != 0
	BEGIN
		DECLARE @wks int, @wk0 datetime

		SELECT @wk0 = '01/01/04'
		SELECT @wk0 = DATEADD(d,1 - DATEPART(dw, @wk0), @wk0)
		SELECT @wks = DATEDIFF(wk, @wk0, @start) % 2
		

		IF (@period_id < 215104 AND @wks = 1) OR (@period_id >= 215104 AND @wks = 0) 
		BEGIN
			SELECT @start = DATEADD(wk, 1, @start)
			IF @start > @date SELECT @start = DATEADD(wk, -2, @start)
		END
	END

	WHILE @rows > 0
	BEGIN
		SELECT @next = DATEADD(wk, @step, @start)
		INSERT INTO @temp VALUES (@start, DATEADD(d, -1, @next))
		SELECT @start = @next, @rows = @rows - 1
	END
END
ELSE 
BEGIN
	DECLARE @month int
	DECLARE @dayOfMonth int
	DECLARE @year int
	DECLARE @yesterday datetime, @tomorrow datetime
	DECLARE @yearless int

	SELECT @year = YEAR(@date), @month = DATEPART(m, @date), @dayOfMonth = DATEPART(d, @date)
	SELECT @tomorrow = DATEADD(d, 1, @date), @yesterday = DATEADD(d, -1, @date), @yearless = @month * 100 + @dayOfMonth

	-- Bimonthly **********************************************************************
	IF @period_id & 8 = 8
	BEGIN
		-- Bimonthly ending 1/1, 3/1
		IF @period_id = 90120
		BEGIN
			IF @dayOfMonth = 1 AND @month % 2 = 1 SELECT @start = DATEADD(m, -2, @tomorrow)
			ELSE IF @month % 2 = 0 SELECT @start = dbo.GetDateFROMMDY(@month - 1, 2, @year)
			ELSE SELECT @start = dbo.GetDateFromMDY(@month, 2, @year)
		END

		-- Bimonthly ending 2/28|29, 4/30
		ELSE IF @period_id = 92168
		BEGIN
			IF @month >= 11 SELECT @start = dbo.GetDateFromMDY(11, 1, @year)
			ELSE SELECT @start = dbo.GetDateFromMDY(@month - 1 + @month % 2, 1, @year)
		
		END
		ELSE RAISERROR(@error_message, 16, 1)

		WHILE @rows > 0
		BEGIN
			SELECT @next = DATEADD(m, 2, @start)
			INSERT INTO @temp VALUES (@start, DATEADD(d, -1, @next))
			SELECT @start = @next, @rows = @rows - 1
		END
	END

	-- Monthly **********************************************************************
	ELSE IF @period_id & 16 = 16
	BEGIN
		-- Ends First Day of Each Month
		IF @period_id = 126992
		BEGIN
			IF @yearless = 101 SELECT @start = dbo.GetDateFromMDY(12, 2, @year - 1)
			ELSE IF @dayOfMonth = 1 SELECt @start = dbo.GetDateFromMDY(@month - 1, 2, @year)
			ELSE SELECT @start = dbo.GetDateFromMDY(@month, 2, @year)
		END
		-- Ends Last Day of Each Month
		ELSE IF @period_id = 129040
		BEGIN
			SELECT @start = dbo.GetDateFromMDY(@month, 1, @year)
		END

		-- Ends 28th of each month
		ELSE IF @period_id = 131088
		BEGIN
			IF @dayOfMonth >= 29 SELECT @start = dbo.GetDateFromMDY(@month, 29, @year)
			ELSE IF @month = 1 SELECT @start = dbo.GetDateFromMDY(12, 29, @year - 1)
			ELSE SELECT @start = dbo.GetDateFromMDY(@month - 1, 29, @year) 
		END

		-- Ends 15th of each month
		ELSE IF @period_id = 141328
		BEGIN
			IF @dayOfMonth >= 16 SELECT @start = dbo.GetDateFromMDY(@month, 16, @year)
			ELSE IF @month = 1 SELECT @start = dbo.GetDateFromMDY(12, 16, @year - 1)
			ELSE SELECT @start = dbo.GetDateFromMDY(@month - 1, 16, @year) 
		END

		-- Ends 16h of each month
		ELSE IF @period_id = 143376
		BEGIN
			IF @dayOfMonth >= 17 SELECT @start = dbo.GetDateFromMDY(@month, 17, @year)
			ELSE IF @month = 1 SELECT @start = dbo.GetDateFromMDY(12, 17, @year - 1)
			ELSE SELECT @start = dbo.GetDateFromMDY(@month - 1, 17, @year) 
		END

		-- Ends 30th of each month
		ELSE IF @period_id = 145424
		BEGIN
			IF @dayOfMonth >= 31 SELECT @start = dbo.GetDateFromMDY(@month, 31, @year)
			ELSE IF @month = 1 SELECT @start = dbo.GetDateFromMDY(12, 31, @year - 1)
			ELSE SELECT @start = dbo.GetDateFromMDY(@month, 0, @year) -- Last day of last month
		END


		ELSE RAISERROR(@error_message, 16, 1)
		
		WHILE @rows > 0
		BEGIN
			SELECT @next = DATEADD(m, 1, @start)
			INSERT INTO @temp VALUES (@start, DATEADD(d, -1, @next))
			SELECT @start = @next, @rows = @rows - 1
		END
	END

	-- Ends 1st and 15th of each month
	ELSE IF @period_id = 163872
	BEGIN
		IF @dayOfMonth = 1 SELECT @start = dbo.GetDateFromMDY(@month - 1, 16, @year)
		ELSE IF @dayOfMonth <= 15 SELECT @start = dbo.GetDateFromMDY(@month, 2, @year)
		ELSE SELECT @start = dbo.GetDateFromMDY(@month, 16, @year)

		WHILE @rows > 0
		BEGIN
			IF DATEPART(d, @start) = 2 SELECT @next = DATEADD(d, 14, @start)
			ELSE SELECT @next = DATEADD(d, -14, DATEADD(m, 1, @start))

			INSERT INTO @temp VALUES (@start, DATEADD(d, -1, @next))
			SELECT @start = @next, @rows = @rows - 1
		END
	END

	-- Ends 1st and 16th of each month
	ELSE IF @period_id = 165920
	BEGIN
		IF @dayOfMonth = 1 SELECT @start = dbo.GetDateFromMDY(@month - 1, 17, @year)
		ELSE IF @dayOfMonth <= 16 SELECT @start = dbo.GetDateFromMDY(@month, 2, @year)
		ELSE SELECT @start = dbo.GetDateFromMDY(@month, 17, @year)

		WHILE @rows > 0
		BEGIN
			IF DATEPART(d, @start) = 2 SELECT @next = dbo.GetDateFromMDY(MONTH(@start), 17, YEAR(@start))
			ELSE SELECT @next = dbo.GetDateFromMDY(MONTH(@start) + 1, 2, YEAR(@start))

			INSERT INTO @temp VALUES (@start, DATEADD(d, -1, @next))
			SELECT @start = @next, @rows = @rows - 1
		END
	END

	-- Ends 14th and 28th of each month
	ELSE IF @period_id = 167968
	BEGIN
		IF @dayOfMonth <= 14 SELECT @start = dbo.GetDateFromMDY(@month - 1, 29, @year)
		ELSE IF @dayOfMonth <= 28 SELECt @start = dbo.GetDateFromMDY(@month, 15, @year)
		ELSE SELECT @start = dbo.GetDateFromMDY(@month, 29, @year)
		
		WHILE @rows > 0
		BEGIN
			IF DATEPART(d, @start) = 15 SET @next = dbo.GetDateFromMDY(MONTH(@start), 29, YEAR(@start))
			ELSE IF DATEPART(d, @start) >= 29 SET @next = dbo.GetDateFromMDY(MONTH(@start) + 1, 15, YEAR(@start))
			ELSE SET @next = dbo.GetDateFromMDY(MONTH(@start), 15, YEAR(@start))

			INSERT INTO @temp VALUES (@start, DATEADD(d, -1, @next))
			SELECT @start = @next, @rows = @rows - 1
		END
	END

	-- Ends 15th and 28th of each month
	ELSE IF @period_id = 170016
	BEGIN
		IF @dayOfMonth <= 15 SELECT @start = dbo.GetDateFromMDY(@month - 1, 29, @year)
		ELSE IF @dayOfMonth <= 28 SELECt @start = dbo.GetDateFromMDY(@month, 16, @year)
		ELSE SELECT @start = dbo.GetDateFromMDY(@month, 29, @year)
		
		WHILE @rows > 0
		BEGIN
			IF DATEPART(d, @start) = 16 SET @next = dbo.GetDateFromMDY(MONTH(@start), 29, YEAR(@start))
			ELSE IF DATEPART(d, @start) >= 29 SET @next = dbo.GetDateFromMDY(MONTH(@start) + 1, 16, YEAR(@start))
			ELSE SET @next = dbo.GetDateFromMDY(MONTH(@start), 16, YEAR(@start))


			INSERT INTO @temp VALUES (@start, DATEADD(d, -1, @next))
			SELECT @start = @next, @rows = @rows - 1
		END
	END

	-- Ends 15th and 30th of each month
	ELSE IF @period_id = 172064
	BEGIN
		IF @dayOfMonth <= 15 AND @month IN (2, 4, 6, 9, 11) SELECT @start = dbo.GetDateFromMDY(@month - 1, 31, @year)
		ELSE IF @dayOfMonth <= 15 SELECT @start = dbo.GetDateFromMDY(@month, 1, @year)
		ELSE IF @dayOfMonth <= 30 SELECt @start = dbo.GetDateFromMDY(@month, 16, @year)
		ELSE SELECT @start = dbo.GetDateFromMDY(@month, 31, @year)
		
		WHILE @rows > 0
		BEGIN
			IF DATEPART(d, @start) = 16 AND MONTH(@start) IN (2, 4, 6, 9, 11) SET @next = dbo.GetDateFromMDY(MONTH(@start) + 1, 1, YEAR(@start))
			ELSE IF DATEPART(d, @start) = 16 SET @next = dbo.GetDateFromMDY(MONTH(@start), 31, YEAR(@start))
			ELSE IF DATEPART(d, @start) >= 31 SET @next = dbo.GetDateFromMDY(MONTH(@start) + 1, 16, YEAR(@start))
			ELSE SET @next = dbo.GetDateFromMDY(MONTH(@start), 16, YEAR(@start))


			INSERT INTO @temp VALUES (@start, DATEADD(d, -1, @next))
			SELECT @start = @next, @rows = @rows - 1
		END
	END

	-- Ends 15th and last of each month
	ELSE IF @period_id = 174112
	BEGIN
		IF @dayOfMonth <= 15 SELECT @start = dbo.GetDateFromMDY(@month, 1, @year)
		ELSE SELECT @start = dbo.GetDateFromMDY(@month, 16, @year)
		
		WHILE @rows > 0
		BEGIN
			IF DATEPART(d, @start) = 16 SET @next = dbo.GetDateFromMDY(MONTH(@start) + 1, 1, YEAR(@start))
			ELSE SET @next = dbo.GetDateFromMDY(MONTH(@start), 16, YEAR(@start))

			INSERT INTO @temp VALUES (@start, DATEADD(d, -1, @next))
			SELECT @start = @next, @rows = @rows - 1
		END
	END

	ELSE 
	BEGIN
		RAISERROR(@error_message, 16, 1)
	END
END

SELECT * FROM @temp
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
ALTER PROC dbo.spDepartmentDelete
	@department_id int
AS
SET NOCOUNT ON

IF EXISTS(SELECT * FROM Department WHERE DepartmentID != @department_id)
DELETE Department WHERE DepartmentID = @department_id
ELSE EXEC spErrorRaise 50034
GO
ALTER PROC dbo.spDivisionDelete
	@division_id int
AS
SET NOCOUNT ON

IF EXISTS(SELECT * FROM Division WHERE DivisionID != @division_id)
DELETE Division WHERE DivisionID = @division_id
ELSE EXEC spErrorRaise 50035
GO
ALTER PROC dbo.spLocationDelete
	@location_id int
AS
SET NOCOUNT ON

IF EXISTS(SELECT * FROM Location WHERE LocationID != @location_id)
DELETE Location WHERE LocationID = @location_id
ELSE EXEC spErrorRaise 50036
GO
ALTER PROCEDURE spShiftDelete
	@shift_id int
AS
SET NOCOUNT ON

IF EXISTS(SELECT * FROM Shift WHERE ShiftID != @shift_id)
DELETE Shift WHERE ShiftID = @shift_id
ELSE EXEC spErrorRaise 50037
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
	@pay_step int,
	@compensation_id int OUT
AS
DECLARE @authorized bit

SET NOCOUNT ON

EXEC spPermissionInsureForCurrentUserOnPerson @employee_id, 1024, 4, @authorized out

IF @authorized = 1
BEGIN
	BEGIN TRAN

	-- If the last compensation entry for the employee was left open then sets its stop date to one day before the start date for the new entry
	UPDATE EmployeeCompensation SET [Stop Day past 1900] = @start_day_past_1900 - 1 WHERE [Stop Day past 1900] IS NULL AND EmployeeID = @employee_id AND @start_day_past_1900 > [Start Day past 1900]

	-- If @stop is null and there is a next compensation entry for the employee then change @stop to next start - 1
	IF @stop_day_past_1900 IS NULL 
	SELECT @stop_day_past_1900 = [Start Day past 1900] - 1 FROM EmployeeCompensation WHERE EmployeeID = @employee_id AND [Start Day past 1900] > @start_day_past_1900 ORDER BY [Start Day past 1900] 
	

	INSERT EmployeeCompensation(EmployeeID, PeriodID, [Start Day past 1900], [Stop Day past 1900],Note, [Base Pay], [Other Compensation], PositionID, [Pay Step], Budgeted, EmploymentStatusID)
	VALUES (@employee_id, @period_id, @start_day_past_1900, @stop_day_past_1900,@note, @base_pay, @other_compensation, @position_id, @pay_step, @budgeted, @employment_status_id)
	SELECT @compensation_id = @@IDENTITY

	COMMIT TRAN
END
GO
ALTER PROC dbo.spPositionListFillingEmployees
	@batch_id int
AS
DECLARE @today int

SET NOCOUNT ON

EXEC spPermissionGetOnPeopleForCurrentUser2 @batch_id, 1024

CREATE TABLE #P(PositionID int, Employees varchar(8000))

SELECT @today = DATEDIFF(d, 0, GETDATE())

DECLARE p_cursor CURSOR LOCAL FOR 
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
ALTER PROC dbo.spEmployeeTerminate
	@employee_id int,
	@effective int,
	@compensation bit,
	@leave bit,
	@inactive bit,
	@reason varchar(4000),
	@rehire bit
AS
DECLARE @compensation_id int
DECLARE @terminated bit
DECLARE @authorized bit

SET NOCOUNT ON

BEGIN TRAN

EXEC spPermissionInsureForCurrentUserOnPerson @employee_id, 0x1000000, 2, @authorized out

IF @authorized = 1 UPDATE Employee SET [Terminated Day past 1900] = @effective, [Reason for Termination] = @reason, Rehire = @rehire WHERE EmployeeID = @employee_id
SELECT @compensation_id = LastCompensationID FROM Employee WHERE EmployeeID = @employee_id

-- Close employee compensation
IF @compensation = 1 AND NOT (@compensation_id IS NULL) AND  @authorized = 1
BEGIN
	EXEC spPermissionInsureForCurrentUserOnPerson @employee_id, 1024, 2, @authorized out
	IF @authorized = 1 UPDATE EmployeeCompensation SET [Stop Day past 1900] = @effective WHERE CompensationID = @compensation_id AND [Stop Day past 1900] IS NULL
END

-- Inactivates
IF @inactive = 1 AND @authorized = 1
BEGIN
	EXEC spPermissionInsureForCurrentUserOnPerson @employee_id, 8, 2, @authorized out
	IF @authorized = 1 UPDATE Employee SET [Active Employee] = 0 WHERE EmployeeID = @employee_id
END

-- Closes leave plan
IF @leave = 1 AND @authorized = 1
BEGIN
	DECLARE @plan_item_id int
	SELECT TOP 1 @plan_item_id = ItemID FROM EmployeeLeavePlan WHERE EmployeeID = @employee_id AND ([Stop Day past 1900] IS NULL OR [Stop Day past 1900] > @effective) ORDER BY [Start Day past 1900] DESC 

	IF @plan_item_id IS NOT NULL
	BEGIN
		EXEC spPermissionInsureForCurrentUserOnPerson @employee_id, 128, 2, @authorized out
		IF @authorized = 1 
		BEGIN
			UPDATE EmployeeLeavePlan SET [Stop Day past 1900] = @effective WHERE ItemID = @plan_item_id
			EXEC spEmployeeLeaveCalcForEmployee @employee_id, @effective
		END
	END
END

IF @authorized = 1 COMMIT TRAN
ELSE ROLLBACK TRAN
GO
ALTER TRIGGER dbo.CheckPeriodOnEmployeeCompensation ON dbo.EmployeeCompensation
FOR INSERT, UPDATE, DELETE
AS
DECLARE @batch_id int
DECLARE @error int
DECLARE @error_msg varchar(400)
DECLARE @item_id int, @dup_item_id int

SET NOCOUNT ON

SELECT @error = 0, @batch_id = RAND() * 2147483647, @error_msg = '', @dup_item_id = NULL, @item_id = NULL

-- Selects the affected employees into TempX.[ID]
IF EXISTS(SELECT * FROM inserted)
BEGIN
	INSERT TempX (BatchID, [ID])
	SELECT DISTINCT @batch_id, EmployeeID FROM inserted
END
ELSE
BEGIN
	INSERT TempX (BatchID, [ID])
	SELECT DISTINCT @batch_id, EmployeeID FROM deleted
END

-- Updates LastCopmpensationID
UPDATE Employee SET LastCompensationID = (
	SELECT TOP 1 EC.CompensationID FROM EmployeeCompensation EC WHERE EC.EmployeeID = E.EmployeeID
	ORDER BY EC.[Start Day past 1900] DESC
) 
FROM Employee E
INNER JOIN TempX X ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID

-- Checks period integrity if start or stop was inserted or updated
IF (UPDATE([Start Day past 1900]) OR UPDATE([Stop Day past 1900]))
BEGIN
	-- Ensures only the last period is left open
	SELECT TOP 1 @error = 50018 FROM EmployeeCompensation P
	INNER JOIN TempX T ON T.BatchID = @batch_id AND T.[ID] = P.EmployeeID AND P.[Stop Day past 1900] IS NULL
	INNER JOIN EmployeeCompensation P2 ON P.EmployeeID = P2.EmployeeID AND P.CompensationID <> P2.CompensationID AND P2.[Start Day past 1900] >= P.[Start Day past 1900]

	-- Ensures periods for the same employee do not overlap upon insert and update
	SELECT TOP 1 @error = 50010 FROM EmployeeCompensation C
	INNER JOIN [TempX] T ON T.BatchID = @batch_id AND T.[ID] = C.EmployeeID
	INNER JOIN EmployeeCompensation C2 ON C.EmployeeID = C2.EmployeeID AND C.CompensationID <> C2.CompensationID AND C.[Start Day past 1900] BETWEEN C2.[Start Day past 1900] AND ISNULL(C2.[Stop Day past 1900], 0x7FFFFFFF)



	SELECT TOP 1 @dup_item_id = EC2.CompensationID, @item_id = EC.CompensationID FROM EmployeeCompensation EC
	INNER JOIN [TempX] T ON T.BatchID = @batch_id AND T.[ID] = EC.EmployeeID
	INNER JOIN EmployeeCompensation EC2 ON EC.EmployeeID = EC2.EmployeeID AND EC.CompensationID <> EC2.CompensationID AND dbo.DoRaysIntersect(EC.[Start Day past 1900], EC.[Stop Day past 1900], EC2.[Start Day past 1900], EC2.[Stop Day past 1900]) = 1
	
	IF @@ROWCOUNT > 0
	BEGIN
		SELECT @error_msg = 'The compensation entry for ' + P.[First Name] + ' (' + CAST(EC.[Start] AS char(11)) + CASE WHEN EC.[Stop] IS NULL THEN '' ELSE ' to ' +  CAST(EC.[Stop] AS char(11)) END + ') overlaps the entry for '
		FROM vwEmployeeCompensation EC
		INNER JOIN Person P ON EC.CompensationID = @item_id AND EC.EmployeeID = P.PersonID
		
		SELECT @error_msg = @error_msg  + P.[First Name] + ' (' + CAST(EC2.[Start] AS char(11)) + CASE WHEN EC2.[Stop] Is NULL THEN '' ELSE ' to ' +  CAST(EC2.[Stop] AS char(11)) END + '). Please fix the entry and try again.'
		FROM vwEmployeeCompensation EC2
		INNER JOIN Person P ON EC2.CompensationID = @dup_item_id AND EC2.EmployeeID = P.PersonID
	END
END

DELETE [TempX] WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1

IF LEN(@error_msg) > 0 RAISERROR (@error_msg, 16, 1)
ELSE IF @error <> 0 EXEC spErrorRaise @error
IF (@error <> 0 OR LEN(@error_msg) > 0) AND @@TRANCOUNT > 0 ROLLBACK
GO
ALTER VIEW dbo.vwEmployeeLeave
AS
SELECT [Limit Adjustment] = CAST(CASE WHEN E.Auto = 2 THEN 1 ELSE 0 END AS bit), E.[Day past 1900], E.Seconds, [Date] = DATEADD(d, 0, E.[Day past 1900]), [Extended Type Mask] = E.TypeID, E.TypeID, E.EmployeeID FROM EmployeeLeaveEarned E
UNION
SELECT 0, I.[Day past 1900], -I.Seconds, I.[Date], I.[Extended Type Mask], I.TypeID, I.EmployeeID FROM vwEmployeeLeaveUsedItem I
GO
ALTER VIEW dbo.vwEmployeeLeaveUsedItemApproved
AS
SELECT I.[Day past 1900], I.Seconds, I.[Date], I.[Extended Type Mask], I.TypeID, I.EmployeeID FROM vwEmployeeLeaveUsedItem I WHERE I.Status = 2
UNION
SELECT E.[Day past 1900], -E.Seconds, DATEADD(d, 0, E.[Day past 1900]), E.TypeID, E.TypeID, E.EmployeeID FROM EmployeeLeaveEarned E WHERE E.Seconds < 0 AND E.Auto = 0
GO
ALTER PROC dbo.spEmployeeLeaveGetScheduled
	@employee_id int,
	@type_id int,
	@day int,
	@seconds int out
AS
DECLARE @authorized bit
SET NOCOUNT ON

EXEC spPermissionInsureForCurrentUserOnPerson @employee_id, 10003, 1, @authorized out
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

EXEC spPermissionInsureForCurrentUserOnPerson @employee_id, 10003, 1, @authorized out
IF @authorized = 1
BEGIN
	SELECT @seconds = ISNULL(SUM(Seconds), 0) FROM vwEmployeeLeaveUsedItemApproved WHERE ([Extended Type Mask] & @type_id) != 0 AND EmployeeID = @employee_id AND [Day past 1900] = @day
END
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
EXEC spPermissionGetOnPeopleForCurrentUser2 @batch_id, 10003

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
	SELECT @group_id = GroupID FROM LeaveRatePeriod WHERE Payroll = 1 AND PeriodID = (SELECT CurrentPayrollPeriodID FROM Constant)

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
	FROM vwPersonListAs P
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
	FROM vwPersonListAs P CROSS JOIN LeaveType LT
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
	FROM vwPersonListAs P CROSS JOIN LeaveType LT
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
	FROM vwPersonListAs P CROSS JOIN LeaveType LT
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
	FROM vwPersonListAs P CROSS JOIN LeaveType LT
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
	FROM vwPersonListAs P CROSS JOIN LeaveType LT
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
	FROM vwPersonListAs P CROSS JOIN LeaveType LT
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
	FROM vwPersonListAs P CROSS JOIN LeaveType LT
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

EXEC spPermissionGetOnPeopleForCurrentUser2 @batch_id, 10003
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
	SELECT SUM(U.Seconds /  CAST(S.[Seconds per Day] AS numeric(18,4))) FROM vwEmployeeLeaveUsedItemApproved U
	INNER JOIN Shift S ON U.EmployeeID = #E.EmployeeID AND U.[Day past 1900] BETWEEN @start AND @stop AND (U.[Extended Type Mask] & @type_or_mask) <> 0 AND #E.ShiftID = S.ShiftID
), 0),
[Lost Hours] = ISNULL((
	SELECT SUM(U.Seconds) / 3600.0 FROM vwEmployeeLeaveUsedItemApproved U WHERE U.EmployeeID = #E.EmployeeID AND U.[Day past 1900] BETWEEN @start AND @stop AND (U.[Extended Type Mask] & @type_or_mask) <> 0
), 0),
[Working Hours] = dbo.BoundInt(0, DATEDIFF(d, #E.[Seniority Begins], GETDATE()), 365) * S.[Seconds per day] / 3600 * CAST(S.[Days On] AS numeric(18,4)) / CAST(S.[Days On] + S.[Days Off] AS numeric(18,4))

FROM #E
INNER JOIN Shift S ON #E.ShiftID = S.ShiftID



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
INNER JOIN vwPersonListAs E ON #E.EmployeeID = E.PersonID
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
ALTER PROC dbo.spLeaveSummarizeUnused
	@day int,
	@batch_id int
AS
SET NOCOUNT ON

EXEC spPermissionGetOnPeopleForCurrentUser2 @batch_id, 10003
DELETE TempX WHERE BatchID = @batch_id AND (X & 1) = 0

-- Calculate Accumulated
SELECT EmployeeID = X.[ID],
T.TypeID,
[Accumulated Day] = ISNULL((
	SELECT MAX(U.[Day Past 1900]) FROM EmployeeLeaveUnused U WHERE U.[Day past 1900] <= @day AND U.EmployeeID = X.[ID] AND U.TypeID = T.TypeID
), 0),
[Accumulated] = 0,
[Available] = NULL,
[Limit Day] = NULL,
Rolling = 0
INTO #U
FROM TempX X
CROSS JOIN LeaveType T
WHERE X.BatchID = @batch_id AND T.TypeID IN
(
	SELECT TypeID FROM LeaveRate
)

UPDATE #U SET [Limit Day] = ISNULL((
	SELECT MIN(E.[Day Past 1900]) FROM vwEmployeeLeaveEarned E WHERE E.[Day past 1900] > @day AND E.EmployeeID = #U.EmployeeID AND E.TypeID = #U.TypeID AND E.[Limit Adjustment] = 1
), 2147483647)

UPDATE #U SET Accumulated = U.Unused
FROM #U
INNER JOIN EmployeeLeaveUnused U ON U.EmployeeID = #U.EmployeeID AND U.TypeID = #U.TypeID AND U.[Day past 1900] = #U.[Accumulated Day]

-- Calculate available
UPDATE #U SET Available = (
	SELECT MIN(U.Unused) FROM EmployeeLeaveUnused U WHERE U.EmployeeID = #U.EmployeeID AND U.TypeID = #U.TypeID AND U.[Day past 1900] >= @day AND U.[Day past 1900] < #U.[Limit Day]
)
FROM #U

UPDATE #U SET Available = Accumulated WHERE Available IS NULL OR Available > Accumulated










-- Special case: rolling year (38914)

-- Identify which people have plans of this type that include rolling years as of day
UPDATE #U SET Rolling = R.Seconds FROM #U
INNER JOIN EmployeeLeavePlan EP ON #U.EmployeeID = EP.EmployeeID AND @day >= EP.[Start Day past 1900] AND (@day <= EP.[Stop Day past 1900] OR EP.[Stop Day past 1900] IS NULL)
INNER JOIN LeaveRate R ON R.TypeID = #U.TypeID AND R.PeriodID = 38914 AND EP.PlanID = R.PlanID

-- #R holds available leave based on rolling accrual for a given employee over a variety of days (D)
CREATE TABLE #R(
	EmployeeID int,
	TypeID int,
	D int,
	Available int
)

CREATE UNIQUE INDEX R04132005 ON #R(EmployeeID, TypeID, D) WITH IGNORE_DUP_KEY 

INSERT #R
SELECT #U.EmployeeID, #U.TypeID, @day, #U.Rolling FROM #U WHERE Rolling != 0

-- Employees with used leave, start day
INSERT #R
SELECT U.EmployeeID, #U.TypeID, U.[Start Day past 1900], #U.Rolling FROM EmployeeLeaveUsed U
INNER JOIN #U ON #U.Rolling != 0 AND U.EmployeeID = #U.EmployeeID AND U.[Start Day past 1900] BETWEEN @day AND (@day + 364) AND 
(U.[Advanced Type Mask] & #U.TypeID) != 0 AND Status = 2

-- Employees with used leave, stop day
INSERT #R
SELECT U.EmployeeID, #U.TypeID, U.[Stop Day past 1900], #U.Rolling FROM EmployeeLeaveUsed U
INNER JOIN #U ON #U.Rolling != 0 AND U.EmployeeID = #U.EmployeeID AND U.[Stop Day past 1900] BETWEEN @day AND (@day + 364) AND 
(U.[Advanced Type Mask] & #U.TypeID) != 0 AND Status = 2

-- Employees with negative earned leave adjustments
INSERT #R
SELECT E.EmployeeID, #U.TypeID, E.[Day Past 1900], #U.Rolling FROM EmployeeLeaveEarned E
INNER JOIN #U ON #U.Rolling != 0 AND E.Seconds < 0 AND E.[Day past 1900] BETWEEN @day AND (@day + 364) ANd E.TypeID = #U.TypeID


UPDATE #R SET Available = Available - ISNULL((
	SELECT SUM(U.Seconds) FROM vwEmployeeLeaveUsedItemApproved U WHERE U.EmployeeID = #R.EmployeeID AND (U.[Extended Type Mask] & #R.TypeID) != 0 AND U.[Day past 1900] BETWEEN (#R.D - 364) AND #R.D
), 0)

-- Updates #U based on #R
UPDATE #U SET Available = (
	SELECT MIN(Available) FROM #R WHERE #R.EmployeeID = #U.EmployeeID AND #R.TypeID = #U.TypeID
), Accumulated = (
	SELECT Available FROM #R WHERE #R.EmployeeID = #U.EmployeeID AND #R.D = @day AND #R.TypeID = #U.TypeID
)
WHERE Rolling != 0










-- Special case: rolling year (2049)

UPDATE #U SET Rolling = 0
DELETE #R

-- Identify which people have plans of this type that include rolling 24 months as of day
UPDATE #U SET Rolling = R.Seconds FROM #U
INNER JOIN EmployeeLeavePlan EP ON #U.EmployeeID = EP.EmployeeID AND @day >= EP.[Start Day past 1900] AND (@day <= EP.[Stop Day past 1900] OR EP.[Stop Day past 1900] IS NULL)
INNER JOIN LeaveRate R ON R.TypeID = #U.TypeID AND R.PeriodID = 2049 AND EP.PlanID = R.PlanID
 

INSERT #R
SELECT #U.EmployeeID, #U.TypeID, @day, #U.Rolling FROM #U WHERE Rolling != 0

INSERT #R
SELECT U.EmployeeID, #U.TypeID, U.[Start Day past 1900], #U.Rolling FROM EmployeeLeaveUsed U
INNER JOIN #U ON #U.Rolling != 0 AND U.EmployeeID = #U.EmployeeID AND U.[Start Day past 1900] BETWEEN @day AND (@day + 729) AND 
(U.[Advanced Type Mask] & #U.TypeID) != 0 AND Status = 2

INSERT #R
SELECT U.EmployeeID, #U.TypeID, U.[Stop Day past 1900], #U.Rolling FROM EmployeeLeaveUsed U
INNER JOIN #U ON #U.Rolling != 0 AND U.EmployeeID = #U.EmployeeID AND U.[Stop Day past 1900] BETWEEN @day AND (@day + 729) AND 
(U.[Advanced Type Mask] & #U.TypeID) != 0 AND Status = 2

-- Employees with negative earned leave adjustments
INSERT #R
SELECT E.EmployeeID, #U.TypeID, E.[Day Past 1900], #U.Rolling FROM EmployeeLeaveEarned E
INNER JOIN #U ON #U.Rolling != 0 AND E.Seconds < 0 AND E.[Day past 1900] BETWEEN @day AND (@day + 364) ANd E.TypeID = #U.TypeID


UPDATE #R SET Available = Available - ISNULL((
	SELECT SUM(U.Seconds) FROM vwEmployeeLeaveUsedItemApproved U WHERE U.EmployeeID = #R.EmployeeID AND (U.[Extended Type Mask] & #R.TypeID) != 0 AND U.[Day past 1900] BETWEEN (#R.D - 729) AND #R.D
), 0)

-- Updates #U based on #R
UPDATE #U SET Available = (
	SELECT MIN(Available) FROM #R WHERE #R.EmployeeID = #U.EmployeeID AND #R.TypeID = #U.TypeID
), Accumulated = (
	SELECT Available FROM #R WHERE #R.EmployeeID = #U.EmployeeID AND #R.D = @day AND #R.TypeID = #U.TypeID
)
WHERE Rolling != 0






DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1

-- Return results
SELECT
#U.EmployeeID,
--#U.TypeID,
Employee = P.[List As],
T.Type,
Accumulated = #U.Accumulated / 3600.0,
Available = #U.Available / 3600.0
FROM #U
INNER JOIN vwPersonListAs P ON #U.EmployeeID = P.PersonID
INNER JOIN LeaveType T ON #U.TypeID = T.TypeID AND T.TypeID IN
(
	SELECT DISTINCT TypeID FROM #U WHERE Available != 0
)
ORDER BY P.[List As], #U.EmployeeID, T.[Order], T.TypeID
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
		SELECT DISTINCT I.LeaveID FROM vwEmployeeLeaveUsedItem I WHERE I.[Day past 1900] BETWEEN @start AND @stop AND
		(@type_or_mask = 0x7FFFFFFF OR (I.[Extended Type Mask] & @type_or_mask) <> 0) AND I.Status = 2
	))
	+
	(SELECT COUNT(*) FROM EmployeeLeaveEarned E WHERE E.EmployeeID = #E.EmployeeID AND (E.[Day past 1900] BETWEEN @start AND @stop) AND (@type_or_mask = 0x7FFFFFFF OR (E.TypeID & @type_or_mask) <> 0) AND E.Seconds < 0)
,
[Lost Days] = ISNULL((
	SELECT SUM(U.Seconds /  CAST(S.[Seconds per Day] AS numeric(18,4))) FROM vwEmployeeLeaveUsedItemApproved U
	INNER JOIN Employee E ON U.EmployeeID = E.EmployeeID AND U.[Day past 1900] BETWEEN @start AND @stop AND E.EmployeeID = #E.EmployeeID AND E.[Terminated Day past 1900] IS NULL AND (U.[Extended Type Mask] & @type_or_mask) <> 0
	INNER JOIN Shift S ON E.ShiftID = S.ShiftID
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
	SELECT SUM(dbo.BoundInt(0, DATEDIFF(d, E.[Seniority Begins Day past 1900], GETDATE()) , 365) * S.[Seconds per day] / 3600 * CAST(S.[Days On] AS numeric(18,4)) / CAST(S.[Days On] + S.[Days Off] AS numeric(18,4)))
	FROM Shift S INNER JOIN #E ON #E.ShiftID = S.ShiftID AND #E.DepartmentID = #D.DepartmentID
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

EXEC spPermissionGetOnPeopleForCurrentUser2 @batch_id, 10003
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
ALTER PROC dbo.spLeaveAnalysisByManager
	@type_or_mask int,
	@manager_id int,
	@ongoing bit,
	@sort tinyint,
	@authorized bit OUT
AS
SET NOCOUNT ON

DECLARE @start int, @stop int, @batch_id int, @today smalldatetime, @null_id int

SELECT @today = GETDATE()
SELECT @stop = DATEDIFF(d, 0, @today)
SELECT @start = DATEDIFF(d, 0, DATEADD(yy, -1, @today))
SELECT @batch_id = RAND() * 2147483647
SELECT @null_id = ISNULL(MIN(EmployeeID), 0) - 1 FROM Employee

CREATE TABLE #E(EmployeeID int, ManagerID int, ShiftID int, Incidents int, [Lost Days] numeric(18,4), B numeric(18,4))

INSERT #E
SELECT E.EmployeeID, ISNULL(E.ManagerID, @null_id), E.ShiftID, 0, 0, 0
FROM Employee E WHERE [Terminated Day past 1900] IS NULL OR (@ongoing IS NULL OR E.[Ongoing Condition] = @ongoing)

UPDATE #E SET Incidents = 
	(SELECT COUNT(*) FROM EmployeeLeaveUsed U
	INNER JOIN Employee E ON U.EmployeeID = E.EmployeeID AND E.EmployeeID = #E.EmployeeID AND U.Status = 2 AND U.LeaveID IN
	(
		SELECT DISTINCT I.LeaveID FROM vwEmployeeLeaveUsedItem I WHERE I.[Day past 1900] BETWEEN @start AND @stop AND
		(@type_or_mask = 0x7FFFFFFF OR (I.[Extended Type Mask] & @type_or_mask) <> 0) AND I.Status = 2
	))
	+
	(SELECT COUNT(*) FROM EmployeeLeaveEarned E WHERE E.EmployeeID = #E.EmployeeID AND (E.[Day past 1900] BETWEEN @start AND @stop) AND (@type_or_mask = 0x7FFFFFFF OR (E.TypeID & @type_or_mask) <> 0) AND E.Seconds < 0)

,
[Lost Days] = ISNULL((
	SELECT SUM(U.Seconds /  CAST(S.[Seconds per Day] AS numeric(18,4))) FROM vwEmployeeLeaveUsedItemApproved U
	INNER JOIN Employee E ON U.EmployeeID = E.EmployeeID AND U.[Day past 1900] BETWEEN @start AND @stop AND E.EmployeeID = #E.EmployeeID AND E.[Terminated Day past 1900] IS NULL AND (U.[Extended Type Mask] & @type_or_mask) <> 0
	INNER JOIN Shift S ON E.ShiftID = S.ShiftID
), 0)

UPDATE #E SET B = Incidents * Incidents * [Lost Days]


CREATE TABLE #M (ManagerID int, Incidents numeric(18,4), [Lost Hours] numeric(18,4), People int, [Working Hours] numeric(18,4))

INSERT #M
SELECT EmployeeID, 0, 0, 0, 0 FROM Employee
UNION
SELECT @null_id, 0, 0, 0, 0


UPDATE #M SET Incidents = 
	(SELECT COUNT(*) FROM EmployeeLeaveUsed U
	INNER JOIN #E ON U.EmployeeID = #E.EmployeeID AND 
	#E.ManagerID = #M.ManagerID AND 
	dbo.DoRaysIntersect(U.[Start Day past 1900], U.[Stop Day past 1900], @start, @stop) = 1 AND 
	U.Status = 2 AND U.LeaveID IN
	(
		SELECT DISTINCT I.LeaveID FROM vwEmployeeLeaveUsedItem I WHERE I.[Day past 1900] BETWEEN @start AND @stop AND
		(@type_or_mask = 0x7FFFFFFF OR (I.[Extended Type Mask] & @type_or_mask) <> 0) AND I.Status = 2
	))
	+
	(SELECT COUNT(*) FROM EmployeeLeaveEarned E
	INNER JOIN #E ON E.EmployeeID = #E.EmployeeID AND
	#E.ManagerID = #M.ManagerID AND E.[Day past 1900] BETWEEN @start AND @STOP)
, [Lost Hours] = ISNULL((
	SELECT SUM(U.Seconds) / 3600.0 FROM vwEmployeeLeaveUsedItemApproved U
	INNER JOIN #E ON U.EmployeeID = #E.EmployeeID AND U.[Day past 1900] BETWEEN @start AND @stop AND #E.ManagerID = #M.ManagerID AND (U.[Extended Type Mask] & @type_or_mask) <> 0
), 0),
People = ISNULL((
	SELECT COUNT(*) FROM #E WHERE #E.ManagerID = #M.ManagerID
), 0),
[Working Hours] = ISNULL((
	SELECT SUM(dbo.BoundInt(0, DATEDIFF(d, E.[Seniority Begins Day past 1900], GETDATE()) , 365) * CAST(S.[Days On] AS numeric(18,4)) / CAST(S.[Days On] + S.[Days Off] AS numeric(18,4)) * S.[Seconds per day]  )
	FROM Shift S INNER JOIN #E ON #E.ShiftID = S.ShiftID AND #E.ManagerID = #M.ManagerID
	INNER JOIN Employee E ON #E.EmployeeID = E.EmployeeID
), 0)



	
SELECT
[Order] = CASE WHEN M.PersonID IS NULL THEN -1 ELSE 0 END,
#M.ManagerID,
Manager = ISNULL(M.[List As], 'No Manager'),
[Percent Working Time Lost] = CAST(CASE WHEN [Working Hours]= 0 THEN 0 ELSE 100 * #M.[Lost Hours] / #M.[Working Hours] END AS numeric(18,4)),
[Lost Hours per Week] = CAST(#M.[Lost Hours] / 52 AS numeric(18,4)),
[Avg Hours per Incident] = CAST(CASE WHEN #M.Incidents = 0 THEN 0 ELSE #M.[Lost Hours] / #M.Incidents END AS numeric(18,4)),
[Avg Hours per Person] = CAST(CASE WHEN #M.People = 0 THEN 0 ELSE #M.[Lost Hours] / #M.People END AS numeric(18,4)),
#M.[Incidents],
[Incidents per Person] = CAST(CASE WHEN #M.People = 0 THEN 0 ELSE #M.Incidents / #M.People END AS numeric(18,4)),
[Max Bradford Factor] = ISNULL((
	SELECT MAX(#E.B) FROM #E WHERE #E.ManagerID = #M.ManagerID
), 0)
INTO #R
FROM #M
LEFT JOIN vwPersonListAs M ON #M.ManagerID = M.PersonID

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
FROM #M

-- Weeds out managers that the user does not have permisison to see and managers that have 0 incidents
INSERT TempX(BatchID, [ID])
SELECT @batch_id, EmployeeID FROM Employee WHERE [Terminated Day past 1900] IS NULL AND (@manager_id IS NULL OR ManagerID = @manager_id)

EXEC spPermissionGetOnPeopleForCurrentUser2 @batch_id, 10003
DELETE TempX WHERE BatchID = @batch_id AND (X & 1) = 0
SELECT @authorized = CASE WHEN @@ROWCOUNT = 0 THEN 1 ELSE 0 END

SELECT Manager,
[Percent Working Time Lost],
[Lost Hours per Week],
[Avg Hours per Incident],
[Avg Hours per Person],
Incidents,
[Incidents per Person],
[Max Bradford Factor]
FROM #R
WHERE [Order] = 1 OR (Incidents != 0 AND (@manager_id IS NULL OR ManagerID = @manager_id) AND EXISTS(
	SELECT * FROM Employee E
	INNER JOIN TempX X ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID AND E.ManagerID = #R.ManagerID
))
ORDER BY [Order], CASE WHEN @sort IN (1, 2, 3) THEN '' ELSE Manager END,
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

EXEC spPermissionGetOnPeopleForCurrentUser2 @batch_id, 10003

DELETE TempX WHERE (X & 1) = 0 OR [ID] NOT IN (
	SELECT DISTINCT I.EmployeeID FROM vwEmployeeLeaveUsedItemApproved I WHERE I.[Day past 1900] BETWEEN @start_day AND @stop_day
)

SELECT EmployeeID = P.PersonID, Employee = P.[List As],
Absent = (SELECT COUNT(*) FROM vwEmployeeLeaveUsedItemApproved X	
	WHERE X.EmployeeID = P.PersonID AND X.[Day past 1900] BETWEEN @start_day AND @stop_day)
INTO #U
FROM vwPersonListAs P
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
-- Returns a list of timecard entries for use in reports
-- Includes paid leave if @include_paid_leave = 1
ALTER PROC dbo.spEmployeeTimeList2
	@employee_id int,
	@start_day int,
	@stop_day int,
	@include_paid_leave bit
AS
DECLARE @authorized bit

SET NOCOUNT ON

EXEC spPermissionInsureForCurrentUserOnPerson @employee_id, 262144, 1, @authorized out

IF @authorized = 1
BEGIN
	CREATE TABLE #ET
	(
		TempItemID int IDENTITY(1,1),
		Leave bit,
		[Day past 1900] int,
		[In] datetime,
		[Out] datetime,
		Seconds int,
		[Month Start] datetime,
		[Week Start] datetime,
		[Payroll Start] datetime,
		[Payroll Stop] datetime
	)


	INSERT #ET(Leave, [Day past 1900], [In], [Out], Seconds, [Month Start], [Week Start])

	-- In Day = Out Day
	SELECT Leave = CAST(0 AS bit), [Day past 1900] = ET.[In Day past 1900], ET.[In], ET.[Out], Seconds = DATEDIFF(s, ET.[In], ET.[Out]),
	[Month Start] = dbo.GetDateFromMDY(MONTH([In]), 1, YEAR([In])),
	[Week Start] = DATEADD(dd, 1 - DATEPART(dw, [In Day past 1900]), [In Day past 1900])
	FROM vwEmployeeTime ET WHERE ET.EmployeeID = @employee_id AND [In Day past 1900] = [Out Day past 1900] AND [Out] IS NOT NULL AND [In Day past 1900] BETWEEN @start_day AND @stop_day

	UNION

	-- In Day <> Out Day : In to midnight
	SELECT 0, [Day past 1900] = ET.[In Day past 1900], ET.[In], [Out] = DATEADD(ms, -2, ET.[Out Day past 1900]), Seconds = DATEDIFF(s, ET.[In], ET.[Out Day past 1900]),
	[Month Start] = dbo.GetDateFromMDY(MONTH([In]), 1, YEAR([In])),
	[Week Start] = DATEADD(dd, 1 - DATEPART(dw, [In Day past 1900]), [In Day past 1900])
	FROM vwEmployeeTime ET WHERE ET.EmployeeID = @employee_id AND [In Day past 1900] != [Out Day past 1900] AND [Out] IS NOT NULL AND [In Day past 1900] BETWEEN @start_day AND @stop_day

	UNION

	-- In Day <> Out Day : midnight to out
	SELECT 0, [Day past 1900] = ET.[Out Day past 1900], [In] = ET.[Out Day past 1900], [Out], Seconds = DATEDIFF(s, ET.[Out Day past 1900], [Out]),
	[Month Start] = dbo.GetDateFromMDY(MONTH([Out]), 1, YEAR([Out])),
	[Week Start] = DATEADD(dd, 1 - DATEPART(dw, [Out Day past 1900]), [Out Day past 1900])
	FROM vwEmployeeTime ET WHERE ET.EmployeeID = @employee_id AND [In Day past 1900] != [Out Day past 1900] AND [Out] IS NOT NULL AND [Out Day past 1900] BETWEEN @start_day AND @stop_day

	UNION

	-- Paid Leave
	SELECT 1, I.[Day past 1900], I.[Day past 1900], DATEADD(s, I.[Seconds], I.[Day past 1900]), I.Seconds,
	[Month Start] = dbo.GetDateFromMDY(MONTH(I.[Day past 1900]), 1, YEAR(I.[Day past 1900])),
	[Week Start] = DATEADD(dd, 1 - DATEPART(dw, I.[Day past 1900]), I.[Day past 1900])
	FROM vwEmployeeLeaveUsedItemApproved I
	INNER JOIN LeaveType T ON @include_paid_leave = 1 AND I.EmployeeID = @employee_id AND I.[Day Past 1900] BETWEEN @start_day AND @stop_day AND I.TypeID = T.TypeID AND T.Paid = 1

	ORDER BY [In]


	CREATE TABLE #T(StartDate datetime, StopDate datetime)
	DECLARE @dt datetime
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



	-- Black magic takes care of rounding
	DECLARE @rounding decimal
	SELECT @rounding = [Timecard Rounding] FROM Constant

	SELECT [Day past 1900], Total = SUM(Seconds), Adjustment = NULL, FirstTempItemID = NULL
	INTO #Rounding
	FROM #ET GROUP BY [Day past 1900]

	UPDATE #Rounding SET Adjustment = Total - ROUND(Total / @rounding, 0) * @rounding

	UPDATE #Rounding SET FirstTempItemID = (
		SELECT TOP 1 TempItemID FROM #ET WHERE #ET.[Day past 1900] = R.[Day past 1900] ORDER BY #ET.[In]
	) 
	FROM #Rounding R WHERE R.Adjustment != 0

	UPDATE #ET SET Seconds = Seconds - Adjustment
	FROM #ET INNER JOIN #Rounding R ON R.FirstTempItemID = #ET.TempItemID

	
	SELECT *, Hrs = Seconds / 3600.00 FROM #ET ORDER BY [In]
END
GO

ALTER VIEW vwLeaveLimit
AS
SELECT L.*, T.Type, [Description] = CASE WHEN L.[Max Seconds] IS NULL THEN 'Unlimited' ELSE
	CAST(CAST(L.[Max Seconds] / 3600 AS numeric(9,2)) AS varchar(100)) + ' Hrs' + CASE L.PeriodID
		WHEN 1 THEN ' Applied Every ' + 
			DATENAME(m, CONVERT(DATETIME,'00'+
				(CASE WHEN L.[Month]  < 10 THEN '0' ELSE '' END) + CAST(L.[Month] AS varchar(100))
			+'01',12)) + ' ' + CAST(L.[Day] AS varchar(100))
		WHEN 2 THEN ' Applied on Each Seniority Anniversary'
		WHEN 3 THEN ' Applied on the Eve of Each Seniority Anniversary'
		ELSE ''
	END
END
FROM LeaveLimit L
INNER JOIN LeaveType T ON L.TypeID = T.TypeID
GO
IF OBJECT_ID('dbo.spEmployeeTimeSelectLast') IS NOT NULL DROP PROC dbo.spEmployeeTimeSelectLast
GO
CREATE PROCEDURE dbo.spEmployeeTimeSelectLast
	@employee_id int
AS
DECLARE @authorized bit

SET NOCOUNT ON

EXEC spPermissionInsureForCurrentUserOnPerson @employee_id, 262144, 1, @authorized out

IF @authorized = 1 
SELECT TOP 1 E.*, [Employee] = V.[List As] FROM EmployeeTime E
INNER JOIN vwPersonListAs V ON E.EmployeeID = V.PersonID AND E.EmployeeID = @employee_id
ORDER BY E.[In] DESC
GO
GRANT EXEC ON dbo.spEmployeeTimeSelectLast TO public
GO
ALTER PROC dbo.spEmployeeLeaveUsedList
	@batch_id int,
	@start_day int,
	@stop_day int,
	@delete_batch bit = 1
AS
SET NOCOUNT ON

-- Requires read permission on Employee Leave and Schedules
EXEC spPermissionGetOnPeopleForCurrentUser2 @batch_id, 10002
DELETE TempX WHERE BatchID = @batch_id AND X & 1 = 0

SELECT DISTINCT L.EmployeeID, Person = P.[Full Name], P.Initials, Covering = CAST('' AS varchar(400)), [Type Mask] = 0, [Temp Type Mask] = NULL,
[Month] = MONTH(L.[Day past 1900]), [Day] = DAY(L.[Day past 1900]), [Year] = YEAR(L.[Day past 1900]), L.[Day past 1900], [Date] = dbo.GetDateFromDaysPast1900(L.[Day past 1900])
INTO #L
FROM vwEmployeeLeaveUsedItemApproved L
INNER JOIN TempX X ON L.EmployeeID = X.[ID] AND L.[Day past 1900] BETWEEN @start_day AND @stop_day
INNER JOIN vwPersonCalculated P ON L.EmployeeID = P.PersonID

ORDER BY L.[Day past 1900], P.[Full Name]

UPDATE #L SET Covering = ISNULL((
	SELECT TOP 1 C.Initials FROM EmployeeLeaveUsed U
	INNER JOIN EmployeeLeaveUsedItem I ON U.EmployeeID = #L.EmployeeID AND U.LeaveID = I.LeaveID AND I.[Day past 1900] = #L.[Day past 1900] AND U.Status = 2
	INNER JOIN vwPersonCalculated C ON U.CoveringEmployeeID = C.PersonID
), '')

DECLARE @rows int
SET @rows = 1
WHILE @rows > 0
BEGIN
	UPDATE #L SET [Temp Type Mask] = [Type Mask], [Type Mask] = [Type Mask] | ISNULL((
		SELECT TOP 1 I.[Extended Type Mask] FROM vwEmployeeLeaveUsedItemApproved I 
		WHERE I.EmployeeID = #L.EmployeeID AND I.[Day past 1900] = #L.[Day past 1900] AND
		(I.[Extended Type Mask] & #L.[Type Mask]) != I.[Extended Type Mask]
	), 0) WHERE [Temp Type Mask] IS NULL OR [Temp Type Mask] != [Type Mask]
	SET @rows = @@ROWCOUNT
END


SELECT EmployeeID, Person, Initials, Covering, [Type Mask],
[Month], [Day], [Year], [Day past 1900], [Date]
FROM #L

IF @delete_batch = 1 DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1
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
IF OBJECT_ID('dbo.spEmployeeBatchSubordinates') IS NOT NULL DROP PROC dbo.spEmployeeBatchSubordinates
GO
CREATE PROC dbo.spEmployeeBatchSubordinates
	@batch_id int,
	@include_user bit,
	@include_coworkers bit
AS
DECLARE @superior_id int

SET NOCOUNT ON

SELECT @superior_id = EmployeeID FROM Employee WHERE SID = SUSER_SID()

IF @@ROWCOUNT = 0
BEGIN
	DECLARE @error varchar(400)
	SELECT @error = 'The system could not identify your subordinates because your logon could not be matched to an employee record. Ask your administrator to open your employee record and enter your logon in the ''Security Account'' field.'

	RAISERROR (@error, 16, 1)
	RETURN
END

INSERT TempX(BatchID, [ID])
SELECT @batch_id, EmployeeID FROM EmployeeSuperior WHERE SuperiorID = @superior_id

IF @include_coworkers = 1
BEGIN
	DECLARE @manager_id int
	SELECT @manager_id = ManagerID FROM Employee WHERE EmployeeID = @superior_id
	
	IF @manager_id IS NULL
	INSERT TempX(BatchID, [ID])
	SELECT @batch_id, EmployeeID FROM Employee WHERE ManagerID IS NULL

	ELSE
	INSERT TempX(BatchID, [ID])
	SELECT @batch_id, EmployeeID FROM Employee WHERE ManagerID = @manager_id
END
ELSE IF @include_user = 1
INSERT TempX(BatchID, [ID])
SELECT @batch_id, @superior_id
GO
GRANT EXEC ON dbo.spEmployeeBatchSubordinates TO public
GRANT EXEC ON dbo.spEmployeeBatchSubordinates TO public
GRANT EXEC ON dbo.spDenialReasonList TO public
GRANT EXEC ON dbo.spDenialReasonSelect TO public
GRANT EXEC ON dbo.spStandardTaskList TO public
GO
-- Summarizes timecard information for one payroll period
ALTER PROC dbo.spEmployeeTimeSummarizeBasis
	@batch_id int,
	@start smalldatetime,
	@stop smalldatetime,
	@exclude_salaried bit
AS
DECLARE @rounding decimal

SELECT @rounding = [Timecard Rounding] FROM Constant

IF @exclude_salaried = 1 DELETE TempX
FROM TempX X
INNER JOIN Employee E ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID AND E.Salaried = 1

-- Table that will hold final report
CREATE TABLE #Report(
	EmployeeID int NOT NULL,
	[OT Basis] int,
	Holiday int default(0),
	OT int default(0),
	Regular int default(0),
	[Paid Leave] int default(0),
	[Unpaid Leave] int default(0),
	Total int default(0),
	Weekend int default(0),
	Scratch int default(0),
	[Holiday Hrs] numeric(9,4) default(0),
	[OT Hrs] numeric(9,4) default(0),
	[Total Hrs] numeric(9,4) default(0),
	[Paid Leave Hrs] numeric(9,4) default(0),
	[Unpaid Leave Hrs] numeric(9,4) default(0),
	[Weekend Hrs] numeric(9,4) default(0),
	[Regular Hrs] numeric(9,4) default(0),
	[Regular Rate] money
)
ALTER TABLE #Report WITH NOCHECK ADD 
CONSTRAINT [PK_TempTableR] PRIMARY KEY NONCLUSTERED 
(
	EmployeeID
) WITH  FILLFACTOR = 90 ON [PRIMARY]

-- Files final report table with EmployeeIDs
INSERT #Report(EmployeeID, [OT Basis])
SELECT E.EmployeeID, E.[OT Basis] FROM Employee E
INNER JOIN TempX X ON E.EmployeeID = X.[ID] AND X.BatchID = @batch_id

-- Table that holds list of holidays
CREATE TABLE #Holiday(D int NOT NULL,)
ALTER TABLE #Holiday WITH NOCHECK ADD 
CONSTRAINT [PK_TempTableH] PRIMARY KEY NONCLUSTERED 
(
	D
)

-- Lists nonrecurring holidays into temp table
INSERT #Holiday
SELECT DISTINCT DATEDIFF(d, 0, dbo.GetDateFromMDY([Month], [Day], [Year]))
FROM Holiday WHERE [Year] IS NOT NULL AND ([Year] BETWEEN YEAR(@start) AND YEAR(@stop))

-- Inserts all recurring holidays for start year through stop year into temporary table
DECLARE @year int
SELECT @year = YEAR(@start)

WHILE @year <= YEAR(@stop)
BEGIN
	INSERT #Holiday
	SELECT DATEDIFF(d, 0, dbo.GetDateFromMDY([Month], [Day], @year))
	FROM Holiday WHERE [Year] IS NULL AND DATEDIFF(d, 0, dbo.GetDateFromMDY([Month], [Day], @year)) NOT IN
	(
		SELECT D FROM #Holiday
	)

	SELECT @year = @year + 1
END

-- Removes temp holidays outside of reporting period
DELETE #Holiday WHERE D < DATEDIFF(d, 0, @start) OR D > DATEDIFF(d, 0, @stop)



-- Break timecards so that in/out always fall on same day.
-- For each day, holds OT and whether day is a weekend or holiday
CREATE TABLE #Timecard(ItemID int IDENTITY(1,1) NOT NULL, EmployeeID int NOT NULL, D int, Weekend bit, Wk int, Seconds int, [OT Basis] int, [Previous Total] int default(0), [OT Seconds] int default(0), [Paid Leave Seconds] int default(0), [Unpaid Leave Seconds] int default(0), Holiday bit default(0))
ALTER TABLE #Timecard WITH NOCHECK ADD 
CONSTRAINT [PK_TempTableT] PRIMARY KEY CLUSTERED 
(
	ItemID
) WITH  FILLFACTOR = 90 ON [PRIMARY]
CREATE  UNIQUE  INDEX [IX_TempTableT] ON #Timecard([EmployeeID], D) WITH  FILLFACTOR = 90 ON [PRIMARY]
CREATE  INDEX [IX_TempTableT2] ON #Timecard([EmployeeID]) WITH  FILLFACTOR = 90 ON [PRIMARY]


-- @d: loops from @start to @stop
-- @n: @d 11:59:59
-- @dp1900: @d - 1900
-- @weekend: is @d a @weekend?
-- @i: @d - @start, calcs week @wk for OT
DECLARE @d smalldatetime, @n smalldatetime, @dp1900 int
DECLARE @wkend bit, @wk int, @i int
SELECT @d = @start, @i = 0

WHILE @d <= @stop
BEGIN
	SELECT @n = DATEADD(s, -1, DATEADD(d, 1, @d)), @dp1900 = DATEDIFF(d, 0, @d)
	SELECT @wkend = CASE WHEN DATEPART(dw, @d) IN (1,7) THEN 1 ELSE 0 END
	SELECT @wk = @i / 7

	INSERT #Timecard(EmployeeID, D, Weekend, Wk, Seconds, [Previous Total], [OT Basis])
	SELECT #Report.EmployeeID, @dp1900, @wkend, @wk, 0, #Report.Scratch , #Report.[OT Basis]
	FROM #Report

	-- Update ([Out] - [In])
	UPDATE #Timecard SET Seconds = ISNULL((
		SELECT SUM(DATEDIFF(s, ET.[In], ET.[Out]))
		FROM vwEmployeeTime ET 
		WHERE ET.EmployeeID = #Timecard.EmployeeID AND ET.[In Day past 1900] = ET.[Out Day past 1900] AND @dp1900 = ET.[In Day past 1900]
	), 0) WHERE #Timecard.D = @dp1900

	-- Update (end of day - [In])
	UPDATE #Timecard SET Seconds = Seconds + ISNULL((
		SELECT SUM(DATEDIFF(s, ET.[In], @n))
		FROM vwEmployeeTime ET 
		WHERE ET.EmployeeID = #Timecard.EmployeeID AND ET.[In Day past 1900] <> ET.[Out Day past 1900] AND @dp1900 = ET.[In Day past 1900]
	), 0) WHERE #Timecard.D = @dp1900

	-- Update ([Out] - start of day)
	UPDATE #Timecard SET Seconds = Seconds + ISNULL((
		SELECT SUM(DATEDIFF(s, @d, ET.[Out]))
		FROM vwEmployeeTime ET 
		WHERE ET.EmployeeID = #Timecard.EmployeeID AND ET.[In Day past 1900] <> ET.[Out Day past 1900] AND @dp1900 = ET.[Out Day past 1900]
	), 0) WHERE #Timecard.D = @dp1900

	-- Add in paid leave
	UPDATE #Timecard SET [Paid Leave Seconds] = ISNULL((
		SELECT SUM(I.Seconds)
		FROM vwEmployeeLeaveUsedItemApproved I
		INNER JOIN LeaveType T ON I.[Day past 1900] = @dp1900 AND I.EmployeeID = #Timecard.EmployeeID AND I.TypeID = T.TypeID AND T.Paid = 1
	), 0),
	[Unpaid Leave Seconds] = ISNULL((
		SELECT SUM(I.Seconds)
		FROM vwEmployeeLeaveUsedItemApproved I
		INNER JOIN LeaveType T ON I.[Day past 1900] = @dp1900 AND I.EmployeeID = #Timecard.EmployeeID AND I.TypeID = T.TypeID AND T.Paid = 0
	), 0) 
	WHERE #Timecard.D = @dp1900

	UPDATE #Timecard SET Seconds = Seconds + [Paid Leave Seconds] WHERE #Timecard.D = @dp1900

	-- @rounding is decimal
	UPDATE #Timecard SET Seconds = ROUND(Seconds / @rounding, 0) * @rounding WHERE D = @dp1900
	

	-- Resets weekly Previous Total
	IF @i % 7 = 6 UPDATE #Report SET Scratch = 0
	-- Updates weekly Previous Total for each employee
	ELSE 
	BEGIN
		UPDATE #Report SET Scratch = #Report.Scratch + #Timecard.Seconds FROM #Report
		INNER JOIN #Timecard ON #Timecard.EmployeeID = #Report.EmployeeID AND #Timecard.D = @dp1900
	END

	SELECT @d = DATEADD(d, 1, @d)
	SELECT @i = @i + 1
END





-- Calcs OT Seconds each day
-- Calcs days where all time was OT
UPDATE #Timecard SET [OT Seconds] = Seconds WHERE [OT Basis] = 1 AND [Previous Total] > 144000
-- Calcs days where some time was OT
UPDATE #Timecard SET [OT Seconds] = [Previous Total] + Seconds - 144000 WHERE [OT Basis] = 1 AND [Previous Total] <= 144000 AND ([Previous Total] + Seconds) > 144000


-- Calc OT (daily basis)
UPDATE #Timecard SET [OT Seconds] = Seconds - 28800 WHERE [OT Basis] = 2 AND Seconds > 28800


-- Calcs holidays
UPDATE #Timecard SET Holiday = 1 FROM #Timecard 
INNER JOIN #Holiday ON #Timecard.D = #Holiday.D






-- Takes time that falls into multiple categories and puts it in the highest paying category
-- For example, if an employee works OT on a holiday, time is either classied as OT or holiday depending on which pays more

-- HOL/WKEND >> HOL
UPDATE #Timecard SET [Weekend] = 0 FROM #Timecard
INNER JOIN Employee E ON 
#Timecard.Weekend = 1 AND #Timecard.Holiday = 1 AND
#Timecard.EmployeeID = E.EmployeeID AND 
E.[Weekend Pay Multiplier] <= E.[Holiday Pay Multiplier]

-- HOL/WKEND >> WKEND
UPDATE #Timecard SET [Holiday] = 0 FROM #Timecard
INNER JOIN Employee E ON 
#Timecard.Weekend = 1 AND #Timecard.Holiday = 1 AND
#Timecard.EmployeeID = E.EmployeeID AND 
E.[Weekend Pay Multiplier] > E.[Holiday Pay Multiplier]

-- OT/HOL >> OT
UPDATE #Timecard SET [Holiday] = 0 FROM #Timecard
INNER JOIN Employee E ON 
#Timecard.[OT Seconds] > 0 AND #Timecard.Holiday = 1 AND
#Timecard.EmployeeID = E.EmployeeID AND 
E.[Holiday Pay Multiplier] <= E.[OT Pay Multiplier]

-- OT/HOL >> HOL
UPDATE #Timecard SET [OT Seconds] = 0 FROM #Timecard
INNER JOIN Employee E ON 
#Timecard.[OT Seconds] > 0 AND #Timecard.Holiday = 1 AND
#Timecard.EmployeeID = E.EmployeeID AND 
E.[Holiday Pay Multiplier] > E.[OT Pay Multiplier]

-- OT/WKEND >> OT
UPDATE #Timecard SET [Weekend] = 0 FROM #Timecard
INNER JOIN Employee E ON 
#Timecard.[OT Seconds] > 0 AND #Timecard.Weekend = 1 AND
#Timecard.EmployeeID = E.EmployeeID AND 
E.[Weekend Pay Multiplier] <= E.[OT Pay Multiplier]

-- OT/WKEND >> WKEND
UPDATE #Timecard SET [OT Seconds] = 0 FROM #Timecard
INNER JOIN Employee E ON 
#Timecard.[OT Seconds] > 0 AND #Timecard.Weekend = 1 AND
#Timecard.EmployeeID = E.EmployeeID AND 
E.[Weekend Pay Multiplier] > E.[OT Pay Multiplier]










-- Calc total for each employee
UPDATE #Report SET Total = ISNULL((
	SELECT SUM(#Timecard.Seconds)
	FROM #Timecard WHERE #Report.EmployeeID = #Timecard.EmployeeID
), 0), Holiday = ISNULL((
	SELECT SUM(#Timecard.Seconds)
	FROM #Timecard WHERE #Report.EmployeeID = #Timecard.EmployeeID AND #Timecard.Holiday = 1
), 0), Weekend = ISNULL((
	SELECT SUM(#Timecard.Seconds)
	FROM #Timecard WHERE #Report.EmployeeID = #Timecard.EmployeeID AND #Timecard.Weekend = 1
), 0), OT = ISNULL((
	SELECT SUM(#Timecard.[OT Seconds])
	FROM #Timecard WHERE #Report.EmployeeID = #Timecard.EmployeeID
), 0), [Paid Leave] = ISNULL((
	SELECT SUM(#Timecard.[Paid Leave Seconds])
	FROM #Timecard WHERE #Report.EmployeeID = #Timecard.EmployeeID
), 0), [Unpaid Leave] = ISNULL((
	SELECT SUM(#Timecard.[Unpaid Leave Seconds])
	FROM #Timecard WHERE #Report.EmployeeID = #Timecard.EmployeeID
), 0)

UPDATE #Report SET Regular = Total - Holiday - Weekend - OT

-- Caveat: Regular Seconds include Paid Leave, Regular Hours does not
UPDATE #Report SET [Regular Hrs] = (Regular - [Paid Leave]) / 3600.0,
[Holiday Hrs] = Holiday / 3600.0,
[OT Hrs] = OT / 3600.0,
[Total Hrs] = Total / 3600.0,
[Paid Leave Hrs] = [Paid Leave] / 3600.0,
[Unpaid Leave Hrs] = [Unpaid Leave] / 3600.0


-- Look up rate for each employee
SELECT @dp1900 = DATEDIFF(d, 0, @start)
UPDATE #Report SET [Regular Rate] = ISNULL((
	SELECT TOP 1 [Base Pay] * (3600.0 / P.Seconds)
	FROM EmployeeCompensation C
	INNER JOIN Period P ON C.EmployeeID = #Report.EmployeeID AND C.PeriodID = P.PeriodID AND 
	(@dp1900 BETWEEN C.[Start Day past 1900] AND ISNULL(C.[Stop Day past 1900], 2147483647))
), 0)


-- Final
SELECT Employee = P.[List As], #Report.EmployeeID, E.[Employee Number], X.SSN, 
#Report.[Regular Hrs], #Report.[OT Hrs], #Report.[Holiday Hrs], #Report.[Weekend Hrs], #Report.[Total Hrs],
#Report.[Paid Leave Hrs], #Report.[Unpaid Leave Hrs],
[Regular Rate],
[OT Rate] = [Regular Rate] * [OT Pay Multiplier],
[Holiday Rate] = [Regular Rate] * [Holiday Pay Multiplier],
[Weekend Rate] = [Regular Rate] * [Weekend Pay Multiplier],
Pay = ([Regular Hrs] +
[Paid Leave Hrs] +
[Holiday Hrs] * [Holiday Pay Multiplier] +
[Weekend Hrs] * [Weekend Pay Multiplier] +
[OT Hrs] * [OT Pay Multiplier]) * [Regular Rate]
FROM #Report
INNER JOIN vwPerson P ON #Report.EmployeeID = P.PersonID
INNER JOIN PersonX X ON P.PersonID = X.PersonID
INNER JOIN Employee E ON X.PersonID = E.EmployeeID
ORDER BY Employee
GO
IF (SELECT [Server Version] FROM Constant) < 14
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
exec sp_cursoropen @P1 output, N'EXECUTE sp_rename N''dbo.Tmp_I9Status'', N''I9Status'', ''OBJECT''
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
ALTER PROC dbo.spPayGradeList2
	@pattern varchar(50),
	@pay_steps int OUT
AS
DECLARE @l int

SET NOCOUNT ON

SELECT @l = LEN(@pattern), @pattern = UPPER(@pattern)

SELECT @pay_steps = MAX(
	CASE WHEN [Pay Step Increase] = 0 THEN 0 ELSE CEILING(([Maximum Hourly Pay] - [Minimum Hourly Pay]) / [Pay Step Increase]) END
) FROM PayGrade WHERE @l = 0 OR (LEN([Pay Grade]) >= @l AND UPPER(SUBSTRING([Pay Grade], 1, @l)) = @pattern)

SELECT * FROM vwPayGrade WHERE @l = 0 OR (LEN([Pay Grade]) >= @l AND UPPER(SUBSTRING([Pay Grade], 1, @l)) = @pattern)
ORDER BY [Pay Grade]
GO
IF OBJECT_ID('dbo.spEmployeeTimeUpdateOut') IS NOT NULL DROP PROC dbo.spEmployeeTimeUpdateOut
GO
CREATE PROCEDURE dbo.spEmployeeTimeUpdateOut
	@out smalldatetime,
	@item_id int
AS
DECLARE @in smalldatetime
DECLARE @employee_id int
DECLARE @authorized bit

SET NOCOUNT ON

SELECT @employee_id = EmployeeID, @in = [In] FROM EmployeeTime WHERE ItemID = @item_id
EXEC spPermissionInsureForCurrentUserOnPerson @employee_id, 262144, 2, @authorized out

IF @authorized = 1
BEGIN
	IF DATEDIFF(hh, @in, @out) < 24 UPDATE EmployeeTime SET [Out] = @out WHERE ItemID = @item_id
	ELSE	
	BEGIN
		SET @in = DATEADD(mi, 1, @in)
		UPDATE EmployeeTime SET [Out] = @in WHERE ItemID = @item_id

		INSERT EmployeeTime(EmployeeID, [In])
		VALUES(@employee_id, @out)
	END
END
GO
GRANT EXEC ON dbo.spEmployeeTimeUpdateOut TO public
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
	SELECT TOP 1 @error = 50014 FROM EmployeeTime Et
	INNER JOIN [TempX] T ON T.BatchID = @batch_id AND T.[ID] = Et.EmployeeID AND Et.[Out] IS NULL
	INNER JOIN EmployeeTime Et2 ON Et.EmployeeID = Et2.EmployeeID AND Et.ItemID <> Et2.ItemID AND Et2.[In] >= Et.[In]


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
ALTER  PROC dbo.spEmployeeLeaveEarnMapFromPlan
	@employee_id int,
	@start_day int,
	@stop_day int,
	@period_id int,
	@type_id int,
	@seconds int
AS
DECLARE @note varchar(4000)
DECLARE @error_msg varchar(100)

SET NOCOUNT ON


SELECT @error_msg = 'Case does not switch PeriodID (' + CAST(@period_id AS varchar(50)) + ')'


IF @stop_day < @start_day OR @seconds = 0 RETURN

IF @seconds % 3600 = 0
	SELECT @note = @seconds / 3600
ELSE
	SELECT @note = CAST((@seconds / 3600.0) AS numeric(9,2))

SELECT @note = 'Earns ' + @note + ' hr'

IF @seconds != 3600 SELECT @note = @note + 's'

SELECT @note = @note + ' ' + G.[Period] FROM LeaveRatePeriod P
INNER JOIN Period G ON P.PeriodID = @period_id AND P.GroupID = G.PeriodID

DECLARE @wk0 datetime
SELECT @wk0 = CONVERT(datetime, '20031228', 112) -- Sunday dec 28 2003 is the reference day for biweekly calculations

DECLARE @dayOfWeek int, @wk int
--DECLARE @Seniority bit
--SELECT @Seniority = 0
--SELECT @Seniority = 1 FROM LeaveRatePeriod WHERE Period LIKE '%Seniority%' AND PeriodID = @period_id


DECLARE @seniority_begins_day int	
DECLARE @seniority_begins datetime

SELECT @seniority_begins_day = [Seniority Begins day past 1900] FROM Employee WHERE EmployeeID = @employee_id
SELECT @seniority_begins = dbo.GetDateFromDaysPast1900(@seniority_begins_day)


DECLARE @month int, @day int, @year int
DECLARE @start_date datetime, @stop_date datetime, @temp datetime
SELECT @start_date = dbo.GetDateFromDaysPast1900(@start_day), @stop_date = dbo.GetDateFromDaysPast1900(@stop_day)

-- Annual accrual (non anniversaries)
IF @period_id IN (22530, 24578, 26626, 28674, 40962, 43010, 45058, 47106)
BEGIN
	IF @period_id = 22530 SELECT @month = 1, @day = 1
	ELSE IF @period_id = 24578 SELECT @month = 12, @day = 31
	ELSE IF @period_id = 26626 SELECT @month = [Fiscal Year Start Month], @day = [Fiscal Year Start Day] FROM Constant
	ELSE IF @period_id = 28674 SELECT @month = [Fiscal Year Start Month], @day = [Fiscal Year Start Day] - 1 FROM Constant
	ELSE IF @period_id = 40962 SELECT @month = [Operational Year Start Month], @day = [Operational Year Start Day] FROM Constant
	ELSE IF @period_id = 43010 SELECT @month = [Administrative Year Start Month], @day = [Administrative Year Start Day] FROM Constant
	ELSE IF @period_id = 45058 SELECT @month = [Operational Year Start Month], @day = [Operational Year Start Day] - 1 FROM Constant
	ELSE IF @period_id = 47106 SELECT @month = [Administrative Year Start Month], @day = [Administrative Year Start Day] - 1 FROM Constant
	ELSE RAISERROR(16, 1, @error_msg)

	SELECT @temp = dbo.GetDateFromMDY(@month, @day, YEAR(@start_date))
	IF @temp < @start_date SET @temp = DATEADD(yy, 1, @temp)
	
	WHILE @temp <= @stop_date
	BEGIN
		INSERT EmployeeLeaveEarned(EmployeeID, TypeID, Seconds, [Day past 1900], Note, [Auto]) 
		VALUES (@employee_id, @type_id, @seconds, DATEDIFF(d, 0, @temp), @note, 1) -- Accrual = 1
		SELECT @temp = DATEADD(yy, 1, @temp)
	END
END

-- Seniority Anniversary I : If seniority starts 1/3/00 then credit 1/3/00, 1/3/01, 1/3/02 ..
-- Seniority Anniversary III : If seniority starts 1/3/00 then credit 1/3/01, 1/3/02 ..
-- Seniority Anniversary IV : If seniority starts 1/3/00 then credit 1/2/01, 1/2/02 ..
ELSE IF @period_id IN (30722, 34818, 36866)
BEGIN
	IF @period_id <> 30722 SELECT @seniority_begins = DATEADD(yy, 1, @seniority_begins)
	IF @period_id = 36866 SELECT @seniority_begins = DATEADD(d, -1, @seniority_begins)

	EXEC spEmployeeLeaveEarnMapMonth 0, 12, @seniority_begins, @start_date, @stop_date, @employee_id, @type_id, @seconds, @note 
END

-- Seniority Anniversary II : If seniority starts 1/3/00 then credit 1/3/00, 1/2/01, 1/2/02 ..
ELSE IF @period_id = 32770
BEGIN
	EXEC spEmployeeLeaveEarnMapMonth2 12, @seniority_begins, @start_date, @stop_date, @employee_id, @type_id, @seconds, @note
END

-- Semiannually I and II
ELSE IF @period_id IN (53252, 55300)
BEGIN
	IF @period_id = 53252 SELECT @temp = dbo.GetDateFromMDY(1, 1, YEAR(@start_date))
	ELSE SELECT @temp = dbo.GetDateFromMDY(6, 30, YEAR(@start_date))

	IF @temp < @start_date SELECT @temp = DATEADD(m, 6, @temp)
	IF MONTH(@temp) = 12 SELECT @temp = DATEADD(d, 1, @temp) -- takes 12/30 to 12/31

	IF @temp < @start_date SELECT @temp = DATEADD(m, 6, @temp) -- never happens for @period_id = 55300

	SELECT @start_date = @temp

	WHILE @start_date <= @stop_date
	BEGIN
		INSERT EmployeeLeaveEarned(EmployeeID, TypeID, Seconds, [Day past 1900], Note, [Auto]) 
		VALUES (@employee_id, @type_id, @seconds, DATEDIFF(d, 0, @start_date), @note, 1)

		SELECT @start_date = DATEADD(m, 6, @start_date) -- adds 6 months
		IF MONTH(@start_date) = 12 SELECT @start_date = DATEADD(d, 1, @start_date) -- takes 12/30 to 12/31
	END
END

-- Every 6 Months of Seniority I : If seniority starts 1/3/00 then credit 1/3/00, 7/3/00, 1/3/01 ..
-- Every 6 Months of Seniority III : If seniority starts 1/3/00 then credit 7/3/00, 1/3/01 ..
-- Every 6 Months of Seniority IV : If seniority starts 1/3/00 then credit 7/2/00, 1/2/01 ..
ELSE IF @period_id IN (57348, 61444, 63492)
BEGIN
	SELECT @month = CASE WHEN @period_id = 57348 THEN 0 ELSE 6 END
	IF @period_id = 63492 SELECT @seniority_begins = DATEADD(d, -1, @seniority_begins)

	EXEC spEmployeeLeaveEarnMapMonth @month, 6, @seniority_begins, @start_date, @stop_date, @employee_id, @type_id, @seconds, @note 
END

-- Every 6 Months of Seniority II : If seniority starts 1/3/00 then credit 1/3/00, 7/2/00, 1/2/01 ..
ELSE IF @period_id = 59396
BEGIN
	EXEC spEmployeeLeaveEarnMapMonth2 6, @seniority_begins, @start_date, @stop_date, @employee_id, @type_id, @seconds, @note
END


--Bimonthly I : 1,1, 3/1, 5/1, 7/1, 9/1, 11/1
--Bimonthly II : 2/28|29, 4/30,  6/30, 8/31, 10/31, 12/31
ELSE IF @period_id IN (90120, 92168)
BEGIN
	SELECT @temp = dbo.GetDateFromMDY(1, 1, YEAR(@start_date))
	IF @period_id = 92168 SELECT @temp = DATEADD(d, -1, @temp)

	SELECT @month = 0
	WHILE DATEADD(m, @month, @temp) < @start_date
	BEGIN
		SELECT @month = @month + 2
	END

	SELECT @start_date = DATEADD(m, @month, @temp)
	WHILE @start_date < @stop_date
	BEGIN
		INSERT EmployeeLeaveEarned(EmployeeID, TypeID, Seconds, [Day past 1900], Note, [Auto]) 
		VALUES (@employee_id, @type_id, @seconds, DATEDIFF(d, 0, @start_date), @note, 1)

		SELECT @month = @month + 2
		SELECT @start_date = DATEADD(m, @month, @temp)
	END
END

-- Every 2 Months of Seniority I : If seniority starts 1/3 then credit 1/3, 3/3, 5/3 ..
-- Every 2 Months of Seniority III : If seniority starts 1/3 then credit 3/3, 5/3 ..
-- Every 2 Months of Seniority IV : If seniority starts 1/3 then credit 3/2, 5/2 ..
ELSE IF @period_id IN (94216, 98312, 100360)
BEGIN
	SELECT @month = CASE WHEN @period_id = 57348 THEN 0 ELSE 2 END
	IF @period_id = 100360 SELECT @seniority_begins = DATEADD(d, -1, @seniority_begins)

	EXEC spEmployeeLeaveEarnMapMonth @month, 2, @seniority_begins, @start_date, @stop_date, @employee_id, @type_id, @seconds, @note 
END

--Every 2 Months of Seniority II : If seniority starts 1/3 then credit 1/3, 3/2, 5/2 ..
ELSE IF @period_id = 96264
BEGIN
	EXEC spEmployeeLeaveEarnMapMonth2 1, @seniority_begins, @start_date, @stop_date, @employee_id, @type_id, @seconds, @note
END

-- 126992 1st of each month
-- 129040 31st
-- 131088 28th
-- 141328 15th
-- 143376 16th
-- 145424 30th
ELSE IF @period_id IN (126992, 129040, 131088, 141328, 143376, 145424)
BEGIN
	SELECT @month = MONTH(@start_date), @year=YEAR(@start_date),
		@day = CASE WHEN @period_id = 126992 THEN 1
			WHEN @period_id = 129040 THEN 31
			WHEN @period_id = 131088 THEN 28
			WHEN @period_id = 141328 THEN 15
			WHEN @period_id = 143376 THEN 16
			WHEN @period_id = 145424 THEN 30
		END

	IF dbo.AddMonthsToDY(@month, @day, @year) < @start_date SET @month = @month + 1

	SELECT @start_date = dbo.AddMonthsToDY(@month, @day, @year)

	WHILE @start_date < @stop_date
	BEGIN
		INSERT EmployeeLeaveEarned(EmployeeID, TypeID, Seconds, [Day past 1900], Note, [Auto]) 
		VALUES (@employee_id, @type_id, @seconds, DATEDIFF(d, 0, @start_date), @note, 1)

		SELECT @month = @month + 1
		SELECT @start_date = dbo.AddMonthsToDY(@month, @day, @year)
	END
END

-- Every Month of Seniority I : If seniority starts 1/3 then credit 1/3, 2/3, 3/3 ..
-- Every Month of Seniority III : If seniority starts 1/3 then credit 2/3, 3/3 ..
-- Every Month of Seniority IV : If seniority starts 1/3 then credit 2/2, 3/2 ..
ELSE IF @period_id IN (133136, 137232, 139280)
BEGIN
	SELECT @month = CASE WHEN @period_id = 133136 THEN 0 ELSE 1 END
	IF @period_id = 139280 SELECT @seniority_begins = DATEADD(d, -1, @seniority_begins)

	EXEC spEmployeeLeaveEarnMapMonth @month, 1, @seniority_begins, @start_date, @stop_date, @employee_id, @type_id, @seconds, @note 

END

-- Every Month of Seniority II : If seniority starts 1/3 then credit 1/3, 2/2, 3/2 ..
ELSE IF @period_id = 135184
BEGIN
	EXEC spEmployeeLeaveEarnMapMonth2 1, @seniority_begins, @start_date, @stop_date, @employee_id, @type_id, @seconds, @note
END


-- 163872 1st 15th
-- 165920 1st 16th
-- 167968 14th 28th
-- 170016 15th 28th
-- 172064 15th 30th
-- 174112 15th 31st
ELSE IF @period_id IN (163872, 165920, 167968, 170016, 172064, 174112)
BEGIN
	DECLARE @d1 int, @d2 int, @dx int

	IF @period_id = 163872 SELECT @d1 = 1, @d2 = 15
	ELSE IF @period_id = 165920 SELECT @d1 = 1, @d2 = 16
	ELSE IF @period_id = 167968 SELECT @d1 = 14, @d2 = 28
	ELSE IF @period_id = 170016 SELECT @d1 = 15, @d2 = 28
	ELSE IF @period_id = 172064 SELECT @d1 = 15, @d2 = 30
	ELSE IF @period_id = 174112 SELECT @d1 = 15, @d2 = 31
	ELSE RAISERROR(16, 1, @error_msg)
	
	SELECT @temp = dbo.GetDateFromMDY(MONTH(@start_date) - 1, 1, YEAR(@start_date))

	WHILE @temp <= @stop_date
	BEGIN
		SELECT @month = MONTH(@temp), @year = YEAR(@temp)

		SELECT @dx = dbo.GetLastDayOfMonth(@month, @year)
		IF @d2 < @dx SET @dx = @d2

		SELECT @temp = dbo.GetDateFromMDY(@month, @d1, @year)
		IF @temp BETWEEN @start_date AND @stop_date 
		INSERT EmployeeLeaveEarned(EmployeeID, TypeID, Seconds, [Day past 1900], Note, [Auto]) 
		VALUES (@employee_id, @type_id, @seconds, DATEDIFF(d, 0, @temp), @note, 1)

		SELECT @temp = dbo.GetDateFromMDY(@month, @dx, @year)
		IF @temp BETWEEN @start_date AND @stop_date 
		INSERT EmployeeLeaveEarned(EmployeeID, TypeID, Seconds, [Day past 1900], Note, [Auto]) 
		VALUES (@employee_id, @type_id, @seconds, DATEDIFF(d, 0, @temp), @note, 1)

		SELECT @temp = dbo.GetDateFromMDY(@month + 1, 1, @year)
	END
	
END

-- Biweekly
ELSE IF @period_id IN (200768, 202816, 204864, 206912, 208960, 211008, 213056,
	215104, 217152, 219200, 221248, 223296, 225344, 227392)
BEGIN
	SELECT @dayOfWeek = CASE @period_id 
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
		
	SELECT @wk = DATEDIFF(wk, @wk0, @start_date) / 2
	SELECT @temp = DATEADD(wk, @wk * 2, @wk0)
	SELECT @temp = DATEADD(d, @dayOfWeek, @temp)

	IF @temp < @start_date SELECT @temp = DATEADD(wk, 2, @temp)
	
	WHILE @temp <= @stop_date
	BEGIN
		INSERT EmployeeLeaveEarned(EmployeeID, TypeID, Seconds, [Day past 1900], Note, [Auto]) 
		VALUES (@employee_id, @type_id, @seconds, DATEDIFF(d, 0, @temp), @note, 1)
		SELECT @temp = DATEADD(wk, 2, @temp)
	END	
END

-- Every 2 Weeks of Seniority I : If seniority starts 1/3 then credit 1/3, 1/17, 1/31 ..
-- Every 2 Weeks of Seniority III : If seniority starts 1/3 then credit 1/17, 1/31 ..
-- Every 2 Weeks of Seniority IV : If seniority starts 1/3 then credit 1/16, 1/30 ..
ELSE IF @period_id IN (229440, 233536, 235584)
BEGIN
	IF @period_id <> 229440 SELECT @seniority_begins = DATEADD(wk, 2, @seniority_begins)
	IF @period_id = 100360 SELECT @seniority_begins = DATEADD(d, -1, @seniority_begins)

	EXEC spEmployeeLeaveEarnMapWeek 2, @seniority_begins, @start_date, @stop_date, @employee_id, @type_id, @seconds, @note 
END

-- Every 2 Weeks of Seniority II : If seniority starts 1/3 then credit 1/3, 1/16, 1/30 ..
ELSE IF @period_id = 231488
BEGIN
	EXEC spEmployeeLeaveEarnMapWeek2 2, @seniority_begins, @start_date, @stop_date, @employee_id, @type_id, @seconds, @note 
END
ELSE IF @period_id IN (258176, 260224, 262272, 264320, 266368, 268416, 270464)
BEGIN
	SELECT @dayOfWeek = CASE @period_id 
		WHEN 258176 THEN 0
		WHEN 260224 THEN 1
		WHEN 262272 THEN 2
		WHEN 264320 THEN 3
		WHEN 266368 THEN 4
		WHEN 268416 THEN 5
		ELSE 6
	END
		
	SELECT @wk = DATEDIFF(wk, @wk0, @start_date)
	SELECT @temp = DATEADD(wk, @wk, @wk0)
	SELECT @temp = DATEADD(d, @dayOfWeek, @temp)

	IF @temp < @start_date SELECT @temp = DATEADD(wk, 1, @temp)
	
	WHILE @temp <= @stop_date
	BEGIN
		INSERT EmployeeLeaveEarned(EmployeeID, TypeID, Seconds, [Day past 1900], Note, [Auto]) 
		VALUES (@employee_id, @type_id, @seconds, DATEDIFF(d, 0, @temp), @note, 1)
		SELECT @temp = DATEADD(wk, 1, @temp)
	END	
END
	
-- Every Week of Seniority I : If seniority starts 1/3 then credit 1/3, 1/10, 1/17 ..
-- Every Week of Seniority III : If seniority starts 1/3 then credit 1/10, 1/17 ..
-- Every Week of Seniority IV : If seniority starts 1/3 then credit 1/9, 1/16 ..
ELSE IF @period_id IN (272512, 276608, 278656)
BEGIN
	IF @period_id <> 272512 SELECT @seniority_begins = DATEADD(wk, 1, @seniority_begins)
	IF @period_id = 278656 SELECT @seniority_begins = DATEADD(d, -1, @seniority_begins)

	EXEC spEmployeeLeaveEarnMapWeek 2, @seniority_begins, @start_date, @stop_date, @employee_id, @type_id, @seconds, @note 
END
-- Every Week of Seniority II : If seniority starts 1/3 then credit 1/3, 1/9, 1/16 ..
ELSE IF @period_id = 274560
BEGIN
	EXEC spEmployeeLeaveEarnMapWeek2 1, @seniority_begins, @start_date, @stop_date, @employee_id, @type_id, @seconds, @note 
END
GO
ALTER TABLE [dbo].[LeaveLimit] DROP CONSTRAINT [CK_LeaveLimit_InvalidPeriod]
ALTER TABLE [dbo].[LeaveLimit] ADD CONSTRAINT [CK_LeaveLimit_InvalidPeriod] CHECK ([PeriodID] >= 0 and [PeriodID] <= 4)
GO
ALTER VIEW dbo.vwLeaveLimit
AS
SELECT L.*, T.Type, [Description] = CASE WHEN L.[Max Seconds] IS NULL THEN 'Unlimited' ELSE
	CAST(CAST(L.[Max Seconds] / 3600 AS numeric(9,2)) AS varchar(100)) + ' Hrs' + CASE L.PeriodID
		WHEN 1 THEN ' Applied Every ' + 
			DATENAME(m, CONVERT(DATETIME,'00'+
				(CASE WHEN L.[Month]  < 10 THEN '0' ELSE '' END) + CAST(L.[Month] AS varchar(100))
			+'01',12)) + ' ' + CAST(L.[Day] AS varchar(100))
		WHEN 2 THEN ' Applied on Each Seniority Anniversary'
		WHEN 3 THEN ' Applied on the Eve of Each Seniority Anniversary'
		WHEN 4 THEN ' Applied Day ' + CAST(L.[Day] AS varchar(100)) + ' of Each Month'
		ELSE ''
	END
END
FROM LeaveLimit L
INNER JOIN LeaveType T ON L.TypeID = T.TypeID
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
IF OBJECT_ID('dbo.vwEmployeeLeaveApproved') IS NOT NULL DROP VIEW dbo.vwEmployeeLeaveApproved
GO
CREATE VIEW dbo.vwEmployeeLeaveApproved
AS
SELECT [Limit Adjustment] = CAST(CASE WHEN E.Auto = 2 THEN 1 ELSE 0 END AS bit), E.[Day past 1900], E.Seconds, [Date] = DATEADD(d, 0, E.[Day past 1900]), [Extended Type Mask] = E.TypeID, E.TypeID, E.EmployeeID FROM EmployeeLeaveEarned E
UNION
SELECT 0, I.[Day past 1900], -I.Seconds, I.[Date], I.[Extended Type Mask], I.TypeID, I.EmployeeID FROM vwEmployeeLeaveUsedItemApproved I
GO

-- Builds EmployeeLeaveUnused, a running total of unused paid leave
-- Applies limits
ALTER PROCEDURE dbo.spEmployeeLeaveUnusedBuild
	@employee_id int,	
	@type_id int,
	@start_day int
AS
DECLARE @item_id int, @last_recorded_day int
DECLARE @day int, @seconds int, @unused int
DECLARE @limit bit

SET NOCOUNT ON

DECLARE @carryover_source_leave_type_id int, @carryover_target_leave_type_id int
SELECT @carryover_source_leave_type_id = CarryoverSourceLeaveTypeID,  @carryover_target_leave_type_id = CarryoverTargetLeaveTypeID FROM Constant

-- Delete existing totals and limit adjustments
DELETE EmployeeLeaveUnused WHERE EmployeeID = @employee_id AND TypeID = @type_id AND [Day past 1900] >= @start_day
DELETE EmployeeLeaveEarned WHERE [Auto] = 2 AND [Day past 1900] >= @start_day AND EmployeeID = @employee_id AND TypeID = @type_id -- Auto 2 = Limit
IF @type_id <> @carryover_target_leave_type_id DELETE EmployeeLeaveEarned WHERE [Auto] = 3 AND EmployeeID = @employee_id AND TypeID = @type_id -- Auto 3 = Carryover

IF @carryover_source_leave_type_id = @type_id
DELETE EmployeeLeaveEarned WHERE [Auto] = 3 AND [Day past 1900] >= @start_day AND EmployeeID = @employee_id AND TypeID = @carryover_target_leave_type_id -- Auto 2 = Carryover

SELECT @unused = 0
SELECT @last_recorded_day = ISNULL(MAX(U.[Day past 1900]), -2147483648) FROM EmployeeLeaveUnused U WHERE EmployeeID = @employee_id AND TypeID = @type_id AND [Day Past 1900] < @start_day

SELECT @unused = Unused FROM EmployeeLeaveUnused WHERE EmployeeID = @employee_id AND TypeID = @type_id AND [Day past 1900] = @last_recorded_day

-- Does not build unused leave tables for types that have rolling accrual
-- Does not build unused leave tables for employee/types that are not accrued (no matching leaverate in an associated leaveplan)
-- Does not build unused leave tables for leave that is not approved (pending or denied)
DECLARE leave_cursor CURSOR FOR SELECT V.[Day past 1900], V.Seconds, V.[Limit Adjustment] FROM vwEmployeeLeaveApproved V WHERE
V.EmployeeID = @employee_id AND (V.TypeID = @type_id OR (V.[Extended Type Mask] & @type_id) != 0) AND V.[Day past 1900] > @last_recorded_day AND EXISTS
(
	SELECT RateID FROM EmployeeLeavePlan EP
	INNER JOIN LeavePlan P ON EP.EmployeeID = V.EmployeeID AND EP.PlanID = P.PlanID
	INNER JOIN LeaveRate R ON P.PlanID = R.PlanID AND R.TypeID = V.TypeID AND R.PeriodID NOT IN (38914, 2049)
)
ORDER BY [Day past 1900]


OPEN leave_cursor

SELECT @last_recorded_day = NULL

FETCH leave_cursor INTO @day, @seconds, @limit
WHILE @@FETCH_STATUS = 0
BEGIN
	SELECT @unused = @unused + @seconds


	SELECT @item_id = U.ItemID FROM EmployeeLeaveUnused U WHERE U.EmployeeID = @employee_id AND U.TypeID = @type_id AND U.[Day past 1900] = @day
	IF @last_recorded_day IS NULL OR @last_recorded_day != @day SET @item_id = NULL

	IF @item_id IS NULL
	BEGIN
		--PRINT  CAST(DATEADD(dd, @day, 0) AS varchar(11)) + ' Insert ' + CASt(@unused / 3600.0 AS varchar(40)) + ' ' + CASt(@seconds / 3600.0 AS varchar(40))
		INSERT EmployeeLeaveUnused(EmployeeID, TypeID, Unused, [Day past 1900], [Limit Adjustment])
		SELECT @employee_id, @type_id, @unused, @day, @limit

		SELECT @item_id = SCOPE_IDENTITY( )
	END
	ELSE
	BEGIN
		--PRINT  CAST(DATEADD(dd, @day, 0) AS varchar(11)) + ' Update ' + CASt(@unused / 3600.0 AS varchar(40)) + ' '+ ' ' + CASt(@seconds / 3600.0 AS varchar(40))
		UPDATE EmployeeLeaveUnused SET Unused = @unused, [Limit Adjustment] = CASE WHEN [Limit Adjustment] = 1 THEN 1 ELSE @limit  END WHERE ItemID = @item_id
	END

	SELECT @last_recorded_day = @day
	FETCH leave_cursor INTO @day, @seconds, @limit
END

CLOSE leave_cursor
DEALLOCATE leave_cursor

-- Recalc limit adjustments
EXEC spEmployeeLeaveLimit @employee_id, @type_id, @start_day
GO
ALTER PROC dbo.spEmployeeLeaveLimit
	@employee_id int,
	@type_id int,
	@start_day int
AS
DECLARE @plan_id int
DECLARE @effective_start datetime
DECLARE @effective_stop datetime
DECLARE @limit_id int
DECLARE @infinity datetime
DECLARE @infinity_day int
DECLARE @seniority_day int, @seniority datetime
DECLARE @start2 datetime, @stop datetime, @start datetime
DECLARE @start2_day int, @stop_day int
DECLARE @max_year int

SET NOCOUNT ON

SELECT @max_year = [Leave Seer Years] FROM Constant
SELECT @infinity = DATEADD(yy, @max_year, GETDATE()), @start = dbo.GetDateFromDaysPast1900(@start_day)
SELECT @seniority = dbo.GetDateFromDaysPast1900(@seniority_day), @infinity_day = DATEDIFF(d, 0, @infinity)


DECLARE emplan_cursor CURSOR LOCAL
FOR SELECT EP.PlanID,
		[Effective Start] = dbo.GetDateFromDaysPast1900(EP.[Start day past 1900]),
		[Effective Stop] = ISNULL(dbo.GetDateFromDaysPast1900(EP.[Stop day past 1900]), @infinity)
	FROM EmployeeLeavePlan EP 
	WHERE EP.EmployeeID = @employee_id AND EP.[Start Day past 1900] <= @infinity_day AND (EP.[Stop Day past 1900] IS NULL OR EP.[Stop Day past 1900] >= @start)
	ORDER BY EP.[Start Day past 1900]


OPEN emplan_cursor
FETCH NEXT FROM emplan_cursor INTO @plan_id, @effective_start, @effective_stop
WHILE @@FETCH_STATUS = 0
BEGIN
	SELECT @start2 = @effective_start
	SELECT @stop =  @effective_stop
	
	IF @start2 < @start SELECT @start2 = @start
	IF @stop > @infinity SELECT @stop = @infinity

	SELECT @start2_day = DATEDIFF(dd, 0, @start2), @stop_day = DATEDIFF(dd, 0, @stop)

	SELECT @limit_id = NULL
	SELECT @limit_id = LimitID FROM LeaveLimit WHERE PlanID = @plan_id AND TypeID = @type_id
	
	IF @stop_day >= @start2_day EXEC spEmployeeLeaveApplyLimits @employee_id, @type_id, @start2_day, @stop_day, @limit_id

	FETCH NEXT FROM emplan_cursor INTO @plan_id, @effective_start, @effective_stop
END
CLOSE emplan_cursor
DEALLOCATE emplan_cursor
GO
UPDATE Constant SET [Server Version] = 17