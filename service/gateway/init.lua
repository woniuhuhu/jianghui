local skynet = require "skynet"
local s = require "service"
local socket = require "skynet.socket"
local runconfig = require "runconfig"

function s.init(  )
    skynet.error("[start]"..s.name.." "..s.id)
    local node = skynetos.getenv("node")
    local nodecfg = runconfig[node]
    local port = nodecfg.gateway[s.id].port
    local listenfd = socket.listen("0,0,0,0",port)
    skynet.error("listen socket:","0,0,0,0",port)
    socket.start(listenfd,connect)
end
local connect = function ( fd,addr )
    print("connect from"..addr.." "..fd)
    local c = conn()
    conns[fd] = c
    c.fd = fd
    skynet.fork(recv_loop,fd)
end

conns = {} --[fd] = conn
players = {} --[playerid] = gateplayer
--连接类
function conn()
    local m = {
        fd = nil,
        player = nil,
    }
    return m}
end

function gateplayer()
    local m = {
        playerid = nil,
        agent = nil,
        conn = nil,
    }
    return m 
end


s.start(...)