#!/usr/bin/env -S tarantool --script
local test = require("sqltester")
test:plan(3)

--!./tcltestrunner.lua
-- 2014-02-25
--
-- The author disclaims copyright to this source code.  In place of
-- a legal notice, here is a blessing:
--
--    May you do good and not evil.
--    May you find forgiveness for yourself and forgive others.
--    May you share freely, never taking more than you give.
--
-------------------------------------------------------------------------
--
-- Test cases to show that ticket [8c63ff0eca81a9132d8d67b31cd6ae9712a2cc6f]
-- "Incorrect query result on a UNION ALL" which was caused by using the same
-- temporary register in concurrent co-routines, as been fixed.
--
-- ["set","testdir",[["file","dirname",["argv0"]]]]
-- ["source",[["testdir"],"\/tester.tcl"]]
test:do_execsql_test(
    1.1,
    [[
        CREATE TABLE t1(a INTEGER PRIMARY KEY, b INT, c INT, d INT, e INT);
        INSERT INTO t1 VALUES(1,20,30,40,50),(3,60,70,80,90);
        CREATE TABLE t2(x INTEGER PRIMARY KEY);
        INSERT INTO t2 VALUES(2);
        CREATE TABLE t3(id INT primary key, z INT);
        INSERT INTO t3 VALUES(1, 2),(2, 2),(3, 2),(4, 2);

        SELECT a, b+c FROM t1
        UNION ALL
        SELECT x, 5 FROM t2 JOIN t3 ON z=x WHERE x=2
        ORDER BY a;
    ]], {
        -- <1.1>
        1, 50, 2, 5, 2, 5, 2, 5, 2, 5, 3, 130
        -- </1.1>
    })

test:do_execsql_test(
    1.2,
    [[
        SELECT a, b+c+d FROM t1
        UNION ALL
        SELECT x, 5 FROM t2 JOIN t3 ON z=x WHERE x=2
        ORDER BY a;
    ]], {
        -- <1.2>
        1, 90, 2, 5, 2, 5, 2, 5, 2, 5, 3, 210
        -- </1.2>
    })

test:do_execsql_test(
    1.3,
    [[
        SELECT a, b+c+d+e FROM t1
        UNION ALL
        SELECT x, 5 FROM t2 JOIN t3 ON z=x WHERE x=2
        ORDER BY a;
    ]], {
        -- <1.3>
        1, 140, 2, 5, 2, 5, 2, 5, 2, 5, 3, 300
        -- </1.3>
    })

test:finish_test()

