"""Convert selected Alex Samusenko city buildings to private mobile atlases.
Usage: blender -b --python prepare_licensed_city.py -- source.blend output_directory
The complete source city is not exported: only five building meshes are kept.
"""
import bpy,sys,pathlib
from mathutils import Vector,Matrix
source,folder=sys.argv[sys.argv.index('--')+1:][:2];folder=pathlib.Path(folder)
buildings=[('BANK','CityBank'),('Business center.001','CityOffice'),('HOUSE TERAZZA','CityTerrace'),('OLD BRICK HOUSE','CityBrick'),('Six-story building','CityApartment')]
for authored,name in buildings:
    bpy.ops.wm.open_mainfile(filepath=source)
    obj=bpy.data.objects[authored]
    world=obj.matrix_world.copy();obj.parent=None;obj.matrix_world=world
    # Keep source coordinates during baking; source shaders use the authored UV.
    for tree in list(bpy.data.node_groups)+[m.node_tree for m in bpy.data.materials if m.node_tree]:
        for node in list(tree.nodes):
            if node.type=='TEX_COORD':
                links=list(node.outputs['UV'].links)
                if links:
                    uv=tree.nodes.new('ShaderNodeUVMap');uv.uv_map='UVMap'
                    for link in links:tree.links.new(uv.outputs['UV'],link.to_socket)
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=4
    scene.render.bake.use_pass_direct=False;scene.render.bake.use_pass_indirect=False;scene.render.bake.use_pass_color=True;scene.render.bake.margin=8
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    obj.data.uv_layers.new(name='MobileAtlas');obj.data.uv_layers.active_index=len(obj.data.uv_layers)-1
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.2,island_margin=.01);bpy.ops.object.mode_set(mode='OBJECT')
    images={}
    for role,bake in [('Color','DIFFUSE'),('Normal','NORMAL')]:
        img=bpy.data.images.new(name+role,width=1024,height=1024,alpha=False)
        if role=='Normal':img.colorspace_settings.name='Non-Color'
        for mat in obj.data.materials:
            mat.use_nodes=True;n=mat.node_tree.nodes.new('ShaderNodeTexImage');n.image=img;mat.node_tree.nodes.active=n
        print('BAKING',name,role,flush=True);bpy.ops.object.bake(type=bake);img.pack();images[role]=img
    atlas=bpy.data.materials.new(name+'Facade');atlas.use_nodes=True;p=atlas.node_tree.nodes.get('Principled BSDF');p.inputs['Roughness'].default_value=.72
    for role,img in images.items():
        n=atlas.node_tree.nodes.new('ShaderNodeTexImage');n.image=img
        if role=='Color':atlas.node_tree.links.new(n.outputs['Color'],p.inputs['Base Color'])
        else:
            normal=atlas.node_tree.nodes.new('ShaderNodeNormalMap');atlas.node_tree.links.new(n.outputs['Color'],normal.inputs['Color']);atlas.node_tree.links.new(normal.outputs['Normal'],p.inputs['Normal'])
    window=bpy.data.materials.new(name+'Glazing');window.use_nodes=True;w=window.node_tree.nodes.get('Principled BSDF');w.inputs['Base Color'].default_value=(.09,.16,.21,1);w.inputs['Metallic'].default_value=.5;w.inputs['Roughness'].default_value=.18
    # Preserve window faces as glazing; the diffuse-only glass bake is black.
    originals=list(obj.data.materials);indices=[face.material_index for face in obj.data.polygons]
    obj.data.materials.clear();obj.data.materials.append(atlas);obj.data.materials.append(window)
    for face,index in zip(obj.data.polygons,indices):face.material_index=1 if 'glass' in originals[index].name.lower() else 0
    for uv in list(obj.data.uv_layers):
        if uv.name!='MobileAtlas':obj.data.uv_layers.remove(uv)
    obj.data.uv_layers.active.name='UVMap'
    # Evaluate modest bevels, detach from the city origin and center each model.
    deps=bpy.context.evaluated_depsgraph_get();mesh=bpy.data.meshes.new_from_object(obj.evaluated_get(deps));obj.data=mesh
    mesh.transform(obj.matrix_world);obj.matrix_world=Matrix.Identity(4)
    points=[v.co for v in mesh.vertices];center=Vector(((min(v.x for v in points)+max(v.x for v in points))/2,(min(v.y for v in points)+max(v.y for v in points))/2,min(v.z for v in points)))
    mesh.transform(Matrix.Translation(-center));obj.name=name
    bpy.ops.export_scene.gltf(filepath=str(folder/(name+'.glb')),export_format='GLB',export_yup=True,use_selection=True,export_apply=True,export_extras=False,export_cameras=False,export_lights=False)
    print('CITY_BUILDING_EXPORTED',name,len(mesh.polygons),flush=True)
