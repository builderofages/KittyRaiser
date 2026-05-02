"""
blender_kittyraiser_cat.py

Generates a low-poly stylized cat suitable for Roblox import.
Outputs OBJ files in the same folder for: cat_body, cat_head, cat_ear, cat_leg, cat_tail.
These are anatomically-correct enough that they don't read as "primitives" in Roblox.

HOW TO RUN:
1. Open Blender (free download: blender.org)
2. Switch to "Scripting" workspace
3. New text block, paste this script
4. Run Script (Alt+P)
5. Switch to "Layout" workspace to see the cat
6. The script auto-exports OBJ files to ~/Desktop/kittyraiser_cat_meshes/

Or run headless from terminal:
    /Applications/Blender.app/Contents/MacOS/Blender --background --python blender_kittyraiser_cat.py
"""

import bpy
import math
import os

OUTPUT_DIR = os.path.expanduser("~/Desktop/kittyraiser_cat_meshes")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# ── CLEAR SCENE ─────────────────────────────────────────────
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

def export_active(name):
    """Export the currently-selected/active object as an OBJ at OUTPUT_DIR/name.obj"""
    path = os.path.join(OUTPUT_DIR, f"{name}.obj")
    bpy.ops.wm.obj_export(
        filepath=path,
        export_selected_objects=True,
        export_uv=True,
        export_normals=True,
        export_materials=False,
        forward_axis='NEGATIVE_Z',
        up_axis='Y',
    )
    print(f"[export] {path}")

# ── 1. CAT BODY (elongated capsule shape) ──────────────────
bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, radius=1, location=(0, 0, 0))
body = bpy.context.active_object
body.name = "cat_body"
body.scale = (1.0, 1.6, 0.95)  # elongate front-to-back, slightly squish vertically
bpy.ops.object.transform_apply(scale=True)
# Smooth shading
for poly in body.data.polygons:
    poly.use_smooth = True
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
bpy.context.view_layer.objects.active = body
export_active("cat_body")

# ── 2. CAT HEAD (slightly flattened sphere with pointed muzzle) ──────
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, radius=0.7, location=(0, 1.4, 0.15))
head = bpy.context.active_object
head.name = "cat_head"
head.scale = (1.0, 0.95, 0.85)
bpy.ops.object.transform_apply(scale=True)
# Add a slight muzzle by pulling front-bottom verts forward
import bmesh
me = head.data
bm = bmesh.new()
bm.from_mesh(me)
for v in bm.verts:
    if v.co.y > 0.4 and v.co.z < 0.0:
        v.co.y += 0.15  # extend muzzle forward
        v.co.z -= 0.05  # drop slightly
bm.to_mesh(me)
bm.free()
for poly in head.data.polygons:
    poly.use_smooth = True
bpy.ops.object.select_all(action='DESELECT')
head.select_set(True)
bpy.context.view_layer.objects.active = head
export_active("cat_head")

# ── 3. CAT EAR (triangular pyramid, slightly leaning) ─────
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.18, radius2=0, depth=0.45, location=(0, 0, 0))
ear = bpy.context.active_object
ear.name = "cat_ear"
ear.rotation_euler = (math.radians(-15), 0, 0)
bpy.ops.object.transform_apply(rotation=True)
for poly in ear.data.polygons:
    poly.use_smooth = True
bpy.ops.object.select_all(action='DESELECT')
ear.select_set(True)
bpy.context.view_layer.objects.active = ear
export_active("cat_ear")

# ── 4. CAT LEG (cylindrical with paw at bottom) ───────────
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.2, depth=0.7, location=(0, 0, 0))
leg = bpy.context.active_object
leg.name = "cat_leg"
# Add a paw at bottom by adding a slight bulge
bm = bmesh.new()
bm.from_mesh(leg.data)
for v in bm.verts:
    if v.co.z < -0.3:
        v.co.x *= 1.3
        v.co.y *= 1.3
bm.to_mesh(leg.data)
bm.free()
for poly in leg.data.polygons:
    poly.use_smooth = True
bpy.ops.object.select_all(action='DESELECT')
leg.select_set(True)
bpy.context.view_layer.objects.active = leg
export_active("cat_leg")

# ── 5. CAT TAIL (tapered curve made of cylinder segments) ─
bpy.ops.object.select_all(action='DESELECT')
# Single tapered cone for simplicity (chained instances at runtime in Roblox)
bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.15, radius2=0.05, depth=1.4, location=(0, 0, 0))
tail = bpy.context.active_object
tail.name = "cat_tail_segment"
for poly in tail.data.polygons:
    poly.use_smooth = True
bpy.ops.object.select_all(action='DESELECT')
tail.select_set(True)
bpy.context.view_layer.objects.active = tail
export_active("cat_tail_segment")

# ── 6. ALSO BUILD A FULL ASSEMBLED CAT FOR PREVIEW ────────
# Re-add all parts in proper position so the user can see the assembled cat in Blender
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

# Body
bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, radius=1, location=(0, 0, 0))
b = bpy.context.active_object
b.scale = (1.0, 1.6, 0.95)
bpy.ops.object.transform_apply(scale=True)

# Head
bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, radius=0.7, location=(0, 1.4, 0.15))
h = bpy.context.active_object
h.scale = (1.0, 0.95, 0.85)
bpy.ops.object.transform_apply(scale=True)

# Two ears
for offset in (-0.3, 0.3):
    bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.18, radius2=0, depth=0.45, location=(offset, 1.55, 0.65))

# Four legs
for x in (-0.45, 0.45):
    for y in (-0.7, 0.7):
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.2, depth=0.7, location=(x, y, -0.85))

# Tail
bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.15, radius2=0.05, depth=1.4, location=(0, -1.5, 0.4))
t = bpy.context.active_object
t.rotation_euler = (math.radians(-30), 0, 0)

# Material — orange tabby
mat = bpy.data.materials.new(name="OrangeTabby")
mat.use_nodes = True
bsdf = mat.node_tree.nodes["Principled BSDF"]
bsdf.inputs["Base Color"].default_value = (0.85, 0.45, 0.15, 1.0)
bsdf.inputs["Roughness"].default_value = 0.7
for obj in bpy.context.scene.objects:
    if obj.type == 'MESH':
        if not obj.data.materials:
            obj.data.materials.append(mat)
        for poly in obj.data.polygons:
            poly.use_smooth = True

# Studio lighting
bpy.ops.object.light_add(type='AREA', location=(4, -4, 6))
key = bpy.context.active_object
key.data.energy = 500
key.data.size = 3

bpy.ops.object.light_add(type='AREA', location=(-3, -2, 4))
fill = bpy.context.active_object
fill.data.energy = 150

bpy.ops.object.camera_add(location=(5, -5, 3))
cam = bpy.context.active_object
cam.rotation_euler = (math.radians(70), 0, math.radians(45))
bpy.context.scene.camera = cam

# Render config
scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.render.resolution_x = 1024
scene.render.resolution_y = 1024

print(f"[blender_kittyraiser_cat] DONE. OBJ files in: {OUTPUT_DIR}")
print("[next] Upload these via Roblox Studio Asset Manager Bulk Import.")
