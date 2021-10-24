local skynet = require "skynet"
local s = require "service"
local socket = require "skynet.socket"
local runconfig = require "runconfig"
local closing = false
--不再接受新连接4-29
s.resp.shutdown = function ( ... )
	closing = true
end
--3.6.1连接类和玩家类
--[[
	gateway需要使用两个列表，一个用于保存客户端连接信息，另一个用于记录已登录的玩家信息。
	表3-4提及的“让gateway把客户端和agent关联起来”，即是将“连接信息”和“玩家信息”关联起来。
	在代码3-12中，定义了conns和players这两个表，以及conn和gateplayer这两个类。
	图3-19是代码3-12的示意图。在客户端进行连接后，程序会创建一个conn对象（稍后实现），
	gateway会以fd为索引把它存进conns表中。conn对象会保存连接的fd标识，但playerid属性为空。
	此时gateway可以通过conn对象找到连接标识fd，给客户端发送消息。
	当玩家成功登录时，程序会创建一个gateplayer对象（稍后实现，只有成功登录服务端才会创建角色对象，
	按照较常见的命名规则，这里称为player而不称为role），gateway会以玩家id为索引，将它存入players表中。
	gateplayer对象会保存playerid（玩家id）、agent（对应的代理服务id）和conn（对应的conn对象）。
	关联conn和gateplayer，即设置conn对象的playerid。
	登录后，gateway可以做到双向查找：·若客户端发送了消息，可由底层Socket获取连接标识fd。
	gateway则由fd索引到conn对象，再由playerid属性找到player对象，进而知道它的代理服务（agent）在哪里，
	并将消息转发给agent。·若agent发来消息，只要附带着玩家id，
	gateway即可由playerid索引到gateplayer对象，进而通过conn属性找到对应的连接及其fd，
	向对应客户端发送消息。
]]
--3-12
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
--3.6.8登出流程
--[[
	玩家有两种登出的情况，一种是客户端掉线，另一种是被顶替下线。
	若是客户端掉线，3.6.2节的程序（赶紧翻回去看看）会调用代码3-21所示的disconnect方法。
	按照3.5.2节的登出流程，gateway会向agentmgr发送下线请求“reqkick”，由agentmgr仲裁。
]]
--3-21
local disconnect = function(fd)
	local c = conns[fd]
	if not c then
		return
	end
	local playerid = c.playerid
	if not playerid then
		return
	else
		players[playerid] = nil
		local reason = "断线"
		skynet.call("agentmgr","lua","reqkick",playerid,reason)
	end
end
--3.6.4解码和编码
--[[
	本节实现两个辅助方法str_unpack和str_pack，用于消息的解码和编码，见代码3-17。
	其中str_unpack对应图3-21的阶段③。
	str_unpack是一个解码方法，参数msgstr代表消息字符串
	。示意图见图3-22，图中msgstr的值为“login,101,134”
	。第一个返回值cmd是字符串“login”，第二个返回值msg是一个Lua表。
	看str_unpack的具体实现，内部是个循环结构，每次循环都由string.match匹配逗号前的字符。
	例如，传入的msgstr为“login, 101,134”，则匹配后arg的值为“login”、rest的值为“101, 134”；
	传入的msgstr为“101, 134”，则匹配后arg的值为“101”、rest的值为“134”。
	每次取值后，它会把参数插入msg表，msg表用作协议对象，方便后续取值。
	str_unpack会返回两个值，第一个值msg[1]是协议名称（协议对象第一个元素），第二个值即为协议对象。
]]
--[[
	str_pack实现了与str_unpack相反的功能，
	示意图见图3-23，它将协议对象转换成字符串，并添加分隔符“\r\n”。
]]
--3-17
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
--3.6.5 消息分发
--[[
	消息处理方法process_msg如代码3-18所示，虽然代码只有十多行，但还是有点复杂，
	可通过如下四个部分理解这个方法。
	1.消息解码通过str_unpack解码消息，相关变量的含义如下。
	·msgstr：切分后的消息，如“login,101,123”。
	·cmd：消息名，如login。
	·msg：消息对象，如Lua表{[1]="login", [2]="101", [3]="123"}。
	2.如果尚未登录对于代码“if not playerid”为真的部分，
	程序将随机选取同节点的一个登录服务器转发消息，
	如图3-24所示的阶段②，相关变量的含义如下。
	·conn：3.6.1节定义的连接对象。
	·playerid：如果完成登录，那么它会保存着玩家id，否则为空。
	·node和nodecfg：同3.6.2节的含义。
	·loginid：随机的login服务编号。
	·login：随机的login服务名称，如“login2”。
	3.如果已登录将消息转发给对应的agent。
	如图3-24所示的阶段③，相关变量的含义如下。
	·gpalayer：3.6.1节定义的gateplayer对象。
	·agent：该连接对应的代理服务id。
	4.client消息消息转发使用了skynet.send(srv,"lua","client", ...)的形式，
	其中的client是自定义的消息名（skynet中的概念，指服务间传递的消息名字，
	它与cmd的区别是cmd是客户端协议的名字）。
	在封装好的service模块中（见3.4.3节），login和agent可以用s.resp.client接收转发的消息，
	再根据cmd做不同处理。
]]
--[[
	图3-24是process_msg方法的示意图，
	gateway收到客户端协议后，如果玩家已登录，它会将消息转发给对应的代理（阶段③）；
	如果未登录，gateway会随机选取一个登录服务器，并将消息转发给它处理。gateway保持着轻量级的功能，
	它只转发协议，不做具体处理。
	读者可以先屏蔽掉process_msg中分发消息的代码，用telnet等客户端测试gateway能否正常工作。
	由于在telnet换行即为输入分隔符“\r\n”，因此直接用换行分割消息即可，如图3-25所示。
]]
--3-18
local process_msg = function(fd,msgstr)
	local cmd,msg = str_unpack(msgstr)
	skynet.error("3-18 process_msg recv: fd:"..fd.."   ["..cmd.."] {"..table.concat(msg,",").."}")
	local conn = conns[fd]
	local playerid = conn.playerid
	--not login
	if not playerid then
		local node = skynet.getenv("node")
		local nodecfg = runconfig[node]
		local loginid = math.random(1,#nodecfg.login)
		local login = "login"..loginid
		skynet.error("3-18 process_msg 向服务名为  :"..login.." 的服务发送消息")
		skynet.send(login,"lua","client",fd,cmd,msg)
	else
		skynet.error(playerid)
		local gplayer = players[playerid]
		local agent = gplayer.agent
		skynet.error("******************************")
		skynet.send(agent,"lua","client",cmd,msg)
	
	end
end

--3.6.3 处理客户端协议
--[[
	在3.6.3节讲解的程序框架中，服务端接收到数据后，就会调用process_buff，
	并把对应连接的缓冲区传给它。process_buff会实现消息的切分工作，
	举例来说，如果缓冲区readbuff的内容是“login,101,134\r\nwork\r\nwo”，
	那么process_buff会把它切分成“login,101,123”和“work”这两条消息交由下一阶段的方法去处理，
	然后返回“wo”，供下一阶段的recv_loop处理。process_buff的整个处理流程如图3-21所示。
	它先接收缓冲区数据（阶段①），然后按照分隔符\r\n切分数据（协议格式已在3.5.3节中说明），
	并将切分好的数据交由process_msg方法处理（②阶段），最后返回尚未处理的数据“wo”
	（阶段④，返回值会重新赋给readbuff，见代码3-15）。
	process_msg会解码协议，并将字符串转为Lua表（如把字符串“login,101,123”转成图中的msg表，阶段③）。
	process_buff方法如代码3-16所示。由于缓冲区readbuff可能包含多条消息，
	且process_buff主体是个循环结构，因此每次循环时都会使用string.match匹配一条消息，
	再调用下一阶段的process_msg（稍后实现）处理它。
]]
--[[
	代码3-16中变量名的含义如下：
	·参数fd：客户端连接的标识。
	·参数readbuff：接收数据的缓冲区。
	·msgstr和rest：根据正则表达式“(.-)\r\n(.*)”的规则，它们分别代表取出的第一条消息和剩余的部分。
	举例来说，假如readbuff的内容是“login,101,134\r\nwork\r\nwo”，经过string.match语句匹配，
	msgstr的值为“login,101,134”，rest的值为“work\r\nwo”；如果匹配不到数据，
	例如readbuff的内容是“wo”，那么经过string.match语句匹配后，msgstr为空值。
	至此，我们实现了处理客户端消息的程序框架，读者可以先自行编写process_msg方法，
	让它打印出客户端消息以测试功能是否正常，再往下看如何编写具体的协议处理方法。
]]
--3-16
local process_buff = function(fd,readbuff)
	while true do
		local msgstr,rest = string.match(readbuff,"(.-)\r\n(.*)")
		if msgstr then
			readbuff = rest
			skynet.error("3-16 process_buff : "..readbuff)
			process_msg(fd,msgstr)
		else
			return readbuff
		end
	end		
end
--3-15
--[[
	代码3-15分为如下四部分。
	1）初始化：使用socket.start开启连接，定义字符串缓冲区readbuff。
	为了处理TCP数据的粘包现象（见3.5.3节），我们把接收到的数据全部存入readbuff中。
	2）循环：通过while true do ...end实现循环，该协程会一直循环。
	每次循环开始，就会由socket.read阻塞的读取连接数据。
	3）若有数据：若接收到数据（if recvstr为真的分支），程序将数据拼接到readbuff后面，
	再调用process_buff（稍后实现）处理数据。process_buff会返回尚未处理的剩余数据。
	举例说明，假如readbuf的值为“login\r\nwork\r\nwo”，传入process_buff后，
	process_buff会处理两条完整的协议“login\r\”和“work\r\n”（按照3.5.3节描述的协议格式，
	协议以“\r\n”作为结束符），返回不完整的“wo”，供下一次处理。
	4）若断开连接：若客户端断开连接（if recvstr为假的分支），调用disconnect（稍后实现）处理断开事务，
	再调用socket.close关闭连接。
]]
--[[
	图3-20对本节的3段代码做了总结。
	当客户端连接时，程序通过skynet.fork发起协程，协程recv_loop是个循环，
	每个协程都记录着连接fd和缓冲区readbuff。收到数据后，程序会调用process_buff处理缓冲区里的数据。
]]
--每一条连接接受数据处理
--协议格式cmd,arg1,arg2....#
local recv_loop = function(fd)
	socket.start(fd)
	skynet.error("3-15   recv_loop  socket connect "..fd)
	local readbuff = ""
	while true do
		local recvstr = socket.read(fd)
		if recvstr then
			readbuff = readbuff..recvstr
			skynet.error("3-15 recv_loop : "..readbuff)
			readbuff = process_buff(fd,readbuff)
		else
			skynet.error("3-15 recv_loop  skoket close"..fd)
			disconnect(fd)
			socket.close(fd)
			return
		end
	end
end
--3-14
--[[
	代码3-14中变量名的含义如下。
	·参数fd：客户端连接的标识，这些参数是socket.start规定好的。
	·参数addr：客户端连接的地址，如“127.0.0.1:60000”。
	·c：新创建的conn对象。
	recv_loop负责接收客户端消息，如代码3-15所示。
	其中参数fd由skynet.fork传入，代表客户端的标识。
	这段代码可以分成四个部分，可以先大致浏览代码，再看下面的解释。
]]
local connect = function ( fd,addr )
    skynet.error("3-14 connect from:"..addr.." "..fd)
	if closing then
		skynet.error("不再接受新连接")
		return
	end
    local c = conn()
    conns[fd] = c
    c.fd = fd
    skynet.fork(recv_loop,fd)
end
--3.6.2 接受客户端连接
--[[
	本节将会实现gateway处理客户端连接的功能。
	在服务启动后，service模块会调用s.init方法（见3.4.2节），
	在里面编写功能，如代码3-13所示。先开启Socket监听，程序读取了3.3.5节编写的配置文件，
	找到该gateway的监听端口port，然后使用skynet.socket模块的listen和start方法开启监听。
	当有客户端连接时，start方法的回调函数connect（稍后实现）会被调用。
]]
--[[
	代码3-13中变量名的含义如下。
	·node：获取3.3.2节中配置文件的节点名，如“node1”。
	·nodecfg：获取3.3.5节中配置文件的节点配置，如{gateway={...}, login={..}}。
	·s.id：服务的编号，见3.4.2节。·port：获取gateway要监听的端口号，如8001。
	·listenfd：监听Socket的标识。
	现在来看看connect方法的内容。
	当客户端连接上时，gateway创建代表该连接的conn对象，并开启协程recv_loop（稍后实现）
	专接收该连接的数据，如代码3-14所示，相应的图片解释在下一段代码后，即图3-20。
]]
--3-13
function s.init(  )
    skynet.error("3-13 s.init [start]"..s.name.." "..s.id)
    local node = skynet.getenv("node")
    local nodecfg = runconfig[node]
    local port = nodecfg.gateway[s.id].port
	skynet.error(port)
	skynet.error(socket)
	local jh = "0.0.0.0:"..port  --这是什么情况，卧槽，必须这样才不会报错，我也不晓得咋的了~
    local listenfd = socket.listen(jh)
    skynet.error("3-13 s.init listen socket:","0,0,0,0",port)
    socket.start(listenfd,connect)
end
--3.6.6发送接口消息
--[[
	gateway将消息传给login或agent，login或agent也需要给客户端回应。
	比如，客户端发送登录协议，login校验失败后，要给客户端回应“账号或密码错误”，
	这个过程如图3-26所示，它先将消息发送给gateway（阶段③），再由gateway（阶段④）转发。
]]
--[[
	send_by_fd方法用于login服务的消息转发，功能是将消息发送到指定fd的客户端。
	参数source代表消息发送方，比如来自“login1”，后面两个参数fd和msg代表客户端fd和消息内容
	。它先用str_pack编码消息，然后使用socket.write将它发送给客户端。send方法用于agent的消息转发，
	功能是将消息发送给指定玩家id的客户端。它先根据玩家id（playerid）查找对应客户端连接，
	再调用send_by_fd发送。这两个接口会在后续实现login和agent时调用。
]]
--3-19
s.resp.send_by_fd = function ( source,fd,msg )
	if not conns[fd] then
		return
	end
	local buff = str_pack(msg[1],msg)
	skynet.error("（3-19） s.resp.send_by_fd send "..fd.." ["..msg[1].."] {"..table.concat(msg,",").."}")
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
--3.6.7 确认登录接口
--[[
	在3.5.1节描述的阶段⑧中，在完成了登录流程后，login会通知gateway，
	让它把客户端连接和新agent关联起来。下面定义如代码3-20所示的sure_agent远程调用方法，实现该功能。
]]
--3-20
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

--3-22
--[[
	如果agentmgr仲裁通过，或是agentmgr想直接把玩家踢下线，在保存数据后，
	它会通知gateway做3.6.7节介绍的反向操作（具体接口如代码3-22所示），
	来删掉玩家对应的conn和gateplayer对象。
]]
s.resp.kick = function(source,playerid)
	local gplayer = players[playerid]
	if not gplayer then
		return
	end
	local c = gplayer.conn
	players[playerid] = nil
	if not c then
		return
	end
	conns[c.fd] = nil
	disconnect(c.fd)
	socket.close(c.fd)
end

s.start(...)
