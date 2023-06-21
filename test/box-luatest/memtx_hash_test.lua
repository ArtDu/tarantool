local server = require('luatest.server')
local t = require('luatest')

local g = t.group()

g.before_all(function(cg)
    cg.server = server:new()
    cg.server:start()
end)

g.after_all(function(cg)
    cg.server:drop()
end)

g.test_insert_int_to_double = function(cg)
    cg.server:exec(function ()
        local ffi = require('ffi')

        local s = box.schema.space.create('s')
        s:create_index('s_idx', {type='HASH', parts={1, 'double'}, unique=true})

        -- For double-typed key we cast it to double before hashing.
        -- So 1 and 1.0 are interpret as the same value.
        local int_1 = 1
        local double_1 = ffi.new('double', 1.0)
        local errdup = 'Duplicate key exists in unique index "s_idx" in space '
                       ..'"s" with old tuple - '

        -- Ok, new integer (1).
        s:insert({int_1})

        -- Fail, duplicate of 1.
        t.assert_error_msg_contains(errdup, s.insert, s, {double_1})

        -- Select the integer.
        t.assert_equals(s:select({double_1}), {{int_1}});

        -- 2 ** 63 - 1 can't be directly converted to double,
        -- it becomes 2 ** 63 on cast.
        local int_2e63_minus_1 = 0x7fffffffffffffffULL
        local double_2e63 = ffi.new('double', int_2e63_minus_1)

        -- Successfully insert the integer into the double field.
        s:insert({int_2e63_minus_1})

        -- Insert of double-casted integer should fail since it's recognized as
        -- a duplicate of the integer inserted above (despite the fact that
        -- integer is not exactly equal to the resulting double, it becomes
        -- equal on cast to double in index).
        t.assert_error_msg_contains(errdup, s.insert, s, {double_2e63})

        -- Select of the double should retrieve the inserted integer.
        t.assert_equals(s:select({double_2e63}), {{int_2e63_minus_1}})

        s:drop()
    end)
end
