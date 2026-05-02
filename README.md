# NeuroHell

**Dark sci-fi horror FPS** — développé sous Godot 4

> *Un enfer biomécanique où le métal gothique, la chair, la mémoire et la culpabilité se mélangent.*

---

## À propos

NeuroHell est un roguelite FPS cyberpunk/horror dans lequel tu incarnes un soldat damné qui doit traverser l'enfer pour atteindre le purgatoire.

- **Moteur** : Godot 4.6
- **Genre** : FPS roguelite, dark sci-fi horror
- **Plateformes** : Windows, Linux
- **État** : prototype en développement actif

---

## Télécharger

Les builds compilés sont disponibles sur [neurohell.com](https://neurohell.com) ou directement via les [GitHub Releases](https://github.com/Paullux/neurohell/releases).

| Plateforme | Instructions |
|---|---|
| 🪟 Windows | Extraire le zip et lancer `NeuroHell.exe` |
| 🐧 Linux | `chmod +x NeuroHell.x86_64 && ./NeuroHell.x86_64` |

---

## Configuration minimale

| | Minimum |
|---|---|
| GPU | Vulkan 1.0 ou OpenGL 3.3 |
| RAM | 4 Go |
| OS Windows | Windows 10 64-bit |
| OS Linux | Distribution récente, glibc ≥ 2.31 |

---

## Structure du projet

```
├── scenes/       — scènes Godot (niveaux, HUD, menus, démons)
├── scripts/      — GDScript (joueur, armes, IA, HUD, portails)
├── assets/
│   ├── demons/   — modèles GLB des démons
│   ├── levels/   — GLB des niveaux
│   ├── decor/    — GLB des décors procéduraux
│   ├── audio/    — musiques et effets sonores
│   ├── videos/   — cinématiques
│   ├── images/   — textures, HDRI, icônes
│   └── font/     — polices (Orbitron, Exo 2)
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

## Licence

Ce projet est sous licence **MIT** — voir [LICENSE](LICENSE).
