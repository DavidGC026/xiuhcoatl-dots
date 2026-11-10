const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');
const model = {};
vm.createContext(model);
vm.runInContext(fs.readFileSync(path.join(__dirname, '../OverviewModel.js'), 'utf8').replace(/^\.pragma library\n/, ''), model);
const plain = value => JSON.parse(JSON.stringify(value));
const windows = [
  {id: 'hypr:abc', nativeId: 'abc', title: 'Informe noviembre', appId: 'Temoa', workspaceLabel: '1', workspace: 0, output: 'eDP-1', lastFocus: 10},
  {id: 'hypr:def', nativeId: '0xdef', title: 'Xiuhcóatl', appId: 'Kitty', workspaceLabel: 'Trabajo', workspace: -1, output: 'HDMI-A-1', focused: true}
];
test('search matches every word across title, app, workspace and output', () => {
  const snapshot = model.snapshot(windows);
  assert.equal(model.filtered(snapshot, 'informe TEMOA', '').length, 1);
  assert.equal(model.filtered(snapshot, 'kitTy hdmi', 'Trabajo').length, 1);
  assert.equal(model.filtered(snapshot, 'informe kitty', '').length, 0);
  assert.equal(model.filtered(snapshot, '', '10').length, 0);
});
test('native title/workspace changes supersede stale tracker metadata', () => {
  const result = model.snapshot([{...windows[0], native: {title: 'Nuevo título', workspace: {id: 4, name: '4'}, monitor: {name: 'DP-1'}, activated: true}}]);
  assert.equal(result[0].title, 'Nuevo título');
  assert.equal(result[0].workspaceLabel, '4');
  assert.equal(result[0].output, 'DP-1');
});
test('focused window sorts first and vanished selection falls back', () => {
  const result = model.snapshot(windows);
  assert.equal(result[0].id, 'hypr:def');
  assert.equal(model.selectedIndex(result, 'missing'), 0);
  assert.equal(model.selectedIndex([], 'missing'), -1);
});
test('empty workspaces remain destinations and named/special ones join them', () => {
  const result = model.workspaces([{id: -1, name: 'Trabajo', active: true}, {id: -99, name: 'special:scratch'}], model.snapshot(windows));
  assert.equal(result.length, 12);
  assert.equal(result.find(ws => ws.label === '1').count, 1);
  assert.equal(result.find(ws => ws.label === 'Trabajo').count, 1);
  assert.equal(result.find(ws => ws.label === '10').count, 0);
});
test('renamed numbered workspace appears once', () => {
  const result = model.workspaces([{id: 1, name: 'Trabajo'}], []);
  assert.equal(result.length, 10);
  assert.equal(result.filter(ws => ws.id === 1).length, 1);
});
test('Lua move addresses an exact window and preserves current desktop', () => {
  assert.equal(model.moveCommand(windows[0], {id: 3, label: '3'}, true), 'hl.dsp.window.move({ window = "address:0xabc", workspace = "3", follow = false })');
  assert.equal(model.moveCommand(windows[1], {id: -99, label: 'special:scratch'}, true), 'hl.dsp.window.move({ window = "address:0xdef", workspace = "special:scratch", follow = false })');
});
test('named workspace strings are quoted and invalid addresses rejected', () => {
  assert.equal(model.workspaceTarget({id: -1, label: 'Trabajo'}), 'name:Trabajo');
  const command = model.moveCommand(windows[0], {id: -1, label: 'a"\\b\n'}, true);
  assert.ok(command.includes('workspace = "name:a\\"\\\\b\\n"'));
  assert.equal(model.moveCommand({nativeId: 'abc); evil()'}, {id: 1, label: '1'}, true), '');
});
test('legacy movement rejects separators and uses silent exact-window dispatch', () => {
  assert.equal(model.moveCommand(windows[0], {id: 2, label: '2'}, false), 'movetoworkspacesilent 2,address:0xabc');
  assert.equal(model.moveCommand(windows[0], {id: -1, label: 'foo,bar'}, false), '');
});

test('metadata polling preserves thumbnail delegates until content changes', () => {
  const a = model.snapshot(windows);
  const b = model.snapshot(windows);
  assert.equal(model.sameWindows(a, b), true);
  b[0].title = 'Renamed';
  assert.equal(model.sameWindows(a, b), false);
  assert.equal(model.sameWindows(a, []), false);
  const wa = model.workspaces([], a);
  assert.equal(model.sameWorkspaces(wa, model.workspaces([], a)), true);
  assert.equal(model.sameWorkspaces(wa, model.workspaces([], [])), false);
});

test('workspace activation handles empty, named and special workspaces', () => {
  assert.equal(model.workspaceCommand({id: 97, label: '97'}, true), 'hl.dsp.focus({ workspace = "97" })');
  assert.equal(model.workspaceCommand({id: -1, label: 'Trabajo'}, true), 'hl.dsp.focus({ workspace = "name:Trabajo" })');
  assert.equal(model.workspaceCommand({id: -99, label: 'special:scratch'}, false), 'togglespecialworkspace scratch');
});
