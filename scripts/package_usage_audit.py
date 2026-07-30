#!/usr/bin/env python3
"""Check pubspec dependencies vs lib/ imports."""
import os
import re
import yaml

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

with open(os.path.join(ROOT, "pubspec.yaml"), encoding="utf-8") as f:
    pub = yaml.safe_load(f)

deps = {}
for section in ("dependencies", "dev_dependencies"):
    for name, ver in (pub.get(section) or {}).items():
        if name in ("flutter", "flutter_test", "flutter_lints"):
            continue
        deps[name] = section

import_counts = {k: 0 for k in deps}
lib_text = []
for root, _, files in os.walk(os.path.join(ROOT, "lib")):
    for fn in files:
        if fn.endswith(".dart"):
            p = os.path.join(root, fn)
            with open(p, encoding="utf-8", errors="ignore") as f:
                t = f.read()
            lib_text.append(t)
            for m in re.finditer(r"import\s+['\"]package:([^/]+)", t):
                pkg = m.group(1)
                if pkg in import_counts:
                    import_counts[pkg] += 1

print("UNUSED_PACKAGES (0 imports in lib/):")
for pkg, cnt in sorted(import_counts.items(), key=lambda x: x[0]):
    if cnt == 0:
        print(f"  {pkg} ({deps[pkg]})")

print("\nLOW_USAGE (1-2 imports):")
for pkg, cnt in sorted(import_counts.items(), key=lambda x: -x[1]):
    if 0 < cnt <= 2:
        print(f"  {cnt}\t{pkg}")
