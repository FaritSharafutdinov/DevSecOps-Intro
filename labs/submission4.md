# Lab 4 — SBOM Generation & Software Composition Analysis

**Target:** OWASP Juice Shop `bkimminich/juice-shop:v19.0.0`

---

## Task 1 — SBOM Generation with Syft and Trivy

### 1.1–1.3 Setup and SBOM Generation

- Working directories: `labs/lab4/syft`, `trivy`, `analysis`, `comparison`.
- Docker images used: `anchore/syft:latest`, `aquasec/trivy:latest`, `anchore/grype:latest`.
- Syft: native JSON SBOM, table output, and license extraction generated.
- Trivy: JSON SBOM with `--list-all-pkgs`, table output generated.

### 1.4 Package Type Distribution Comparison

| Tool  | npm / Node | deb (OS) | binary |
|-------|------------|----------|--------|
| **Syft**  | 1,128 | 10 | 1 |
| **Trivy** | 1,125 (node-pkg) | 10 (debian) | — |

- **Syft** reports 1,139 components (1,128 npm + 10 deb + 1 binary). **Trivy** reports 1,135 (1,125 Node.js + 10 debian); it does not list the Node binary as a separate “binary” type.
- Both tools agree on OS packages (10 deb). The small difference in npm/node count (1,128 vs 1,125) is consistent with different aggregation or filtering (e.g. dev vs prod, deduplication).

### Dependency Discovery Analysis

- **Syft** provides rich metadata (PURLs, locations, layers) and distinguishes npm, deb, and binary types clearly. It discovered slightly more npm packages (1,128).
- **Trivy** groups language packages by target (e.g. “Node.js”) and separates OS packages by image layer. It reported 1,125 node-pkg components.
- **Conclusion:** Syft gives slightly higher npm count and clearer type breakdown; Trivy’s output is well-suited to vulnerability scanning and license checks with good coverage. For this image, dependency discovery is comparable; differences are mostly in presentation and taxonomy.

### License Discovery Analysis

- **Syft:** 32 unique license types; top counts: MIT (890), ISC (143), LGPL-3.0 (19), BSD-3-Clause (16), Apache-2.0 (15). Also reports GPL-2, GPL, BlueOak-1.0.0, Artistic, GFDL-1.2, MPL-2.0, Unlicense, etc.
- **Trivy:** 28 unique license types; OS packages use SPDX-style names (e.g. GPL-2.0-only, GPL-2.0-or-later); Node.js licenses align with Syft (MIT 878, ISC 143, LGPL-3.0-only 19, BSD-3-Clause 14, Apache-2.0 12).
- **Conclusion:** Syft found more distinct license labels (32 vs 28); Trivy normalizes more to SPDX (e.g. LGPL-3.0-only). Both are suitable for compliance review; Syft gives slightly more variety in naming, Trivy slightly cleaner normalization.

---

## Task 2 — Software Composition Analysis with Grype and Trivy

### 2.1–2.2 SCA Execution

- **Grype:** Run against Syft SBOM: `sbom:.../juice-shop-syft-native.json`; outputs: `grype-vuln-results.json`, `grype-vuln-table.txt`.
- **Trivy:** Full image scan for vulnerabilities; separate runs for secrets and licenses; outputs: `trivy-vuln-detailed.json`, `trivy-secrets.txt`, `trivy-licenses.json`.

### SCA Tool Comparison — Vulnerability Detection

| Severity   | Grype | Trivy |
|-----------|-------|-------|
| Critical  | 11    | 10    |
| High      | 86    | 81    |
| Medium    | 32    | 34    |
| Low       | 3     | 18    |
| Negligible| 12    | —     |
| **Total** | **144** | **143** |

- Both tools report similar total and severity spread. Grype uses “Negligible”; Trivy folds some of these into Low or omits them.
- Grype is fed by the Syft SBOM (same component set); Trivy builds its own view of the image. Overlap in CVEs/GHSAs is strong but not 1:1 (see Task 3).

### Critical Vulnerabilities Analysis — Top 5 and Remediation

1. **vm2 (3.9.17)** — GHSA-whpj-8f3w-67p5, GHSA-g644-9gfx-q4q4, GHSA-cchq-frgv-rjh5, GHSA-p5gc-c584-jj6v, GHSA-99p7-6v5w-7xg8  
   - **Remediation:** Upgrade to vm2 ≥ 3.10.0 (or remove if sandboxing is not required; consider alternatives like isolated-vm or Node’s built-in policies).

2. **jsonwebtoken (0.1.0 / 0.4.0)** — GHSA-c7hr-j4mj-j2w6 (algorithm confusion).  
   - **Remediation:** Upgrade to jsonwebtoken ≥ 4.2.2 (or ≥ 9.0.0 for newer API).

3. **lodash (2.4.2)** — GHSA-jf85-cpcp-j695 (prototype pollution).  
   - **Remediation:** Upgrade to lodash ≥ 4.17.12 (or 4.17.21 for additional fixes).

4. **crypto-js (3.3.0)** — GHSA-xwcq-pm8m-c4vf.  
   - **Remediation:** Upgrade to crypto-js ≥ 4.2.0.

5. **libssl3 (3.0.17-1~deb12u2)** — CVE-2025-15467.  
   - **Remediation:** Rebuild image on base with libssl3 3.0.18-1~deb12u2 or later (e.g. update Debian and rebuild).

### License Compliance Assessment

- **Risky or attention-needed licenses:** GPL-2, GPL-3, LGPL-* (copyleft); GFDL-1.2 (documentation). Most components are MIT/ISC/BSD/Apache-2.0.
- **Recommendations:** (1) Keep an approved license list (e.g. MIT, Apache-2.0, BSD, ISC) and flag GPL/LGPL/GFDL for legal review. (2) Use Trivy’s `--scanners license` and policy to fail on disallowed licenses in CI. (3) Syft’s license list is suitable for generating a compliance report and tracking dual/multi-license packages.

### Additional Security Features — Secrets Scanning

- **Trivy** was run with `--scanners secret` on the image.
- **Result:** No secrets detected; all reported targets show “-” in the Secrets column. This indicates no hardcoded credentials or high-confidence secret patterns were found in the image filesystem for the scanned paths.

---

## Task 3 — Toolchain Comparison: Syft+Grype vs Trivy All-in-One

### Accuracy Analysis — Quantified

- **Package detection**
  - Packages detected by **both** tools: **988**
  - Packages **only** in Syft: **13**
  - Packages **only** in Trivy: **9**
- **Vulnerability detection**
  - **Grype:** 93 unique CVE/GHSA IDs.
  - **Trivy:** 91 unique CVE/GHSA IDs.
  - **Common** (found by both): **26**.

So a large share of packages is agreed (988 common); each tool adds a small set of unique packages. Only a subset of reported vulnerabilities overlaps (26); many findings are tool- or feed-specific.

### Tool Strengths and Weaknesses

- **Syft**
  - Strengths: Rich SBOM metadata, multiple formats, good license extraction, clear type breakdown (npm/deb/binary).
  - Weaknesses: No built-in vuln or secret scanning; requires Grype (or another scanner) for SCA.

- **Grype**
  - Strengths: Designed for Syft SBOMs; fast; EPSS/risk-style metadata in table output.
  - Weaknesses: Depends on Syft (or other SBOM); vulnerability set differs from Trivy (different feeds/deduplication).

- **Trivy**
  - Strengths: Single tool for SBOM, vulns, licenses, secrets; good CI integration; consistent format.
  - Weaknesses: Slightly fewer unique license labels than Syft here; different package taxonomy (e.g. “node-pkg” vs “npm”).

### Use Case Recommendations

- **Choose Syft + Grype** when: You need a standardized SBOM (e.g. SPDX/CycloneDX) and want to reuse it across scanners and compliance; you prefer Anchore’s vulnerability and EPSS data; you already use Syft in pipelines.
- **Choose Trivy** when: You want one CLI for SBOM, vulns, licenses, and secrets; you prefer Aqua’s vulnerability DB and severity mapping; you want minimal tooling (single binary, fewer moving parts).

### Integration Considerations

- **CI/CD:** Both can run in Docker; mount workspace and output paths. Trivy can fail the build by severity (e.g. `--exit-code 1` for High/Critical). Grype can be wired to fail on match count or severity.
- **Automation:** Syft SBOM can be stored in a registry or artifact store and scanned by Grype later; Trivy can be run on the same image repeatedly for vuln/license/secret without a separate SBOM step.
- **Operational:** Syft+Grype = two images and two steps (SBOM then scan); Trivy = one image and one scan (optionally multiple scanner flags). For “scan this image now,” Trivy is simpler; for “produce and persist SBOM, then scan,” Syft+Grype fits well.

---

## Summary

- **Task 1:** SBOMs generated with Syft and Trivy; package type and license analysis completed; Syft reported slightly more npm packages and more license labels; Trivy’s license names are more normalized.
- **Task 2:** Grype and Trivy SCA executed; vulnerability counts and severities are similar; top critical issues (vm2, jsonwebtoken, lodash, crypto-js, libssl3) have clear upgrade paths; license compliance approach and Trivy secrets scan (no findings) documented.
- **Task 3:** Package overlap is high (988 common); vulnerability overlap is partial (26 common CVEs); strengths and use cases for Syft+Grype vs Trivy summarized with practical integration notes.

All generated artifacts are under `labs/lab4/` (syft/, trivy/, analysis/, comparison/).
