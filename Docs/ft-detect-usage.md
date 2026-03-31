# ft-detect: Service Discovery & Tool Invocation

`ft-detect` is a command-line tool that discovers FlaschenTaschen displays on the local network using Bonjour/mDNS and can automatically invoke other tools with the display's network and geometry details.

## Building

Build as part of the ft-swift package:

```bash
swift build -c release
# Binary will be at .build/release/ft-detect
```

## Usage

### List All Displays

```bash
$ ft-detect
Brennan's Mac FT
  Address: 192.168.1.50
  Hostname: macbook-air-m4-brennan.local.
  Port: 1337
  Geometry: 64x64
  URL: https://wiki.sequoiafabrica.org/wiki/FlaschenTaschen
```

### Query for a Specific Display

**Case-insensitive partial match:**

```bash
$ ft-detect -q "Polaris"
Polaris
  Address: 192.168.1.100
  Hostname: pi.local.
  Port: 1337
  Geometry: 128x64
  URL: https://wiki.org/Polaris
```

### Output as Shell Variables

Useful for shell scripts:

```bash
$ ft-detect -q "Polaris" -f sh
FT_NAME="Polaris"
FT_HOST="192.168.1.100"
FT_PORT="1337"
FT_WIDTH="128"
FT_HEIGHT="64"
FT_URL="https://wiki.org/Polaris"

# Use in a script:
eval $(ft-detect -q "Polaris" -f sh)
send-image -h $FT_HOST -g ${FT_WIDTH}x${FT_HEIGHT} photo.jpg
```

### Output as JSON

```bash
$ ft-detect -q "Polaris" -f json
{
  "name" : "Polaris",
  "instanceName" : "Polaris",
  "hostname" : "pi.local.",
  "address" : "192.168.1.100",
  "port" : 1337,
  "width" : 128,
  "height" : 64,
  "url" : "https://wiki.org/Polaris"
}
```

### Proxy Mode: Auto-Invoke Tools

**Send image to first discovered display:**

```bash
$ ft-detect send-image photo.jpg
# Discovers first available display and runs:
# send-image -h 192.168.1.50 -g 64x64 photo.jpg
```

**Send image to a specific display:**

```bash
$ ft-detect -q "Kitchen" send-image photo.jpg
# Discovers "Kitchen" display and runs:
# send-image -h 192.168.1.101 -g 128x64 photo.jpg
```

**Verbose output (see what's happening):**

```bash
$ ft-detect -v -q "Kitchen" send-image photo.jpg
Discovered: Kitchen (192.168.1.101:1337, 128x64) [stderr]
Executing: send-image -h 192.168.1.101 -g 128x64 photo.jpg [stderr]
[send-image runs and takes over]
```

### Discovery Timeout

Default is 5 seconds. Adjust with `-t` (milliseconds):

```bash
# 2 second timeout
$ ft-detect -t 2000

# 10 second timeout
$ ft-detect -t 10000
```

## Command Reference

```
Usage: ft-detect [options] [client-tool] [client-args...]

Options:
  -l, --list              List all discovered displays and exit
  -q, --query <name>      Query for specific display name (case-insensitive partial match)
  -f, --format <sh|json>  Output format for query results (sh: shell vars, json: JSON)
  -t, --timeout <ms>      Discovery timeout in milliseconds (default: 5000)
  -v, --verbose           Verbose output (to stderr)
  -h, --help              Show this help
```

## Implementation Details

### Service Discovery

- Uses Bonjour/mDNS via `NetServiceBrowser` (native macOS)
- Searches for `_flaschen-taschen._udp` services
- Resolves services to get:
  - Hostname and IP address
  - Port (1337)
  - Display dimensions (width, height)
  - Display name and optional URL (from TXT records)

### Tool Invocation (Proxy Mode)

When invoked with a tool name:

1. Discovers display(s) using Bonjour
2. Constructs command with `-h <address>` and `-g <width>x<height>`
3. Uses `fork()` and `execvp()` to replace process
4. The child process inherits stdin/stdout/stderr
5. **ft-detect exits** and the tool takes over (no zombie processes)

Example:

```bash
$ ft-detect send-image photo.jpg
# Internally becomes:
# send-image -h 192.168.1.50 -g 64x64 photo.jpg
```

### Error Handling

- **No displays found**: Exits with code 1 and error message
- **Discovery timeout**: Returns whatever was found within timeout period
- **Query no match**: Exits with code 1
- **Service resolution failure**: Gracefully skips unresolvable services

## Integration with Existing Tools

No changes needed to `send-image`, `send-text`, or `send-video`. They already support:
- `-h <host>` for host/IP address
- `-g <width>x<height>` for geometry

Example:

```bash
# Manual invocation (old way):
send-image -h 192.168.1.50 -g 64x64 photo.jpg

# Automatic discovery (new way):
ft-detect send-image photo.jpg
```

## Troubleshooting

### No displays found

1. Verify mDNS is enabled on the server:
   ```bash
   dns-sd -B _flaschen-taschen._udp local
   ```

2. Increase timeout:
   ```bash
   ft-detect -t 10000
   ```

3. Check Bonjour is working:
   ```bash
   dns-sd -L "DisplayName" _flaschen-taschen._udp local
   ```

### Query returns wrong display

Use full instance name or more specific partial match:

```bash
ft-detect -q "Brennan's Mac"  # Instead of just "Mac"
```

### Tool invocation fails

Ensure the tool is in PATH and executable:

```bash
which send-image
chmod +x /path/to/send-image
```

## Examples

**Script: Send to all displays (rotate through)**

```bash
#!/bin/bash
eval $(ft-detect -q "" -f sh)  # First match
send-image -h $FT_HOST -g ${FT_WIDTH}x${FT_HEIGHT} photo.jpg
```

**Script: Query display info and store**

```bash
#!/bin/bash
eval $(ft-detect -q "Kitchen" -f sh)
echo "Kitchen display: ${FT_WIDTH}x${FT_HEIGHT} at $FT_HOST"
```

**One-liner: Send to specific display with verbose output**

```bash
ft-detect -v -q "Polaris" send-image /path/to/image.jpg
```
