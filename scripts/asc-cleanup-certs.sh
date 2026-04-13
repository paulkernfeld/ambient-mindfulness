#!/bin/bash
# Revoke old iOS distribution certificates, keeping only the newest (write operation)
# Usage: asc-cleanup-certs.sh [--dry-run]
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

KEY_ID="V92Q946H8M"
ISSUER_ID="$(cat "$REPO_DIR/apple-issuer-id.txt")"
KEY_FILE="$REPO_DIR/AuthKey_${KEY_ID}.p8"
DRY_RUN="${1:-}"

node -e "
const crypto = require('crypto');
const https = require('https');
const fs = require('fs');

const key = fs.readFileSync('$KEY_FILE', 'utf8');
const now = Math.floor(Date.now() / 1000);
const header = { alg: 'ES256', kid: '$KEY_ID', typ: 'JWT' };
const payload = { iss: '$ISSUER_ID', iat: now, exp: now + 1200, aud: 'appstoreconnect-v1' };
const b64 = (obj) => Buffer.from(JSON.stringify(obj)).toString('base64url');
const sigInput = b64(header) + '.' + b64(payload);
const sig = crypto.sign('sha256', Buffer.from(sigInput), { key, dsaEncoding: 'ieee-p1363' });
const token = sigInput + '.' + sig.toString('base64url');

const BASE = 'https://api.appstoreconnect.apple.com';
const dryRun = '$DRY_RUN' === '--dry-run';

function request(method, path) {
  return new Promise((resolve, reject) => {
    const url = new URL(BASE + path);
    const opts = {
      hostname: url.hostname, path: url.pathname + url.search, method,
      headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' }
    };
    const req = https.request(opts, (res) => {
      let data = '';
      res.on('data', d => data += d);
      res.on('end', () => {
        if (res.statusCode >= 400) {
          const parsed = data ? JSON.parse(data) : {};
          const errs = (parsed.errors || []).map(e => e.title + ': ' + e.detail).join('; ');
          reject(new Error('HTTP ' + res.statusCode + ': ' + (errs || data)));
        } else {
          resolve(data ? JSON.parse(data) : null);
        }
      });
    });
    req.on('error', reject);
    req.end();
  });
}

async function main() {
  // List all certificates
  const certs = await request('GET', '/v1/certificates?limit=200&fields[certificates]=displayName,certificateType,expirationDate');

  // Group by type
  const byType = {};
  for (const c of certs.data) {
    const type = c.attributes.certificateType;
    if (!byType[type]) byType[type] = [];
    byType[type].push(c);
  }

  console.log('Certificates by type:');
  for (const [type, list] of Object.entries(byType)) {
    console.log('  ' + type + ': ' + list.length);
  }
  console.log('');

  // For each type that has more than 1 cert, keep the newest and revoke the rest
  let revokedCount = 0;
  for (const [type, list] of Object.entries(byType)) {
    if (list.length <= 1) continue;

    // Sort by expiration date descending (newest first)
    list.sort((a, b) => new Date(b.attributes.expirationDate) - new Date(a.attributes.expirationDate));

    const toRevoke = list.slice(1); // keep the first (newest)
    console.log(type + ': keeping newest (expires ' + list[0].attributes.expirationDate + '), revoking ' + toRevoke.length + ' older certs');

    for (const cert of toRevoke) {
      if (dryRun) {
        console.log('  [dry-run] would revoke ' + cert.attributes.displayName + ' (expires ' + cert.attributes.expirationDate + ')');
      } else {
        await request('DELETE', '/v1/certificates/' + cert.id);
        console.log('  revoked ' + cert.attributes.displayName + ' (expires ' + cert.attributes.expirationDate + ')');
        revokedCount++;
      }
    }
  }

  console.log('\\nDone. Revoked ' + revokedCount + ' certificates.' + (dryRun ? ' (dry run)' : ''));
}

main().catch(e => { console.error(e.message); process.exit(1); });
"
