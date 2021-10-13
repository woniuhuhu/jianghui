local skynet = require "skynet"
local cluster = require "skynet.cluster"
local M = {
    --类型和ID
    name = "",
    id = 0,
    --回调函数
    exit = nil,
    init = nil,
    --分发方法
    resp = {}, 
}

function traceback( err )
    skynet.error(tostring(err))
    skynet.error(debug.traceback())
end

local dispatch = function ( session,address,cmd,... )
    local fun = M.resp[cmd]
    if not fun then
        skynet.ret()
        return
    end
    local ret = table.pack(xpcall(fun,traceback,address,...))
    skynet.error(ret)
    local isok = ret[1]
    skynet.error(ret[1])
    skynet.error(ret[2])
    skynet.error(ret[3])
    skynet.error(ret[4])
    if not isok then
        skynet.ret()
        return
    end
    skynet.error(table.unpack(ret,2))
    skynet.retpack(table.unpack(ret,2))
end


function init()
    skynet.dispatch("lua",dispatch)
    if M.init then      
        M.init()
    end
end

function M.start(name,id,...)
    M.name = name
    M.id = tonumber(id)
    skynet.error("jianghui  "..M.name,M.id)
    skynet.start(init)
end

function M.call(node,srv,...)
    local mynode = skynet.getenv("node")
    if node==mynode then
        return skynet.call(srv,"lua",...)
    else
        return cluster.call(node,srv,...)
    end
end

function M.send( node,srv,... )
    local mynode = skynet.getenv("node")
    if node==mynode then
        return skynet.send(srv,"lua",...)
    else
        return cluster.send(node,srv,...)
    end
end

return M