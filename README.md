# NeuroHell

**Dark sci-fi horror FPS** — développé sous Godot 4

> *Un enfer biomécanique où le métal gothique, la chair, la mémoire et la culpabilité se mélangent.*

---

## À propos

NeuroHell est un roguelite FPS cyberpunk/horror dans lequel tu incarnes un soldat damné qui doit traverser l'enfer pour atteindre le purgatoire.

- **Moteur** : Godot 4.6
- **Genre** : FPS roguelite, dark sci-fi horror
- **Plateformes** : Windows, Linux
- **État** : prototype en développement actif — v0.8.6

---

## Télécharger

Les builds compilés sont disponibles sur [neurohell.com](https://neurohell.com) ou directement via les [GitHub Releases](https://github.com/Paullux/neurohell/releases).

| Plateforme | Fichier | Instructions |
|---|---|---|
| 🪟 **Windows (recommandé)** | `NeuroHell-vX.X.X-Setup.exe` | Double-clic et suivre l'assistant |
| 🪟 Windows (portable) | `NeuroHell-Windows.zip` | Extraire et lancer `NeuroHell.exe` |
| 🐧 **Linux (recommandé)** | `NeuroHell-vX.X.X-Linux.AppImage` | `chmod +x *.AppImage && ./NeuroHell-*.AppImage` |
| 🐧 Linux (portable) | `NeuroHell-Linux.zip` | `chmod +x NeuroHell.x86_64 && ./NeuroHell.x86_64` |

---

## Configuration minimale

| | Minimum |
|---|---|
| GPU | Vulkan 1.0 ou OpenGL 3.3 |
| RAM | 4 Go |
| OS Windows | Windows 10 64-bit |
| OS Linux | Distribution récente, glibc ≥ 2.31 |

---

## Démons

6 types de démons, chacun avec comportement, sons et cadavre unique :

| Démon | Particularité | Feu cadavre |
|---|---|---|
| Mawgrub | Lourd, suit les pentes | 🟡 Jaune/orange |
| Ravager | Rapide, agressif | 🟡 Jaune/orange |
| Pyrarachnid | Araignée de feu | 🟡 Jaune/orange |
| Taurex | Tank, haute santé | 🟡 Jaune/orange |
| Spectre | Vol lent, attaque à distance | 🟣 Violet |
| Voidborn | Vol rapide, hauteur caméra | 🔵 Cyan |

### Système de cadavres (v0.8.6)

À chaque mort un cadavre physique est spawné sur le sol avec des flammes 3D spatialisées :
- Mesh GLB unique aléatoire parmi 3 variantes par démon (`assets/demons/waste/`)
- Particules flammèches avec texture réelle (`flam.png`) — couleur selon le type de démon
- Son de feu 3D (`fire_sound.ogg`) synchronisé avec les particules (6 secondes)
- Cadavre supprimé automatiquement au respawn du démon
- Pool limité à 50 cadavres simultanés dans la scène

---

## Structure du projet

```
├── scenes/          — scènes Godot (niveaux, HUD, menus, démons)
├── scripts/         — GDScript (joueur, armes, IA, HUD, portails)
│   ├── demon_base.gd       — IA démons, physique, cadavres
│   ├── debris_manager.gd   — autoload pool cadavres + feu
│   └── …
├── assets/
│   ├── demons/
│   │   └── waste/   — GLB cadavres (6 démons × 3 variantes)
│   ├── levels/      — GLB des niveaux
│   ├── decor/       — GLB des décors procéduraux
│   ├── audio/
│   │   ├── music/       — musiques contextuelles
│   │   └── sound_fx/    — effets sonores (feu, impacts…)
│   ├── videos/      — cinématiques
│   ├── images/
│   │   └── particules/  — textures VFX (flam.png…)
│   └── font/        — polices (Orbitron, Exo 2)
└── .github/
    └── workflows/
        └── godot-build.yml  — CI : build Windows + Linux → GitHub Release
```

---

## CI/CD

Un push de tag `v*.*.*` déclenche automatiquement :
1. Export Windows (`NeuroHell.exe`)
2. Export Linux (`NeuroHell.x86_64`)
3. Création d'une GitHub Release avec les deux archives
4. Mise à jour automatique des liens sur [neurohell.com](https://neurohell.com)

---

## 📚 Documentation

La documentation technique est dans le dossier [`docs/`](docs/) :

| Fichier | Contenu |
|---|---|
| [architecture.md](docs/architecture.md) | Vue d'ensemble, scènes, autoloads, groupes, signaux |
| [player.md](docs/player.md) | Contrôleur FPS, mouvement, torche, dégâts, regen |
| [combat.md](docs/combat.md) | Armes, projectiles, système plasma |
| [hud.md](docs/hud.md) | HUD, portraits, jauges, minimap, scope |
| [ai.md](docs/ai.md) | IA des démons, navigation, animations, respawn |
| [levels.md](docs/levels.md) | Contrôleurs de niveau, colliders GLB, portails |
| [audio.md](docs/audio.md) | Musique contextuelle, transitions |
| [cicd.md](docs/cicd.md) | CI/CD GitHub Actions, builds Windows/Linux |

---

## Licence

Ce projet est sous licence **MIT** — voir [LICENSE](LICENSE).
