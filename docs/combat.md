# Système de combat

## Armes (`weapon_manager.gd`)

### Les 5 armes

| # | ID | Mains | Couleur | Max munitions | Regen/s | Dégâts | Mode |
|---|---|---|---|---|---|---|---|
| 1 | `irongazlet` | Les deux | Orange | ∞ | — | 12.0 | Continu |
| 2 | `plasma_standard` | Droite | Bleu | 50 | 0.7 | 18.0 | Semi-auto |
| 3 | `plasma_elite` | Droite | Bleu foncé | 35 | 3.0 | 28.0 | Semi-auto |
| 4 | `teal_sniper` | Droite | Cyan | 120 | 0.4 | 55.0 | Semi-auto + scope |
| 5 | `void_rifle` | Droite | Violet | 90 | 10.0 | 35.0 | Semi-auto |

### Contrôles

| Action | Commande |
|---|---|
| Changer d'arme | Touches `1`–`5` |
| Arme suivante/précédente | Molette souris |
| Tirer | Clic gauche |
| Viser (sniper uniquement) | Clic droit |

### Scope sniper (Teal Sniper)

- FOV normal : 65°
- FOV scope : 7° (≈ zoom 8×)
- Signal `scope_toggled(on)` → HUD affiche/masque l'overlay scope
- Crosshair masqué en mode scope

### Iron Gazlet — cas particulier

- Arme à deux mains : deux modèles GLB instanciés simultanément (gauche + droite, miroir X)
- Tir depuis les deux points `Muzzle` en même temps
- Animation de fermeture des mains au tir (`AnimationPlayer` — recherche parmi : `fire`, `close`, `grip`, `attack`, `squeeze`)

### Régénération des munitions

Toutes les armes (sauf `irongazlet` en ∞) se rechargent automatiquement :
```
ammo += regen_rate * delta  (chaque frame, toutes les armes)
```

---

## Projectiles (`plasma_system.gd` + `plasma_bolt.gd`)

### Flux de tir

```
WeaponManager._try_fire()
  └── PlasmaSystem.fire(muzzle_pos, direction, damage, color, weapon_id)
        └── instancie plasma_bolt.tscn
              └── charge la scène FX correspondante (fx/plasma_{id}.tscn)
                  applique la couleur au matériau
                  se déplace selon direction * speed
                  détecte collision via RayCast ou Area3D
                  → PlasmaBolt.hit_demon(area) → demon.take_damage(damage)
                  → queue_free() après lifetime ou impact
```

### Calcul du point de visée

Raycast depuis la caméra sur 200 unités, masques de collision `1 | 8` (monde + hitbox démons) :
- Si hit → point d'impact comme cible
- Si miss → point fictif à 60 unités devant la caméra

Le projectile part du point `Muzzle` du GLB et se dirige vers ce point de visée. Cela corrige la parallaxe entre la caméra et le canon.

### Recherche du nœud Muzzle

Recherche récursive insensible à la casse dans le GLB :
- Nom exact : `muzzle` ou `muzzlepoint`
- Nom contenant : `muzzle` (ex. `GunMuzzle`)
- Fallback : position caméra + 0.5 unités vers l'avant

---

## Hitbox des démons

Chaque démon crée dynamiquement une `Area3D` (couche 8) avec une `CapsuleShape3D` :
- Rayon : 0.85
- Hauteur : 2.4
- Offset Y : +1.2 (centré sur le corps debout)

La hitbox est désactivée quand le démon est mort (`_col_shape.disabled = true`).
