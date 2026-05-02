bl_info = {
    "name": "NeuroHell Semi-Directed Level Generator",
    "author": "OpenAI",
    "version": (0, 2, 5, 3),
    "blender": (4, 0, 0),
    "location": "View3D > Sidebar > NeuroHell",
    "description": "Semi-directed FPS blockout with exact room openings, cleaner corridor turns, auto textures and front-biased decor placement",
    "category": "Object",
}

import bpy
import random
from pathlib import Path
from mathutils import Vector
from bpy.props import (
    IntProperty,
    FloatProperty,
    BoolProperty,
    EnumProperty,
    PointerProperty,
    StringProperty,
)
from bpy.types import Operator, Panel, PropertyGroup


# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

def ensure_collection(name, parent=None):
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        if parent is None:
            bpy.context.scene.collection.children.link(col)
        else:
            parent.children.link(col)
    return col


def clear_collection(col):
    for child in list(col.children):
        clear_collection(child)
        try:
            col.children.unlink(child)
        except Exception:
            pass
        try:
            bpy.data.collections.remove(child)
        except Exception:
            pass
    for obj in list(col.objects):
        bpy.data.objects.remove(obj, do_unlink=True)


def link_object_to_collection(obj, col):
    for c in list(obj.users_collection):
        try:
            c.objects.unlink(obj)
        except Exception:
            pass
    col.objects.link(obj)


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def rect_overlaps(a, b, margin=0.0):
    return not (
        a[2] + margin <= b[0] or
        a[0] >= b[2] + margin or
        a[3] + margin <= b[1] or
        a[1] >= b[3] + margin
    )


def create_cube(name, location, scale, collection, material=None):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    try:
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.cube_project(cube_size=1.0)
        bpy.ops.object.mode_set(mode='OBJECT')
    except Exception:
        pass
    link_object_to_collection(obj, collection)
    if material is not None:
        if obj.data.materials:
            obj.data.materials[0] = material
        else:
            obj.data.materials.append(material)
    return obj


def create_cylinder(name, location, radius, depth, collection, material=None, vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location)
    obj = bpy.context.active_object
    obj.name = name
    link_object_to_collection(obj, collection)
    if material is not None:
        if obj.data.materials:
            obj.data.materials[0] = material
        else:
            obj.data.materials.append(material)
    return obj


def create_uv_sphere(name, location, radius, collection, material=None):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=location)
    obj = bpy.context.active_object
    obj.name = name
    link_object_to_collection(obj, collection)
    if material is not None:
        if obj.data.materials:
            obj.data.materials[0] = material
        else:
            obj.data.materials.append(material)
    return obj


def create_plane_marker(name, location, scale, collection, material=None, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_plane_add(location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    link_object_to_collection(obj, collection)
    if material is not None:
        if obj.data.materials:
            obj.data.materials[0] = material
        else:
            obj.data.materials.append(material)
    return obj


# ------------------------------------------------------------
# Texture helpers
# ------------------------------------------------------------

def make_basic_material(name, color, emission_strength=0.0):
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    out = nodes.new("ShaderNodeOutputMaterial")
    out.location = (320, 0)
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (40, 0)
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Emission Color"].default_value = color
    bsdf.inputs["Emission Strength"].default_value = emission_strength
    links.new(bsdf.outputs[0], out.inputs[0])
    return mat


def find_first_file(folder: Path, stems):
    if not folder.exists():
        return None
    exts = [".png", ".jpg", ".jpeg", ".webp", ".tif", ".tiff", ".exr"]
    for stem in stems:
        for ext in exts:
            p = folder / f"{stem}{ext}"
            if p.exists():
                return p
    return None


def get_texture_folder(settings, folder_name: str) -> Path:
    root = Path(bpy.path.abspath(settings.game_root_folder))
    return root / "assets" / "images" / "textures" / folder_name


def get_or_load_image(path: Path):
    abs_path = str(path.resolve())
    for img in bpy.data.images:
        try:
            if str(Path(bpy.path.abspath(img.filepath)).resolve()) == abs_path:
                return img
        except Exception:
            pass
    try:
        return bpy.data.images.load(str(path), check_existing=True)
    except RuntimeError:
        return None


def build_pbr_material_from_folder(mat_name: str, folder: Path, tex_scale: float = 0.5):
    mat = bpy.data.materials.get(mat_name)
    if mat is None:
        mat = bpy.data.materials.new(mat_name)
    mat.use_nodes = True

    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    out = nodes.new("ShaderNodeOutputMaterial")
    out.location = (1100, 0)
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (760, 0)
    bsdf.inputs["Roughness"].default_value = 1.0
    links.new(bsdf.outputs[0], out.inputs[0])

    texcoord = nodes.new("ShaderNodeTexCoord")
    texcoord.location = (-1200, 0)
    mapping = nodes.new("ShaderNodeMapping")
    mapping.location = (-980, 0)
    mapping.inputs["Scale"].default_value[0] = tex_scale
    mapping.inputs["Scale"].default_value[1] = tex_scale
    mapping.inputs["Scale"].default_value[2] = tex_scale
    links.new(texcoord.outputs["UV"], mapping.inputs["Vector"])

    ao_path = find_first_file(folder, ["ao"])
    albedo_path = find_first_file(folder, ["albedo", "basecolor", "color"])
    normal_path = find_first_file(folder, ["normal"])
    roughness_path = find_first_file(folder, ["roughness", "rough"])
    metallic_path = find_first_file(folder, ["metallic", "metalness"])
    emissive_path = find_first_file(folder, ["emissive", "emission"])

    albedo_node = None
    if albedo_path:
        img = get_or_load_image(albedo_path)
        if img:
            albedo_node = nodes.new("ShaderNodeTexImage")
            albedo_node.location = (-700, 240)
            albedo_node.image = img
            links.new(mapping.outputs["Vector"], albedo_node.inputs["Vector"])

    if ao_path and albedo_node:
        img = get_or_load_image(ao_path)
        if img:
            ao_node = nodes.new("ShaderNodeTexImage")
            ao_node.location = (-700, 60)
            ao_node.image = img
            ao_node.image.colorspace_settings.name = 'Non-Color'
            mix = nodes.new("ShaderNodeMixRGB")
            mix.blend_type = 'MULTIPLY'
            mix.inputs[0].default_value = 1.0
            mix.location = (200, 180)
            links.new(mapping.outputs["Vector"], ao_node.inputs["Vector"])
            links.new(albedo_node.outputs["Color"], mix.inputs[1])
            links.new(ao_node.outputs["Color"], mix.inputs[2])
            links.new(mix.outputs["Color"], bsdf.inputs["Base Color"])
        else:
            links.new(albedo_node.outputs["Color"], bsdf.inputs["Base Color"])
    elif albedo_node:
        links.new(albedo_node.outputs["Color"], bsdf.inputs["Base Color"])

    if roughness_path:
        img = get_or_load_image(roughness_path)
        if img:
            rough = nodes.new("ShaderNodeTexImage")
            rough.location = (-700, -120)
            rough.image = img
            rough.image.colorspace_settings.name = 'Non-Color'
            links.new(mapping.outputs["Vector"], rough.inputs["Vector"])
            links.new(rough.outputs["Color"], bsdf.inputs["Roughness"])

    if metallic_path:
        img = get_or_load_image(metallic_path)
        if img:
            metal = nodes.new("ShaderNodeTexImage")
            metal.location = (-700, -300)
            metal.image = img
            metal.image.colorspace_settings.name = 'Non-Color'
            links.new(mapping.outputs["Vector"], metal.inputs["Vector"])
            links.new(metal.outputs["Color"], bsdf.inputs["Metallic"])

    if normal_path:
        img = get_or_load_image(normal_path)
        if img:
            normal_tex = nodes.new("ShaderNodeTexImage")
            normal_tex.location = (-700, -500)
            normal_tex.image = img
            normal_tex.image.colorspace_settings.name = 'Non-Color'
            normal_map = nodes.new("ShaderNodeNormalMap")
            normal_map.location = (180, -480)
            links.new(mapping.outputs["Vector"], normal_tex.inputs["Vector"])
            links.new(normal_tex.outputs["Color"], normal_map.inputs["Color"])
            links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])

    if emissive_path:
        img = get_or_load_image(emissive_path)
        if img:
            emissive = nodes.new("ShaderNodeTexImage")
            emissive.location = (-700, -700)
            emissive.image = img
            links.new(mapping.outputs["Vector"], emissive.inputs["Vector"])
            links.new(emissive.outputs["Color"], bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = 2.4

    return mat


def build_material_library(settings):
    mats = {
        "wall": make_basic_material("NH_Fallback_Wall", (0.22, 0.20, 0.23, 1.0)),
        "floor": make_basic_material("NH_Fallback_Floor", (0.10, 0.10, 0.10, 1.0)),
        "lava": make_basic_material("NH_Fallback_Lava", (1.0, 0.30, 0.05, 1.0), emission_strength=3.0),
        "metal": make_basic_material("NH_Fallback_Metal", (0.24, 0.24, 0.28, 1.0)),
        "gothic": make_basic_material("NH_Fallback_Gothic", (0.18, 0.18, 0.20, 1.0)),
        "window": make_basic_material("NH_Window", (0.12, 0.75, 1.0, 1.0), emission_strength=1.6),
        "door": make_basic_material("NH_Door", (0.13, 0.13, 0.16, 1.0)),
        "marker_spawn": make_basic_material("NH_MarkerSpawn", (0.2, 1.0, 0.2, 1.0), emission_strength=1.5),
        "marker_arena": make_basic_material("NH_MarkerArena", (1.0, 0.55, 0.1, 1.0), emission_strength=1.5),
        "marker_portal": make_basic_material("NH_MarkerPortal", (0.3, 0.7, 1.0, 1.0), emission_strength=3.0),
        "marker_weapon": make_basic_material("NH_MarkerWeapon", (1.0, 0.85, 0.15, 1.0), emission_strength=2.0),
        "gargoyle": make_basic_material("NH_Gargoyle", (0.38, 0.38, 0.40, 1.0)),
    }

    if not settings.use_game_textures:
        return mats

    s = settings.texture_scale
    folders = {
        "wall": get_texture_folder(settings, settings.wall_texture_set),
        "floor": get_texture_folder(settings, settings.floor_texture_set),
        "lava": get_texture_folder(settings, settings.lava_texture_set),
        "metal": get_texture_folder(settings, settings.metal_texture_set),
        "gothic": get_texture_folder(settings, settings.gothic_texture_set),
    }
    names = {
        "wall": "NH_Wall",
        "floor": "NH_Floor",
        "lava": "NH_Lava",
        "metal": "NH_Metal",
        "gothic": "NH_Gothic",
    }
    for key, folder in folders.items():
        if folder.exists():
            mats[key] = build_pbr_material_from_folder(names[key], folder, s)
    return mats


# ------------------------------------------------------------
# Layout model
# ------------------------------------------------------------

def rect_room(name, cx, cy, w, h, room_type):
    return {
        "name": name,
        "type": room_type,
        "x1": cx - w * 0.5,
        "y1": cy - h * 0.5,
        "x2": cx + w * 0.5,
        "y2": cy + h * 0.5,
        "w": w,
        "h": h,
        "center": Vector((cx, cy, 0.0)),
    }


def room_bounds(room):
    return room["x1"], room["y1"], room["x2"], room["y2"]


def dir_to_side(dx, dy):
    if abs(dx) >= abs(dy):
        return "E" if dx >= 0 else "W"
    return "N" if dy >= 0 else "S"


def opposite_side(side):
    return {"N": "S", "S": "N", "E": "W", "W": "E"}[side]


def opening_local_offset(room_w, room_h, side, wall_t):
    if side == "N":
        return Vector((0.0, room_h * 0.5 - wall_t * 0.5, 0.0))
    if side == "S":
        return Vector((0.0, -room_h * 0.5 + wall_t * 0.5, 0.0))
    if side == "E":
        return Vector((room_w * 0.5 - wall_t * 0.5, 0.0, 0.0))
    return Vector((-room_w * 0.5 + wall_t * 0.5, 0.0, 0.0))


def room_center_from_entry(entry_point, room_w, room_h, entry_side, wall_t):
    local = opening_local_offset(room_w, room_h, entry_side, wall_t)
    center = entry_point - local
    return center.x, center.y


def entry_offset_for_turn(base_entry, new_dx, new_dy, prev_dx, prev_dy, corridor_width):
    if prev_dx == 0 and prev_dy == 0:
        return base_entry

    prev_h = abs(prev_dx) > 0
    new_h = abs(new_dx) > 0
    if prev_h == new_h:
        return base_entry

    half = corridor_width * 0.5
    if new_h:
        return Vector((base_entry.x + (1 if new_dx >= 0 else -1) * half, base_entry.y, 0.0))
    return Vector((base_entry.x, base_entry.y + (1 if new_dy >= 0 else -1) * half, 0.0))


def generate_room_layout(settings):
    rnd = random.Random(settings.seed)

    spawn = rect_room("Spawn", 0.0, 0.0, settings.spawn_width, settings.spawn_height, "spawn")
    rooms = [spawn]
    occupied = [room_bounds(spawn)]
    corridors = []

    current = spawn
    prev_dx, prev_dy = 0, 0

    total_mid = max(0, settings.room_count - 2)
    all_specs = []
    for i in range(total_mid):
        kind = "arena" if (i == 0 and settings.include_arena) else "room"
        all_specs.append((f"Room_{i+1}", kind))
    all_specs.append(("Portal_Final", "portal"))

    for room_name, room_kind in all_specs:
        w = settings.final_width if room_kind == "portal" else rnd.uniform(settings.room_min_size, settings.room_max_size)
        h = settings.final_height if room_kind == "portal" else rnd.uniform(settings.room_min_size, settings.room_max_size)

        if settings.layout_style == 'LINEAR':
            choices = [(1, 0), (0, 1), (0, -1)]
        elif settings.layout_style == 'ZIGZAG':
            choices = [(1, 0), (0, 1), (1, 0), (0, -1)]
        else:
            choices = [(1, 0), (1, 0), (0, 1), (0, -1)]

        placed = None
        corridor_data = None

        for _ in range(64):
            dx, dy = rnd.choice(choices)
            if dx == 0 and dy == 0:
                continue

            exit_side = dir_to_side(dx, dy)
            entry_side = opposite_side(exit_side)
            exit_point = current["center"] + opening_local_offset(current["w"], current["h"], exit_side, settings.wall_thickness)

            dist = settings.room_spacing_max if room_kind == "portal" else rnd.uniform(settings.room_spacing_min, settings.room_spacing_max)
            base_entry = exit_point + Vector((dx * dist, dy * dist, 0.0))
            entry_point = entry_offset_for_turn(base_entry, dx, dy, prev_dx, prev_dy, settings.corridor_width)

            cx, cy = room_center_from_entry(entry_point, w, h, entry_side, settings.wall_thickness)
            candidate = rect_room(room_name, cx, cy, w, h, room_kind)

            if any(rect_overlaps(room_bounds(candidate), other, settings.room_margin) for other in occupied):
                continue

            placed = candidate
            corridor_data = {
                "name": f"Corridor_{len(corridors) + 1}",
                "a": current,
                "b": candidate,
                "exit_side_a": exit_side,
                "entry_side_b": entry_side,
                "exit_point_a": exit_point.copy(),
                "entry_point_b": entry_point.copy(),
                "dir": (dx, dy),
            }
            break

        if placed is None:
            dx, dy = 1, 0
            exit_side = dir_to_side(dx, dy)
            entry_side = opposite_side(exit_side)
            exit_point = current["center"] + opening_local_offset(current["w"], current["h"], exit_side, settings.wall_thickness)
            base_entry = exit_point + Vector((settings.room_spacing_max, 0.0, 0.0))
            entry_point = entry_offset_for_turn(base_entry, dx, dy, prev_dx, prev_dy, settings.corridor_width)
            cx, cy = room_center_from_entry(entry_point, w, h, entry_side, settings.wall_thickness)
            placed = rect_room(room_name, cx, cy, w, h, room_kind)
            corridor_data = {
                "name": f"Corridor_{len(corridors) + 1}",
                "a": current,
                "b": placed,
                "exit_side_a": exit_side,
                "entry_side_b": entry_side,
                "exit_point_a": exit_point.copy(),
                "entry_point_b": entry_point.copy(),
                "dir": (dx, dy),
            }

        occupied.append(room_bounds(placed))
        rooms.append(placed)
        corridors.append(corridor_data)
        current = placed
        prev_dx, prev_dy = corridor_data["dir"]

    return rooms, corridors


# ------------------------------------------------------------
# Room geometry
# ------------------------------------------------------------

def get_connection_side(room, target):
    delta = target["center"] - room["center"]
    if abs(delta.x) >= abs(delta.y):
        return "E" if delta.x >= 0 else "W"
    return "N" if delta.y >= 0 else "S"


def get_corridor_entry_center(room, side, corridor_width, wall_t):
    local = opening_local_offset(room["w"], room["h"], side, wall_t)
    return room["center"] + local


def segment_wall_with_openings(name_prefix, orientation, fixed_coord, axis_start, axis_end, wall_t, wall_h, openings, collection, material):
    wall_t_half = wall_t * 0.5
    boundaries = [axis_start, axis_end]
    for op_center, op_width, op_height, op_bottom in openings:
        left = clamp(op_center - op_width * 0.5, axis_start, axis_end)
        right = clamp(op_center + op_width * 0.5, axis_start, axis_end)
        boundaries.extend([left, right])

    boundaries = sorted(set(boundaries))
    for i in range(len(boundaries) - 1):
        s = boundaries[i]
        e = boundaries[i + 1]
        seg_len = e - s
        if seg_len <= 0.02:
            continue
        mid = (s + e) * 0.5

        opening = None
        for op_center, op_width, op_height, op_bottom in openings:
            left = op_center - op_width * 0.5
            right = op_center + op_width * 0.5
            if left <= mid <= right:
                opening = (op_center, op_width, op_height, op_bottom)
                break

        def make_seg(seg_name, z_center, z_half):
            if orientation == "H":
                obj = create_cube(seg_name, (mid, fixed_coord, z_center), (seg_len * 0.5, wall_t_half, z_half), collection, material)
            else:
                obj = create_cube(seg_name, (fixed_coord, mid, z_center), (wall_t_half, seg_len * 0.5, z_half), collection, material)
            obj["nh_type"] = "wall"
            return obj

        if opening is None:
            make_seg(f"{name_prefix}_{i}", wall_h * 0.5, wall_h * 0.5)
            continue

        _, _, op_height, op_bottom = opening
        if op_bottom > 0.02:
            make_seg(f"{name_prefix}_{i}_base", op_bottom * 0.5, op_bottom * 0.5)

        lintel_h = wall_h - (op_bottom + op_height)
        if lintel_h > 0.02:
            make_seg(f"{name_prefix}_{i}_lintel", op_bottom + op_height + lintel_h * 0.5, lintel_h * 0.5)


def add_opening_frame(room_col, room_name, side, center, width, bottom, height, wall_t, mats):
    frame_t = wall_t * 0.5
    jamb = max(0.08, wall_t * 0.35)
    lintel_h = max(0.10, wall_t * 0.45)
    half = width * 0.5
    z_mid = bottom + height * 0.5

    if side in {"N", "S"}:
        y = center.y
        create_cube(f"{room_name}_{side}_Frame_L", (center.x - half - jamb * 0.5, y, z_mid), (jamb * 0.5, frame_t * 0.5, height * 0.5), room_col, mats["door"])
        create_cube(f"{room_name}_{side}_Frame_R", (center.x + half + jamb * 0.5, y, z_mid), (jamb * 0.5, frame_t * 0.5, height * 0.5), room_col, mats["door"])
        create_cube(f"{room_name}_{side}_Frame_T", (center.x, y, bottom + height + lintel_h * 0.5), (half, frame_t * 0.5, lintel_h * 0.5), room_col, mats["door"])
    else:
        x = center.x
        create_cube(f"{room_name}_{side}_Frame_L", (x, center.y - half - jamb * 0.5, z_mid), (frame_t * 0.5, jamb * 0.5, height * 0.5), room_col, mats["door"])
        create_cube(f"{room_name}_{side}_Frame_R", (x, center.y + half + jamb * 0.5, z_mid), (frame_t * 0.5, jamb * 0.5, height * 0.5), room_col, mats["door"])
        create_cube(f"{room_name}_{side}_Frame_T", (x, center.y, bottom + height + lintel_h * 0.5), (frame_t * 0.5, half, lintel_h * 0.5), room_col, mats["door"])


def build_room(room, opening_specs, root_col, mats, settings):
    room_col = ensure_collection(f"ROOM_{room['name']}", root_col)
    wall_h = settings.wall_height
    wall_t = settings.wall_thickness
    floor_t = settings.floor_thickness
    cx = room["center"].x
    cy = room["center"].y
    w = room["w"]
    h = room["h"]

    if room["type"] == "arena":
        floor_mat = mats["lava"]
    elif room["type"] == "portal":
        floor_mat = mats["gothic"]
    else:
        floor_mat = mats["floor"]
    wall_mat = mats["gothic"] if room["type"] == "portal" else mats["wall"]

    floor = create_cube(f"LVL_{room['name']}_Floor", (cx, cy, -floor_t * 0.5), (w * 0.5, h * 0.5, floor_t * 0.5), room_col, floor_mat)
    floor["nh_type"] = "floor"

    openings = {"N": [], "S": [], "E": [], "W": []}
    sides_with_doors = set()

    for spec in opening_specs:
        side = spec["side"]
        center = spec["point"]
        width = settings.corridor_width - settings.wall_thickness
        axis_center = center.x if side in {"N", "S"} else center.y
        openings[side].append((axis_center, width, settings.door_height, settings.door_bottom))
        sides_with_doors.add(side)
        add_opening_frame(room_col, room["name"], side, center, width, settings.door_bottom, settings.door_height, wall_t, mats)

    if settings.create_windows:
        candidate_sides = []
        if room["type"] in {"portal", "arena"} or (room["type"] == "room" and settings.windows_on_rooms):
            candidate_sides = [s for s in ["N", "S", "E", "W"] if s not in sides_with_doors]

        for side in candidate_sides:
            if side in {"N", "S"}:
                max_w = max(1.2, min(w * 0.35, w - 2.0))
                openings[side].append((cx, max_w, settings.window_height, settings.window_bottom))
                y = cy + h * 0.5 - wall_t * 0.35 if side == "N" else cy - h * 0.5 + wall_t * 0.35
                create_plane_marker(
                    f"LVL_{room['name']}_Window_{side}",
                    (cx, y, settings.window_bottom + settings.window_height * 0.5),
                    (max_w * 0.5, settings.window_height * 0.5, 1.0),
                    room_col, mats["window"], rotation=(1.5708, 0.0, 0.0),
                )
            else:
                max_w = max(1.2, min(h * 0.35, h - 2.0))
                openings[side].append((cy, max_w, settings.window_height, settings.window_bottom))
                x = cx + w * 0.5 - wall_t * 0.35 if side == "E" else cx - w * 0.5 + wall_t * 0.35
                create_plane_marker(
                    f"LVL_{room['name']}_Window_{side}",
                    (x, cy, settings.window_bottom + settings.window_height * 0.5),
                    (max_w * 0.5, settings.window_height * 0.5, 1.0),
                    room_col, mats["window"], rotation=(1.5708, 0.0, 1.5708),
                )

    segment_wall_with_openings(f"LVL_{room['name']}_Wall_N", "H", cy + h * 0.5 - wall_t * 0.5, room["x1"], room["x2"], wall_t, wall_h, openings["N"], room_col, wall_mat)
    segment_wall_with_openings(f"LVL_{room['name']}_Wall_S", "H", cy - h * 0.5 + wall_t * 0.5, room["x1"], room["x2"], wall_t, wall_h, openings["S"], room_col, wall_mat)
    segment_wall_with_openings(f"LVL_{room['name']}_Wall_E", "V", cx + w * 0.5 - wall_t * 0.5, room["y1"], room["y2"], wall_t, wall_h, openings["E"], room_col, wall_mat)
    segment_wall_with_openings(f"LVL_{room['name']}_Wall_W", "V", cx - w * 0.5 + wall_t * 0.5, room["y1"], room["y2"], wall_t, wall_h, openings["W"], room_col, wall_mat)

    if room["type"] == "spawn":
        m = create_uv_sphere("MARKER_Spawn", (cx, cy, 1.0), 0.45, room_col, mats["marker_spawn"])
        m["nh_type"] = "spawn"
    elif room["type"] == "arena":
        m = create_cylinder("MARKER_Arena", (cx, cy, 0.15), min(w, h) * 0.22, 0.2, room_col, mats["marker_arena"])
        m["nh_type"] = "arena"
    elif room["type"] == "portal":
        p = create_cylinder("MARKER_Portal_Final", (cx, cy, 1.5), 1.25, 0.25, room_col, mats["marker_portal"], vertices=32)
        p.rotation_euler[0] = 1.5708
        p["nh_type"] = "portal"

    if settings.place_weapon_marker and room["name"] == "Room_1":
        wpn = create_cube("MARKER_Weapon_01", (cx, cy, 0.45), (0.35, 0.12, 0.12), room_col, mats["marker_weapon"])
        wpn["nh_type"] = "pickup_weapon"

    if settings.place_gargoyle_markers and room["type"] in {"room", "portal", "arena"}:
        gx = cx + w * 0.25
        gy = cy + h * 0.25
        garg = create_cylinder(f"MARKER_Gargoyle_{room['name']}", (gx, gy, 0.75), 0.35, 1.5, room_col, mats["gargoyle"], vertices=6)
        garg["nh_type"] = "gargoyle_marker"


# ------------------------------------------------------------
# Corridor geometry
# ------------------------------------------------------------

def build_corridor_wall_segment(name, horizontal, start, end, fixed, offset_sign, width, wall_t, wall_h, collection, material):
    if horizontal:
        length = abs(end - start)
        if length <= 0.01:
            return None
        mid = (start + end) * 0.5
        y = fixed + offset_sign * (width * 0.5 - wall_t * 0.5)
        obj = create_cube(name, (mid, y, wall_h * 0.5), (length * 0.5, wall_t * 0.5, wall_h * 0.5), collection, material)
    else:
        length = abs(end - start)
        if length <= 0.01:
            return None
        mid = (start + end) * 0.5
        x = fixed + offset_sign * (width * 0.5 - wall_t * 0.5)
        obj = create_cube(name, (x, mid, wall_h * 0.5), (wall_t * 0.5, length * 0.5, wall_h * 0.5), collection, material)
    obj["nh_type"] = "corridor_wall"
    return obj


def build_corridor_floor_segment(name, horizontal, start, end, fixed, width, floor_t, collection, material):
    length = abs(end - start)
    if length <= 0.01:
        return None
    mid = (start + end) * 0.5
    if horizontal:
        obj = create_cube(name, (mid, fixed, -floor_t * 0.5), (length * 0.5, width * 0.5, floor_t * 0.5), collection, material)
    else:
        obj = create_cube(name, (fixed, mid, -floor_t * 0.5), (width * 0.5, length * 0.5, floor_t * 0.5), collection, material)
    obj["nh_type"] = "corridor_floor"
    return obj


def build_corridor(corridor, root_col, mats, settings):
    col = ensure_collection(f"CORRIDOR_{corridor['name']}", root_col)

    a = corridor["exit_point_a"]
    b = corridor["entry_point_b"]

    w = settings.corridor_width
    wall_t = settings.wall_thickness
    wall_h = settings.wall_height
    floor_t = settings.floor_thickness
    half = w * 0.5

    dx = b.x - a.x
    dy = b.y - a.y

    if abs(dx) <= 0.01 or abs(dy) <= 0.01:
        if abs(dx) > abs(dy):
            start = min(a.x, b.x)
            end = max(a.x, b.x)
            build_corridor_floor_segment(f"{corridor['name']}_Floor", True, start, end, a.y, w, floor_t, col, mats["metal"])
            build_corridor_wall_segment(f"{corridor['name']}_Wall_Outer1", True, start, end, a.y, +1, w, wall_t, wall_h, col, mats["wall"])
            build_corridor_wall_segment(f"{corridor['name']}_Wall_Outer2", True, start, end, a.y, -1, w, wall_t, wall_h, col, mats["wall"])
        else:
            start = min(a.y, b.y)
            end = max(a.y, b.y)
            build_corridor_floor_segment(f"{corridor['name']}_Floor", False, start, end, a.x, w, floor_t, col, mats["metal"])
            build_corridor_wall_segment(f"{corridor['name']}_Wall_Outer1", False, start, end, a.x, +1, w, wall_t, wall_h, col, mats["wall"])
            build_corridor_wall_segment(f"{corridor['name']}_Wall_Outer2", False, start, end, a.x, -1, w, wall_t, wall_h, col, mats["wall"])
        return

    # L path
    corner = Vector((b.x, a.y, 0.0))
    sx = 1 if (corner.x - a.x) >= 0 else -1
    sy = 1 if (b.y - corner.y) >= 0 else -1

    start_x = min(a.x, corner.x)
    end_x = max(a.x, corner.x)
    start_y = min(corner.y, b.y)
    end_y = max(corner.y, b.y)

    build_corridor_floor_segment(f"{corridor['name']}_Floor_1", True, start_x, end_x + half, a.y, w, floor_t, col, mats["metal"])
    build_corridor_floor_segment(f"{corridor['name']}_Floor_2", False, start_y - half, end_y, b.x, w, floor_t, col, mats["metal"])

    corner_floor = create_cube(
        f"{corridor['name']}_CornerFloor",
        (corner.x + sx * half * 0.5, corner.y + sy * half * 0.5, -floor_t * 0.5),
        (half * 0.5, half * 0.5, floor_t * 0.5),
        col, mats["metal"]
    )
    corner_floor["nh_type"] = "corridor_floor"

    outer_h_sign = +1 if sy > 0 else -1
    outer_v_sign = +1 if sx > 0 else -1
    inner_h_sign = -outer_h_sign
    inner_v_sign = -outer_v_sign

    build_corridor_wall_segment(f"{corridor['name']}_Wall_H_Outer", True, start_x, end_x + half, a.y, outer_h_sign, w, wall_t, wall_h, col, mats["wall"])
    build_corridor_wall_segment(f"{corridor['name']}_Wall_V_Outer", False, start_y - half, end_y, b.x, outer_v_sign, w, wall_t, wall_h, col, mats["wall"])
    build_corridor_wall_segment(f"{corridor['name']}_Wall_H_Inner", True, start_x, end_x, a.y, inner_h_sign, w, wall_t, wall_h, col, mats["wall"])
    build_corridor_wall_segment(f"{corridor['name']}_Wall_V_Inner", False, start_y, end_y, b.x, inner_v_sign, w, wall_t, wall_h, col, mats["wall"])

    inner_corner = create_cube(
        f"{corridor['name']}_InnerCorner",
        (corner.x - sx * (half - wall_t * 0.5), corner.y - sy * (half - wall_t * 0.5), wall_h * 0.5),
        (wall_t * 0.5, wall_t * 0.5, wall_h * 0.5),
        col, mats["wall"]
    )
    inner_corner["nh_type"] = "corridor_wall"


# ------------------------------------------------------------
# Decor system (v2.5)
# ------------------------------------------------------------

# Which decors can appear per room type
_DECOR_POOL = {
    "spawn":  ["decor_column", "decor_bone_pile"],
    "room":   ["decor_column", "decor_bone_pile", "decor_iron_cage",
               "decor_flesh_pillar", "decor_gargoyle", "decor_gothic_panel",
               "decor_broken_arch"],
    "arena":  ["decor_lava_crack", "decor_altar", "decor_bone_pile",
               "decor_iron_cage", "decor_gargoyle"],
    "portal": ["decor_ritual_circle", "decor_altar", "decor_gothic_panel",
               "decor_gargoyle", "decor_column"],
}

# Collision radius (units) used to avoid overlapping placements
_DECOR_RADIUS = {
    "decor_column":        0.6,
    "decor_bone_pile":     0.9,
    "decor_iron_cage":     1.1,
    "decor_flesh_pillar":  0.7,
    "decor_gargoyle":      0.9,
    "decor_gothic_panel":  1.3,
    "decor_broken_arch":   1.6,
    "decor_lava_crack":    2.2,
    "decor_altar":         1.3,
    "decor_ritual_circle": 1.6,
}

# Scale range (min, max) per decor
_DECOR_SCALE = {
    "decor_column":        (0.8, 1.1),
    "decor_bone_pile":     (0.5, 0.9),
    "decor_iron_cage":     (0.7, 1.0),
    "decor_flesh_pillar":  (0.8, 1.2),
    "decor_gargoyle":      (0.6, 0.9),
    "decor_gothic_panel":  (0.8, 1.0),
    "decor_broken_arch":   (0.8, 1.1),
    "decor_lava_crack":    (0.6, 0.9),
    "decor_altar":         (0.7, 1.0),
    "decor_ritual_circle": (0.8, 1.2),
}

# Hauteur cible en unités Blender (≈ mètres) après import
# Corrige les exports Rodin en cm (scale 0.01) et uniformise les tailles en jeu
_DECOR_TARGET_HEIGHT = {
    "decor_column":        3.5,
    "decor_bone_pile":     0.5,
    "decor_iron_cage":     2.2,
    "decor_flesh_pillar":  3.2,
    "decor_gargoyle":      1.8,
    "decor_gothic_panel":  3.0,
    "decor_broken_arch":   4.0,
    "decor_lava_crack":    0.25,
    "decor_altar":         1.6,
    "decor_ritual_circle": 0.12,
}

# Offset de rotation Z (radians) appliqué sur les vertices à l'import
# pour que la face "avant" de chaque décor soit orientée +Y après normalisation.
# +Y = face visible quand rot_z=0, rot aléatoire tourne autour de cette base.
# 0       = déjà orienté +Y (colonnes, props symétriques)
# 1.5708  = +90°  (était face +X → corriger vers +Y)
# -1.5708 = -90°  (était face -X → corriger vers +Y)
# 3.14159 = 180°  (était face -Y → corriger vers +Y)
import math as _math
_DECOR_FACE_OFFSET_Z = {
    "decor_column":        0.0,
    "decor_bone_pile":     0.0,
    "decor_iron_cage":     0.0,
    "decor_flesh_pillar":  0.0,
    "decor_gargoyle":      0.0,
    "decor_gothic_panel":  0.0,
    "decor_broken_arch":   0.0,
    "decor_lava_crack":    0.0,
    "decor_altar":         0.0,
    "decor_ritual_circle": 0.0,
}
# Note : ajuste les valeurs ci-dessus après le premier test visuel dans Blender.
# Si la face est vers +X  → mettre -1.5708
# Si la face est vers -X  → mettre  1.5708
# Si la face est vers -Y  → mettre  3.14159



def _find_decor_asset_path(decor_root, name):
    """
    Supporte :
    - .../assets/decor/decor_name/decor_name.gltf
    - .../assets/decor/decor_name/decor_name.glb
    - .../assets/decor/decor_name.gltf
    - .../assets/decor/decor_name.glb
    """
    root = Path(decor_root)
    candidates = [
        root / name / f"{name}.gltf",
        root / name / f"{name}.glb",
        root / f"{name}.gltf",
        root / f"{name}.glb",
    ]
    for p in candidates:
        if p.exists():
            return p
    return None


def _import_decor_source(name, decor_folder, lib_col):
    """
    Importe une source de décor une seule fois, joint ses meshes,
    puis la déplace dans DECOR_LIBRARY masquée.
    Supporte les assets .gltf / .glb dans des sous-dossiers.
    """
    src_name = f"DECOR_SRC_{name}"
    existing = bpy.data.objects.get(src_name)
    if existing is not None:
        return existing

    asset_path = _find_decor_asset_path(decor_folder, name)
    if asset_path is None:
        return None

    bpy.ops.object.select_all(action='DESELECT')
    try:
        bpy.ops.import_scene.gltf(filepath=str(asset_path))
    except Exception:
        return None

    imported = list(bpy.context.selected_objects)
    mesh_objs = [o for o in imported if o.type == 'MESH']
    non_mesh = [o for o in imported if o.type != 'MESH']

    if not mesh_objs:
        for o in imported:
            if o.name in bpy.data.objects:
                bpy.data.objects.remove(o, do_unlink=True)
        return None

    bpy.ops.object.select_all(action='DESELECT')
    for o in mesh_objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = mesh_objs[0]
    if len(mesh_objs) > 1:
        bpy.ops.object.join()

    joined = bpy.context.active_object
    joined.name = src_name

    for o in non_mesh:
        if o.name in bpy.data.objects:
            bpy.data.objects.remove(o, do_unlink=True)

    # Étape 1 : bake la matrice world COMPLÈTE (4×4) sur les vertices
    # Corrige rotation + scale GLTF sans opérateur ni dépendance au contexte
    try:
        mat = joined.matrix_world.copy()
        for v in joined.data.vertices:
            v.co = mat @ v.co
        joined.location = Vector((0.0, 0.0, 0.0))
        joined.rotation_euler = (0.0, 0.0, 0.0)
        joined.scale = (1.0, 1.0, 1.0)
        joined.data.update()
    except Exception:
        joined.location = Vector((0.0, 0.0, 0.0))
        joined.rotation_euler = (0.0, 0.0, 0.0)
        joined.scale = (1.0, 1.0, 1.0)

    # Étape 2 : correction de l'orientation "face avant" → +Y
    # Applique une rotation Z sur les vertices pour que la face décorative
    # soit orientée +Y (convention Blender : face vers -Y en vue front/num1,
    # donc la face "active" en jeu est +Y quand rot_z=0).
    face_offset = _DECOR_FACE_OFFSET_Z.get(name, 0.0)
    if abs(face_offset) > 0.0001:
        try:
            cos_a = _math.cos(face_offset)
            sin_a = _math.sin(face_offset)
            for v in joined.data.vertices:
                x, y = v.co.x, v.co.y
                v.co.x = cos_a * x - sin_a * y
                v.co.y = sin_a * x + cos_a * y
            joined.data.update()
        except Exception:
            pass

    # Étape 3 : normaliser la hauteur et poser la BASE à Z local = 0
    # => origin (orange dot) à (0,0,0) = bas du mesh
    # => _place_decor_instance pose inst.location.z = 0 → sur le sol exactement
    target_h = _DECOR_TARGET_HEIGHT.get(name, 2.0)
    try:
        zs = [v.co.z for v in joined.data.vertices]
        min_z = min(zs)
        max_z = max(zs)
        actual_h = max_z - min_z
        sc = (target_h / actual_h) if actual_h > 0.0001 else 1.0
        for v in joined.data.vertices:
            v.co.x *= sc
            v.co.y *= sc
            v.co.z = (v.co.z - min_z) * sc   # base → Z=0, sommet → target_h
        joined.data.update()
    except Exception:
        pass

    joined.location = Vector((0.0, 0.0, 0.0))
    joined.rotation_euler = (0.0, 0.0, 0.0)
    joined.scale = (1.0, 1.0, 1.0)

    link_object_to_collection(joined, lib_col)
    joined.hide_viewport = True
    joined.hide_render = True
    joined["nh_type"] = "decor_source"
    joined["nh_decor_name"] = name
    return joined



def _place_decor_instance(src, location, rotation_z, scale, target_col, idx):
    """
    Crée un linked duplicate de src et le place dans target_col.
    Après _import_decor_source : vertices Z ∈ [0, target_h], origine à (0,0,0).
    => inst.location.z = location[2] pose la base exactement sur le sol.
    """
    inst = src.copy()
    inst.data = src.data
    inst.name = f"{src.name}_i{idx}"
    inst.rotation_euler = (0.0, 0.0, rotation_z)
    inst.scale = Vector((scale, scale, scale))
    inst.location = Vector(location)
    inst.hide_viewport = False
    inst.hide_render = False
    inst["nh_type"] = "decor"
    link_object_to_collection(inst, target_col)
    return inst



def build_decor_library(settings, root_col):
    """
    Importe toutes les sources de décor disponibles dans une collection cachée DECOR_LIBRARY.
    Retourne un dict {decor_name: source_object}.
    """
    lib_col = ensure_collection("DECOR_LIBRARY", root_col)

    def find_layer(lc, name):
        if lc.name == name:
            return lc
        for child in lc.children:
            r = find_layer(child, name)
            if r:
                return r
        return None

    try:
        lib_layer = find_layer(bpy.context.view_layer.layer_collection, "DECOR_LIBRARY")
        if lib_layer:
            lib_layer.exclude = True
    except Exception:
        pass

    decor_folder = bpy.path.abspath(settings.decor_folder)
    sources = {}
    all_decors = set()
    for pool in _DECOR_POOL.values():
        all_decors.update(pool)

    for name in sorted(all_decors):
        src = _import_decor_source(name, decor_folder, lib_col)
        if src is not None:
            sources[name] = src

    return sources



def place_decor_in_room(room, rnd, settings, root_col, decor_sources, global_placed,
                        entry_side=None):
    """
    Place des instances de décor de manière semi-procédurale dans une salle.

    entry_side : côté d'entrée du joueur dans la pièce ("N", "S", "E", "W" ou None).
    Quand entry_side est fourni, les décors sont biaisés vers l'AVANT de la pièce
    (moitié côté entrée → centre) et font face au joueur qui entre.
    decor_front_bias (0‒1) contrôle l'intensité du biais :
      0 = comportement v2.5.2 (aléatoire),
      1 = tous les décors dans la moitié avant, face à l'entrée.
    """
    room_type = room["type"]
    pool = [p for p in _DECOR_POOL.get(room_type, []) if p in decor_sources]
    if not pool:
        return

    cx, cy = room["center"].x, room["center"].y
    w, h = room["w"], room["h"]
    wall_margin = 1.6

    x_min = cx - w * 0.5 + wall_margin
    x_max = cx + w * 0.5 - wall_margin
    y_min = cy - h * 0.5 + wall_margin
    y_max = cy + h * 0.5 - wall_margin

    if x_max <= x_min or y_max <= y_min:
        return

    area = (x_max - x_min) * (y_max - y_min)
    n_target = max(1, int(area * settings.decor_density * 0.018))
    n_target = min(n_target, 8)

    room_col = bpy.data.collections.get(f"ROOM_{room['name']}")
    if room_col is None:
        return
    decor_col = ensure_collection(f"DECOR_{room['name']}", room_col)

    # Décors qui doivent faire face à l'entrée / au mur (directionnels)
    # Les autres (symétriques) gardent une rotation semi-libre
    _DIRECTIONAL = {
        "decor_gargoyle", "decor_gothic_panel", "decor_broken_arch",
        "decor_altar", "decor_iron_cage", "decor_flesh_pillar",
    }

    bias = getattr(settings, "decor_front_bias", 0.7)

    # ----------------------------------------------------------------
    # Calcul de la zone « avant » en fonction du côté d'entrée
    # L'avant = moitié de la pièce côté entrée, l'arrière = moitié opposée
    #
    # entry_side "S" → joueur vient du Sud → avant = zone Sud (y_min..cy)
    # entry_side "N" → avant = zone Nord  (cy..y_max)
    # entry_side "W" → avant = zone Ouest (x_min..cx)
    # entry_side "E" → avant = zone Est   (cx..x_max)
    # ----------------------------------------------------------------
    def front_range_x():
        """Retourne (x_low, x_high) de la zone avant selon entry_side."""
        if entry_side == "W":
            return x_min, cx
        if entry_side == "E":
            return cx, x_max
        return x_min, x_max   # N/S : pas de restriction en X

    def front_range_y():
        """Retourne (y_low, y_high) de la zone avant selon entry_side."""
        if entry_side == "S":
            return y_min, cy
        if entry_side == "N":
            return cy, y_max
        return y_min, y_max   # E/W : pas de restriction en Y

    def sample_front_position(radius):
        """
        Tire une position dans la zone avant.
        Si bias < 1, mélange stochastiquement avec la zone pleine.
        """
        use_front = (entry_side is not None) and (rnd.random() < bias)
        if use_front:
            fx_min, fx_max = front_range_x()
            fy_min, fy_max = front_range_y()
            px = rnd.uniform(
                min(fx_min + radius, fx_max),
                max(fx_min + radius, fx_max - radius),
            )
            py = rnd.uniform(
                min(fy_min + radius, fy_max),
                max(fy_min + radius, fy_max - radius),
            )
        else:
            px = rnd.uniform(x_min + radius, max(x_min + radius, x_max - radius))
            py = rnd.uniform(y_min + radius, max(y_min + radius, y_max - radius))
        return px, py

    # ----------------------------------------------------------------
    # Rotation : décors directionnels font face à l'entrée
    # Si pas d'entrée connue → face au centre
    # ----------------------------------------------------------------
    def rot_face_entry(px, py):
        """
        Retourne rot_z pour que le +Y du décor pointe VERS l'entrée
        (le joueur voit la face avant en entrant).
        Mapping :
          entry_side "S" → décor face au S (−Y world) → rot_z = π
          entry_side "N" → décor face au N (+Y world) → rot_z = 0
          entry_side "W" → décor face à W (−X world) → rot_z = π/2
          entry_side "E" → décor face à E (+X world) → rot_z = −π/2
        Fallback (pas d'entry) : face au centre de la pièce
        """
        if entry_side == "S":
            return _math.pi
        if entry_side == "N":
            return 0.0
        if entry_side == "W":
            return _math.pi / 2.0
        if entry_side == "E":
            return -_math.pi / 2.0
        # Fallback : face vers le centre
        dx = cx - px
        dy = cy - py
        return _math.atan2(dx, dy)   # atan2(x,y) → +Y = nord

    placed_here = []
    inst_idx = 0

    for _ in range(n_target * 16):
        if len(placed_here) >= n_target:
            break

        name = rnd.choice(pool)
        src = decor_sources[name]
        radius = _DECOR_RADIUS.get(name, 1.0)

        # --- Calcul de position ---
        if name == "decor_ritual_circle":
            # Toujours au centre
            px, py = cx, cy
        elif name in _DIRECTIONAL:
            # Décors directionnels : placés dans la zone avant, légèrement en retrait
            # (à mi-chemin entre l'entrée et le centre), pas contre un mur du fond
            if entry_side is not None and rnd.random() < bias:
                # Position dans la moitié avant, avec un décalage vers le centre
                fx_min, fx_max = front_range_x()
                fy_min, fy_max = front_range_y()
                inset = radius + 0.4

                if entry_side in {"N", "S"}:
                    # Variation latérale libre, profondeur dans la zone avant
                    px = rnd.uniform(
                        x_min + radius,
                        max(x_min + radius, x_max - radius),
                    )
                    raw_y_min = fy_min + inset
                    raw_y_max = fy_max - inset
                    if raw_y_max < raw_y_min:
                        raw_y_max = raw_y_min
                    py = rnd.uniform(raw_y_min, raw_y_max)
                else:
                    # Variation latérale libre en Y, profondeur dans la zone avant en X
                    py = rnd.uniform(
                        y_min + radius,
                        max(y_min + radius, y_max - radius),
                    )
                    raw_x_min = fx_min + inset
                    raw_x_max = fx_max - inset
                    if raw_x_max < raw_x_min:
                        raw_x_max = raw_x_min
                    px = rnd.uniform(raw_x_min, raw_x_max)
            else:
                # Comportement legacy : proche d'un mur aléatoire
                side = rnd.choice(["N", "S", "E", "W"])
                inset = radius + 0.3
                if side == "N":
                    px = rnd.uniform(x_min + radius, max(x_min + radius, x_max - radius))
                    py = cy + h * 0.5 - inset
                elif side == "S":
                    px = rnd.uniform(x_min + radius, max(x_min + radius, x_max - radius))
                    py = cy - h * 0.5 + inset
                elif side == "E":
                    px = cx + w * 0.5 - inset
                    py = rnd.uniform(y_min + radius, max(y_min + radius, y_max - radius))
                else:
                    px = cx - w * 0.5 + inset
                    py = rnd.uniform(y_min + radius, max(y_min + radius, y_max - radius))
        else:
            # Décors symétriques : biaisés vers l'avant
            px, py = sample_front_position(radius)

        # --- Vérification de distance ---
        too_close = False
        for (ex, ey, er) in placed_here + global_placed:
            if ((px - ex) ** 2 + (py - ey) ** 2) < (radius + er + 0.4) ** 2:
                too_close = True
                break
        if too_close:
            continue

        # --- Calcul de rotation ---
        if name in _DIRECTIONAL:
            # Face vers l'entrée (ou vers le mur le plus proche si pas d'entrée)
            if entry_side is not None:
                rot_z = rot_face_entry(px, py)
                # Légère variation angulaire pour éviter un alignement trop parfait
                rot_z += rnd.uniform(-0.25, 0.25)
            else:
                # Legacy : face au mur le plus proche
                dist_n = (cy + h * 0.5) - py
                dist_s = py - (cy - h * 0.5)
                dist_e = (cx + w * 0.5) - px
                dist_w = px - (cx - w * 0.5)
                nearest = min(dist_n, dist_s, dist_e, dist_w)
                if nearest == dist_n:
                    rot_z = 0.0
                elif nearest == dist_s:
                    rot_z = _math.pi
                elif nearest == dist_e:
                    rot_z = -_math.pi / 2.0
                else:
                    rot_z = _math.pi / 2.0
        else:
            # Décors symétriques : rotation libre mais légèrement biaisée vers l'entrée
            if entry_side is not None and rnd.random() < bias * 0.5:
                rot_z = rot_face_entry(px, py) + rnd.uniform(-_math.pi * 0.4, _math.pi * 0.4)
            else:
                rot_z = rnd.uniform(0.0, _math.pi * 2.0)

        s_min, s_max = _DECOR_SCALE.get(name, (0.8, 1.1))
        scale = rnd.uniform(s_min, s_max)

        inst = _place_decor_instance(src, (px, py, 0.0), rot_z, scale, decor_col, inst_idx)
        inst["nh_decor_name"] = name

        placed_here.append((px, py, radius))
        inst_idx += 1

    global_placed.extend(placed_here)


# ------------------------------------------------------------
# Generation / operators / UI
# ------------------------------------------------------------

def create_level(settings):
    root = ensure_collection("NEUROHELL_LEVEL")
    if settings.clear_previous:
        clear_collection(root)

    mats = build_material_library(settings)
    rooms, corridors = generate_room_layout(settings)

    opening_specs = {room["name"]: [] for room in rooms}
    for c in corridors:
        opening_specs[c["a"]["name"]].append({"side": c["exit_side_a"], "point": c["exit_point_a"]})
        opening_specs[c["b"]["name"]].append({"side": c["entry_side_b"], "point": c["entry_point_b"]})

    for room in rooms:
        build_room(room, opening_specs[room["name"]], root, mats, settings)
    for corridor in corridors:
        build_corridor(corridor, root, mats, settings)

    # Decor placement (v2.5.3 — front-biased)
    if settings.place_decor:
        decor_sources = build_decor_library(settings, root)
        if decor_sources:
            rnd = random.Random(settings.seed + 1000)
            global_placed = []

            # Reconstruit la correspondance salle → côté d'entrée du joueur
            # (premier corridor dont la salle est la destination → entry_side_b)
            room_entry_side = {}
            for c in corridors:
                # La salle B est atteinte par le côté entry_side_b
                b_name = c["b"]["name"]
                if b_name not in room_entry_side:   # garde le premier corridor (chemin principal)
                    room_entry_side[b_name] = c["entry_side_b"]

            for room in rooms:
                entry_side = room_entry_side.get(room["name"])   # None pour le spawn
                place_decor_in_room(
                    room, rnd, settings, root, decor_sources, global_placed,
                    entry_side=entry_side,
                )

    bpy.context.scene["nh_last_seed"] = settings.seed


class NH_LevelSettings(PropertyGroup):
    seed: IntProperty(name="Seed", default=42, min=0)
    clear_previous: BoolProperty(name="Effacer l'ancien niveau", default=True)

    layout_style: EnumProperty(
        name="Style",
        items=[
            ('LINEAR', 'Linéaire', ''),
            ('ZIGZAG', 'Zigzag', ''),
            ('MIXED', 'Mixte', ''),
        ],
        default='ZIGZAG'
    )

    room_count: IntProperty(name="Salles totales", default=5, min=3, max=14)
    room_min_size: FloatProperty(name="Taille min pièce", default=8.0, min=4.0)
    room_max_size: FloatProperty(name="Taille max pièce", default=14.0, min=6.0)
    room_spacing_min: FloatProperty(name="Espacement min", default=14.0, min=8.0)
    room_spacing_max: FloatProperty(name="Espacement max", default=22.0, min=10.0)
    room_margin: FloatProperty(name="Marge anti-chevauchement", default=2.5, min=0.0)

    spawn_width: FloatProperty(name="Largeur spawn", default=12.0, min=6.0)
    spawn_height: FloatProperty(name="Profondeur spawn", default=10.0, min=6.0)
    final_width: FloatProperty(name="Largeur salle finale", default=16.0, min=8.0)
    final_height: FloatProperty(name="Profondeur salle finale", default=14.0, min=8.0)

    corridor_width: FloatProperty(name="Largeur couloir", default=4.0, min=2.0)
    wall_height: FloatProperty(name="Hauteur murs", default=5.0, min=2.5)
    wall_thickness: FloatProperty(name="Epaisseur murs", default=0.4, min=0.1)
    floor_thickness: FloatProperty(name="Epaisseur sol", default=0.3, min=0.05)

    door_height: FloatProperty(name="Hauteur porte", default=3.2, min=2.0)
    door_bottom: FloatProperty(name="Bas de porte", default=0.0, min=0.0)

    include_arena: BoolProperty(name="Créer une première arène", default=True)
    create_windows: BoolProperty(name="Créer des fenêtres", default=True)
    windows_on_rooms: BoolProperty(name="Fenêtres sur pièces simples", default=False)
    window_bottom: FloatProperty(name="Hauteur bas fenêtre", default=1.3, min=0.0)
    window_height: FloatProperty(name="Hauteur fenêtre", default=2.0, min=0.5)

    place_weapon_marker: BoolProperty(name="Placer un marker d'arme", default=True)
    place_gargoyle_markers: BoolProperty(name="Markers gargouille", default=False)

    use_game_textures: BoolProperty(name="Utiliser les textures du jeu", default=True)
    game_root_folder: StringProperty(name="Dossier du jeu", default=r"G:\NeuroHell", subtype='DIR_PATH')
    wall_texture_set: StringProperty(name="Texture mur", default="hell_wall")
    floor_texture_set: StringProperty(name="Texture sol", default="hell_floor")
    lava_texture_set: StringProperty(name="Texture lave", default="lava")
    metal_texture_set: StringProperty(name="Texture métal", default="tech_metal")
    gothic_texture_set: StringProperty(name="Texture gothique", default="gothic_metal")
    texture_scale: FloatProperty(name="Échelle texture", default=0.5, min=0.05, max=5.0)

    # --- v2.5 : décor ---
    place_decor: BoolProperty(
        name="Placer les décors",
        description="Importe et place aléatoirement les GLB de décor dans chaque salle",
        default=True,
    )
    decor_folder: StringProperty(
        name="Dossier décors",
        description="Dossier racine contenant les sous-dossiers decor_* avec .gltf/.glb",
        default=r"G:\NeuroHell\assets\decor",
        subtype='DIR_PATH',
    )
    decor_density: FloatProperty(
        name="Densité décors",
        description="Contrôle le nombre de décors par salle (0 = minimal, 1 = dense)",
        default=0.5,
        min=0.0,
        max=1.0,
    )
    decor_front_bias: FloatProperty(
        name="Biais avant",
        description=(
            "Probabilité que les décors soient placés dans la moitié avant de la pièce "
            "(côté entrée → centre) et fassent face au joueur entrant. "
            "0 = comportement entièrement aléatoire, 1 = toujours à l'avant."
        ),
        default=0.75,
        min=0.0,
        max=1.0,
    )


class NH_OT_generate_level(Operator):
    bl_idname = "nh.generate_level"
    bl_label = "Générer le niveau"
    bl_options = {'REGISTER', 'UNDO'}

    def execute(self, context):
        create_level(context.scene.nh_level_settings)
        self.report({'INFO'}, "Niveau généré")
        return {'FINISHED'}


class NH_OT_regenerate_seed(Operator):
    bl_idname = "nh.regenerate_seed"
    bl_label = "Nouvelle seed"
    bl_options = {'REGISTER', 'UNDO'}

    def execute(self, context):
        s = context.scene.nh_level_settings
        s.seed = random.randint(0, 999999)
        create_level(s)
        self.report({'INFO'}, f"Niveau régénéré avec seed {s.seed}")
        return {'FINISHED'}


class NH_OT_reload_materials(Operator):
    bl_idname = "nh.reload_materials"
    bl_label = "Recharger les matériaux"
    bl_options = {'REGISTER', 'UNDO'}

    def execute(self, context):
        build_material_library(context.scene.nh_level_settings)
        self.report({'INFO'}, "Matériaux rechargés")
        return {'FINISHED'}


class NH_OT_export_glb(Operator):
    bl_idname = "nh.export_glb"
    bl_label = "Exporter en GLB"

    filepath: bpy.props.StringProperty(subtype='FILE_PATH')

    def execute(self, context):
        root = bpy.data.collections.get("NEUROHELL_LEVEL")
        if root is None or not root.all_objects:
            self.report({'ERROR'}, "Aucun niveau à exporter")
            return {'CANCELLED'}

        bpy.ops.object.select_all(action='DESELECT')
        for obj in root.all_objects:
            # Skip hidden library sources
            if obj.get("nh_type") == "decor_source":
                continue
            obj.select_set(True)
            context.view_layer.objects.active = obj

        bpy.ops.export_scene.gltf(
            filepath=self.filepath,
            export_format='GLB',
            use_selection=True,
            export_apply=True,
            export_extras=True,
        )
        self.report({'INFO'}, f"Export GLB terminé: {self.filepath}")
        return {'FINISHED'}

    def invoke(self, context, event):
        self.filepath = "//neurohell_level.glb"
        context.window_manager.fileselect_add(self)
        return {'RUNNING_MODAL'}


class NH_PT_level_panel(Panel):
    bl_label = "NeuroHell Level"
    bl_idname = "NH_PT_level_panel"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = 'NeuroHell'

    def draw(self, context):
        layout = self.layout
        s = context.scene.nh_level_settings

        box = layout.box()
        box.label(text="Génération")
        box.prop(s, "seed")
        box.prop(s, "clear_previous")
        box.prop(s, "layout_style")
        box.operator("nh.generate_level", icon='MOD_BUILD')
        box.operator("nh.regenerate_seed", icon='FILE_REFRESH')

        box = layout.box()
        box.label(text="Pièces")
        box.prop(s, "room_count")
        box.prop(s, "room_min_size")
        box.prop(s, "room_max_size")
        box.prop(s, "room_spacing_min")
        box.prop(s, "room_spacing_max")
        box.prop(s, "room_margin")
        box.prop(s, "spawn_width")
        box.prop(s, "spawn_height")
        box.prop(s, "final_width")
        box.prop(s, "final_height")

        box = layout.box()
        box.label(text="Volumes")
        box.prop(s, "corridor_width")
        box.prop(s, "wall_height")
        box.prop(s, "wall_thickness")
        box.prop(s, "floor_thickness")
        box.prop(s, "include_arena")

        box = layout.box()
        box.label(text="Fenêtres / statues")
        box.prop(s, "create_windows")
        box.prop(s, "windows_on_rooms")
        box.prop(s, "window_bottom")
        box.prop(s, "window_height")
        box.prop(s, "place_gargoyle_markers")

        box = layout.box()
        box.label(text="Gameplay")
        box.prop(s, "place_weapon_marker")

        box = layout.box()
        box.label(text="Décors (v2.5.3)")
        box.prop(s, "place_decor")
        if s.place_decor:
            box.prop(s, "decor_folder")
            box.prop(s, "decor_density", slider=True)
            box.prop(s, "decor_front_bias", slider=True)

        box = layout.box()
        box.label(text="Textures du jeu")
        box.prop(s, "use_game_textures")
        box.prop(s, "game_root_folder")
        box.prop(s, "wall_texture_set")
        box.prop(s, "floor_texture_set")
        box.prop(s, "lava_texture_set")
        box.prop(s, "metal_texture_set")
        box.prop(s, "gothic_texture_set")
        box.prop(s, "texture_scale")
        box.operator("nh.reload_materials", icon='SHADING_RENDERED')

        layout.separator()
        layout.operator("nh.export_glb", icon='EXPORT')


classes = (
    NH_LevelSettings,
    NH_OT_generate_level,
    NH_OT_regenerate_seed,
    NH_OT_reload_materials,
    NH_OT_export_glb,
    NH_PT_level_panel,
)


def register():
    for cls in classes:
        bpy.utils.register_class(cls)
    bpy.types.Scene.nh_level_settings = PointerProperty(type=NH_LevelSettings)


def unregister():
    del bpy.types.Scene.nh_level_settings
    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)


if __name__ == "__main__":
    register()
