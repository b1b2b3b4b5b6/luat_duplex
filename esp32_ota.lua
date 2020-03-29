require "sim"
require "misc"
require "utils"
require "pm"
require "duplex"
require"http"


esp32_ota = {}
cut_url = "http://lumoschen.cn:2201/get_cut"

local function wait_socket()
    while true do
        if socket.isReady() then 
            break
        end
        sys.wait(3000)
    end
end


local ret_data = nil

local function post_cb(result,prompt,head,body)
    if body == nil then
        ret_data = nil
    else
        log.info("body len[%d]", string.len(body))
        ret_data = body
    end
    sys.publish("GET_BODY")
end

function http_post(arg) 
    sys.waitUntil("GET_BODY", 100)
    log.info("post arg: ", arg)
    http.request("POST", cut_url, nil, nil, arg, 6000, post_cb, nil)
    res = sys.waitUntil("GET_BODY", 15000)
    if res == true and ret_data ~= nil then
    else
        return nil, false
    end
end


local function loop_task()
    wait_socket()
    while true do
        local str = duplex.recv_ota()
        data, ok = http_post(str) 
        if ok == true then
            duplex.sendbin(data)
        end     
        
    end

end

sys.taskInit(loop_task)
