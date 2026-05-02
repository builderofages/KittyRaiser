"""
blender_kittyraiser_props.py
Generates real 3D props for KittyRaiser: anvil, taxi, brownstone, skyscraper,
trashcan, hydrant, mailbox, pie. Outputs OBJ files to ~/Desktop/kittyraiser_prop_meshes/

Run headless:
  /opt/homebrew/bin/blender --background --python blender_kittyraiser_props.py
"""

import bpy
import bmesh
import math
import os

OUTPUT_DIR = os.path.expanduser("~/Desktop/kittyraiser_prop_meshes")
os.makedirs(OUTPUT_DIR, exist_ok=True)

def reset_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def export_active(name):
    path = os.path.join(OUTPUT_DIR, f"{name}.obj")
    bpy.ops.wm.obj_export(
        filepath=path,
        export_selected_objects=True,
        export_uv=True,
        export_normals=True,
        export_materials=False,
    )
    print(f"[export] {path}")

def smooth(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = True

# ── ANVIL ─────────────────────────────────────────────────
reset_scene()
# bottom
bpy.ops.mesh.primitive_cube_add(size=2, location=(0, 0, 0))
bot = bpy.context.active_object
bot.scale = (1.4, 0.9, 0.4)
bpy.ops.object.transform_apply(scale=True)
# waist
bpy.ops.mesh.primitive_cube_add(size=2, location=(0, 0, 0.7))
waist = bpy.context.active_object
waist.scale = (0.8, 0.7, 0.3)
bpy.ops.object.transform_apply(scale=True)
# top
bpy.ops.mesh.primitive_cube_add(size=2, location=(0, 0, 1.2))
top = bpy.context.active_object
top.scale = (1.6, 1.0, 0.3)
bpy.ops.object.transform_apply(scale=True)
# horn
bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.4, radius2=0.05, depth=1.2, location=(1.6, 0, 1.2))
horn = bpy.context.active_object
horn.rotation_euler = (0, math.radians(90), 0)
bpy.ops.object.transform_apply(rotation=True)
# join
bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active = bot
bpy.ops.object.join()
bot.name = "anvil"
smooth(bot)
bpy.ops.object.select_all(action='DESELECT')
bot.select_set(True)
bpy.context.view_layer.objects.active = bot
export_active("anvil")

# ── BROWNSTONE (small NYC building) ───────────────────────
reset_scene()
bpy.ops.mesh.primitive_cube_add(size=2, location=(0, 0, 1))
b = bpy.context.active_object
b.scale = (12, 8, 16)  # 24x16x32 stud building
bpy.ops.object.transform_apply(scale=True)
# add window grid via inset and extrude (skip for speed; keep simple cube but with edge bevel)
mod = b.modifiers.new(name='Bevel', type='BEVEL')
mod.width = 0.3
mod.segments = 2
bpy.ops.object.modifier_apply(modifier='Bevel')
b.name = "brownstone"
smooth(b)
export_active("brownstone")

# ── SKYSCRAPER (tall) ─────────────────────────────────────
reset_scene()
bpy.ops.mesh.primitive_cube_add(size=2, location=(0, 0, 40))
b = bpy.context.active_object
b.scale = (20, 20, 80)  # 40x40x160 stud
bpy.ops.object.transform_apply(scale=True)
mod = b.modifiers.new(name='Bevel', type='BEVEL')
mod.width = 0.5
mod.segments = 1
bpy.ops.object.modifier_apply(modifier='Bevel')
b.name = "skyscraper"
smooth(b)
export_active("skyscraper")

# ── TAXI (yellow cab silhouette) ──────────────────────────
reset_scene()
# body
bpy.ops.mesh.primitive_cube_add(size=2, location=(0, 0, 0.6))
body = bpy.context.active_object
body.scale = (3.2, 1.5, 0.6)
bpy.ops.object.transform_apply(scale=True)
# cab
bpy.ops.mesh.primitive_cube_add(size=2, location=(0.5, 0, 1.3))
cab = bpy.context.active_object
cab.scale = (1.5, 1.4, 0.5)
bpy.ops.object.transform_apply(scale=True)
# wheels (4)
for x in (-2.0, 2.0):
    for y in (-1.4, 1.4):
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.45, depth=0.3, location=(x, y, 0.45))
        w = bpy.context.active_object
        w.rotation_euler = (math.radians(90), 0, 0)
        bpy.ops.object.transform_apply(rotation=True)
# join
bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
body.name = "taxi"
smooth(body)
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
bpy.context.view_layer.objects.active = body
export_active("taxi")

# ── TRASHCAN (cylindrical with lid) ───────────────────────
reset_scene()
bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=1, depth=2.4, location=(0, 0, 1.2))
can = bpy.context.active_object
can.name = "trashcan"
# lid (slightly wider top)
bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=1.05, depth=0.15, location=(0, 0, 2.5))
lid = bpy.context.active_object
bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active = can
bpy.ops.object.join()
smooth(can)
bpy.ops.object.select_all(action='DESELECT')
can.select_set(True)
bpy.context.view_layer.objects.active = can
export_active("trashcan")

# ── HYDRANT (squat with cap) ──────────────────────────────
reset_scene()
bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.6, depth=1.2, location=(0, 0, 0.6))
h = bpy.context.active_object
h.name = "hydrant"
# cap on top (sphere)
bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.55, location=(0, 0, 1.4))
cap = bpy.context.active_object
# side nozzles
for ang in (0, math.pi):
    nozzle_loc = (math.sin(ang) * 0.7, math.cos(ang) * 0.7, 0.6)
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.18, depth=0.3, location=nozzle_loc)
    n = bpy.context.active_object
    n.rotation_euler = (math.radians(90), 0, ang)
    bpy.ops.object.transform_apply(rotation=True)
bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active = h
bpy.ops.object.join()
smooth(h)
bpy.ops.object.select_all(action='DESELECT')
h.select_set(True)
bpy.context.view_layer.objects.active = h
export_active("hydrant")

# ── MAILBOX ───────────────────────────────────────────────
reset_scene()
bpy.ops.mesh.primitive_cube_add(size=2, location=(0, 0, 1))
m = bpy.context.active_object
m.scale = (1.4, 0.6, 1.0)
bpy.ops.object.transform_apply(scale=True)
m.name = "mailbox"
mod = m.modifiers.new(name='Bevel', type='BEVEL')
mod.width = 0.15
bpy.ops.object.modifier_apply(modifier='Bevel')
smooth(m)
export_active("mailbox")

# ── PIE (cylinder with crust ridge) ───────────────────────
reset_scene()
bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=1, depth=0.5, location=(0, 0, 0.25))
p = bpy.context.active_object
p.name = "pie"
mod = p.modifiers.new(name='Bevel', type='BEVEL')
mod.width = 0.05
bpy.ops.object.modifier_apply(modifier='Bevel')
smooth(p)
export_active("pie")

print(f"[blender_kittyraiser_props] DONE. OBJs in: {OUTPUT_DIR}")
