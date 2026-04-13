#!/bin/bash
# Check TestFlight beta groups and their builds (read-only)
set -e
source "$(dirname "$0")/asc-config.sh"

ASC_KEY_ID="$ASC_KEY_ID" ASC_ISSUER_ID="$ASC_ISSUER_ID" ASC_KEY_PATH="$ASC_KEY_FILE" \
node -e "
const { createClient } = require('./scripts/asc-lib');
const asc = createClient({});

(async () => {
  const apps = await asc.get('/v1/apps?filter[bundleId]=com.paulkernfeld.ambientmindfulness');
  const app = apps.data[0];
  if (!app) { console.log('App not found'); process.exit(1); }
  console.log('App: ' + app.attributes.name + ' (' + app.id + ')');

  const groups = await asc.get('/v1/apps/' + app.id + '/betaGroups');
  console.log('\nBeta Groups:');
  for (const g of groups.data) {
    console.log('  ' + g.attributes.name + ' (internal=' + g.attributes.isInternalGroup + ')');
    const builds = await asc.get('/v1/betaGroups/' + g.id + '/builds?limit=5');
    if (builds.data.length === 0) {
      console.log('    No builds assigned');
      continue;
    }
    for (const b of builds.data) {
      const bd = await asc.get('/v1/builds/' + b.id + '?fields[builds]=version,processingState,uploadedDate');
      const a = bd.data.attributes;
      console.log('    Build ' + a.version + '  state=' + a.processingState + '  uploaded=' + a.uploadedDate);
    }
  }

  console.log('\nLatest builds (all):');
  const allBuilds = await asc.get('/v1/builds?sort=-uploadedDate&limit=5&fields[builds]=version,processingState,uploadedDate');
  for (const b of allBuilds.data) {
    const a = b.attributes;
    console.log('  Build ' + a.version + '  state=' + a.processingState + '  uploaded=' + a.uploadedDate);
  }
})().catch(e => { console.error(e.message); process.exit(1); });
"
