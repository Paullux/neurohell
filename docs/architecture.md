# Architecture générale

## Structure des scènes

```
scenes/
├── main.tscn              — scène d'entrée (redirige vers MainMenu)
├── MainMenu.tscn          — menu principal
├── level_1.tscn           — niveau 1
├── level_2.tscn           — niveau 2
├── level_3.tscn           — niveau 3 (final)
├── game_win.tscn          — écran de victoire
├── hud.tscn               — HUD (CanvasLayer instancié dans chaque niveau)
├── player.tscn            — joueur FPS
├── plasma_bolt.tscn       — projectile générique
├── demons/
│   └── demon_base.tscn    — démon (réutilisé pour tous les types)
└── fx/
    ├── plasma_elite.tscn
    ├── plasma_irongazlet.tscn
    ├── plasma_standard.tscn
    ├── plasma_tealsniper.tscn
    └── plasma_voidrifle.tscn
```

## Hiérarchie d'un niveau (ex. level_1.tscn)

```
Level1 (Node3D)  ← level_1.gd
├── Player (CharacterBody3D)  ← player.gd
│   └── Head (Node3D)
│       └── Camera3D
│           ├── Flashlight (SpotLight3D)
│           └── WeaponHolder (Node3D)
│               └── WeaponManager (Node3D)  ← weapon_manager.gd
│                   └── PlasmaSystem (Node)  ← plasma_system.gd
├── HUD (CanvasLayer)  ← hud.gd
├── GameManager (Node)  ← game_manager.gd
├── Demons (Node3D)
│   ├── DemonRavager (CharacterBody3D)  ← demon_base.gd
│   ├── DemonSpectre ...
│   └── ...
└── NavigationRegion3D
    └── World (Node3D)  ← GLB du niveau
```

## Autoloads

| Nom | Script | Rôle |
|---|---|---|
| `GameData` | `game_data.gd` | Persistance santé/armure entre niveaux |
| `GameVersion` | `game_version.gd` | Version et date de build (généré par CI) |
| `UpdateChecker` | `update_checker.gd` | Vérification silencieuse des mises à jour |

## Groupes

| Groupe | Membres | Usage |
|---|---|---|
| `player` | CharacterBody3D joueur | Référence rapide sans signal |
| `demon` | Tous les CharacterBody3D démons | Itération pour le GameManager |
| `demon_hitbox` | Area3D hitbox de chaque démon | Détection des impacts plasma |
| `decor` | StaticBody3D générés depuis meshes `DECOR_SRC_*` | Exclusion de l'anti-coincement |

## Couches de collision

| Layer | Bit | Utilisé par |
|---|---|---|
| Monde (géométrie) | 1 | Niveau GLB, murs, sols |
| Démons | 2 | CharacterBody3D des démons |
| Joueur | 4 | CharacterBody3D du joueur |
| Hitbox démons | 8 | Area3D interne de chaque démon |

## Flux de données (signaux principaux)

```
Player
  ├── health_changed(hp)   → HUD.set_health()
  │                        → GameManager._on_player_health_changed()
  ├── armor_changed(armor) → HUD.set_armor()
  ├── torch_changed(ratio, depleted) → HUD.set_torch()
  └── player_died          → HUD.show_death_screen()
                           → GameManager._on_player_died()

WeaponManager
  ├── weapon_switched(index) → HUD.set_active_weapon()
  ├── ammo_changed(index, ammo) → HUD.set_ammo()
  └── scope_toggled(on)     → HUD.set_scope()

DemonBase
  ├── demon_died(demon)    → (comptage, events futurs)
  └── demon_hit_player(damage) → Level.player.take_damage()
                              → HUD.show_hit_flash()
```
