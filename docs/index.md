# NeuroHell — Documentation technique

Documentation interne du projet Godot 4. Mise à jour au fil du développement.

---

## Sommaire

| Fichier | Contenu |
|---|---|
| [architecture.md](architecture.md) | Vue d'ensemble, scènes, autoloads, groupes |
| [player.md](player.md) | Contrôleur FPS, mouvement, torche, dégâts, regen |
| [combat.md](combat.md) | Armes, projectiles, système plasma |
| [hud.md](hud.md) | HUD, portraits, jauges, minimap, scope |
| [ai.md](ai.md) | IA des démons, navigation, animations, respawn |
| [levels.md](levels.md) | Contrôleurs de niveau, colliders GLB, portails |
| [audio.md](audio.md) | Musique contextuelle, transitions |
| [cicd.md](cicd.md) | CI/CD GitHub Actions, builds Windows/Linux |

---

## Stack technique

- **Moteur** : Godot 4.6.2 stable
- **Langage** : GDScript (typage statique activé)
- **Rendu** : Vulkan (Forward+) — fallback OpenGL 3.3
- **Assets 3D** : Blender → GLB
- **Polices** : Orbitron (titres/valeurs), Exo 2 (texte courant)
- **CI** : GitHub Actions → build headless → GitHub Release
