local skynet = require "skynet"
local cjson = require "cjson"
local pb = require "protobuf"
local mysql = require "skynet.db.mysql"
--4.20 
function test7( ... )
    local db = mysql.connect({
        host="127.0.0.1",
        port=3306,
        database="message_board",
        user="jianghui",
        password="winjhs1125",
        max_packet_size=1024*1024,
        on_connect=nil
        })
    pb.register_file("./storage/playerdata.pb")
    --读取数据库
    local sql = string.format( "select * from baseinfo where playerid = 109" )
    local res = db:query(sql)
    --反序列化
    local data = res[1].data
    print("data len: "..string.len(data))
    local udata = pb.decode("playerdata.BaseInfo",data)
    if not udata then
        print("err")
        return false
    end
    --输出
    local playerdata = udata
    print("coin: "..playerdata.coin)
    print("name: "..playerdata.name)
    print("time: "..playerdata.last_login)
end
function test6( )
    local db = mysql.connect({
        host="127.0.0.1",
        port=3306,
        database="message_board",
        user="jianghui",
        password="winjhs1125",
        max_packet_size=1024*1024,
        on_connect=nil
        })
    pb.register_file("./storage/playerdata.pb")
    --创角
    local playerdata = {
        playerid = 109,
        coin = 999999999,
        name = "jianghui",
        level = 3,
        last_login = os.time(),
    }
    --序列化
    local data = pb.encode("playerdata.BaseInfo",playerdata)
    print("data len: "..string.len(data))
    --存入数据库
    local sql = string.format( "insert into baseinfo (playerid,data) value (%d,%s)",109,mysql.quote_sql_str(data) )
    local res = db:query(sql)
    --查看存储结果
    if res.err then
        print("err : "..res.err)
    else
        print("ok")
    end
end

--protobuf编码
function test4(  )
    pb.register_file("./proto/login.pb")
    --编码
    local msg = {
        id = 101,
        pw = "123456",
    }
    local buff = pb.encode("login.Login",msg)
    print("len: "..string.len(buff))
    --解码
    local umsg = pb.decode("login.Login",buff)
    if umsg then
        print("id:"..umsg.id)
        print("pw: "..umsg.pw)
    else
        print("err")
    end
end
function json_pack( cmd,msg )
    msg._cmd = cmd
    local body = cjson.encode(msg) --协议体字节流
    local namelen = string.len( cmd ) --协议名长度
    local bodylen = string.len( body ) --协议体长度
    local len = namelen +bodylen + 2 --协议总长度
    local format = string.format( ">i2 i2 c%d c%d",namelen ,bodylen)
    local buff = string.pack(format,len,namelen,cmd,body)
    return buff
end
function json_unpack( buff )
    local len = string.len(buff)
    local namelen_format = string.format("> i2 c%d",len-2)
    local namelen,other = string.unpack(namelen_format,buff)
    local bodylen = len-2-namelen
    local format = string.format( "> c%d c%d",namelen,bodylen)
    local cmd,bodybuff = string.unpack(format,other)
    local isok,msg = pcall(cjson.decode,bodybuff)
    if not isok or not msg or not msg._cmd or not cmd == msg._cmd then
        print("error")
        return
    end
    return cmd,msg
end
--编码测试
function test1(  )
    local msg = {
        _cmd = "balllist",
        balls = {
            [1] = {id=102, x=10, y=20, size=1},
            [2] = {id=103, x=10, y=30, size=2},
        }
    }
    local buff = cjson.encode(msg)
    print(buff)
end
function test2( ... )
    local buff = [[{"_cmd":"entry","playerid":101,"x":10,"y":20,"size":1}]]
    local isok,msg = pcall(cjson.decode,buff)
    if isok then
        print(msg._cmd)
        print(msg.playerid)
    else
        print("error")
    end
end
--协议测试
function test3(  )
    local msg = {
        _cmd = "playerinfi",
        coin = 100,
        bag = {
            [1] = {1001,1},--倚天剑*1
            [2] = {1005,5},--草药*5
        },
    }
    --编码
    local buff_with_len = json_pack("playerinfo",msg)
    local len = string.len( buff_with_len )
    print("len: "..len)
    print(buff_with_len)
    --解码
    local format = string.format( ">i2 c%d",len-2 )
    local _,buff = string.unpack(format,buff_with_len)
    local cmd,umsg = json_unpack(buff)
    print("cmd: "..cmd)
    print("coin: "..umsg.coin)
    print("sword: "..umsg.bag[1][2] )
end

skynet.start(function()
    
    
        
    
        
    --test1()
    --test2()
    --test3()
    --test4()
    --test6()
    test7()
    skynet.exit()
end)