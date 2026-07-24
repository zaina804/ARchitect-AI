"""
Blender Headless Building Generator
------------------------------------
Reads two JSON files and builds a 3D structure exported as .glb for Unity.

Inputs:
  cv_result   → blender_result.json  (land boundary coordinates from YOLO)
  nlp_result  → nlp_output.json      (building type + user preferences from NLP)

Output:
  building.glb  → sent to Unity for 360° visualization in the mobile app

Run headlessly (no Blender window):
  blender --background --python blender_build.py -- \
      --cv    path/to/blender_result.json \
      --nlp   path/to/nlp_output.json \
      --output path/to/building.glb

IMPORTANT: This script must be run through Blender, not plain Python.
  Install Blender: https://www.blender.org/download/
  Server (Linux):  apt install blender  OR  download portable .tar.xz
"""

import bpy
import bmesh
import json
import sys
import os
import argparse
import math


# ── Helpers ───────────────────────────────────────────────────────────────────

def parse_args():
    """Parse args after the '--' separator Blender uses for custom args."""
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []

    parser = argparse.ArgumentParser()
    parser.add_argument("--cv",     required=True, help="Path to blender_result.json (CV output)")
    parser.add_argument("--nlp",    required=True, help="Path to nlp_output.json (NLP output)")
    parser.add_argument("--output", required=True, help="Output .glb file path")
    return parser.parse_args(argv)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for col in bpy.data.collections:
        bpy.data.collections.remove(col)


def pixels_to_blender(px, py, img_w, img_h, scale=0.01):
    """
    Convert pixel coordinates to Blender world units.
    scale=0.01 → 1 pixel = 0.01m  (100px = 1m)
    Origin is centered on the land boundary.
    """
    x = (px - img_w / 2) * scale
    y = (py - img_h / 2) * scale
    return x, -y   # flip Y axis (image Y goes down, Blender Y goes up)


# ── Material helpers ──────────────────────────────────────────────────────────

def make_material(name, r, g, b, a=1.0, roughness=0.5, metallic=0.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (r, g, b, a)
    bsdf.inputs["Roughness"].default_value  = roughness
    bsdf.inputs["Metallic"].default_value   = metallic
    return mat


def assign_material(obj, mat):
    if obj.data.materials:
        obj.data.materials[0] = mat
    else:
        obj.data.materials.append(mat)


# ── Primitive builders ────────────────────────────────────────────────────────

def add_box(name, location, scale, material=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    if material:
        assign_material(obj, material)
    return obj


def add_cylinder(name, location, radius, depth, material=None):
    bpy.ops.mesh.primitive_cylinder_add(
        radius=radius, depth=depth,
        location=location, vertices=32
    )
    obj = bpy.context.active_object
    obj.name = name
    if material:
        assign_material(obj, material)
    return obj


# ── Building type generators ──────────────────────────────────────────────────

FLOOR_HEIGHT = 3.0   # metres per floor


def build_house(land_w, land_h, floors, mat_wall, mat_roof, mat_window):
    objects = []

    # Body
    body_h = floors * FLOOR_HEIGHT
    objects.append(add_box(
        "House_Body",
        location=(0, 0, body_h / 2),
        scale=(land_w, land_h, body_h),
        material=mat_wall
    ))

    # Pitched roof
    roof_h = land_w * 0.4
    bpy.ops.mesh.primitive_cone_add(
        vertices=4, radius1=math.sqrt(2) * (land_w / 2 + 0.3),
        depth=roof_h,
        location=(0, 0, body_h + roof_h / 2),
        rotation=(0, 0, math.radians(45))
    )
    roof = bpy.context.active_object
    roof.name = "House_Roof"
    assign_material(roof, mat_roof)
    objects.append(roof)

    # Windows (front face)
    win_w, win_h = 0.8, 1.0
    win_depth = 0.05
    for floor in range(floors):
        z = floor * FLOOR_HEIGHT + FLOOR_HEIGHT * 0.5
        for x_offset in [-land_w * 0.25, land_w * 0.25]:
            objects.append(add_box(
                f"Window_F{floor}_{x_offset:.1f}",
                location=(x_offset, land_h / 2 + win_depth / 2, z),
                scale=(win_w, win_depth, win_h),
                material=mat_window
            ))

    # Door
    objects.append(add_box(
        "Door",
        location=(0, land_h / 2 + 0.05, 1.0),
        scale=(1.0, 0.1, 2.0),
        material=make_material("Door_Mat", 0.4, 0.2, 0.1)
    ))

    return objects


def build_school(land_w, land_h, floors, mat_wall, mat_roof, mat_window):
    objects = []
    body_h = floors * FLOOR_HEIGHT

    # Main block
    objects.append(add_box(
        "School_Main",
        location=(0, 0, body_h / 2),
        scale=(land_w, land_h, body_h),
        material=mat_wall
    ))

    # Flat roof with parapet
    objects.append(add_box(
        "School_Roof",
        location=(0, 0, body_h + 0.15),
        scale=(land_w + 0.3, land_h + 0.3, 0.3),
        material=mat_roof
    ))

    # Windows — rows per floor
    win_w, win_h = 1.0, 1.2
    cols = max(2, int(land_w / 2.5))
    for floor in range(floors):
        z = floor * FLOOR_HEIGHT + FLOOR_HEIGHT * 0.55
        for col in range(cols):
            x = -land_w / 2 + (land_w / (cols + 1)) * (col + 1)
            objects.append(add_box(
                f"Win_{floor}_{col}",
                location=(x, land_h / 2 + 0.05, z),
                scale=(win_w, 0.1, win_h),
                material=mat_window
            ))

    # Entrance canopy
    objects.append(add_box(
        "Canopy",
        location=(0, land_h / 2 + 1.0, FLOOR_HEIGHT * 0.85),
        scale=(4.0, 2.0, 0.2),
        material=mat_roof
    ))

    # Double door
    for dx in [-0.6, 0.6]:
        objects.append(add_box(
            f"Door_{dx}",
            location=(dx, land_h / 2 + 0.05, 1.1),
            scale=(0.9, 0.1, 2.2),
            material=make_material("Door_School", 0.15, 0.3, 0.5)
        ))

    return objects


def build_hospital(land_w, land_h, floors, mat_wall, mat_roof, mat_window):
    objects = []
    body_h = floors * FLOOR_HEIGHT

    # Main building
    objects.append(add_box(
        "Hospital_Main",
        location=(0, 0, body_h / 2),
        scale=(land_w, land_h, body_h),
        material=mat_wall
    ))

    # Flat roof
    objects.append(add_box(
        "Hospital_Roof",
        location=(0, 0, body_h + 0.2),
        scale=(land_w + 0.4, land_h + 0.4, 0.4),
        material=mat_roof
    ))

    # Red cross on front face
    cross_mat = make_material("Cross", 0.9, 0.1, 0.1)
    objects.append(add_box("Cross_H", location=(0, land_h / 2 + 0.1, body_h * 0.75),
                           scale=(2.0, 0.1, 0.5), material=cross_mat))
    objects.append(add_box("Cross_V", location=(0, land_h / 2 + 0.1, body_h * 0.75),
                           scale=(0.5, 0.1, 2.0), material=cross_mat))

    # Windows
    cols = max(3, int(land_w / 2.0))
    for floor in range(floors):
        z = floor * FLOOR_HEIGHT + FLOOR_HEIGHT * 0.5
        for col in range(cols):
            x = -land_w / 2 + (land_w / (cols + 1)) * (col + 1)
            objects.append(add_box(
                f"Win_{floor}_{col}",
                location=(x, land_h / 2 + 0.05, z),
                scale=(0.9, 0.1, 1.1),
                material=mat_window
            ))

    # Entrance
    objects.append(add_box(
        "Entrance",
        location=(0, land_h / 2 + 0.05, 1.1),
        scale=(2.5, 0.1, 2.2),
        material=make_material("EntranceDoor", 0.6, 0.8, 0.9, metallic=0.3)
    ))

    return objects


def build_mosque(land_w, land_h, floors, mat_wall, mat_roof, mat_window):
    objects = []
    body_h = max(floors * FLOOR_HEIGHT, 6.0)

    # Main hall
    objects.append(add_box(
        "Mosque_Hall",
        location=(0, 0, body_h / 2),
        scale=(land_w, land_h, body_h),
        material=mat_wall
    ))

    # Central dome
    dome_r = min(land_w, land_h) * 0.3
    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=dome_r, location=(0, 0, body_h + dome_r * 0.6),
        segments=32, ring_count=16
    )
    dome = bpy.context.active_object
    dome.name  = "Dome"
    dome.scale = (1.0, 1.0, 0.7)
    bpy.ops.object.transform_apply(scale=True)
    assign_material(dome, mat_roof)
    objects.append(dome)

    # Minarets (4 corners)
    minaret_h = body_h * 1.4
    minaret_r = 0.5
    corners = [
        ( land_w / 2 - 0.5,  land_h / 2 - 0.5),
        (-land_w / 2 + 0.5,  land_h / 2 - 0.5),
        ( land_w / 2 - 0.5, -land_h / 2 + 0.5),
        (-land_w / 2 + 0.5, -land_h / 2 + 0.5),
    ]
    for i, (cx, cy) in enumerate(corners):
        objects.append(add_cylinder(
            f"Minaret_{i}",
            location=(cx, cy, minaret_h / 2),
            radius=minaret_r,
            depth=minaret_h,
            material=mat_wall
        ))
        # Minaret tip
        bpy.ops.mesh.primitive_cone_add(
            radius1=minaret_r + 0.1, depth=1.5,
            location=(cx, cy, minaret_h + 0.75)
        )
        tip = bpy.context.active_object
        tip.name = f"Minaret_Tip_{i}"
        assign_material(tip, mat_roof)
        objects.append(tip)

    return objects


def build_generic(land_w, land_h, floors, mat_wall, mat_roof, mat_window):
    """Fallback: simple multi-floor block building."""
    objects = []
    body_h = floors * FLOOR_HEIGHT

    objects.append(add_box(
        "Building_Body",
        location=(0, 0, body_h / 2),
        scale=(land_w, land_h, body_h),
        material=mat_wall
    ))
    objects.append(add_box(
        "Building_Roof",
        location=(0, 0, body_h + 0.25),
        scale=(land_w + 0.3, land_h + 0.3, 0.5),
        material=mat_roof
    ))

    cols = max(2, int(land_w / 2.5))
    for floor in range(floors):
        z = floor * FLOOR_HEIGHT + FLOOR_HEIGHT * 0.5
        for col in range(cols):
            x = -land_w / 2 + (land_w / (cols + 1)) * (col + 1)
            objects.append(add_box(
                f"Win_{floor}_{col}",
                location=(x, land_h / 2 + 0.05, z),
                scale=(0.8, 0.1, 1.0),
                material=mat_window
            ))

    return objects


BUILDERS = {
    "house":    build_house,
    "school":   build_school,
    "hospital": build_hospital,
    "mosque":   build_mosque,
}

# Wall color per building type
WALL_COLORS = {
    "house":    (0.95, 0.88, 0.76),
    "school":   (0.85, 0.90, 0.95),
    "hospital": (0.98, 0.98, 0.98),
    "mosque":   (0.96, 0.93, 0.85),
}


# ── Ground plane ──────────────────────────────────────────────────────────────

def add_ground(land_w, land_h):
    bpy.ops.mesh.primitive_plane_add(
        size=1,
        location=(0, 0, 0)
    )
    ground = bpy.context.active_object
    ground.name  = "Ground"
    ground.scale = (land_w + 2, land_h + 2, 1)
    bpy.ops.object.transform_apply(scale=True)
    assign_material(ground, make_material("Ground_Mat", 0.3, 0.55, 0.25, roughness=0.9))
    return ground


# ── Lighting & camera ─────────────────────────────────────────────────────────

def setup_scene(land_w, land_h, floors):
    body_h = floors * FLOOR_HEIGHT

    # Sun light
    bpy.ops.object.light_add(type="SUN", location=(10, -10, 20))
    sun = bpy.context.active_object
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(45), 0, math.radians(30))

    # Ambient (area light)
    bpy.ops.object.light_add(type="AREA", location=(0, 0, body_h * 2))
    area = bpy.context.active_object
    area.data.energy = 500
    area.data.size   = max(land_w, land_h) * 2

    # Camera
    cam_dist = max(land_w, land_h) * 3
    bpy.ops.object.camera_add(
        location=(cam_dist, -cam_dist, body_h + cam_dist * 0.5)
    )
    cam = bpy.context.active_object
    cam.name = "Camera"
    bpy.context.scene.camera = cam

    # Point camera at origin
    constraint = cam.constraints.new(type="TRACK_TO")
    bpy.ops.object.empty_add(location=(0, 0, body_h / 2))
    target = bpy.context.active_object
    target.name = "CameraTarget"
    constraint.target    = target
    constraint.track_axis = "TRACK_NEGATIVE_Z"
    constraint.up_axis    = "UP_Y"


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    args = parse_args()

    # Load JSONs
    with open(args.cv,  "r") as f:
        cv_data  = json.load(f)
    with open(args.nlp, "r") as f:
        nlp_data = json.load(f)

    # ── Extract CV data ───────────────────────────────────────────────────────
    img_w = cv_data.get("image_width",  1000)
    img_h = cv_data.get("image_height", 1000)

    boundaries = cv_data.get("boundaries", [])
    if not boundaries:
        print("ERROR: No land boundaries found in CV JSON. Cannot build.")
        sys.exit(1)

    # Use the highest-confidence boundary
    boundary = max(boundaries, key=lambda b: b["confidence"])
    px = boundary["pixel"]
    land_px_w = px["width"]
    land_px_h = px["height"]
    cx_px     = px["center_x"]
    cy_px     = px["center_y"]

    # Convert to Blender units (1 pixel = 0.01m)
    SCALE    = 0.01
    land_w   = land_px_w * SCALE
    land_h   = land_px_h * SCALE
    center_x, center_y = pixels_to_blender(cx_px, cy_px, img_w, img_h, SCALE)

    # ── Extract NLP data ──────────────────────────────────────────────────────
    build_type = nlp_data.get("build_type", "generic").lower().strip()
    floors     = max(1, int(nlp_data.get("floors", 1)))

    print(f"Building type : {build_type}")
    print(f"Floors        : {floors}")
    print(f"Land size     : {land_w:.2f}m × {land_h:.2f}m")
    print(f"Land center   : ({center_x:.2f}, {center_y:.2f})")

    # ── Build scene ───────────────────────────────────────────────────────────
    clear_scene()

    # Materials
    wall_rgb = WALL_COLORS.get(build_type, (0.85, 0.82, 0.78))
    mat_wall   = make_material("Wall",   *wall_rgb, roughness=0.7)
    mat_roof   = make_material("Roof",   0.35, 0.32, 0.30, roughness=0.6)
    mat_window = make_material("Window", 0.55, 0.75, 0.95, roughness=0.05, metallic=0.1)

    add_ground(land_w, land_h)

    builder = BUILDERS.get(build_type, build_generic)
    builder(land_w, land_h, floors, mat_wall, mat_roof, mat_window)

    # Move everything to the land center
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            obj.location.x += center_x
            obj.location.y += center_y

    setup_scene(land_w, land_h, floors)

    # ── Export GLB ────────────────────────────────────────────────────────────
    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)

    bpy.ops.export_scene.gltf(
        filepath=args.output,
        export_format="GLB",
        export_materials="EXPORT",
        export_cameras=True,
        export_lights=True,
        use_selection=False
    )

    print(f"\nExported → {args.output}")


main()
