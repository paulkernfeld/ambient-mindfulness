#!/usr/bin/env node
// List recent TestFlight builds (read-only)
const { createClient } = require('./asc-lib');

(async () => {
  const asc = createClient();
  const builds = await asc.get('/v1/builds?sort=-uploadedDate&limit=5&fields[builds]=version,processingState,uploadedDate');
  for (const b of builds.data) {
    const a = b.attributes;
    console.log(`Build ${a.version}  state=${a.processingState}  uploaded=${a.uploadedDate}`);
  }
})().catch(e => { console.error(e.message); process.exit(1); });
