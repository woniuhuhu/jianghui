local skynet = require "skynet"
local s = require "service"
local socket = require "skynet.socket"
local runconfig = require "runconfig"
local str_unpack = function(msgstr)
	local msg = {}
	while true do
		local arg,rest = string.match(msgstr,"(.-),(.*)")
		if arg then
			msgstr = rest
			table.insert(msg,arg)
		else
			table.insert(msg,msgstr)
			break
		end
	end	
		return msg[1],msg
end

local str_pack = function(cmd,msg)
	return table.concat(msg,",").."\r\n"
end

local process_msg = function(fd,msgstr)
	local cmd,msg = str_unpack(msgstr)
	skynet.error("recv: "..fd.."["..cmd.."] {"..table.concat(msg,",").."}")
	local conn = conns[fd]
	local playerid = conn.playerid
	--not login
	if not playerid then
		local node = skynet.getenv("node")
		local nodecfg = runconfig[node]
		local loginid = math.random(1,#nodecfg.login)
		local login = "login"..loginid
		skynet.send(login,"lua","client",fd,cmd,msg)
	else
		local gplayer = players[playerid]
		local agent = gplayer.agent
		skynet.send(agent,"lua","client",cmd,msg)
	end
end

--local process_msg = function(fd,msgstr)
--	print(msgstr)
--end


local process_buff = function(fd,readbuff)
	while true do
		local msgstr,rest = string.match(readbuff,"(.-)\r\n(.*)")
		if msgstr then
			readbuff = rest
			skynet.error(readbuff)
			process_msg(fd,msgstr)
		else
			return readbuff
		end
	end		
end

local recv_loop = function(fd)
	socket.start(fd)
	skynet.error("socket connect "..fd)
	local readbuff = ""
	while true do
		local recvstr = socket.read(fd)
		if recvstr then
			readbuff = readbuff..recvstr
			skynet.error(readbuff)
			readbuff = process_buff(fd,readbuff)
		else
			skynet.error("skoket close"..fd)
			disconnect(fd)
			socket.close(fd)
			return
		end
	end
end

local connect = function ( fd,addr )
    print("connect from:"..addr.." "..fd)
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
    return m
end
function gateplayer()
    local m = {
        playerid = nil,
        agent = nil,
        conn = nil,
    }
    return m 
end
function s.init(  )
    skynet.error("[start]"..s.name.." "..s.id)
    local node = skynet.getenv("node")
    local nodecfg = runconfig[node]
    local port = nodecfg.gateway[s.id].port
	skynet.error(port)
	skynet.error(socket)
	local jh = "0.0.0.0:"..port  --这是什么情况，卧槽，必须这样才不会报错，我也不晓得咋的了~
    local listenfd = socket.listen(jh)
    skynet.error("listen socket:","0,0,0,0",port)
    socket.start(listenfd,connect)
end
s.resp.send_by_fd = function ( source,fd,msg )
	if not conns[fd] then
		return
	end
	local buff = str_pack(msg[1],msg)
	skynet.error("send "..fd.."["..msg[1].."] {"..table.concat(msg,",").."}")
	socket.write(fd,buff)
end

s.resp.send = function(source,playerid,msg)
	local gplayer = players[playerid]
	if gplayer == nil then
		return
	end
	local c = gplayer.conn
	if c == nil then
		return 
	end
	s.resp.send_by_fd(nil,c.fd,msg)
end

s.resp.sure_agent = function(source,fd,playerid,agent)
	local conn = conns[fd]
	if not conn then 
		skynet.call("agentmgr","lua","reqkick",playerid,"未完成登录即下线")
		return false
	end
	conn.playerid = playerid
	local gplayer = gateplayer()
	gplayer.playerid = playerid
	gplayer.agent = agent
	gplayer.conn = conn
	players[playerid] = gplayer
	return true
end



s.start(...)
