# Système audio

**Script** : `scripts/game_manager.gd`

---

## Musique contextuelle

Trois tracks correspondant à trois états de jeu :

| Contexte | Fichier | Loop |
|---|---|---|
| `IDLE` — exploration | `Cold Circuits of Hell.mp3` | Oui |
| `COMBAT` — démon actif proche | `Riot Protocol.mp3` | Oui |
| `DEATH` — joueur mort | `Signal Lost.mp3` | Non |

### Logique de switch

Chaque frame, le `GameManager` vérifie si un démon **actif** (non mort) se trouve à moins de `spawn_dist + 5` unités du joueur.

```
Si au moins un démon dans le rayon → COMBAT
Sinon → IDLE
Mort du joueur → DEATH (via signal player_died)
```

La transition est immédiate (pas de crossfade pour l'instant) — le track change dès que le contexte change.

### Connexion

Le `GameManager` est instancié dans chaque niveau via `register_player()` et `register_demons()`. Il s'abonne aux signaux du joueur et itère sur la liste des démons chaque frame.

---

## Portraits vidéo (OGV)

11 fichiers OGV pour le portrait du joueur dans le HUD (`assets/videos/face/`).
Streaming via `VideoStreamPlayer` avec `loop = true`.

Les OGV sont des fichiers Theora/Vorbis — format natif Godot 4, pas de plugin requis.

---

## Vidéos cinématiques (MP4)

- **Intro** : `assets/videos/NeuroHell-Intro.mp4` — jouée dans `MainMenu.tscn` via `VideoStreamPlayer`
- **Fin** : vidéo de victoire jouée dans `game_win.tscn`

Format H.264/MP4 — nécessite le plugin de décodage vidéo activé dans `project.godot`.

---

## Assets audio (`assets/audio/`)

```
assets/audio/
└── musics/
    ├── Cold Circuits of Hell.mp3   — exploration
    ├── Riot Protocol.mp3           — combat
    └── Signal Lost.mp3             — mort
```

Tous les assets audio sont stockés en **git natif** (pas de LFS sur la branche `game`).
