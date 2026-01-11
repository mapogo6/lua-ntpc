# luantpc

A simple NTP client implemented in Lua.

## Overview

This project implements a simple NTP client to synchronize time with NTP servers. It includes functions for sending requests to an NTP server and processing the responses.

## Installation

To install this package using LuaRocks, run the following command:

```bash
luarocks install luantpc
```

## Usage

You can use the NTP client by running the `ntpc.lua` script. The basic usage is as follows:

```bash
lua src/ntpc.lua [options] <ntp-server>
```

### Options

- `-h`: Print help message.
- `-p <port>`: Specify the port to use (default: 123).
- `-t <sec>`: Set the number of seconds to wait for a response (default: 0).
- `-v`: Enable verbose output.

### Example

To synchronize time with the default NTP server:

```bash
lua src/ntpc.lua
```

To specify a different NTP server:

```bash
lua src/ntpc.lua -p 123 pool.ntp.org
```

## Contribution

Contributions are welcome! Please feel free to submit a pull request or open an issue for any suggestions or improvements.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.