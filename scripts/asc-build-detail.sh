#!/bin/bash
# Show detailed info about a specific build (read-only)
# Usage: asc-build-detail.sh [build-number]
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

function get(path) {
  return new Promise((resolve, reject) => {
    https.get('https://api.appstoreconnect.apple.com' + path, {
      headers: { Authorization: 'Bearer ' + token }
    }, (res) => {
      let body = '';
      res.on('data', d => body += d);
      res.on('end', () => resolve(JSON.parse(body)));
    }).on('error', reject);
  });
}

async function main() {
  // Find the build
  const builds = await get('/v1/builds?sort=-uploadedDate&limit=10&fields[builds]=version,processingState,uploadedDate,usesNonExemptEncryption,minOsVersion');
  const build = builds.data.find(b => b.attributes.version === '$BUILD_NUM') || builds.data[0];
  const a = build.attributes;
  console.log('Build ' + a.version);
  console.log('  processingState: ' + a.processingState);
  console.log('  uploadedDate: ' + a.uploadedDate);
  console.log('  usesNonExemptEncryption: ' + a.usesNonExemptEncryption);
  console.log('  minOsVersion: ' + a.minOsVersion);

  // Check beta app review submission
  try {
    const review = await get('/v1/builds/' + build.id + '/betaAppReviewSubmission');
    console.log('  betaReviewState: ' + (review.data ? review.data.attributes.betaReviewState : 'none'));
  } catch(e) {}

  // Check build beta detail (auto notify, export compliance)
  try {
    const detail = await get('/v1/builds/' + build.id + '/buildBetaDetail');
    const d = detail.data.attributes;
    console.log('  autoNotifyEnabled: ' + d.autoNotifyEnabled);
    console.log('  externalBuildState: ' + d.externalBuildState);
    console.log('  internalBuildState: ' + d.internalBuildState);
  } catch(e) {}
}

main().catch(e => { console.error(e.message); process.exit(1); });
"
