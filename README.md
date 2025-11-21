# Bedrock Starter

A minimal starter project for [Bedrock](https://bedrockdb.com/), the rock-solid distributed database built by Expensify. This project runs on a single Ubuntu VM with systemd services, managed by Multipass.

## What is Bedrock?

Bedrock is a simple, modular, WAN-replicated, blockchain-based data foundation for global-scale applications. It's built on top of SQLite and provides:

- **Fast** - Direct memory access to SQLite with distributed read scaling
- **Simple** - Modern defaults that "just work"
- **Reliable** - Active/active distributed transactions with automatic failover
- **Powerful** - Full SQLite feature set plus plugin system with job queue and cache

## Project Structure

This starter project provides a complete development environment:

```
BedrockStarter/
├── multipass.yaml        # Multipass cloud-init configuration
├── scripts/              # Shell scripts
│   ├── launch.sh         # Cross-platform VM launcher script
│   ├── setup.sh          # Manual installation script (for non-Multipass setups)
│   └── common.sh          # Common shell utilities
├── server/
│   ├── api/              # PHP API Service
│   │   ├── composer.json # PHP dependencies
│   │   └── api.php       # REST API endpoints
│   ├── config/           # Configuration files
│   │   ├── nginx.conf    # Web server configuration
│   │   └── bedrock.service # Bedrock systemd service
│   ├── core/             # Bedrock Plugin
│   │   ├── CMakeLists.txt # C++ build configuration
│   │   ├── Core.h/.cpp   # Main plugin class (extends BedrockPlugin)
│   │   └── commands/     # Custom Bedrock commands
│   │       └── HelloWorld.h/.cpp # Example command (extends BedrockCommand)
│   └── config/           # Systemd service files
│       └── bedrock.service # Bedrock systemd service
└── README.md
```

## Services Architecture

The project runs on a single VM with multiple systemd services:

### 🔧 **Bedrock Service** (`bedrock.service`)
- **Service**: Systemd unit running Bedrock with Core plugin
- **Port**: 8888
- **Plugin**: Custom `Core` plugin with `HelloWorld` command
- **Database**: SQLite database at `/var/lib/bedrock/bedrock.db`
- **Installation**: `/opt/bedrock/Bedrock`
- **Access**: Direct socket connection or MySQL protocol

### 🌐 **API Service** (`nginx` + `php8.4-fpm`)
- **Port**: 80
- **Stack**: nginx + PHP 8.4 FPM
- **Installation**: `/opt/bedrock/server/api`
- **Endpoints**:
  - `GET /api/status` - Service health check
  - `GET /api/hello?name=World` - Hello world endpoint
- **Features**: JSON responses, CORS headers, error handling

### ⚙️ **Build System**
- **C++ Compiler**: Clang with libc++ (C++20, matches Bedrock)
- **Linker**: mold (ultra-fast linking)
- **Build Tools**: CMake + Ninja
- **Package Manager**: apt-fast (parallel downloads)
- **Compiler Cache**: ccache (2GB, compressed)
- **Optimization**: LTO, sanitizers, parallel builds

## Quick Start

### Using Multipass (Recommended - 100% Free)

Multipass is Canonical's official VM solution that works identically on Linux, macOS (ARM & Intel), and Windows. It's completely free and open source.

1. **Install Multipass:**
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
   - Detect your system architecture (ARM or x86)
   - Launch an appropriate Ubuntu VM (ARM Ubuntu on ARM Macs for native performance)
   - Install all dependencies
   - Build Bedrock and the Core plugin
   - Configure and start all services
   - Mount your project directory for real-time development sync

4. **Access the VM:**
   ```bash
   # SSH into the VM (equivalent to 'vagrant ssh')
   multipass shell bedrock-starter

   # Or run commands directly from host
   multipass exec bedrock-starter -- command
   ```

5. **Access the services:**
   ```bash
   # Get VM IP address
   multipass info bedrock-starter

   # Test Bedrock database
   VM_IP=$(multipass info bedrock-starter | grep IPv4 | awk '{print $2}')
   nc $VM_IP 8888
   Query: SELECT 1 AS hello, 'world' AS bedrock;

   # Test API
   curl http://$VM_IP/api/status
   curl http://$VM_IP/api/hello?name=Developer

   # Test custom plugin
   nc $VM_IP 8888
   HelloWorld name=Developer
   ```

6. **Port Forwarding (Optional):**
   ```bash
   # Access from localhost instead of VM IP
   multipass port-forward bedrock-starter 8888:8888  # Bedrock
   multipass port-forward bedrock-starter 80:8080    # API (host:guest)

   # Then access via localhost
   nc localhost 8888
   curl http://localhost:8080/api/status
   ```

### Manual Setup on Ubuntu 24.04

If you prefer to set up on a physical machine or cloud VM:

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd BedrockStarter
   git submodule update --init --recursive
   ```

2. **Run the setup script:**
   ```bash
   sudo ./scripts/setup.sh
   ```

3. **Start services:**
   ```bash
   sudo systemctl start bedrock
   sudo systemctl start php8.4-fpm
   sudo systemctl start nginx
   ```

4. **Enable services to start on boot:**
   ```bash
   sudo systemctl enable bedrock
   sudo systemctl enable php8.4-fpm
   sudo systemctl enable nginx
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
# Rebuild the Core plugin
multipass exec bedrock-starter -- bash -c 'cd /opt/bedrock/server/core && ninja'

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
# If you modify Bedrock itself
multipass exec bedrock-starter -- bash -c 'cd /opt/bedrock/Bedrock && make'
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
       // Implement peekCommand() and processCommand()
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
   multipass exec bedrock-starter -- bash -c 'cd /opt/bedrock/server/core && ninja'
   multipass exec bedrock-starter -- sudo systemctl restart bedrock
   ```

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
multipass exec bedrock-starter -- ls -la /opt/bedrock/server/core/lib/Core.so

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
