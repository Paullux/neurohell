/**
 * gauntlet_controller.js — NeuroHell
 *
 * Machine à états pour les Irongazlets (gants plasma).
 * Gère la séquence d'animations et déclenche le plasma ou les coups de poing.
 *
 * Animations requises dans le GLB :
 *   Close_hand   — fermeture de la main (joué UNE fois, transition)
 *   Closed_hand  — poing fermé (loop)
 *   Open_hand    — ouverture de la main (joué UNE fois, transition)
 *   Opened_hand  — main ouverte (loop, état par défaut)
 *
 * Usage :
 *   const gc = new GauntletController(plasmaSystem);
 *   gc.init(mixerLeft, mixerRight, gltfAnimations);   // à l'init du modèle
 *   // Inputs :
 *   gc.onRMBDown();   gc.onRMBUp();
 *   gc.onLMBDown();   gc.onLMBUp();
 *   // Render loop :
 *   gc.update(delta, originVec3, directionVec3);
 */

import * as THREE from 'three';

// ─── États ───────────────────────────────────────────────────────────────────
const STATE = {
  OPENED:        'OPENED',        // main ouverte — Opened_hand loop
  CLOSING:       'CLOSING',       // Close_hand en cours (transition)
  CLOSED_PLASMA: 'CLOSED_PLASMA', // Closed_hand loop + plasma continu
  CLOSED_PUNCH:  'CLOSED_PUNCH',  // Closed_hand loop + coups de poing
  OPENING:       'OPENING',       // Open_hand en cours (transition)
};

export class GauntletController {

  /**
   * @param {import('./plasma_system.js').PlasmaSystem} plasma
   * @param {object} options
   * @param {Function} options.onPunch  Callback() déclenché à chaque coup de poing
   *                                   (utile pour hit detection + son dans le jeu)
   * @param {number}  options.punchRate Secondes entre chaque coup (défaut 0.38)
   */
  constructor(plasma, options = {}) {
    this._plasma    = plasma;
    this._onPunch   = options.onPunch   ?? null;
    this._punchRate = options.punchRate ?? 0.38;

    this._state     = STATE.OPENED;
    this._mode      = null;          // 'plasma' | 'punch' | null

    this._mixerL    = null;
    this._mixerR    = null;
    this._clips     = {};            // { Opened_hand, Close_hand, ... } → AnimationClip

    this._punchTimer     = 0;        // timer pour cadence des coups
    this._pendingRelease = false;    // relâchement reçu pendant CLOSING → ouvrir dès arrivée en CLOSED
    this._finishListenerL = null;    // listener "finished" sur mixerLeft
  }

  // ─── Initialisation ────────────────────────────────────────────────────────

  /**
   * À appeler après le chargement du GLB.
   * @param {THREE.AnimationMixer} mixerLeft
   * @param {THREE.AnimationMixer} mixerRight  null si une seule main
   * @param {THREE.AnimationClip[]} animations  gltf.animations
   */
  init(mixerLeft, mixerRight, animations) {
    this._mixerL = mixerLeft;
    this._mixerR = mixerRight;
    this._clips  = {};

    // Indexer les clips par nom court (sans prefix "Armature|")
    animations.forEach(clip => {
      const short = clip.name.replace(/^[^|]*\|/, '');
      this._clips[short] = clip;
    });

    const missing = ['Opened_hand','Close_hand','Closed_hand','Open_hand']
      .filter(n => !this._clips[n]);
    if (missing.length) console.warn(`[Gauntlet] Animations manquantes : ${missing.join(', ')}`);

    this._state = STATE.OPENED;
    this._mode  = null;
    this._playLoop('Opened_hand');
  }

  // ─── Inputs ────────────────────────────────────────────────────────────────

  /** Clic droit appuyé → fermer les mains, préparer plasma */
  onRMBDown() {
    if (this._state === STATE.CLOSED_PLASMA) return;  // déjà en plasma
    if (this._state === STATE.CLOSED_PUNCH)  return;  // en punch, on ignore RMB
    if (this._state === STATE.CLOSING || this._state === STATE.OPENING) {
      this._pendingRelease = false;
      return; // en transition, on attend
    }
    this._mode           = 'plasma';
    this._pendingRelease = false;
    this._startClosing();
  }

  /** Clic droit relâché → ouvrir les mains, stopper plasma */
  onRMBUp() {
    if (this._mode !== 'plasma') return;
    if (this._state === STATE.CLOSING) {
      this._pendingRelease = true; // on attend la fin de Close_hand
      return;
    }
    this._startOpening();
  }

  /** Clic gauche appuyé → fermer les mains, commencer à frapper */
  onLMBDown() {
    if (this._state === STATE.CLOSED_PUNCH)  return;
    if (this._state === STATE.CLOSED_PLASMA) return; // en plasma, on ignore LMB
    if (this._state === STATE.CLOSING || this._state === STATE.OPENING) {
      this._pendingRelease = false;
      return;
    }
    this._mode           = 'punch';
    this._pendingRelease = false;
    this._punchTimer     = 0;
    this._startClosing();
  }

  /** Clic gauche relâché → ouvrir les mains */
  onLMBUp() {
    if (this._mode !== 'punch') return;
    if (this._state === STATE.CLOSING) {
      this._pendingRelease = true;
      return;
    }
    this._startOpening();
  }

  // ─── Update (render loop) ─────────────────────────────────────────────────

  /**
   * @param {number}          delta      Secondes depuis la dernière frame
   * @param {THREE.Vector3}   origin     Position du spawn du plasma (bout du poing)
   * @param {THREE.Vector3}   direction  Direction de tir (avant caméra)
   */
  /**
   * @param {number}          delta
   * @param {THREE.Vector3[]} origins    Tableau de positions (une par poing actif)
   * @param {THREE.Vector3}   direction  Direction de tir commune
   */
  update(delta, origins, direction) {
    // Plasma continu — un bolt par poing simultanément
    if (this._state === STATE.CLOSED_PLASMA) {
      const pts = Array.isArray(origins) ? origins : [origins];
      this._plasma.fireMultiple(pts, direction);
    }

    // Coups de poing cadencés
    if (this._state === STATE.CLOSED_PUNCH) {
      this._punchTimer -= delta;
      if (this._punchTimer <= 0) {
        this._punchTimer = this._punchRate;
        if (this._onPunch) this._onPunch();
      }
    }
  }

  // ── Accesseurs ─────────────────────────────────────────────────────────────

  get state()     { return this._state; }
  get mode()      { return this._mode; }
  get isFiring()  { return this._state === STATE.CLOSED_PLASMA; }
  get isPunching(){ return this._state === STATE.CLOSED_PUNCH; }

  // ─── Internals ─────────────────────────────────────────────────────────────

  _startClosing() {
    this._state = STATE.CLOSING;
    this._playOnce('Close_hand', () => this._onCloseFinished());
  }

  _onCloseFinished() {
    if (this._pendingRelease) {
      // L'utilisateur a relâché pendant la fermeture → ouvrir directement
      this._pendingRelease = false;
      this._startOpening();
      return;
    }
    if (this._mode === 'plasma') {
      this._state = STATE.CLOSED_PLASMA;
    } else {
      this._state      = STATE.CLOSED_PUNCH;
      this._punchTimer = 0; // premier coup immédiat
    }
    this._playLoop('Closed_hand');
  }

  _startOpening() {
    this._plasma.stopFiring();
    this._state = STATE.OPENING;
    this._playOnce('Open_hand', () => {
      this._state = STATE.OPENED;
      this._mode  = null;
      this._playLoop('Opened_hand');
    });
  }

  // ── Helpers animations ──────────────────────────────────────────────────────

  /** Joue une animation en boucle sur les deux mains */
  _playLoop(clipName) {
    const clip = this._clips[clipName];
    if (!clip) return;
    [this._mixerL, this._mixerR].forEach(mixer => {
      if (!mixer) return;
      mixer.stopAllAction();
      const action = mixer.clipAction(clip);
      action.reset();
      action.setLoop(THREE.LoopRepeat, Infinity);
      action.timeScale = 1;
      action.play();
    });
  }

  /**
   * Joue une animation une seule fois puis appelle onFinish.
   * Utilise le mixer gauche comme référence pour le callback.
   */
  _playOnce(clipName, onFinish) {
    const clip = this._clips[clipName];
    if (!clip) {
      // Clip absent → skip directement au callback
      if (onFinish) onFinish();
      return;
    }

    // Nettoyer l'ancien listener si présent
    if (this._finishListenerL && this._mixerL) {
      this._mixerL.removeEventListener('finished', this._finishListenerL);
    }

    // Jouer sur les deux mains
    [this._mixerL, this._mixerR].forEach(mixer => {
      if (!mixer) return;
      mixer.stopAllAction();
      const action = mixer.clipAction(clip);
      action.reset();
      action.setLoop(THREE.LoopOnce, 1);
      action.clampWhenFinished = true;
      action.timeScale = 2.5;
      action.play();
    });

    // Callback sur la fin du mixer gauche
    if (this._mixerL && onFinish) {
      this._finishListenerL = (e) => {
        const name = e.action.getClip().name.replace(/^[^|]*\|/, '');
        if (name === clipName) {
          this._mixerL.removeEventListener('finished', this._finishListenerL);
          this._finishListenerL = null;
          onFinish();
        }
      };
      this._mixerL.addEventListener('finished', this._finishListenerL);
    }
  }
}
