"""Convert fetched CC0 Poly Haven nature models into mobile GLBs.
Run: Blender -b --python prepare_nature.py -- /tmp/afterlight-nature
Leaf geometry is thinned by whole leaf islands (kept leaves are enlarged to
hold the canopy silhouette); solid parts are decimated to a triangle budget.
"""
import bpy, bmesh, sys, pathlib, random
from mathutils import Vector, Matrix
source = pathlib.Path(sys.argv[sys.argv.index('--')+1])
out_dir = pathlib.Path(__file__).resolve().parents[1]/'Resources'/'Models'
# name: (output, solid triangle budget, leaf triangle budget, leaf enlargement)
PLAN = {
    'island_tree_02': ('IslandTree', 16000, 12000, 2.6),
    'quiver_tree_01': ('QuiverTree', 8000, 20000, 1.0), 'quiver_tree_02': ('QuiverTreeB', 9000, 0, 1.0),
    'coast_rocks_01': ('CoastRocks', 5000, 0, 1), 'coast_land_rocks_02': ('CoastLandRocks', 6000, 0, 1),
    'namaqualand_boulder_02': ('DesertBoulder', 3500, 0, 1), 'namaqualand_boulder_05': ('DesertBoulderB', 3500, 0, 1),
    'namaqualand_cliff_01': ('DesertCliff', 6000, 0, 1), 'rock_moss_set_01': ('MossRocks', 5000, 0, 1),
    'boulder_01': ('Boulder', 3500, 0, 1), 'dead_tree_trunk_02': ('DeadTrunk', 4000, 0, 1),
   
    'tree_stump_01': ('Stump', 2500, 0, 1), 'rock_face_01': ('RockFace', 6000, 0, 1),
}
random.seed(7)
for folder, (name, solid_budget, leaf_budget, enlarge) in PLAN.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source/folder/(folder+'.gltf')))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    for o in meshes: o.data.transform(o.matrix_world); o.matrix_world = Matrix.Identity(4); o.parent = None
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes: o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1: bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    leaf_slots = {i for i, m in enumerate(obj.data.materials) if m and ('leaf' in m.name or 'leaves' in m.name)}
    bm = bmesh.new(); bm.from_mesh(obj.data); bm.faces.ensure_lookup_table()
    leaves = [f for f in bm.faces if f.material_index in leaf_slots]
    if leaves and leaf_budget:
        # Split leaf faces into connected islands, keep a random subset, enlarge each.
        seen = set(); islands = []
        for f in leaves:
            if f.index in seen: continue
            stack = [f]; island = []; seen.add(f.index)
            while stack:
                face = stack.pop(); island.append(face)
                for e in face.edges:
                    for g in e.link_faces:
                        if g.index not in seen and g.material_index in leaf_slots: seen.add(g.index); stack.append(g)
            islands.append(island)
        keep_ratio = min(1, leaf_budget/max(1, len(leaves)))
        drop = []
        for island in islands:
            if random.random() > keep_ratio: drop.extend(island); continue
            verts = {v for f in island for v in f.verts}
            c = sum((v.co for v in verts), Vector())/len(verts)
            for v in verts: v.co = c+(v.co-c)*enlarge
        bmesh.ops.delete(bm, geom=drop, context='FACES')
    bm.to_mesh(obj.data); bm.free()
    # Decimate solid parts on their own, then rejoin the thinned leaf cards.
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); bpy.context.view_layer.objects.active = obj
    parts = [obj]
    if leaf_slots:
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='DESELECT')
        for slot in leaf_slots: obj.active_material_index = slot; bpy.ops.object.material_slot_select()
        bpy.ops.mesh.separate(type='SELECTED'); bpy.ops.object.mode_set(mode='OBJECT')
        parts = list(bpy.context.selected_objects)
    for part in parts:
        is_leaf = any(p.material_index in leaf_slots for p in part.data.polygons[:1])
        count = len(part.data.polygons)
        if not is_leaf and count > solid_budget:
            bpy.context.view_layer.objects.active = part
            mod = part.modifiers.new('budget', 'DECIMATE'); mod.ratio = solid_budget/count; mod.use_collapse_triangulate = True
            bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.select_all(action='DESELECT')
    for part in parts: part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    if len(parts) > 1: bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    lo = Vector([min(v.co[i] for v in obj.data.vertices) for i in range(3)]); hi = Vector([max(v.co[i] for v in obj.data.vertices) for i in range(3)])
    obj.data.transform(Matrix.Translation(-Vector(((lo.x+hi.x)/2, (lo.y+hi.y)/2, lo.z)))); obj.name = name
    for image in bpy.data.images:
        if image.size[0] > 1024: image.scale(1024, 1024)
    bpy.ops.export_scene.gltf(filepath=str(out_dir/(name+'.glb')), export_format='GLB', export_yup=True, export_apply=True, export_image_format='JPEG' if not leaf_slots else 'AUTO', export_extras=False)
    print('NATURE', name, len(obj.data.polygons), tuple(round(x, 1) for x in hi-lo), flush=True)
