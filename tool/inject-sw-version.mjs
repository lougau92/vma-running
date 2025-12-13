import { readFileSync, writeFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const buildVersion = process.env.BUILD_NAME || 'local-dev';
const buildNumber = process.env.BUILD_NUMBER || '0';

const sanitize = (value) => value.replace(/[^0-9A-Za-z_.-]/g, '-');
const fullVersion = `${sanitize(buildVersion)}+${sanitize(buildNumber)}`;

const swPath = join(__dirname, '../web/service_worker.js');

try {
  const swContent = readFileSync(swPath, 'utf8');
  const cacheNameRegex = /const CACHE_NAME = '.*';/;

  if (!cacheNameRegex.test(swContent)) {
    console.error('Could not find CACHE_NAME in service_worker.js');
    process.exit(1);
  }

  const updatedContent = swContent.replace(
    cacheNameRegex,
    `const CACHE_NAME = 'vma-running-cache-${fullVersion}';`
  );

  writeFileSync(swPath, updatedContent);
  console.log(`Service worker stamped with cache version: ${fullVersion}`);
} catch (error) {
  console.error(error);
  process.exit(1);
}
