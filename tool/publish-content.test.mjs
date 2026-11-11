import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, mkdtemp, mkdir, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { root, sources, validateContent, loadContent, commitBody, publish } from './publish-content.mjs';

const script = path.join(root, 'tool/publish-content.mjs');

test('all shipped assets validate and retain their original text', async () => {
  const documents = await loadContent();
  assert.equal(documents.length, 3);
  for (const d of documents) {
    assert.equal(d.content, await readFile(path.join(root, sources[d.id]), 'utf8'));
  }
});

test('publishing makes one atomic request and changes only the content fields', async () => {
  const documents = await loadContent();
  const calls = [];
  const client = { post: async (...args) => {
    calls.push(args);
    return { body: { writeResults: documents.map(() => ({})) } };
  } };
  await publish(client, 'vma-training', documents);
  assert.equal(calls.length, 1);
  const [url, body, options] = calls[0];
  assert.equal(url, 'projects/vma-training/databases/(default)/documents:commit');
  assert.equal(body.writes.length, 3);
  for (const [i, write] of body.writes.entries()) {
    assert.equal(write.update.name, `projects/vma-training/databases/(default)/documents/app_documents/${documents[i].id}`);
    assert.deepEqual(write.updateMask.fieldPaths, ['content']);
    assert.deepEqual(write.update.fields, { content: { stringValue: documents[i].content } });
  }
  assert.equal(options.retries, 0);
  assert.deepEqual(options.skipLog, { body: true, resBody: true });
});

test('raw messages, malformed JSON, empty and oversized content are rejected', async () => {
  const raw = await readFile(path.join(root, 'assets/communications/raw_messages.json'), 'utf8');
  assert.throws(() => validateContent('club_communications', raw), /encrypted/);
  assert.throws(() => validateContent('training_plan', '{'), /invalid JSON/);
  assert.throws(() => validateContent('training_plan', '{}'), /structure/);
  assert.throws(() => validateContent('challenge_classement', 'wrong,header'), /header/);
  assert.throws(() => validateContent('training_plan', ' '), /nonempty/);
  assert.throws(() => validateContent('training_plan', 'é'.repeat(500001)), /UTF-8 bytes/);
});

test('invalid input in any file aborts loading the complete batch', async () => {
  const directory = await mkdtemp(path.join(tmpdir(), 'vma-publish-'));
  try {
    for (const [id, file] of Object.entries(sources)) {
      const target = path.join(directory, file);
      await mkdir(path.dirname(target), { recursive: true });
      await writeFile(target, id === 'club_communications' ? '{}' : await readFile(path.join(root, file)));
    }
    await assert.rejects(loadContent(Object.keys(sources), directory), /encrypted/);
  } finally { await rm(directory, { recursive: true, force: true }); }
});

test('selection and project validation prevent unintended targets', async () => {
  await assert.rejects(loadContent(['raw_messages']), /Choose documents/);
  for (const project of [undefined, '', 'bad/project', 'UpperCase']) {
    assert.throws(() => commitBody(project, []), /project ID/);
  }
  assert.throws(() => commitBody('vma-training', [{ id: '../other', content: '{}' }]), /Unknown/);
  assert.deepEqual((await loadContent(['training_plan'])).map(d => d.id), ['training_plan']);
});

test('failed or unconfirmed server writes are not reported as success', async () => {
  const docs = await loadContent(['training_plan']);
  await assert.rejects(publish({ post: async () => { throw new Error('denied'); } }, 'vma-training', docs), /denied/);
  await assert.rejects(publish({ post: async () => ({ body: {} }) }, 'vma-training', docs), /not confirm/);
});

test('default dry run works outside the repository without authentication', () => {
  const result = spawnSync(process.execPath, [script], {
    cwd: tmpdir(), encoding: 'utf8', env: { ...process.env, FIREBASE_TOKEN: 'must-not-be-used' },
  });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Dry run/);
  assert.match(result.stdout, /Project: vma-training/);
  assert.doesNotMatch(result.stdout + result.stderr, /must-not-be-used/);
});

test('conflicting flags fail before authentication or a remote write', () => {
  const result = spawnSync(process.execPath, [script, '--write', '--dry-run'], { encoding: 'utf8' });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /Choose --write or --dry-run/);
});
