# NeuroHell — Migration Web Demo → Desktop (Godot)

## Vue d'ensemble

| | Démo Web (actuelle) | Desktop (cible) |
|---|---|---|
| Moteur | Three.js | Godot 4.x (Vulkan) |
| Cible | Navigateur HTML5 | Windows / Linux natif |
| Modèles | Medium poly + baked | High poly direct |
| Anims | AnimationMixer manuel | AnimationTree visuel |
| Particules | CPU (sphères) | GPUParticles3D |
| Éclairage | Statique / faux | Dynamique Vulkan |
| Assets démons | GLB existants | GLB existants (réutilisés) |
| Assets décors | Limités | Rodin + Blender |

---

## Étape 1 — Préparer les assets Blender

### Démons existants
- Ouvrir chaque `.blend` source dans `G:\NeuroHell-Source-Assets`
- Vérifier que les armatures et actions sont propres (noms lisibles : `Idle`, `Walk`, `Fly`, `Mouth_Open_Close`...)
- Export GLB depuis Blender : **File → Export → glTF 2.0**
  - Cocher : `Include Animations`, `Shape Keys`, `Skinning`
  - Format : `.glb` (binaire, tout en un fichier)
- Pas besoin de bake pour le desktop — le high poly passe directement

### Décors avec Rodin (Hyper3D)
Exemples de prompts adaptés à l'univers NeuroHell :
```
gothic gargoyle statue, biomechanical, dark metal, horns, cracked stone
broken altar, gothic industrial, rust and bone, hellish
organic pipe column, flesh and metal fused, sci-fi horror
wall relief, demonic faces, gothic architecture, dark
scattered bones and mechanical debris, floor decoration
```
- Télécharger en GLB
- Passer dans Blender si la topologie est trop dense (Decimate modifier, ratio ~0.3)
- Vérifier les UVs, appliquer une texture PBR sombre si absente

---

## Étape 2 — Installer Godot 4

- Télécharger **Godot 4.x** (version standard, pas Mono sauf si tu veux C#)
- Créer un nouveau projet : `NeuroHell-Desktop`
- Renderer : **Forward+** (Vulkan — ombres dynamiques, particules GPU, SSAO)
- Importer les GLB : drag & drop dans `res://assets/demons/` etc.

---

## Étape 3 — Structure du projet Godot

```
NeuroHell-Desktop/
├── assets/
│   ├── demons/          ← GLB depuis Blender (armatures + anims)
│   ├── decors/          ← GLB depuis Rodin (statues, colonnes, débris)
│   ├── weapons/         ← GLB depuis Blender
│   ├── textures/        ← PBR maps (albedo, normal, roughness, emissive)
│   └── sounds/
├── scenes/
│   ├── main.tscn        ← scène racine
│   ├── level_1.tscn     ← niveau 1
│   ├── player.tscn      ← joueur + caméra FPS
│   ├── demons/
│   │   ├── mawgrub.tscn
│   │   ├── pyrarachnid.tscn
│   │   └── ...
│   └── decors/
│       ├── gargoyle.tscn
│       └── ...
├── scripts/
│   ├── player.gd
│   ├── demon_base.gd    ← logique commune (HP, collider, chase)
│   ├── level_generator.gd
│   ├── plasma_bolt.gd
│   └── weapon_manager.gd
└── shaders/
    └── plasma_distortion.gdshader
```

---

## Étape 4 — Importer les animations

Godot importe automatiquement les actions Blender depuis le GLB :

1. Sélectionner le GLB importé dans le FileSystem
2. Onglet **Import** → `Animation` → cocher `Import Animations`
3. Les clips apparaissent dans le nœud `AnimationPlayer`
4. Créer un `AnimationTree` pour le blending :

```
AnimationTree
└── AnimationNodeStateMachine
    ├── Idle
    ├── Walk  (transition si velocity > 0.1)
    ├── Fly   (Voidborn : blend avec Idle via AnimationNodeBlend2)
    └── Mouth_Open_Close  (Mawgrub : OneShot sur contact)
```

Équivalent exact de ce qui est fait manuellement en Three.js, mais en visuel.

---

## Étape 5 — Plasma en GPUParticles3D

Chaque tir plasma = une scène `plasma_bolt.tscn` :

```
PlasmaScene (Node3D)
├── MeshInstance3D       ← cœur du projectile (shader émissif)
├── OmniLight3D          ← éclaire l'environnement en passant
├── GPUParticles3D       ← traînée de particules
│   └── ParticleProcessMaterial
│       ├── direction: vec3(0,-0.1,0)
│       ├── initial_velocity: 0.5
│       ├── color_ramp: couleur arme → transparent
│       └── lifetime: 0.3
└── Area3D + CollisionShape3D  ← détection d'impact
    └── on body_entered → impact()
```

À l'impact :
- `GPUParticles3D` burst (explosion)
- Decal brûlure sur la surface
- `OmniLight3D` flash lumineux bref

Couleur par arme (variable exportée dans `plasma_bolt.gd`) :
```gdscript
@export var plasma_color: Color = Color(1.0, 0.4, 0.0)  # orange irongazlet
```

---

## Étape 6 — Génération procédurale

Le script Python Blender existant peut se transposer en GDScript.
La logique de placement reste la même, Godot ajoute :

```gdscript
# Placer un décor aléatoire parmi les variantes Rodin
func scatter_decors(room: Node3D):
    var decor_pool = [
        preload("res://scenes/decors/gargoyle.tscn"),
        preload("res://scenes/decors/altar.tscn"),
        preload("res://scenes/decors/column.tscn"),
    ]
    for i in range(randi_range(3, 8)):
        var decor = decor_pool.pick_random().instantiate()
        decor.position = Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
        decor.rotation.y = randf_range(0, TAU)
        room.add_child(decor)
```

---

## Étape 7 — Export Desktop

### Windows
- **Project → Export → Add Preset → Windows Desktop**
- Télécharger les templates d'export (bouton dans l'interface)
- Export → `.exe` + dossier `pck`

### Linux
- **Project → Export → Add Preset → Linux/X11**
- Export → `.x86_64` (binaire natif, pas besoin d'installation)
- Fonctionne sur Ubuntu, Debian, Arch, etc.

Les deux exports depuis le même projet, même clic.

---

## Étape 8 — Page de téléchargement (index.html)

Une fois les builds générés :
- Héberger les archives sur GitHub Releases ou un CDN
- Mettre à jour `index.html` :
  - Section **Télécharger** avec boutons Windows / Linux
  - Section **Captures d'écran** avec screenshots in-game

---

## Roadmap suggérée

| Phase | Contenu |
|---|---|
| **1 — Setup** | Installer Godot, importer GLB existants, scène joueur FPS basique |
| **2 — Combat** | Démons (Pyrarachnid, Mawgrub...) portés en GDScript, plasma GPUParticles |
| **3 — Niveau 1** | Générateur procédural, décors Rodin scattés, éclairage Vulkan |
| **4 — Polish** | AnimationTree complet, sons, HUD, menus |
| **5 — Build** | Export Windows + Linux, screenshots, mise à jour index.html |

---

## Ce qui est réutilisé à 100%

- Tous les GLB des démons (armatures + anims intactes)
- Tous les GLB des armes
- Les textures PBR
- La logique de jeu (traduite de JS → GDScript, syntaxe très proche)
- L'histoire, l'univers, le HUD design
- Les assets vidéo (intro cinématique)
