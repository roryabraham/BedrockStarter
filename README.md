# Bedrock Starter

A minimal Docker-based starter project for [Bedrock](https://bedrockdb.com/), the rock-solid distributed database built by Expensify.

## What is Bedrock?

Bedrock is a simple, modular, WAN-replicated, blockchain-based data foundation for global-scale applications. It's built on top of SQLite and provides:

- **Fast** - Direct memory access to SQLite with distributed read scaling
- **Simple** - Modern defaults that "just work" 
- **Reliable** - Active/active distributed transactions with automatic failover
- **Powerful** - Full SQLite feature set plus plugin system with job queue and cache

## Project Structure

This starter project provides a complete development environment with:

```
BedrockStarter/
├── docker-compose.yml          # Multi-service orchestration
├── server/
│   ├── api/                    # PHP API Service
│   │   ├── Dockerfile         # API container definition
│   │   ├── start.sh           # API service startup
│   │   ├── nginx.conf         # Web server configuration
│   │   ├── composer.json      # PHP dependencies
│   │   └── api.php           # REST API endpoints
│   └── core/                   # Bedrock Database Service
│       ├── Dockerfile         # Bedrock + plugin container
│       ├── CMakeLists.txt     # C++ build configuration
│       ├── Core.h/.cpp        # Main plugin class (extends BedrockPlugin)
│       └── commands/          # Custom Bedrock commands
│           └── HelloWorld.h/.cpp  # Example command (extends BedrockCommand)
└── README.md
```

## Services Architecture

The project uses a microservices architecture with separate containers:

### 🔧 **Bedrock Service** (`bedrock-1`)
- **Container**: Built from `server/core/Dockerfile`
- **Port**: 8888
- **Plugin**: Custom `Core` plugin with `HelloWorld` command
- **Database**: SQLite with full Bedrock features
- **Access**: Direct socket connection or MySQL protocol
- **Scaling**: Support for 3-node cluster (uncomment nodes 2 & 3)

### 🌐 **API Service** (`api`)
- **Container**: Built from `server/api/Dockerfile`
- **Port**: 80
- **Stack**: nginx + PHP 8.4 FPM
- **Endpoints**:
  - `GET /api/status` - Service health check
  - `GET /api/hello?name=World` - Hello world endpoint
- **Features**: JSON responses, CORS headers, error handling
- **Communication**: Connects to Bedrock service via internal network

### ⚙️ **Build System**
- **C++ Compiler**: Clang with libc++ (C++20, matches Bedrock)
- **Linker**: mold (ultra-fast linking)
- **Build Tools**: CMake + Ninja
- **Package Manager**: apt-fast (parallel downloads)
- **Compiler Cache**: ccache (2GB, compressed)
- **Optimization**: LTO, sanitizers, parallel builds

## Quick Start

### Using Docker Compose

1. **Start all services:**
   ```bash
   docker compose up --build
   ```

2. **Start individual services:**
   ```bash
   # Just the API service
   docker compose up api
   
   # Just the Bedrock service
   docker compose up bedrock-1
   ```

3. **Test the services:**
   ```bash
   # Test API
   curl http://localhost/api/status
   curl http://localhost/api/hello?name=Developer
   
   # Test Bedrock database
   nc localhost 8888
   Query: SELECT 1 AS hello, 'world' AS bedrock;
   
   # Test custom plugin
   nc localhost 8888
   HelloWorld name=Developer
   ```

4. **Stop services:**
   ```bash
   docker compose down
   ```

### 3-Node Cluster Setup

For production-like distributed setup:

1. **Uncomment `bedrock-2` and `bedrock-3`** in `docker-compose.yml`

2. **Start the cluster:**
   ```bash
   docker compose up --build
   ```

3. **Access different Bedrock nodes:**
   ```bash
   # Node 1 (Primary)
   nc localhost 8888
   
   # Node 2 (Follower)  
   nc localhost 8889
   
   # Node 3 (Follower)
   nc localhost 8890
   ```

### Service Scaling

Scale individual services independently:

```bash
# Scale API service (multiple instances)
docker compose up --scale api=2

# Scale with load balancer (uncomment api-2 first)
docker compose up api api-2
```

### Example Queries

**Basic SQL:**
```sql
Query: CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);
Query: INSERT INTO users (name) VALUES ('Alice'), ('Bob');
Query: SELECT * FROM users;
```

**JSON Output:**
```
Query
query: SELECT * FROM users;
format: json
```

**Using MySQL client:**
```bash
mysql -h 127.0.0.1 -P 8888
```

## Development

### Adding New API Endpoints

Edit `server/api/api.php` to add new REST endpoints:

```php
case '/api/myendpoint':
    handleMyEndpoint();
    break;
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
   registerCommand(new MyCommand(*this));
   ```

3. Rebuild the plugin:
   ```bash
   # Rebuild Bedrock service with updated plugin
   docker compose build bedrock-1
   docker compose restart bedrock-1
   
   # Or rebuild within running container
   docker compose exec bedrock-1 bash
   cd /app/core
   ninja
   # Container will restart automatically
   ```

### Service Management

**Docker Compose Commands:**
```bash
# View logs
docker compose logs -f
docker compose logs -f bedrock-1  # Specific service
docker compose logs -f api

# Check service status
docker compose ps
docker compose exec bedrock-1 ps aux  # Check processes
docker compose exec api ps aux

# Restart services
docker compose restart
docker compose restart bedrock-1      # Specific service
docker compose restart api

# Rebuild and restart
docker compose build bedrock-1
docker compose up -d bedrock-1
```

**Service Health:**
```bash
# Check health status
docker compose ps
curl http://localhost/api/status      # API health
nc -z localhost 8888                  # Bedrock connectivity

# View service logs
docker compose logs bedrock-1
docker compose logs api
```

### Build Configuration

The C++ build system uses cutting-edge tooling for maximum performance:

**Compilation Speed:**
- **apt-fast**: Parallel package downloads (up to 10x faster)
- **ccache**: Compiler caching (2GB compressed cache)
- **Clang**: Modern C++20 compiler with libc++ (matches Bedrock)
- **mold linker**: Ultra-fast linking (5-10x faster than gold/bfd)

**Build Modes:**
- **Debug builds**: AddressSanitizer + UndefinedBehaviorSanitizer
- **Release builds**: Link-time optimization (LTO) for maximum performance
- **Development**: Live code reloading with Docker volumes

**Performance Benefits:**
- **First build**: Standard compile time, populates caches
- **Subsequent builds**: Near-instant with ccache hits
- **Docker rebuilds**: Persistent caches across container rebuilds
