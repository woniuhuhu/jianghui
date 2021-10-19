local balls = {}
--球
function ball()
    local m = {
        playerid = nil,
        node = nil,
        agent = nil,
        x = math.random( 0,100 ),
        y = math.random( 0,100 ),
        size = 2,
        speedx = 0,
        speedy = 0,
    }
    return m 
end
--球列表
local function balllist_msg()
    local msg = {"balllist"}
    for i,v in pairs (balls) do
        table.insert( msg,v.playerid )
        table.insert( msg,v.x )
        table.insert( msg,v.y )
        table.insert( msg,v.size )
    end
    return msg
end

local foods = {}
local food_maxid = 0
local food_count = 0
--食物
function food()
    local m = {
        id = nil,
        x = math.random( 0,100 )
        y = math.random( 0,100 )
    }
    return m 
end

--食物列表
local function foodlist_msg()
    local msg = {"foodlist"}
    for i,v in pairs(foods) do
        table.insert( msg,v.id )
        table.insert( msg,v.x )
        table.insert( msg,v.y )
    end
    return msg
end

--进入
s.resp.enter = function(source,playerid,node,agent)
    if balls[playerid] then
        return false
    end
    local b = ball()
    b.playerid = playerid
    b.node = node
    b.agent = agent
    --广播
    local entermsg = {"enter",playerid,b.x,b.y,b.size}
    boardcast(entermsg)
    --记录
    balls[playerid] = b
    --回应
    local ret_msg = {"enter",0,"进入成功"}
    s.send(b.node,b.agent,"send",ret_msg)
    --发战场信息
    s.send(b.node,b.agent,"send",balllist_msg())
    s.send(b.node,b.agent,"send",foodlist_msg())
    return true
end
--广播
function broadcast(msg)
    for i,v in pairs(balls) do
        s.send(v.node,v.agend,"send",msg)
    end
end
--退出
s.resp.leave = functionm(source,playerid)
    if not balls[playerid] then
        return false
    end
    balls[playerid] = nil
    local leavemsg = {"leave",playerid}
    broadcast(leavemsg)
end
--改变速度
s.resp.shift = function ( source,playerid,x,y )
    local b = balls[playerid]
    if not b then
        return false
    end
    b.speedx = x
    b.speedy = y
end

function update( frame )
    food_update()
    move_update()
    eat_update()
    --碰撞略
    --分裂略
end