-- average logical reads per minute, estimated from query stats
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @cpu_count int;

SELECT 
	@cpu_count = cpu_count
FROM sys.dm_os_sys_info
OPTION (RECOMPILE);

;WITH query_stats AS (
	SELECT
		DB_NAME(st.dbid) as db,
		qs.execution_count,
		qs.total_logical_reads / ISNULL(NULLIF(DATEDIFF(minute, qs.creation_time, qs.last_execution_time), 0), 1) as logical_reads,
		qs.total_physical_reads / ISNULL(NULLIF(DATEDIFF(minute, qs.creation_time, qs.last_execution_time), 0), 1) as physical_reads,
		qs.total_worker_time / ISNULL(NULLIF(DATEDIFF(minute, qs.creation_time, qs.last_execution_time), 0), 1) as worker_time,
		qs.total_rows / ISNULL(NULLIF(DATEDIFF(minute, qs.creation_time, qs.last_execution_time), 0), 1) as row_count,
		qs.creation_time, 
		qs.last_execution_time, 
		qs.execution_count / ISNULL(NULLIF(DATEDIFF(minute, qs.creation_time, qs.last_execution_time), 0), 1) AS executions,
		qs.total_elapsed_time / ISNULL(NULLIF(DATEDIFF(minute, qs.creation_time, qs.last_execution_time), 0), 1) as elapsed_time
	FROM sys.dm_exec_query_stats qs
	CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) st
	--AND st.dbid = DB_ID() -- only the current database
)
SELECT 
	db,
	SUM(execution_count) as execution_count,
	CAST((CAST(SUM(logical_reads) as bigint) * 8192.0) / 1024 / 1024 as decimal(20, 2)) as logical_reads_mb,
	CAST((CAST(SUM(physical_reads) as bigint) * 8192.0) / 1024 / 1024 as decimal(20, 2)) as physical_reads_mb,
	CAST(SUM(worker_time) / 1000.0 / 1000 / 60 as decimal(20, 2)) as worker_time_min,
	CAST(SUM(worker_time) / 1000.0 / 1000 / 60 / @cpu_count as decimal(20, 2)) as worker_time_min_per_cpu,
	SUM(row_count) as row_count,
	MIN(creation_time) as creation_time, 
	MAX(last_execution_time) as last_execution_time, 
	SUM(executions) as executions,
	CAST(SUM(elapsed_time) / 1000.0 / 1000 / 60 as decimal(20, 2)) as elapsed_time_min,
	CAST(SUM(elapsed_time) / 1000.0 / 1000 / 60 / @cpu_count as decimal(20, 2)) as elapsed_time_min_per_cpu
FROM query_stats
GROUP BY db
OPTION (RECOMPILE);