# Système de niveaux

## Contrôleurs de niveau

Trois niveaux actuels — `level_1.gd`, `level_2.gd`, `level_3.gd` — partagent la même logique de base avec quelques variantes.

| Niveau | Script | Particularités |
|---|---|---|
| 1 | `level_1.gd` | Génération trimesh complète, pas de fondu d'entrée |
| 2 | `level_2.gd` | Fondu blanc à l'entrée, colliders mixtes (trimesh murs + box décors), cuisson NavMesh dynamique, démons plus résistants |
| 3 | `level_3.gd` | Identique au niveau 2, message d'overlay différent |

---

## Initialisation d'un niveau (`_ready`)

### 1. Connexion des signaux

```
Player → HUD : health_changed, armor_changed, torch_changed, player_died
WeaponManager → HUD : weapon_switched, ammo_changed, scope_toggled
Démons → Level : demon_hit_player
Player, Demons → GameManager : register_player(), register_demons()
```

### 2. Génération des colliders GLB

Le GLB du niveau est importé sans collision statique. Les colliders sont générés à l'exécution :

**Niveau 1** — trimesh sur tous les `MeshInstance3D` :
```gdscript
mesh_inst.create_trimesh_collision()
# Si le mesh commence par "DECOR_SRC_" → tag "decor" sur le StaticBody3D généré
```

**Niveau 2+** — logique différenciée :
- Meshes décoratifs → `BoxShape3D` (plus rapide, collision approximative)
- Murs et sols → trimesh précis

### 3. Point de spawn

Recherche d'un nœud nommé `"Spawn"` dans le GLB. S'il n'existe pas, position par défaut `Vector3(0, 2, 0)`.

### 4. Persistance inter-niveaux (`GameData`)

Si `GameData.has_saved == true` : restaure `health` et `armor` du niveau précédent.
Sinon : valeurs par défaut (100 / 100).

---

## Portails (`portal_disc.gd`)

Chaque niveau se termine par un portail `Area3D` :

1. Détection du joueur dans la zone
2. Sauvegarde dans `GameData` : `health`, `armor`, `has_saved = true`
3. Animation : fondu blanc + rotation du disque
4. `get_tree().change_scene_to_file(next_scene_path)`

---

## Décors procéduraux (`decor_scatter.gd`)

Le script scatter instancie aléatoirement jusqu'à 10 types de modèles GLB aux points de spawn définis dans le niveau.

Chaque modèle est encapsulé dans un `StaticBody3D` avec `BoxShape3D` et tagué `"decor"` pour l'anti-coincement. Rotation aléatoire sur Y pour la variété visuelle.

---

## Vitres (`window_glass.gd`)

Script post-import : parcourt l'arbre de scène au `_ready()`, trouve les meshes nommés `window*`, et applique un `StandardMaterial3D` semi-transparent :
- Albedo : bleu cyan semi-transparent
- `transparency = ALPHA`
- Metallic : 0.8, Roughness : 0.05
- Émission faible pour l'effet néon

---

## Navigation dynamique (niveau 2+)

Le `NavigationRegion3D` est cuisiné après la génération des colliders :
```gdscript
NavigationServer3D.bake_from_source_geometry_data(...)
```
Tant que la cuisson est en cours, les démons utilisent le fallback direct (ligne droite). Le NavMesh devient opérationnel quelques frames après le chargement.

---

## Scène de victoire (`game_win.tscn`)

Déclenchée après le niveau 3. Affiche :
- Titre avec effet glitch + pulsation de couleur
- Scanlines
- Bordures cyberpunk
- Vidéo cinématique finale en autoplay (`VideoStreamPlayer`)
