# Système joueur

**Script** : `scripts/player.gd`
**Scène** : `scenes/player.tscn`
**Type** : `CharacterBody3D`

---

## Constantes de mouvement

| Constante | Valeur | Description |
|---|---|---|
| `SPEED_GROUND` | 25.0 | Vitesse au sol (unités/s) |
| `SPEED_AIR` | 8.0 | Accélération en l'air |
| `JUMP_VELOCITY` | 10.0 | Impulsion verticale du saut |
| `GRAVITY` | 30.0 | Gravité appliquée chaque frame |
| `DAMPING_GROUND` | 4.0 | Coefficient de freinage au sol |
| `DAMPING_AIR` | 0.4 | Coefficient de freinage en l'air |

Le damping utilise `exp(-k * delta) - 1.0` pour un freinage exponentiel indépendant du framerate.

---

## Caméra FPS

- Sensibilité souris : `0.002` rad/pixel (exportable via Inspector)
- Pitch limité à ±89° (`PITCH_MAX = deg_to_rad(89.0)`)
- Camera bob : `sin(t * 10.0) * 0.01` en mouvement, `sin(t * 2.0) * 0.01` à l'arrêt
- Touche `pause` : bascule `MOUSE_MODE_CAPTURED` / `MOUSE_MODE_VISIBLE`

---

## Statistiques

| Stat | Max | Description |
|---|---|---|
| `health` | 100.0 | Points de vie |
| `armor` | 100.0 | Armure — absorbe 75% des dégâts |

### Régénération passive

| Paramètre | Valeur | Description |
|---|---|---|
| `ARMOR_REGEN_DELAY` | 4.0 s | Délai sans coup avant recharge armure |
| `ARMOR_REGEN_RATE` | 10.0 pts/s | Vitesse de recharge armure |
| `HP_REGEN_DELAY` | 15.0 s | Délai sans coup avant regen vie |
| `HP_REGEN_RATE` | 0.5 pts/s | Vitesse de regen vie (très lente) |

Tout coup remet `_time_since_damage` à zéro, repoussant les deux délais.

### Invulnérabilité temporaire

Après chaque coup : 1 seconde d'invulnérabilité (`_invuln_timer`). Évite les combos de dégâts instantanés.

---

## Torche électrique (`[F]`)

| Paramètre | Valeur |
|---|---|
| `TORCH_MAX` | 4.0 s d'autonomie |
| `TORCH_RECHARGE` | 5.0 s pour recharge complète |

- Energie lumineuse : `lerp(5.0, 12.0, ratio)` selon charge restante
- Portée : `lerp(10.0, 26.0, ratio)` unités
- Angle d'ouverture : 42°, atténuation 1.65
- Scintillement : `randf_range(0.97, 1.03)` appliqué à l'énergie
- Quand épuisée (`_torch_depleted = true`) : recharge automatique, ne peut pas être rallumée pendant la recharge
- Signal `torch_changed(ratio, is_depleted)` → `HUD.set_torch()`

---

## Système de dégâts

```gdscript
func take_damage(amount: float) -> void:
    # 1. Ignore si mort ou invulnérable
    # 2. L'armure absorbe 75% → armor -= blocked
    # 3. La vie reçoit le reste → health -= amount
    # 4. Si health <= 0 → _die()
```

La formule d'absorption : `blocked = min(amount * 0.75, armor_restante)`

---

## Anti-coincement

Détection : vélocité horizontale > 1.0 mais déplacement < 0.003 unités pendant > 0.35 s.

Comportement selon le type de collision :
- **Mur normal** : `position += normal * 0.18` + slide de vélocité
- **Décor** (groupe `decor`) : glissement simple, pas de push
- **Aucune collision détectée** : reset vélocité X/Z

Filet de sécurité : si `position.y < -5.0` → téléportation au `_spawn_position`.

---

## Signaux émis

| Signal | Arguments | Déclencheur |
|---|---|---|
| `health_changed` | `hp: float` | `take_damage()`, `_tick_regen()` |
| `armor_changed` | `armor: float` | `take_damage()`, `_tick_regen()` |
| `torch_changed` | `ratio: float, is_depleted: bool` | Chaque frame si torche active/recharge |
| `player_died` | — | `health <= 0` |
