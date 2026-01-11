package = "ntpc"
version = "1.0-0"
source = { url = "https://github.com/mapogo6/lua-ntpc" }
description = {
    summary = "A simple NTP client in Lua",
    detailed = "This project implements a simple NTP client to synchronize time.",
    license = "MIT"
}
dependencies = { "luasocket", "lua-struct", "getopt" }
build = {
    type = "builtin",
    modules = {},
    install = {
        bin = {
            ["ntpc"] = "src/ntpc.lua"
        }
    }
}