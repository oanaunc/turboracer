"""Create a mobile derivative of Pierre-Louis Baril's licensed sport sedan.
Run with Blender and pass the downloaded .blend after --. Keep input/output
models outside the public repository; package the final GLB with pack_art.swift.
"""
import bpy,sys,math,pathlib
from mathutils import Vector,Matrix
args=sys.argv[sys.argv.index('--')+1:];asset_name=args[1] if len(args)>1 else "LuxurySedan"
source=pathlib.Path(args[0]);bpy.ops.wm.open_mainfile(filepath=str(source))
# Evaluate visible authored geometry before stripping support objects.
deps=bpy.context.evaluated_depsgraph_get();objects=[]
for obj in list(bpy.data.objects):
    if obj.type!='MESH' or obj.hide_render or obj.name=='Roundcube.001':continue
    # Three subdivisions preserve the body curvature at a mobile mesh budget.
    for mod in obj.modifiers:
        if mod.type=='SUBSURF':mod.levels=min(mod.levels,3);mod.render_levels=min(mod.render_levels,3)
    deps.update();mesh=bpy.data.meshes.new_from_object(obj.evaluated_get(deps),depsgraph=deps)
    n=bpy.data.objects.new(obj.name+' Mobile',mesh);bpy.context.collection.objects.link(n);n.matrix_world=obj.matrix_world.copy();objects.append(n)
for obj in list(bpy.data.objects):
    if obj not in objects:bpy.data.objects.remove(obj,do_unlink=True)
# Retain authored UVs and image maps where they are portable. Procedural paint,
# transmission and nested node groups become a consistent mobile PBR palette.
for mat in bpy.data.materials:
    name=mat.name.lower();mat.use_nodes=True
    images=[node.image for node in mat.node_tree.nodes if node.type=='TEX_IMAGE' and node.image]
    mat.node_tree.nodes.clear();out=mat.node_tree.nodes.new('ShaderNodeOutputMaterial');p=mat.node_tree.nodes.new('ShaderNodeBsdfPrincipled');mat.node_tree.links.new(p.outputs['BSDF'],out.inputs['Surface'])
    color=(.055,.075,.09,1);metal=.05;rough=.45
    if 'paint' in name and 'rim' not in name and name not in ['grey paint','blue paint','white paint','red paint'] and (asset_name!='RivalPickup' or name.startswith('car paint')):
        color=(.025,.07,.12,1);metal=.55;rough=.24;mat.name='LuxuryBodyPaint '+mat.name
    elif any(x in name for x in ['glass','sunroof']):color=(.012,.025,.032,1);metal=.12;rough=.12
    elif any(x in name for x in ['chrome','nickel','aluminium','steel','metal','mirror']):color=(.36,.4,.43,1);metal=.9;rough=.23
    elif 'rubber' in name or 'sidewall' in name:color=(.016,.019,.02,1);metal=0;rough=.87
    elif 'caliper' in name:color=(.65,.11,.025,1);metal=.3;rough=.4
    elif 'red glass' in name:color=(.5,.004,.007,1);metal=.2;rough=.2
    elif 'drl' in name or 'carlight' in name or 'emissive hl' in name:color=(.7,.85,1,1);p.inputs['Emission Color'].default_value=(.5,.7,1,1);p.inputs['Emission Strength'].default_value=1.3
    elif 'license' in name or 'licence' in name:color=(.018,.022,.025,1);metal=.15;rough=.4
    p.inputs['Base Color'].default_value=color;p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    if 'red glass' in name:p.inputs['Emission Color'].default_value=(.8,.004,.008,1);p.inputs['Emission Strength'].default_value=.7
    mat.diffuse_color=color
# Retain the authored exterior normals before simplifying. Transferring them
# back after decimation avoids the rippled paint caused by averaged triangles.
normal_sources={}
for obj in objects:
    if any(m and m.name.startswith('LuxuryBodyPaint') for m in obj.data.materials):
        original=obj.copy();original.data=obj.data.copy();bpy.context.collection.objects.link(original)
        normal_sources[obj]=original
# Remove interior micro-detail that cannot be seen through opaque tinted glass;
# retain the dashboard/seats to support garage close-ups.
for obj in objects:
    bpy.context.view_layer.objects.active=obj
    budget=12000 if any(m and m.name.startswith('LuxuryBodyPaint') for m in obj.data.materials) else 1600
    if len(obj.data.polygons)>budget:
        mod=obj.modifiers.new('Mobile surface budget','DECIMATE');mod.ratio=min(1,budget/len(obj.data.polygons));bpy.ops.object.modifier_apply(modifier=mod.name)
# Reduce small interior components while retaining more exterior curvature.
total=sum(len(o.data.polygons) for o in objects)
ratio=min(1,90000/max(total,1))
for obj in objects:
    if len(obj.data.polygons)>64:
        bpy.context.view_layer.objects.active=obj
        mod=obj.modifiers.new('Fleet triangle budget','DECIMATE');mod.ratio=.95 if any(m and m.name.startswith('LuxuryBodyPaint') for m in obj.data.materials) else ratio
        bpy.ops.object.modifier_apply(modifier=mod.name)
for obj,original in normal_sources.items():
    bpy.context.view_layer.objects.active=obj
    transfer=obj.modifiers.new('Authored surface normals','DATA_TRANSFER')
    transfer.object=original;transfer.use_loop_data=True;transfer.data_types_loops={'CUSTOM_NORMAL'}
    transfer.loop_mapping='POLYINTERP_NEAREST'
    bpy.ops.object.modifier_apply(modifier=transfer.name)
    bpy.data.objects.remove(original,do_unlink=True)
# Keep authored real-world dimensions and ground contact. glTF maps -Y to +Z.
points=[o.matrix_world@Vector(v) for o in objects for v in o.bound_box]
lo=Vector([min(p[i] for p in points) for i in range(3)]);hi=Vector([max(p[i] for p in points) for i in range(3)])
center=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
for obj in objects:
    obj.location-=center
# Consolidate the hundreds of authored parts into a body and four wheel assemblies.
# Keep the wheel pivot at its hub so SceneKit can animate the real wheel meshes.
for obj in objects:
    obj.data.transform(obj.matrix_world);obj.matrix_world=Matrix.Identity(4)
bpy.context.view_layer.update()
tires=[o for o in objects if ('PilotSport' in o.name or o.name.lower().startswith('tire'))]
wheel_centers=[sum((Vector(v) for v in o.bound_box),Vector())/8 for o in tires]
groups=[[] for _ in range(5)]
for obj in objects:
    c=sum((Vector(v) for v in obj.bound_box),Vector())/8
    nearest=min(range(len(wheel_centers)),key=lambda i:(c-wheel_centers[i]).length) if wheel_centers else None
    if nearest is not None and (c-wheel_centers[nearest]).length<.57 and max(obj.dimensions)<1.1:groups[nearest+1].append(obj)
    else:groups[0].append(obj)
objects=[]
for index,parts in enumerate(groups):
    if not parts:continue
    bpy.ops.object.select_all(action='DESELECT')
    for part in parts:part.select_set(True)
    bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();joined=bpy.context.object
    if index==0:joined.name='LuxuryBody';pivot=Vector()
    else:
        pivot=wheel_centers[index-1]
        joined.name='Wheel'+('Front' if pivot.y<0 else 'Rear')+('L' if pivot.x<0 else 'R')
    bpy.context.scene.cursor.location=pivot;bpy.ops.object.origin_set(type='ORIGIN_CURSOR');objects.append(joined)
print('MOBILE_GEOMETRY',[(o.name,len(o.data.polygons)) for o in objects],flush=True)
output=pathlib.Path('/Users/oanarinaldi/Library/Application Support/TurboRacer/ArtSources/'+asset_name+'.glb')
bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',export_yup=True,export_apply=True,export_materials='EXPORT',export_extras=False)
print('EXPORTED',output,'dimensions',tuple(hi-lo),'polygons',sum(len(o.data.polygons) for o in objects),flush=True)
