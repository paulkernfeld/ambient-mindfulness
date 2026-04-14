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

// Default config: env vars (CI) or local files (dev)
function resolveConfig(opts = {}) {
  const path = require('path');
  const repoDir = path.resolve(__dirname, '..');
  const issuerId = opts.issuerId || process.env.ASC_ISSUER_ID ||
    (() => { try { return fs.readFileSync(path.join(repoDir, 'apple-issuer-id.txt'), 'utf8').trim(); } catch { return null; } })();
  // Key ID from opts, env, or derived from AuthKey_*.p8 filename
  const keyId = opts.keyId || process.env.ASC_KEY_ID ||
    (() => { try { const files = require('fs').readdirSync(repoDir).filter(f => f.match(/^AuthKey_(.+)\.p8$/)); return files[0]?.match(/^AuthKey_(.+)\.p8$/)?.[1] || null; } catch { return null; } })();
  const keyPath = opts.keyPath || process.env.ASC_KEY_PATH ||
    (() => { if (!keyId) return null; const p = path.join(repoDir, `AuthKey_${keyId}.p8`); return fs.existsSync(p) ? p : null; })();
  if (!keyId || !issuerId || !keyPath) {
    throw new Error('Missing ASC config. Set ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH env vars, or run from repo root with local credential files.');
  }
  return { keyId, issuerId, keyPath };
}

function createClient(opts = {}) {
  const { keyId, issuerId, keyPath } = resolveConfig(opts);
  const token = createToken(keyId, issuerId, keyPath);
  return {
    get: (path) => request(token, 'GET', path),
    post: (path, body) => request(token, 'POST', path, body),
    patch: (path, body) => request(token, 'PATCH', path, body),
    del: (path) => request(token, 'DELETE', path),
  };
}

module.exports = { createToken, request, createClient };
