#!/usr/bin/env node
/**
 * Task 1.4: SBOM Analysis and Extraction
 * Run from repo root: node labs/lab4/task1.4-analyze.js
 */
const fs = require('fs');
const path = require('path');

const BASE = path.join(__dirname);
const SYFT_JSON = path.join(BASE, 'syft', 'juice-shop-syft-native.json');
const TRIVY_JSON = path.join(BASE, 'trivy', 'juice-shop-trivy-detailed.json');
const OUT_ANALYSIS = path.join(BASE, 'analysis', 'sbom-analysis.txt');
const OUT_LICENSES = path.join(BASE, 'syft', 'juice-shop-licenses.txt');

const lines = [];

// Syft package counts
const syft = JSON.parse(fs.readFileSync(SYFT_JSON, 'utf8'));
const syftTypes = {};
for (const a of syft.artifacts || []) {
  const t = a.type || 'unknown';
  syftTypes[t] = (syftTypes[t] || 0) + 1;
}
lines.push('=== SBOM Component Analysis ===', '');
lines.push('Syft Package Counts:');
for (const [t, c] of Object.entries(syftTypes).sort((a, b) => b[1] - a[1])) {
  lines.push(`     ${c} ${t}`);
}
lines.push('');

// Trivy package counts
const trivy = JSON.parse(fs.readFileSync(TRIVY_JSON, 'utf8'));
const trivyTypes = {};
for (const r of trivy.Results || []) {
  const cls = r.Class || '';
  if (!cls.includes('os-pkgs') && !cls.includes('lang-pkgs')) continue; // skip secret, etc.
  const target = r.Target || 'Unknown';
  const type = r.Type || 'unknown';
  const key = `${target} - ${type}`;
  for (const _ of r.Packages || []) {
    trivyTypes[key] = (trivyTypes[key] || 0) + 1;
  }
}
lines.push('Trivy Package Counts:');
for (const [k, c] of Object.entries(trivyTypes).sort((a, b) => b[1] - a[1])) {
  lines.push(`     ${c} ${k}`);
}
lines.push('');

// License Analysis
lines.push('=== License Analysis ===', '');
lines.push('Syft Licenses:');
const syftLicenses = {};
for (const a of syft.artifacts || []) {
  for (const l of a.licenses || []) {
    const v = l.value || l;
    syftLicenses[v] = (syftLicenses[v] || 0) + 1;
  }
}
for (const [lic, c] of Object.entries(syftLicenses).sort((a, b) => b[1] - a[1])) {
  lines.push(`     ${c} ${lic}`);
}
lines.push('');

lines.push('Trivy Licenses (OS Packages):');
const trivyOsLicenses = {};
for (const r of trivy.Results || []) {
  if ((r.Class || '').includes('os-pkgs')) {
    for (const p of r.Packages || []) {
      for (const lic of p.Licenses || []) {
        trivyOsLicenses[lic] = (trivyOsLicenses[lic] || 0) + 1;
      }
    }
  }
}
for (const [lic, c] of Object.entries(trivyOsLicenses).sort((a, b) => b[1] - a[1])) {
  lines.push(`     ${c} ${lic}`);
}
lines.push('');

lines.push('Trivy Licenses (Node.js):');
const trivyNodeLicenses = {};
for (const r of trivy.Results || []) {
  if ((r.Class || '').includes('lang-pkgs')) {
    for (const p of r.Packages || []) {
      for (const lic of p.Licenses || []) {
        trivyNodeLicenses[lic] = (trivyNodeLicenses[lic] || 0) + 1;
      }
    }
  }
}
for (const [lic, c] of Object.entries(trivyNodeLicenses).sort((a, b) => b[1] - a[1])) {
  lines.push(`     ${c} ${lic}`);
}

fs.writeFileSync(OUT_ANALYSIS, lines.join('\n') + '\n');
console.log('Written:', OUT_ANALYSIS);

// Syft licenses file (package | version | licenses)
const licenseLines = ['Extracting licenses from Syft SBOM...'];
for (const a of syft.artifacts || []) {
  if (a.licenses && a.licenses.length > 0) {
    const vals = a.licenses.map(l => l.value || l).join(', ');
    licenseLines.push(`${a.name} | ${a.version} | ${vals}`);
  }
}
fs.writeFileSync(OUT_LICENSES, licenseLines.join('\n') + '\n');
console.log('Written:', OUT_LICENSES);
