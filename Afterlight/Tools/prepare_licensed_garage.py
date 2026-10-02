"""Bake Dennis Hafemann's warehouse materials into a private mobile showroom.
Usage: blender -b --python prepare_licensed_garage.py -- source.blend output.glb
Source and output remain outside the public repository.
"""
import bpy,sys,pathlib
from mathutils import Matrix
source,output=sys.argv[sys.argv.index('--')+1:][:2]
bpy.ops.wm.open_mainfile(filepath=source)
for o in list(bpy.data.objects):
    if o.type!='MESH' or o.name in ['Atmosphere','Ground Stones','Rock.001','rock.002']:
        bpy.data.objects.remove(o,do_unlink=True)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=8
scene.render.bake.use_pass_direct=False;scene.render.bake.use_pass_indirect=False;scene.render.bake.use_pass_color=True;scene.render.bake.margin=12
room=bpy.data.objects['Room'];bpy.ops.object.select_all(action='DESELECT');room.select_set(True);bpy.context.view_layer.objects.active=room
# Preserve source UV coordinates used by the procedural shader; add a separate
# non-overlapping atlas for the baked mobile textures.
room.data.uv_layers.new(name='MobileAtlas');room.data.uv_layers.active_index=len(room.data.uv_layers)-1
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.015);bpy.ops.object.mode_set(mode='OBJECT')
images={}
for role,bake in [('Color','DIFFUSE'),('Normal','NORMAL')]:
    img=bpy.data.images.new('Warehouse'+role,width=2048,height=2048,alpha=False)
    if role=='Normal':img.colorspace_settings.name='Non-Color'
    for mat in room.data.materials:
        n=mat.node_tree.nodes.new('ShaderNodeTexImage');n.image=img;mat.node_tree.nodes.active=n
    bpy.ops.object.bake(type=bake)
    img.pack();images[role]=img
mat=bpy.data.materials.new('WarehouseConcrete');mat.use_nodes=True;p=mat.node_tree.nodes.get('Principled BSDF');p.inputs['Roughness'].default_value=.78
for role in images:
    n=mat.node_tree.nodes.new('ShaderNodeTexImage');n.image=images[role]
    if role=='Color':mat.node_tree.links.new(n.outputs['Color'],p.inputs['Base Color'])
    else:
        normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');mat.node_tree.links.new(n.outputs['Color'],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs['Normal'],p.inputs['Normal'])
# Split window faces before replacing the room's mixed source shader.
window=bpy.data.materials.new('WarehouseWindow');window.use_nodes=True;wp=window.node_tree.nodes.get('Principled BSDF');wp.inputs['Base Color'].default_value=(.13,.25,.32,1);wp.inputs['Metallic'].default_value=.5;wp.inputs['Roughness'].default_value=.15
material_indices=[face.material_index for face in room.data.polygons]
room.data.materials.clear();room.data.materials.append(mat);room.data.materials.append(window)
for face,index in zip(room.data.polygons,material_indices):face.material_index=index
for uv in list(room.data.uv_layers):
    if uv.name!='MobileAtlas':room.data.uv_layers.remove(uv)
room.data.uv_layers.active.name='UVMap'
for o in bpy.data.objects:
    if o==room:continue
    for old in list(o.data.materials):
        name=old.name;old.use_nodes=True;old.node_tree.nodes.clear();out=old.node_tree.nodes.new('ShaderNodeOutputMaterial');p=old.node_tree.nodes.new('ShaderNodeBsdfPrincipled');old.node_tree.links.new(p.outputs['BSDF'],out.inputs['Surface'])
        p.inputs['Base Color'].default_value=(.7,.39,.035,1) if 'Yellow' in name else (.2,.25,.3,1) if 'Light' in name else (.035,.045,.055,1)
        p.inputs['Metallic'].default_value=.65;p.inputs['Roughness'].default_value=.35
    for uv in list(o.data.uv_layers)[1:]:o.data.uv_layers.remove(uv)
# Enlarge architecture, keeping a clear central display bay for every car.
for o in bpy.data.objects:
    o.matrix_world=Matrix.Diagonal((1.8,1.8,1.8,1))@o.matrix_world
bpy.ops.export_scene.gltf(filepath=output,export_format='GLB',export_yup=True,export_apply=True,export_extras=False,export_cameras=False,export_lights=False)
print('GARAGE_EXPORTED',output,flush=True)
