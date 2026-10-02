"""Convert Jan Hecl's licensed coconut palm to portable mobile PBR."""
import bpy,sys,pathlib,json,struct
from mathutils import Matrix,Vector
source=sys.argv[sys.argv.index('--')+1];bpy.ops.wm.open_mainfile(filepath=source)
for obj in list(bpy.data.objects):
    if obj.type!='MESH' or obj.hide_render:bpy.data.objects.remove(obj,do_unlink=True)
for image in bpy.data.images:
    if max(image.size)>1024:
        factor=1024/max(image.size);image.scale(max(1,int(image.size[0]*factor)),max(1,int(image.size[1]*factor)))
for mat in bpy.data.materials:
    textures=[n.image for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image]
    mat.node_tree.nodes.clear();out=mat.node_tree.nodes.new('ShaderNodeOutputMaterial');p=mat.node_tree.nodes.new('ShaderNodeBsdfPrincipled');mat.node_tree.links.new(p.outputs['BSDF'],out.inputs['Surface']);p.inputs['Roughness'].default_value=.8
    for role,socket in [('albedo','Base Color'),('diffuse','Base Color'),('roughness','Roughness'),('opacity','Alpha')]:
        image=next((i for i in textures if role in i.name.lower()),None)
        if image:
            tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;mat.node_tree.links.new(tex.outputs['Color'],p.inputs[socket])
    image=next((i for i in textures if 'normal' in i.name.lower()),None)
    if image:
        tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');mat.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs['Normal'],p.inputs['Normal'])
    mat.use_backface_culling=False;mat.surface_render_method='DITHERED'
# Rename each authored UV layer before joining. Different source names would
# otherwise create empty UV channels for the leaf meshes.
for obj in bpy.data.objects:
    if obj.data.uv_layers:obj.data.uv_layers.active.name="UVMap"
# Bake authored object transforms and merge parts; six materials remain distinct.
for obj in bpy.data.objects:obj.data.transform(obj.matrix_world);obj.matrix_world=Matrix.Identity(4)
bpy.context.view_layer.update();bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.objects.active=list(bpy.data.objects)[0];bpy.ops.object.join()
obj=bpy.context.object;obj.name='CoconutPalm';bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
output=pathlib.Path('/Users/oanarinaldi/Library/Application Support/TurboRacer/ArtSources/RoyalPalm.glb')
bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',export_yup=True,export_apply=True,export_extras=False)
# Explicit cutout foliage prevents depth-sorting halos around overlapping fronds.
data=output.read_bytes();length=struct.unpack_from('<I',data,12)[0];doc=json.loads(data[20:20+length]);binary=data[20+length:]
for mat in doc.get('materials',[]):
    if any(word in mat.get('name','').lower() for word in ['leaf','leaves','dry_palm']):mat['alphaMode']='MASK';mat['alphaCutoff']=.4;mat['doubleSided']=True
js=json.dumps(doc,separators=(',',':')).encode();js+=b' '*((-len(js))%4)
output.write_bytes(struct.pack('<III',0x46546c67,2,20+len(js)+len(binary))+struct.pack('<II',len(js),0x4e4f534a)+js+binary)
print('PALM_EXPORTED',len(obj.data.polygons),output,flush=True)
