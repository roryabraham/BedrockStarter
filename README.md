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

3. Rebuild the plugin (from the host):
   ```bash
   ./scripts/build-core-plugin.sh
   ```

#### Peek vs. Process

Bedrock commands have two main lifecycle methods: `peek()` and `process()`.

1. Request arrives at a node (e.g., a follower).
2. **`peek()` is run.**
   - If it returns `true`: Command is finished, response is sent.
   - If it returns `false`: Command is escalated to the leader.
3. **On the leader:**
   - **`peek()` is run again.**
     - If it returns `true`: Command is finished, response is sent.
     - If it returns `false`: **`process()` is run.**

- **Load Reduction:** `peek()` allows read-only commands or validation to run on followers, reducing load on the leader.
- **Read Commands:** Should define `peek()` and always return `true`.
- **Write Commands:**
  - Can use `peek()` for validation. If invalid, throw an error (saving leader load).
  - If valid, return `false` to escalate to the leader for the actual write in `process()`.
  - `process()` is only run on the leader and is the only place writes to the DB are allowed.

## Running Tests

Core plugin unit tests live in `server/core/test`.

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

## Build Configuration

This section summarizes how C++ code is built in the VM.

- **Toolchain**
  - **Compiler**: `clang` / `clang++` (C++20, libc++), configured in `scripts/setup.sh`
  - **Build systems**: CMake + Ninja for the Core plugin and tests; GNU Make for the upstream Bedrock submodule
  - **Linker**: `mold` via `-fuse-ld=mold` flags in `server/core/CMakeLists.txt`

- **Core plugin & tests (`server/core`)**
  - CMake project root: `server/core/CMakeLists.txt`
  - Local dev build directory: `server/core/.build`
  - Installed plugin build directory in the VM: `/opt/bedrock/server/core/.build`
  - Default flags:
    - **Debug**: `-O0 -g` with AddressSanitizer and UndefinedBehaviorSanitizer
    - **Release**: `-O3 -DNDEBUG` with LTO

- **Bedrock submodule (`Bedrock/`)**
  - Built with the upstream Makefile: `make bedrock --jobs $(nproc)` (run automatically by `scripts/setup.sh` and on demand by `scripts/test-cpp.sh`)
  - Installed under `/opt/bedrock/Bedrock` by `scripts/setup.sh`

- **Caching and packages (inside the VM)**
  - `apt-fast` is used for package installs
  - `ccache` is configured with a shared cache in `/var/cache/ccache` (2GB, compressed)
