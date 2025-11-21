# Bedrock Starter

A minimal starter project for [Bedrock](https://bedrockdb.com/), the rock-solid distributed database built by Expensify. This project runs on a single Ubuntu VM with systemd services, managed by Multipass.

## Project Structure

This starter project provides a complete Bedrock + API development environment:

```
BedrockStarter/
├── multipass.yaml          # Multipass + cloud-init config for the dev VM
├── scripts/                # Dev/CI helper scripts (launch, setup, tests, lint, logs)
├── Bedrock/                # Bedrock database submodule (external dependency)
└── server/
    ├── api/                # PHP API service (routes in api.php, deps in composer.json)
    ├── core/               # Custom Bedrock plugin ("Core")
    │   ├── commands/       # Example commands (HelloWorld, message CRUD, etc.)
    │   └── test/           # C++ tests for the Core plugin
    └── config/             # Nginx + systemd templates for Bedrock and API
```

## Services and Toolchain

The project runs on a single VM with two services and a modern C++ toolchain.

### 🔧 **Bedrock Service** (`bedrock.service`)
- **Unit**: Systemd service running Bedrock with the `Core` plugin
- **Port**: `8888` (SQL + Bedrock commands)
- **Database file**: `/var/lib/bedrock/bedrock.db`
- **Binary directory**: `/opt/bedrock/Bedrock`

### 🌐 **API Service** (`nginx` + `php8.4-fpm`)
- **Units**: `nginx` + `php8.4-fpm`
- **Code root**: `/opt/bedrock/server/api`
- **Port**: `80` (HTTP)
- **Sample endpoints**: `/api/status`, `/api/hello?name=World`

### ⚙️ **Build System**
- **Toolchain**: Clang (C++20) + libc++, CMake + Ninja, mold, ccache
- **Extras**: apt-fast for faster installs, sanitizers in debug, LTO in release

## Quick Start
1. **Install Multipass:**

   Multipass is Canonical's official VM solution that works identically on Linux, macOS (ARM & Intel), and Windows. It's completely free and open source.

   ```bash
   # macOS
   brew install multipass

   # Linux (Snap)
   snap install multipass

   # Windows
   # Download installer from https://multipass.run/install
   ```

2. **Clone and initialize:**

   ```bash
   git clone <repository-url>
   cd BedrockStarter
   git submodule update --init --recursive
   ```

3. **Launch the VM:**

   ```bash
   ./scripts/launch.sh
   ```

   This will:
   - Detect your OS and system architecture (ARM or x86)
   - Launch an appropriate Ubuntu VM
   - Install all dependencies
   - Build Bedrock and the Core plugin
   - Configure and start all services
   - Mount your project directory for real-time development sync
   - Configure clangd for IDE intellisense

4. **Access the VM:**

   ```bash
   # SSH into the VM
   multipass shell bedrock-starter

   # Note: it will automatically open to `~`, but the project directory in the VM is `/bedrock-starter`

   # launch.sh also aliases "bedrock-starter" to "primary", so this simpler alternative also works
   multipass shell

   # Or run commands directly from host
   multipass exec bedrock-starter -- command
   ```

5. **Access the services:**

   ```bash
   # Get VM IP address
   VM_IP=$(multipass info bedrock-starter | grep IPv4 | awk '{print $2}')

   # Test API endpoints
   curl http://$VM_IP/api/status
   curl http://$VM_IP/api/hello?name=Rory
   ```

## Development Workflow

### Real-Time File Syncing

Your project directory is automatically mounted at `/bedrock-starter` in the VM, providing **real-time bidirectional sync**:

- Edit files locally in your IDE
- Changes appear immediately in the VM
- Changes made in the VM appear on your host
- No manual copying needed!

### Rebuilding After Code Changes

**C++ Plugin Changes:**
```bash
# Rebuild the Core plugin (using all available CPU cores)
multipass exec bedrock-starter -- bash -c 'cd /opt/bedrock/server/core/.build && ninja -j $(nproc)'

# Copy plugin to install location
multipass exec bedrock-starter -- sudo cp /bedrock-starter/server/core/.build/lib/Core.so /opt/bedrock/server/core/.build/lib/

# Restart Bedrock to load new plugin
multipass exec bedrock-starter -- sudo systemctl restart bedrock
```

**PHP API Changes:**
```bash
# PHP changes are picked up automatically (no rebuild needed)
# Just restart nginx if you changed nginx.conf
multipass exec bedrock-starter -- sudo systemctl restart nginx
```

**Bedrock Changes:**
```bash
# If you modify Bedrock itself (using all available CPU cores)
multipass exec bedrock-starter -- bash -c 'cd /opt/bedrock/Bedrock && make --jobs $(nproc)'
multipass exec bedrock-starter -- sudo systemctl restart bedrock
```

## Service Management

### Starting and Stopping Services

```bash
# Shell into the VM
multipass shell bedrock-starter

# Then use standard systemctl commands
sudo systemctl start bedrock
sudo systemctl stop bedrock
sudo systemctl restart bedrock

# Or run commands directly from host
multipass exec bedrock-starter -- sudo systemctl restart bedrock
```

### Checking Service Status

```bash
# Check status from host
multipass exec bedrock-starter -- systemctl status bedrock
multipass exec bedrock-starter -- systemctl status php8.4-fpm
multipass exec bedrock-starter -- systemctl status nginx

# Or shell into VM and check
multipass shell bedrock-starter
systemctl status bedrock
```

### Viewing Logs

Use the colorized log viewer:

```bash
# Watch Bedrock logs (colorized)
./scripts/watch-logs.sh

# Watch nginx error logs
./scripts/watch-logs.sh -s nginx

# Watch PHP-FPM logs
./scripts/watch-logs.sh -s php

# Filter for specific patterns
./scripts/watch-logs.sh -f HelloWorld
./scripts/watch-logs.sh -f "error|warn"

# Combine service and filter
./scripts/watch-logs.sh -s bedrock -f "HelloWorld"
```

Or use journalctl/tail directly:

```bash
# View Bedrock logs
multipass exec bedrock-starter -- sudo journalctl -u bedrock -f

# View PHP-FPM logs
multipass exec bedrock-starter -- sudo journalctl -u php8.4-fpm -f

# View nginx logs
multipass exec bedrock-starter -- sudo tail -f /var/log/nginx/api_access.log
multipass exec bedrock-starter -- sudo tail -f /var/log/nginx/api_error.log
```

### VM Management

```bash
# List VMs
multipass list

# Stop VM
multipass stop bedrock-starter

# Start VM
multipass start bedrock-starter

# Delete VM (and all data)
multipass delete bedrock-starter --purge

# Shell into VM
multipass shell bedrock-starter

# Get VM info
multipass info bedrock-starter
```

## Development

### Adding New API Endpoints

Edit `server/api/api.php` to add new REST endpoints:

```php
case '/api/myendpoint':
    handleMyEndpoint();
    break;
```

After making changes, restart nginx:
```bash
multipass exec bedrock-starter -- sudo systemctl restart nginx
```

### Creating New Bedrock Commands

1. Create a new command class in `server/core/commands/`:
   ```cpp
   class MyCommand : public BedrockCommand {
       // Implement peek() and process()
   };
   ```

2. Register it in `server/core/Core.cpp`:
   ```cpp
   if (SIEquals(baseCommand.request.methodLine, "MyCommand")) {
       return make_unique<MyCommand>(std::move(baseCommand), this);
   }
   ```

3. Rebuild the plugin:
   ```bash
   multipass exec bedrock-starter -- bash -c 'cd /opt/bedrock/server/core && ninja -j $(nproc)'
   multipass exec bedrock-starter -- sudo systemctl restart bedrock
   ```

#### Peek vs. Process

Bedrock commands have two main lifecycle methods: `peek()` and `process()`.

**Flow:**
1. Request arrives at a node (e.g., a follower).
2. **`peek()` is run.**
   - If it returns `true`: Command is finished, response is sent.
   - If it returns `false`: Command is escalated to the leader.
3. **On the leader:**
   - **`peek()` is run again.**
     - If it returns `true`: Command is finished, response is sent.
     - If it returns `false`: **`process()` is run.**

**Why?**
- **Load Reduction:** `peek()` allows read-only commands or validation to run on followers, reducing load on the leader.
- **Read Commands:** Should define `peek()` and always return `true`.
- **Write Commands:**
  - Can use `peek()` for validation. If invalid, throw an error (saving leader load).
  - If valid, return `false` to escalate to the leader for the actual write in `process()`.
  - `process()` is only run on the leader and is the only place writes to the DB are allowed.

## Running Tests

Core plugin smoke tests live in `server/core/test`.

```bash
# Build and run all tests (works on host or inside the VM)
./scripts/test-cpp.sh

# Run a single test or enable verbose logging
./scripts/test-cpp.sh -only Core_HelloWorld
./scripts/test-cpp.sh -v
```

## Continuous Integration

GitHub Actions workflows run automatically on pull requests:

- **Shellcheck** - Lints all shell scripts in `scripts/`
- **C++ Tests** - Builds and runs Core plugin tests
- **Clang-Tidy** - Static analysis on C++ code

Workflows are defined in `.github/workflows/` and run when relevant files change.

## Example Queries

### Basic SQL

Connect to Bedrock:
```bash
VM_IP=$(multipass info bedrock-starter | grep IPv4 | awk '{print $2}')
nc $VM_IP 8888
```

Then run SQL queries:
```
Query: CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);
Query: INSERT INTO users (name) VALUES ('Alice'), ('Bob');
Query: SELECT * FROM users;
```

### JSON Output

```
Query
query: SELECT * FROM users;
format: json
```

### Using MySQL Client

```bash
VM_IP=$(multipass info bedrock-starter | grep IPv4 | awk '{print $2}')
mysql -h $VM_IP -P 8888
```

## File Locations

- **Bedrock**: `/opt/bedrock/Bedrock/`
- **Core Plugin**: `/opt/bedrock/server/core/`
- **API**: `/opt/bedrock/server/api/`
- **Database**: `/var/lib/bedrock/bedrock.db`
- **Service Config**: `/etc/systemd/system/bedrock.service` (source: `server/config/bedrock.service`)
- **Nginx Config**: `/etc/nginx/sites-available/bedrock-api` (source: `server/config/nginx.conf`)
- **Mounted Project**: `/bedrock-starter/` (synced with host)
- **Logs**: `journalctl -u bedrock` and `/var/log/nginx/`

## Troubleshooting

### VM Won't Start

```bash
# Check Multipass status
multipass list

# Check VM info
multipass info bedrock-starter

# View VM logs
multipass get local.privileged
```

### Service Won't Start

```bash
# Check service status
multipass exec bedrock-starter -- sudo systemctl status bedrock

# View detailed logs
multipass exec bedrock-starter -- sudo journalctl -u bedrock -n 50
```

### Plugin Not Loading

```bash
# Verify plugin library exists
multipass exec bedrock-starter -- ls -la /opt/bedrock/server/core/.build/lib/Core.so

# Check LD_LIBRARY_PATH
multipass exec bedrock-starter -- sudo systemctl show bedrock | grep Environment
```

### API Not Responding

```bash
# Check nginx and PHP-FPM
multipass exec bedrock-starter -- sudo systemctl status nginx
multipass exec bedrock-starter -- sudo systemctl status php8.4-fpm

# Test PHP-FPM socket
multipass exec bedrock-starter -- ls -la /run/php/php8.4-fpm.sock
```

### Mount Issues

If file syncing isn't working:

```bash
# Check mount status
multipass info bedrock-starter

# Remount if needed
multipass unmount bedrock-starter
multipass mount . bedrock-starter:/bedrock-starter
```

### Architecture Issues

If you're on an ARM Mac and want to use x86 Ubuntu (for compatibility testing):

```bash
# Delete existing VM
multipass delete bedrock-starter --purge

# Launch with x86 image (slower due to emulation)
multipass launch ubuntu/amd64 --name bedrock-starter --memory 4G --cpus 4 --cloud-init multipass.yaml
```

## Build Configuration

The C++ build system uses modern tooling for maximum performance:

**Compilation Speed:**
- **apt-fast**: Parallel package downloads (up to 10x faster)
- **ccache**: Compiler caching (2GB compressed cache)
- **Clang**: Modern C++20 compiler with libc++ (matches Bedrock)
- **mold linker**: Ultra-fast linking (5-10x faster than gold/bfd)

**Build Modes:**
- **Debug builds**: AddressSanitizer + UndefinedBehaviorSanitizer
- **Release builds**: Link-time optimization (LTO) for maximum performance

**Performance Benefits:**
- **First build**: Standard compile time, populates caches
- **Subsequent builds**: Near-instant with ccache hits

## Why Multipass?

- ✅ **100% Free** - Open source, no commercial licenses required
- ✅ **Cross-platform** - Works identically on Linux, macOS (ARM & Intel), Windows
- ✅ **Official** - Maintained by Canonical (Ubuntu's creators)
- ✅ **Simple** - Single command to launch VMs
- ✅ **Native Performance** - Runs ARM Ubuntu natively on ARM Macs (fast), x86 Ubuntu on x86 systems
- ✅ **Real-time Sync** - Bidirectional file syncing via `multipass mount`
- ✅ **No Complex Setup** - No need for VirtualBox, Parallels, or other providers

## Coming from Vagrant?

If you're familiar with Vagrant, here's the Multipass equivalent:

| Vagrant Command | Multipass Equivalent |
|----------------|---------------------|
| `vagrant up` | `./scripts/launch.sh` or `multipass launch` |
| `vagrant ssh` | `multipass shell bedrock-starter` |
| `vagrant halt` | `multipass stop bedrock-starter` |
| `vagrant destroy` | `multipass delete bedrock-starter --purge` |
| `vagrant status` | `multipass list` |
| `vagrant provision` | `multipass exec bedrock-starter -- sudo bash /bedrock-starter/scripts/setup.sh` |
| Synced folders (automatic) | `multipass mount . bedrock-starter:/bedrock-starter` (manual, but real-time) |

## Resources

- [Bedrock Documentation](https://bedrockdb.com/)
- [Bedrock GitHub](https://github.com/Expensify/Bedrock)
- [Multipass Documentation](https://multipass.run/docs)
- [Systemd Documentation](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
