


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
with open("/import_directives.txt") as f:
    for line in f:
        parsed = parse_import_line(line)
        if parsed:
            IMPORTS.append(parsed)

for stmt, severity, desc in IMPORTS:
    print(f"[TESTING] {desc} (severity: {severity})", flush=True)
    try:
        exec(stmt, {})
        print(f"[OK] {desc}", flush=True)
    except Exception as e:
        failures.append((desc, severity, str(e)))
        detailed_errors.append(f"--- {desc} ({severity}) ---\n{traceback.format_exc()}")


# Write summary (machine-readable)
with open("/import_failures.txt", "w") as f:
    for desc, severity, err in failures:
        f.write(f"{desc}\t{severity}\t{err}\n")

# Write detailed errors
with open("/import_errors.log", "w") as f:
    for detail in detailed_errors:
        f.write(detail + "\n")

# Write formatted summary (human-readable)
with open("/import_test_formatted.txt", "w") as f:
    if not IMPORTS:
        f.write("No import directives found.\n")
    else:
        f.write("Import Test Results\n===================\n")
        for stmt, severity, desc in IMPORTS:
            status = "OK"
            err = ""
            for fail_desc, fail_sev, fail_err in failures:
                if fail_desc == desc:
                    status = "FAILED"
                    err = fail_err
                    break
            f.write(f"{desc:40} [{severity:7}] {status}")
            if status == "FAILED":
                f.write(f" - {err}")
            f.write("\n")
        f.write("\nSummary:\n")
        total = len(IMPORTS)
        failed = len(failures)
        fatal_failed = sum(1 for _, sev, _ in failures if sev == "FATAL")
        warning_failed = sum(1 for _, sev, _ in failures if sev == "WARNING")
        f.write(f"Total imports:   {total}\n")
        f.write(f"Failures:        {failed}\n")
        f.write(f"FATAL failures:  {fatal_failed}\n")
        f.write(f"WARNING failures:{warning_failed}\n")

# Print summary to stdout
if failures:
    print("\nFailed Imports:")
    for desc, severity, err in failures:
        print(f"{desc} [{severity}]: {err}")

# Always exit 0 so build.sh can decide based on output, not exit code
sys.exit(0)
