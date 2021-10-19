--代码实现：login
--[[
    3.7.1　登录协议首先，定义如图3-27所示的登录协议。
    客户端需要发送玩家id（此处当做账号）和密码，服务端收到登录协议后，
    会做出回应，中间参数0代表登录成功，若为1则代表登录失败，第二个参数代表（失败的）原因，
    比如“账号或密码错误”“其他玩家正在尝试登录该账号，请稍后再试”。
]]
--3.7.2 客户端消息分发
--[[
    gateway会将客户端协议以client消息的形式转发给login服务（回顾3.6.5节）。
    由于客户端会发送很多协议，虽然可以在login服务的s.resp.client方法（回顾3.3.4节
    ，service模块会在服务收到client消息后调用该方法）中编写多个if来判断，但消息一多，
    s.resp.client可能会变得混乱，因此最好是再做一次消息分发，根据不同的协议名指定不同的处理方法。
    下面编写如代码3-23所示的client远程调用，它实现两个功能。
    ·根据协议名（cmd）找到s.client.XXX方法，并调用它。
    ·鉴于服务端几乎都要给客户端回应消息，因此给出一个简便处理方式。
    将s.client.XXX的返回值发回给客户端（经由gateway转发）。
]]
--[[
    上述代码结构和3.4.3节的代码很相似，读者可以对照着理解。
    一些变量的含义如下。
    ·s.client：定义一个空表，用于存放客户端消息处理方法。
    ·参数source：消息发送方，比如某个gateway。
    ·参数fd：客户端连接的标识，由gateway发送过来。
    ·参数cmd和msg：协议名和协议对象。下面编写如代码3-24所示的测试方法，在收到login协议后，
    登录服务会给客户端回应（需在main中启动登录服务）。
]]
--3-23
local skynet = require "skynet"
local s = require "service"
s.client = {}
s.resp.client = function(source,fd,cmd,msg)
    if s.client[cmd] then
        local ret_msg = s.client[cmd](fd,msg,source)
        skynet.send(source,"lua","send_by_fd",fd,ret_msg)
    else
        skynet.error("3-23  s.resp.client fail",cmd)
    end
end

--代码3-24　service/login/init.lua的测试内容
--s.client.login = function(fd,msg,source)
  --  skynet.error("代码3-24　service/login/init.lua的测试内容,login recv "..msg[1])
    --return {"login",-1,"测试"}
--end
s.client.login = function(fd,msg,source)
	local playerid = tonumber(msg[2])
	local pw = tonumber(msg[3])
	local gate = source
	node = skynet.getenv("node")
	--校验用户密码
	if pw ~= 123 then
		return {"login",1,"password is wrong"}
	end
	--发给 agentmgr
    skynet.error(playerid)
	local isok,agent = skynet.call("agentmgr","lua","reglogin",playerid,node,gate)
    skynet.error("login  :"..playerid)
    if not isok then
		return {"login",1,"请求 mgr lost"}
	end
	--回应 gate
	local isok = skynet.call(gate,"lua","sure_agent",fd,playerid,agent)
	if not isok then
		return {"login",1,"gate is lost"}
	end
	skynet.error("login succ"..playerid)
	return {"login",0,"success"}
end

s.start(...)
