"""
NeuroHell — Zero Root Motion
Compatible Blender 3.x et 4.x (Layered Actions)

Usage :
  1. Ouvrir le GLB du démon dans Blender
  2. Scripting → coller ce fichier → Run Script
  3. File → Export → glTF 2.0 → remplacer le GLB original
"""

import bpy

# Noms de root bones — conventions Mixamo, Godot ET rigs custom francophones
ROOT_BONES = [
    'Root', 'root', 'Hips', 'hips',
    'mixamorig:Hips', 'mixamorig:Root',
    'pelvis', 'Pelvis',
    # Rigs francophones (NeuroHell)
    'Os_racine', 'os_racine', 'Racine', 'racine',
    'Bassin', 'bassin', 'Origine', 'origine',
]


def get_fcurves(action):
    """Retourne toutes les FCurves d'une action — compatible Blender 3.x et 4.4+"""
    # Blender 4.4+ : Layered Actions → layers → strips → channelbags → fcurves
    if hasattr(action, 'layers'):
        curves = []
        for layer in action.layers:
            for strip in layer.strips:
                if hasattr(strip, 'channelbags'):
                    for bag in strip.channelbags:
                        curves.extend(bag.fcurves)
        if curves:
            return curves

    # Blender 3.x / fallback : action.fcurves existe directement
    if hasattr(action, 'fcurves'):
        return list(action.fcurves)

    return []


def zero_root_motion():
    total_actions  = 0
    total_curves   = 0

    for action in bpy.data.actions:
        count = 0
        for fcurve in get_fcurves(action):
            # Seulement les courbes de position (pas rotation/scale)
            if 'location' not in fcurve.data_path:
                continue
            # Seulement X (index 0) et Z (index 2) — déplacement horizontal
            if fcurve.array_index not in [0, 2]:
                continue
            # Vérifier si la courbe cible un root bone
            for bone in ROOT_BONES:
                if bone in fcurve.data_path:
                    for kp in fcurve.keyframe_points:
                        kp.co.y          = 0.0
                        kp.handle_left.y  = 0.0
                        kp.handle_right.y = 0.0
                    fcurve.update()
                    count += 1
                    break

        if count:
            print(f"✅  {action.name} : {count} courbe(s) X/Z remises à zéro")
            total_actions += 1
            total_curves  += count

    print(f"\n--- Terminé : {total_actions} action(s), {total_curves} courbe(s) modifiée(s) ---")
    print("→ File → Export → glTF 2.0 pour re-générer le GLB")


zero_root_motion()
