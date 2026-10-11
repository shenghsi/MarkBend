import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const load = async name => JSON.parse(await readFile(new URL(name, import.meta.url), 'utf8'));
const navigation = await load('static-height-controls.json');
const editing = await load('static-edit-height-controls.json');
assert.equal(navigation.length, 8);
assert.equal(editing.length, 4);
const matrix = records => new Set(records.map(r => [r.indexed, r.control, r.reverse].join('/')));
assert.equal(matrix(navigation).size, 8);
assert.equal(matrix(editing).size, 4);
const navigationActions = ['top', 'middle', 'end', 'distant', 'owner', 'narrow', 'find', 'top', 'middle', 'end'];
const editActions = ['edit-anchor', 'unicode-edit', 'distant', 'narrow', 'undo', 'redo', 'source', 'live', 'end'];
function geometry(x) {
  assert.equal(x.error, undefined);
  assert.equal(x.settling.status, 'stable');
  assert.ok(x.settling.samples.length >= 8);
  assert.equal(x.differences.length, 0);
  assert.ok(x.boxes.length > 0);
  assert.ok(x.boxes.every(box => box.delta === 0 && box.textEqual));
  assert.equal(x.maxHeightDelta, 0);
  assert.equal(x.candidateEstimatedHeight, x.baselineEstimatedHeight);
  assert.equal(x.candidateHead.scrollHeight, x.baselineHead.scrollHeight);
  assert.equal(x.candidateHead.scrollTop, x.baselineHead.scrollTop);
  assert.equal(x.candidateHead.relativeTop, x.baselineHead.relativeTop);
  assert.equal(x.candidateHead.head, x.baselineHead.head);
  assert.ok(x.sourceEqual && x.complete && x.baselineComplete);
  assert.ok(x.sourceUnchangedByCheck && x.historyUnchangedByCheck);
  assert.ok(x.sourceUnchangedDuringSettle && x.historyUnchangedDuringSettle);
}
for (const record of navigation) {
  assert.equal(record.checking, false);
  assert.deepEqual(record.batchResults.map(x => x.action), navigationActions);
  for (const x of record.batchResults) {
    geometry(x); assert.ok(x.exactOriginal); assert.equal(x.history, 0);
  }
}
for (const record of editing) {
  assert.equal(record.checking, false); assert.equal(record.indexed, true);
  assert.deepEqual(record.editResults.map(x => x.action), editActions);
  for (const x of record.editResults) {
    geometry(x); assert.ok(x.exactExpected && x.selectionEqual);
    assert.deepEqual(x.fonts[0], x.fonts[1]);
    assert.equal(x.history, ['edit-anchor', 'undo'].includes(x.action) ? 0 : 1);
    assert.equal(x.exactOriginal, ['edit-anchor', 'undo'].includes(x.action));
  }
  const edit = record.editResults.find(x => x.action === 'unicode-edit');
  if (!record.control) {
    assert.equal(record.editMode, 'indexed');
    assert.equal(edit.readiness.before, 'indexed'); assert.equal(edit.readiness.after, 'indexed');
  }
  assert.equal(record.editResults.find(x => x.action === 'source').readiness.after, 'source');
}
console.log(JSON.stringify({ navigationChecks: 80, editChecks: 36, geometry: 'exact',
  scope: 'static projection with complete trees; comparator unchanged; no input, latency, memory or native acceptance claim' }, null, 2));
