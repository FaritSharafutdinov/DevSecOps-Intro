# Lab 6 — IaC Security: Scanning & Policy Enforcement (Submission)

## Scope & Evidence (what I scanned)

- **Terraform**: `labs/lab6/vulnerable-iac/terraform/`
  - Tools: **tfsec**, **Checkov**, **Terrascan**
  - Artifacts: `labs/lab6/analysis/tfsec-*`, `checkov-terraform-*`, `terrascan-*`
- **Pulumi (YAML)**: `labs/lab6/vulnerable-iac/pulumi/Pulumi-vulnerable.yaml`
  - Tool: **KICS**
  - Artifacts: `labs/lab6/analysis/kics-pulumi-*`
- **Ansible**: `labs/lab6/vulnerable-iac/ansible/`
  - Tool: **KICS**
  - Artifacts: `labs/lab6/analysis/kics-ansible-*`

> Note: this lab uses intentionally vulnerable IaC. I did **not** modify the vulnerable code (per lab instructions).

## Task 1 — Terraform & Pulumi Security Scanning (tfsec / Checkov / Terrascan / KICS)

### Terraform: findings count comparison (high level)

From generated artifacts:

- **tfsec**: **53** findings (`labs/lab6/analysis/tfsec-results.json`)
- **Checkov**: **78** failed checks (`labs/lab6/analysis/checkov-terraform-results.json`)
- **Terrascan**: **22** violated policies (`labs/lab6/analysis/terrascan-results.json`)

**Why counts differ** (important): each tool has different rule catalogs, default severities, and “what counts as a finding” (failed checks vs violations vs results). Tool overlap is significant, but not complete.

### Terraform: key themes observed across tools

- **Network exposure**: Security Groups with `0.0.0.0/0` ingress/egress (SSH open; wide-open rules).
- **Data exposure**: Publicly accessible RDS.
- **Encryption gaps**: Unencrypted S3 buckets / DynamoDB / RDS storage.
- **IAM least privilege violations**: Wildcards (`*`) in IAM policies; risky actions.
- **Governance/ops**: Missing logging/versioning/backup-hardening and other security hygiene.

### Pulumi (KICS): summary

KICS results for Pulumi YAML (`labs/lab6/analysis/kics-pulumi-results.json`):

- **TOTAL**: **6**
  - **CRITICAL**: 1
  - **HIGH**: 2
  - **MEDIUM**: 1
  - **INFO**: 2

Representative Pulumi findings (from `labs/lab6/analysis/kics-pulumi-report.txt`):

- **CRITICAL**: RDS DB Instance **Publicly Accessible**
- **HIGH**: DynamoDB table **Not Encrypted**
- **HIGH**: **Hardcoded secret/password** detected
- **MEDIUM/INFO**: Observability / best-practice findings (monitoring disabled, etc.)

### Terraform vs Pulumi: HCL vs YAML manifest security differences

- **Misconfig types are similar** (public endpoints, weak SG rules, missing encryption), but:
  - **Terraform (HCL)** scanning is mature across multiple tools; you get **broader coverage** and more policy packs (security + compliance).
  - **Pulumi (YAML manifest)** with KICS is effective for **Pulumi-specific schema checks** (resource properties, platform rules) and provides clear “expected vs actual” keys.
- **Developer ergonomics trade-off**:
  - Terraform’s declarative model makes it straightforward for scanners to reason about resource intent.
  - Pulumi’s programmatic approach (Python/TS/etc.) may require different tooling; here we intentionally used YAML because KICS has first-class support for it.

### KICS Pulumi support evaluation

- **Strengths**
  - Clear mapping to Pulumi registry docs for each rule.
  - Good “expected/actual” messages for YAML keys (`publiclyAccessible`, `serverSideEncryption`, etc.).
  - Same scanner works for both Pulumi + Ansible → consistent reporting format and severity counters.
- **Limitations**
  - Coverage is limited by the query catalog; results are fewer than Terraform tools here (6 vs 53/78).
  - YAML-only scan: programmatic Pulumi (e.g., `__main__.py`) requires different analysis approaches.

## Task 2 — Ansible Security Scanning with KICS

KICS results for Ansible (`labs/lab6/analysis/kics-ansible-results.json`):

- **TOTAL**: **10**
  - **HIGH**: 9
  - **LOW**: 1

### Key Ansible security issues detected

- **Hardcoded secrets/passwords** in:
  - `inventory.ini` (multiple password/secret matches)
  - `deploy.yml` (password in URL + generic password)
  - `configure.yml` (generic password)
- **Supply-chain / ops hygiene**
  - **Unpinned package version** (LOW): using `state: latest` without constraints.

### Best-practice violations (at least 3) + security impact

- **Hardcoded secrets in repo**
  - **Impact**: credential leakage via git history, logs, PRs; lateral movement if reused elsewhere.
  - **Fix**: use **Ansible Vault** or external secret manager (e.g., Vault/SM/SSM), and reference secrets via variables.
- **Passwords inside URLs**
  - **Impact**: ends up in shell history, proxy logs, monitoring traces; often copied/pasted.
  - **Fix**: use headers/tokens/vars; avoid embedding credentials in URIs.
- **Unpinned package installs (`latest`)**
  - **Impact**: non-reproducible deployments; unexpected breaking changes; potential supply-chain risk via unexpected updates.
  - **Fix**: pin versions, or use `update_cache` + explicit versions; maintain upgrade cadence separately.

### Remediation steps (Ansible)

- **Secrets**:
  - Move secrets to `group_vars/` or `vars/` and encrypt:
    - `ansible-vault encrypt vars/secrets.yml`
  - In tasks that touch secrets, use:
    - `no_log: true`
- **Packages**:
  - Replace `state: latest` with pinned `state: present` and explicit versions where possible.

## Task 3 — Comparative Tool Analysis & Security Insights

### Tool comparison matrix

| Criterion | tfsec | Checkov | Terrascan | KICS |
|---|---:|---:|---:|---:|
| **Total Findings** | 53 | 78 | 22 | 16 (Pulumi 6 + Ansible 10) |
| **Scan Speed** | Fast | Medium | Medium (when policies available) | Fast |
| **False Positives (observed)** | Low–Med | Med | Med | Low–Med |
| **Report Quality** | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Ease of Use** | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Documentation** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Platform Support** | Terraform-focused | Multi (Terraform, K8s, etc.) | Multi (OPA-style) | Multi (Pulumi YAML, Ansible, Terraform, etc.) |
| **Output Formats** | JSON/text/SARIF | JSON/CLI/SARIF | JSON/SARIF/etc. | JSON/HTML/SARIF + console |
| **CI/CD Integration** | Easy | Easy–Medium | Medium | Easy |
| **Unique Strengths** | Terraform-first, pragmatic | Broad policy catalog + ecosystem | Policy/compliance mapping mindset | Great multi-IaC coverage; strong secrets detection |

### Category analysis (qualitative; based on this repo’s outputs)

| Security Category | tfsec | Checkov | Terrascan | KICS (Pulumi) | KICS (Ansible) | Best Tool (here) |
|---|---|---|---|---|---|---|
| **Encryption Issues** | Strong | Strong | Medium | Strong | N/A | tfsec / Checkov |
| **Network Security** | Strong | Strong | Strong | Medium | N/A | tfsec / Checkov / Terrascan |
| **Secrets Management** | Medium | Medium | Low | Medium | **Strong** | **KICS (Ansible)** |
| **IAM/Permissions** | Strong | Strong | Medium | N/A (in this YAML set) | N/A | tfsec / Checkov |
| **Access Control** | Strong | Strong | Medium | Medium | Medium | Checkov |
| **Compliance/Best Practices** | Medium | Strong | Strong-ish | Medium | Medium | Checkov / Terrascan |

### Top 5 critical findings (with remediation examples)

> The snippets below are **example remediations** (do not apply changes to the lab’s vulnerable code).

#### 1) Public RDS instance (internet-exposed DB)

- **Evidence**
  - tfsec: `aws-rds-no-public-db-access` (`database.tf`), `publicly_accessible = true`
  - KICS Pulumi: **RDS DB Instance Publicly Accessible** (`Pulumi-vulnerable.yaml`)
  - Terrascan: `AC_AWS_0054 rdsPubliclyAccessible`
- **Risk**
  - Unauthorized access attempts, credential stuffing, brute force, and data exfiltration.
- **Remediation (Terraform example)**

```hcl
resource "aws_db_instance" "db" {
  publicly_accessible = false
  vpc_security_group_ids = [aws_security_group.db_private.id]
  # additionally: place in private subnets + no public route
}
```

#### 2) Security groups allow `0.0.0.0/0` ingress (e.g., SSH open)

- **Evidence**
  - tfsec: `aws-ec2-no-public-ingress-sgr`
  - Terrascan: `AC_AWS_0227 port22OpenToInternet` and `AC_AWS_0275 portWideOpenToPublic`
- **Risk**
  - Direct remote access, brute force, exploitation of exposed services.
- **Remediation (Terraform example)**

```hcl
resource "aws_security_group" "ssh" {
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["203.0.113.0/24"] # replace with your admin/VPN CIDR
  }
}
```

#### 3) S3 buckets with public access / missing public access blocks

- **Evidence**
  - tfsec: public ACL / missing public access blocks (`aws-s3-no-public-access-with-acl`, etc.)
  - Terrascan: `AC_AWS_0496 s3PublicAclNoAccessBlock`, `AC_AWS_0210 allUsersReadAccess`
- **Risk**
  - Data leakage, accidental public exposure, compliance violations.
- **Remediation (Terraform example)**

```hcl
resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}
```

#### 4) Missing encryption at rest (RDS / DynamoDB / S3)

- **Evidence**
  - tfsec: RDS `encrypt-instance-storage-data`, DynamoDB encryption checks, S3 encryption checks
  - KICS Pulumi: DynamoDB Table Not Encrypted
- **Risk**
  - If storage snapshots/backups are accessed, data is readable.
- **Remediation (Terraform examples)**

```hcl
# RDS
resource "aws_db_instance" "db" {
  storage_encrypted = true
  kms_key_id        = aws_kms_key.db.arn
}

# DynamoDB
resource "aws_dynamodb_table" "t" {
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.ddb.arn
  }
}
```

#### 5) Hardcoded secrets in IaC / config management (Ansible + Pulumi YAML)

- **Evidence**
  - KICS Ansible: multiple **Generic Password / Secret** + **Password in URL**
  - KICS Pulumi: **Generic Password**
- **Risk**
  - Credential disclosure + reuse risk; compromises spread quickly.
- **Remediation**
  - Use **Ansible Vault** / external secrets manager; remove secrets from repo; rotate exposed credentials.

```yaml
# Example: reference vaulted var instead of plaintext
vars_files:
  - vars/secrets.vault.yml

tasks:
  - name: Configure app
    ansible.builtin.template:
      src: app.conf.j2
      dest: /etc/app/app.conf
    no_log: true
```

### CI/CD integration strategy (practical)

- **Pre-commit (fast feedback)**
  - Run `tfsec` on changed Terraform files.
  - Run `kics` secrets scan on `ansible/` + `pulumi/` manifests.
- **PR pipeline (quality gate)**
  - `checkov` full scan with SARIF upload to GitHub code scanning.
  - `tfsec` JSON/SARIF outputs for dashboards.
- **Nightly / scheduled**
  - Re-run full scans + generate trend metrics; include heavier compliance packs.

### Challenges encountered (and how I handled them)

- **Checkov** attempted to fetch Prisma Cloud guideline mappings and timed out (`api0.prismacloud.io`), but the **local Terraform scan still produced full results**.
- **Terrascan** intermittently failed to download policies with `unexpected EOF` (likely network/regional restriction). A valid `terrascan-results.json` was still generated and used for reporting.

## Appendix: output files created

See `labs/lab6/analysis/`:

- `tfsec-results.json`, `tfsec-report.txt`
- `checkov-terraform-results.json`, `checkov-terraform-report.txt`
- `terrascan-results.json` (and if available) `terrascan-report.txt`
- `kics-pulumi-results.json`, `kics-pulumi-report.html`, `kics-pulumi-report.txt`
- `kics-ansible-results.json`, `kics-ansible-report.html`, `kics-ansible-report.txt`
- `terraform-comparison.txt`, `pulumi-analysis.txt`, `ansible-analysis.txt`, `tool-comparison.txt`

