"""
blender_kittyraiser_extras.py

Generates the 9 NEW low-poly OBJ meshes referenced in AssetIds.lua but not yet
uploaded:
    cop_car, streetlamp, park_bench, oak_tree, palm_tree, donut, coffee,
    manhole, fire_truck.

HOW TO RUN:
    /Applications/Blender.app/Contents/MacOS/Blender --background \\
        --python blender_kittyraiser_extras.py
    # Or open Blender, paste into Scripting workspace, Alt+P.

OUTPUT: ~/Desktop/kittyraiser_extra_meshes/<name>.obj

NEXT STEP after running:
    python3 open_cloud_upload.py meshes ~/Desktop/kittyraiser_extra_meshes
    # paste returned IDs into src/ReplicatedStorage/Modules/AssetIds.lua

Style: low-poly, smooth-shaded, single material per object. Roblox imports OBJ
as MeshPart; we tint via .Color in Lua so geometry is colorless here.
"""

import bpy, bmesh, math, os

OUT = os.path.expanduser("~/Desktop/kittyraiser_extra_meshes")
os.makedirs(OUT, exist_ok=True)


def reset():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()


def smooth(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = True


def export(name):
    bpy.ops.object.select_all(action='DESELECT')
    obj = bpy.context.scene.objects[-1] if bpy.context.scene.objects else None
    if obj is None:
        return
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    smooth(obj)
    bpy.ops.wm.obj_export(
        filepath=os.path.join(OUT, f"{name}.obj"),
        export_selected_objects=True,
        export_uv=True, export_normals=True, export_materials=False,
        forward_axis='NEGATIVE_Z', up_axis='Y',
    )
    print(f"[export] {name}")


def join_and_export(name):
    bpy.ops.object.select_all(action='SELECT')
    if len(bpy.context.selected_objects) > 1:
        bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
        bpy.ops.object.join()
    export(name)


# ----- 1. COP CAR (police squad car) -----
def build_cop_car():
    reset()
    # Main body
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.5))
    body = bpy.context.active_object
    body.scale = (1.0, 2.4, 0.6)
    bpy.ops.object.transform_apply(scale=True)
    # Roof / cabin
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.2, 1.1))
    cabin = bpy.context.active_object
    cabin.scale = (0.85, 1.4, 0.5)
    bpy.ops.object.transform_apply(scale=True)
    # Light bar on top
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.2, 1.5))
    bar = bpy.context.active_object
    bar.scale = (0.7, 0.6, 0.15)
    bpy.ops.object.transform_apply(scale=True)
    # Wheels
    for x in (-0.55, 0.55):
        for y in (-1.1, 1.1):
            bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.3, depth=0.25,
                                                rotation=(math.radians(90), 0, 0),
                                                location=(x, y, 0.25))
    join_and_export("cop_car")


# ----- 2. STREETLAMP -----
def build_streetlamp():
    reset()
    # Pole
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.12, depth=4.5, location=(0, 0, 2.25))
    # Crossbar
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.06, depth=1.0,
                                        rotation=(0, math.radians(90), 0),
                                        location=(0.5, 0, 4.2))
    # Lamp head
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.35,
                                         location=(1.0, 0, 4.0))
    # Base
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.25, depth=0.3, location=(0, 0, 0.15))
    join_and_export("streetlamp")


# ----- 3. PARK BENCH -----
def build_park_bench():
    reset()
    # Seat
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.6))
    s = bpy.context.active_object; s.scale = (3.0, 0.6, 0.1)
    bpy.ops.object.transform_apply(scale=True)
    # Backrest
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.25, 1.0))
    b = bpy.context.active_object; b.scale = (3.0, 0.1, 0.7)
    bpy.ops.object.transform_apply(scale=True)
    # Legs (4)
    for x in (-1.3, 1.3):
        for y in (-0.25, 0.25):
            bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, 0.3))
            leg = bpy.context.active_object; leg.scale = (0.12, 0.12, 0.6)
            bpy.ops.object.transform_apply(scale=True)
    join_and_export("park_bench")


# ----- 4. OAK TREE -----
def build_oak_tree():
    reset()
    # Trunk
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.3, depth=2.4, location=(0, 0, 1.2))
    # Crown (multiple overlapping spheres for organic look)
    for off in [(0, 0, 2.4), (0.6, 0, 2.6), (-0.5, 0.3, 2.7), (0.2, -0.4, 2.5)]:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.85, location=off)
    join_and_export("oak_tree")


# ----- 5. PALM TREE -----
def build_palm_tree():
    reset()
    # Curved trunk: 3 stacked tapered cylinders with slight tilt
    bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=0.32, radius2=0.22, depth=1.5, location=(0, 0, 0.75))
    bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=0.22, radius2=0.16, depth=1.5, location=(0.15, 0, 2.2))
    bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=0.16, radius2=0.12, depth=1.5, location=(0.3, 0, 3.6))
    # Fronds (5 cones radiating from top)
    top = (0.4, 0, 4.3)
    for i in range(5):
        ang = i * (2 * math.pi / 5)
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.18, radius2=0,
                                        depth=2.2,
                                        rotation=(math.radians(85), ang, 0),
                                        location=(top[0] + math.cos(ang) * 0.9,
                                                  top[1] + math.sin(ang) * 0.9,
                                                  top[2] - 0.3))
    join_and_export("palm_tree")


# ----- 6. DONUT (torus) -----
def build_donut():
    reset()
    bpy.ops.mesh.primitive_torus_add(major_radius=0.5, minor_radius=0.18,
                                     major_segments=20, minor_segments=10,
                                     location=(0, 0, 0.18))
    join_and_export("donut")


# ----- 7. COFFEE CUP -----
def build_coffee():
    reset()
    # Cup body
    bpy.ops.mesh.primitive_cone_add(vertices=14, radius1=0.32, radius2=0.4, depth=1.0, location=(0, 0, 0.5))
    # Lid
    bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=0.42, depth=0.08, location=(0, 0, 1.04))
    # Lid bump
    bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=0.12, radius2=0.04, depth=0.16, location=(0, 0, 1.16))
    join_and_export("coffee")


# ----- 8. MANHOLE COVER -----
def build_manhole():
    reset()
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=1.0, depth=0.08, location=(0, 0, 0.04))
    join_and_export("manhole")


# ----- 9. FIRE TRUCK -----
def build_fire_truck():
    reset()
    # Cabin
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 1.8, 1.2))
    c = bpy.context.active_object; c.scale = (1.4, 1.4, 1.5)
    bpy.ops.object.transform_apply(scale=True)
    # Tank / rear body
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.6, 1.0))
    t = bpy.context.active_object; t.scale = (1.4, 3.0, 1.3)
    bpy.ops.object.transform_apply(scale=True)
    # Light bar
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 1.8, 2.1))
    bb = bpy.context.active_object; bb.scale = (1.0, 0.8, 0.15)
    bpy.ops.object.transform_apply(scale=True)
    # Ladder (long thin top piece)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.4, 1.85))
    lad = bpy.context.active_object; lad.scale = (0.3, 4.0, 0.1)
    bpy.ops.object.transform_apply(scale=True)
    # Wheels
    for x in (-0.85, 0.85):
        for y in (-1.6, 1.5):
            bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.45, depth=0.3,
                                                rotation=(math.radians(90), 0, 0),
                                                location=(x, y, 0.45))
    join_and_export("fire_truck")


# ----- RUN ALL -----
build_cop_car()
build_streetlamp()
build_park_bench()
build_oak_tree()
build_palm_tree()
build_donut()
build_coffee()
build_manhole()
build_fire_truck()

print(f"\n[blender_kittyraiser_extras] DONE — 9 meshes in {OUT}")
print("[next] python3 open_cloud_upload.py meshes ~/Desktop/kittyraiser_extra_meshes")
