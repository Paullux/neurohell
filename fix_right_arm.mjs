/**
 * fix_right_arm.mjs
 * Fix frozen CC_Base_R_* animation tracks in AccuRig humanoid GLB files.
 * Strategy: for each R-side track with ≤ 2 keyframes, copy data from the
 * matching L-side track in the same animation.
 *
 * CC4 skeleton is fully symmetric — local bone orientations mirror each other,
 * so left quaternion values produce correct right-side world-space motion.
 */

import { readFileSync, writeFileSync, existsSync, cpSync } from 'fs';
import { NodeIO } from '@gltf-transform/core';
import { resolve } from 'path';

const DEMONS = [
  'demon_voidborn.glb',
  'demon_taurex.glb',
  'demon_spectre.glb',
  'demon_ravager.glb',
];

const BASE = 'G:/NeuroHell/assets/demon';
const FROZEN_THRESHOLD = 3; // ≤ this many keyframes = considered frozen

const io = new NodeIO();

async function fixGLB(filename) {
  const path = `${BASE}/${filename}`;
  console.log(`\n=== Processing ${filename} ===`);

  const doc = await io.read(path);
  const root = doc.getRoot();
  const animations = root.listAnimations();
  console.log(`  Animations: ${animations.length}`);

  let totalFixed = 0;

  for (const anim of animations) {
    const animName = anim.getName();
    const channels = anim.listChannels();

    // Build a map: boneName -> { path -> sampler } for quick lookup
    const trackMap = new Map(); // key: `${boneName}.${path}` -> channel
    for (const ch of channels) {
      const target = ch.getTargetNode();
      const path = ch.getTargetPath();
      if (!target) continue;
      const key = `${target.getName()}.${path}`;
      trackMap.set(key, ch);
    }

    // Find frozen R channels and fix them from L counterparts
    let fixedInAnim = 0;
    for (const ch of channels) {
      const target = ch.getTargetNode();
      if (!target) continue;
      const boneName = target.getName();
      const path = ch.getTargetPath(); // 'rotation' | 'translation' | 'scale'

      // Only care about Right-side bones
      if (!boneName.includes('_R_')) continue;

      const sampler = ch.getSampler();
      if (!sampler) continue;
      const outputAcc = sampler.getOutput();
      if (!outputAcc) continue;

      const kfCount = outputAcc.getCount();
      if (kfCount > FROZEN_THRESHOLD) continue; // Not frozen, skip

      // Find matching Left bone
      const leftBoneName = boneName.replace('_R_', '_L_');
      const leftKey = `${leftBoneName}.${path}`;
      const leftCh = trackMap.get(leftKey);

      if (!leftCh) {
        console.log(`    [WARN] No L counterpart for ${boneName}.${path} in "${animName}"`);
        continue;
      }

      const leftSampler = leftCh.getSampler();
      const leftInput = leftSampler.getInput();
      const leftOutput = leftSampler.getOutput();
      if (!leftInput || !leftOutput) continue;

      const leftKfCount = leftOutput.getCount();
      if (leftKfCount <= FROZEN_THRESHOLD) {
        console.log(`    [SKIP] L counterpart also frozen: ${leftBoneName}.${path} (${leftKfCount} kf)`);
        continue;
      }

      console.log(`    FIX  ${boneName}.${path}: ${kfCount} kf -> ${leftKfCount} kf (from ${leftBoneName})`);

      // Copy timestamps (input)
      const currentInput = sampler.getInput();
      const leftInputArray = leftInput.getArray();
      currentInput.setArray(leftInputArray.slice());
      try { currentInput.setMin(leftInput.getMin([])); } catch (e) {}
      try { currentInput.setMax(leftInput.getMax([])); } catch (e) {}

      // Copy output values (setArray automatically updates count)
      const leftOutputArray = leftOutput.getArray();
      outputAcc.setArray(leftOutputArray.slice());
      try { outputAcc.setMin(leftOutput.getMin([])); } catch (e) {}
      try { outputAcc.setMax(leftOutput.getMax([])); } catch (e) {}

      fixedInAnim++;
      totalFixed++;
    }

    if (fixedInAnim > 0) {
      console.log(`  -> Animation "${animName}": fixed ${fixedInAnim} track(s)`);
    }
  }

  if (totalFixed === 0) {
    console.log('  No frozen R tracks found — file unchanged.');
    return;
  }

  // Backup original
  const backup = path.replace('.glb', '_backup.glb');
  if (!existsSync(backup)) {
    cpSync(path, backup);
    console.log(`  Backup saved: ${backup}`);
  }

  await io.write(path, doc);
  console.log(`  Saved: ${path} (fixed ${totalFixed} tracks total)`);
}

(async () => {
  for (const demon of DEMONS) {
    await fixGLB(demon);
  }
  console.log('\nDone.');
})();
