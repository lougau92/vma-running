/* tool/inject-sw-version.js */
const fs = require('fs');
const path = require('path');

// Read environment variables passed by GitHub Actions
// Fallback to 'local-dev' if running on your machine
const buildVersion = process.env.BUILD_NAME || '1.0.0';
const buildNumber = process.env.BUILD_NUMBER || '1';
const fullVersion = `${buildVersion}+${buildNumber}`;

const swPath = path.join(__dirname, '../web/service_worker.js');

try {
    let swContent = fs.readFileSync(swPath, 'utf8');

    // Replace the cache name with the dynamic version
    const cacheNameRegex = /const CACHE_NAME = '.*';/;
    const newCacheLine = `const CACHE_NAME = 'vma-running-cache-${fullVersion}';`;

    if (swContent.match(cacheNameRegex)) {
        swContent = swContent.replace(cacheNameRegex, newCacheLine);
        fs.writeFileSync(swPath, swContent);
        console.log(`✅ Service Worker stamped with: ${fullVersion}`);
    } else {
        console.error('❌ Could not find CACHE_NAME in service_worker.js');
        process.exit(1);
    }
} catch (err) {
    console.error(err);
    process.exit(1);
}
