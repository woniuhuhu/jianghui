local skynet = require "skynet"
local runconfig = require "runconfig"
skynet.start(function()
    skynet.error("配置文件："..runconfig.agentmgr.node)
    skynet.exit()
end)