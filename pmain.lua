local skynet = require "skynet"
local socketdriver = require "skynet.socketdriver"
local netpack = require "skynet.netpack"
local queue --message queue
--解码底层传来的SOCKET类型消息
function socket_unpack( msg,sz )
    return netpack.filter(queue,msg,sz)
end
--处理底层传来的SOCKET类型消息
function socket_dispatch( _,_,q,type,... )
    skynet.error("socket_dispatch type:"..(type or "nil"))
    queue = q
    if type == "open" then
        process_connect(...)
    elseif type == "data" then
        process_msg(...)
    elseif type == "more" then
        process_more(...)
    elseif type == "close" then
        process_close(...) 
    elseif type == "error" then
        process_error(...)
    elseif type == "warning" then
        process_warning(...)
    end
end

skynet.start(function()
    --注册SOCKET类型消息
    skynet.register_protocol({
        name = "socket",
        id = skynet.PTYPE_SOCKET,
        unpack = socket_unpack,
        dispatch = socket_dispatch,
    })
    --注册LUA类型消息
    --开启监听
    local listenfd = socketdriver.listen("0.0.0.0",8888)
    socketdriver.start(listenfd)
end)