local skynet = require "skynet"
local s = require "service"
s.client = {}
require "scene"
s.gate = nil
s.resp.send = function ( source,msg )
	skynet.send(s.gate,"lua","send",s.id,msg)
end
s.resp.kick = function(source)
	s.leave_scene()
	--在此处保存数据
	skynet.error("在此处保存数据")
	skynet.sleep(200)
end
s.resp.exit = function(source)
	skynet.exit()
end
s.client.work = function(msg)
	s.data.coin = s.data.coin +1
	return {"work",s.data.coin}
end
s.resp.client = function(source,cmd,msg)
	s.gate = source
	if s.client[cmd] then
		skynet.error("^^^^^^^"..s.name.."   ")
		local ret_msg = s.client[cmd](msg,source)
		if ret_msg then
			skynet.send(source,"lua","send",s.id,ret_msg)
			skynet.error(ret_msg[1].."  "..s.data.coin)
			skynet.error(s.id)
			skynet.error(s.name.."~!~")
		end
	else
		skynet.error("s.resp.client fail",cmd)
	end
end

s.init = function()
	--在此处加载角色数据
	skynet.sleep(200)
	s.data = {
		coin = 100,
		hp = 200,	
	}	
	skynet.error(s.data.coin.."  在此处加载角色数据  ")
end
s.start(...)