#! /usr/bin/env lua

local socket = require("socket")
local struct = require("struct")
local getopt = require("getopt")

local ntp_packet_size <const> = 48
local ntp_format <const> = ">BBBBIIIIIIIIIII"
local ntp_timestamp_delta <const> = 2208988800
local date_format <const> = "!%Y-%m-%dT%H:%M:%S" 

local ntp_server = "pool.ntp.org"
local ntp_port = 123
local timeout = 0

help = function()
    print("Usage: ntp [options] <ntp-server>")
    print("")
    print("Options:")
    print("  -h        print this message")
    print("  -p        port to use, default: " .. ntp_port)
    print("  -t <sec>  number of seconds to wait for a response, default: " .. timeout)
    print("  -v        verbose output")
    print("Arguments:")
    print("  <ntp-server> the server to call, default " .. ntp_server)
    os.exit(0)
end

local opts = {}
local opts_result = getopt.std("hp:t:v", opts)

if not opts_result or opts['h'] then
    help()
end

if opts.p then
    ntp_port = tonumber(opts.p)
end

if opts.t then
    timeout = tonumber(opts.t)
end

local verbose = opts.v or false
ntp_server = arg[getopt.get_optind()] or ntp_server

local dns, error = socket.dns.getaddrinfo(ntp_server)
if dns == nil or #dns == 0 then
    io.stderr:write(error .. "\n")
    os.exit(1)
end

local udp, error = socket.udp()
if udp == nil then
    io.stderr:write(error .. "\n")
    os.exit(1)
end

if timeout > 0 then
udp:settimeout(timeout)
end

local log = function(...)
    if not verbose then return end
    print(...)
end

local ntp_request = function(udp, addr, port)
    local ntp_request = struct.pack(ntp_format,
    0x1b, 0, 0, 0,                      -- (li, vn, mode), stratum, poll, precision
    0, 0, 0,                            -- delay, dispersion, id
    0, 0,                               -- reference timestamp
    0, 0,                               -- origin timestamp
    0, 0,                               -- receive timestamp
    os.time() + ntp_timestamp_delta, 0) -- transmit timestamp

    udp:setpeername(addr, port)

    local sent, error = udp:send(ntp_request)
    if sent == nil or sent ~= ntp_packet_size then
        io.stderr:write("send failed: " .. error .. "\n")
        return nil
    end

    local data, error = udp:receive()
    if data == nil then
      io.stderr:write("recv failed: " .. error .. "\n")
      return nil
    end

    return data
end

local key, value = next(dns)
while key and value do
    log("connecting to " .. ntp_server .. ":" .. ntp_port .. " ('" .. value.addr .. "')")
    local response, error = ntp_request(udp, value.addr, ntp_port)
    if response then
        local t4_sec = os.time() + ntp_timestamp_delta

        local header, stratum, poll, precision, root_delay, root_dispersion, reference_id, ref_sec, ref_fract, t1_sec, t1_fract, t2_sec, t2_fract, t3_sec, t3_fract = struct.unpack(ntp_format, response)

        log("reference: ", os.date(date_format, ref_sec - ntp_timestamp_delta))
        log("origin: ",    os.date(date_format, t1_sec - ntp_timestamp_delta))
        log("receive: ",   os.date(date_format, t2_sec - ntp_timestamp_delta))
        log("transmit:",   os.date(date_format, t3_sec - ntp_timestamp_delta))

        local delay = (t4_sec - t1_sec) - (t3_sec - t2_sec)
        local offset = ((t2_sec - t1_sec) + (t3_sec - t4_sec)) / 2

        local ntp_time = t4_sec + offset - ntp_timestamp_delta
        log("delay: " .. delay, "offset: " .. offset, "ntp_time: " .. ntp_time)

        print("time: " .. os.date(date_format, math.floor(ntp_time)))
        os.exit(0)
    end
    key, value = next(dns, key)
end
