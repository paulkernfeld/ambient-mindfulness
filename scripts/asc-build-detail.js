#!/usr/bin/env node
// Show detailed info about a build (read-only)
// Usage: node asc-build-detail.js [build-number]
const { createClient } = require('./asc-lib');

const buildNum = process.argv[2];

(async () => {
  const asc = createClient();
  const builds = await asc.get('/v1/builds?sort=-uploadedDate&limit=10&fields[builds]=version,processingState,uploadedDate,usesNonExemptEncryption');
  const build = buildNum ? builds.data.find(b => b.attributes.version === buildNum) : builds.data[0];
  if (!build) { console.error('Build not found'); process.exit(1); }

  const a = build.attributes;
  console.log(`Build ${a.version}`);
  console.log(`  processingState: ${a.processingState}`);
  console.log(`  uploadedDate: ${a.uploadedDate}`);
  console.log(`  usesNonExemptEncryption: ${a.usesNonExemptEncryption}`);

  try {
    const detail = await asc.get(`/v1/builds/${build.id}/buildBetaDetail`);
    const d = detail.data.attributes;
    console.log(`  externalBuildState: ${d.externalBuildState}`);
    console.log(`  internalBuildState: ${d.internalBuildState}`);
  } catch {}
})().catch(e => { console.error(e.message); process.exit(1); });
