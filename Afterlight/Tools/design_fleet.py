"""Author distinct geometric derivatives of the attributed DGG concept platform.
World-space deformation preserves seams; wheel shapes remain circular.
"""
import bpy, math, pathlib
from mathutils import Vector, Matrix
ROOT=pathlib.Path(__file__).resolve().parents[1]/'Resources'/'Models'
for name,width,length,cabin,roof in [('Sprint',.91,.90,.90,True),('Hyper',1.10,1.10,.76,True),('Roadster',1.02,1.02,.93,False)]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/'Concept'/'Concept.glb'))
    for obj in list(bpy.data.objects):
        if obj.type!='MESH':continue
        if 'Emblem' in obj.name or obj.name=='License Plate' or 'Wiper' in obj.name or (not roof and obj.name=='BodyRoofPanel'):
            bpy.data.objects.remove(obj,do_unlink=True);continue
        world=obj.matrix_world.copy(); inverse=world.inverted()
        iswheel='Wheel' in obj.name or obj.name.startswith('Mesh_8') or obj.name.startswith('Mesh_9')
        center=world.translation.copy()
        for vertex in obj.data.vertices:
            p=world@vertex.co
            # The Blender import has X across the car, Y along the car, Z up.
            if iswheel:
                q=p.copy();q.x+=(width-1)*center.x;q.y+=(length-1)*center.y
            else:
                q=Vector((p.x*width,p.y*length,p.z))
                if p.z>.48:q.z=.48+(p.z-.48)*cabin
                if name=='Hyper':
                    # Wide shoulders, tapered nose and lower hood give a wedge profile.
                    shoulder=math.exp(-((p.y+1.2)/.8)**2)
                    q.x*=1+.055*shoulder
                    if p.y < -.6:q.z-=.08*min(1,(-p.y-.6)/1.5)*max(0,min(1,(p.z-.3)/.4))
                if name=='Sprint' and p.y>1.1:q.y-=.12*min(1,(p.y-1.1)/.9)
            vertex.co=inverse@q
        obj.data.update()
    # Keep source names for material replacement and wheel animation.
    bpy.ops.export_scene.gltf(filepath=str(ROOT/(name+'.glb')),export_format='GLB',export_yup=True,export_apply=True)
    print('DESIGNED',name,flush=True)
