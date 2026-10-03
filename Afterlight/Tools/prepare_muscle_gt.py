"""Create a mobile derivative of sadawn 322's royalty-free "Muscle car" (BlenderKit).
Run: Blender -b --python prepare_muscle_gt.py -- <downloaded .blend>
Writes ArtSources/MuscleGT.glb outside the repository; package it with pack_art.swift.
"""
import bpy, sys, math, pathlib
from mathutils import Vector, Matrix
source = pathlib.Path(sys.argv[sys.argv.index('--')+1])
bpy.ops.wm.open_mainfile(filepath=str(source))
deps = bpy.context.evaluated_depsgraph_get(); objects = []
for obj in list(bpy.data.objects):
    # Camera prop, support cube, number stub and the hidden underbody plane are not exterior art.
    if obj.type != 'MESH' or obj.hide_render or obj.name in ('camera', 'Roundcube.002', 'stub', 'number'): continue
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(deps), depsgraph=deps)
    n = bpy.data.objects.new(obj.name+' Mobile', mesh); bpy.context.collection.objects.link(n); n.matrix_world = obj.matrix_world.copy(); objects.append(n)
for obj in list(bpy.data.objects):
    if obj not in objects: bpy.data.objects.remove(obj, do_unlink=True)
# Mobile PBR palette; the body paint keeps the prefix the game recolours.
for mat in bpy.data.materials:
    name = mat.name.lower(); mat.use_nodes = True
    mat.node_tree.nodes.clear(); out = mat.node_tree.nodes.new('ShaderNodeOutputMaterial'); p = mat.node_tree.nodes.new('ShaderNodeBsdfPrincipled')
    mat.node_tree.links.new(p.outputs['BSDF'], out.inputs['Surface'])
    color = (.03, .035, .04, 1); metal = .1; rough = .45
    if name.startswith('car paint.003'): color = (.4, .05, .02, 1); metal = .5; rough = .25; mat.name = 'LuxuryBodyPaint ' + mat.name
    elif name.startswith('car paint'): color = (.6, .62, .64, 1); metal = .85; rough = .25
    elif 'glass' in name and 'red' in name: color = (.5, .004, .007, 1); metal = .2; rough = .2; p.inputs['Emission Color'].default_value = (.8, .004, .008, 1); p.inputs['Emission Strength'].default_value = .8
    elif 'glass' in name: color = (.012, .025, .032, 1); metal = .1; rough = .08
    elif 'steel' in name: color = (.55, .57, .6, 1); metal = .95; rough = .2
    elif 'carbon' in name: color = (.03, .03, .035, 1); metal = .3; rough = .3
    elif 'rubber' in name: color = (.016, .018, .02, 1); metal = 0; rough = .88
    elif 'led' in name or 'emission' in name or 'carlight' in name or name.startswith('material.003'):
        color = (.8, .9, 1, 1); p.inputs['Emission Color'].default_value = (.6, .75, 1, 1); p.inputs['Emission Strength'].default_value = 1.4
    elif 'piano' in name: color = (.01, .012, .014, 1); metal = .2; rough = .15
    p.inputs['Base Color'].default_value = color; p.inputs['Metallic'].default_value = metal; p.inputs['Roughness'].default_value = rough
    mat.diffuse_color = color
# Decimate dense parts (the grille and the wheels carry most of the 460K faces).
budgets = {'grid5': 6000, 'Wheel.': 7000, 'WheelBrake': 900, 'light': 3000}
for obj in objects:
    budget = next((b for k, b in budgets.items() if k in obj.name), 20000)
    if len(obj.data.polygons) > budget:
        bpy.context.view_layer.objects.active = obj
        mod = obj.modifiers.new('Mobile budget', 'DECIMATE'); mod.ratio = budget/len(obj.data.polygons); bpy.ops.object.modifier_apply(modifier=mod.name)
for obj in objects: obj.data.transform(obj.matrix_world); obj.matrix_world = Matrix.Identity(4)
# The source faces +Y; the game expects the nose at glTF +Z, which is Blender -Y.
# Authored at 1.2x real size; 0.84 brings it to a 4.6 m grand tourer.
turn = Matrix.Rotation(math.pi, 4, 'Z') @ Matrix.Scale(0.84, 4)
for obj in objects: obj.data.transform(turn)
points = [o.matrix_world @ Vector(c) for o in objects for c in o.bound_box]
lo = Vector([min(p[i] for p in points) for i in range(3)]); hi = Vector([max(p[i] for p in points) for i in range(3)])
shift = Vector(((lo.x+hi.x)/2, (lo.y+hi.y)/2, lo.z))
for obj in objects: obj.data.transform(Matrix.Translation(-shift))
bpy.context.view_layer.update()
# Body plus four rotating wheels pivoted at their hubs; brakes stay on the body.
groups = {'LuxuryBody': []}
for obj in objects:
    if '-Wheel.' in obj.name and 'Brake' not in obj.name:
        tag = obj.name.split('-Wheel.')[1].split(' ')[0]  # Ft.L, Bk.R, ...
        groups['Wheel'+('Front' if tag.startswith('Ft') else 'Rear')+('L' if tag.endswith('L') else 'R')] = [obj]
    else: groups['LuxuryBody'].append(obj)
final = []
for name, parts in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for part in parts: part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    if len(parts) > 1: bpy.ops.object.join()
    joined = bpy.context.view_layer.objects.active; joined.name = name
    pivot = Vector() if name == 'LuxuryBody' else sum((Vector(c) for c in joined.bound_box), Vector())/8
    bpy.context.scene.cursor.location = pivot; bpy.ops.object.origin_set(type='ORIGIN_CURSOR'); final.append(joined)
print('MOBILE_GEOMETRY', [(o.name, len(o.data.polygons)) for o in final], flush=True)
output = pathlib.Path('/Users/oanarinaldi/Library/Application Support/TurboRacer/ArtSources/MuscleGT.glb')
bpy.ops.export_scene.gltf(filepath=str(output), export_format='GLB', export_yup=True, export_apply=True, export_materials='EXPORT', export_extras=False)
print('EXPORTED', output, 'dimensions', tuple(hi-lo), flush=True)
