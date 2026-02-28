#!/bin/sh
# Task 1.4: SBOM Analysis and Extraction
# Run from repo root: docker run --rm -v "$(pwd)":/work -w /work alpine:latest sh labs/lab4/task1.4-analyze.sh

apk add --no-cache jq 2>/dev/null

BASE="labs/lab4"

# Component Analysis
echo "=== SBOM Component Analysis ===" > "$BASE/analysis/sbom-analysis.txt"
echo "" >> "$BASE/analysis/sbom-analysis.txt"
echo "Syft Package Counts:" >> "$BASE/analysis/sbom-analysis.txt"
jq -r '.artifacts[] | .type' "$BASE/syft/juice-shop-syft-native.json" | sort | uniq -c >> "$BASE/analysis/sbom-analysis.txt"

echo "" >> "$BASE/analysis/sbom-analysis.txt"
echo "Trivy Package Counts:" >> "$BASE/analysis/sbom-analysis.txt"
# Type is at Result level in Trivy JSON, not Package level
jq -r '.Results[] as $r | $r.Packages[]? | "\($r.Target // "Unknown") - \($r.Type // "unknown")"' \
  "$BASE/trivy/juice-shop-trivy-detailed.json" | sort | uniq -c >> "$BASE/analysis/sbom-analysis.txt"

# License Extraction
echo "" >> "$BASE/analysis/sbom-analysis.txt"
echo "=== License Analysis ===" >> "$BASE/analysis/sbom-analysis.txt"
echo "" >> "$BASE/analysis/sbom-analysis.txt"
echo "Syft Licenses:" >> "$BASE/analysis/sbom-analysis.txt"
jq -r '.artifacts[]? | select(.licenses != null) | .licenses[]? | .value' \
  "$BASE/syft/juice-shop-syft-native.json" | sort | uniq -c >> "$BASE/analysis/sbom-analysis.txt"

echo "" >> "$BASE/analysis/sbom-analysis.txt"
echo "Trivy Licenses (OS Packages):" >> "$BASE/analysis/sbom-analysis.txt"
jq -r '.Results[] | select((.Class // "") | contains("os-pkgs")) | .Packages[]? | select(.Licenses != null) | .Licenses[]?' \
  "$BASE/trivy/juice-shop-trivy-detailed.json" | sort | uniq -c >> "$BASE/analysis/sbom-analysis.txt"

echo "" >> "$BASE/analysis/sbom-analysis.txt"
echo "Trivy Licenses (Node.js):" >> "$BASE/analysis/sbom-analysis.txt"
jq -r '.Results[] | select((.Class // "") | contains("lang-pkgs")) | .Packages[]? | select(.Licenses != null) | .Licenses[]?' \
  "$BASE/trivy/juice-shop-trivy-detailed.json" | sort | uniq -c >> "$BASE/analysis/sbom-analysis.txt"

# Syft licenses extraction (from lab 1.2)
echo "Extracting licenses from Syft SBOM..." > "$BASE/syft/juice-shop-licenses.txt"
jq -r '.artifacts[] | select(.licenses != null and (.licenses | length > 0)) | "\(.name) | \(.version) | \(.licenses | map(.value) | join(", "))"' \
  "$BASE/syft/juice-shop-syft-native.json" >> "$BASE/syft/juice-shop-licenses.txt" 2>/dev/null || true

echo "Task 1.4 analysis complete. Check $BASE/analysis/sbom-analysis.txt"
