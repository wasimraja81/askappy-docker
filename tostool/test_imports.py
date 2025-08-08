


import sys
import traceback
import re

failures = []
detailed_errors = []

def parse_import_line(line):
    # Remove comments and whitespace
    line = line.split('#', 1)[0].strip()
    if not line:
        return None
    # Handle severity
    parts = line.split()
    if not parts:
        return None
    # If 'from ... import ...' convert to 'import ...[.submodule]'
    if parts[0] == 'from' and 'import' in parts:
        mod = parts[1]
        sub = parts[3]
        import_stmt = f"import {mod}.{sub}"
        severity = parts[4].upper() if len(parts) > 4 and parts[4].upper() in ("FATAL", "WARNING") else "FATAL"
        desc = f"{mod}.{sub}"
        return (import_stmt, severity, desc)
    elif parts[0] == 'import':
        # e.g. import numpy.typing WARNING
        mod = parts[1]
        severity = parts[2].upper() if len(parts) > 2 and parts[2].upper() in ("FATAL", "WARNING") else "FATAL"
        desc = mod
        return (f"import {mod}", severity, desc)
    return None

IMPORTS = []
with open("/tmp/import_directives.txt") as f:
    for line in f:
        parsed = parse_import_line(line)
        if parsed:
            IMPORTS.append(parsed)

for stmt, severity, desc in IMPORTS:
    try:
        exec(stmt, {})
        print(f"[OK] {desc}")
    except Exception as e:
        failures.append((desc, severity, str(e)))
        detailed_errors.append(f"--- {desc} ({severity}) ---\n{traceback.format_exc()}")

# Write summary
with open("/tmp/import_failures.txt", "w") as f:
    for desc, severity, err in failures:
        f.write(f"{desc}\t{severity}\t{err}\n")

# Write detailed errors
with open("/tmp/import_errors.log", "w") as f:
    for detail in detailed_errors:
        f.write(detail + "\n")

# Print summary to stdout
if failures:
    print("\nFailed Imports:")
    for desc, severity, err in failures:
        print(f"{desc} [{severity}]: {err}")

# Exit code: 1 if any FATAL, 0 otherwise
if any(sev == "FATAL" for _, sev, _ in failures):
    sys.exit(1)
else:
    sys.exit(0)
