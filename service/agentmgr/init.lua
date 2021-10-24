local skynet = require "skynet"
local s = require "service"

STATUS = {
	LOGIN = 2,
	GAME = 3,
	LOGOUT = 4,
}
--玩家列表
local players = {}
--玩家类
function mgrplayer()
	local m = {
		playerid = nil,
		node = nil,
		agent = nil,
		status = nil,
		gate = nil,
	}
	return m
end
--获取在线人数
function get_online_count( ... )
	local count = 0
	for playerid,player in pairs(players) do
		count = count +1
	end
	return count
end
--将num数量的玩家踢下线
s.resp.shutdown = function ( source,num )
	--当前玩家数量
	local count = get_online_count()
	--踢下线
	local n = 0
	for playerid,player in pairs(players) do
		skynet.fork(s.resp.reqkick,nil,playerid,"close server")
		n = n+1  --计算总共发了num条下线消息
		if n>= num then
			break
		end
	end
	--等待玩家数下线
	while true do
		skynet.sleep(200)
		local new_count = get_online_count()
		skynet.error("shutdown online: "..new_count)
		if new_count <= 0 or new_count <= count-num then
			return new_count
		end
	end
end
s.resp.reglogin = function(source,playerid,node,gate)
	local mplayer = players[playerid]
	--登录过程禁止顶替
	if mplayer and mplayer.status == STATUS.LOGOUT then
		skynet.error("reglogin fail,at status LOGOUT"..playerid)
		return false
	end
	if mplayer and mplayer.status == STATUS.LOGIN then
		skynet.error("reglogin fail,at status LOGIN"..playerid)
		return false
	end
	--在线顶替
	if mplayer then
		local pnode = mplayer.node
		local pagent = mplayer.agent
		local pgate = mplayer.gate
		mplayer.status = STATUS.LOGOUT,
		s.call(pnode,pagent,"kick")
		s.send(pnode,pagent,"exit")
		s.send(pnode,pgate,"send",playerid,{"kick","dingti xia xian"})
		s.call(pnode,pgate,"kick",playerid)
	end
	--上线
	local player = mgrplayer()
	player.playerid = playerid
	player.node = node
	player.gate = gate
	player.agent = nil
	player.status = STATUS.LOGIN
	skynet.error(s.name.."  @@  "..playerid)
	players[playerid] = player
	local agent = s.call(node,"nodemgr","newservice","agent","agent",playerid)
	player.agent = agent
	player.status = STATUS.GAME
	return true,agent
end
s.resp.reqkick = function(source,playerid,reson)
	local mplayer = players[playerid]
	if not mplayer then
		return false	
	end
	if mplayer.status ~= STATUS.GAME then
		return false
	end
	
	local pnode = mplayer.node
	local pagent = mplayer.agent
	local pgate = mplayer.gate
	mplayer.status = STATUS.LOGOUT
	
	s.call(pnode,pagent,"kick")
	s.send(pnode,pagent,"exit")
	s.send(pnode,pgate,"kick",playerid)
	players[playerid] = nil

	return true
end
s.start(...)
