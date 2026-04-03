/**
 * plasma_system.js - NeuroHell
 *
 * Système de projectiles plasma réutilisable.
 * Import :
 *   import { PlasmaSystem, WEAPON_CONFIGS } from './plasma_system.js';
 *
 * Usage minimal :
 *   const plasma = new PlasmaSystem(scene);
 *   plasma.setWeapon('irongazlet');
 *   plasma.update(delta, targetMeshes);
 *   plasma.fireAt(originVec3, directionVec3);
 */

import * as THREE from 'three';

// ─────────────────────────────────────────────────────────────────────────────
// Config par arme
// ─────────────────────────────────────────────────────────────────────────────
export const WEAPON_CONFIGS = {
  irongazlet: {
    label: 'Irongazlet',
    continuousFire: true,
    fireRate: 0.05,
    speed: 18,
    damage: 8,
    projectileType: 'plasma_ball',
    color: 0xff6600,
    emissive: 2.2,
    radius: 0.075,
    stretch: 1.35,
    maxLife: 1.2,
    trailLen: 10,
    trailOpacity: 0.42,
    lightIntensity: 1.6,
    lightRange: 1.8,
    spread: 0.008,
    burst: 1,
    burstDelay: 0.0,
    originOffset: new THREE.Vector3(0, 0, 0),
  },

  plasma_standard: {
    label: 'Plasma Standard',
    continuousFire: false,
    fireRate: 0.22,
    speed: 22,
    damage: 18,
    projectileType: 'plasma_ball',
    color: 0x3377ff,
    emissive: 2.8,
    radius: 0.095,
    stretch: 1.45,
    maxLife: 1.5,
    trailLen: 12,
    trailOpacity: 0.50,
    lightIntensity: 2.2,
    lightRange: 2.2,
    spread: 0.004,
    burst: 1,
    burstDelay: 0.0,
    originOffset: new THREE.Vector3(0, 0, 0),
  },

  plasma_elite: {
    label: 'Plasma Elite',
    continuousFire: true,
    fireRate: 0.09,
    speed: 24,
    damage: 16,
    projectileType: 'plasma_ball',
    color: 0x1144ff,
    emissive: 3.1,
    radius: 0.105,
    stretch: 1.55,
    maxLife: 1.55,
    trailLen: 13,
    trailOpacity: 0.56,
    lightIntensity: 2.6,
    lightRange: 2.5,
    spread: 0.006,
    burst: 1,
    burstDelay: 0.0,
    originOffset: new THREE.Vector3(0, 0, 0),
  },

  teal_sniper: {
    label: 'Teal Sniper',
    continuousFire: false,
    fireRate: 0.65,
    speed: 80,
    damage: 65,
    projectileType: 'beam',
    color: 0x00ddbb,
    emissive: 3.0,
    radius: 0.13,
    beamLength: 20,
    beamOpacity: 0.92,
    beamLife: 0.065,
    impactRadius: 0.22,
    spread: 0.0,
    burst: 1,
    burstDelay: 0.0,
    originOffset: new THREE.Vector3(0, 0, 0),
  },

  void_rifle: {
    label: 'Void Rifle',
    continuousFire: true,
    fireRate: 0.17, // cadence d'une rafale, pas d'une bille
    speed: 26,
    damage: 14,
    projectileType: 'plasma_ball',
    color: 0xaa00ff,
    emissive: 2.9,
    radius: 0.105,
    stretch: 1.45,
    maxLife: 1.6,
    trailLen: 12,
    trailOpacity: 0.55,
    lightIntensity: 2.4,
    lightRange: 2.5,
    spread: 0.012,
    burst: 3,
    burstDelay: 0.045,
    originOffset: new THREE.Vector3(0, 0, 0),
  },
};

// ─────────────────────────────────────────────────────────────────────────────
// Geometries partagées
// ─────────────────────────────────────────────────────────────────────────────
const _boltGeo = new THREE.SphereGeometry(1, 18, 14);
const _impactGeo = new THREE.SphereGeometry(1, 14, 10);

// ─────────────────────────────────────────────────────────────────────────────
// PlasmaSystem
// ─────────────────────────────────────────────────────────────────────────────
export class PlasmaSystem {
  /**
   * @param {THREE.Scene} scene
   * @param {object} options
   * @param {number} options.poolSize
   * @param {Function|null} options.onHit
   */
  constructor(scene, options = {}) {
    this._scene = scene;
    this._pool = [];
    this._active = [];
    this._impacts = [];
    this._beams = [];
    this._burstQueue = [];

    this._weapon = 'irongazlet';
    this._cooldown = 0;
    this._firing = false;

    this._onHit    = options.onHit    ?? null;
    this._poolSize = options.poolSize ?? 60;
    // Référence au tableau de colliders (partagé avec weapon_preview — se remplit dynamiquement)
    this._beamTargets = options.targets ?? null;

    for (let i = 0; i < 20; i++) this._pool.push(this._makeBolt());
  }

  // ── API publique ──────────────────────────────────────────────────────────

  setWeapon(id) {
    if (!WEAPON_CONFIGS[id]) {
      console.warn(`PlasmaSystem: arme inconnue "${id}"`);
      return;
    }
    if (this._weapon === id) return; // déjà actif — ne pas reset le cooldown
    this._weapon = id;
    this._cooldown = 0;
    this._burstQueue.length = 0;
  }

  startFiring() {
    this._firing = true;
  }

  stopFiring() {
    this._firing = false;
  }

  /**
   * Tire depuis plusieurs origins simultanément (ex: deux poings) avec un seul cooldown.
   * @param {THREE.Vector3[]} origins
   * @param {THREE.Vector3}   direction
   */
  fireMultiple(origins, direction) {
    const cfg = WEAPON_CONFIGS[this._weapon];
    if (!cfg || this._cooldown > 0) return;
    this._cooldown = cfg.fireRate;

    const dir = direction.clone().normalize();
    if (cfg.spread > 0) {
      dir.x += (Math.random() - 0.5) * cfg.spread;
      dir.y += (Math.random() - 0.5) * cfg.spread;
      dir.z += (Math.random() - 0.5) * cfg.spread;
      dir.normalize();
    }

    origins.forEach(origin => {
      const o = origin.clone().add(cfg.originOffset);
      if (cfg.projectileType === 'beam') {
        this._fireBeam(o, dir.clone(), cfg);
      } else {
        this._spawnBolt(o, dir.clone(), cfg);
      }
    });
  }

  fireAt(origin, direction) {
    const cfg = WEAPON_CONFIGS[this._weapon];
    if (!cfg) return;
    if (this._cooldown > 0) return;

    this._cooldown = cfg.fireRate;

    const dir = direction.clone().normalize();

    if (cfg.spread > 0) {
      dir.x += (Math.random() - 0.5) * cfg.spread;
      dir.y += (Math.random() - 0.5) * cfg.spread;
      dir.z += (Math.random() - 0.5) * cfg.spread;
      dir.normalize();
    }

    const spawnOrigin = origin.clone().add(cfg.originOffset);

    if (cfg.projectileType === 'beam') {
      this._fireBeam(spawnOrigin, dir, cfg);
      return;
    }

    this._spawnBolt(spawnOrigin, dir, cfg);

    const burstCount = cfg.burst ?? 1;
    const burstDelay = cfg.burstDelay ?? 0.045;

    for (let i = 1; i < burstCount; i++) {
      this._burstQueue.push({
        origin: spawnOrigin.clone(),
        dir: dir.clone(),
        cfg,
        delay: i * burstDelay,
        elapsed: 0,
      });
    }
  }

  update(delta, targets = []) {
    this._cooldown = Math.max(0, this._cooldown - delta);

    // Rafales
    for (let i = this._burstQueue.length - 1; i >= 0; i--) {
      const bq = this._burstQueue[i];
      bq.elapsed += delta;
      if (bq.elapsed >= bq.delay) {
        this._spawnBolt(bq.origin, bq.dir, bq.cfg);
        this._burstQueue.splice(i, 1);
      }
    }

    // Projectiles actifs
    const hasTargets = targets.length > 0;
    const ray = hasTargets ? new THREE.Raycaster() : null;

    for (let i = this._active.length - 1; i >= 0; i--) {
      const b = this._active[i];
      b.life += delta;

      const prevPos = b.mesh.position.clone();
      b.mesh.position.addScaledVector(b.velocity, delta);
      b.light.position.copy(b.mesh.position);

      // Trail
      b.trailPts.unshift(b.mesh.position.clone());
      if (b.trailPts.length > b.trailMaxLen) b.trailPts.pop();
      if (b.trailPts.length >= 2) {
        b.trail.geometry.setFromPoints(b.trailPts);
        b.trail.geometry.computeBoundingSphere();
      }

      const lifeRatio = b.life / b.maxLife;
      b.trail.material.opacity = b.trailOpacity * (1 - lifeRatio * 0.65);
      b.mesh.material.opacity = Math.max(0, 1 - lifeRatio * lifeRatio);
      b.mesh.scale.set(
        b.baseScale.x * (1.0 + 0.08 * Math.sin(b.life * 60)),
        b.baseScale.y * (1.0 + 0.08 * Math.sin(b.life * 60)),
        b.baseScale.z
      );
      b.light.intensity = b.cfg.lightIntensity * (1 - lifeRatio * 0.9);

      // Collision
      if (hasTargets) {
        const moveDir = b.mesh.position.clone().sub(prevPos);
        const moveDist = moveDir.length();

        if (moveDist > 0.0001) {
          ray.set(prevPos, moveDir.clone().normalize());
          ray.far = moveDist + b.cfg.radius * 1.5;

          const hits = ray.intersectObjects(targets, true);
          if (hits.length > 0) {
            const hit = hits[0];
            this._spawnImpact(hit.point, b.cfg.color, Math.max(0.12, b.cfg.radius * 1.6));

            if (this._onHit) {
              this._onHit({
                point: hit.point.clone(),
                normal: hit.face?.normal?.clone() ?? new THREE.Vector3(0, 1, 0),
                target: hit.object,
                weapon: b.cfg.label,
                damage: b.cfg.damage ?? this._calcDamage(b.cfg),
              });
            }

            this._returnToPool(b);
            this._active.splice(i, 1);
            continue;
          }
        }
      }

      if (b.life >= b.maxLife) {
        this._returnToPool(b);
        this._active.splice(i, 1);
      }
    }

    // Beams
    for (let i = this._beams.length - 1; i >= 0; i--) {
      const beam = this._beams[i];
      beam.life += delta;
      const t = beam.life / beam.maxLife;

      beam.mesh.material.opacity = beam.baseOpacity * (1 - t);
      beam.glow.material.opacity = beam.baseGlowOpacity * (1 - t);

      if (beam.life >= beam.maxLife) {
        this._scene.remove(beam.mesh);
        this._scene.remove(beam.glow);
        beam.mesh.geometry.dispose();
        beam.mesh.material.dispose();
        beam.glow.geometry.dispose();
        beam.glow.material.dispose();
        this._beams.splice(i, 1);
      }
    }

    // Impacts
    for (let i = this._impacts.length - 1; i >= 0; i--) {
      const imp = this._impacts[i];
      imp.life += delta;
      const t = imp.life / imp.maxLife;

      const s = imp.baseRadius * (0.15 + t * 1.35);
      imp.mesh.scale.setScalar(s);
      imp.mesh.material.opacity = Math.max(0, 1 - t);
      imp.mesh.material.emissiveIntensity = 4.5 * (1 - t);
      imp.light.intensity = 8 * (1 - t);

      if (imp.life >= imp.maxLife) {
        this._scene.remove(imp.mesh);
        this._scene.remove(imp.light);
        imp.mesh.material.dispose();
        this._impacts.splice(i, 1);
      }
    }
  }

  get canFire() {
    return this._cooldown <= 0;
  }

  get activeCount() {
    return this._active.length + this._beams.length;
  }

  dispose() {
    [...this._active].forEach(b => this._returnToPool(b));

    for (const b of this._pool) {
      b.mesh.geometry.dispose();
      b.mesh.material.dispose();
      b.trail.geometry.dispose();
      b.trail.material.dispose();
    }

    for (const beam of this._beams) {
      this._scene.remove(beam.mesh);
      this._scene.remove(beam.glow);
      beam.mesh.geometry.dispose();
      beam.mesh.material.dispose();
      beam.glow.geometry.dispose();
      beam.glow.material.dispose();
    }

    for (const imp of this._impacts) {
      this._scene.remove(imp.mesh);
      this._scene.remove(imp.light);
      imp.mesh.material.dispose();
    }

    this._pool = [];
    this._active = [];
    this._beams = [];
    this._impacts = [];
    this._burstQueue = [];
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  _calcDamage(cfg) {
    return cfg.damage ?? 10;
  }

  _makeBolt() {
    // MeshBasicMaterial + NormalBlending : sphère opaque visible sur tout fond,
    // ignore l'éclairage (pas de surexposition par les PointLights).
    // depthTest: false — le bolt spawn au point Muzzle (surface du gant) ;
    // avec depthTest actif ses fragments sont cachés par le depth buffer du gant.
    const mesh = new THREE.Mesh(
      _boltGeo,
      new THREE.MeshBasicMaterial({
        color: 0xffffff,
        transparent: true,
        opacity: 1.0,
        depthWrite: false,
        depthTest: false,
      })
    );
    mesh.renderOrder = 10;
    mesh.frustumCulled = false;

    const light = new THREE.PointLight(0xffffff, 2, 2);

    const trailGeo = new THREE.BufferGeometry();
    trailGeo.setFromPoints([new THREE.Vector3(), new THREE.Vector3()]);
    const trailMat = new THREE.LineBasicMaterial({
      color: 0xffffff,
      transparent: true,
      opacity: 0.5,
      depthWrite: false,
      depthTest: false,
    });
    const trail = new THREE.Line(trailGeo, trailMat);
    trail.renderOrder = 9;

    return {
      mesh,
      light,
      trail,
      velocity: new THREE.Vector3(),
      life: 0,
      maxLife: 1.5,
      trailPts: [],
      trailMaxLen: 10,
      trailOpacity: 0.5,
      baseScale: new THREE.Vector3(1, 1, 1),
      cfg: null,
    };
  }

  _spawnBolt(origin, direction, cfg) {
    let b;

    if (this._pool.length > 0) {
      b = this._pool.pop();
    } else if (this._active.length >= this._poolSize) {
      b = this._active.shift();
      this._scene.remove(b.mesh);
      this._scene.remove(b.light);
      this._scene.remove(b.trail);
    } else {
      b = this._makeBolt();
    }

    b.cfg = cfg;
    b.life = 0;
    b.maxLife = cfg.maxLife ?? 1.5;
    b.trailPts = [origin.clone()];
    b.trailMaxLen = cfg.trailLen ?? 10;
    b.trailOpacity = cfg.trailOpacity ?? 0.5;

    b.mesh.position.copy(origin);

    const sx = cfg.radius ?? 0.09;
    const sy = cfg.radius ?? 0.09;
    const sz = (cfg.radius ?? 0.09) * (cfg.stretch ?? 1.4);
    b.baseScale.set(sx, sy, sz);
    b.mesh.scale.copy(b.baseScale);

    b.mesh.material.color.setHex(cfg.color);
    b.mesh.material.opacity = 1.0;

    const quat = new THREE.Quaternion();
    quat.setFromUnitVectors(
      new THREE.Vector3(0, 0, 1),
      direction.clone().normalize()
    );
    b.mesh.quaternion.copy(quat);

    b.light.color.setHex(cfg.color);
    b.light.intensity = cfg.lightIntensity ?? 2.0;
    b.light.distance = cfg.lightRange ?? 2.0;
    b.light.position.copy(origin);

    b.trail.material.color.setHex(cfg.color);
    b.trail.material.opacity = cfg.trailOpacity ?? 0.5;
    b.trail.geometry.setFromPoints([origin, origin]);

    b.velocity.copy(direction).normalize().multiplyScalar(cfg.speed ?? 20);

    this._scene.add(b.mesh);
    this._scene.add(b.light);
    this._scene.add(b.trail);
    this._active.push(b);
  }

  _returnToPool(b) {
    this._scene.remove(b.mesh);
    this._scene.remove(b.light);
    this._scene.remove(b.trail);
    b.trailPts = [];
    this._pool.push(b);
  }

  _fireBeam(origin, direction, cfg) {
    const dir = direction.clone().normalize();
    // near=1.5 : évite que le raycast tape le mesh de l'arme au départ
    const ray = new THREE.Raycaster(origin, dir, 1.5, cfg.beamLength ?? 20);

    // Utilise les colliders dédiés si disponibles (évite de taper les SkinnedMesh en bind pose)
    const useTargets = this._beamTargets?.length > 0;
    const testTargets = useTargets ? this._beamTargets : this._scene.children;
    const hits = ray.intersectObjects(testTargets, !useTargets)
      .filter(h => h.object.isMesh);

    let hitPoint = origin.clone().addScaledVector(dir, cfg.beamLength ?? 20);
    let hitTarget = null;

    if (hits.length > 0) {
      for (const h of hits) {
        if (h.object.type === 'Line' || h.object.type === 'Points') continue;
        hitPoint.copy(h.point);
        hitTarget = h.object;
        break;
      }
    }

    const dist = origin.distanceTo(hitPoint);
    if (dist <= 0.0001) return;

    const radius = cfg.radius ?? 0.12;

    const beamGeo = new THREE.CylinderGeometry(radius, radius, dist, 12, 1, false);
    const beamMat = new THREE.MeshBasicMaterial({
      color: cfg.color,
      transparent: true,
      opacity: cfg.beamOpacity ?? 0.9,
      depthWrite: false,
    });

    const glowGeo = new THREE.CylinderGeometry(radius * 1.9, radius * 1.9, dist, 12, 1, false);
    const glowMat = new THREE.MeshBasicMaterial({
      color: cfg.color,
      transparent: true,
      opacity: 0.18,
      depthWrite: false,
    });

    const beam = new THREE.Mesh(beamGeo, beamMat);
    const glow = new THREE.Mesh(glowGeo, glowMat);

    const mid = origin.clone().lerp(hitPoint, 0.5);
    beam.position.copy(mid);
    glow.position.copy(mid);

    const q = new THREE.Quaternion().setFromUnitVectors(
      new THREE.Vector3(0, 1, 0),
      dir
    );
    beam.quaternion.copy(q);
    glow.quaternion.copy(q);

    beam.renderOrder = 5;
    glow.renderOrder = 4;

    this._scene.add(glow);
    this._scene.add(beam);

    this._beams.push({
      mesh: beam,
      glow,
      life: 0,
      maxLife: cfg.beamLife ?? 0.06,
      baseOpacity: cfg.beamOpacity ?? 0.9,
      baseGlowOpacity: 0.18,
    });

    this._spawnImpact(hitPoint, cfg.color, cfg.impactRadius ?? 0.18);

    if (hitTarget && this._onHit) {
      this._onHit({
        point: hitPoint.clone(),
        normal: new THREE.Vector3(0, 1, 0),
        target: hitTarget,
        weapon: cfg.label,
        damage: cfg.damage ?? this._calcDamage(cfg),
      });
    }
  }

  _spawnImpact(position, color, radius = 0.16) {
    const mat = new THREE.MeshStandardMaterial({
      color: new THREE.Color(color),
      emissive: new THREE.Color(color),
      emissiveIntensity: 4.5,
      transparent: true,
      opacity: 1.0,
      depthWrite: false,
    });

    const mesh = new THREE.Mesh(_impactGeo, mat);
    mesh.position.copy(position);
    mesh.scale.setScalar(radius * 0.15);
    mesh.renderOrder = 3;

    const light = new THREE.PointLight(color, 8, 3.2);
    light.position.copy(position);

    this._scene.add(mesh);
    this._scene.add(light);

    this._impacts.push({
      mesh,
      light,
      life: 0,
      maxLife: 0.24,
      baseRadius: radius,
    });
  }
}