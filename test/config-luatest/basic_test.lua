local fun = require('fun')
local yaml = require('yaml')
local fio = require('fio')
local t = require('luatest')
local treegen = require('test.treegen')
local server = require('test.luatest_helpers.server')
local helpers = require('test.config-luatest.helpers')

local g = t.group()

g.before_all(function(g)
    treegen.init(g)
end)

g.after_all(function(g)
    treegen.clean(g)
end)

g.after_each(function(g)
    for k, v in pairs(g) do
        if k == 'server' or k:match('^server_%d+$') then
            v:stop()
        end
    end
end)

g.test_basic = function(g)
    local dir = treegen.prepare_directory(g, {}, {})
    local config = {
        credentials = {
            users = {
                guest = {
                    roles = {'super'},
                },
            },
        },
        iproto = {
            listen = 'unix/:./{{ instance_name }}.iproto',
        },
        groups = {
            ['group-001'] = {
                replicasets = {
                    ['replicaset-001'] = {
                        instances = {
                            ['instance-001'] = {
                                database = {
                                    rw = true,
                                },
                            },
                        },
                    },
                },
            },
        },
    }
    local config_file = treegen.write_script(dir, 'config.yaml', yaml.encode(config))
    local opts = {config_file = config_file, chdir = dir}
    g.server = server:new(fun.chain(opts, {alias = 'instance-001'}):tomap())
    g.server:start()
    t.assert_equals(g.server:eval('return box.info.name'), g.server.alias)
end

g.test_example_single = function(g)
    local dir = treegen.prepare_directory(g, {}, {})
    local config_file = fio.abspath('doc/examples/config/single.yaml')
    local opts = {config_file = config_file, chdir = dir}
    g.server = server:new(fun.chain(opts, {alias = 'instance-001'}):tomap())
    g.server:start()
    t.assert_equals(g.server:eval('return box.info.name'), g.server.alias)
end

g.test_example_replicaset = function(g)
    local dir = treegen.prepare_directory(g, {}, {})
    local config_file = fio.abspath('doc/examples/config/replicaset.yaml')
    helpers.start_example_replicaset(g, dir, config_file)
end

g.test_example_credentials = function(g)
    local dir = treegen.prepare_directory(g, {}, {})
    local config_file = fio.abspath('doc/examples/config/credentials.yaml')
    helpers.start_example_replicaset(g, dir, config_file)

    -- Verify roles.
    local info = g.server_1:eval("return box.schema.role.info('api_access')")
    t.assert_equals(info, {})
    local info = g.server_1:eval("return box.schema.role.info('audit')")
    t.assert_equals(info, {
        {'read,write,execute,create,drop,alter', 'universe', ''},
    })
    local info = g.server_1:eval("return box.schema.role.info('cdc')")
    t.assert_equals(info, {
        {'execute', 'role', 'replication'},
    })

    local all_permissions = 'read,write,execute,session,usage,create,drop,' ..
        'alter,reference,trigger,insert,update,delete'

    -- Verify users.
    local info = g.server_1:eval("return box.schema.user.info('replicator')")
    t.assert_equals(info, {
        {'execute', 'role', 'public'},
        {'execute', 'role', 'replication'},
        {'session,usage', 'universe', ''},
        {'alter', 'user', 'replicator'},
    })
    local info = g.server_1:eval("return box.schema.user.info('client')")
    t.assert_equals(info, {
        {'execute', 'role', 'public'},
        {'execute', 'role', 'super'},
        {'execute', 'role', 'api_access'},
        {'session,usage', 'universe', ''},
        {'alter', 'user', 'client'},
    })
    local info = g.server_1:eval("return box.schema.user.info('admin')")
    t.assert_equals(info, {
        {all_permissions, 'universe', ''}
    })
    local info = g.server_1:eval("return box.schema.user.info('monitor')")
    t.assert_equals(info, {
        {'execute', 'role', 'public'},
        {'session,usage', 'universe', ''},
        {'alter', 'user', 'monitor'},
    })

    -- TODO: Verify passwords.
end