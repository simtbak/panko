--1. CREATE TEST TABLE 
use ebs
;IF OBJECT_ID('dbo.TEST','U') is not null DROP TABLE dbo.TEST
;IF OBJECT_ID('delta.TEST','U') is not null DROP TABLE delta.TEST
;IF OBJECT_ID('state.TEST','U') is not null DROP TABLE state.TEST
BEGIN
	SELECT 0 a, 0 b, 0 c into dbo.TEST
	insert into dbo.TEST SELECT 0 a, 0 b, 0 c 
	insert into dbo.TEST SELECT 0 a, 0 b, 0 c
END 
SELECT '=========================================', 'FIRST CREATE A TEST TABLE' NOTE
SELECT * FROM dbo.TEST

GO 
SELECT '=========================================', 'BREADCRUMB IT (A PRIMARY KEY WILL BE CREATED)' NOTE
EXEC [tsc].[Breadcrumb] 'dbo', 'test'

GO
		SELECT '=========================================', 'THE BREADCRUMB CREATED TWO TABLES State and Change (or [delta])' NOTE
UNION ALL SELECT '=========================================', 'THESE ARE COMBINED IN THE [report] VIEW ' NOTE
UNION ALL SELECT '=========================================', 'THE TABLE''S ORIGINAL COLUMNS ARE AFTER [AUTHOR]:' NOTE
SELECT * FROM report.TEST

GO --3. UPDATE TEST TABLE AND CHECK BREADCRUMBS
		SELECT '=========================================', 'WHEN WE UPDATE THE ORIGINAL TABLE ' NOTE
UNION ALL SELECT '=========================================', 'WE CAN SEE HOW IT CHANGES:' NOTE
UPDATE dbo.TEST set a = 1  WHERE AutoId = 1
SELECT * FROM report.TEST
GO
		SELECT '=========================================', 'HERE IS ANOTHER UPDATE ' NOTE
UPDATE dbo.TEST set a = 2 WHERE AutoId = 1 
SELECT * FROM report.TEST

/*
SELECT * FROM dbo.TEST
SELECT * FROM state.TEST
SELECT * FROM delta.TEST
--*/