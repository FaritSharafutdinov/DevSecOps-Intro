#!/usr/bin/env python3
"""Task 2.3 + Task 3.1: Vulnerability analysis and toolchain comparison. Run from labs/: python lab4/task2_task3_analyze.py"""
import json
from pathlib import Path
from collections import Counter

BASE = Path(__file__).parent
SYFT_SBOM = BASE / "syft" / "juice-shop-syft-native.json"
GRYPE_JSON = BASE / "syft" / "grype-vuln-results.json"
TRIVY_SBOM = BASE / "trivy" / "juice-shop-trivy-detailed.json"
TRIVY_VULN = BASE / "trivy" / "trivy-vuln-detailed.json"
TRIVY_LIC = BASE / "trivy" / "trivy-licenses.json"
OUT_VULN = BASE / "analysis" / "vulnerability-analysis.txt"
COMP = BASE / "comparison"
COMP.mkdir(exist_ok=True)

def load(path, encoding="utf-8"):
    with open(path, encoding=encoding) as f:
        return json.load(f)

def load_json(path):
    for enc in ("utf-8-sig", "utf-8"):
        try:
            return load(path, enc)
        except (UnicodeDecodeError, json.JSONDecodeError):
            continue
    return load(path, "utf-8")

# --- Task 2.3: Vulnerability Analysis ---
lines = ["=== Vulnerability Analysis ===", ""]
try:
    grype = load(GRYPE_JSON, "utf-8-sig")
    g_sev = Counter(m.get("vulnerability", {}).get("severity", "Unknown") for m in grype.get("matches", []))
    lines.extend(["Grype Vulnerabilities by Severity:"])
    for sev, c in g_sev.most_common():
        lines.append(f"     {c} {sev}")
except Exception as e:
    lines.extend(["Grype: (failed)", str(e)])
lines.append("")

try:
    trivy_v = load(TRIVY_VULN)
    t_sev = Counter()
    for r in trivy_v.get("Results", []):
        for v in r.get("Vulnerabilities", []):
            t_sev[v.get("Severity", "UNKNOWN")] += 1
    lines.extend(["Trivy Vulnerabilities by Severity:"])
    for sev, c in t_sev.most_common():
        lines.append(f"     {c} {sev}")
except Exception as e:
    lines.extend(["Trivy: (failed)", str(e)])
lines.append("")

lines.extend(["=== License Analysis Summary ===", "Tool Comparison:"])
try:
    syft = load(SYFT_SBOM)
    syft_lic = set()
    for a in syft.get("artifacts", []):
        for l in a.get("licenses", []):
            syft_lic.add(l.get("value", l))
    lines.append(f"- Syft found {len(syft_lic)} unique license types")
except Exception:
    lines.append("- Syft: (failed)")
try:
    trivy_lic = load(TRIVY_LIC)
    t_lic = set()
    for r in trivy_lic.get("Results", []):
        for lic in r.get("Licenses", []):
            t_lic.add(lic.get("Name", lic))
    lines.append(f"- Trivy found {len(t_lic)} unique license types")
except Exception:
    lines.append("- Trivy: (failed)")

OUT_VULN.write_text("\n".join(lines) + "\n", encoding="utf-8")
print("Written:", OUT_VULN)

# --- Task 3.1: Package and CVE comparison ---
syft_data = load(SYFT_SBOM)
trivy_sbom = load(TRIVY_SBOM)
grype_data = load(GRYPE_JSON, "utf-8-sig")
trivy_vuln = load(TRIVY_VULN)

syft_pkgs = sorted(set(f'{a.get("name")}@{a.get("version")}' for a in syft_data.get("artifacts", [])))
trivy_pkgs = []
for r in trivy_sbom.get("Results", []):
    if (r.get("Class") or "").lower() in ("os-pkgs", "lang-pkgs"):
        for p in r.get("Packages", []):
            trivy_pkgs.append(f'{p.get("Name")}@{p.get("Version")}')
trivy_pkgs = sorted(set(trivy_pkgs))

(COMP / "syft-packages.txt").write_text("\n".join(syft_pkgs) + "\n", encoding="utf-8")
(COMP / "trivy-packages.txt").write_text("\n".join(trivy_pkgs) + "\n", encoding="utf-8")

syft_set = set(syft_pkgs)
trivy_set = set(trivy_pkgs)
common = sorted(syft_set & trivy_set)
syft_only = sorted(syft_set - trivy_set)
trivy_only = sorted(trivy_set - syft_set)

(COMP / "common-packages.txt").write_text("\n".join(common) + "\n", encoding="utf-8")
(COMP / "syft-only.txt").write_text("\n".join(syft_only) + "\n", encoding="utf-8")
(COMP / "trivy-only.txt").write_text("\n".join(trivy_only) + "\n", encoding="utf-8")

grype_cves = sorted(set(m.get("vulnerability", {}).get("id", "") for m in grype_data.get("matches", []) if m.get("vulnerability", {}).get("id")))
trivy_cves = sorted(set())
for r in trivy_vuln.get("Results", []):
    for v in r.get("Vulnerabilities", []):
        vid = v.get("VulnerabilityID")
        if vid:
            trivy_cves.append(vid)
trivy_cves = sorted(set(trivy_cves))

(COMP / "grype-cves.txt").write_text("\n".join(grype_cves) + "\n", encoding="utf-8")
(COMP / "trivy-cves.txt").write_text("\n".join(trivy_cves) + "\n", encoding="utf-8")

common_cves = len(set(grype_cves) & set(trivy_cves))
acc_lines = [
    "=== Package Detection Comparison ===",
    "",
    f"Packages detected by both tools: {len(common)}",
    f"Packages only detected by Syft: {len(syft_only)}",
    f"Packages only detected by Trivy: {len(trivy_only)}",
    "",
    "=== Vulnerability Detection Overlap ===",
    "",
    f"CVEs found by Grype: {len(grype_cves)}",
    f"CVEs found by Trivy: {len(trivy_cves)}",
    f"Common CVEs: {common_cves}",
]
(COMP / "accuracy-analysis.txt").write_text("\n".join(acc_lines) + "\n", encoding="utf-8")
print("Written:", COMP / "accuracy-analysis.txt")
print("Done.")
