#!/bin/bash
# Show detailed info about a specific build (read-only)
# Usage: asc-build-detail.sh [build-number]
set -e
source "$(dirname "$0")/asc-config.sh"

BUILD_NUM="${1:-}"

ASC_KEY_ID="$ASC_KEY_ID" ASC_ISSUER_ID="$ASC_ISSUER_ID" ASC_KEY_PATH="$ASC_KEY_FILE" \
node -e "
const { createClient } = require('./scripts/asc-lib');
const asc = createClient({});

(async () => {
  const builds = await asc.get('/v1/builds?sort=-uploadedDate&limit=10&fields[builds]=version,processingState,uploadedDate,usesNonExemptEncryption,minOsVersion');
  const build = '$BUILD_NUM' ? builds.data.find(b => b.attributes.version === '$BUILD_NUM') : builds.data[0];
  if (!build) { console.error('Build not found'); process.exit(1); }
  const a = build.attributes;
  console.log('Build ' + a.version);
  console.log('  processingState: ' + a.processingState);
  console.log('  uploadedDate: ' + a.uploadedDate);
  console.log('  usesNonExemptEncryption: ' + a.usesNonExemptEncryption);

  try {
    const detail = await asc.get('/v1/builds/' + build.id + '/buildBetaDetail');
    const d = detail.data.attributes;
    console.log('  externalBuildState: ' + d.externalBuildState);
    console.log('  internalBuildState: ' + d.internalBuildState);
  } catch(e) {}
})().catch(e => { console.error(e.message); process.exit(1); });
"
