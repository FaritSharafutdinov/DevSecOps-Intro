#!/usr/bin/env python3
"""Task 1.4: SBOM Analysis and Extraction. Run from labs/: python lab4/task1.4_analyze.py"""
import json
from pathlib import Path
from collections import Counter

BASE = Path(__file__).parent
SYFT = BASE / "syft" / "juice-shop-syft-native.json"
TRIVY = BASE / "trivy" / "juice-shop-trivy-detailed.json"
OUT = BASE / "analysis" / "sbom-analysis.txt"
LIC = BASE / "syft" / "juice-shop-licenses.txt"

with open(SYFT, encoding="utf-8") as f:
    syft = json.load(f)
with open(TRIVY, encoding="utf-8") as f:
    trivy = json.load(f)

lines = []

# Syft package counts
syft_types = Counter(a.get("type", "unknown") for a in syft.get("artifacts", []))
lines.extend(["=== SBOM Component Analysis ===", "", "Syft Package Counts:"])
for t, c in syft_types.most_common():
    lines.append(f"     {c} {t}")
lines.append("")

# Trivy package counts (os-pkgs + lang-pkgs only)
trivy_types = Counter()
for r in trivy.get("Results", []):
    cls = r.get("Class", "")
    if "os-pkgs" not in cls and "lang-pkgs" not in cls:
        continue
    key = f"{r.get('Target', 'Unknown')} - {r.get('Type', 'unknown')}"
    trivy_types[key] += len(r.get("Packages", []))
lines.extend(["Trivy Package Counts:"])
for k, c in trivy_types.most_common():
    lines.append(f"     {c} {k}")
lines.append("")

# License Analysis
lines.extend(["=== License Analysis ===", "", "Syft Licenses:"])
syft_lic = Counter()
for a in syft.get("artifacts", []):
    for l in a.get("licenses", []):
        syft_lic[l.get("value", l)] += 1
for lic, c in syft_lic.most_common():
    lines.append(f"     {c} {lic}")
lines.append("")

lines.append("Trivy Licenses (OS Packages):")
trivy_os = Counter()
for r in trivy.get("Results", []):
    if "os-pkgs" in (r.get("Class") or ""):
        for p in r.get("Packages", []):
            for lic in p.get("Licenses", []):
                trivy_os[lic] += 1
for lic, c in trivy_os.most_common():
    lines.append(f"     {c} {lic}")
lines.append("")

lines.append("Trivy Licenses (Node.js):")
trivy_node = Counter()
for r in trivy.get("Results", []):
    if "lang-pkgs" in (r.get("Class") or ""):
        for p in r.get("Packages", []):
            for lic in p.get("Licenses", []):
                trivy_node[lic] += 1
for lic, c in trivy_node.most_common():
    lines.append(f"     {c} {lic}")

OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
print("Written:", OUT)

# Syft licenses file
lic_lines = ["Extracting licenses from Syft SBOM..."]
for a in syft.get("artifacts", []):
    if a.get("licenses"):
        vals = ", ".join(l.get("value", l) for l in a["licenses"])
        lic_lines.append(f"{a.get('name')} | {a.get('version')} | {vals}")
LIC.write_text("\n".join(lic_lines) + "\n", encoding="utf-8")
print("Written:", LIC)
