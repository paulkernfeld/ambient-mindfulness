// Shared ASC API library — JWT auth + HTTP helpers
// Usage: require('./asc-lib') or run directly to print a token
const crypto = require('crypto');
const https = require('https');
const fs = require('fs');

function createToken(keyId, issuerId, keyPath) {
  const key = fs.readFileSync(keyPath, 'utf8');
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'ES256', kid: keyId, typ: 'JWT' };
  const payload = { iss: issuerId, iat: now, exp: now + 1200, aud: 'appstoreconnect-v1' };
  const b64 = (obj) => Buffer.from(JSON.stringify(obj)).toString('base64url');
  const sigInput = b64(header) + '.' + b64(payload);
  const sig = crypto.sign('sha256', Buffer.from(sigInput), { key, dsaEncoding: 'ieee-p1363' });
  return sigInput + '.' + sig.toString('base64url');
}

function request(token, method, path, body) {
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
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

function createClient(opts) {
  const keyId = opts.keyId || process.env.ASC_KEY_ID;
  const issuerId = opts.issuerId || process.env.ASC_ISSUER_ID;
  const keyPath = opts.keyPath || process.env.ASC_KEY_PATH;
  if (!keyId || !issuerId || !keyPath) {
    throw new Error('Missing: keyId, issuerId, keyPath (or ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH env vars)');
  }
  const token = createToken(keyId, issuerId, keyPath);
  return {
    get: (path) => request(token, 'GET', path),
    post: (path, body) => request(token, 'POST', path, body),
    patch: (path, body) => request(token, 'PATCH', path, body),
    del: (path) => request(token, 'DELETE', path),
  };
}

module.exports = { createToken, request, createClient };
