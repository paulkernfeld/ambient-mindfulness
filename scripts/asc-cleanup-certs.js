// Revoke old signing certificates, keeping only the newest per type.
// Runs in CI before archive to prevent hitting Apple's cert limit.
// Env vars: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH
const { createClient } = require('./asc-lib');

async function main() {
  const asc = createClient({});

  const certs = await asc.get('/v1/certificates?limit=200&fields[certificates]=displayName,certificateType,expirationDate');

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
      await asc.del('/v1/certificates/' + cert.id);
      console.log('Revoked ' + type + ' cert: ' + cert.attributes.displayName + ' (expires ' + cert.attributes.expirationDate + ')');
      revoked++;
    }
  }

  console.log('Cleaned up ' + revoked + ' old certificates');
}

main().catch(e => { console.error(e.message); process.exit(1); });
