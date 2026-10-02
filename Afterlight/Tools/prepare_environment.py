"""Build mobile-sized GLB derivatives of verified licensed source models."""
import bpy,pathlib
ROOT=pathlib.Path('/Users/oanarinaldi/Desktop/turboracer/Afterlight/Resources/Models')
for name in ['coastal_cliff_01','island_tree_01','pine_sapling_small']:
    source=pathlib.Path('/tmp/afterlight-environment')/name/(name+'.gltf')
    if not source.exists():continue
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(source))
    for obj in list(bpy.data.objects):
        if obj.type!='MESH':continue
        count=len(obj.data.polygons)
        if count>16000:
            bpy.context.view_layer.objects.active=obj
            mod=obj.modifiers.new('Mobile mesh budget','DECIMATE');mod.ratio=16000/count;bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.export_scene.gltf(filepath=str(ROOT/(name+'.glb')),export_format='GLB',export_yup=True,export_apply=True)
    print('PREPARED',name,flush=True)
# Legacy Blender palm: keep the creator's leaf atlas and explicit attribution.
bpy.ops.wm.open_mainfile(filepath='/tmp/afterlight-palm/palm.blend')
for image in bpy.data.images:
    if image.name.endswith('.png'):
        image.filepath='/tmp/afterlight-palm/palm.png';image.reload()
for obj in list(bpy.data.objects):
    if obj.type!='MESH':bpy.data.objects.remove(obj,do_unlink=True)
if not bpy.data.materials: bpy.data.materials.new('PalmAtlas')
for obj in bpy.data.objects:
    if obj.type=='MESH' and not obj.data.materials: obj.data.materials.append(bpy.data.materials[0])
for mat in bpy.data.materials:
    mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Roughness'].default_value=.8
    tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load('/tmp/afterlight-palm/palm.png',check_existing=True)
    mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color']);mat.node_tree.links.new(tex.outputs['Alpha'],bsdf.inputs['Alpha']);mat.surface_render_method='DITHERED';mat.use_backface_culling=False
bpy.ops.export_scene.gltf(filepath=str(ROOT/'CoastalPalm.glb'),export_format='GLB',export_yup=True,export_apply=True)
