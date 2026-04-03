/**
 * fix_right_arm_v2.mjs
 * Patch GLB JSON-only: redirect frozen CC_Base_R_* animation samplers to
 * reference the same accessor indices as their CC_Base_L_* counterparts.
 *
 * - BIN chunk is NOT touched (file stays structurally identical to original)
 * - Only the JSON chunk is modified (sampler input/output indices updated)
 * - No external dependencies — pure Node.js binary manipulation
 */

import { readFileSync, writeFileSync, existsSync, copyFileSync } from 'fs';

const FROZEN_THRESHOLD = 3; // ≤ this many keyframes = frozen

const DEMONS = [
  'demon_voidborn',
  'demon_taurex',
  'demon_spectre',
  'demon_ravager',
];

const BASE = 'G:/NeuroHell/assets/demon';

function readGLB(path) {
  const buf = readFileSync(path);
  // Header
  const magic   = buf.readUInt32LE(0);
  const version = buf.readUInt32LE(4);
  if (magic !== 0x46546C67) throw new Error('Not a GLB file');

  // JSON chunk (chunk 0)
  const jsonLen  = buf.readUInt32LE(12);
  const jsonType = buf.readUInt32LE(16);
  if (jsonType !== 0x4E4F534A) throw new Error('Chunk 0 is not JSON');
  const jsonBuf  = buf.slice(20, 20 + jsonLen);
  const json     = JSON.parse(jsonBuf.toString('utf8'));

  // BIN chunk (chunk 1), offset = 12 (header) + 8 (chunk0 header) + jsonLen
  const binOffset = 20 + jsonLen;
  const binLen    = buf.readUInt32LE(binOffset);
  const binType   = buf.readUInt32LE(binOffset + 4);
  if (binType !== 0x004E4942) throw new Error('Chunk 1 is not BIN');
  const binBuf    = buf.slice(binOffset + 8, binOffset + 8 + binLen);

  return { json, binBuf };
}

function writeGLB(path, json, binBuf) {
  const jsonStr  = JSON.stringify(json);
  // JSON chunk must be 4-byte aligned, padded with spaces
  const jsonPad  = (4 - (jsonStr.length % 4)) % 4;
  const jsonFull = jsonStr + ' '.repeat(jsonPad);
  const jsonBytes = Buffer.from(jsonFull, 'utf8');

  // BIN chunk must be 4-byte aligned, padded with 0x00
  const binPad  = (4 - (binBuf.length % 4)) % 4;
  const binFull = binPad > 0 ? Buffer.concat([binBuf, Buffer.alloc(binPad)]) : binBuf;

  const totalLen = 12 + 8 + jsonBytes.length + 8 + binFull.length;

  const out = Buffer.allocUnsafe(totalLen);
  let off = 0;

  // GLB header
  out.writeUInt32LE(0x46546C67, off); off += 4; // magic 'glTF'
  out.writeUInt32LE(2, off); off += 4;           // version
  out.writeUInt32LE(totalLen, off); off += 4;    // total length

  // JSON chunk
  out.writeUInt32LE(jsonBytes.length, off); off += 4;
  out.writeUInt32LE(0x4E4F534A, off); off += 4; // 'JSON'
  jsonBytes.copy(out, off); off += jsonBytes.length;

  // BIN chunk
  out.writeUInt32LE(binFull.length, off); off += 4;
  out.writeUInt32LE(0x004E4942, off); off += 4; // 'BIN\0'
  binFull.copy(out, off); off += binFull.length;

  writeFileSync(path, out);
}

/** Count keyframes for a given accessor index */
function accessorKFCount(json, accIdx) {
  if (accIdx === undefined || accIdx === null) return 0;
  const acc = json.accessors[accIdx];
  if (!acc) return 0;
  if (acc.sparse) return acc.sparse.count;
  return acc.count;
}

function fixGLB(name) {
  // Always patch from the BACKUP (clean original)
  const backup = `${BASE}/${name}_backup.glb`;
  const output = `${BASE}/${name}.glb`;

  if (!existsSync(backup)) {
    console.log(`[SKIP] No backup for ${name}`);
    return;
  }

  console.log(`\n=== ${name} ===`);
  const { json, binBuf } = readGLB(backup);

  // Build node-name -> nodeIndex map
  const nodeByName = {};
  (json.nodes || []).forEach((node, i) => {
    if (node.name) nodeByName[node.name] = i;
  });

  let totalFixed = 0;

  for (const anim of json.animations || []) {
    const { channels = [], samplers = [] } = anim;

    // Build a map from (nodeIndex, path) -> samplerIndex for quick lookup
    const samplerMap = new Map();
    for (const ch of channels) {
      const key = `${ch.target.node}:${ch.target.path}`;
      samplerMap.set(key, ch.sampler);
    }

    let fixedInAnim = 0;
    for (const ch of channels) {
      const nodeName = json.nodes[ch.target.node]?.name ?? '';
      if (!nodeName.includes('_R_')) continue;

      const sIdx = ch.sampler;
      const samp = samplers[sIdx];
      if (!samp) continue;

      const kf = accessorKFCount(json, samp.output);
      if (kf > FROZEN_THRESHOLD) continue; // not frozen

      // Find L counterpart
      const leftName = nodeName.replace('_R_', '_L_');
      const leftNodeIdx = nodeByName[leftName];
      if (leftNodeIdx === undefined) {
        console.log(`  [WARN] No L node for ${leftName}`);
        continue;
      }

      const leftKey = `${leftNodeIdx}:${ch.target.path}`;
      const leftSamplerIdx = samplerMap.get(leftKey);
      if (leftSamplerIdx === undefined) {
        console.log(`  [WARN] No L sampler for ${leftName}.${ch.target.path} in "${anim.name}"`);
        continue;
      }

      const leftSamp = samplers[leftSamplerIdx];
      const leftKF = accessorKFCount(json, leftSamp.output);
      if (leftKF <= FROZEN_THRESHOLD) continue; // L also frozen, skip

      console.log(`  FIX  ${nodeName}.${ch.target.path}: ${kf} kf -> ${leftKF} kf`);

      // Redirect R sampler to use L sampler's input+output accessors
      samp.input  = leftSamp.input;
      samp.output = leftSamp.output;

      fixedInAnim++;
      totalFixed++;
    }

    if (fixedInAnim > 0) {
      console.log(`  -> "${anim.name}": fixed ${fixedInAnim} track(s)`);
    }
  }

  if (totalFixed === 0) {
    console.log('  No frozen R tracks found in backup.');
    return;
  }

  writeGLB(output, json, binBuf);
  console.log(`  Saved ${output} (${totalFixed} tracks fixed, BIN unchanged)`);
}

for (const name of DEMONS) {
  fixGLB(name);
}
console.log('\nDone.');
