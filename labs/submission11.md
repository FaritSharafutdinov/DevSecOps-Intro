# Lab 11 Submission — Reverse Proxy Hardening (Nginx)

Date: 2026-04-20  
Environment: Windows 10 + Docker Desktop, PowerShell

## Task 1 — Reverse Proxy Compose Setup (2 pts)

### Why a reverse proxy improves security

- **Single controlled entry point**: only Nginx is exposed to the host, so the application is not directly reachable.
- **TLS termination**: the proxy can enforce modern TLS versions/ciphers and centralize certificate handling.
- **Security headers at the edge**: headers can be injected/standardized without changing app code.
- **Request filtering and throttling**: rate limits/timeouts can reduce brute-force and basic DoS/slowloris risk.

### Why hiding the app port reduces attack surface

- **Fewer exposed services**: the app container is reachable only on the internal Docker network, not from the host network.
- **Less direct fingerprinting/exploitation**: scanners cannot hit the app port directly; only the hardened proxy is accessible.
- **Policy enforcement**: all traffic must pass through the proxy controls (headers/TLS/rate limits/logging).

### Evidence (only Nginx publishes host ports)

`labs/lab11/analysis/compose-ps.txt`

```text
NAME            IMAGE                           COMMAND                  SERVICE   CREATED          STATUS          PORTS
lab11-juice-1   bkimminich/juice-shop:v19.0.0   "/nodejs/bin/node /j…"   juice     41 seconds ago   Up 40 seconds   3000/tcp
lab11-nginx-1   nginx:stable-alpine             "/docker-entrypoint.…"   nginx     41 seconds ago   Up 40 seconds   0.0.0.0:8080->8080/tcp, [::]:8080->8080/tcp, 0.0.0.0:8443->8443/tcp, [::]:8443->8443/tcp
```

### Evidence (HTTP redirects to HTTPS)

`labs/lab11/analysis/http-status.txt`

```text
HTTP 308
```

## Task 2 — Security Headers (3 pts)

### Evidence (HTTP headers)

`labs/lab11/analysis/headers-http.txt`

```text
HTTP/1.1 308 Permanent Redirect
Location: https://localhost:8443/
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(), geolocation=(), microphone=()
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Resource-Policy: same-origin
Content-Security-Policy-Report-Only: default-src 'self'; img-src 'self' data:; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'
```

### Evidence (HTTPS headers)

`labs/lab11/analysis/headers-https.txt`

```text
HTTP/1.1 200 OK
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(), geolocation=(), microphone=()
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Resource-Policy: same-origin
Content-Security-Policy-Report-Only: default-src 'self'; img-src 'self' data:; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'
```

### What each header protects against

- **X-Frame-Options (DENY)**: clickjacking defenses by preventing the site from being framed.
- **X-Content-Type-Options (nosniff)**: reduces MIME-type sniffing, lowering risk of content-type confusion and some XSS vectors.
- **Strict-Transport-Security (HSTS)**: forces browsers to use HTTPS for subsequent requests, reducing SSL-stripping/downgrade attacks.  
  - Confirmed **present on HTTPS** and **not present on HTTP**, which is correct.
- **Referrer-Policy (strict-origin-when-cross-origin)**: limits referrer leakage to other origins while still keeping useful referrers for same-origin navigation.
- **Permissions-Policy**: disables or restricts access to sensitive browser features (camera/geolocation/microphone), reducing abuse from injected scripts or unwanted embeds.
- **COOP/CORP**:
  - **Cross-Origin-Opener-Policy (same-origin)** helps isolate the browsing context group and reduces cross-origin window interactions (mitigates some XS-Leaks patterns).
  - **Cross-Origin-Resource-Policy (same-origin)** reduces the ability for other origins to load this site’s resources.
- **CSP-Report-Only**: provides visibility into CSP violations without breaking the app; helps iteratively tighten policy for a JS-heavy app like Juice Shop.

## Task 3 — TLS, HSTS, Rate Limiting & Timeouts (5 pts)

### TLS / testssl summary

Source: `labs/lab11/analysis/testssl.txt`

- **Protocols enabled**:
  - TLS 1.2: offered
  - TLS 1.3: offered
  - SSLv2/SSLv3/TLS 1.0/TLS 1.1: not offered
- **Cipher suites observed**:
  - TLS 1.2: `ECDHE-RSA-AES256-GCM-SHA384`, `ECDHE-RSA-AES128-GCM-SHA256`
  - TLS 1.3: `TLS_AES_256_GCM_SHA384`, `TLS_CHACHA20_POLY1305_SHA256`, `TLS_AES_128_GCM_SHA256`
- **Why TLS 1.2+ (prefer 1.3)**:
  - Older protocols (TLS 1.0/1.1) are deprecated and have a weaker security baseline.
  - TLS 1.3 removes legacy/fragile constructs, supports faster handshakes, and improves confidentiality/integrity properties.

### testssl warnings / notes

- The certificate is **self-signed**, so trust-chain checks are **NOT ok** (expected for localhost labs).
- The scan target used `host.docker.internal`, while the cert CN/SAN is `localhost`, so hostname validation can warn (**expected** in this setup).
- No OCSP/CRL/CT/CAA signals are provided (typical for self-signed dev certs), and **OCSP stapling** is not offered.

### HSTS scope validation

- **HTTPS**: `Strict-Transport-Security` is present (`headers-https.txt`).
- **HTTP**: no HSTS header on the redirect response (`headers-http.txt`).

### Rate limiting test results

Rate limiting is applied on `POST /rest/user/login` using:
- `limit_req_zone ... rate=10r/m`
- `limit_req ... burst=5 nodelay`
- `limit_req_status 429`

Evidence: `labs/lab11/analysis/rate-limit-test.txt`

```text
500
500
500
500
500
500
429
429
429
429
429
429
```

Interpretation:
- **6 requests** returned non-429 application responses, then **6 requests** were **throttled with 429** once burst+rate thresholds were exceeded.

Why `rate=10r/m` with `burst=5` is a reasonable balance:
- **Security**: slows password guessing and reduces automated abuse at the login endpoint.
- **Usability**: allows short bursts (e.g., a few retries) without immediately blocking legitimate users.
- **Trade-off**: NAT/shared-IP environments can cause multiple users to share a limit; per-user (or token-based) throttling would be better but requires app-aware logic.

### Access log evidence of 429s

`labs/lab11/analysis/access-429.txt`

```text
172.22.0.1 - - [20/Apr/2026:19:55:50 +0000] "POST /rest/user/login HTTP/1.1" 429 162 "-" "curl/8.18.0" rt=0.000 uct=- urt=-
```

### Timeout settings and trade-offs

Configured in `labs/lab11/reverse-proxy/nginx.conf`:
- **client_body_timeout 10s / client_header_timeout 10s**: mitigates slowloris-style attacks by limiting how long clients can drip headers/body.
- **proxy_read_timeout 30s / proxy_send_timeout 30s / proxy_connect_timeout 5s**: prevents stuck upstream connections from consuming proxy resources.

Trade-offs:
- Tight timeouts can impact slow clients or large/slow upstream responses.
- Longer timeouts improve compatibility but increase exposure to resource exhaustion.

## Short analysis: overall trade-offs

- **CSP in Report-Only**: safer rollout for a JS-heavy app; stronger enforcing CSP would likely break functionality without tuning.
- **Self-signed TLS**: good for learning and local hardening, but not suitable for real users; production should use a trusted CA and consider OCSP stapling.
- **HSTS includeSubDomains/preload**: great for real domains, but generally not appropriate to preload for localhost; used here to demonstrate configuration and verification.
