local skynet = require "skynet"
local runconfig = require "runconfig"
skynet.start(function()
    skynet.error("配置文件："..runconfig.agentmgr.node)
    skynet.error("start main")
    skynet.newservice("gateway","gateway",1)
    skynet.exit()
end)
