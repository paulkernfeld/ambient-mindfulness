// Revoke old signing certificates, keeping only the newest per type.
// Runs in CI before archive to prevent hitting Apple's cert limit.
// Env vars: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH
const crypto = require('crypto');
const https = require('https');
const fs = require('fs');

const keyId = process.env.ASC_KEY_ID;
const issuerId = process.env.ASC_ISSUER_ID;
const keyPath = process.env.ASC_KEY_PATH;

if (!keyId || !issuerId || !keyPath) {
  console.error('Missing env vars: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH');
  process.exit(1);
}

const key = fs.readFileSync(keyPath, 'utf8');
const now = Math.floor(Date.now() / 1000);
const header = { alg: 'ES256', kid: keyId, typ: 'JWT' };
const payload = { iss: issuerId, iat: now, exp: now + 1200, aud: 'appstoreconnect-v1' };
const b64 = (obj) => Buffer.from(JSON.stringify(obj)).toString('base64url');
const sigInput = b64(header) + '.' + b64(payload);
const sig = crypto.sign('sha256', Buffer.from(sigInput), { key, dsaEncoding: 'ieee-p1363' });
const token = sigInput + '.' + sig.toString('base64url');

function request(method, path) {
  return new Promise((resolve, reject) => {
    const url = new URL('https://api.appstoreconnect.apple.com' + path);
    const req = https.request({
      hostname: url.hostname, path: url.pathname + url.search, method,
      headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' }
    }, (res) => {
      let data = '';
      res.on('data', d => data += d);
      res.on('end', () => {
        if (res.statusCode >= 400) {
          const parsed = data ? JSON.parse(data) : {};
          const errs = (parsed.errors || []).map(e => e.detail).join('; ');
          reject(new Error('HTTP ' + res.statusCode + ': ' + errs));
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
  const certs = await request('GET', '/v1/certificates?limit=200&fields[certificates]=displayName,certificateType,expirationDate');

  const byType = {};
  for (const c of certs.data) {
    const type = c.attributes.certificateType;
    if (!byType[type]) byType[type] = [];
    byType[type].push(c);
  }

  let revoked = 0;
  for (const [type, list] of Object.entries(byType)) {
    if (list.length <= 1) continue;
    list.sort((a, b) => new Date(b.attributes.expirationDate) - new Date(a.attributes.expirationDate));
    for (const cert of list.slice(1)) {
      await request('DELETE', '/v1/certificates/' + cert.id);
      console.log('Revoked ' + type + ' cert: ' + cert.attributes.displayName + ' (expires ' + cert.attributes.expirationDate + ')');
      revoked++;
    }
  }

  console.log('Cleaned up ' + revoked + ' old certificates');
}

main().catch(e => { console.error(e.message); process.exit(1); });
