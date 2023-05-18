local server = require('luatest.server')
local t = require('luatest')

local g = t.group()

g.before_all(function(cg)
    cg.server_default = server:new({
        box_cfg = { memtx_use_mvcc_engine = false }
    })
    cg.server_default:start()
    cg.server_mvcc = server:new({
        box_cfg = { memtx_use_mvcc_engine = true }
    })
    cg.server_mvcc:start()
end)

g.after_all(function(cg)
    cg.server_default:drop()
    cg.server_mvcc:drop()
end)

local function test_transactional_ddl(engine)
    ----------------------------------------------------------------------------
    -- box.schema.space.create -------------------------------------------------
    ----------------------------------------------------------------------------

    local value
    local step0_size = 9999 -- More than 1k to ensure yielding.
    local txn_engine = box.cfg.memtx_use_mvcc_engine and 'mvcc' or 'default'
    local prefix = debug.getinfo(0, "n").name..'_'..txn_engine..'_'..engine..'_'
    local s_name_initial = prefix..'test'
    local s_name_new = s_name_initial..'_new'
    local s = box.schema.space.create(s_name_initial)
    local fs1 = box.schema.space.create(prefix..'foreign_1')
    local fs2 = box.schema.space.create(prefix..'foreign_2')
    local fs3 = box.schema.space.create(prefix..'foreign_3')

    s:create_index('spk', { parts = { { 1, 'scalar' } } })
    fs1:create_index('fs1pk', { parts = { { 1, 'scalar' } } })
    fs2:create_index('fs2pk', { parts = { { 1, 'scalar' } } })
    fs3:create_index('fs3pk', { parts = { { 1, 'scalar' } } })

    local iut = s:create_index('iut', {
        parts = { { 1, 'scalar' } },
        unique = true,
        type = 'tree'
    })

    local iuh = s:create_index('iuh', {
        parts = { { 1, 'scalar' } },
        unique = true,
        type = 'hash'
    })

    local int = s:create_index('int', {
        parts = { { 1, 'scalar' } },
        unique = false,
        type = 'tree'
    })

    local fs1sk = fs1:create_index('fs1sk', {
        parts = { { 1, 'unsigned' } },
        unique = false
    })

    local constr1_name = prefix..'constr1'
    local constr2_name = prefix..'constr2'

    box.schema.func.create(constr1_name, {
        language = 'LUA',
        is_deterministic = true,
        body = 'function(t, c) return t.id < 999999 end'
    })

    box.schema.func.create(constr2_name, {
        language = 'LUA',
        is_deterministic = true,
        body = 'function(t, c) return t.id < 99999 end'
    })


    -- Fill the spaces.
    local function fill_spaces(from, to)
        for i = from, to do
            fs1:insert({ i + 1 })
            fs2:insert({ i + 2 })
            fs3:insert({ i + 3 })
            s:insert({ i, i + 1, i + 2, i + 3 })
        end
    end

    fill_spaces(0, step0_size)

    ----------------------------------------------------------------------------
    -- box.schema.space.format -------------------------------------------------
    ----------------------------------------------------------------------------

    -- Non-yielding format change.
    value = { { name = 'id', type = 'scalar' } }
    box.schema.space.format(s.id, value)
    t.assert_equals(box.schema.space.format(s.id), value)

    -- Yielding format change.
    value = { { name = 'id', type = 'number' } }
    box.schema.space.format(s.id, value)
    t.assert_equals(box.schema.space.format(s.id), value)

    ----------------------------------------------------------------------------
    -- box.schema.space.rename -------------------------------------------------
    ----------------------------------------------------------------------------

    box.schema.space.rename(s.id, s_name_new)
    t.assert_equals(s.name, s_name_new)

    box.schema.space.rename(s.id, s_name_initial)
    t.assert_equals(s.name, s_name_initial)

    ----------------------------------------------------------------------------
    -- box.schema.space.alter --------------------------------------------------
    ----------------------------------------------------------------------------

    -- Change field count (strengthen and relax).
    box.schema.space.alter(s.id, { field_count = 4 })
    box.schema.space.alter(s.id, { field_count = 0 })

    -- Change format.
    value = {
        { name = 'id', type = 'scalar' },
        { name = 'f1', type = 'scalar' },
        {
            name = 'f2',
            type = 'scalar',
            foreign_key = {
                f2 = { space = fs2.name, field = 1 }
            }
        },
        { name = 'f3', type = 'scalar' },
    }
    box.schema.space.alter(s.id, { format = value })

    -- Change sync flag.
    box.schema.space.alter(s.id, { is_sync = true })
    t.assert_equals(s.is_sync, true)

    box.schema.space.alter(s.id, { is_sync = false })
    t.assert_equals(s.is_sync, false)

    -- Change defer_deletes flag.
    box.schema.space.alter(s.id, { defer_deletes = true })
    box.schema.space.alter(s.id, { defer_deletes = false })

    -- Change name.
    box.schema.space.alter(s.id, { name = s_name_new })
    t.assert_equals(s.name, s_name_new)

    box.schema.space.alter(s.id, { name = s_name_initial })
    t.assert_equals(s.name, s_name_initial)

    -- Change constraint.
    box.schema.space.alter(s.id, { constraint = constr1_name })

    -- Change foreigin key.
    value = {
        f1 = { space = fs1.name, field = { f1 = 1 } }
    }
    box.schema.space.alter(s.id, { foreign_key = value })

    -- Change everything at once.
    value = {
        field_count = 4,
        format = {
            { name = 'id', type = 'number' },
            { name = 'f1', type = 'number' },
            { name = 'f2', type = 'number' },
            { name = 'f3', type = 'number' },
        },
        is_sync = true,
        defer_deletes = true,
        name = s_name_new,
        constraint = constr2_name,
        foreign_key = {
            f1 = { space = fs1.name, field = { f1 = 1 } },
            f2 = { space = fs2.name, field = { f2 = 1 } },
            f3 = { space = fs3.name, field = { f3 = 1 } },
        }
    }
    box.schema.space.alter(s.id, value)

    ----------------------------------------------------------------------------
    -- box.schema.space.drop ---------------------------------------------------
    ----------------------------------------------------------------------------

    -- Attempt tp drop a referenced foreign key space with secondary indices.
    --
    -- Currently the space drop flow looks like this:
    -- 1. Drop automatically generated sequence for the space.
    -- 2. Drop triggers of the space.
    -- 3. Disable functional indices of the space.
    -- 4. (!) Remove each index of the space starting from secondary indices.
    -- 5. Revoke the space privileges.
    -- 6. Remove the associated entry from the _truncate system space.
    -- 7. Remove the space entry from _space system space.
    --
    -- If the space is referenced by another space with foreign key constraint
    -- then the flow fails on the primary index drop (step 4). But at that point
    -- all the secondary indices are dropped already, so we have an inconsistent
    -- state of the database.
    --
    -- But if the drop function is transactional then the dropped secondary
    -- indices are restored on transaction revert and the database remains
    -- consistent: we can continue using the secondary index of the table we
    -- have failed to drop.

    local err = "Can't modify space '"..fs1.name
                .."': space is referenced by foreign key"
    t.assert_error_msg_equals(err, fs1.drop, fs1)

    -- The secondary index is restored on drop fail so this must succeed.
    fs1sk:select(42)

    ----------------------------------------------------------------------------
    -- box.schema.index.rename -------------------------------------------------
    ----------------------------------------------------------------------------

    local new_name = 'fs1sk_renamed'

    box.schema.index.rename(fs1.id, fs1sk.id, new_name)
    -- FIXME: On the secondary index drop its lua object was invalidated,
    -- so it does not hold the new index name, and we have to restore it
    -- from fs1.index[new_name].
    --
    -- Please remove this comment and the following three lines once the
    -- issue is solved.
    t.assert_not_equals(fs1sk.name, new_name)
    t.assert_not_equals(fs1.index[new_name], nil)
    fs1sk = fs1.index[new_name]
    t.assert_equals(fs1sk.name, new_name)

    ----------------------------------------------------------------------------
    -- box.schema.index.drop ---------------------------------------------------
    ----------------------------------------------------------------------------

    -- Drop unique tree index.
    box.schema.index.drop(s.id, iut.id)

    -- Drop unique hash index.
    box.schema.index.drop(s.id, iuh.id)

    -- Drop non-unique tree index.
    box.schema.index.drop(s.id, int.id)

    -- Finish him.
    s:drop()
    fs1:drop()
    fs2:drop()
    fs3:drop()
end

g.test_transactional_ddl_default_memtx = function(cg)
    cg.server_default:exec(test_transactional_ddl, { 'memtx' })
end

g.test_transactional_ddl_default_vinyl = function(cg)
    cg.server_default:exec(test_transactional_ddl, { 'vinyl' })
end

g.test_transactional_ddl_mvcc_memtx = function(cg)
    cg.server_mvcc:exec(test_transactional_ddl, { 'memtx' })
end

g.test_transactional_ddl_mvcc_vinyl = function(cg)
    cg.server_mvcc:exec(test_transactional_ddl, { 'vinyl' })
end
