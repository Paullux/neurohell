# IA des démons

**Script** : `scripts/demon_base.gd`
**Scène** : `scenes/demons/demon_base.tscn`
**Type** : `CharacterBody3D`

Un seul script gère tous les types de démons. Les différences sont configurées via les `@export` de l'Inspector.

---

## Paramètres configurables (Inspector)

| Paramètre | Type | Description |
|---|---|---|
| `demon_name` | String | Nom affiché dans les logs |
| `hp_max` | float | Points de vie maximum (défaut : 80) |
| `chase_speed` | float | Vitesse de poursuite (défaut : 3.5) |
| `spawn_dist` | float | Distance d'activation (défaut : 18) |
| `melee_range` | float | Portée du corps-à-corps (défaut : 1.5) |
| `melee_damage` | float | Dégâts par coup (défaut : 15) |
| `float_amplitude` | float | > 0 = démon volant (ex. Voidborn) |
| `float_freq` | float | Fréquence de l'oscillation verticale |
| `anim_idle` | String | Nom de l'animation idle dans le GLB |
| `anim_walk` | String | Nom de l'animation de déplacement |
| `anim_attack` | String | Nom de l'animation d'attaque |
| `anim_speed_scale` | float | Multiplicateur de vitesse d'animation |

---

## Cycle de vie

```
Invisible → Activation (joueur < spawn_dist) → Pop-in scale → Actif → Mort → Respawn (10s)
```

**Pop-in** : à l'activation, `scale = 0.01` puis lerp vers `Vector3.ONE` à vitesse 5.

**Mort** :
- Invisible + inactif
- `CollisionShape3D` désactivée (ne bloque plus les tirs)
- Respawn après 10 secondes à la position d'origine

---

## Navigation

### Démons au sol (NavMesh)

1. `NavigationAgent3D` avec `target_position = player.global_position`
2. Chemin calculé automatiquement sur le `NavigationRegion3D` du niveau
3. Direction vers `get_next_path_position()`
4. **Fallback direct** si `dir.length_squared() < 0.05` (NavMesh absent, en cours de cuisson, ou bloqué) : ligne droite vers le joueur

### Démons volants (`float_amplitude > 0`, ex. Voidborn)

- Ignore le NavMesh complètement
- Mouvement direct horizontal vers le joueur
- Oscillation verticale : `position.y = base_y + sin(phase * freq) * amplitude`

---

## Corps-à-corps

Cooldown de 1 seconde entre chaque coup.
Condition : `distance <= melee_range AND cooldown <= 0`.
Émet `demon_hit_player(melee_damage)` → géré par le contrôleur de niveau.

---

## Anti-coincement

Identique à celui du joueur mais avec seuils adaptés à la vitesse des démons.

| Condition | Action |
|---|---|
| Collision avec un **mur** | Push `normal * 0.12` + slide de vélocité |
| Collision avec un **décor** | Reset vélocité X/Z (le NavMesh recalcule) |
| Aucune collision identifiable | Reset vélocité X/Z |

Détection du groupe `decor` : remontée de 4 niveaux dans l'arbre de scène.

---

## Animations

Transition douce entre animations via `anim_player.play(anim, 0.2)` (blend time 0.2s).
L'animation d'attaque a la priorité — `_attacking = true` bloque le switch vers idle/walk jusqu'à la fin de l'animation.

---

## Signaux émis

| Signal | Arguments | Déclencheur |
|---|---|---|
| `demon_died` | `demon` (self) | `hp <= 0` |
| `demon_hit_player` | `damage: float` | Corps-à-corps réussi |
