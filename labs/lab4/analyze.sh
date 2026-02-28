#!/bin/sh
apk add --no-cache jq > /dev/null
echo "=== SBOM Component Analysis ===" > /tmp/labs/lab4/analysis/sbom-analysis.txt
echo "" >> /tmp/labs/lab4/analysis/sbom-analysis.txt
echo "Syft Package Counts:" >> /tmp/labs/lab4/analysis/sbom-analysis.txt
jq -r '.artifacts[] | .type' /tmp/labs/lab4/syft/juice-shop-syft-native.json | sort | uniq -c >> /tmp/labs/lab4/analysis/sbom-analysis.txt
echo "" >> /tmp/labs/lab4/analysis/sbom-analysis.txt
echo "Trivy Package Counts:" >> /tmp/labs/lab4/analysis/sbom-analysis.txt
jq -r '.Results[] as $result | $result.Packages[]? | "(\($result.Target // 'Unknown')) - \(.Type // 'unknown')"' /tmp/labs/lab4/trivy/juice-shop-trivy-detailed.json | sort | uniq -c >> /tmp/labs/lab4/analysis/sbom-analysis.txt