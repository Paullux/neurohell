/**
 * minimap_integration_example.js
 * Montre comment brancher minimap.js dans ta scène Three.js existante.
 * À adapter dans neurohell_preview.html ou ton fichier principal.
 */

import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { Minimap } from './minimap.js';

// ── Chargement du niveau ──────────────────────────────────────────────────────
const loader = new GLTFLoader();
let minimap  = null;

loader.load('assets/levels/neurohell_level_1.glb', (gltf) => {
  scene.add(gltf.scene);

  // Initialise la minimap après chargement du GLB
  minimap = new Minimap(
    gltf.scene,
    document.getElementById('minimap-wrap'),  // div dans le HUD
    {
      width:        210,
      height:       170,
      fogOfWar:     true,   // true = brouillard de guerre, false = tout visible
      rotateMarker: true,   // flèche orientée selon la caméra
    }
  );

  // En mode debug / démo : révèle tout d'emblée
  // minimap.revealAll();
});

// ── Boucle de rendu ───────────────────────────────────────────────────────────
function animate() {
  requestAnimationFrame(animate);

  // … ton rendu principal Three.js …
  renderer.render(scene, camera);

  // Minimap : mise à jour + rendu
  if (minimap) {
    minimap.updatePlayer(camera.position, camera.rotation.y);
    minimap.render();
  }
}
animate();

// ── API Fog of War — à appeler depuis ta game logic ───────────────────────────

// Quand le joueur entre dans une salle :
// minimap.revealZone('Room_3');
// minimap.revealZone('Corridor_4');
// minimap.revealZone('Portal_Final');

// Zones disponibles :
// 'Spawn'
// 'Room_1' … 'Room_8'
// 'Corridor_1' … 'Corridor_9'
// 'Portal_Final'
