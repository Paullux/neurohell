import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { readFileSync } from 'fs';

const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const document = await io.readBinary(readFileSync('assets/levels/neurohell_level_1.glb'));
const root = document.getRoot();

// --- Scènes & nœuds ---
console.log('\n=== SCENES ===');
root.listScenes().forEach((scene, i) => {
  console.log(`  Scene[${i}] "${scene.getName()}"`);
  scene.listChildren().forEach(n => logNode(n, '    '));
});

function logNode(node, indent = '') {
  const mesh = node.getMesh();
  const meshInfo = mesh
    ? ` → mesh:"${mesh.getName()}" (${mesh.listPrimitives().length} prim)`
    : '';
  console.log(`${indent}Node "${node.getName()}"${meshInfo}`);
  node.listChildren().forEach(c => logNode(c, indent + '  '));
}

// --- Meshes ---
console.log('\n=== MESHES ===');
root.listMeshes().forEach((mesh, i) => {
  const prims = mesh.listPrimitives();
  const mat = prims[0]?.getMaterial();
  console.log(`  [${i}] "${mesh.getName()}" — ${prims.length} primitive(s) — mat:"${mat?.getName() ?? 'none'}"`);
});

// --- Matériaux ---
console.log('\n=== MATERIALS ===');
root.listMaterials().forEach((mat, i) => {
  const base = mat.getBaseColorFactor();
  console.log(`  [${i}] "${mat.getName()}" baseColor:[${base.map(v=>v.toFixed(2))}]`);
});

// --- Textures ---
console.log('\n=== TEXTURES ===');
root.listTextures().forEach((tex, i) => {
  const size = tex.getImage()?.byteLength ?? 0;
  console.log(`  [${i}] "${tex.getName()}" — mime:${tex.getMimeType()} — ${(size/1024).toFixed(1)} KB`);
});

// --- Bounds via accessor min/max ---
console.log('\n=== BOUNDS (POSITION accessors) ===');
let globalMin = [Infinity,Infinity,Infinity];
let globalMax = [-Infinity,-Infinity,-Infinity];

root.listMeshes().forEach(mesh => {
  mesh.listPrimitives().forEach(prim => {
    const pos = prim.getAttribute('POSITION');
    if (!pos) return;
    const mn = pos.getMin([]);
    const mx = pos.getMax([]);
    for (let i = 0; i < 3; i++) {
      globalMin[i] = Math.min(globalMin[i], mn[i]);
      globalMax[i] = Math.max(globalMax[i], mx[i]);
    }
  });
});

console.log(`  Global MIN : x=${globalMin[0].toFixed(2)}  y=${globalMin[1].toFixed(2)}  z=${globalMin[2].toFixed(2)}`);
console.log(`  Global MAX : x=${globalMax[0].toFixed(2)}  y=${globalMax[1].toFixed(2)}  z=${globalMax[2].toFixed(2)}`);
console.log(`  Size       : ${(globalMax[0]-globalMin[0]).toFixed(2)} × ${(globalMax[1]-globalMin[1]).toFixed(2)} × ${(globalMax[2]-globalMin[2]).toFixed(2)}`);
console.log(`  Center     : x=${((globalMin[0]+globalMax[0])/2).toFixed(2)}  y=${((globalMin[1]+globalMax[1])/2).toFixed(2)}  z=${((globalMin[2]+globalMax[2])/2).toFixed(2)}`);
