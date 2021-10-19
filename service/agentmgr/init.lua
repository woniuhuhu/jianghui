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
s.resp.reglogin = function(source,playerid,node,gate)
	local mplayer = players[playerid]
	skynet.error("@@@@@@@@@@@@")
	skynet.error(mplayer)
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
