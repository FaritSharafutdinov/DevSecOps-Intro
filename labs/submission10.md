# Lab 10 Submission — Vulnerability Management & Response

**Student:** Farit Sharafutdinov  

---

## 1. Deployment Evidence (Task 1)
The DefectDojo instance was successfully deployed locally using Docker Compose.
- **Status:** All 58 containers are up and running in a `healthy` state.
- **Access:** Admin login verified at `http://localhost:8080`.

## 2. Import Results (Task 2)
The data import was performed using the `run-imports.sh` automation script. Findings were mapped to the **Juice Shop** product under the **Labs Security Testing** engagement.

| Tool | Source File | Status | Active Findings |
| :--- | :--- | :--- | :--- |
| **Semgrep** | `semgrep-results.json` | Success | 25 |
| **Trivy** | `trivy-vuln-detailed.json` | Success | 147 |
| **Grype** | `grype-vuln-results.json` | Success | 120 |
| **ZAP** | `zap-report-noauth.json` | Error (XML required) | 0 |
| **Nuclei** | `nuclei-results.json` | Not Found (Skipped) | 0 |

## 3. Metrics & Analytics (Task 3)

### Severity Breakdown (Metrics Snapshot)
As of April 11, 2026, the system tracks **292 active findings**:
- **Critical:** 21
- **High:** 152
- **Medium:** 86
- **Low:** 21
- **Informational:** 12

### Key Insights:
- **Tooling Efficiency:** Over 90% of the total vulnerabilities were identified by software composition analysis (SCA) tools (Trivy and Grype), highlighting significant risks in the supply chain and base images.
- **SLA Alert:** There are 21 Critical findings that require immediate remediation (typically within 24-48 hours) to comply with standard security policies.
- **Deduplication Potential:** A high correlation between Trivy and Grype findings suggests that enabling deduplication logic would significantly reduce the manual triage workload for security engineers.

## 4. Artifacts
The following governance-ready files are located in `labs/lab10/report/`:
- [Metrics Snapshot (Markdown)](./lab10/report/metrics-snapshot.md)
- [Detailed Security Report (PDF)](./lab10/report/EngagementReport.pdf)
- [Findings Export (CSV)](./lab10/report/findings.csv)