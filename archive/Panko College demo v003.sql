USE ebs 
GO
/*--
	CHECK IF DEMO OBJECTS EXIST, IF YES, DROP THEM
--*/
;IF OBJECT_ID('dbo.RegisterGrid','V') is not null DROP VIEW dbo.RegisterGrid
;IF OBJECT_ID('dbo.Students'	,'U') is not null DROP TABLE dbo.Students
;IF OBJECT_ID('dbo.Courses'		,'U') is not null DROP TABLE dbo.Courses	
;IF OBJECT_ID('dbo.Enrolments'	,'U') is not null DROP TABLE dbo.Enrolments
;IF OBJECT_ID('dbo.Registers'	,'U') is not null DROP TABLE dbo.Registers

;IF OBJECT_ID('delta.Students'	,'U') is not null DROP TABLE delta.Students
;IF OBJECT_ID('delta.Courses'	,'U') is not null DROP TABLE delta.Courses	
;IF OBJECT_ID('delta.Enrolments','U') is not null DROP TABLE delta.Enrolments
;IF OBJECT_ID('delta.Registers'	,'U') is not null DROP TABLE delta.Registers

;IF OBJECT_ID('state.Students'	,'U') is not null DROP TABLE state.Students
;IF OBJECT_ID('state.Courses'	,'U') is not null DROP TABLE state.Courses	
;IF OBJECT_ID('state.Enrolments','U') is not null DROP TABLE state.Enrolments
;IF OBJECT_ID('state.Registers'	,'U') is not null DROP TABLE state.Registers

/*--
	CREATE DEMO TABLES 
--*/

CREATE TABLE dbo.Students ( 
	 id int PRIMARY KEY IDENTITY(1001,1)
	,name varchar(50)
)

CREATE TABLE dbo.Courses ( 
	 id int PRIMARY KEY IDENTITY(2001,1)
	,name varchar(50)
)

CREATE TABLE dbo.Enrolments ( 
	 id int PRIMARY KEY IDENTITY(3001,1)
	,student_id int
	,course_id int
	,startdate	date
	,enddate	date
	,status varchar(10)
)

CREATE TABLE dbo.Registers (
	 id int PRIMARY KEY IDENTITY(4001,1)
	,enrolment_id int
	,startdate date
	,mark char(1)
)

GO

/*--
	CREATE DEMO VIEW
--*/

CREATE VIEW dbo.RegisterGrid AS 
SELECT
	 crs.name		Course
	,stu.name		Studen
	,reg.id			RegisterId
	,reg.startdate	ClassStarted
	,reg.mark		RegisterMark
	,enr.status		EnrolmentStatus

FROM dbo.Registers			reg
INNER JOIN dbo.Enrolments	enr	on	reg.enrolment_id = enr.id
INNER JOIN dbo.Students		stu	on	enr.student_id = stu.id
INNER JOIN dbo.Courses		crs	on	enr.course_id = crs.id

GO

/*--
	POPULATE DATA 
--*/

INSERT INTO dbo.Courses(name) SELECT 't-SQL Entry level 3'

INSERT INTO dbo.Students(name) SELECT 'Simeon'
INSERT INTO dbo.Students(name) SELECT 'Richard'

INSERT INTO dbo.Enrolments(student_id,course_id,status,startdate,enddate) SELECT 1001,2001,'Active','01-Apr-2020','31-May-2020'
INSERT INTO dbo.Enrolments(student_id,course_id,status,startdate,enddate) SELECT 1002,2001,'Active','01-Apr-2020','31-May-2020'

INSERT INTO dbo.Registers(enrolment_id,startdate,mark) 
			SELECT 3001, dateadd(week,-2,GETDATE()), '/'
UNION ALL	SELECT 3001, dateadd(week,-1,GETDATE()), '/'
UNION ALL	SELECT 3001, dateadd(week,0,GETDATE()), 'O'
UNION ALL	SELECT 3001, dateadd(week,1,GETDATE()), 'O'
UNION ALL	SELECT 3002, dateadd(week,-2,GETDATE()),'L'
UNION ALL	SELECT 3002, dateadd(week,-1,GETDATE()),'L'
UNION ALL	SELECT 3002, dateadd(week,0,GETDATE()), 'L'
UNION ALL	SELECT 3002, dateadd(week,1,GETDATE()), 'L'

GO

/*--
	BREADCRUMB TABLES
--*/

--EXEC tsc.Breadcrumb 'dbo','Students'
--EXEC tsc.Breadcrumb 'dbo','Courses'
EXEC tsc.Breadcrumb 'dbo','Enrolments'
--EXEC tsc.Breadcrumb 'dbo','Registers'

	--ARTIFICIALLY TRAVEL BACK IN TIME
	--UPDATE delta.Students	SET ActiveFrom = '01-Apr-2020'
	--UPDATE delta.Enrolments SET ActiveFrom = '01-Apr-2020'
	--UPDATE delta.Registers	SET ActiveFrom = '01-Apr-2020'
	--UPDATE delta.Courses	SET ActiveFrom = '01-Apr-2020'
GO

SELECT * FROM report.Enrolments
/*--
	DATA HAS BEEN ALTERED
--*/
GO
WAITFOR DELAY '00:00:01';
UPDATE dbo.Enrolments SET status = 'Withdrawn', enddate = GETDATE() WHERE id = 3001 
WAITFOR DELAY '00:00:01';
GO

declare @Perspective as datetime;
declare @scopeend	as date = '01/01/3000';

SELECT 
	 crs.name			Course
	,stu.name			Student
	,reg.id				RegisterId
	,reg.startdate		ClassStarted
	,reg.mark			RegisterMark
	,enr.status			EnrolmentStatus
	,enr.Step			EnrolmentStep
	,enr.ActiveFrom		EnrolmentChangeStart
	,enr.ActiveTo		EnrolmentChangeEnd
	,enr.startdate
	,enr.enddate

FROM dbo.Registers			reg
INNER JOIN report.Enrolments	enr	on	reg.enrolment_id = enr.id
INNER JOIN dbo.Students		stu	on	enr.student_id = stu.id
INNER JOIN dbo.Courses		crs	on	enr.course_id = crs.id

WHERE reg.startdate	between 
					CASE WHEN enr.status = 'Active'		and enr.ActiveFrom	> enr.startdate	THEN enr.startdate	ELSE enr.ActiveFrom END 
				and	isnull(enr.ActiveTo,@scopeend) --enr.enddate) 
				--and	CASE WHEN enr.ActiveTo > enr.enddate	THEN enr.enddate ELSE isnull(enr.ActiveTo,enr.enddate) END
				----CASE WHEN enr.status = 'Withdrawn'	and enr.ActiveTo	< enr.enddate	THEN enr.enddate	ELSE enr.ActiveTo	END

ORDER BY Student, ClassStarted 

GO

UPDATE dbo.Enrolments SET status = 'Active', enddate = '2020-05-31' WHERE id = 3001 
GO
SELECT * FROM state.Enrolments