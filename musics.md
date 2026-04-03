Path of music : assets/audio/musics/*.mp3

## 🎵 Direction musicale 
### Style : Hybrid Doom / Industrial Fusion metal brutal + techno froide sci-fi. 
**Références :** 
- Metal : Mick Gordon (DOOM OST) 
- Techno/Industrial : Gesaffelstein, Carpenter Brut, Perturbator 
  
**Structure par contexte :** 
| Contexte | Style | Description | 
|----------|-------|-------------| 
| idle / exploration | Ambient dark techno | Basse répétitive, atmosphère froide | 
| Combat standard | Techno + metal overlay | Kicks lourds + guitare saturée | 
| Boss fight | Full metal agressif | Riffs lourds, énergie brute maximale | 
| Mort joueur | Silence + drone | Tension pure | 

**Caractéristiques audio :** 
- Basse techno répétitive en fondation 
- Guitare saturée en overlay sur les moments intenses 
- Kicks lourds, rythmes mécaniques 
- Transitions dynamiques selon l'état du jeu 
  
**Pipeline audio :** 
Suno (génération) → BandLab (mastering) → Three.js `AudioLoader`


| Title                    | Context             | Usage               |
|--------------------------|---------------------|---------------------|
| Cold Circuits of Hell    | IDLE / EXPLORATION  | Ambient gameplay    |
| Infernal Overdrive-BOSS  | BOSS FIGHT          | High intensity      |
| Riot Protocol            | COMBAT STANDARD     | Combat loop         |

| Signal Lost              | PLAYER DEATH        | Death sequence      |
| Fading Warmth            | INTRO               | Memory / Love       |
| Fractured Mind           | INTRO               | PTSD Breakdown      |
| Ashes of Reality         | INTRO               | Hell Awakening      |