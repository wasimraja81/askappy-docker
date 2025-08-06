# askappy-docker: Multi-Project Build System

This repository contains multiple independent Docker projects for ASKAP astronomical data processing. The build system provides a complete scientific computing environment with flexible deployment options.

## 🏗️ **Architecture Overview**

```
askappy-docker/
├── askappy-base/          # 🧱 Base image (Ubuntu 24.04 + casacore + scientific tools)
│   ├── Dockerfile         # Multi-stage build optimized for size and security
│   ├── build.sh          # Registry build script
│   ├── requirements.txt   # Python scientific dependencies
│   └── config.py         # Casacore configuration
├── tostool/              # 🔭 ASKAP TOS tools (builds on askappy-base)
│   ├── Dockerfile        # ASKAP tools installation
│   ├── build.sh          # Production build with registry push
│   └── requirements.txt  # ASKAP-specific dependencies
├── Makefile              # 🚀 Complete build automation
└── README.md            # This file
```

### **🔗 Dependency Chain**
```
Ubuntu 24.04 → askappy-base (881MB) → tostool (914MB)
     ↑              ↑                    ↑
 Base OS    Scientific Stack      ASKAP Tools
```

## 🎯 **Available Projects**

| Project | Status | Size | Registry | Description |
|---------|---------|------|----------|-------------|
| **askappy-base** | ✅ **Ready** | 881MB | `wasimraja81/askappy-ubuntu-24.04` | Ubuntu 24.04 + MPICH 4.3.1 + Casacore 3.6.1 + Scientific Python |
| **tostool** | ✅ **Ready** | 914MB | `wasimraja81/tostool-ubuntu-24.04` | ASKAP TOS tools v2.28.0 + schedblock + parset utilities |

## 🚀 **Quick Start**

### **Basic Usage**
```bash
# Show all available commands
make help

# Build askappy-base (independent - builds from scratch)
make build-askappy-local    # Local development build
make build-askappy          # Registry build + push

# Build tostool (depends on askappy-base)
make build-tostool-local-base     # Uses local askappy-base (fastest)
make build-tostool-registry-base  # Uses registry askappy-base (testing)
make build-tostool                # Production build + push

# Test images
make test-askappy-local
make test-tostool-local-base

# Clean up
make clean-temp    # Remove temporary files
make clean         # Docker cleanup
```

### **Release Management**
```bash
# Create and build a release
git tag v2.28.1
git push origin v2.28.1
make tag-release   # Auto-builds and pushes with tag + SHA

# Check build information
make info
make status
```

## 📋 **Complete Command Reference**

```
askappy-docker Multi-Project Build System
=============================================

Available commands:

  help                      Show this help message
  list-projects             List all available projects
  build-all                 Build all enabled projects
  test-all                  Test all enabled projects
  push-all                  Push all enabled projects
  build-askappy             Build askappy-base Docker image
  build-askappy-local       Build askappy-base locally without pushing
  test-askappy-local        Test askappy-base local image
  test-askappy              Test askappy-base Docker image
  push-askappy              Push askappy-base to Docker Hub
  build-tostool             Build and PUSH tostool to Docker Hub [PRODUCTION]
  build-tostool-local-base  Build tostool locally (uses LOCAL base image, no push)
  build-tostool-registry-base Build tostool locally (uses REGISTRY base image, no push)
  test-tostool              Test tostool Docker image (production registry version)
  test-tostool-local-base   Test tostool built with local base image
  test-tostool-registry-base Test tostool built with registry base image
  push-tostool              Push tostool to Docker Hub
  dev-up                    Start development environment
  dev-down                  Stop development environment
  dev-logs                  Show development environment logs
  clean                     Clean up Docker resources
  clean-temp                Clean up temporary build files
  clean-project             Clean images for specific project
  lint                      Lint all Dockerfiles
  security-scan-askappy     Run security scan on askappy-base
  info                      Show build information
  status                    Show current Docker status
  setup                     Initial setup for development
  tag-release               Tag and build release version (auto-detects git tag)
  ci-build-askappy          Build askappy-base for CI/CD
  ci-test-askappy           Test askappy-base CI build
  enable-tostool            Enable tostool project (remove from gitignore)

Project-specific commands:
  build-askappy                Build askappy-base image
  build-askappy-local          Build askappy-base locally (no push)
  build-tostool                Build + PUSH tostool (production)
  build-tostool-local-base     Build tostool using LOCAL base (dev)
  build-tostool-registry-base  Build tostool using REGISTRY base (test)
  test-askappy                 Test askappy-base image
  test-askappy-local           Test askappy-base local image
  test-tostool-local-base      Test local-base build
  push-askappy                 Push askappy-base image
  clean-temp                   Clean temporary files
  tag-release                  Tag and build release version

Examples:
  make build-askappy      # Build askappy-base project
  make test-askappy       # Test askappy-base project
  make build-all          # Build all enabled projects
```

## 🏗️ **Build Strategy & Dependencies**

### **askappy-base (Independent)**
- **Can build from scratch** - No dependencies on other containers
- **Build options:**
  - `make build-askappy` - Registry build + push to Docker Hub
  - `make build-askappy-local` - Local development build (fastest)
- **Base:** Ubuntu 24.04 with PEP 668 compliance
- **Includes:** MPICH 4.3.1, Casacore 3.6.1, Scientific Python stack

### **tostool (Dependent)**
- **Requires askappy-base** - Builds on top of askappy-base image
- **Build options:**
  - `make build-tostool` - Production: Uses registry base + pushes to Docker Hub
  - `make build-tostool-local-base` - Development: Uses local askappy-base (fastest iteration)
  - `make build-tostool-registry-base` - Testing: Uses registry askappy-base (integration testing)
- **Includes:** ASKAP TOS tools v2.28.0, schedblock, parset utilities
- **Security:** Uses local Git credentials, no SSH keys in containers

### **Validation Testing**
```bash
# Test ASKAP command-line tools
docker run --rm wasimraja81/tostool-ubuntu-24.04:2.28.0-local schedblock info -h

# Test Python environment
docker run --rm wasimraja81/tostool-ubuntu-24.04:2.28.0-local \
  python3 -c "import casacore, numpy; print('✅ Working')"
```

## 🎯 **Development Workflows**

### **Working on askappy-base Only**
```bash
# Edit askappy-base files
vim askappy-base/Dockerfile

# Quick local test
make build-askappy-local
make test-askappy-local

# Clean iteration (no external dependencies)
make clean-temp
```

### **Working on tostool**
```bash
# First ensure you have a working askappy-base
make build-askappy-local    # Build base dependency

# Fast iteration using local base
make build-tostool-local-base
make test-tostool-local-base

# Integration test with registry base
make build-tostool-registry-base
make test-tostool-registry-base
```

### **Release Process**
```bash
# Create release tag
git tag v2.28.1
git push origin v2.28.1

# Automated release build (builds both projects with version tags)
make tag-release

# Resulting images:
# - wasimraja81/askappy-ubuntu-24.04:v2.28.1
# - wasimraja81/askappy-ubuntu-24.04:v2.28.1-abc123 (with SHA)
# - wasimraja81/tostool-ubuntu-24.04:v2.28.1
# - wasimraja81/tostool-ubuntu-24.04:v2.28.1-abc123 (with SHA)
```

## � **Security & Best Practices**

### **No SSH Keys in Containers**
- ✅ Uses local Git credential cloning
- ✅ COPY strategy instead of git clone inside containers
- ✅ Minimal attack surface

### **Multi-Architecture Support**
- ✅ linux/amd64 (Intel/AMD)
- ✅ linux/arm64 (Apple Silicon, ARM servers)
- ✅ Buildx with automatic platform detection

### **Ubuntu 24.04 Compliance**
- ✅ PEP 668 externally-managed environment
- ✅ `--break-system-packages` for pip installations
- ✅ Clean multi-stage builds for optimal size

## 🔍 **Troubleshooting**

### **Common Issues**

**"No space left on device"**
```bash
make clean        # Clean Docker cache
make clean-temp   # Remove temporary files
docker system df  # Check space usage
```

**"Image not found locally"**
```bash
# Ensure local images are built with --load flag
make build-askappy-local

# Check available images
make status
```

**"Git credentials required"**
```bash
# Ensure SSH key is configured for CSIRO Bitbucket
ssh -T git@bitbucket.csiro.au

# Or check Git credential helper
git config --get credential.helper
```

### **Build Information**
```bash
make info     # Shows dependency chain, tags, git status
make status   # Shows Docker builder status and available images
```

## 🎯 **Current Status & Next Steps**

### **✅ Completed**
- ✅ Ubuntu 24.04 migration complete
- ✅ Flexible build system with local/registry options  
- ✅ Security improvements (no SSH keys in containers)
- ✅ Automated testing and validation
- ✅ Release management with git tag integration
- ✅ Complete documentation

### **🚀 Ready for Production**
- Both askappy-base and tostool are production-ready
- Complete CI/CD workflow for automated builds
- Flexible development and testing options
- Comprehensive validation testing

### **Next Steps**
1. **Set up automated CI/CD** triggers on git tag pushes
2. **Enable registry automation** for release builds
3. **Add monitoring** for container health and performance
4. **Scale workflow** for additional ASKAP tools as needed

---