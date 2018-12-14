




local event = require "event"
local mysql_core = require "luasql.mysql"
local mysql_core = mysql_core.mysql()
local CREATE_TABLE_TEST2_TBL = [[
CREATE TABLE IF NOT EXISTS `test2_tbl`(
   `id` INT UNSIGNED AUTO_INCREMENT,
   `title` VARCHAR(100) NOT NULL,
   `author` VARCHAR(40) NOT NULL,
   `submission_date` DATE,
   PRIMARY KEY ( `id` )
)ENGINE=InnoDB DEFAULT CHARSET=utf8;
]]

local ALTER_TABLE_TEST2_TBL = [[
-- ALTER TABLE test2_tbl ADD COLUMN `name` VARCHAR(40) NOT NULL;
ALTER TABLE test2_tbl ADD COLUMN `level` int(10) DEFAULT '0' COMMENT "等级";
]]
local mysql,err = mysql_core:connect("test","root","2444cc818a3bbc06","127.0.0.1",3306)
print(mysql,err)
-- table.print(mysql:execute(CREATE_TABLE_TEST2_TBL))
table.print(mysql:execute(ALTER_TABLE_TEST2_TBL))
-- for i = 1, 1024 * 100 do
-- 	mysql:execute("insert into test2_tbl (title,submission_date) values (\"mrq\",123456)")
-- end

-- local cursor = mysql:execute("select * from test2_tbl")

-- local row = cursor:fetch ({}, "a")	-- the rows will be indexed by field names
-- while row do
-- 	print("1111111111111")
-- 	table.print(row)
--   row = cursor:fetch (row, "a")	-- reusing the table of results
-- end

-- -- table.print(mysql:execute("insert into test1_tbl (title) values (\"mrq\")"))

-- -- table.print(mysql:execute("update test1_tbl set title='mrq1',submission_date = 18-03-20 where id = 1"))

-- table.print(mysql:execute("select * from test1_tbl where id = 1"))
