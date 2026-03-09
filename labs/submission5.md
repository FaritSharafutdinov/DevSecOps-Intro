# SAST Analysis Report

## SAST Tool Effectiveness
Semgrep was used to perform static code analysis on the OWASP Juice Shop source code (v19.0.0). It identified 25 security findings. The analysis covered various vulnerability types including SQL injection, Cross-Site Scripting (XSS), hardcoded secrets, and path traversal.

## Critical Vulnerability Analysis

| Vulnerability Type | File Path | Line | Severity |
| :--- | :--- | :--- | :--- |
| SQL Injection | /src/data/static/codefixes/dbSchemaChallenge_1.ts | 5 | ERROR |
| SQL Injection | /src/data/static/codefixes/dbSchemaChallenge_3.ts | 11 | ERROR |
| SQL Injection | /src/data/static/codefixes/unionSqlInjectionChallenge_1.ts | 6 | ERROR |
| SQL Injection | /src/data/static/codefixes/unionSqlInjectionChallenge_3.ts | 10 | ERROR |
| SQL Injection | /src/routes/login.ts | 34 | ERROR |

## Task 2: DAST Analysis Results

### Authenticated vs Unauthenticated Scanning
Authenticated scanning (with ZAP AJAX spider) discovered over 600 URLs, significantly higher than the unauthenticated scan. This highlights the importance of authenticated scanning to access protected endpoints and user-specific features.

### Tool Comparison Matrix

| Tool | Findings | Severity Breakdown | Best Use Case |
| :--- | :--- | :--- | :--- |
| ZAP | 100+ | Mix of High/Med/Low | Comprehensive web app testing |
| Nuclei | 1 | Info | Fast CVE detection |
| Nikto | 0 | None | Web server misconfigurations |
| SQLmap | 1 | High | SQL Injection analysis |

### Tool-Specific Strengths
- **ZAP**: Excellent for comprehensive, authenticated web application scanning.
- **Nuclei**: Fast, template-based scanning for known vulnerabilities.
- **Nikto**: Useful for identifying server misconfigurations.
- **SQLmap**: Highly effective for deep SQL injection testing.

## Task 3: SAST/DAST Correlation
SAST and DAST found different types of vulnerabilities. SAST (Semgrep) identified code-level issues like potential SQL injection patterns, while DAST tools identified runtime issues such as missing security headers and authenticated endpoints vulnerabilities. Both approaches are necessary for full coverage.
