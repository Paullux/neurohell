# HUD

**Script** : `scripts/hud.gd`
**Scène** : `scenes/hud.tscn`
**Type** : `CanvasLayer`

Le HUD reproduit fidèlement le design du prototype web HTML/CSS.
Tout le styling est appliqué dynamiquement en GDScript via `StyleBoxFlat`.

---

## Polices

| Usage | Police | Variante |
|---|---|---|
| Valeur santé, munitions | Orbitron Bold | `static/Orbitron-Bold.ttf` |
| Labels biométriques | Orbitron Regular | `static/Orbitron-Regular.ttf` |
| Noms armes, texte courant | Exo 2 Regular | `static/Exo2-Regular.ttf` |
| Overlay de démarrage | Exo 2 SemiBold | `static/Exo2-SemiBold.ttf` |

---

## Composants

### Portrait vidéo (haut gauche)

11 vidéos OGV correspondant à des paliers de santé (0, 10, 20, … 100%).
Pré-chargées en `_ready()` dans `_portrait_streams: Dictionary`.

Changement de portrait uniquement si le **bracket** change (ex. 87 HP → bracket 80) — évite les redémarrages inutiles :
```
bracket = floor(hp / 10.0) * 10
```

### Biométriques (haut gauche)

- **HR** (fréquence cardiaque) : calculée depuis la santé
  - > 50% HP → `72 + (100 - hp) * 0.5 bpm`
  - 20–50% HP → 110 bpm
  - < 20% HP → 145 bpm
- **ARMOR** : valeur directe en %
- **PWR** : miroir de la santé

### Segments de santé

10 segments `Panel` construits dynamiquement dans `_build_hp_segments()`.
Couleur selon état :
- > 50% → cyan `#00e5ff`
- 20–50% → orange `#ffaa00`
- < 20% → rouge `#ff3333`

Glow simulé via `StyleBoxFlat.shadow_color` et `shadow_size = 3`.

### Jauge d'armure (`armor_gauge.gd`)

Arc de 240° avec barres segmentées et graduations radiales.
Widget `Control` dessiné en `_draw()` via `draw_arc()` et `draw_line()`.
Valeur mise à jour via `set_value(val: float)`.

### Slots d'armes (bas)

5 slots `Panel` avec :
- Icône arme (texture JPG)
- Nom (Exo 2)
- Compteur munitions (Orbitron Bold)
- Touche raccourci (Exo 2)

Slot actif : bordure blanche épaisse (4px) + glow blanc + fond bleu foncé.
Slots inactifs : bordure cyan fine (1px, 22% opacité) + texte teinté.

### Torche (`torch_gauge.gd`)

20 segments dynamiques avec :
- État déchargé : clignotement
- Recharge : animation de remplissage
- Label contextuel : `"TORCH [F]"` ou `"RECHARGING..."`

### Minimap

`SubViewport` partageant le `World3D` principal (via `world_3d = get_viewport().world_3d`).
Caméra orthogonale à +30 unités de hauteur, orientée selon la direction du joueur (`rotation_degrees.y`).
Mise à jour chaque frame dans `_process()`.

### Scope sniper

Shader GLSL inline sur un `ColorRect` plein écran :
```glsl
// Masque circulaire avec vignette douce
float d = distance(pixel, center);
float mask = smoothstep(radius_px, radius_px + softness_px, d);
COLOR = vec4(0.0, 0.0, 0.0, mask * darkness);
```
Paramètres : rayon 278px, adoucissement 25px. Le `ScopeCanvas` (`scope_canvas.gd`) dessine par-dessus la réticule, les mil-dots et le label de zoom `8.0x`.

### Flash de dégâts

`ColorRect` plein écran (couleur rouge `rgba(255, 100, 0, 0.4)`).
Disparaît en 0.15s via `Tween.tween_property(hit_flash, "color:a", 0.0, 0.15)`.

---

## Écrans spéciaux

### Écran de mort

Décompte de 5 secondes puis `get_tree().reload_current_scene()`.

### Overlay de démarrage

Affiché en `_ready()` avec les contrôles clavier. Masqué au premier clic souris.

### Transition entre niveaux

`fade_in_from_white(duration)` : crée un `ColorRect` blanc sur `CanvasLayer` layer 98, fondu vers 0 en `duration` secondes (ease out quadratic).

---

## API publique

| Méthode | Arguments | Description |
|---|---|---|
| `set_health(hp)` | `float` | Met à jour valeur, couleur, portrait, segments |
| `set_armor(val)` | `float` | Met à jour jauge + label |
| `set_torch(ratio, dep)` | `float, bool` | Met à jour la torch gauge |
| `set_ammo(index, ammo)` | `int, float` | Met à jour le compteur du slot |
| `set_active_weapon(index)` | `int` | Met en surbrillance le bon slot |
| `set_scope(on)` | `bool` | Affiche/masque le scope |
| `show_hit_flash(color)` | `Color` | Déclenche le flash |
| `show_death_screen()` | — | Affiche l'écran de mort + décompte |
| `show_start_overlay(msg)` | `String` | Affiche le message de démarrage |
| `hide_start_overlay()` | — | Cache l'overlay |
| `fade_in_from_white(duration)` | `float` | Transition entrée de niveau |
| `set_minimap_target(node)` | `Node3D` | Cible suivie par la minimap |
