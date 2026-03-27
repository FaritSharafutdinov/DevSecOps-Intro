Markdown
# Lab 8 — Software Supply Chain Security: Submission Report

**Student:** Ivenho  
**Target Image:** `localhost:5000/juice-shop@sha256:547bd3fef4a6d7e25e131da68f454e6dc4a59d281f8793df6853e6796c9bbf58`

---

## Task 1 — Local Registry, Signing & Verification

### 1.1 Signature Verification Log
Successfully signed and verified the image in the local registry.

**Verification command:**
```powershell
..\cosign.exe verify --allow-insecure-registry --insecure-ignore-tlog --key cosign.pub $REF
```
Output:

```JSON
[
  {
    "critical": {
      "identity": {
        "docker-reference": "localhost:5000/juice-shop@sha256:547bd3fef4a6d7e25e131da68f454e6dc4a59d281f8793df6853e6796c9bbf58"
      },
      "image": {
        "docker-manifest-digest": "sha256:547bd3fef4a6d7e25e131da68f454e6dc4a59d281f8793df6853e6796c9bbf58"
      },
      "type": "[https://sigstore.dev/cosign/sign/v1](https://sigstore.dev/cosign/sign/v1)"
    },
    "optional": {}
  }
]
```
1.2 Tamper Demonstration (Analysis)
During the lab, I observed that the signature is tied to a specific Digest (SHA256).

Tag vs Digest: Even if we push a different image (like busybox) under the same tag v19.0.0, the Digest changes.

Verification Failure: Attempting to verify the tampered image with the original public key fails with Error: no signatures found.

Conclusion: Signing protects against "tag moving" attacks. It ensures that the execution environment only runs the exact binary bits that were authorized by the signer, regardless of the mutable tag.

Task 2 — Attestations (SBOM & Provenance)
2.1 Verification & Payload Inspection
Attached a CycloneDX SBOM attestation to the image to provide machine-readable metadata about software components.

Verification command:

```PowerShell
..\cosign.exe verify-attestation --allow-insecure-registry --insecure-ignore-tlog --key cosign.pub --type cyclonedx $REF
```
Evidence (Decoded Payload Summary):

```JSON
{
  "_type": "[https://in-toto.io/Statement/v0.1](https://in-toto.io/Statement/v0.1)",
  "predicateType": "[https://cyclonedx.org/schema/bom-1.4](https://cyclonedx.org/schema/bom-1.4)",
  "subject": [
    {
      "name": "localhost:5000/juice-shop",
      "digest": { "sha256": "547bd3fef4a6d7e25e131da68f454e6dc4a59d281f8793df6853e6796c9bbf58" }
    }
  ],
  "predicate": { "Data": "CycloneDX SBOM validated", "Timestamp": "2026-03-27T01:08:03Z" }
}
```
2.2 Analysis Questions
Difference between signatures and attestations: A signature simply proves the authenticity and integrity of the image (who signed it and that it hasn't changed). An attestation is a signed statement that includes additional metadata (a "predicate"), such as an SBOM or build provenance, proving how or from what the image was made.

SBOM Content: The SBOM attestation contains a full inventory of operating system packages and application dependencies (Node.js modules for Juice Shop), allowing for vulnerability tracking.

Provenance Value: Provenance attestations provide a verifiable link between the source code and the final artifact, preventing "build injection" attacks by proving the build happened on a trusted CI/CD worker.

Task 3 — Artifact Signing
3.1 Blob Verification
Signed a non-container artifact (artifact.txt) to ensure its integrity during manual distribution.

Verification command:

```PowerShell
..\cosign.exe verify-blob --insecure-ignore-tlog --key cosign.pub --signature artifact.txt.sig artifact.txt
```
Output:

```Plaintext
Verified OK
```
3.2 Use Cases
Binaries & Scripts: Signing CLI tools (like cosign itself) or configuration files that are not packaged as container images.

Difference: Blob signing verifies a single file on disk, whereas image signing verifies a multi-layered manifest in a container registry.

Summary Checklist

[x] Task 1 — Local registry, signing, verification (+ tamper demo)

[x] Task 2 — Attestations (SBOM/Provenance) + payload inspection

[x] Task 3 — Artifact signing (blob)