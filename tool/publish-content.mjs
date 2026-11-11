import { readFile } from 'node:fs/promises';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { parseArgs } from 'node:util';
import path from 'node:path';

export const root = fileURLToPath(new URL('../', import.meta.url));
export const sources = Object.freeze({
  training_plan: 'assets/training_plans/training_example.json',
  club_communications: 'assets/communications/messages.json',
  challenge_classement: 'assets/enjambee_challenge/classement_challenge_enjambee_2025_12_10_2025.csv',
});
const defaultProject = 'vma-training';

export function validateContent(id, content) {
  if (!content.trim() || Buffer.byteLength(content) > 1_000_000) {
    throw new Error(`${id}: file must be nonempty and at most 1,000,000 UTF-8 bytes.`);
  }
  if (id === 'challenge_classement') {
    if (content.split(/\r?\n/, 1)[0] !== 'Nom,Prenom,Dernière course,Total,Participations') {
      throw new Error(`${id}: unexpected CSV header.`);
    }
    return;
  }
  let data;
  try { data = JSON.parse(content); }
  catch { throw new Error(`${id}: invalid JSON.`); }
  if (id === 'training_plan') {
    if (!['title', 'warmup', 'cooldown', 'remarks'].every(k => typeof data?.[k] === 'string') ||
        !Array.isArray(data.groups) || !data.groups.length ||
        !data.groups.every(g => typeof g?.title === 'string' && Array.isArray(g.blocks) &&
          g.blocks.every(b => typeof b?.title === 'string' && Array.isArray(b.sets)))) {
      throw new Error(`${id}: invalid training plan structure.`);
    }
  } else if (id === 'club_communications') {
    if (data?.version !== 2 || !Array.isArray(data.messages) ||
        typeof data.kdf?.salt !== 'string' || !Number.isInteger(data.kdf.iterations) ||
        data.kdf.iterations < 1 || !data.messages.every(m =>
          ['nonce', 'cipher', 'tag'].every(k => typeof m?.[k] === 'string' && m[k]) &&
          !['title', 'summary', 'body'].some(k => Object.hasOwn(m, k)))) {
      throw new Error(`${id}: expected encrypted version-2 messages, not raw messages.`);
    }
  } else {
    throw new Error('Unknown content document.');
  }
}

export async function loadContent(ids = Object.keys(sources), directory = root) {
  if (!ids.length || ids.some(id => !Object.hasOwn(sources, id))) {
    throw new Error(`Choose documents from: ${Object.keys(sources).join(', ')}.`);
  }
  return Promise.all(ids.map(async id => {
    const file = sources[id];
    const bytes = await readFile(path.join(directory, file));
    const content = new TextDecoder('utf-8', { fatal: true }).decode(bytes);
    validateContent(id, content);
    return { id, file, content };
  }));
}

export function commitBody(project, documents) {
  if (typeof project !== 'string' || !/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(project)) {
    throw new Error('Invalid Firebase project ID.');
  }
  return { writes: documents.map(({ id, content }) => {
    if (!Object.hasOwn(sources, id)) throw new Error('Unknown content document.');
    return {
      update: {
        name: `projects/${project}/databases/(default)/documents/app_documents/${id}`,
        fields: { content: { stringValue: content } },
      },
      updateMask: { fieldPaths: ['content'] },
    };
  }) };
}

// Pinned firebase-tools internals reuse its saved login and token refresh.
// No credentials are copied, passed as arguments, or printed by this script.
export async function authenticatedClient(project) {
  const { getProjectDefaultAccount, setActiveAccount } = await import('firebase-tools/lib/auth.js');
  const { requireAuth } = await import('firebase-tools/lib/requireAuth.js');
  const { Client } = await import('firebase-tools/lib/apiv2.js');
  const account = getProjectDefaultAccount(root);
  if (!account) throw new Error('Sign in with firebase login first.');
  if (process.env.FIREBASE_TOKEN) throw new Error('Use the saved Firebase login, not FIREBASE_TOKEN.');
  const options = { project, projectRoot: root, nonInteractive: true };
  setActiveAccount(options, account);
  await requireAuth(options, true);
  return new Client({ urlPrefix: 'https://firestore.googleapis.com', apiVersion: 'v1', auth: true });
}

export async function publish(client, project, documents) {
  const body = commitBody(project, documents);
  const response = await client.post(
    `projects/${project}/databases/(default)/documents:commit`, body,
    { timeout: 30_000, retries: 0, skipLog: { body: true, resBody: true } },
  );
  if (response.body?.writeResults?.length !== documents.length) {
    throw new Error('The server response did not confirm every write; check the database before retrying.');
  }
}

async function main() {
  const { values } = parseArgs({ options: {
    project: { type: 'string' }, only: { type: 'string' },
    write: { type: 'boolean' }, 'dry-run': { type: 'boolean' }, help: { type: 'boolean' },
  } });
  if (values.help) {
    console.log('Usage: npm run content:publish -- [--dry-run | --write] [--only training_plan] [--project ID]');
    return;
  }
  if (values.write && values['dry-run']) throw new Error('Choose --write or --dry-run.');
  const project = values.project ?? defaultProject;
  const ids = values.only === undefined ? Object.keys(sources) : values.only.split(',');
  const documents = await loadContent(ids);
  commitBody(project, documents);
  console.log(`Project: ${project}; database: (default); collection: app_documents`);
  for (const d of documents) console.log(`  ${d.id} <- ${d.file} (${Buffer.byteLength(d.content)} bytes)`);
  if (!values.write) {
    console.log('Dry run: validated locally; no authentication or network calls. Add --write to publish.');
    return;
  }
  try {
    const client = await authenticatedClient(project);
    await publish(client, project, documents);
  } catch {
    throw new Error('Publish not confirmed. Check firebase login, the enabled Firestore API, the (default) database, and your IAM write access. No rules were changed.');
  }
  console.log(`Published ${documents.length} document(s) atomically. Other fields were preserved.`);
}

if (process.argv[1] && pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url) {
  main().catch(error => {
    // Remote errors are replaced above; never dump authenticated request objects.
    console.error(error.message);
    process.exitCode = 1;
  });
}
