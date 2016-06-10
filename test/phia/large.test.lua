#!/usr/bin/env tarantool

test_run = require('test_run').new()
large = require('large')

tuple_cnt = large.large(500, 10)
large.check(tuple_cnt)

test_run:cmd('restart server default')

large = require('large')
large.check()

