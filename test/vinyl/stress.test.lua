#!/usr/bin/env -S tarantool --script

test_run = require('test_run').new()

require('stress').stress(10)

test_run:cmd('restart server default')

require('stress').stress(10)

test_run:cmd('restart server default')
