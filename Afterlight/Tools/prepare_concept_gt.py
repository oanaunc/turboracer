"""Mobile adaptation of Sharif Miah's Concept styled sports car 1 (BlenderKit).
Input and output remain in private art storage. Export four independently
rotating wheels, tuned proportions, and portable physically based materials.
"""
import bpy,sys,pathlib,math,bmesh
from mathutils import Vector,Matrix
bpy.ops.wm.open_mainfile(filepath=sys.argv[-1]);deps=bpy.context.evaluated_depsgraph_get();parts=[]
for obj in list(bpy.data.objects):
 if obj.type!='MESH':continue
 for mod in obj.modifiers:
  if mod.type=='SUBSURF':mod.levels=1;mod.render_levels=1
 deps.update();mesh=bpy.data.meshes.new_from_object(obj.evaluated_get(deps),depsgraph=deps)
 n=bpy.data.objects.new(obj.name,mesh);bpy.context.collection.objects.link(n);mesh.transform(obj.matrix_world)
 if obj.matrix_world.determinant()<0:mesh.flip_normals()
 parts.append(n)
for o in list(bpy.data.objects):
 if o not in parts:bpy.data.objects.remove(o,do_unlink=True)
# The source is a 2 m concept maquette. Scale it to a 4.65 m GT,
# preserving round wheel profiles with a lower, narrower cabin above the beltline.
points=[v.co for o in parts for v in o.data.vertices];lo=Vector([min(v[i] for v in points) for i in range(3)]);hi=Vector([max(v[i] for v in points) for i in range(3)])
scale=4.65/(hi.y-lo.y);center=(lo+hi)*.5
for o in parts:
 wheel='tyres' in o.name or 'alloys' in o.name
 hub_y=sum(v.co.y for v in o.data.vertices)/len(o.data.vertices)
 for v in o.data.vertices:
  p=v.co;longitudinal=(hub_y-center.y)+(p.y-hub_y)*.86 if wheel else p.y-center.y
  v.co=Vector((-(p.x-center.x)*scale*.82,-longitudinal*scale,(p.z-lo.z)*scale*.86))
for m in bpy.data.materials:
 name=m.name.lower();m.use_nodes=True;m.node_tree.nodes.clear();out=m.node_tree.nodes.new('ShaderNodeOutputMaterial');p=m.node_tree.nodes.new('ShaderNodeBsdfPrincipled');m.node_tree.links.new(p.outputs['BSDF'],out.inputs['Surface'])
 color=(.015,.02,.024,1);metal=.1;rough=.55
 if 'main body black' in name:m.name='LuxuryBodyPaint GT';color=(.19,.05,.32,1);metal=.45;rough=.27
 elif 'main body 2' in name:color=(.015,.02,.026,1);metal=.45;rough=.32
 elif 'lamp cover' in name or 'main lamp covers' in name:
  m.name='Headlight Lens';color=(.48,.68,.8,1);metal=.1;rough=.22;p.inputs['Emission Color'].default_value=(.45,.65,.8,1);p.inputs['Emission Strength'].default_value=.65
 elif 'rear lights main cover' in name:
  m.name='Tail Light Lens';color=(.4,.004,.008,1);metal=.1;rough=.22;p.inputs['Emission Color'].default_value=(.5,.002,.003,1)
 elif any(x in name for x in ['window','glass','screen covers']):m.name='Glass '+m.name;color=(.018,.035,.045,1);metal=.2;rough=.16
 elif any(x in name for x in ['alloy','metal']):color=(.3,.34,.38,1);metal=.85;rough=.3
 elif any(x in name for x in ['tyre','charcoal']):color=(.012,.012,.014,1);metal=0;rough=.82
 elif 'emission' in name:
  color=(.65,.8,1,1);p.inputs['Emission Color'].default_value=(.5,.75,1,1);p.inputs['Emission Strength'].default_value=1
 elif 'brake' in name:color=(.55,.005,.008,1);p.inputs['Emission Color'].default_value=(.6,.002,.004,1)
 elif 'leather' in name or 'interior' in name:color=(.12,.065,.035,1);rough=.75
 p.inputs['Base Color'].default_value=color;p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough;m.diffuse_color=color
wheel_parts=[]
for o in list(parts):
 if 'tyres' not in o.name and 'alloys' not in o.name:continue
 for sign in [-1,1]:
  mesh=o.data.copy();bm=bmesh.new();bm.from_mesh(mesh)
  bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.co.x*sign<0],context='VERTS');bm.to_mesh(mesh);bm.free()
  n=bpy.data.objects.new(o.name+str(sign),mesh);bpy.context.collection.objects.link(n);wheel_parts.append(n)
 parts.remove(o);bpy.data.objects.remove(o,do_unlink=True)
groups=[parts,[],[],[],[]]
for o in wheel_parts:
 c=sum((v.co for v in o.data.vertices),Vector())/len(o.data.vertices);groups[1+(0 if c.y<0 else 2)+(0 if c.x<0 else 1)].append(o)
for index,group in enumerate(groups):
 bpy.ops.object.select_all(action='DESELECT')
 for o in group:o.select_set(True)
 bpy.context.view_layer.objects.active=group[0];bpy.ops.object.join();o=bpy.context.object
 o.name=['GTBody','WheelFrontL','WheelFrontR','WheelRearL','WheelRearR'][index]
 if index:
  points=[Vector(v) for v in o.bound_box];pivot=sum(points,Vector())/8
  bpy.context.scene.cursor.location=pivot;bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
 print('MOBILE',o.name,len(o.data.polygons),flush=True)
out=pathlib.Path.home()/'Library/Application Support/TurboRacer/ArtSources/ConceptGT.glb'
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',export_yup=True,export_apply=True)
print('EXPORTED ConceptGT',flush=True)
