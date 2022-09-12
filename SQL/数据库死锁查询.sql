
DECLARE @spid INT
DECLARE @blk INT
DECLARE @count INT
DECLARE @index INT
DECLARE @lock TINYINT
 
SET @lock=0
 
CREATE TABLE #temp_who_lock(id INT IDENTITY(1, 1), spid INT, blk INT)
 
--if @@error<>0 return @@error    
INSERT INTO #temp_who_lock (spid, blk)
SELECT 0,blocked
FROM (SELECT * FROM master..sysprocesses WHERE  blocked > 0) AS A
WHERE NOT EXISTS(SELECT * FROM master..sysprocesses WHERE  a.blocked = spid AND blocked > 0)
UNION
SELECT spid,blocked FROM   master..sysprocesses WHERE  blocked > 0
 
SELECT @count = Count(*),@index = 1 FROM   #temp_who_lock
 
 
IF @count = 0
  BEGIN
      SELECT N'没有阻塞和死锁信息'   
  END
 
WHILE @index <= @count
  BEGIN
      IF 
		EXISTS(SELECT 1 FROM #temp_who_lock a WHERE id > @index AND EXISTS(SELECT 1 FROM #temp_who_lock WHERE id <= @index AND a.blk = spid))
        BEGIN
            SET @lock=1
 
            SELECT @spid = spid,@blk = blk FROM #temp_who_lock WHERE  id = @index
			 
            SELECT  N'引起数据库死锁的是: ' + Cast(@spid AS VARCHAR(10)) + '进程号,其执行的SQL语法如下' ;
 
            SELECT @spid,@blk
 
            DBCC inputbuffer(@spid)

            DBCC inputbuffer(@blk)
        END 
      SET @index=@index + 1
  END
 
IF @lock = 0
  BEGIN
      SET @index=1
 
      WHILE @index <= @count
        BEGIN
            SELECT @spid = spid, @blk = blk FROM   #temp_who_lock WHERE  id = @index
 
            IF @spid = 0
              SELECT N'引起阻塞的是:' + Cast(@blk AS VARCHAR(10)) + '进程号,其执行的SQL语法如下' 
            ELSE
              SELECT N'进程号SPID：' + Cast(@spid AS VARCHAR(10)) + '被' + '进程号SPID：' + Cast(@blk AS VARCHAR(10)) + '阻塞,其当前进程执行的SQL语法如下'
 
            PRINT ( LTRIM(@spid) + ''+ LTRIM(@blk));
            if(@spid <> 0)
            BEGIN
               DBCC inputbuffer(@spid)   --
             END
 
            DBCC inputbuffer(@blk)   --引起阻塞语句
			 
            SET @index=@index + 1
        END
  END
   
DROP TABLE #temp_who_lock