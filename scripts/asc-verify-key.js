#!/usr/bin/env node
// Verify the ASC API key works by hitting a low-impact endpoint.
// Reads creds the same way as other asc-* scripts (env vars or local files).
const fs = require('fs');
const { createClient } = require('./asc-lib');

async function main() {
  const asc = createClient({});
  // Show what we're using (without leaking the key body)
  const path = require('path');
  const repoDir = path.resolve(__dirname, '..');
  const keyId = process.env.ASC_KEY_ID || (() => {
    const f = fs.readdirSync(repoDir).find(n => /^AuthKey_.+\.p8$/.test(n));
    return f ? f.match(/^AuthKey_(.+)\.p8$/)[1] : '?';
  })();
  const issuerId = process.env.ASC_ISSUER_ID || (() => {
    try { return fs.readFileSync(path.join(repoDir, 'apple-issuer-id.txt'), 'utf8').trim(); } catch { return '?'; }
  })();
  const keyPath = process.env.ASC_KEY_PATH || path.join(repoDir, `AuthKey_${keyId}.p8`);
  const keySize = fs.existsSync(keyPath) ? fs.statSync(keyPath).size : 0;

  console.log(`Key ID:    ${keyId}`);
  console.log(`Issuer:    ${issuerId}`);
  console.log(`Key file:  ${keyPath} (${keySize} bytes)`);
  console.log('');

  console.log('Calling GET /v1/users?limit=1 ...');
  const res = await asc.get('/v1/users?limit=1');
  const total = res.meta?.paging?.total ?? res.data.length;
  console.log(`OK — auth works. Team has ${total} user(s) visible to this key.`);
}

main().catch(e => {
  console.error('FAILED:', e.message);
  console.error('');
  console.error('If 401: key may be revoked, or key ID / issuer ID / .p8 contents are wrong.');
  console.error('If 403: key is valid but lacks the role needed for this call.');
  process.exit(1);
});
