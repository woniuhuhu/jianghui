local skynet = require "skynet"
local s = require "service"
local runconfig = require "runconfig"
local mynode =  skynet.getenv("node")
--scene_node
s.snode = nil 
--scene_id
s.sname = nil
--改变方向
s.client.shift = function(msg)
    if not s.sname then
        return
    end
    local x = msg[2] or 0
    local y = msg[3] or 0
    skynet.error("~~~~~~~~~~~~~~~~~~~~~!!~")
    s.call(s.snode,s.sname,"shift",s.id,x,y)
end
s.leave_scene = function()
    --不在场景
    if not  s.sname then
        return
    end
    s.call(s.node,s.name,"leave",s.id)
    s.snode = nil
    s.sname = nil
end
local function random_scene(  )
    --选择node
    local nodes = {}
    for i,v in pairs(runconfig.scene) do
        table.insert( nodes,i )
        if runconfig.scene[mynode] then
            table.insert( nodes, mynode ) 
        end
    end
    local idx = math.random( 1,#nodes )
    local scenenode = nodes[idx]
    --具体场景
    local scenelist = runconfig.scene[scenenode]
    local idx = math.random( 1,#scenelist )
    local sceneid = scenelist[idx]
    return scenenode,sceneid
end
s.client.enter = function(msg)
    if s.sname then
        return {"enter",1,"已在场景"}
    end
    local snode,sid = random_scene()
    local sname = "scene"..sid
    local isok = s.call(snode,sname,"enter",s.id,mynode,skynet.self())
    if not isok then
        return {"enter",1,"进入失败"}
    end
    s.snode = snode
    s.sname = sname
    return nil
end
