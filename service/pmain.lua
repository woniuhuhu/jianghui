local skynet = require "skynet"
local cjson = require "cjson"
--编码测试
function test1( ... )
    local msg = {
        _cmd = "balllist",
        balls = {
            [1] = {id=102, x=10, y=20, size=1},
            [2] = {id=103, x=10, y=30, size=2},
        }
    }
    local buff = cjson.encode(msg)
    print(burff)
end
skynet.start(function()
    test1()
end
)