IF EXISTS(SELECT * FROM syscolumns WHERE [name] = '[Expires Day past 19001]' AND [id] = OBJECT_ID('dbo.EmployeeBenefit')) ALTER TABLE dbo.EmployeeBenefit DROP COLUMN [Expires Day past 19001]

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [name] = 'Note' AND [id] = OBJECT_ID('Benefit'))
ALTER TABLE Benefit ADD Note varchar(4000) NOT NULL DEFAULT ''

IF OBJECT_ID('dbo.spBenefitGetBenefitFromBenefitID') IS NOT NULL DROP PROC dbo.spBenefitGetBenefitFromBenefitID
IF OBJECT_ID('dbo.spBenefitListPremiums2') IS NOT NULL DROP PROC dbo.spBenefitListPremiums2
IF OBJECT_ID('dbo.spBenefitPremiumInsert') IS NOT NULL DROP PROC dbo.spBenefitPremiumInsert
IF OBJECT_ID('dbo.spBenefitPremiumUpdate') IS NOT NULL DROP PROC dbo.spBenefitPremiumUpdate
IF OBJECT_ID('dbo.spBenefitPremiumDelete') IS NOT NULL DROP PROC dbo.spBenefitPremiumDelete
IF OBJECT_ID('dbo.spBenefitPremiumList') IS NOT NULL DROP PROC dbo.spBenefitPremiumList
IF OBJECT_ID('dbo.spBenefitSelect') IS NOT NULL DROP PROC dbo.spBenefitSelect
IF OBJECT_ID('dbo.vwBenefitPremium') IS NOT NULL DROP VIEW dbo.vwBenefitPremium
IF OBJECT_ID('dbo.vwBenefit') IS NOT NULL DROP VIEW dbo.vwBenefit
IF OBJECT_ID('dbo.spLeaveSummarizeUnused2') IS NOT NULL DROP PROC dbo.spLeaveSummarizeUnused2
GO
IF OBJECT_ID('[dbo].[BenefitPremium]') IS NULL
BEGIN
	-- Predefined premiums
	CREATE TABLE [dbo].[BenefitPremium] (
		[PremiumID] [int] IDENTITY (1, 1) NOT NULL ,
		[BenefitID] [int] NOT NULL ,
		[Provider] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[Plan] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[Coverage] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[Employee Premium] [money] NOT NULL ,
		[Employer Premium] [money] NOT NULL ,
		[Home ZIP] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL 
	) ON [PRIMARY]
	
	ALTER TABLE [dbo].[BenefitPremium] WITH NOCHECK ADD 
		CONSTRAINT [PK_BenefitPremium] PRIMARY KEY  CLUSTERED 
		(
			[PremiumID]
		)  ON [PRIMARY] 


	ALTER TABLE [dbo].[BenefitPremium] ADD 
		CONSTRAINT [FK_BenefitPremium_Benefit] FOREIGN KEY 
		(
			[BenefitID]
		) REFERENCES [dbo].[Benefit] (
			[BenefitID]
		) ON DELETE CASCADE 
END
GO
CREATE PROC dbo.spBenefitGetBenefitFromBenefitID
	@benefit_id int,
	@benefit varchar(50) OUT
AS
SELECT @benefit = NULL
SELECT @benefit = Benefit FROM Benefit WHERE BenefitID = @benefit_id
GO
ALTER PROC dbo.spBenefitInsert
	@benefit varchar(50),
	@note varchar(4000) = '',
	@benefit_id int out

AS
SET NOCOUNT ON

INSERT Benefit(Benefit, Note)
VALUES (@benefit, @note)

SELECT @benefit_id = @@IDENTITY
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
ALTER PROC dbo.spPersonUpdateColumnVariant
	@person_id int,
	@field_id int,
	@value sql_variant,
	@authorized bit = NULL out
AS
DECLARE @error int
DECLARE @sql nvarchar(4000)
DECLARE @type int
DECLARE @length int

SET NOCOUNT ON

SELECT @type = S.xtype, @length = S.length
FROM ColumnGrid C
INNER JOIN syscolumns S ON C.FieldID = @field_id AND S.[id] = OBJECT_ID(C.[Table]) AND S.colid = C.colid


IF @@ROWCOUNT = 0 SET @error = 50017
ELSE
BEGIN
	EXEC spPersonUpdateColumnBase @person_id, @field_id, NULL, NULL, @sql out, @authorized out, @error out

	IF @error = 0 AND @authorized = 1 
	BEGIN
		DECLARE @tvalue varchar(4000)
		DECLARE @ivalue int
		SELECT @tvalue = SUBSTRING(CAST(@value as varchar(4000)), 1, @length)

		IF @type = 104 
		BEGIN
			DECLARE @bvalue bit
			SELECT @bvalue = CAST(@value as bit)
			EXEC sp_executesql @sql, N'@value bit, @person_id int', @bvalue, @person_id
		END
		ELSE IF @type = 56 
		BEGIN
			-- If the value is not a number, then assume it is a date that gets stored as days past 1900
			IF RTRIM(LTRIM(@tvalue)) = '' EXEC sp_executesql @sql, N'@value int, @person_id int', NULL, @person_id
			ELSE IF @tvalue LIKE '%[^0123456789. -]%' 
			BEGIN
				DECLARE @dvalue datetime
				SELECT @dvalue = CAST(@value as datetime)
				SELECT @ivalue = DATEDIFF(D, 0, @dvalue)
				EXEC sp_executesql @sql, N'@value int, @person_id int', @ivalue, @person_id
			END
			ELSE
			BEGIN
				SELECT @ivalue = CAST(@value as int)
				EXEC sp_executesql @sql, N'@value int, @person_id int', @ivalue, @person_id
			END
		END
		ELSE IF @type = 60
		BEGIN
			DECLARE @mvalue money
			SELECT @mvalue = CAST(@value as money)
			EXEC sp_executesql @sql, N'@value money, @person_id int', @mvalue, @person_id
		END
		ELSE IF @type = 167 EXEC sp_executesql @sql, N'@value varchar(4000), @person_id int', @tvalue, @person_id
		ELSE SET @error = 50017
	END
END

IF @error <>0 EXEC spErrorRaise @error
GO
CREATE VIEW dbo.vwBenefit AS SELECT * FROM Benefit
GO
ALTER PROC dbo.spBenefitList
AS
SELECT * FROM vwBenefit
ORDER BY Benefit
GO
CREATE PROC dbo.spBenefitSelect
	@benefit_id int
AS
SELECT * FROM vwBenefit WHERE BenefitID = @benefit_id
GO
ALTER VIEW dbo.vwEmployeeBenefit
AS
SELECT 
Eligible = dbo.GetDateFromDaysPast1900(EB.[Eligible Day past 1900]),
Notified = dbo.GetDateFromDaysPast1900(EB.[Notified Day past 1900]),
Expires = dbo.GetDateFromDaysPast1900(EB.[Expires Day past 1900]),
[First Enrolled] = dbo.GetDateFromDaysPast1900(EB.[First Enrolled Day past 1900]),
[Last Enrolled] = dbo.GetDateFromDaysPast1900(EB.[Last Enrolled Day past 1900]),
Declined = dbo.GetDateFromDaysPast1900(EB.[Declined Day past 1900]),
Enrollment = CASE 
	WHEN EB.[Declined Day past 1900] IS NOT NULL THEN
		CASE WHEN [First Enrolled Day past 1900] IS NULL THEN 'Declined ' ELSE 'Discontinued ' END + CAST(dbo.GetDateFromDaysPast1900(EB.[Declined Day past 1900]) AS varchar(11))
	WHEN EB.[Expires Day past 1900] IS NOT NULL THEN 'Enrolled. Expires ' + CAST(dbo.GetDateFromDaysPast1900(EB.[Expires Day past 1900]) AS varchar(11))
	WHEN EB.[Last Enrolled Day past 1900] IS NOT NULL THEN 'Enrolled ' + CAST(dbo.GetDateFromDaysPast1900(EB.[Last Enrolled Day past 1900]) AS varchar(11))
	WHEN EB.[First Enrolled Day past 1900] IS NOT NULL THEN 'Enrolled ' + CAST(dbo.GetDateFromDaysPast1900(EB.[First Enrolled Day past 1900]) AS varchar(11))
	WHEN EB.[Eligible Day past 1900] IS NOT NULL THEN 'Eligible ' + CAST(dbo.GetDateFromDaysPast1900(EB.[Eligible Day past 1900]) AS varchar(11))
	ELSE ''
END,
[Active] = CAST(CASE 
	WHEN EB.[Declined Day past 1900] IS NULL AND (EB.[First Enrolled Day past 1900]  IS NOT NULL OR EB.[Last Enrolled Day past 1900] IS NOT NULL) THEN 1
	ELSE 0
END AS bit),
EB.*, E.[Home ZIP] FROM EmployeeBenefit EB
INNER JOIN Person E ON EB.EmployeeID = E.PersonID
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
	SELECT @compensation_id = SCOPE_IDENTITY()

	COMMIT TRAN
END
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
	Provider varchar(50),
	[Plan] varchar(50),
	[Coverage] varchar(50),
	[Employee Premium] money,
	[Employer Premium] money,
	[Home Zip] varchar(50) DEFAULT '',
	[Min Zip] varchar(50) DEFAULT '',
	[Max Zip] varchar(50) DEFAULT '',
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
CREATE PROC dbo.spBenefitPremiumInsert
	@benefit_id int,
	@provider varchar(50),
	@plan varchar(50),
	@coverage varchar(50),
	@home_zip varchar(50),
	@employee_premium money,
	@employer_premium money,
	@premium_id int OUT
AS
INSERT BenefitPremium(BenefitID, Provider, [Plan], Coverage, [Home ZIP], [Employee Premium], [Employer Premium])
SELECT @benefit_id, @provider, @plan, @coverage, @home_zip, @employee_premium, @employer_premium

SET @premium_id = SCOPE_IDENTITY()
GO
CREATE PROC dbo.spBenefitPremiumUpdate
	@provider varchar(50),
	@plan varchar(50),
	@coverage varchar(50),
	@home_zip varchar(50),
	@employee_premium money,
	@employer_premium money,
	@premium_id int
AS
UPDATE BenefitPremium
SET Provider = @provider,
[Plan] = @plan,
Coverage = @coverage,
[Home ZIP] = @home_zip,
[Employee Premium] = @employee_premium,
[Employer Premium] = @employer_premium
WHERE PremiumID = @premium_id
GO
CREATE PROC dbo.spBenefitPremiumDelete
	@premium_id int
AS
DELETE BenefitPremium WHERE PremiumID = @premium_id
GO
CREATE VIEW dbo.vwBenefitPremium
AS
SELECT * FROM BenefitPremium
GO
CREATE PROC dbo.spBenefitPremiumList
	@benefit_id int
AS
SET NOCOUNT ON

SELECT * FROM vwBenefitPremium WHERE BenefitID = @benefit_id ORDER BY Provider, [Plan], Coverage, [Home ZIP]
GO
CREATE PROC dbo.spLeaveSummarizeUnused2
	@batch_id int,
	@type_id int,
	@day int,
	@authorized bit OUT
AS
DECLARE @plan_id int
DECLARE @month_seniority int
DECLARE @fmla_rate int
DECLARE @fmla_available int

SET NOCOUNT ON

EXEC spPermissionGetOnPeopleForCurrentUser2 @batch_id, 10003
DELETE TempX WHERE BatchID = @batch_id AND (X & 1) = 0
SELECT @authorized = CASE WHEN @@ROWCOUNT = 0 THEN 1 ELSE 0 END

-- Calculate Accumulated
SELECT EmployeeID = X.[ID],
[Accumulated Day] = ISNULL((
	SELECT MAX(U.[Day Past 1900]) FROM EmployeeLeaveUnused U WHERE U.[Day past 1900] <= @day AND U.EmployeeID = X.[ID] AND U.TypeID = @type_id
), 0),
[Accumulated] = 0,
[Available] = NULL,
[Limit Day] = NULL,
[Recent Day] = ISNULL((
	SELECT TOP 1 [Start Day past 1900] FROM EmployeeLeaveUsed U
	WHERE U.EmployeeID = X.[ID] AND [Start Day past 1900] > @day AND Status = 2
), @day),
Rolling = 0,
Recent = CAST('' AS varchar(80)),
[Month Seniority] = DATEDIFF(mm, [Seniority Begins Day past 1900], GETDATE()),
PlanID = (
	SELECT P.PlanID FROM EmployeeLeavePlan P WHERE P.EmployeeID = E.EmployeeID AND @day >= P.[Start Day past 1900] AND (P.[Stop Day past 1900] IS NULL OR @day <= P.[Stop Day past 1900])
)
INTO #U
FROM TempX X 
INNER JOIN Employee E ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID



DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1

UPDATE #U SET [Limit Day] = ISNULL((
	SELECT MIN(E.[Day Past 1900]) FROM vwEmployeeLeaveEarned E WHERE E.[Day past 1900] > @day AND E.EmployeeID = #U.EmployeeID AND E.TypeID = @type_id AND E.[Limit Adjustment] = 1
), 2147483647)

UPDATE #U SET Accumulated = U.Unused
FROM #U
INNER JOIN EmployeeLeaveUnused U ON U.EmployeeID = #U.EmployeeID AND U.TypeID = @type_id AND U.[Day past 1900] = #U.[Accumulated Day]

-- Calculate available
UPDATE #U SET Available = (
	SELECT MIN(U.Unused) FROM EmployeeLeaveUnused U WHERE U.EmployeeID = #U.EmployeeID AND U.TypeID = @type_id AND U.[Day past 1900] >= @day AND U.[Day past 1900] < #U.[Limit Day]
)
FROM #U

UPDATE #U SET Available = Accumulated WHERE Available IS NULL OR Available > Accumulated






-- Special case: rolling year (38914)

-- Identify which people have plans of this type that include rolling years as of day
UPDATE #U SET Rolling = R.Seconds FROM #U
INNER JOIN EmployeeLeavePlan EP ON #U.EmployeeID = EP.EmployeeID AND @day >= EP.[Start Day past 1900] AND (@day <= EP.[Stop Day past 1900] OR EP.[Stop Day past 1900] IS NULL)
INNER JOIN LeaveRate R ON R.TypeID = @type_id AND R.PeriodID = 38914 AND EP.PlanID = R.PlanID

-- #R holds available leave based on rolling accrual for a given employee over a variety of days (D)
CREATE TABLE #R(
	EmployeeID int,
	D int,
	Available int
)

CREATE UNIQUE INDEX R04132005 ON #R(EmployeeID, D) WITH IGNORE_DUP_KEY 

INSERT #R
SELECT #U.EmployeeID, @day, #U.Rolling FROM #U WHERE Rolling != 0

-- Employees with used leave, start day
INSERT #R
SELECT U.EmployeeID, U.[Start Day past 1900], #U.Rolling FROM EmployeeLeaveUsed U
INNER JOIN #U ON #U.Rolling != 0 AND U.EmployeeID = #U.EmployeeID AND U.[Start Day past 1900] BETWEEN @day AND (@day + 364) AND 
(U.[Advanced Type Mask] & @type_id) != 0 AND Status = 2

-- Employees with used leave, stop day
INSERT #R
SELECT U.EmployeeID, U.[Stop Day past 1900], #U.Rolling FROM EmployeeLeaveUsed U
INNER JOIN #U ON #U.Rolling != 0 AND U.EmployeeID = #U.EmployeeID AND U.[Stop Day past 1900] BETWEEN @day AND (@day + 364) AND 
(U.[Advanced Type Mask] & @type_id) != 0 AND Status = 2

-- Employees with negative earned leave adjustments
INSERT #R
SELECT E.EmployeeID, E.[Day Past 1900], #U.Rolling FROM EmployeeLeaveEarned E
INNER JOIN #U ON #U.Rolling != 0 AND E.Seconds < 0 AND E.[Day past 1900] BETWEEN @day AND (@day + 364) ANd E.TypeID = @type_id


UPDATE #R SET Available = Available - ISNULL((
	SELECT SUM(U.Seconds) FROM vwEmployeeLeaveUsedItemApproved U WHERE U.EmployeeID = #R.EmployeeID AND (U.[Extended Type Mask] & @type_id) != 0 AND U.[Day past 1900] BETWEEN (#R.D - 364) AND #R.D
), 0)

-- Updates #U based on #R
UPDATE #U SET Available = (
	SELECT MIN(Available) FROM #R WHERE #R.EmployeeID = #U.EmployeeID
), Accumulated = (
	SELECT Available FROM #R WHERE #R.EmployeeID = #U.EmployeeID AND #R.D = @day
)
WHERE Rolling != 0






-- Special case: rolling year (2049)

UPDATE #U SET Rolling = 0
DELETE #R

-- Identify which people have plans of this type that include rolling 24 months as of day
UPDATE #U SET Rolling = R.Seconds FROM #U
INNER JOIN EmployeeLeavePlan EP ON #U.EmployeeID = EP.EmployeeID AND @day >= EP.[Start Day past 1900] AND (@day <= EP.[Stop Day past 1900] OR EP.[Stop Day past 1900] IS NULL)
INNER JOIN LeaveRate R ON R.TypeID = @type_id AND R.PeriodID = 2049 AND EP.PlanID = R.PlanID
 

INSERT #R
SELECT #U.EmployeeID, @day, #U.Rolling FROM #U WHERE Rolling != 0

INSERT #R
SELECT U.EmployeeID, U.[Start Day past 1900], #U.Rolling FROM EmployeeLeaveUsed U
INNER JOIN #U ON #U.Rolling != 0 AND U.EmployeeID = #U.EmployeeID AND U.[Start Day past 1900] BETWEEN @day AND (@day + 729) AND 
(U.[Advanced Type Mask] & @type_id) != 0 AND Status = 2

INSERT #R
SELECT U.EmployeeID, U.[Stop Day past 1900], #U.Rolling FROM EmployeeLeaveUsed U
INNER JOIN #U ON #U.Rolling != 0 AND U.EmployeeID = #U.EmployeeID AND U.[Stop Day past 1900] BETWEEN @day AND (@day + 729) AND 
(U.[Advanced Type Mask] & @type_id) != 0 AND Status = 2

-- Employees with negative earned leave adjustments
INSERT #R
SELECT E.EmployeeID, E.[Day Past 1900], #U.Rolling FROM EmployeeLeaveEarned E
INNER JOIN #U ON #U.Rolling != 0 AND E.Seconds < 0 AND E.[Day past 1900] BETWEEN @day AND (@day + 364) ANd E.TypeID = @type_id


UPDATE #R SET Available = Available - ISNULL((
	SELECT SUM(U.Seconds) FROM vwEmployeeLeaveUsedItemApproved U WHERE U.EmployeeID = #R.EmployeeID AND (U.[Extended Type Mask] & @type_id) != 0 AND U.[Day past 1900] BETWEEN (#R.D - 729) AND #R.D
), 0)

-- Updates #U based on #R
UPDATE #U SET Available = (
	SELECT MIN(Available) FROM #R WHERE #R.EmployeeID = #U.EmployeeID
), Accumulated = (
	SELECT Available FROM #R WHERE #R.EmployeeID = #U.EmployeeID AND #R.D = @day
)
WHERE Rolling != 0




DECLARE @yy int, @ly int
SELECT @yy = YEAR(GETDATE())

DECLARE @this_year_start int, @this_year_stop int
DECLARE @last_year_start int, @last_year_stop int
DECLARE @rolling_start int, @rolling_stop int

SELECT @this_year_start = DATEDIFF(dd, 0, dbo.GetDateFromMDY(1, 1, @yy))
SELECT @this_year_stop = DATEDIFF(dd, 0, dbo.GetDateFromMDY(12, 31, @yy))

SELECT @ly = @yy - 1
SELECT @last_year_start = DATEDIFF(dd, 0, dbo.GetDateFromMDY(1, 1, @ly))
SELECT @last_year_stop = DATEDIFF(dd, 0, dbo.GetDateFromMDY(12, 31, @ly))

SELECT @rolling_start = DATEDIFF(dd, 0, DATEADD(yy, -1, GETDATE())) + 1
SELECT @rolling_stop = DATEDIFF(dd, 0, GETDATE())

DECLARE @rows int
SET @rows = 1

WHILE @rows > 0
BEGIN
	UPDATE #U SET Recent = SUBSTRING(
		Recent +
		CASE WHEN Recent = '' THEN '' ELSE ', ' END +
		CASE WHEN YEAR([Start Day past 1900]) = @yy THEN CAST(DATEADD(d, [Start Day past 1900], 0) AS varchar(6))
		ELSE CAST(DATEADD(d, [Start Day past 1900], 0) AS varchar(11)) END
		+
		CASE WHEN [Start Day past 1900] != [Stop Day past 1900] THEN ' to ' + CAST(DATEADD(d, [Stop Day past 1900], 0) AS varchar(6))
		ELSE '' END,
		0, 80
	)
	,
	[Recent Day] = (
		SELECT TOP 1 [Start Day past 1900] FROM EmployeeLeaveUsed U
		WHERE U.EmployeeID = #U.EmployeeID AND [Start Day past 1900] < [Recent Day] AND Status = 2
	)
	FROM #U
	INNER JOIN EmployeeLeaveUsed U ON #U.[Recent Day] = U.[Start Day past 1900] AND LEN(Recent) < 80

	SET @rows = @@ROWCOUNT
END

-- Return results
SELECT
#U.EmployeeID,
#U.Recent,
Employee = P.[List As],
[Annualized Hrs] = CASE WHEN R.Seconds IS NULL THEN 0 ELSE R.Seconds * (2080.0 / R.[Seconds in Period]) END,
[Accumulated Hrs] = #U.Accumulated / 3600.0,
[Available Hrs] = #U.Available / 3600.0,
[Used Last Year Hrs] = ISNULL((
	SELECT SUM(I.Seconds) FROM vwEmployeeLeaveUsedItemApproved I WHERE
	I.EmployeeID = #U.EmployeeID AND (I.[Extended Type Mask] & @type_id) != 0 AND I.[Day past 1900] BETWEEN @last_year_start AND @last_year_stop
), 0) / 3600.0,
[Used This Year Hrs] = ISNULL((
	SELECT SUM(I.Seconds) FROM vwEmployeeLeaveUsedItemApproved I WHERE
	I.EmployeeID = #U.EmployeeID AND (I.[Extended Type Mask] & @type_id) != 0 AND I.[Day past 1900] BETWEEN @this_year_start AND @this_year_stop
), 0) / 3600.0,
[Used Rolling Year Hrs] = ISNULL((
	SELECT SUM(I.Seconds) FROM vwEmployeeLeaveUsedItemApproved I WHERE
	I.EmployeeID = #U.EmployeeID AND (I.[Extended Type Mask] & @type_id) != 0 AND I.[Day past 1900] BETWEEN @rolling_start AND @rolling_stop
), 0) / 3600.0,
[Scheduled Hrs] = ISNULL((
	SELECT SUM(I.Seconds) FROM vwEmployeeLeaveUsedItemApproved I WHERE
	I.EmployeeID = #U.EmployeeID AND (I.[Extended Type Mask] & @type_id) != 0 AND I.[Day past 1900] > @day
), 0) / 3600.0
FROM #U
LEFT JOIN vwLeaveRate R ON R.TypeID = @type_id AND R.PlanID = #U.PlanID AND #U.[Month Seniority] BETWEEN R.[Start Month] AND R.[Stop Month]
INNER JOIN vwPersonListAs P ON #U.EmployeeID = P.PersonID

ORDER BY P.[List As], #U.EmployeeID
GO
CREATE PROC dbo.spBenefitListPremiums2
	@benefit_id int
AS
SET NOCOUNT ON

-- Insert explicitly defined premiums
SELECT B.Benefit, EB.Provider, EB.[Plan], EB.Coverage, [Home Zip] = CASE WHEN MIN(EB.[Home ZIP]) = MAX(EB.[Home ZIP]) THEN MIN(EB.[Home ZIP]) ELSE '' END, EB.[Employee Premium], EB.[Employer Premium]
INTO #EB
FROM vwEmployeeBenefit EB
INNER JOIN Benefit B ON EB.Active = 1 AND EB.BenefitID = B.BenefitID AND (@benefit_id IS NULL OR EB.BenefitID = @benefit_id)
GROUP BY B.Benefit, EB.Provider, EB.[Plan], EB.Coverage, EB.[Employee Premium], EB.[Employer Premium] 

INSERT #EB
SELECT B.Benefit, P.Provider, P.[Plan], P.Coverage, P.[Home ZIP], P.[Employee Premium], P.[Employer Premium] 
FROM BenefitPremium P
INNER JOIN Benefit B ON P.BenefitID = B.BenefitID AND (P.[Employee Premium] != 0 OR P.[Employer Premium] !=0) AND (@benefit_id IS NULL OR P.BenefitID = @benefit_id)

SELECT Benefit, Provider, [Plan], Coverage, [Home Zip] = CASE WHEN MIN([Home ZIP]) = MAX([Home ZIP]) THEN MIN([Home ZIP]) ELSE '' END, [Employee Premium], [Employer Premium]
FROM #EB
GROUP BY Benefit, Provider, [Plan], Coverage, [Employee Premium], [Employer Premium] 
ORDER BY Benefit, Provider, [Plan], [Home ZIP], Coverage, [Employee Premium]
GO
GRANT EXEC ON dbo.spBenefitListPremiums2 TO public
GRANT EXEC ON dbo.spBenefitPremiumList TO public
GRANT EXEC ON dbo.spBenefitSelect TO public
GRANT EXEC ON dbo.spBenefitGetBenefitFromBenefitID TO public
GRANT EXEC ON dbo.spLeaveSummarizeUnused2 TO public
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
VALUES(24, 2, OBJECT_ID(N'spBenefitPremiumUpdate'))

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(24, 4, OBJECT_ID(N'spBenefitInsert'))
INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(24, 4, OBJECT_ID(N'spTDRPInsert'))
INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(24, 4, OBJECT_ID(N'spTDRPMatchingInsert'))
INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(24, 4, OBJECT_ID(N'spBenefitPremiumInsert'))

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(24, 8, OBJECT_ID(N'spTDRPMatchingDelete'))
INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(24, 8, OBJECT_ID(N'spBenefitPremiumDelete'))

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
EXEC dbo.spPermissionAssociateIDsForStoredProcsWithAffectedTable

-- Sets proper permission on Benefits, PayTable, PayStep, and Pay
DECLARE @scope_id int, @uid int, @permission_mask int, @attribute_id int

DECLARE p_cursor CURSOR FOR SELECT ScopeID, AttributeID, UID, [Permission Mask] FROM PermissionScopeAttribute WHERE AttributeID IN (24, 33)

OPEN p_cursor
FETCH p_cursor INTO @scope_id, @attribute_id, @uid, @permission_mask
WHILE @@FETCH_STATUS = 0
BEGIN
	EXEC spPermissionUpdateForUserScopeOnAttribute @scope_id, @attribute_id, @uid, @permission_mask
	FETCH p_cursor INTO @scope_id, @attribute_id, @uid, @permission_mask
END
CLOSE p_cursor
DEALLOCATE p_cursor
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

SELECT * INTO #R FROM vwReminderTypes WHERE @show_reminders = 1 AND (@owner_id IS NULL OR OwnerEmployeeID = @owner_id)
CREATE INDEX R_ReminderTypeID_EmployeeID ON #R(ReminderTypeID, EmployeeID)

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
INNER JOIN #R R ON R.ReminderTypeID = 1 AND E.EmployeeID = R.EmployeeID AND 
	dbo.DoRaysIntersect(E.[Next Performance Review Day past 1900] - R.Days, E.[Next Performance Review Day past 1900],  @due_start, @due_stop) = 1 AND
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
INNER JOIN #R R ON R.ReminderTypeID = 2 AND E.EmployeeID = R.EmployeeID AND R.[Active Employee] = 1 AND
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
INNER JOIN #R R ON R.ReminderTypeID = 3 AND P.PersonID = R.EmployeeID AND R.[Active Employee] = 1 AND
	dbo.DoRaysIntersect(P.[Expires Day past 1900] - R.Days, P.[Expires Day past 1900], @due_start, @due_stop) = 1 AND
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
INNER JOIN #R R ON R.ReminderTypeID = 4 AND P.PersonID = R.EmployeeID AND R.[Active Employee] = 1 AND
	dbo.DoRaysIntersect(P.[Renew I9 Status Day past 1900] - R.Days, P.[Renew I9 Status Day past 1900], @due_start, @due_stop) =  1 AND
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
INNER JOIN #R R ON R.ReminderTypeID = 5 AND P.PersonID = R.EmployeeID AND R.[Active Employee] = 1 AND
	dbo.DoRaysIntersect(P.[Visa Expires Day past 1900] - R.Days, P.[Visa Expires Day past 1900], @due_start, @due_stop) = 1 AND
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
INNER JOIN #R R ON R.ReminderTypeID = 6 AND P.PersonID = R.EmployeeID AND R.[Active Employee] = 1 AND
	dbo.DoRaysIntersect(P.[Passport Expires Day past 1900] - R.Days, P.[Passport Expires Day past 1900], @due_start, @due_stop)  = 1 AND
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
INNER JOIN #R R ON R.ReminderTypeID = 7 AND P.PersonID = R.EmployeeID AND R.[Active Employee] = 1 AND
	dbo.DoRaysIntersect(P.[Driver License Expires Day past 1900] - R.Days, P.[Driver License Expires Day past 1900], @due_start,  @due_stop) = 1 AND
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
INNER JOIN #R R ON R.ReminderTypeID = 8 AND P.PersonID = R.EmployeeID AND R.[Active Employee] = 1 AND
	dbo.DoRaysIntersect(P.[Driver Insurance Expires Day past 1900] - R.Days, P.[Driver Insurance Expires Day past 1900],  @due_start, @due_stop) = 1 AND
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
INNER JOIN #R R ON R.ReminderTypeID = 9 AND P.PersonID = R.EmployeeID AND R.[Active Employee] = 1 AND
	(
		(MONTH(dbo.GetDateFromDaysPast1900(P.[Birth Day past 1900])) * 100 + DAY(dbo.GetDateFromDaysPast1900(P.[Birth Day past 1900]))) BETWEEN
		MONTH(GETDATE()) * 100 + DAY(GETDATE()) AND
		MONTH(DATEADD(d, R.Days, GETDATE())) * 100 + DAY(DATEADD(d, R.Days, GETDATE()))
	) AND
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
INNER JOIN #R R ON R.ReminderTypeID = 10 AND P.PersonID = R.EmployeeID AND  R.[Active Employee] = 1 AND
	dbo.DoRaysIntersect(P.[Expires Day past 1900] - R.Days, P.[Expires Day past 1900], @due_start, @due_stop) = 1 AND
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
INNER JOIN #R R ON R.ReminderTypeID = 11 AND U.EmployeeID = R.EmployeeID AND
	dbo.DoRaysIntersect(U.[Start Day past 1900] - R.Days, U.[Start Day past 1900], @due_start, @due_stop) = 1 AND
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
INNER JOIN #R R ON R.ReminderTypeID = 12 AND U.EmployeeID = R.EmployeeID AND
	dbo.DoRaysIntersect(U.[Stop Day past 1900] - R.Days, U.[Stop Day past 1900], @due_start, @due_stop) = 1 AND U.[Stop Day past 1900] > @todaym7 AND
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
INNER JOIN #R R ON R.ReminderTypeID = 13 AND U.EmployeeID = R.EmployeeID AND
	dbo.DoRaysIntersect(U.[Start Day past 1900] - R.Days, U.[Start Day past 1900], @due_start, @due_stop) = 1 AND U.[Start Day past 1900] > @todaym7 AND
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
INNER JOIN #R R ON R.ReminderTypeID = 14 AND E.EmployeeID = R.EmployeeID AND 
	dbo.DoRaysIntersect(E.[Recertify Condition Day past 1900] - R.Days, E.[Recertify Condition Day past 1900], @due_start, @due_stop) = 1 AND
	(@regarding_id IS NULL OR E.EmployeeID = @regarding_id)
INNER JOIN TempX X ON X.BatchID = @batch_id AND R.OwnerEmployeeID = X.[ID]



--************************************** (END) ************************************************

ORDER BY Urgent DESC, Due ASC, Completed ASC





DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1
GO


UPDATE Constant SET [Server Version]= 29
GO

IF OBJECT_ID('CK_Subfolder_BadCharacters') IS NULL
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

	ALTER TABLE [dbo].[Subfolder] ADD 
	CONSTRAINT [CK_Subfolder_BadCharacters] CHECK (charindex('\',[Subfolder]) <= 0 and charindex('/',[Subfolder]) <= 0 and charindex(':',[Subfolder]) <= 0 and charindex('*',[Subfolder]) <= 0 and charindex('?',[Subfolder]) <= 0 and charindex('"',[Subfolder]) <= 0 and charindex('<',[Subfolder]) <= 0 and charindex('>',[Subfolder]) <= 0 and charindex('|',[Subfolder]) <= 0)
END
GO
IF OBJECT_ID('dbo.Filter') IS NULL
BEGIN
	CREATE TABLE [dbo].[Filter] (
		[FilterID] [int] IDENTITY (1, 1) NOT NULL ,
		[Filter] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[Stream] [image] NOT NULL ,
		[Active] [bit] NULL 
	) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
	
	ALTER TABLE [dbo].[Filter] WITH NOCHECK ADD CONSTRAINT [PK_Filter] PRIMARY KEY CLUSTERED ([FilterID])  ON [PRIMARY] 
	ALTER TABLE [dbo].[Filter] WITH NOCHECK ADD CONSTRAINT [IX_Filter_Name] UNIQUE  NONCLUSTERED ([Filter])  ON [PRIMARY] ,
		CONSTRAINT [CK_Filter_NameRequired] CHECK (len([Filter]) > 0)
END
GO
IF NOT EXISTS(SELECT * FROM syscolumns WHERE [name] = 'OT Comp' AND [id] = OBJECT_ID('dbo.LeaveType'))
ALTER TABLE LeaveType ADD [OT Comp] bit NOT NULL DEFAULT 0

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [name] = 'OT Eligible' AND [id] = OBJECT_ID('dbo.LeaveType'))
ALTER TABLE LeaveType ADD [OT Eligible] bit NOT NULL DEFAULT 1

IF NOT EXISTS(SELECT * FROM syscolumns WHERE [name] = 'Active Role Mask' AND [id] = OBJECT_ID('dbo.Person'))
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
	FROM syscolumns WHERE [ID] = OBJECT_ID('dbo.Employee') AND [name] LIKE '%COBRA%'
END

IF OBJECT_ID('dbo.spTempXDelete') IS NOT NULL DROP PROC dbo.spTempXDelete
IF OBJECT_ID('dbo.spTempXList') IS NOT NULL DROP PROC dbo.spTempXList
IF OBJECT_ID('dbo.vwLeaveType') IS NOT NULL DROP VIEW dbo.vwLeaveType
IF OBJECT_ID('dbo.spPersonSelect2') IS NOT NULL DROP PROC dbo.spPersonSelect2
IF OBJECT_ID('dbo.spPersonListAsListItems2') IS NOT NULL DROP PROC dbo.spPersonListAsListItems2
IF OBJECT_ID('dbo.ChangePersonRoleMaskOnEmployeeUpdate') IS NOT NULL DROP TRIGGER ChangePersonRoleMaskOnEmployeeUpdate
IF OBJECT_ID('dbo.spPositionGetPositionFromPositionID') IS NOT NULL DROP PROC dbo.spPositionGetPositionFromPositionID
IF OBJECT_ID('dbo.spFilterInsert') IS NOT NULL DROP PROC dbo.spFilterInsert
IF OBJECT_ID('dbo.spFilterUpdate') IS NOT NULL DROP PROC dbo.spFilterUpdate
IF OBJECT_ID('dbo.spFilterSelect') IS NOT NULL DROP PROC dbo.spFilterSelect
IF OBJECT_ID('dbo.spFilterDelete') IS NOT NULL DROP PROC dbo.spFilterDelete
IF OBJECT_ID('dbo.spFilterList') IS NOT NULL DROP PROC dbo.spFilterList
IF OBJECT_ID('dbo.spPersonListPrepareBatchPOr') IS NOT NULL DROP PROC dbo.spPersonListPrepareBatchPOr
IF OBJECT_ID('dbo.spPersonListPrepareBatchPAnd') IS NOT NULL DROP PROC dbo.spPersonListPrepareBatchPAnd
IF OBJECT_ID('dbo.spPersonListPrepareBatchBOr') IS NOT NULL DROP PROC dbo.spPersonListPrepareBatchBOr
IF OBJECT_ID('dbo.spPersonListPrepareBatchBAnd') IS NOT NULL DROP PROC dbo.spPersonListPrepareBatchBAnd
IF OBJECT_ID('dbo.spPersonListPrepareBatch3') IS NOT NULL DROP PROC dbo.spPersonListPrepareBatch3
GO
ALTER VIEW dbo.vwEmployeeCOBRA
AS
SELECT
E.EmployeeID,
Employee = P.[List As],
E.[Track COBRA],
E.[First Payment Due Day past 1900] , [First Payment Due] = dbo.GetDateFromDaysPast1900(E.[First Payment Due Day past 1900]),
E.[Next Payment Due Day past 1900], [Next Payment Due] = dbo.GetDateFromDaysPast1900(E.[Next Payment Due Day past 1900]),
[Payment Due Day past 1900] = ISNULL(E.[First Payment Due Day past 1900], [Next Payment Due Day past 1900]),
[Payment Due] = dbo.GetDateFromDaysPast1900(ISNULL(E.[First Payment Due Day past 1900], [Next Payment Due Day past 1900])),
E.[COBRA Eligible Day past 1900], [COBRA Eligible] = dbo.GetDateFromDaysPast1900(E.[COBRA Eligible Day past 1900]),
E.[COBRA Notified Day past 1900], [COBRA Notified] = dbo.GetDateFromDaysPast1900(E.[COBRA Notified Day past 1900]),
E.[COBRA First Enrolled Day past 1900], [COBRA First Enrolled] = dbo.GetDateFromDaysPast1900(E.[COBRA First Enrolled Day past 1900]),
E.[COBRA Last Enrolled Day past 1900], [COBRA Last Enrolled] = dbo.GetDateFromDaysPast1900(E.[COBRA Last Enrolled Day past 1900]),
E.[COBRA Declined Day past 1900], [COBRA Declined] = dbo.GetDateFromDaysPast1900(E.[COBRA Declined Day past 1900]),
E.[COBRA Expires Day past 1900], [COBRA Expires] = dbo.GetDateFromDaysPast1900(E.[COBRA Expires Day past 1900]),
E.[Benefit Note],
Enrollment = CASE 
	WHEN E.[Track COBRA] = 0 THEN ''
	WHEN E.[COBRA Declined Day past 1900] IS NOT NULL THEN
		CASE WHEN [COBRA First Enrolled Day past 1900] IS NULL THEN 'Declined ' ELSE 'Discontinued ' END + CAST(dbo.GetDateFromDaysPast1900(E.[COBRA Declined Day past 1900]) AS varchar(11))
	WHEN E.[COBRA Expires Day past 1900] IS NOT NULL THEN 'Expires ' + CAST(dbo.GetDateFromDaysPast1900(E.[COBRA Expires Day past 1900]) AS varchar(11))
	WHEN E.[COBRA Last Enrolled Day past 1900] IS NOT NULL THEN 'Enrolled ' + CAST(dbo.GetDateFromDaysPast1900(E.[COBRA Last Enrolled Day past 1900]) AS varchar(11))
	WHEN E.[COBRA First Enrolled Day past 1900] IS NOT NULL THEN 'Enrolled ' + CAST(dbo.GetDateFromDaysPast1900(E.[COBRA First Enrolled Day past 1900]) AS varchar(11))
	WHEN E.[COBRA Eligible Day past 1900] IS NOT NULL THEN 'Eligible ' + CAST(dbo.GetDateFromDaysPast1900(E.[COBRA Eligible Day past 1900]) AS varchar(11))
	ELSE ''
END,
EnrollmentID = CASE 
	WHEN E.[Track COBRA] = 0 THEN 0
	WHEN E.[COBRA Declined Day past 1900] IS NOT NULL THEN 5
	WHEN E.[COBRA Expires Day past 1900] IS NOT NULL THEN 4
	WHEN E.[COBRA Last Enrolled Day past 1900] IS NOT NULL THEN 3
	WHEN E.[COBRA First Enrolled Day past 1900] IS NOT NULL THEN 2
	WHEN E.[COBRA Eligible Day past 1900] IS NOT NULL THEN 1
	ELSE 0
END
FROM Employee E
INNER JOIN vwPersonListAs P ON E.EmployeeID = P.PersonID
GO
ALTER  VIEW vwEmployeeBenefit
AS
SELECT 
Eligible = dbo.GetDateFromDaysPast1900(EB.[Eligible Day past 1900]),
Notified = dbo.GetDateFromDaysPast1900(EB.[Notified Day past 1900]),
Expires = dbo.GetDateFromDaysPast1900(EB.[Expires Day past 1900]),
[First Enrolled] = dbo.GetDateFromDaysPast1900(EB.[First Enrolled Day past 1900]),
[Last Enrolled] = dbo.GetDateFromDaysPast1900(EB.[Last Enrolled Day past 1900]),
Declined = dbo.GetDateFromDaysPast1900(EB.[Declined Day past 1900]),
Enrollment = CASE 
	WHEN EB.[Declined Day past 1900] IS NOT NULL THEN
		CASE WHEN [First Enrolled Day past 1900] IS NULL THEN 'Declined ' ELSE 'Discontinued ' END + CAST(dbo.GetDateFromDaysPast1900(EB.[Declined Day past 1900]) AS varchar(11))
	WHEN EB.[Expires Day past 1900] IS NOT NULL THEN 'Enrolled. Expires ' + CAST(dbo.GetDateFromDaysPast1900(EB.[Expires Day past 1900]) AS varchar(11))
	WHEN EB.[Last Enrolled Day past 1900] IS NOT NULL THEN 'Enrolled ' + CAST(dbo.GetDateFromDaysPast1900(EB.[Last Enrolled Day past 1900]) AS varchar(11))
	WHEN EB.[First Enrolled Day past 1900] IS NOT NULL THEN 'Enrolled ' + CAST(dbo.GetDateFromDaysPast1900(EB.[First Enrolled Day past 1900]) AS varchar(11))
	WHEN EB.[Eligible Day past 1900] IS NOT NULL THEN 'Eligible ' + CAST(dbo.GetDateFromDaysPast1900(EB.[Eligible Day past 1900]) AS varchar(11))
	ELSE ''
END,
EnrollmentID = CASE 
	WHEN EB.[Declined Day past 1900] IS NOT NULL THEN 5
	WHEN EB.[Expires Day past 1900] IS NOT NULL THEN 4
	WHEN EB.[Last Enrolled Day past 1900] IS NOT NULL THEN 3
	WHEN EB.[First Enrolled Day past 1900] IS NOT NULL THEN 2
	WHEN EB.[Eligible Day past 1900] IS NOT NULL THEN 1
	ELSE 0
END,
[Active] = CAST(CASE 
	WHEN EB.[Declined Day past 1900] IS NULL AND (EB.[First Enrolled Day past 1900]  IS NOT NULL OR EB.[Last Enrolled Day past 1900]  IS NOT NULL) THEN 1
	ELSE 0
END AS bit),
EB.* FROM EmployeeBenefit EB
GO
CREATE PROC dbo.spFilterInsert
	@filter varchar(50),
	@active bit,
	@stream image,
	@filter_id int OUT
AS
INSERT Filter(Filter, Active, Stream)
VALUES (@filter, @active, @stream)

SET @filter_id = SCOPE_IDENTITY()
GO
CREATE PROC dbo.spFilterUpdate
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
CREATE PROC dbo.spFilterDelete
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
CREATE PROC dbo.spFilterList
AS
SET NOCOUNT ON
SELECT Filter, FilterID FROM Filter ORDER BY Filter
GO
CREATE PROC dbo.spPositionGetPositionFromPositionID
	@position_id int,
	@position varchar(50) OUT
AS
SET NOCOUNT ON

SET @position = ''
SELECT @position = [Job Title] FROM Position WHERE PositionID = @position_id
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
SELECT *, Flags = Paid + Advanced * 2 + [OT Comp] * 4 + [OT Eligible] * 8 FROM LeaveType
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

IF @authorized = 1 EXEC spEmployeeUpdateAccount2 @employee_id, @sid
GO
ALTER PROC dbo.spLeaveTypeInsert
	@type varchar(50),
	@paid bit,
	@advanced bit,
	@ot_eligible bit = 1,
	@ot_comp bit = 0,
	@initial_period_id int,
	@initial_seconds int,
	@type_id int OUT
AS
DECLARE @continue bit
DECLARE @error bit
DECLARE @order int

SET NOCOUNT ON

SELECT @type_id = 1, @continue = 0, @error = 0

SELECT @continue = 1 FROM LeaveType WHERE TypeID = @type_id

WHILE @continue = 1
BEGIN
	SELECT @type_id = @type_id * 2, @continue = 0

	IF @type_id = 0x40000000
		SELECT @error = 1 FROM LeaveType WHERE TypeID = @type_id
	ELSE
		SELECT @continue = 1 FROM LeaveType WHERE TypeID = @type_id
END

IF @error = 1
	EXEC spErrorRaise 50006
ELSE
BEGIN
	SELECT @order = ISNULL(MAX([Order]) + 1, 0) FROM LeaveType

	INSERT LeaveType(TypeID, [Type], Paid, Advanced, [OT Eligible], [OT Comp], [Order], InitialPeriodID, [Initial Seconds])
	VALUES(@type_id, @type, @paid, @advanced, @ot_eligible, @ot_comp, @order, @initial_period_id, @initial_seconds)
END
GO
ALTER PROC dbo.spLeaveTypeUpdate
	@type_id int,
	@paid bit,
	@ot_eligible bit = 1,
	@ot_comp bit = 0,
	@type varchar(50)
AS
SET NOCOUNT ON

UPDATE LeaveType SET [Type] = @type, Paid = @paid, [OT Eligible] = @ot_eligible, [OT Comp] = @ot_comp WHERE TypeID = @type_id
GO
CREATE PROC dbo.spPersonListAsListItems2
	@batch_id int
AS

EXEC spPermissionGetOnPeopleForCurrentUser2 @batch_id, 4

SELECT P.PersonID,
P.[List As],
P.[Full Name],
[Employee Number] = ISNULL(E.[Employee Number], ''),
SSN = CASE WHEN T.X = 0 THEN '' ELSE X.SSN END,
[DOB Day past 1900] = CASE WHEN T.X = 0 THEN 0 ELSE X.[DOB Day past 1900] END,
DOB = CASE WHEN T.X = 0 THEN CAST('1/1/1900' AS smalldatetime) ELSE X.DOB END,
P.[Role Mask],
P.[Active Role Mask],
Roles = '' -- Backward compatible
FROM vwPerson P
INNER JOIN TempX T ON T.BatchID = @batch_id AND T.[ID] = P.PersonID
INNER JOIN vwPersonX X ON P.PersonID = X.PersonID
LEFT JOIN Employee E ON P.PersonID = E.EmployeeID
ORDER BY P.[List As]

DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1
GO
ALTER  PROC dbo.spDepartmentGetDepartmentFromDepartmentID
	@department_id int,
	@department varchar(50) OUT
AS
SELECT @department = ''
SELECT @department = Department FROM Department WHERE DepartmentID = @department_id
GO
ALTER PROC dbo.spPersonListAsListItems
	@person_id int = NULL,
	@role_or_mask int = 0x7FFFFFFF,
	@role_and_mask int = 0,
	@role_not_mask int = 0,
	@active_role_or_mask int = 0,
	@active_role_and_mask int = 0,
	@active_role_not_mask int = 0,

	-- Pre V30 compatible
	@active bit = NULL,
	@role_mask int = NULL
AS
DECLARE @batch_id int

SET NOCOUNT ON

IF @active IS NOT NULL OR @role_mask IS NOT NULL
BEGIN
	SELECT @role_or_mask = @role_mask
	IF @active = 1 SET @active_role_or_mask = @role_mask
END

SELECT @batch_id = RAND() * 2147483647

INSERT TempX(BatchID, [ID])
SELECT @batch_id, PersonID FROM Person WHERE
(
	(@role_or_mask = 0 OR (@role_or_mask & [Role Mask]) > 0) AND
	(@role_and_mask = 0 OR (@role_and_mask & [Role Mask]) = @role_and_mask) AND
	((@role_not_mask & [Role Mask]) = 0) AND
	(@active_role_or_mask = 0 OR (@active_role_or_mask & [Active Role Mask]) > 0) AND
	(@active_role_and_mask = 0 OR (@active_role_and_mask & [Active Role Mask]) = @active_role_and_mask) AND
	((@active_role_not_mask & [Active Role Mask]) = 0)
	
) OR PersonID = @person_id

EXEC spPersonListAsListItems2 @batch_id
GO
CREATE PROC dbo.spPersonSelect2
	@person_id int
AS
DECLARE @batch_id int

SET NOCOUNT ON

SELECT @batch_id = RAND() * 2147483647

INSERT TempX(BatchID, [ID])
VALUES(@batch_id, @person_id)

EXEC spPersonListAsListItems2 @batch_id
GO
ALTER PROC dbo.spPersonFind
	@first_name varchar(50),
	@last_name varchar(50),
	@ssn varchar(50),
	@employee_number varchar(50),
	@dob int,
	@role_mask int = 1
AS
DECLARE @result int

SET NOCOUNT ON

SELECT @first_name = RTRIM(LTRIM(@first_name)), @last_name = RTRIM(LTRIM(@last_name))

SELECT @first_name = @first_name + '%' WHERE LEN(@first_name) > 0
SELECT @last_name = @last_name + '%' WHERE LEN(@last_name) > 0
EXEC @result = spSSNClean @ssn OUTPUT

IF @result != 0 EXEC spErrorRaise @result
ELSE
BEGIN
	DECLARE @batch_id int
	SET @batch_id = RAND() * 2147483647

	INSERT TempX(BatchID, [ID])
	SELECT TOP 20 @batch_id, P.PersonID
	FROM vwPerson P
	LEFT JOIN Employee E ON P.PersonID = E.EmployeeID
	LEFT JOIN PersonX X ON P.PersonID = X.PersonID
	WHERE 
	(@first_name = '' OR [First Name] LIKE @first_name) AND
	(@employee_number = '' OR [Employee Number] LIKE @employee_number) AND
	(@last_name = '' OR [Last Name] LIKE @last_name) AND
	(@ssn = '' OR [SSN] LIKE @ssn) AND
	(@dob IS NULL OR X.[DOB Day past 1900] = @dob) AND
	(@role_mask = 0x7FFFFFFF OR (@role_mask & P.[Role Mask]) != 0)
	ORDER BY P.[List As]

	EXEC spPermissionGetOnPeopleForCurrentUser2 @batch_id, 4

	EXEC spPersonListAsListItems2 @batch_id
END
GO
ALTER PROC dbo.spLeaveSummarizeUnused2
	@batch_id int,
	@type_id int,
	@day int,
	@authorized bit OUT
AS
DECLARE @plan_id int
DECLARE @month_seniority int
DECLARE @fmla_rate int
DECLARE @fmla_available int

SET NOCOUNT ON

EXEC spPermissionGetOnPeopleForCurrentUser2 @batch_id, 10003
DELETE TempX WHERE BatchID = @batch_id AND (X & 1) = 0
SELECT @authorized = CASE WHEN @@ROWCOUNT = 0 THEN 1 ELSE 0 END

-- Calculate Accumulated
SELECT EmployeeID = X.[ID],
[Accumulated Day] = ISNULL((
	SELECT MAX(U.[Day Past 1900]) FROM EmployeeLeaveUnused U WHERE U.[Day past 1900] <= @day AND U.EmployeeID = X.[ID] AND U.TypeID = @type_id
), 0),
[Accumulated] = 0,
[Available] = NULL,
[Limit Day] = NULL,
[Recent Day] = ISNULL((
	SELECT TOP 1 U.[Start Day past 1900] FROM EmployeeLeaveUsed U
	WHERE U.EmployeeID = X.[ID] AND U.[Start Day past 1900] > @day AND U.Status = 2 AND U.Seconds > 0
	ORDER BY U.[Start Day past 1900]
),
(
	SELECT TOP 1 U.[Start Day past 1900] FROM EmployeeLeaveUsed U
	WHERE U.EmployeeID = X.[ID] AND U.[Start Day past 1900] <= @day AND U.Status = 2 AND U.Seconds > 0
	ORDER BY U.[Start Day past 1900] DESC
)
),
Rolling = 0,
Recent = CAST('' AS varchar(80)),
[Month Seniority] = DATEDIFF(mm, [Seniority Begins Day past 1900], GETDATE()),
PlanID = (
	SELECT P.PlanID FROM EmployeeLeavePlan P WHERE P.EmployeeID = E.EmployeeID AND @day >= P.[Start Day past 1900] AND (P.[Stop Day past 1900] IS NULL OR @day <= P.[Stop Day past 1900])
)
INTO #U
FROM TempX X 
INNER JOIN Employee E ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID



DELETE TempX WHERE BatchID = @batch_id OR DATEDIFF(hh, Created, GETDATE()) > 1

UPDATE #U SET [Limit Day] = ISNULL((
	SELECT MIN(E.[Day Past 1900]) FROM vwEmployeeLeaveEarned E WHERE E.[Day past 1900] > @day AND E.EmployeeID = #U.EmployeeID AND E.TypeID = @type_id AND E.[Limit Adjustment] = 1
), 2147483647)

UPDATE #U SET Accumulated = U.Unused
FROM #U
INNER JOIN EmployeeLeaveUnused U ON U.EmployeeID = #U.EmployeeID AND U.TypeID = @type_id AND U.[Day past 1900] = #U.[Accumulated Day]

-- Calculate available
UPDATE #U SET Available = (
	SELECT MIN(U.Unused) FROM EmployeeLeaveUnused U WHERE U.EmployeeID = #U.EmployeeID AND U.TypeID = @type_id AND U.[Day past 1900] >= @day AND U.[Day past 1900] < #U.[Limit Day]
)
FROM #U

UPDATE #U SET Available = Accumulated WHERE Available IS NULL OR Available > Accumulated






-- Special case: rolling year (38914)

-- Identify which people have plans of this type that include rolling years as of day
UPDATE #U SET Rolling = R.Seconds FROM #U
INNER JOIN EmployeeLeavePlan EP ON #U.EmployeeID = EP.EmployeeID AND @day >= EP.[Start Day past 1900] AND (@day <= EP.[Stop Day past 1900] OR EP.[Stop Day past 1900] IS NULL)
INNER JOIN LeaveRate R ON R.TypeID = @type_id AND R.PeriodID = 38914 AND EP.PlanID = R.PlanID

-- #R holds available leave based on rolling accrual for a given employee over a variety of days (D)
CREATE TABLE #R(
	EmployeeID int,
	D int,
	Available int
)

CREATE UNIQUE INDEX R04132005 ON #R(EmployeeID, D) WITH IGNORE_DUP_KEY 

INSERT #R
SELECT #U.EmployeeID, @day, #U.Rolling FROM #U WHERE Rolling != 0

-- Employees with used leave, start day
INSERT #R
SELECT U.EmployeeID, U.[Start Day past 1900], #U.Rolling FROM EmployeeLeaveUsed U
INNER JOIN #U ON #U.Rolling != 0 AND U.EmployeeID = #U.EmployeeID AND U.[Start Day past 1900] BETWEEN @day AND (@day + 364) AND 
(U.[Advanced Type Mask] & @type_id) != 0 AND Status = 2

-- Employees with used leave, stop day
INSERT #R
SELECT U.EmployeeID, U.[Stop Day past 1900], #U.Rolling FROM EmployeeLeaveUsed U
INNER JOIN #U ON #U.Rolling != 0 AND U.EmployeeID = #U.EmployeeID AND U.[Stop Day past 1900] BETWEEN @day AND (@day + 364) AND 
(U.[Advanced Type Mask] & @type_id) != 0 AND Status = 2

-- Employees with negative earned leave adjustments
INSERT #R
SELECT E.EmployeeID, E.[Day Past 1900], #U.Rolling FROM EmployeeLeaveEarned E
INNER JOIN #U ON #U.Rolling != 0 AND E.Seconds < 0 AND E.[Day past 1900] BETWEEN @day AND (@day + 364) ANd E.TypeID = @type_id


UPDATE #R SET Available = Available - ISNULL((
	SELECT SUM(U.Seconds) FROM vwEmployeeLeaveUsedItemApproved U WHERE U.EmployeeID = #R.EmployeeID AND (U.[Extended Type Mask] & @type_id) != 0 AND U.[Day past 1900] BETWEEN (#R.D - 364) AND #R.D
), 0)

-- Updates #U based on #R
UPDATE #U SET Available = (
	SELECT MIN(Available) FROM #R WHERE #R.EmployeeID = #U.EmployeeID
), Accumulated = (
	SELECT Available FROM #R WHERE #R.EmployeeID = #U.EmployeeID AND #R.D = @day
)
WHERE Rolling != 0






-- Special case: rolling year (2049)

UPDATE #U SET Rolling = 0
DELETE #R

-- Identify which people have plans of this type that include rolling 24 months as of day
UPDATE #U SET Rolling = R.Seconds FROM #U
INNER JOIN EmployeeLeavePlan EP ON #U.EmployeeID = EP.EmployeeID AND @day >= EP.[Start Day past 1900] AND (@day <= EP.[Stop Day past 1900] OR EP.[Stop Day past 1900] IS NULL)
INNER JOIN LeaveRate R ON R.TypeID = @type_id AND R.PeriodID = 2049 AND EP.PlanID = R.PlanID
 

INSERT #R
SELECT #U.EmployeeID, @day, #U.Rolling FROM #U WHERE Rolling != 0

INSERT #R
SELECT U.EmployeeID, U.[Start Day past 1900], #U.Rolling FROM EmployeeLeaveUsed U
INNER JOIN #U ON #U.Rolling != 0 AND U.EmployeeID = #U.EmployeeID AND U.[Start Day past 1900] BETWEEN @day AND (@day + 729) AND 
(U.[Advanced Type Mask] & @type_id) != 0 AND Status = 2

INSERT #R
SELECT U.EmployeeID, U.[Stop Day past 1900], #U.Rolling FROM EmployeeLeaveUsed U
INNER JOIN #U ON #U.Rolling != 0 AND U.EmployeeID = #U.EmployeeID AND U.[Stop Day past 1900] BETWEEN @day AND (@day + 729) AND 
(U.[Advanced Type Mask] & @type_id) != 0 AND Status = 2

-- Employees with negative earned leave adjustments
INSERT #R
SELECT E.EmployeeID, E.[Day Past 1900], #U.Rolling FROM EmployeeLeaveEarned E
INNER JOIN #U ON #U.Rolling != 0 AND E.Seconds < 0 AND E.[Day past 1900] BETWEEN @day AND (@day + 364) ANd E.TypeID = @type_id


UPDATE #R SET Available = Available - ISNULL((
	SELECT SUM(U.Seconds) FROM vwEmployeeLeaveUsedItemApproved U WHERE U.EmployeeID = #R.EmployeeID AND (U.[Extended Type Mask] & @type_id) != 0 AND U.[Day past 1900] BETWEEN (#R.D - 729) AND #R.D
), 0)

-- Updates #U based on #R
UPDATE #U SET Available = (
	SELECT MIN(Available) FROM #R WHERE #R.EmployeeID = #U.EmployeeID
), Accumulated = (
	SELECT Available FROM #R WHERE #R.EmployeeID = #U.EmployeeID AND #R.D = @day
)
WHERE Rolling != 0




DECLARE @yy int, @ly int
SELECT @yy = YEAR(GETDATE())

DECLARE @this_year_start int, @this_year_stop int
DECLARE @last_year_start int, @last_year_stop int
DECLARE @rolling_start int, @rolling_stop int

SELECT @this_year_start = DATEDIFF(dd, 0, dbo.GetDateFromMDY(1, 1, @yy))
SELECT @this_year_stop = DATEDIFF(dd, 0, dbo.GetDateFromMDY(12, 31, @yy))

SELECT @ly = @yy - 1
SELECT @last_year_start = DATEDIFF(dd, 0, dbo.GetDateFromMDY(1, 1, @ly))
SELECT @last_year_stop = DATEDIFF(dd, 0, dbo.GetDateFromMDY(12, 31, @ly))

SELECT @rolling_start = DATEDIFF(dd, 0, DATEADD(yy, -1, GETDATE())) + 1
SELECT @rolling_stop = DATEDIFF(dd, 0, GETDATE())

DECLARE @rows int
SET @rows = 1

WHILE @rows > 0
BEGIN
	UPDATE #U SET Recent = SUBSTRING(
		Recent +
		CASE WHEN Recent = '' THEN '' ELSE ', ' END +
		CASE WHEN YEAR(dbo.GetDateFromDaysPast1900([Start Day past 1900])) = @yy THEN CAST(dbo.GetDateFromDaysPast1900([Start Day past 1900]) AS varchar(6))
		ELSE CAST(dbo.GetDateFromDaysPast1900([Start Day past 1900]) AS varchar(11)) END
		+
		CASE WHEN [Start Day past 1900] != [Stop Day past 1900] THEN ' to ' + CAST(dbo.GetDateFromDaysPast1900([Stop Day past 1900]) AS varchar(6))
		ELSE '' END,
		0, 80
	)
	, [Recent Day] = (
		SELECT TOP 1 [Start Day past 1900] FROM EmployeeLeaveUsed U2
		WHERE U2.EmployeeID = #U.EmployeeID AND U2.[Start Day past 1900] < #U.[Recent Day] AND U2.Status = 2 AND U2.Seconds > 0
		ORDER BY U2.[Start Day past 1900] DESC
	)
	FROM #U
	INNER JOIN EmployeeLeaveUsed U ON #U.[Recent Day] = U.[Start Day past 1900] AND #U.EmployeeID = U.EmployeeID AND LEN(Recent) < 80

	SET @rows = @@ROWCOUNT
END

-- Return results
SELECT
#U.EmployeeID,
#U.Recent,
Employee = P.[List As],
[Annualized Hrs] = CASE WHEN R.Seconds IS NULL THEN 0 ELSE R.Seconds * (2080.0 / R.[Seconds in Period]) END,
[Accumulated Hrs] = #U.Accumulated / 3600.0,
[Available Hrs] = #U.Available / 3600.0,
[Used Last Year Hrs] = ISNULL((
	SELECT SUM(I.Seconds) FROM vwEmployeeLeaveUsedItemApproved I WHERE
	I.EmployeeID = #U.EmployeeID AND (I.[Extended Type Mask] & @type_id) != 0 AND I.[Day past 1900] BETWEEN @last_year_start AND @last_year_stop
), 0) / 3600.0,
[Used This Year Hrs] = ISNULL((
	SELECT SUM(I.Seconds) FROM vwEmployeeLeaveUsedItemApproved I WHERE
	I.EmployeeID = #U.EmployeeID AND (I.[Extended Type Mask] & @type_id) != 0 AND I.[Day past 1900] BETWEEN @this_year_start AND @this_year_stop
), 0) / 3600.0,
[Used Rolling Year Hrs] = ISNULL((
	SELECT SUM(I.Seconds) FROM vwEmployeeLeaveUsedItemApproved I WHERE
	I.EmployeeID = #U.EmployeeID AND (I.[Extended Type Mask] & @type_id) != 0 AND I.[Day past 1900] BETWEEN @rolling_start AND @rolling_stop
), 0) / 3600.0,
[Scheduled Hrs] = ISNULL((
	SELECT SUM(I.Seconds) FROM vwEmployeeLeaveUsedItemApproved I WHERE
	I.EmployeeID = #U.EmployeeID AND (I.[Extended Type Mask] & @type_id) != 0 AND I.[Day past 1900] > @day
), 0) / 3600.0
FROM #U
LEFT JOIN vwLeaveRate R ON R.TypeID = @type_id AND R.PlanID = #U.PlanID AND #U.[Month Seniority] BETWEEN R.[Start Month] AND R.[Stop Month]
INNER JOIN vwPersonListAs P ON #U.EmployeeID = P.PersonID

ORDER BY P.[List As], #U.EmployeeID
GO

ALTER PROC dbo.spEmployeeCountBySection
	@manager bit,
	@department bit,
	@division bit,
	@location bit
AS
DECLARE @division_label varchar(50)

SET NOCOUNT ON

SELECT @division_label = [Division Label] FROM Constant

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
LEFT JOIN vwPersonListAs V 
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

SET NOCOUNT ON

DECLARE @authorized bit

EXEC spPermissionInsureForCurrentUserOnPerson @person_id, 2, 2, @authorized out
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
ALTER  PROC dbo.spEmployeeInsert
	@title varchar(50),
	@first_name varchar(50),
	@middle_name varchar(50),
	@last_name varchar(50),
	@suffix varchar(50),
	@credentials varchar(50),
	@person_id int OUT
AS
-- Inserts a person, personx, and employee. Intelligently guesses many default values based on either last entry or most frequently entered information.
DECLARE @result int

DECLARE @male bit
DECLARE @last_employee_id int

DECLARE @shift_id int
DECLARE @division_id int
DECLARE @department_id int
DECLARE @location_id int
DECLARE @plan_id int

DECLARE @race_id int
DECLARE @i9status_id int
DECLARE @marital_status_id int

DECLARE @salaried bit
DECLARE @ot_pay_multiplier numeric(9,4) 
DECLARE @holiday_pay_multiplier numeric(9,4)
DECLARE @weekend_pay_multiplier numeric(9,4) 
DECLARE @ot_basis tinyint

SET NOCOUNT ON

SELECT @result = 0, @male = 1

SELECT TOP 1 @last_employee_id = EmployeeID FROM Employee E
INNER JOIN Person P ON P.PersonID = E.EmployeeID
ORDER BY Created DESC

SELECT TOP 1 @male = [Male] FROM Person P
INNER JOIN Employee E ON P.PersonID = E.EmployeeID
GROUP BY Male ORDER BY COUNT(*) DESC


EXEC spPersonXInsertPrepare @race_id out, @i9status_id out, @marital_status_id out
EXEC spEmployeeClassifyPrepare @shift_id out, @division_id out, @department_id out, @location_id out

-- Employee
SELECT @shift_id = ShiftID, @division_id = DivisionID, @department_id = DepartmentID, @salaried = Salaried, @ot_pay_multiplier = [OT Pay Multiplier], @holiday_pay_multiplier = [Holiday Pay Multiplier], @weekend_pay_multiplier = [Weekend Pay Multiplier], @ot_basis = [OT Basis]
FROM Employee WHERE EmployeeID = @last_employee_id

IF @@ROWCOUNT = 0
BEGIN
	SELECT TOP 1 @shift_id = ShiftID FROM Shift
	SELECT TOP 1 @division_id = DivisionID FROM Division
	SELECT TOP 1 @department_id = DepartmentID FROM Department
	SELECT TOP 1 @location_id = LocationID FROM Location
	SELECT @salaried = 0, @ot_pay_multiplier = 1.5, @holiday_pay_multiplier = 1, @weekend_pay_multiplier = 1, @ot_basis = 0
END

BEGIN TRAN

INSERT Person(
Title, [First Name], [Middle Name], [Last Name], Suffix, Credentials,
Male,[Work Phone], [Toll Free Phone],
[Work Fax], [Work Address], [Work Address (cont.)], [Work City], [Work State], [Work ZIP], [Work Country], [Home Country]
) VALUES (
@title, @first_name, @middle_name, @last_name, @suffix, @credentials,
@male, '', '',
'','','','','','','',''
)

SELECT @person_id = @@IDENTITY, @result = @@ERROR

IF @result = 0 EXEC @result = spPersonXInsert @person_id, @race_id, @i9status_id, @marital_status_id
IF @result = 0 EXEC @result = spEmployeeClassify @person_id, @shift_id, @division_id, @department_id, @location_id, @salaried, @ot_pay_multiplier, @holiday_pay_multiplier, @weekend_pay_multiplier, @ot_basis
	

IF @result = 0
	COMMIT TRAN
ELSE IF @@TRANCOUNT > 0
	ROLLBACK TRAN


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


EXEC spPermissionInsureForCurrentUserOnPerson @employee_id, 0x1000000, 2, @authorized out

IF @authorized = 1
BEGIN
	BEGIN TRAN
	
	IF @authorized = 1 UPDATE Employee SET [Terminated Day past 1900] = @effective, [Reason for Termination] = @reason, Rehire = @rehire WHERE EmployeeID = @employee_id
	SELECT @compensation_id = LastCompensationID FROM Employee WHERE EmployeeID = @employee_id
	
	-- Close employee compensation
	IF @compensation = 1 AND NOT (@compensation_id IS NULL)
	BEGIN
		-- EXEC spPermissionInsureForCurrentUserOnPerson @employee_id, 1024, 2, @authorized out
		UPDATE EmployeeCompensation SET [Stop Day past 1900] = @effective WHERE CompensationID = @compensation_id AND [Stop Day past 1900] IS NULL
	END
	
	-- Inactivates
	IF @inactive = 1
	BEGIN
		-- EXEC spPermissionInsureForCurrentUserOnPerson @employee_id, 8, 2, @authorized out
		UPDATE Employee SET [Active Employee] = 0 WHERE EmployeeID = @employee_id
	END
	
	-- Closes leave plan
	IF @leave = 1 AND @authorized = 1
	BEGIN
		-- EXEC spPermissionInsureForCurrentUserOnPerson @employee_id, 128, 2, @authorized out
		
		DECLARE @recalc bit
	
		SET @recalc = 0
		DELETE EmployeeLeavePlan WHERE EmployeeID = @employee_id AND [Start Day past 1900] > @effective
		IF @@ROWCOUNT > 0 SET @recalc = 1
	
		DECLARE @plan_item_id int
		SELECT TOP 1 @plan_item_id = ItemID FROM EmployeeLeavePlan WHERE EmployeeID = @employee_id AND ([Stop Day past 1900] IS NULL OR [Stop Day past 1900] > @effective) ORDER BY [Start Day past 1900] DESC 
	
		IF @plan_item_id IS NOT NULL
		BEGIN
			UPDATE EmployeeLeavePlan SET [Stop Day past 1900] = @effective WHERE ItemID = @plan_item_id
			SET @recalc = 1
		END

		-- DELETE EmployeeLeaveUsedItem WHERE EmployeeID = @employee_id AND [Day past 1900] > @effective
		-- DELETE EmployeeLeaveEarned WHERE EmployeeID = @employee_id AND [Day past 1900] > @effective

		IF @recalc = 1 EXEC spEmployeeLeaveCalcForEmployee @employee_id, @effective
	END
	
	COMMIT TRAN
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
INNER JOIN vwPersonListAs P ON X.[ID] = P.PersonID AND X.BatchID = @batch_id ORDER BY P.[List As]
ELSE
SELECT [ID], X FROM TempX WHERE BatchID = @batch_id
GO
ALTER PROC dbo.spPersonInsert
	@title varchar(50),
	@first_name varchar(50),
	@middle_name varchar(50),
	@last_name varchar(50),
	@suffix varchar(50),
	@credentials varchar(50),
	@person_id int OUT
AS
DECLARE @result int

DECLARE @male bit
DECLARE @last_employee_id int



DECLARE @manager_id int
DECLARE @shift_id int
DECLARE @division_id int
DECLARE @department_id int
DECLARE @location_id int

DECLARE @plan_id int


SET NOCOUNT ON

SELECT @result = 0, @male = 1

SELECT TOP 1 @last_employee_id = EmployeeID FROM Employee E
INNER JOIN Person P ON P.PersonID = E.EmployeeID
ORDER BY Created DESC

SELECT TOP 1 @male = [Male] FROM Person P
INNER JOIN Employee E ON P.PersonID = E.EmployeeID
GROUP BY Male ORDER BY COUNT(*) DESC


-- Employee
SELECT @shift_id = ShiftID, @division_id = DivisionID, @department_id = DepartmentID, @manager_id = ManagerID, @location_id = LocationID
FROM Employee WHERE EmployeeID = @last_employee_id

IF @@ROWCOUNT = 0
BEGIN
	SELECT TOP 1 @shift_id = ShiftID FROM Shift
	SELECT TOP 1 @division_id = DivisionID FROM Division
	SELECT TOP 1 @department_id = DepartmentID FROM Department
	SELECT TOP 1 @location_id = LocationID FROM Location
END



BEGIN TRAN

INSERT Person(
Title, [First Name], [Middle Name], [Last Name], Suffix, Credentials,
Male,[Work Phone], [Toll Free Phone],
[Work Fax], [Work Address], [Work Address (cont.)], [Work City], [Work State], [Work ZIP], [Work Country],
[Role Mask]
) VALUES (
@title, @first_name, @middle_name, @last_name, @suffix, @credentials,
@male, '', '',
'','','','','','','',
1
)

SELECT @result = @@ERROR, @person_id = @@IDENTITY

IF @result = 0
BEGIN
	DECLARE @race_id int
	DECLARE @i9status_id int
	DECLARE @marital_status_id int


	EXEC spPersonXInsertPrepare @race_id out, @i9status_id out, @marital_status_id out
	EXEC @result = spPersonXInsert @person_id, @race_id, @i9status_id, @marital_status_id
	SELECT @result = @@ERROR
END

IF @result = 0
BEGIN
	INSERT Employee(EmployeeID, ManagerID, ShiftID, DivisionID, DepartmentID, LocationID)
	VALUES(@person_id, @manager_id, @shift_id, @division_id, @department_id, @location_id)
	SELECT @result = @@ERROR
END

IF @result = 0
	COMMIT TRAN
ELSE
	ROLLBACK TRAN
GO
CREATE PROC dbo.spPersonListPrepareBatchPOr
	@batch_id int,
	@field_id int, -- ColumnGrid.FieldID
	@operation int,
	@value sql_variant,
	@limit sql_variant
AS
DECLARE @t varchar(50)
DECLARE @i int
DECLARE @f bit
DECLARE @d datetime, @d2 datetime
DECLARE @x int, @y int
DECLARE @type sysname

SET NOCOUNT ON

SELECT @type = CAST(SQL_VARIANT_PROPERTY ( @value, 'BaseType' ) AS sysname), @t = null, @i= null, @f = null, @d = null, @d2 = null, @x = null, @y = null

IF @type IN ('varchar', 'nvarchar') SELECT @t = '%' + CAST(@value AS varchar(50)) + '%'
ELSE IF @type = 'int' SELECT @i = CAST(@value AS int)
ELSE IF @type = 'bit' SELECT @f = CAST(@value AS bit)
ELSE IF @type IN ('datetime', 'smalldatetime') SELECT @d = CAST(@value AS datetime)

IF @limit IS NOT NULL SET @d2 = CAST(@limit AS datetime)

SELECT @x = DATEDIFF(d, 0, @d), @y = DATEDIFF(d, 0, @d2)

-- Active Employee
IF @field_id = 71 INSERT TempX(BatchID, [ID])
SELECT @batch_id, E.EmployeeID FROM Employee E WHERE 
(@operation=0x200 AND E.[Active Employee] = 1) OR 
(@operation=0x400 AND E.[Active Employee] = 0)

-- PersonID
ELSE IF @field_id=1003 INSERT TempX(BatchID, [ID])
VALUES(@batch_id, @i)

-- Current Position 56
ELSE IF @field_id=56 INSERT TempX(BatchID, [ID])
SELECT @batch_id, E.EmployeeID FROM Employee E
INNER JOIN EmployeeCompensation EC ON E.LastCompensationID = EC.CompensationID
INNER JOIN Position P ON EC.PositionID = P.PositionID AND
(
	(@operation=1 AND EC.PositionID = @i) OR (@operation=2 AND EC.PositionID <> @i) OR
	(@operation=4 AND P.[Job Title] LIKE @t) OR (@operation=8 AND P.[Job Title] NOT LIKE @t)
)

-- Division 53
ELSE IF @field_id=53 INSERT TempX(BatchID, [ID])
SELECT @batch_id, E.EmployeeID FROM Employee E
INNER JOIN Division V ON E.DivisionID = V.DivisionID AND
(
	(@operation=1 AND E.DivisionID = @i) OR (@operation=2 AND E.DivisionID <> @i) OR
	(@operation=4 AND V.Division LIKE @t) OR (@operation=8 AND V.Division NOT LIKE @t)
)

-- Department 55
ELSE IF @field_id=55 INSERT TempX(BatchID, [ID])
SELECT @batch_id, E.EmployeeID FROM Employee E
INNER JOIN Department D ON E.DepartmentID = D.DepartmentID AND 
(
	(@operation=1 AND E.DepartmentID = @i) OR (@operation=2 AND E.DepartmentID <> @i) OR
	(@operation=4 AND D.Department LIKE @t) OR (@operation=8 AND D.Department NOT LIKE @t)
)

-- Employment Status 90
ELSE IF @field_id=90
INSERT TempX(BatchID, [ID])
SELECT @batch_id, E.EmployeeID FROM Employee E
INNER JOIN EmployeeComensation EC ON E.LastCompensationID = EC.CompensationID
INNER JOIN EmploymentStatus ES ON EC.EmploymentStatusID = ES.StatusID AND
(
	(@operation=1 AND EC.StatusID = @i) OR (@operation=2 AND EC.StatusID <> @i) OR
	(@operation=4 AND ES.Status LIKE @t) OR (@operation=8 AND ES.Status NOT LIKE @t)
)

-- Location 54
ELSE IF @field_id=54 INSERT TempX(BatchID, [ID])
SELECT @batch_id, E.EmployeeID FROM Employee E
INNER JOIN Location L ON E.LocationID = L.LocationID AND
(
	(@operation=1 AND E.LocationID = @i) OR (@operation=2 AND E.LocationID <> @i) OR
	(@operation=4 AND L.[List As] LIKE @t) OR (@operation=8 AND L.[List As] NOT LIKE @t)
)

-- Manager 52
ELSE IF @field_id=52
INSERT TempX(BatchID, [ID])
SELECT @batch_id, E.EmployeeID FROM Employee E
INNER JOIN vwPersonCalculated M ON E.ManagerID = M.PersonID AND
(
	(@operation=1 AND E.ManagerID = @i) OR (@operation=2 AND E.ManagerID <> @i) OR
	(@operation=4 AND M.[Full Name] LIKE @t) OR (@operation=8 AND M.[Full Name] NOT LIKE @t)
)

-- Note 16
ELSE IF @field_id=16
BEGIN
	INSERT TempX(BatchID, [ID])
	SELECT @batch_id, PersonID
	FROM Person P
	INNER JOIN Employee E ON P.PersonID = E.EmployeeID AND P.Note LIKE @t

	INSERT TempX(BatchID, [ID])
	SELECT DISTINCT @batch_id, EmployeeID
	FROM EmployeeCommunication WHERE Note LIKE @t
END

-- Position Status 91
ELSE IF @field_id=91
INSERT TempX(BatchID, [ID])
SELECT @batch_id, E.EmployeeID FROM Employee E
INNER JOIN EmployeeComensation EC ON E.LastCompensationID = EC.CompensationID
INNER JOIN Postion P ON EC.PositionID = P.PositionID
INNER JOIN PositionStatus PS ON P.PositionStatusID = PS.StatusID AND
(
	(@operation=1 AND P.StatusID = @i) OR (@operation=2 AND P.StatusID <> @i) OR
	(@operation=4 AND PS.Status LIKE @t) OR (@operation=8 AND PS.Status NOT LIKE @t)
)

-- Seniority Begins 58
ELSE IF @field_id = 58
INSERT TempX(BatchID, [ID])
SELECT @batch_id, EmployeeID FROM Employee E WHERE
(
	(@operation=1 AND E.[Seniority Begins Day past 1900] = @x) OR (@operation=2 AND E.[Seniority Begins Day past 1900] <> @x) OR
	(@operation=0x10 AND E.[Seniority Begins Day past 1900] BETWEEN @x AND @y) OR
	(@operation=0x80 AND E.[Seniority Begins Day past 1900] > @x) OR
	(@operation=0x100 AND E.[Seniority Begins Day past 1900] >= @x) OR
	(@operation=0x20 AND E.[Seniority Begins Day past 1900] < @x) OR
	(@operation=0x40 AND E.[Seniority Begins Day past 1900] <= @x)
)

-- Shift 51
ELSE IF @field_id=51
INSERT TempX(BatchID, [ID])
SELECT @batch_id, E.EmployeeID FROM Employee E
INNER JOIN Shift S ON E.ShiftID = S.ShiftID AND
(
	(@operation=1 AND E.ShiftID = @i) OR (@operation=2 AND E.ShiftID <> @i) OR
	(@operation=4 AND S.Shift LIKE @t) OR (@operation=8 AND S.Shift NOT LIKE @t)
)

-- Superior 1029
ELSE IF @field_id = 1029
INSERT TempX(BatchID, [ID])
SELECT DISTINCT @batch_id, ES.EmployeeID
FROM EmployeeSuperior ES
INNER JOIN vwPersonListAs P ON ES.SuperiorID = P.PersonID AND
(
	(@operation=1 AND ES.SuperiorID = @i) OR (@operation=2 AND ES.SuperiorID <> @i) OR
	(@operation=4 AND P.[List As] LIKE @t) OR (@operation=8 AND P.[List As] NOT LIKE @t)
)

-- Terminated 60
ELSE IF @field_id = 60
INSERT TempX(BatchID, [ID])
SELECT @batch_id, EmployeeID FROM Employee E WHERE
(
	(@operation=1 AND E.[Terminated Day past 1900] = @x) OR 
	(@operation=2 AND E.[Terminated Day past 1900] <> @x) OR
	(@operation=0x10 AND E.[Terminated Day past 1900] BETWEEN @x AND @y) OR
	(@operation=0x80 AND E.[Terminated Day past 1900] > @x) OR
	(@operation=0x100 AND E.[Terminated Day past 1900] >= @x) OR
	(@operation=0x20 AND E.[Terminated Day past 1900] < @x) OR
	(@operation=0x40 AND E.[Terminated Day past 1900] <= @x) OR
	(@operation=0x200 AND E.[Terminated Day past 1900] IS NOT NULL) OR
	(@operation=0x400 AND E.[Terminated Day past 1900] IS NULL)
)

-- COBRA 99
ELSE IF @field_id = 99
INSERT TempX(BatchID, [ID])
SELECT @batch_id, EmployeeID FROM vwEmployeeCOBRA E WHERE
(
	(@operation=1 AND @i=E.EnrollmentID) OR (@operation=2 AND @i<>E.EnrollmentID)
)
	
-- COBRA notified 94
ELSE IF @field_id = 94
INSERT TempX(BatchID, [ID])
SELECT @batch_id, EmployeeID FROM Employee E WHERE
(
	(@operation=1 AND E.[COBRA Notified Day past 1900] = @x) OR 
	(@operation=2 AND E.[COBRA Notified Day past 1900] <> @x) OR
	(@operation=0x10 AND E.[COBRA Notified Day past 1900] BETWEEN @x AND @y) OR
	(@operation=0x80 AND E.[COBRA Notified Day past 1900] > @x) OR
	(@operation=0x100 AND E.[COBRA Notified Day past 1900] >= @x) OR
	(@operation=0x20 AND E.[COBRA Notified Day past 1900] < @x) OR
	(@operation=0x40 AND E.[COBRA Notified Day past 1900] <= @x)
)

-- COBRA Eligible 93
ELSE IF @field_id = 93
INSERT TempX(BatchID, [ID])
SELECT @batch_id, EmployeeID FROM Employee E WHERE
(
	(@operation=1 AND E.[COBRA Eligible Day past 1900] = @x) OR 
	(@operation=2 AND E.[COBRA Eligible Day past 1900] <> @x) OR
	(@operation=0x10 AND E.[COBRA Eligible Day past 1900] BETWEEN @x AND @y) OR
	(@operation=0x80 AND E.[COBRA Eligible Day past 1900] > @x) OR
	(@operation=0x100 AND E.[COBRA Eligible Day past 1900] >= @x) OR
	(@operation=0x20 AND E.[COBRA Eligible Day past 1900] < @x) OR
	(@operation=0x40 AND E.[COBRA Eligible Day past 1900] <= @x)
)

-- COBRA Expires 98
ELSE IF @field_id = 98
INSERT TempX(BatchID, [ID])
SELECT @batch_id, EmployeeID FROM Employee E WHERE
(
	(@operation=1 AND E.[COBRA Expires Day past 1900] = @x) OR 
	(@operation=2 AND E.[COBRA Expires Day past 1900] <> @x) OR
	(@operation=0x10 AND E.[COBRA Expires Day past 1900] BETWEEN @x AND @y) OR
	(@operation=0x80 AND E.[COBRA Expires Day past 1900] > @x) OR
	(@operation=0x100 AND E.[COBRA Expires Day past 1900] >= @x) OR
	(@operation=0x20 AND E.[COBRA Expires Day past 1900] < @x) OR
	(@operation=0x40 AND E.[COBRA Expires Day past 1900] <= @x)
)

-- COBRA First Enrolled 95
ELSE IF @field_id = 95
INSERT TempX(BatchID, [ID])
SELECT @batch_id, EmployeeID FROM Employee E WHERE
(
	(@operation=1 AND E.[COBRA First Enrolled Day past 1900] = @x) OR 
	(@operation=2 AND E.[COBRA First Enrolled Day past 1900] <> @x) OR
	(@operation=0x10 AND E.[COBRA First Enrolled Day past 1900] BETWEEN @x AND @y) OR
	(@operation=0x80 AND E.[COBRA First Enrolled Day past 1900] > @x) OR
	(@operation=0x100 AND E.[COBRA First Enrolled Day past 1900] >= @x) OR
	(@operation=0x20 AND E.[COBRA First Enrolled Day past 1900] < @x) OR
	(@operation=0x40 AND E.[COBRA First Enrolled Day past 1900] <= @x)
)

-- COBRA Last Enrolled 96
ELSE IF @field_id = 96
INSERT TempX(BatchID, [ID])
SELECT @batch_id, EmployeeID FROM Employee E WHERE
(
	(@operation=1 AND E.[COBRA First Enrolled Day past 1900] = @x) OR 
	(@operation=2 AND E.[COBRA First Enrolled Day past 1900] <> @x) OR
	(@operation=0x10 AND E.[COBRA First Enrolled Day past 1900] BETWEEN @x AND @y) OR
	(@operation=0x80 AND E.[COBRA First Enrolled Day past 1900] > @x) OR
	(@operation=0x100 AND E.[COBRA First Enrolled Day past 1900] >= @x) OR
	(@operation=0x20 AND E.[COBRA First Enrolled Day past 1900] < @x) OR
	(@operation=0x40 AND E.[COBRA First Enrolled Day past 1900] <= @x)
)

-- COBRA Notified 93
ELSE IF @field_id = 93
INSERT TempX(BatchID, [ID])
SELECT @batch_id, EmployeeID FROM Employee E WHERE
(
	(@operation=1 AND E.[COBRA Notified Day past 1900] = @x) OR 
	(@operation=2 AND E.[COBRA Notified Day past 1900] <> @x) OR
	(@operation=0x10 AND E.[COBRA Notified Day past 1900] BETWEEN @x AND @y) OR
	(@operation=0x80 AND E.[COBRA Notified Day past 1900] > @x) OR
	(@operation=0x100 AND E.[COBRA Notified Day past 1900] >= @x) OR
	(@operation=0x20 AND E.[COBRA Notified Day past 1900] < @x) OR
	(@operation=0x40 AND E.[COBRA Notified Day past 1900] <= @x)
)
GO
CREATE PROC dbo.spPersonListPrepareBatchPAnd
	@batch_id int,
	@field_id int, -- ColumnGrid.FieldID
	@operation int,
	@value sql_variant,
	@limit sql_variant
AS
DECLARE @t varchar(50)
DECLARE @i int
DECLARE @f bit
DECLARE @d datetime, @d2 datetime
DECLARE @x int, @y int
DECLARE @type sysname

SET NOCOUNT ON

SELECT @type = CAST(SQL_VARIANT_PROPERTY ( @value, 'BaseType' ) AS sysname), @t = null, @i= null, @f = null, @d = null, @d2 = null, @x = null, @y = null

IF @type IN ('varchar', 'nvarchar') SELECT @t = '%' + CAST(@value AS varchar(50)) + '%'
ELSE IF @type = 'int' SELECT @i = CAST(@value AS int)
ELSE IF @type = 'bit' SELECT @f = CAST(@value AS bit)
ELSE IF @type IN ('datetime', 'smalldatetime') SELECT @d = CAST(@value AS datetime)

IF @limit IS NOT NULL SET @d2 = CAST(@limit AS datetime)

SELECT @x = DATEDIFF(d, 0, @d), @y = DATEDIFF(d, 0, @d2)

-- Active Employee
IF @field_id = 71 DELETE TempX FROM TempX X
INNER JOIN Employee E ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID AND
(
	(@operation=0x200 AND E.[Active Employee] = 0) OR 
	(@operation=0x400 AND E.[Active Employee] = 1)
)

-- PersonID
--ELSE IF @field_id=1003 INSERT TempX(BatchID, [ID])
--VALUES(@batch_id, @i)

-- Current Position 56
ELSE IF @field_id=56 DELETE TempX FROM TempX X
INNER JOIN Employee E ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID 
INNER JOIN EmployeeCompensation EC ON E.LastCompensationID = EC.CompensationID
INNER JOIN Position P ON EC.PositionID = P.PositionID AND
(
	(@operation=1 AND EC.PositionID <> @i) OR (@operation=2 AND EC.PositionID = @i) OR
	(@operation=4 AND P.[Job Title] NOT LIKE @t) OR (@operation=8 AND P.[Job Title] LIKE @t)
)

-- Division 53
ELSE IF @field_id=53 DELETE TempX FROM TempX X
INNER JOIN Employee E ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID
INNER JOIN Division V ON E.DivisionID = V.DivisionID AND
(
	(@operation=1 AND E.DivisionID <> @i) OR (@operation=2 AND E.DivisionID = @i) OR
	(@operation=4 AND V.Division NOT LIKE @t) OR (@operation=8 AND V.Division LIKE @t)
)

-- Department 55
ELSE IF @field_id=55 DELETE TempX FROM TempX X
INNER JOIN Employee E ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID 
INNER JOIN Department D ON E.DepartmentID = D.DepartmentID AND 
(
	(@operation=1 AND E.DepartmentID <> @i) OR (@operation=2 AND E.DepartmentID = @i) OR
	(@operation=4 AND D.Department NOT LIKE @t) OR (@operation=8 AND D.Department LIKE @t)
)

-- Employment Status 90
ELSE IF @field_id=90 DELETE TempX FROM TempX X
INNER JOIN Employee E ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID 
INNER JOIN EmployeeComensation EC ON E.LastCompensationID = EC.CompensationID
INNER JOIN EmploymentStatus ES ON EC.EmploymentStatusID = ES.StatusID AND
(
	(@operation=1 AND EC.StatusID <> @i) OR (@operation=2 AND EC.StatusID = @i) OR
	(@operation=4 AND ES.Status NOT LIKE @t) OR (@operation=8 AND ES.Status LIKE @t)
)

-- Location 54
ELSE IF @field_id=54 DELETE TempX FROM TempX X
INNER JOIN Employee E ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID
INNER JOIN Location L ON E.LocationID = L.LocationID AND
(
	(@operation=1 AND E.LocationID <> @i) OR (@operation=2 AND E.LocationID = @i) OR
	(@operation=4 AND L.[List As] NOT LIKE @t) OR (@operation=8 AND L.[List As] LIKE @t)
)

-- Manager 52
ELSE IF @field_id=52 DELETE TempX FROM TempX X
INNER JOIN Employee E ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID
INNER JOIN vwPersonCalculated M ON E.ManagerID = M.PersonID AND
(
	(@operation=1 AND E.ManagerID <> @i) OR (@operation=2 AND E.ManagerID = @i) OR
	(@operation=4 AND M.[Full Name] NOT LIKE @t) OR (@operation=8 AND M.[Full Name] LIKE @t)
)

-- Note 16
ELSE IF @field_id=16
BEGIN
	DELETE TempX WHERE BatchID = @batch_id AND [ID] NOT IN
	(
		SELECT PersonID
		FROM Person P
		INNER JOIN Employee E ON P.PersonID = E.EmployeeID AND P.Note LIKE @t
	
		UNION

		SELECT DISTINCT EmployeeID
		FROM EmployeeCommunication WHERE Note LIKE @t
	)
END

-- Position Status 91
ELSE IF @field_id=91 DELETE TempX FROM TempX X
INNER JOIN Employee E ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID 
INNER JOIN EmployeeComensation EC ON E.LastCompensationID = EC.CompensationID
INNER JOIN Postion P ON EC.PositionID = P.PositionID
INNER JOIN PositionStatus PS ON P.PositionStatusID = PS.StatusID AND
(
	(@operation=1 AND P.StatusID <> @i) OR (@operation=2 AND P.StatusID = @i) OR
	(@operation=4 AND PS.Status NOT LIKE @t) OR (@operation=8 AND PS.Status LIKE @t)
)

-- Seniority Begins 58
ELSE IF @field_id = 58 DELETE TempX FROM TempX X
INNER JOIN Employee E ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID AND
(
	(@operation=1 AND E.[Seniority Begins Day past 1900] <> @x) OR 
	(@operation=2 AND E.[Seniority Begins Day past 1900] = @x) OR
	(@operation=0x10 AND E.[Seniority Begins Day past 1900] NOT BETWEEN @x AND @y) OR
	(@operation=0x80 AND E.[Seniority Begins Day past 1900] <= @x) OR
	(@operation=0x100 AND E.[Seniority Begins Day past 1900] < @x) OR
	(@operation=0x20 AND E.[Seniority Begins Day past 1900] >= @x) OR
	(@operation=0x40 AND E.[Seniority Begins Day past 1900] > @x)
)

-- Shift 51
ELSE IF @field_id=51 DELETE TempX FROM TempX X
INNER JOIN Employee E ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID
INNER JOIN Shift S ON E.ShiftID = S.ShiftID AND
(
	(@operation=1 AND E.ShiftID <> @i) OR (@operation=2 AND E.ShiftID = @i) OR
	(@operation=4 AND S.Shift NOT LIKE @t) OR (@operation=8 AND S.Shift LIKE @t)
)

-- Superior 1029
ELSE IF @field_id = 1029 DELETE TempX FROM TempX X WHERE X.BatchID = @batch_id AND X.[ID] NOT IN
(
	SELECT EmployeeID FROM EmployeeSuperior ES
	INNER JOIN vwPersonListAs P ON ES.SuperiorID = P.PersonID AND
	(
		(@operation=1 AND ES.SuperiorID <> @i) OR (@operation=2 AND ES.SuperiorID = @i) OR
		(@operation=4 AND P.[List As] NOT LIKE @t) OR (@operation=8 AND P.[List As] LIKE @t)
	)
)

-- Terminated 60
ELSE IF @field_id = 60 DELETE TempX FROM TempX X
INNER JOIN Employee E ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID AND
(
	(@operation=1 AND E.[Terminated Day past 1900] <> @x) OR 
	(@operation=2 AND E.[Terminated Day past 1900] = @x) OR
	(@operation=0x10 AND E.[Terminated Day past 1900] NOT BETWEEN @x AND @y) OR
	(@operation=0x80 AND E.[Terminated Day past 1900] <= @x) OR
	(@operation=0x100 AND E.[Terminated Day past 1900] < @x) OR
	(@operation=0x20 AND E.[Terminated Day past 1900] >= @x) OR
	(@operation=0x40 AND E.[Terminated Day past 1900] > @x) OR
	(@operation=0x200 AND E.[Terminated Day past 1900] IS NULL) OR
	(@operation=0x400 AND E.[Terminated Day past 1900] IS NOT NULL)
)

-- COBRA 99
ELSE IF @field_id = 99 DELETE TempX FROM TempX X
INNER JOIN vwEmployeeCOBRA E ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID AND
(
	(@operation=1 AND @i<>E.EnrollmentID) OR (@operation=2 AND @i=E.EnrollmentID)
)
	
-- COBRA notified 94
ELSE IF @field_id = 94 DELETE TempX FROM TempX X
INNER JOIN Employee E ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID AND
(
	(@operation=1 AND E.[COBRA Notified Day past 1900] <> @x) OR 
	(@operation=2 AND E.[COBRA Notified Day past 1900] = @x) OR
	(@operation=0x10 AND E.[COBRA Notified Day past 1900] NOT BETWEEN @x AND @y) OR
	(@operation=0x80 AND E.[COBRA Notified Day past 1900] <= @x) OR
	(@operation=0x100 AND E.[COBRA Notified Day past 1900] < @x) OR
	(@operation=0x20 AND E.[COBRA Notified Day past 1900] >= @x) OR
	(@operation=0x40 AND E.[COBRA Notified Day past 1900] > @x)
)

-- COBRA Eligible 93
ELSE IF @field_id = 93 DELETE TempX FROM TempX X
INNER JOIN Employee E ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID AND
(
	(@operation=1 AND E.[COBRA Eligible Day past 1900] <> @x) OR 
	(@operation=2 AND E.[COBRA Eligible Day past 1900] = @x) OR
	(@operation=0x10 AND E.[COBRA Eligible Day past 1900] NOT BETWEEN @x AND @y) OR
	(@operation=0x80 AND E.[COBRA Eligible Day past 1900] <= @x) OR
	(@operation=0x100 AND E.[COBRA Eligible Day past 1900] < @x) OR
	(@operation=0x20 AND E.[COBRA Eligible Day past 1900] >= @x) OR
	(@operation=0x40 AND E.[COBRA Eligible Day past 1900] > @x)
)

-- COBRA Expires 98
ELSE IF @field_id = 98 DELETE TempX FROM TempX X
INNER JOIN Employee E ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID AND
(
	(@operation=1 AND E.[COBRA Expires Day past 1900] <> @x) OR 
	(@operation=2 AND E.[COBRA Expires Day past 1900] = @x) OR
	(@operation=0x10 AND E.[COBRA Expires Day past 1900] NOT BETWEEN @x AND @y) OR
	(@operation=0x80 AND E.[COBRA Expires Day past 1900] <= @x) OR
	(@operation=0x100 AND E.[COBRA Expires Day past 1900] < @x) OR
	(@operation=0x20 AND E.[COBRA Expires Day past 1900] >= @x) OR
	(@operation=0x40 AND E.[COBRA Expires Day past 1900] > @x)
)

-- COBRA First Enrolled 95
ELSE IF @field_id = 95
INSERT TempX(BatchID, [ID])
SELECT @batch_id, EmployeeID FROM Employee E WHERE
(
	(@operation=1 AND E.[COBRA First Enrolled Day past 1900] <> @x) OR 
	(@operation=2 AND E.[COBRA First Enrolled Day past 1900] = @x) OR
	(@operation=0x10 AND E.[COBRA First Enrolled Day past 1900] NOT BETWEEN @x AND @y) OR
	(@operation=0x80 AND E.[COBRA First Enrolled Day past 1900] <= @x) OR
	(@operation=0x100 AND E.[COBRA First Enrolled Day past 1900] < @x) OR
	(@operation=0x20 AND E.[COBRA First Enrolled Day past 1900] >= @x) OR
	(@operation=0x40 AND E.[COBRA First Enrolled Day past 1900] > @x)
)

-- COBRA Last Enrolled 96
ELSE IF @field_id = 96 DELETE TempX FROM TempX X
INNER JOIN Employee E ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID AND
(
	(@operation=1 AND E.[COBRA First Enrolled Day past 1900] <> @x) OR 
	(@operation=2 AND E.[COBRA First Enrolled Day past 1900] = @x) OR
	(@operation=0x10 AND E.[COBRA First Enrolled Day past 1900] NOT BETWEEN @x AND @y) OR
	(@operation=0x80 AND E.[COBRA First Enrolled Day past 1900] <= @x) OR
	(@operation=0x100 AND E.[COBRA First Enrolled Day past 1900] < @x) OR
	(@operation=0x20 AND E.[COBRA First Enrolled Day past 1900] >= @x) OR
	(@operation=0x40 AND E.[COBRA First Enrolled Day past 1900] > @x)
)

-- COBRA Notified 93
ELSE IF @field_id = 93 DELETE TempX FROM TempX X
INNER JOIN Employee E ON X.BatchID = @batch_id AND X.[ID] = E.EmployeeID AND
(
	(@operation=1 AND E.[COBRA Notified Day past 1900] <> @x) OR 
	(@operation=2 AND E.[COBRA Notified Day past 1900] = @x) OR
	(@operation=0x10 AND E.[COBRA Notified Day past 1900] NOT BETWEEN @x AND @y) OR
	(@operation=0x80 AND E.[COBRA Notified Day past 1900] <= @x) OR
	(@operation=0x100 AND E.[COBRA Notified Day past 1900] < @x) OR
	(@operation=0x20 AND E.[COBRA Notified Day past 1900] >= @x) OR
	(@operation=0x40 AND E.[COBRA Notified Day past 1900] > @x)
)
GO
CREATE PROC dbo.spPersonListPrepareBatchBOr
	@batch_id int,
	@benefit_id int,
	@field_id int,
	@operation int,
	@value sql_variant,
	@limit sql_variant
AS
DECLARE @t varchar(50)
DECLARE @i int
DECLARE @f bit
DECLARE @d datetime, @d2 datetime
DECLARE @x int, @y int
DECLARE @type sysname

SELECT @type = CAST(SQL_VARIANT_PROPERTY ( @value, 'BaseType' ) AS sysname), @t = null, @i= null, @f = null, @d = null, @d2 = null, @x = null, @y = null

IF @type IN ('varchar', 'nvarchar') SELECT @t = '%' + CAST(@value AS varchar(50)) + '%'
ELSE IF @type = 'int' SELECT @i = CAST(@value AS int)
ELSE IF @type = 'bit' SELECT @f = CAST(@value AS bit)
ELSE IF @type IN ('datetime', 'smalldatetime') SELECT @d = CAST(@value AS datetime)

IF @limit IS NOT NULL SET @d2 = CAST(@limit AS datetime)

SELECT @x = DATEDIFF(d, 0, @d), @y = DATEDIFF(d, 0, @d2)

-- Coverage = 1
IF @field_id = 1 INSERT TempX(BatchID, [ID])
SELECT DISTINCT @batch_id, EmployeeID FROM EmployeeBenefit EB WHERE EB.BenefitID = @benefit_id AND (
	(@operation = 4 AND EB.Coverage LIKE @t) OR
	(@operation = 8 AND EB.Coverage NOT LIKE @t)
)

-- Plan = 3,
ELSE IF @field_id = 3 INSERT TempX(BatchID, [ID])
SELECT DISTINCT @batch_id, EmployeeID FROM EmployeeBenefit EB WHERE EB.BenefitID = @benefit_id AND (
	(@operation = 4 AND EB.[Plan] LIKE @t) OR
	(@operation = 8 AND EB.[Plan] NOT LIKE @t)
)

-- Provider = 4,
ELSE IF @field_id = 4 INSERT TempX(BatchID, [ID])
SELECT DISTINCT @batch_id, EmployeeID FROM EmployeeBenefit EB WHERE EB.BenefitID = @benefit_id AND (
	(@operation = 4 AND EB.Provider LIKE @t) OR
	(@operation = 8 AND EB.Provider NOT LIKE @t)
)

-- Declined = 97,
ELSE IF @field_id = 97 INSERT TempX(BatchID, [ID])
SELECT DISTINCT @batch_id, EmployeeID FROM EmployeeBenefit EB WHERE EB.BenefitID = @benefit_id AND (
	(@operation=1 AND EB.[Declined Day past 1900] = @x) OR 
	(@operation=2 AND EB.[Declined Day past 1900] <> @x) OR
	(@operation=0x10 AND EB.[Declined Day past 1900] BETWEEN @x AND @y) OR
	(@operation=0x80 AND EB.[Declined Day past 1900] > @x) OR
	(@operation=0x100 AND EB.[Declined Day past 1900] >= @x) OR
	(@operation=0x20 AND EB.[Declined Day past 1900] < @x) OR
	(@operation=0x40 AND EB.[Declined Day past 1900] <= @x)
)

-- Eligible = 93,
ELSE IF @field_id = 93 INSERT TempX(BatchID, [ID])
SELECT DISTINCT @batch_id, EmployeeID FROM EmployeeBenefit EB WHERE EB.BenefitID = @benefit_id AND (
	(@operation=1 AND EB.[Eligible Day past 1900] = @x) OR 
	(@operation=2 AND EB.[Eligible Day past 1900] <> @x) OR
	(@operation=0x10 AND EB.[Eligible Day past 1900] BETWEEN @x AND @y) OR
	(@operation=0x80 AND EB.[Eligible Day past 1900] > @x) OR
	(@operation=0x100 AND EB.[Eligible Day past 1900] >= @x) OR
	(@operation=0x20 AND EB.[Eligible Day past 1900] < @x) OR
	(@operation=0x40 AND EB.[Eligible Day past 1900] <= @x)
)

-- Expires = 98,
ELSE IF @field_id = 98 INSERT TempX(BatchID, [ID])
SELECT DISTINCT @batch_id, EmployeeID FROM EmployeeBenefit EB WHERE EB.BenefitID = @benefit_id AND (
	(@operation=1 AND EB.[Expires Day past 1900] = @x) OR 
	(@operation=2 AND EB.[Expires Day past 1900] <> @x) OR
	(@operation=0x10 AND EB.[Expires Day past 1900] BETWEEN @x AND @y) OR
	(@operation=0x80 AND EB.[Expires Day past 1900] > @x) OR
	(@operation=0x100 AND EB.[Expires Day past 1900] >= @x) OR
	(@operation=0x20 AND EB.[Expires Day past 1900] < @x) OR
	(@operation=0x40 AND EB.[Expires Day past 1900] <= @x)
)

-- FirstEnrolled = 95,
ELSE IF @field_id = 95 INSERT TempX(BatchID, [ID])
SELECT DISTINCT @batch_id, EmployeeID FROM EmployeeBenefit EB WHERE EB.BenefitID = @benefit_id AND (
	(@operation=1 AND EB.[First Enrolled Day past 1900] = @x) OR 
	(@operation=2 AND EB.[First Enrolled Day past 1900] <> @x) OR
	(@operation=0x10 AND EB.[First Enrolled Day past 1900] BETWEEN @x AND @y) OR
	(@operation=0x80 AND EB.[First Enrolled Day past 1900] > @x) OR
	(@operation=0x100 AND EB.[First Enrolled Day past 1900] >= @x) OR
	(@operation=0x20 AND EB.[First Enrolled Day past 1900] < @x) OR
	(@operation=0x40 AND EB.[First Enrolled Day past 1900] <= @x)
)

-- LastEnrolled = 96,
ELSE IF @field_id = 96 INSERT TempX(BatchID, [ID])
SELECT DISTINCT @batch_id, EmployeeID FROM EmployeeBenefit EB WHERE EB.BenefitID = @benefit_id AND (
	(@operation=1 AND EB.[Last Enrolled Day past 1900] = @x) OR 
	(@operation=2 AND EB.[Last Enrolled Day past 1900] <> @x) OR
	(@operation=0x10 AND EB.[Last Enrolled Day past 1900] BETWEEN @x AND @y) OR
	(@operation=0x80 AND EB.[Last Enrolled Day past 1900] > @x) OR
	(@operation=0x100 AND EB.[Last Enrolled Day past 1900] >= @x) OR
	(@operation=0x20 AND EB.[Last Enrolled Day past 1900] < @x) OR
	(@operation=0x40 AND EB.[Last Enrolled Day past 1900] <= @x)
)

-- Notified = 94,
ELSE IF @field_id = 94 INSERT TempX(BatchID, [ID])
SELECT DISTINCT @batch_id, EmployeeID FROM EmployeeBenefit EB WHERE EB.BenefitID = @benefit_id AND (
	(@operation=1 AND EB.[Notified Day past 1900] = @x) OR 
	(@operation=2 AND EB.[Notified Day past 1900] <> @x) OR
	(@operation=0x10 AND EB.[Notified Day past 1900] BETWEEN @x AND @y) OR
	(@operation=0x80 AND EB.[Notified Day past 1900] > @x) OR
	(@operation=0x100 AND EB.[Notified Day past 1900] >= @x) OR
	(@operation=0x20 AND EB.[Notified Day past 1900] < @x) OR
	(@operation=0x40 AND EB.[Notified Day past 1900] <= @x)
)

-- EligibilityAndEnrollment = 99
ELSE IF @field_id = 99 INSERT TempX(BatchID, [ID])
SELECT DISTINCT @batch_id, EmployeeID FROM vwEmployeeBenefit EB WHERE EB.BenefitID = @benefit_id AND (
	(@operation=1 AND EB.EnrollmentID=@field_id) OR
	(@operation=2 AND EB.EnrollmentID<>@field_id)
)
GO
CREATE PROC dbo.spPersonListPrepareBatchBAnd
	@batch_id int,
	@benefit_id int,
	@field_id int,
	@operation int,
	@value sql_variant,
	@limit sql_variant
AS
DECLARE @t varchar(50)
DECLARE @i int
DECLARE @f bit
DECLARE @d datetime, @d2 datetime
DECLARE @x int, @y int
DECLARE @type sysname

SELECT @type = CAST(SQL_VARIANT_PROPERTY ( @value, 'BaseType' ) AS sysname), @t = null, @i= null, @f = null, @d = null, @d2 = null, @x = null, @y = null

IF @type IN ('varchar', 'nvarchar') SELECT @t = '%' + CAST(@value AS varchar(50)) + '%'
ELSE IF @type = 'int' SELECT @i = CAST(@value AS int)
ELSE IF @type = 'bit' SELECT @f = CAST(@value AS bit)
ELSE IF @type IN ('datetime', 'smalldatetime') SELECT @d = CAST(@value AS datetime)

IF @limit IS NOT NULL SET @d2 = CAST(@limit AS datetime)

SELECT @x = DATEDIFF(d, 0, @d), @y = DATEDIFF(d, 0, @d2)

-- Coverage = 1
IF @field_id = 1 DELETE TempX FROM TempX X 
INNER JOIN EmployeeBenefit EB ON X.BatchID = @batch_id AND X.[ID] = EB.EmployeeID AND (
	(@operation = 4 AND EB.Coverage NOT LIKE @t) OR
	(@operation = 8 AND EB.Coverage LIKE @t)
)

-- Plan = 3,
ELSE IF @field_id = 3 DELETE TempX FROM TempX X 
INNER JOIN EmployeeBenefit EB ON X.BatchID = @batch_id AND X.[ID] = EB.EmployeeID AND (
	(@operation = 4 AND EB.[Plan] NOT LIKE @t) OR
	(@operation = 8 AND EB.[Plan] LIKE @t)
)

-- Provider = 4,
ELSE IF @field_id = 4 DELETE TempX FROM TempX X 
INNER JOIN EmployeeBenefit EB ON X.BatchID = @batch_id AND X.[ID] = EB.EmployeeID AND (
	(@operation = 4 AND EB.Provider NOT LIKE @t) OR
	(@operation = 8 AND EB.Provider LIKE @t)
)

-- Declined = 97,
ELSE IF @field_id = 97 DELETE TempX FROM TempX X 
INNER JOIN EmployeeBenefit EB ON X.BatchID = @batch_id AND X.[ID] = EB.EmployeeID AND (
	(@operation=1 AND EB.[Declined Day past 1900] <> @x) OR 
	(@operation=2 AND EB.[Declined Day past 1900] = @x) OR
	(@operation=0x10 AND EB.[Declined Day past 1900] NOT BETWEEN @x AND @y) OR
	(@operation=0x80 AND EB.[Declined Day past 1900] <= @x) OR
	(@operation=0x100 AND EB.[Declined Day past 1900] < @x) OR
	(@operation=0x20 AND EB.[Declined Day past 1900] >= @x) OR
	(@operation=0x40 AND EB.[Declined Day past 1900] > @x)
)

-- Eligible = 93,
ELSE IF @field_id = 93 DELETE TempX FROM TempX X 
INNER JOIN EmployeeBenefit EB ON X.BatchID = @batch_id AND X.[ID] = EB.EmployeeID AND (
	(@operation=1 AND EB.[Eligible Day past 1900] <> @x) OR 
	(@operation=2 AND EB.[Eligible Day past 1900] = @x) OR
	(@operation=0x10 AND EB.[Eligible Day past 1900] NOT BETWEEN @x AND @y) OR
	(@operation=0x80 AND EB.[Eligible Day past 1900] <= @x) OR
	(@operation=0x100 AND EB.[Eligible Day past 1900] < @x) OR
	(@operation=0x20 AND EB.[Eligible Day past 1900] >= @x) OR
	(@operation=0x40 AND EB.[Eligible Day past 1900] > @x)
)

-- Expires = 98,
ELSE IF @field_id = 98 DELETE TempX FROM TempX X 
INNER JOIN EmployeeBenefit EB ON X.BatchID = @batch_id AND X.[ID] = EB.EmployeeID AND (
	(@operation=1 AND EB.[Expires Day past 1900] <> @x) OR 
	(@operation=2 AND EB.[Expires Day past 1900] = @x) OR
	(@operation=0x10 AND EB.[Expires Day past 1900] NOT BETWEEN @x AND @y) OR
	(@operation=0x80 AND EB.[Expires Day past 1900] <= @x) OR
	(@operation=0x100 AND EB.[Expires Day past 1900] < @x) OR
	(@operation=0x20 AND EB.[Expires Day past 1900] >= @x) OR
	(@operation=0x40 AND EB.[Expires Day past 1900] > @x)
)

-- FirstEnrolled = 95,
ELSE IF @field_id = 95 DELETE TempX FROM TempX X 
INNER JOIN EmployeeBenefit EB ON X.BatchID = @batch_id AND X.[ID] = EB.EmployeeID AND (
	(@operation=1 AND EB.[First Enrolled Day past 1900] <> @x) OR 
	(@operation=2 AND EB.[First Enrolled Day past 1900] = @x) OR
	(@operation=0x10 AND EB.[First Enrolled Day past 1900] NOT BETWEEN @x AND @y) OR
	(@operation=0x80 AND EB.[First Enrolled Day past 1900] <= @x) OR
	(@operation=0x100 AND EB.[First Enrolled Day past 1900] < @x) OR
	(@operation=0x20 AND EB.[First Enrolled Day past 1900] >= @x) OR
	(@operation=0x40 AND EB.[First Enrolled Day past 1900] > @x)
)

-- LastEnrolled = 96,
ELSE IF @field_id = 96 DELETE TempX FROM TempX X 
INNER JOIN EmployeeBenefit EB ON X.BatchID = @batch_id AND X.[ID] = EB.EmployeeID AND (
	(@operation=1 AND EB.[Last Enrolled Day past 1900] <> @x) OR 
	(@operation=2 AND EB.[Last Enrolled Day past 1900] = @x) OR
	(@operation=0x10 AND EB.[Last Enrolled Day past 1900] NOT BETWEEN @x AND @y) OR
	(@operation=0x80 AND EB.[Last Enrolled Day past 1900] <= @x) OR
	(@operation=0x100 AND EB.[Last Enrolled Day past 1900] < @x) OR
	(@operation=0x20 AND EB.[Last Enrolled Day past 1900] >= @x) OR
	(@operation=0x40 AND EB.[Last Enrolled Day past 1900] > @x)
)

-- Notified = 94,
ELSE IF @field_id = 94 DELETE TempX FROM TempX X 
INNER JOIN EmployeeBenefit EB ON X.BatchID = @batch_id AND X.[ID] = EB.EmployeeID AND (
	(@operation=1 AND EB.[Notified Day past 1900] <> @x) OR 
	(@operation=2 AND EB.[Notified Day past 1900] = @x) OR
	(@operation=0x10 AND EB.[Notified Day past 1900] NOT BETWEEN @x AND @y) OR
	(@operation=0x80 AND EB.[Notified Day past 1900] <= @x) OR
	(@operation=0x100 AND EB.[Notified Day past 1900] < @x) OR
	(@operation=0x20 AND EB.[Notified Day past 1900] >= @x) OR
	(@operation=0x40 AND EB.[Notified Day past 1900] > @x)
)

-- EligibilityAndEnrollment = 99
ELSE IF @field_id = 99 DELETE TempX FROM TempX X 
INNER JOIN vwEmployeeBenefit EB ON X.BatchID = @batch_id AND X.[ID] = EB.EmployeeID AND (
	(@operation=1 AND EB.EnrollmentID<>@field_id) OR
	(@operation=2 AND EB.EnrollmentID=@field_id)
)
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
VALUES(24, 2, OBJECT_ID(N'spBenefitPremiumUpdate'))

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(24, 4, OBJECT_ID(N'spBenefitInsert'))
INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(24, 4, OBJECT_ID(N'spTDRPInsert'))
INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(24, 4, OBJECT_ID(N'spTDRPMatchingInsert'))
INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(24, 4, OBJECT_ID(N'spBenefitPremiumInsert'))

INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(24, 8, OBJECT_ID(N'spTDRPMatchingDelete'))
INSERT PermissionObjectX(ObjectID, Permission, StoredProcID)
VALUES(24, 8, OBJECT_ID(N'spBenefitPremiumDelete'))

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

INSERT PermissionObject(ObjectID, Object, SelectObjectID, UpdateObjectID, InsertObjectID, DeleteObjectID, [Permission Possible Mask])
VALUES(42, 'Filters', 
0, 
OBJECT_ID(N'dbo.spFilterUpdate'), 
OBJECT_ID(N'dbo.spFilterInsert'), 
OBJECT_ID(N'dbo.spFilterDelete'),
14)
GO
EXEC spPermissionAssociateIDsForStoredProcsWithAffectedTable
GO
GRANT EXEC ON dbo.spPersonListPrepareBatchBOr TO public
GRANT EXEC ON dbo.spPersonListPrepareBatchBAnd TO public
GRANT EXEC ON dbo.spPersonListPrepareBatchPOr TO public
GRANT EXEC ON dbo.spPersonListPrepareBatchPAnd TO public
GRANT EXEC ON dbo.spPositionGetPositionFromPositionID TO public
GRANT EXEC ON dbo.spPersonSelect2 TO public
GRANT EXEC ON dbo.spPersonListAsListItems2 TO public
GRANT EXEC ON dbo.spTempXDelete TO public
GRANT EXEC ON dbo.spTempXList TO public
GRANT EXEC ON dbo.spFilterSelect TO public
GRANT EXEC ON dbo.spFilterList TO public
GO

UPDATE Constant SET [Server Version] = 32


