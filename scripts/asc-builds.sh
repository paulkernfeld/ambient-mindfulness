#!/bin/bash
# List recent TestFlight builds from App Store Connect (read-only)
set -e
source "$(dirname "$0")/asc-config.sh"

ASC_KEY_ID="$ASC_KEY_ID" ASC_ISSUER_ID="$ASC_ISSUER_ID" ASC_KEY_PATH="$ASC_KEY_FILE" \
node -e "
const { createClient } = require('./scripts/asc-lib');
const asc = createClient({});

(async () => {
  const builds = await asc.get('/v1/builds?sort=-uploadedDate&limit=5&fields[builds]=version,processingState,uploadedDate');
  for (const b of builds.data) {
    const a = b.attributes;
    console.log('Build ' + a.version + '  state=' + a.processingState + '  uploaded=' + a.uploadedDate);
  }
})().catch(e => { console.error(e.message); process.exit(1); });
"
