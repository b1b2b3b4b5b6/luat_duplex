
require "utils"
require "pm"
require "crc8"
require"sim"
require"misc"
module(..., package.seeall)

duplex = {}

local UART_ID = 1
local read_quene = {}
local write_quene = {}
local recv_queue = {}
local str_ack_queue = {}
local split_string = "\0\0"

local DUPLEX_NEED_ACK = 2
local DUPLEX_IS_ACK = 3
local DUPLEX_NO_ACK = 1

local ota_queue = {}

local STR = 1
local BIN = 2

write_lock = false
local function inter_write(data)
    while true do 
        if write_lock == false then
            write_lock = true
            break
        end
        sys.wait(100)
    end
    uart.write(UART_ID, data)
    sys.wait(200)
    write_lock = false
end


local function read()
    local data = ""
    local temp = ""      
    while true do
        temp = uart.read(UART_ID, 2000)
        if not temp or string.len(temp) == 0 then break
        else
            data = data..temp
        end
    end
	
	if data == "ask me imei" then
		imei = "imei: " .. misc.getImei() .. " | iccid: " .. sim.getIccid()
		log.info("testUart.write",imei)
		uart.write(UART_ID,imei.."\r\n")
		return
    end
    
	table.insert(read_quene, data)
	log.info("uart read", string.format( "len[%d]",string.len( data )))
	sys.publish("UART_READ")
end

local function write(id, ack_typ, typ, data)
    local raw = "\0\0"
    local len = 0
    if data == nil then
        len = 3
    else
        len = 3 + string.len(data)
    end
    raw = raw..string.char(len / 256)
    raw = raw..string.char(len % 256)
    raw = raw..string.char(id)
    raw = raw..string.char(ack_typ)
    raw = raw..string.char(typ)
    if data ~= nil then
        raw = raw..data
    end
    local crc = crc8.get(string.sub(raw, 5, -1))
    raw = raw..string.char(crc)
    inter_write(raw)
end

-- local function write_task()
--     while true do
--         result = sys.waitUntil("UART_WRITE", nil)
--         if result == true then
--             message = table.remove(write_quene, 1)
--             if message then 
--                 -- while true do
--                 --     if string.len(message) > 500 then
--                 --         local temp = string.sub(message, 1, 500)
-- 				-- 		message = string.sub(message, 501, -1)
--                 --         uart.write(UART_ID,temp)
--                 --     else
--                 --         uart.write(UART_ID,message)
--                 --         uart.write(UART_ID, split_string)
--                 --         break
--                 --     end
--                 -- end
--                 uart.write(UART_ID, message)
--                 sys.wait(200)
--                 --log.info("uart write", string.len( message ))
--             end
--         end 
--     end
-- end

function send_ack(packet_id)
    write(packet_id, DUPLEX_IS_ACK, STR, nil)
end

local function recv_sort(data)

    local json_data, result, errinfo = json.decode(data) 

    if result and type(json_data)=="table" then
        --log.info("duplex", "json format success")
    else
        log.error("duplex", "json format error, :", data)
        return
    end  

    if json_data["Typ"] == "cut_ota" then
        table.insert(ota_queue, data)
        sys.publish("OTA_RECV")
        return
    end

    table.insert(recv_queue, data)
    sys.publish("DUPLEX_RECV")
    
end

function recv_ota()
    while true do 
        res = sys.waitUntil("OTA_RECV", nil)
        if res == true then
            data = table.remove(ota_queue, 1) 
            return data  
        else
            return nil
        end
    end
end


local last_id = 0
function recv_handle(packet)
    local packet_id = string.byte(packet, 1)
    local ack_typ = string.byte(packet, 2)
    local typ = string.byte(packet, 3)
    --log.info("recv_handle", string.format( "id[%d] ack_typ[%d] typ[%d]", packet_id, ack_typ, typ))
    if ack_typ == DUPLEX_NEED_ACK then
        send_ack(packet_id)
    end

    if ack_typ == DUPLEX_IS_ACK then
        log.info("recv_handle", string.format( "recv ack[%d]", packet_id))
        --table.insert(str_ack_queue, packet_id)
        sys.publish("DUPLEX_STR_ACK")
        return
    end

    -- if last_id == packet_id then 
    --     log.info("recv_handle", " same pakcet ignore")
    --     return
    -- end

    last_id = packet_id
    local data = string.sub(packet,  4, -1)
    log.info("recv_handle", "recv: ", data)
    recv_sort(data)
end


local data_buf  = ""
function split_task()
    while true do
        sys.waitUntil("UART_READ", nil)
        message = table.remove(read_quene, 1) 
        if message then
            data_buf = data_buf..message
            while true do
                local offset = string.find(data_buf, split_string, 1)
                --log.info("split task, offset: ", offset) 
                if not offset then break end
                local len_str = string.sub(data_buf, offset, offset + 2)
                data_buf = string.sub(data_buf, offset + 2, -1)
                if string.len(data_buf) < 2 then break end

                local len = string.byte(data_buf, 1) *256 + string.byte(data_buf, 2)
                --log.info("duplex len", len)

                if string.len(data_buf) < len + 2 + 1 then break end

                local pay_load = string.sub(data_buf, 3, 2 + len)
                crc = string.byte(data_buf, 2 + len + 1)

                --log.info("recv crc ", string.format( "%x",crc))
                
                crc_res = crc8.get(pay_load)
                --log.info("duplex crc", string.format( "%x",crc_res))
                if crc_res ~= crc then
                    data_buf = ""
                    break;
                end

                recv_handle(pay_load)
                
                --log.info("split task, data len: ", string.len(pay_load)) 
            end
        end
    end
end

-- wait recv data, block forever
-- @return string, recv data
-- @usage data = duplex.recv(), wati until recv data
function recv()
    while true do 
        res = sys.waitUntil("DUPLEX_RECV", nil)
        if res == true then
            data = table.remove(recv_queue, 1)  
            return data  
        end
    end
end

local id = 1
function get_packet_id()
    id = id + 1
    if id > 100 then
        id = 1
    end
    return id
end


function empty_str_ack()
    while true do
        res = sys.waitUntil("DUPLEX_STR_ACK", 1)
        if res == false then
            break
        end
    end
end

local send_lock = false

-- send str to serial
-- @string data
-- @number time_ms, send time out[ms]
-- @return bool, true or false
-- @usage duplex.sendstr("i am str", 3000) send "i am str" to serial, wait 3000 ms if not success
function sendstr(data, time_ms)
    data = data.."\0"
    while true do 
        if send_lock == false then
            send_lock = true
            break
        end
        sys.wait(100)
    end

    log.info("send str: ", data)
    empty_str_ack()
    -- for i = #str_ack_queue, 1, -1 do
    --     if str_ack_queue[i] == 2 then
    --         table.remove(str_ack_queue, i)
    --     end
    -- end

    local id = get_packet_id();
    
    if time_ms == 0 then
        write(id, DUPLEX_NEED_ACK, STR, data)
        res = sys.waitUntil("DUPLEX_STR_ACK", time_ms)
    else
        write(id, DUPLEX_NO_ACK, STR, data)
        res = true
    end
    -- if res == true then
        -- data = table.remove(str_ack_queue, 1)
        -- if data == id then
      	-- 	send_lock = false
        --     return true
        -- end
    -- end
    send_lock = false
    return res
end

function sendbin(data)
    while true do 
        if send_lock == false then
            send_lock = true
            break
        end
        sys.wait(100)
    end

    log.info("send bin", "len: ", string.len(data))

    local id = get_packet_id();
    write(id, DUPLEX_NO_ACK, BIN, data)

    send_lock = false
    return true
end


function recv_task()
    log.info("duplex", "recv task start")
    while true do
        data = recv()
        log.info("recv_task", string.format( "len[%d]", string.len( data )))
    end
end



uart.on(UART_ID,"receive",read)
uart.setup(UART_ID,115200,8,uart.PAR_NONE,uart.STOP_1)
sys.taskInit(split_task)
--sys.taskInit(write_task)
--sys.taskInit(recv_task)
--sys.taskInit(send_task)
