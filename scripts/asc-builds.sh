#!/bin/bash
# List recent TestFlight builds from App Store Connect (read-only)
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

KEY_ID="V92Q946H8M"
ISSUER_ID="$(cat "$REPO_DIR/apple-issuer-id.txt")"
KEY_FILE="$REPO_DIR/AuthKey_${KEY_ID}.p8"

if [ ! -f "$KEY_FILE" ]; then
  echo "API key not found: $KEY_FILE"
  exit 1
fi

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

const url = 'https://api.appstoreconnect.apple.com/v1/builds?sort=-uploadedDate&limit=5&fields[builds]=version,processingState,uploadedDate';
https.get(url, { headers: { Authorization: 'Bearer ' + token } }, (res) => {
  let body = '';
  res.on('data', d => body += d);
  res.on('end', () => {
    const data = JSON.parse(body);
    if (data.errors) {
      data.errors.forEach(e => console.log('ERROR: ' + e.title + ': ' + e.detail));
      process.exit(1);
    }
    (data.data || []).forEach(b => {
      const a = b.attributes;
      console.log('Build ' + (a.version || '?') + '  state=' + (a.processingState || '?') + '  uploaded=' + (a.uploadedDate || '?'));
    });
  });
}).on('error', e => { console.error(e.message); process.exit(1); });
"
