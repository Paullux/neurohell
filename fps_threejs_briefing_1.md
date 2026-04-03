# 🎮 NeuroHell — Briefing Claude Code

## Contexte du projet

NeuroHell — FPS Three.js inspiré de l'univers Doom — démons infernaux, décors futuristes, ambiance dark sci-fi. Développé par Paul Woisard (ingénieur études techniques PV, Tours). Pipeline d'assets : Rodin.ai → Blender → Three.js.

---

## 🏗️ Stack technique

- **Moteur** : Three.js r168+ avec `WebGLRenderer`
- **Physique** : Rapier.js (WASM)
- **Bundler** : Vite
- **Assets** : GLB (GLTF 2.0) — format unique pour tout
- **Audio** : Three.js `AudioLoader` + `PositionalAudio`
- **Post-processing** : `EffectComposer` (Three.js)

---

## 🎭 Démons — Assets disponibles

### ✅ Prêts (GLB rigués + textures PBR)

| Fichier | Description | Tris | Bones | Animations |
|---------|-------------|------|-------|------------|
| `demon_taurex.glb` | Taureau démoniaque, cornes feu, lava body | 6 000 | 33 | walk, attack |
| `demon_voidborn.glb` | Humanoïde noir, veines teal/cyan, ailes libellule | 5 996 | 43 | walk, attack, run, t-pose |
| `demon_mawgrub.glb` | Larve/ver quadrupède, gueule béante, orbe de feu | 6 000 | 15 | Idle, Walk, Mouth_Open_Close |

> **Note Mawgrub** : rig 100% manuel (Auto-Rig Pro incompatible avec ce type de personnage). Meilleur modèle techniquement — aucune anomalie, scale 1/1/1, 3 animations propres et bien nommées.

| `demon_spectre.glb` | Spectre squelette violet/cyan, traîne fantôme | — | — | — |
| `demon_ravager.glb` | Golem pierre/lave massif, piques, 3 vues | — | — | — |
| `demon_pyrarachnid.glb` | Araignée géante, abdomen boule de feu | — | — | — |

---

## 🔫 Armes — Assets en cours

| Fichier | Description | Émissif |
|---------|-------------|---------|
| `weapon_voidrifle.glb` | Fusil assault, cellules plasma violettes | Violet |
| `weapon_tealsniper.glb` | Fusil précision long, accents teal, scope | Teal |
| `weapon_irongazlet.glb` | Gantelet mécanique, orbes orange | Orange |
| `weapon_plasmapistol.glb` | Pistolet plasma, core bleu électrique | Bleu |

---

## 📁 Structure du projet

```
G:/NeuroHell/                ← racine du projet
├── neurohell_preview.html   ← ✅ prévisualiseur assets (servir via python -m http.server 8080)
├── index.html               ← à créer (jeu principal)
├── vite.config.js           ← à créer
├── package.json             ← à créer
├── assets/                  ← assets existants
│   ├── demon/               ← ✅ GLB démons
│   │   ├── demon_mawgrub.glb      ✅ prêt (Idle/Walk/Mouth_Open_Close) — rig 100% manuel
│   │   ├── demon_pyrarachnid.glb  ✅ prêt
│   │   ├── demon_ravager.glb      ✅ prêt
│   │   ├── demon_spectre.glb      ✅ prêt
│   │   ├── demon_taurex.glb       ✅ prêt
│   │   └── demon_voidborn.glb     ✅ prêt (scale ×100 requis)
│   └── guns/                ← 🔄 GLB armes (à venir)
└── src/
    ├── main.js              ← point d'entrée, game loop
    ├── engine/
    │   ├── Renderer.js      ← WebGLRenderer + EffectComposer
    │   ├── SceneManager.js  ← gestion niveaux, portals
    │   └── Physics.js       ← Rapier.js wrapper
    ├── player/
    │   ├── FPSPlayer.js     ← PointerLock, mouvement, caméra
    │   └── WeaponSystem.js  ← armes, raycasting tirs
    ├── demons/
    │   ├── DemonVoidborn.js ← ✅ PRÊT
    │   ├── DemonTaurex.js   ← à créer
    │   ├── DemonSpectre.js  ← à créer
    │   ├── DemonBase.js     ← classe abstraite commune
    │   └── AISystem.js      ← FSM patrol/chase/attack
    ├── particles/
    │   ├── LightOrb.js      ← projectile lumineux
    │   ├── ParticleCloud.js ← nuage de particules
    │   └── HitFX.js         ← effet impact + glitch
    ├── audio/
    │   └── AudioManager.js  ← musique + sons positionnels
    └── ui/
        └── HUD.js           ← vie, score, arme active
```

---

## 🤖 Classe DemonVoidborn.js — PRÊTE

```javascript
import { DemonVoidborn } from './demons/DemonVoidborn.js';

const demon = new DemonVoidborn(scene);
await demon.load('assets/demon/demon_voidborn.glb');

// Positionner
demon.setPosition(5, 0, -3);

// Animations disponibles : 'walk', 'run', 'attack', 'idle'
demon.playAnimation('walk', 0.3); // fadeTime 300ms

// Déplacement par code (pas par anim)
demon.moveTo(targetX, targetZ, delta);  // vers cible
demon.move(dx, dz, delta);             // vecteur direct

// Game loop
demon.update(delta);
```

**Corrections auto au chargement :**
- Scale ×100 (armature exportée à 0.01)
- Recentrage X/Z, pieds à Y=0
- Nettoyage noms animations Mixamo

**À reproduire pour chaque démon** — même structure de classe avec ajustements scale/position selon le modèle.

---

## ⚔️ Système d'attaques particules

### Types par démon

| Démon | Attaque | Couleur | Effets |
|-------|---------|---------|--------|
| Taurex | Projectile LightOrb | Rouge/orange | Dégâts directs + burst |
| Voidborn | Projectile + Cloud | Blanc/teal | Dégâts + glitch visuel |
| Spectre | ParticleCloud lent | Violet/cyan | Glitch intense |
| Ravager | LightOrb massif | Rouge | Dégâts élevés |

### LightOrb (projectile)
- `Points` geometry ~80 particules, `AdditiveBlending`
- `PointLight` embarquée qui éclaire les murs
- Trail sur les 10 dernières positions
- Impact : burst radial 150 particules

### ParticleCloud (nuage)
- `InstancedMesh` ~200 sphères, drift aléatoire
- Suit le démon puis se détache vers le joueur

### HitFX (impact joueur)
- Chromatic aberration sur UV
- Scanlines horizontales aléatoires
- Noise distortion 0.8s
- ShaderMaterial GLSL custom

**⚠️ Object pooling obligatoire** — pas de `new` dans le game loop

---



---

## 🎯 Gameplay FPS

### Joueur
- PointerLock API
- WASD + souris
- Saut, gravité
- Bobbing caméra

### IA Démons — FSM
```
PATROL → (détection 10m) → CHASE → (portée attaque) → ATTACK
                                                          ↓
                                                       PATROL ←
```

### Armes
- Raycasting pour tirs hitscan
- Projectiles Three.js pour attaques énergie
- 4 armes : pistolet plasma, voidrifle, tealsniper, gantelet

### Niveaux
- Rooms modulaires JSON
- Spawners de démons
- Textures DALL·E (futuriste/infernal)

---

## 🔧 Plugin Blender — rodin_optimizer

Plugin maison pour pipeline Rodin.ai → Three.js :

**Fichiers :** `rodin_optimizer/__init__.py` + `fix_rig.py`

**Pipeline :**
1. Import GLB Rodin haute résolution
2. Décimation (preset par type : Ravager=8k, Voidborn=6k, Spectre=5k, Arme=4k)
3. UV Unwrap canal dédié (préserve UVs Rodin)
4. Baking Normal/AO/Albedo (optionnel si textures Rodin suffisantes)
5. Import FBX Mixamo + Fix & Apply Rig
6. Export GLB Three.js

**Paramètres FBX import (Blender 5.x) :**
- `global_scale=1.0` (Blender applique 0.01 natif)
- `bake_space_transform=False`
- `ignore_leaf_bones=True`
- `automatic_bone_orientation=True`

**Problème échelle connu :**
- Mesh Rodin : scale 1/1/1
- Armature Mixamo après import : scale 0.01/0.01/0.01
- Correction dans Three.js : `model.scale.setScalar(100)`

---

## 📋 TODO — Prochaines étapes Claude Code

### Priorité 0 — Scène de test initiale ⭐ COMMENCER ICI

> **Prévisualiseur déjà prêt** : `neurohell_preview.html` à la racine du projet.
> Lancer avec `python -m http.server 8080` puis ouvrir `http://localhost:8080/neurohell_preview.html`
> Sidebar gauche : sélectionner un démon → ses animations apparaissent → clic = pose statique à frame 0.

Avant tout gameplay, créer une scène de test simple pour valider tous les assets :

**Terrain infini** (plane répété ou shader infini) + tous les démons disponibles posés dessus, animés en idle, sans déplacement.

```
Scène test :
- Terrain infini gris/sombre (shader ou plane 1000×1000)
- Lumière ambiante + directionelle
- Caméra libre (OrbitControls) pour tourner autour
- Chaque démon instancié à une position fixe espacée
- Animation idle lancée sur chacun au chargement
- Pas d'IA, pas de physique, pas de joueur
```

**Démons à placer (espacés de ~5 unités) :**
- `demon_voidborn.glb` → scale ×100, correction position auto
- `demon_taurex.glb` → scale à vérifier
- `demon_mawgrub.glb` → scale 1/1/1 natif, animation `Idle`
- `demon_spectre.glb` → quand disponible
- `demon_pyrarachnid.glb` → quand disponible

**Objectif :** valider que tous les GLB se chargent, que les textures s'affichent, que les animations tournent correctement avant de passer au gameplay.

---

### Priorité 1 — Moteur de base
- [ ] Scaffold Vite + Three.js + Rapier
- [ ] FPSPlayer (PointerLock + WASD + caméra)
- [ ] SceneManager (chargement niveau test)
- [ ] Une room de test avec collisions

### Priorité 2 — Premier démon jouable
- [ ] DemonTaurex.js (sur modèle DemonVoidborn.js)
- [ ] AISystem.js (FSM patrol/chase/attack)
- [ ] LightOrb.js (projectile particules)
- [ ] HitFX.js (effet glitch au hit)

### Priorité 3 — Gameplay complet
- [ ] WeaponSystem.js (pistolet plasma en premier)
- [ ] HUD.js (vie, score)
- [ ] AudioManager.js (musique + sons positionnels)
- [ ] Tous les démons

### Priorité 4 — Polish
- [ ] Tous les démons intégrés
- [ ] Système de niveaux
- [ ] Boss fights
- [ ] Optimisations (LOD, frustum culling)

---

## 💡 Notes importantes pour Claude Code

- **GLB = format unique** — tout passe par GLTFLoader
- **Object pooling** — jamais de `new` dans le game loop pour les particules
- **AnimationMixer** par instance de démon — chaque démon a son propre mixer
- **Scale Voidborn** : `×100` à l'import Three.js (armature exportée à 0.01)
- **Scale Taurex** : à vérifier au premier import
- **Scale Mawgrub** : aucune correction nécessaire — scale 1/1/1 natif
- **Animations Mawgrub** : noms propres sans préfixe — `Idle`, `Walk`, `Mouth_Open_Close`
- **Animations Mixamo** nommées avec préfixe `Armature|` ou `Armature.001|` — nettoyer à l'import
- Les textures Rodin (baseColor + metalRough + normal) sont **embarquées dans le GLB** — pas de fichiers séparés
- Pas de Draco compression — compatibilité max
- Y-up pour Three.js (déjà géré à l'export Blender)
