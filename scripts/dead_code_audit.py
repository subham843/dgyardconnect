#!/usr/bin/env python3
"""Import-graph dead code audit for lib/ (outgoing edges from entry points)."""
import os
import re
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "lib")


def norm(p: str) -> str:
    return os.path.normpath(p).replace("\\", "/")


files = set()
for root, _, fs in os.walk(LIB):
    for f in fs:
        if f.endswith(".dart"):
            files.add(norm(os.path.join(root, f)))

import_re = re.compile(r"""import\s+['"]([^'"]+)['"]""")
export_re = re.compile(r"""export\s+['"]([^'"]+)['"]""")


def resolve_import(from_file: str, imp: str) -> str | None:
    if imp.startswith("package:") or imp.startswith("dart:"):
        return None
    base = os.path.dirname(from_file)
    target = norm(os.path.join(base, imp))
    if not target.endswith(".dart"):
        target += ".dart"
    return target


outgoing = defaultdict(set)
incoming = defaultdict(set)

for fp in files:
    with open(fp, encoding="utf-8", errors="ignore") as f:
        text = f.read()
    for pat in (import_re, export_re):
        for m in pat.finditer(text):
            t = resolve_import(fp, m.group(1))
            if t and t in files:
                outgoing[fp].add(t)
                incoming[t].add(fp)

entries = [
    norm(os.path.join(LIB, "main.dart")),
    norm(os.path.join(LIB, "app.dart")),
    norm(os.path.join(LIB, "platform_init_mobile.dart")),
    norm(os.path.join(LIB, "platform_init_web.dart")),
    norm(os.path.join(LIB, "shared/router/app_router.dart")),
    norm(os.path.join(LIB, "shared/router/app_router_mobile.dart")),
    norm(os.path.join(LIB, "shared/router/app_router_web.dart")),
]

reachable = set()
queue = [e for e in entries if e in files]
while queue:
    cur = queue.pop()
    if cur in reachable:
        continue
    reachable.add(cur)
    for nxt in outgoing.get(cur, []):
        if nxt not in reachable:
            queue.append(nxt)

unreach = sorted(files - reachable)
print(f"TOTAL={len(files)} REACHABLE={len(reachable)} UNREACHABLE={len(unreach)}")
for f in unreach:
    c = len(incoming.get(f, []))
    importers = ", ".join(os.path.basename(x) for x in sorted(incoming.get(f, []))[:3])
    print(f"{c}\t{f}\t{importers}")
