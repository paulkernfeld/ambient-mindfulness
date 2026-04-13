#!/bin/bash
# Set export compliance to false for a build (write operation)
# Usage: asc-set-compliance.sh [build-number]
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

KEY_ID="V92Q946H8M"
ISSUER_ID="$(cat "$REPO_DIR/apple-issuer-id.txt")"
KEY_FILE="$REPO_DIR/AuthKey_${KEY_ID}.p8"

BUILD_NUM="${1:-}"

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

function request(method, path, body) {
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
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function main() {
  // Find the build
  const builds = await request('GET', '/v1/builds?sort=-uploadedDate&limit=10&fields[builds]=version', null);
  const build = builds.data.find(b => b.attributes.version === '$BUILD_NUM');
  if (!build) { console.error('Build $BUILD_NUM not found'); process.exit(1); }
  console.log('Setting export compliance for build ' + build.attributes.version + '...');

  // Set usesNonExemptEncryption = false
  await request('PATCH', '/v1/builds/' + build.id, {
    data: {
      type: 'builds',
      id: build.id,
      attributes: { usesNonExemptEncryption: false }
    }
  });

  console.log('Done! Export compliance set to false. Build should now be available in TestFlight.');
}

main().catch(e => { console.error(e.message); process.exit(1); });
"
