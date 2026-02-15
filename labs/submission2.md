# Lab 2 Submission - Threat Modeling with Threagile

## Task 1: Baseline Analysis

I have modeled the OWASP Juice Shop deployment using Threagile. The baseline analysis revealed several critical security risks related to unencrypted communication and storage.


### Risk Analysis
Based on the generated `report.pdf`, the following risks were identified as most critical:
1. **Cleartext Transmission**: Sensitive user data is transmitted over unencrypted HTTP.
2. **Missing Encryption**: Database storage lacks transparent encryption.
3. **Inherent Risk**: Risks associated with the technology stack (Web Server/Database).

---

## Task 2: Secure Variant Analysis

In this task, I implemented the following security controls in `threagile-model.secure.yaml`:
- Changed `protocol` from `http` to `https` for all communication links.
- Set `encryption` to `transparent` for the `persistent_storage` asset.

### Risk Comparison Table
| Category | Baseline | Secure | Delta |
|---|---:|---:|---:|
| Cleartext Transmission | 1 | 0 | -1 |
| Inherent Risk | 0 | 1 | 1 |
| Missing Encryption | 1 | 0 | -1 |

### Security Findings
By implementing TLS (HTTPS) and storage encryption, we successfully mitigated the "Cleartext Transmission" and "Missing Encryption" risk categories. This demonstrates how architectural changes as code can be automatically verified for security improvements.