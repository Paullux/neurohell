/**
 * minimap.js — NeuroHell
 * Minimap temps réel via OrthographicCamera Three.js (Option A)
 *
 * Usage :
 *   import { Minimap } from './minimap.js';
 *
 *   // Après chargement du GLB :
 *   const minimap = new Minimap(gltf.scene, document.getElementById('minimap-wrap'));
 *
 *   // Dans la boucle de rendu :
 *   minimap.updatePlayer(camera.position, camera.rotation.y);
 *   minimap.render();
 *
 *   // Quand le joueur découvre une salle :
 *   minimap.revealRoom('Room_3');
 */

import * as THREE from 'three';

/* ============================================================
   PALETTE MINIMAP
   Couleurs flat pour chaque matériau NH_*
   ============================================================ */
const MINIMAP_COLORS = {
  NH_Floor:         0x0d1f3c,   // bleu nuit
  NH_Lava:          0x5c0a00,   // rouge sombre
  NH_Gothic:        0x1a0d30,   // violet sombre (Portal Final)
  NH_Metal:         0x0a2e2e,   // cyan sombre (corridors)
  NH_Wall:          0x00b8d4,   // cyan clair
  NH_Door:          0x1a2a3a,   // gris bleuté (cadres)
  NH_Window:        0x004d6e,   // bleu vitre
  // Markers
  NH_MarkerSpawn:   0x00ff66,   // vert spawn
  NH_MarkerArena:   0xff8c00,   // orange arène
  NH_MarkerWeapon:  0xffdd00,   // jaune arme
  NH_Gargoyle:      0xff2244,   // rouge ennemi
  NH_MarkerPortal:  0x4488ff,   // bleu portail
};

/* Priorité de rendu par catégorie (ordre d'affichage) */
const RENDER_ORDER = {
  NH_Floor:   0,  NH_Lava:    0,  NH_Gothic:  0,  NH_Metal:   0,
  NH_Wall:    1,  NH_Door:    1,  NH_Window:  1,
  NH_MarkerSpawn:  2, NH_MarkerArena:  2,
  NH_MarkerWeapon: 2, NH_Gargoyle:     2, NH_MarkerPortal: 2,
};

/* ============================================================
   MINIMAP CLASS
   ============================================================ */
export class Minimap {
  /**
   * @param {THREE.Group}  levelScene   — gltf.scene chargé via GLTFLoader
   * @param {HTMLElement}  container    — div #minimap-wrap du HUD
   * @param {object}       options
   */
  constructor(levelScene, container, options = {}) {
    const {
      width         = 210,
      height        = 170,
      fogOfWar      = true,      // révèle les salles au fur et à mesure
      playerColor   = 0xffffff,
      playerSize    = 0.45,
      rotateMarker  = true,      // flèche directionnelle sur le joueur
      rotateMap     = false,     // caméra top-down dynamique qui suit et tourne
    } = options;

    this.width       = width;
    this.height      = height;
    this.fogOfWar    = fogOfWar;
    this.rotateMarker = rotateMarker;
    this.rotateMap   = rotateMap;

    // Bounds connues du niveau (issues de l'analyse GLB)
    this.BOUNDS = { minX: -12, maxX: 12, minZ: -11.23, maxZ: 11.23 };

    // Set des zones déjà révélées (fog of war)
    this._revealed = new Set();
    this._meshByZone = new Map(); // zoneName → [Mesh, ...]

    // ── Scène minimap ────────────────────────────────────────
    this._scene = new THREE.Scene();
    this._buildFromLevel(levelScene);

    // ── Caméra orthographique top-down ───────────────────────
    // On ajoute 10% de padding autour des bounds
    const padX = (this.BOUNDS.maxX - this.BOUNDS.minX) * 0.08;
    const padZ = (this.BOUNDS.maxZ - this.BOUNDS.minZ) * 0.08;
    const halfW = (this.BOUNDS.maxX - this.BOUNDS.minX) / 2 + padX;
    const halfH = (this.BOUNDS.maxZ - this.BOUNDS.minZ) / 2 + padZ;

    let hw = halfW, hh = halfH;
    if (this.rotateMap) {
      hw = 10;
      hh = 10 * (height / width);
    }

    this._camera = new THREE.OrthographicCamera(
      -hw,  hw,   // left / right
       hh, -hh,   // top / bottom  (Z inversé → vue correcte)
       0.1, 200
    );
    this._camera.position.set(0, 100, 0);
    this._camera.rotation.set(-Math.PI / 2, 0, 0);

    // ── Marqueur joueur ───────────────────────────────────────
    this._playerMarker = this._createPlayerMarker(playerColor, playerSize);
    this._scene.add(this._playerMarker);

    // ── Canvas + renderer dédié ───────────────────────────────
    this._canvas = document.createElement('canvas');
    this._canvas.width  = width;
    this._canvas.height = height;
    Object.assign(this._canvas.style, {
      width:  width  + 'px',
      height: height + 'px',
      display: 'block',
    });

    this._renderer = new THREE.WebGLRenderer({
      canvas: this._canvas,
      alpha:  true,
      antialias: false,
    });
    this._renderer.setSize(width, height);
    this._renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this._renderer.setClearColor(0x000000, 0);

    // Montage dans le DOM
    container.innerHTML = '';
    container.appendChild(this._canvas);

    // Fog of war — on révèle le Spawn d'office
    if (fogOfWar) {
      this._applyFogOfWar();
      this.revealZone('Spawn');
    }
  }

  /* ----------------------------------------------------------
     CONSTRUCTION DE LA SCÈNE MINIMAP
     Parcourt le levelScene, clone la géométrie avec couleurs flat
     ---------------------------------------------------------- */
  _buildFromLevel(levelScene) {
    levelScene.updateMatrixWorld(true);

    levelScene.traverse(obj => {
      if (!obj.isMesh) return;

      const matName = obj.material?.name ?? '';
      const color   = MINIMAP_COLORS[matName];
      if (color === undefined) return; // matériau inconnu, skip

      const geo  = obj.geometry.clone();
      const mat  = new THREE.MeshBasicMaterial({ color, transparent: false });
      const mesh = new THREE.Mesh(geo, mat);
      mesh.userData.matName = matName;
      mesh.userData.sourceName = obj.name;

      // Applique la transform world du nœud original
      mesh.applyMatrix4(obj.matrixWorld);
      mesh.renderOrder = RENDER_ORDER[matName] ?? 0;

      // Rattache au nom de zone (ex: "Room_3", "Spawn", "Corridor_2", "Portal_Final")
      const zone = this._extractZone(obj.name);
      if (zone) {
        if (!this._meshByZone.has(zone)) this._meshByZone.set(zone, []);
        this._meshByZone.get(zone).push(mesh);
        mesh.userData.zone = zone;
      }

      this._scene.add(mesh);
    });
  }

  /* ----------------------------------------------------------
     Extrait le nom de zone depuis le nom du nœud GLB
     "LVL_Room_3_Wall_N_0"  → "Room_3"
     "MARKER_Gargoyle_Room_4" → "Room_4"
     "Corridor_5_Floor"      → "Corridor_5"
     "LVL_Spawn_Floor"       → "Spawn"
     "LVL_Portal_Final_Wall" → "Portal_Final"
     ---------------------------------------------------------- */
  _extractZone(nodeName) {
    // Corridors
    const corridor = nodeName.match(/Corridor_(\d+)/);
    if (corridor) return `Corridor_${corridor[1]}`;

    // Portal_Final
    if (nodeName.includes('Portal_Final')) return 'Portal_Final';

    // Spawn
    if (nodeName.includes('Spawn')) return 'Spawn';

    // Room_N
    const room = nodeName.match(/Room_(\d+)/);
    if (room) return `Room_${room[1]}`;

    return null;
  }

  /* ----------------------------------------------------------
     FOG OF WAR — cache tous les meshes au départ
     ---------------------------------------------------------- */
  _applyFogOfWar() {
    this._scene.traverse(obj => {
      if (obj.isMesh && obj.userData.zone) {
        obj.visible = false;
      }
    });
  }

  /**
   * Révèle une zone sur la minimap
   * @param {string} zoneName  ex: "Room_3", "Corridor_2", "Portal_Final", "Spawn"
   */
  revealZone(zoneName) {
    if (this._revealed.has(zoneName)) return;
    this._revealed.add(zoneName);

    const meshes = this._meshByZone.get(zoneName);
    if (!meshes) return;
    meshes.forEach(m => { m.visible = true; });
  }

  /** Révèle toutes les zones d'un coup (mode debug / no fog) */
  revealAll() {
    this._meshByZone.forEach((_, zone) => this.revealZone(zone));
  }

  /* ----------------------------------------------------------
     MARQUEUR JOUEUR — flèche directionnelle
     ---------------------------------------------------------- */
  _createPlayerMarker(color, size) {
    const group = new THREE.Group();

    // Cercle de base
    const circleGeo = new THREE.CircleGeometry(size, 12);
    const circleMat = new THREE.MeshBasicMaterial({ color, depthTest: false });
    const circle    = new THREE.Mesh(circleGeo, circleMat);
    circle.renderOrder = 10;
    group.add(circle);

    // Flèche de direction
    const arrowShape = new THREE.Shape();
    arrowShape.moveTo( 0,    size * 1.8);
    arrowShape.lineTo(-size * 0.5, size * 0.6);
    arrowShape.lineTo( size * 0.5, size * 0.6);
    arrowShape.closePath();
    const arrowGeo  = new THREE.ShapeGeometry(arrowShape);
    const arrowMat  = new THREE.MeshBasicMaterial({ color: 0x00e5ff, depthTest: false });
    const arrow     = new THREE.Mesh(arrowGeo, arrowMat);
    arrow.renderOrder = 11;
    group.add(arrow);

    // Positionne au-dessus du niveau (Y élevé pour passer par-dessus)
    group.rotation.x = -Math.PI / 2;  // plane XZ
    group.position.y = 5;

    return group;
  }

  /**
   * Met à jour la position et l'orientation du joueur
   * @param {THREE.Vector3} position   — position monde du joueur
   * @param {number}        yRotation  — rotation Y en radians (camera.rotation.y)
   */
  updatePlayer(position, yRotation) {
    this._playerMarker.position.set(position.x, 5, position.z);

    if (this.rotateMap) {
      this._camera.position.set(position.x, 100, position.z);
      this._camera.rotation.set(-Math.PI / 2, 0, -yRotation);
    }

    if (this.rotateMarker) {
      this._playerMarker.rotation.z = -yRotation;
    } else {
      this._playerMarker.rotation.z = 0;
    }

    // Auto-révèle la zone où se trouve le joueur
    if (this.fogOfWar) {
      const zone = this._getZoneAtPosition(position);
      if (zone) this.revealZone(zone);
    }
  }

  /**
   * Devine la zone courante depuis la position (approche AABB simplifiée)
   * Pour une précision maximale, passe la zone explicitement depuis ton game logic
   */
  _getZoneAtPosition(pos) {
    let closest = null;
    let minDist = Infinity;

    this._meshByZone.forEach((meshes, zone) => {
      // Utilise le premier mesh floor de la zone comme référence
      const floorMesh = meshes.find(m =>
        m.userData.matName === 'NH_Floor' ||
        m.userData.matName === 'NH_Lava'  ||
        m.userData.matName === 'NH_Gothic'||
        m.userData.matName === 'NH_Metal'
      ) ?? meshes[0];
      if (!floorMesh) return;

      const center = new THREE.Vector3();
      floorMesh.geometry.computeBoundingBox();
      floorMesh.geometry.boundingBox.getCenter(center);
      center.applyMatrix4(floorMesh.matrixWorld);

      const d = Math.sqrt(
        (pos.x - center.x) ** 2 +
        (pos.z - center.z) ** 2
      );
      if (d < minDist) { minDist = d; closest = zone; }
    });

    return closest;
  }

  /**
   * Rendu de la minimap — à appeler dans la boucle principale
   */
  render() {
    this._renderer.render(this._scene, this._camera);
  }

  /**
   * Resize si la fenêtre change (optionnel, la minimap est fixed en px)
   */
  resize(width, height) {
    this._renderer.setSize(width, height);
  }

  /** Dispose proprement toutes les ressources GPU */
  dispose() {
    this._scene.traverse(obj => {
      if (!obj.isMesh) return;
      obj.geometry.dispose();
      obj.material.dispose();
    });
    this._renderer.dispose();
    this._canvas.remove();
  }
}
