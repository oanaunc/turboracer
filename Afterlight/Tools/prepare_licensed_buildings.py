"""Mobile derivatives of royalty-free BlenderKit buildings for Afterlight.
Run once per downloaded file:
  Blender -b <source.blend> --python prepare_licensed_buildings.py -- <OutputName> [triangle budget]
Writes ArtSources/<OutputName>.glb outside the repository; package with pack_art.swift.
Visible meshes are evaluated, joined, decimated to the budget, centred on the
ground and given portable PBR materials (images capped at 512 px).
"""
import bpy, sys, pathlib
from mathutils import Vector, Matrix
args = sys.argv[sys.argv.index('--')+1:]
name = args[0]; budget = int(args[1]) if len(args) > 1 else 30000
deps = bpy.context.evaluated_depsgraph_get(); objects = []
for obj in list(bpy.data.objects):
    if obj.type != 'MESH' or obj.hide_render or not obj.visible_get(): continue
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(deps), depsgraph=deps)
    if not mesh.polygons: continue
    n = bpy.data.objects.new(obj.name+' M', mesh); bpy.context.collection.objects.link(n); n.matrix_world = obj.matrix_world.copy(); objects.append(n)
for obj in list(bpy.data.objects):
    if obj not in objects: bpy.data.objects.remove(obj, do_unlink=True)
for obj in objects: obj.data.transform(obj.matrix_world); obj.matrix_world = Matrix.Identity(4)
bpy.ops.object.select_all(action='DESELECT')
for o in objects: o.select_set(True)
bpy.context.view_layer.objects.active = objects[0]; bpy.ops.object.join(); building = bpy.context.view_layer.objects.active
count = len(building.data.polygons)
if count > budget:
    mod = building.modifiers.new('budget', 'DECIMATE'); mod.ratio = budget/count; bpy.ops.object.modifier_apply(modifier=mod.name)
lo = Vector([min(v.co[i] for v in building.data.vertices) for i in range(3)]); hi = Vector([max(v.co[i] for v in building.data.vertices) for i in range(3)])
building.data.transform(Matrix.Translation(-Vector(((lo.x+hi.x)/2, (lo.y+hi.y)/2, lo.z)))); building.name = name
for image in bpy.data.images:
    if image.size[0] > 512 or image.size[1] > 512: image.scale(min(512, image.size[0]), min(512, image.size[1]))
for mat in bpy.data.materials:
    if not mat.use_nodes: continue
    p = next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if p is None: continue
    low = mat.name.lower()
    if 'glass' in low or 'fenel' in low or 'frenel' in low:
        # Transmission does not survive glTF on mobile; dark reflective glazing reads better.
        for link in list(p.inputs['Base Color'].links): mat.node_tree.links.remove(link)
        p.inputs['Base Color'].default_value = (.05, .09, .13, 1); p.inputs['Metallic'].default_value = .85; p.inputs['Roughness'].default_value = .08
        if 'Transmission Weight' in p.inputs: p.inputs['Transmission Weight'].default_value = 0
        p.inputs['Alpha'].default_value = 1; mat.name = 'Glazing ' + mat.name
print('BUILDING', name, len(building.data.polygons), tuple(round(x, 1) for x in hi-lo), flush=True)
out = pathlib.Path('/Users/oanarinaldi/Library/Application Support/TurboRacer/ArtSources/'+name+'.glb')
bpy.ops.export_scene.gltf(filepath=str(out), export_format='GLB', export_yup=True, export_apply=True, export_materials='EXPORT', export_image_format='JPEG', export_extras=False)
print('EXPORTED', out, flush=True)
