local skynet = require "skynet"
local s = require "service"

s.resp.newservice = function(source,name,...)
	local srv = skynet.newservice(name,...)
	skynet.error("nodemgr "..name.." "..srv)
	return srv
end

s.start(...)
