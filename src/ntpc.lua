#! /usr/bin/env lua

------------------------------------------------------------------------------------
-- The MIT License (MIT)
--
-- Copyright (c) 2026 David Westen
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
------------------------------------------------------------------------------------

local socket = require("socket")
local struct = require("struct")
local getopt = require("getopt")

local ntp_packet_size <const>     = 48
local ntp_format <const>          = ">BBBBIIIIIIIIIII"
local ntp_timestamp_delta <const> = 2208988800
local date_format <const>         = "!%Y-%m-%dT%H:%M:%S" 

local ntp_server = "pool.ntp.org"
local ntp_port = 123
local timeout = 0

local help = function(code)
    print("Usage: ntp [options] <ntp-server>")
    print("")
    print("Options:")
    print("  -h        print this message")
    print("  -p        port to use, default: " .. ntp_port)
    print("  -t <sec>  number of seconds to wait for a response, default: " .. timeout)
    print("  -v        verbose output")
    print("Arguments:")
    print("  <ntp-server> the server to call, default " .. ntp_server)
    os.exit(code or 0)
end

local opts = {}
if not getopt.std("hp:t:v", opts) then
    help(1)
end

if opts.h then
    help()
end

if opts.p then
    ntp_port = tonumber(opts.p) or help(1)
end

if opts.t then
    timeout = tonumber(opts.t) or help(1)
end

-- function that will either call print or do nothing
local log = opts.v and print or function(...) end

ntp_server = arg[getopt.get_optind()] or ntp_server

local dns, error = socket.dns.getaddrinfo(ntp_server)
if not dns then
    io.stderr:write("getaddrinfo: " .. error .. "\n")
    os.exit(1)
end

local udp, error = socket.udp()
if not udp then 
    io.stderr:write("socket:" .. error .. "\n")
    os.exit(1)
end

if timeout > 0 and not socket.try(udp:settimeout(timeout)) then
    io.stderr:write("settimeout: error\n")
    os.exit(1)
end

local ntp_request = socket.protect(function(udp, addr, port)
    local ntp_request = struct.pack(ntp_format,
    0x1b, 0, 0, 0,                      -- (li, vn, mode), stratum, poll, precision
    0, 0, 0,                            -- delay, dispersion, id
    0, 0,                               -- reference timestamp
    0, 0,                               -- origin timestamp
    0, 0,                               -- receive timestamp
    os.time() + ntp_timestamp_delta, 0) -- transmit timestamp

    socket.try(udp:setpeername(addr, port))

    local sent = socket.try(udp:send(ntp_request))
    if sent ~= ntp_packet_size then
        error("sent " .. sent .. " bytes but expected to send " .. ntp_packet_size .. "bytes")
    end

    return socket.try(udp:receive())
end)

local key, value = next(dns)
while key and value do
    log("connecting to " .. ntp_server .. ":" .. ntp_port .. " ('" .. value.addr .. "')")
    local response, error  = ntp_request(udp, value.addr, ntp_port)
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
    else
        log(error)
    end
    key, value = next(dns, key)
end

io.stderr:write("could not reach " .. ntp_server .. ":" .. ntp_port .. "\n")
os.exit(1)
