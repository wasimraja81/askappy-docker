# Patches for ASKAP TOS Tools - Python 3.10 Compatibility

This directory contains patches applied during the Docker build process to ensure Python 3.10 compatibility with the ASKAP TOS tools.

## Applied Patches

### python-iceutils-python310-compat.patch

**Issue**: `typing.Self` was introduced in Python 3.11, causing import errors in Python 3.10
**File**: `src/askap/iceutils/icesession.py`
**Solution**: Added compatibility import using `typing_extensions` for Python < 3.11

**Changes**:
1. Added conditional import for `typing.Self` with `typing_extensions` fallback
2. Added `typing_extensions >= 4.0; python_version < '3.11'` dependency to pyproject.toml

**Root Cause**: ASKAP python-iceutils uses `typing.Self` which is not available in Python 3.10

**Original Error**:
```
ImportError: cannot import name 'Self' from 'typing' (/usr/lib/python3.10/typing.py)
```

## Usage in Dockerfile

```dockerfile
# Apply Python 3.10 compatibility patches
COPY patches/python-iceutils-python310-compat.patch /tmp/
RUN cd ${BUILD_DIR}/python-iceutils && \
    patch -p1 < /tmp/python-iceutils-python310-compat.patch
```

## Upstream Information

- Repository: ASKAP TOS python-iceutils
- Version: As cloned by build.sh
- Patch Status: Should be submitted upstream for Python 3.10 compatibility
- Maintenance: These patches should be removed when upstream supports Python 3.10 or when we upgrade to Python 3.11+
