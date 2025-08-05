# Multi-Project Docker Repository

This repository contains multiple independent Docker projects needed by ASKAPpipeline for processing ASKAP data in the operational environment. The resulting containers provide python environments for several packages (internal and 3rd party) that various ASKAP science workflows require.

## 🏗️ **Repository Structure**

```
askappy-docker/
├── askappy-base/          # Base image with casacore & scientific tools
│   ├── Dockerfile         # Optimized multi-stage build
│   ├── build.sh          # Build script
│   ├── requirements.txt   # Python dependencies
│   └── config.py         # Casacore configuration
├── tostool/              # TOSTOOL astronomical processing tools [DISABLED]
│   ├── Dockerfile-*      # TOSTOOL Dockerfile
│   ├── build-*.sh        # TOSTOOL build script
│   └── requirements.txt  # TOSTOOL dependencies
├── .github/workflows/    # CI/CD automation
│   └── docker-build.yml  # Multi-project workflow
├── projects.yml          # Project configuration
├── Makefile             # Multi-project commands
├── manage-projects.sh    # Project management utilities
└── docker-compose.yml   # Development environment
```

## 🎯 **Available Projects**

| Project | Status | Registry | Description |
|---------|---------|----------|-------------|
| **askappy-base** | ✅ **Active** | `wasimraja81/askappy-ubuntu-24.04` | Base image with casacore and scientific computing tools |
| **tostool** | 🚧 **Disabled** | `wasimraja81/tostool-ubuntu-22.04` | TOSTOOL astronomical data processing tools |

## 🚀 **Quick Start**

### **Build and Run Projects**
```bash
# Build askappy-base
make build-askappy
# or
cd askappy-base && ./build.sh

# Test the image
make test-askappy

# Push to registry
make push-askappy

# Build all enabled projects
make build-all

# List available projects
./manage-projects.sh list

# Check project status
./manage-projects.sh status
```

## 🔧 **Project Management**

### **Using the Management Script**

```bash
# List all projects
./manage-projects.sh list

# Enable a project (removes from .gitignore)
./manage-projects.sh enable tostool

# Disable a project (adds to .gitignore)
./manage-projects.sh disable tostool

# Check project status
./manage-projects.sh status

# Validate project configurations
./manage-projects.sh validate

# Create a new project template
./manage-projects.sh create-project my-tool wasimraja81/my-tool
```

### **Adding a New Project**

1. **Create project using the template:**
   ```bash
   ./manage-projects.sh create-project new-project wasimraja81/new-project
   ```

2. **Update `projects.yml`:**
   ```yaml
   new-project:
     name: "new-project"
     registry: "docker.io"
     image_name: "wasimraja81/new-project"
     base_tag: "latest"
     enabled: true
   ```

3. **Enable the project:**
   ```bash
   ./manage-projects.sh enable new-project
   ```

### **Enabling tostool**

When ready to enable tostool:
```bash
# Enable the project
./manage-projects.sh enable tostool

# Commit changes
git add .gitignore projects.yml
git commit -m "Enable tostool project"
```

## 🏷️ **Image Tagging Strategy**

Each project uses independent tagging:

### **askappy-base**
- `wasimraja81/askappy-ubuntu-24.04:base-mpich-casacore-3.6.1`
- `wasimraja81/askappy-ubuntu-24.04:latest`
- `wasimraja81/askappy-ubuntu-24.04:develop`
- `wasimraja81/askappy-ubuntu-24.04:20250805-abc123`

### **tostool** (when enabled)
- `wasimraja81/tostool-ubuntu-22.04:mpich-casacore-3.6.1`
- `wasimraja81/tostool-ubuntu-22.04:latest`
- `wasimraja81/tostool-ubuntu-22.04:develop`

## 🔄 **CI/CD Workflow**

### **Automated Triggers**
- **Push to main/develop**: Builds affected projects
- **Pull Request**: Build-only (no push)
- **Release**: Builds all projects with version tags
- **Manual**: Choose specific project or "all"

### **Smart Change Detection**
The workflow automatically detects which projects need rebuilding:
- Changes in `askappy-base/` → builds askappy-base
- Changes in `tostool/` → builds tostool (when enabled)
- No unnecessary builds!

### **GitHub Secrets Required**
```bash
DOCKERHUB_USERNAME=wasimraja81
DOCKERHUB_TOKEN=your-docker-hub-token
```

## 📋 **Development Workflow**

### **Working on askappy-base**
```bash
# Make changes to askappy-base/
vim askappy-base/Dockerfile

# Test locally
make build-askappy-local
make test-askappy

# Commit and push (triggers CI)
git add askappy-base/
git commit -m "Update askappy-base"
git push origin develop
```

### **Working on multiple projects**
```bash
# Build all enabled projects
make build-all
make test-all

# Check status
./manage-projects.sh status
make info
```

## 🔍 **Project Isolation Benefits**

✅ **Independent registries** - Each project has its own Docker Hub repository  
✅ **Isolated builds** - Changes only affect relevant projects  
✅ **Separate versioning** - Each project can evolve independently  
✅ **Efficient CI/CD** - Only builds what changed  
✅ **Scalable** - Easy to add new projects  
✅ **Maintainable** - Clear separation of concerns  

## 🎯 **Current Status**

- ✅ **askappy-base**: Fully operational with optimized multi-stage build
- 🚧 **tostool**: Prepared but disabled (excluded from git until ready)
- ✅ **CI/CD**: Multi-project workflow active and ready
- ✅ **Project Management**: Complete utilities for managing multiple projects
- ✅ **Documentation**: Updated for current multi-project architecture

## 🔜 **Next Steps**

1. **Set up Docker Hub credentials** in GitHub secrets
2. **Commit and test askappy-base** build
3. **Enable tostool** when ready using `./manage-projects.sh enable tostool`
4. **Add new projects** using the management utilities
5. **Scale the workflow** as needed for additional projects

This setup gives you maximum flexibility while maintaining clean separation between projects! 🚀
