#!/bin/bash
# Check TestFlight beta groups and their builds (read-only)
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

KEY_ID="V92Q946H8M"
ISSUER_ID="$(cat "$REPO_DIR/apple-issuer-id.txt")"
KEY_FILE="$REPO_DIR/AuthKey_${KEY_ID}.p8"

ACTION="${1:-status}"

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
      res.on('end', () => {
        const data = JSON.parse(body);
        if (data.errors) {
          data.errors.forEach(e => console.error('ERROR: ' + e.title + ': ' + e.detail));
          process.exit(1);
        }
        resolve(data);
      });
    }).on('error', reject);
  });
}

async function main() {
  // Get the app
  const apps = await get('/v1/apps?filter[bundleId]=com.paulkernfeld.ambientmindfulness');
  const app = apps.data[0];
  if (!app) { console.log('App not found'); process.exit(1); }
  console.log('App: ' + app.attributes.name + ' (' + app.id + ')');

  // Get beta groups
  const groups = await get('/v1/apps/' + app.id + '/betaGroups');
  console.log('\\nBeta Groups:');
  for (const g of groups.data) {
    console.log('  ' + g.attributes.name + ' (id=' + g.id + ', internal=' + g.attributes.isInternalGroup + ')');
    // Get builds in this group
    const builds = await get('/v1/betaGroups/' + g.id + '/builds?limit=5');
    if (builds.data.length === 0) {
      console.log('    No builds assigned');
    }
    for (const b of builds.data) {
      const bd = await get('/v1/builds/' + b.id + '?fields[builds]=version,processingState,uploadedDate');
      const a = bd.data.attributes;
      console.log('    Build ' + a.version + '  state=' + a.processingState + '  uploaded=' + a.uploadedDate);
    }
  }

  // Show latest builds not in any group
  console.log('\\nLatest builds (all):');
  const allBuilds = await get('/v1/builds?sort=-uploadedDate&limit=5&fields[builds]=version,processingState,uploadedDate');
  for (const b of allBuilds.data) {
    const a = b.attributes;
    console.log('  Build ' + a.version + '  state=' + a.processingState + '  uploaded=' + a.uploadedDate);
  }
}

main().catch(e => { console.error(e.message); process.exit(1); });
"
