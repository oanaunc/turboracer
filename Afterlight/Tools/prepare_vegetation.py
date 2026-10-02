"""Create mobile CC0 vegetation while preserving canopy volume.
Blender: -b --python prepare_vegetation.py -- SOURCE_DIRECTORY [--only AlpineFir]
Fetch verified sources with fetch_vegetation.py first. Fir needles become grouped
alpha-cutout fronds; simplifying millions of individual needles erases the canopy.
"""
import bpy, pathlib, sys, argparse, json, math
import numpy as np
from mathutils import Vector
parser=argparse.ArgumentParser();parser.add_argument('source',type=pathlib.Path);parser.add_argument('--only',choices=['AlpineFir','CoastalShrub'])
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:]);source=args.source
root=pathlib.Path(__file__).resolve().parents[1]/'Resources'/'Models'
for name,relative,budget in [('AlpineFir','fir_tree_01/mobile.gltf',12000),('CoastalShrub','shrub_01/shrub_01.gltf',18000)]:
    if args.only and name!=args.only: continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    path=source/relative;clusters=None
    if name=='AlpineFir':
        doc=json.loads(path.read_text());primitive=next(p for p in doc['meshes'][0]['primitives'] if doc['materials'][p['material']]['name']=='fir_tree_01_twig')
        accessor=doc['accessors'][primitive['attributes']['POSITION']];view=doc['bufferViews'][accessor['bufferView']]
        blob=(path.parent/doc['buffers'][view['buffer']]['uri']).read_bytes()
        points=np.ndarray((accessor['count'],3),dtype='<f4',buffer=blob,offset=view.get('byteOffset',0)+accessor.get('byteOffset',0),strides=(view.get('byteStride',12),4))[::32]
        cells=np.floor(points/1.15).astype(np.int32);_,groups=np.unique(cells,axis=0,return_inverse=True)
        counts=np.bincount(groups);clusters=np.stack([np.bincount(groups,weights=points[:,i])/counts for i in range(3)],axis=1)
        doc['meshes'][0]['primitives']=[p for p in doc['meshes'][0]['primitives'] if p is not primitive]
        path=path.parent/'branches.gltf';path.write_text(json.dumps(doc))
    bpy.ops.import_scene.gltf(filepath=str(path))
    objects=[o for o in bpy.data.objects if o.type=='MESH'];total=sum(len(o.data.polygons) for o in objects)
    for obj in objects:
        if len(obj.data.polygons)>100:
            bpy.context.view_layer.objects.active=obj
            mod=obj.modifiers.new('Mobile branch budget','DECIMATE');mod.ratio=min(1,budget/total)
            bpy.ops.object.modifier_apply(modifier=mod.name)
    if clusters is not None:
        mat=bpy.data.materials.new('FirNeedleCutout');mat.use_nodes=True;mat.use_backface_culling=False;mat.surface_render_method='DITHERED'
        nodes=mat.node_tree.nodes;links=mat.node_tree.links;bsdf=nodes.get('Principled BSDF');bsdf.inputs['Roughness'].default_value=.9
        for filename,socket in [('fir_tree_01_twig_diff_1k.jpg','Base Color'),('fir_tree_01_twig_alpha_1k.png','Alpha')]:
            tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(source/'fir_tree_01'/'textures'/filename))
            if socket=='Alpha':tex.image.colorspace_settings.name='Non-Color'
            links.new(tex.outputs['Color'],bsdf.inputs[socket])
        vertices=[];faces=[];coords=[]
        for i,p in enumerate(clusters):
            center=Vector((p[0],-p[2],p[1]));angle=math.atan2(center.y,center.x)+i*2.399
            # Two cupped fronds per occupied source canopy cell, with offset normals.
            for layer in range(2):
                a=angle+layer*math.pi/2;right=Vector((math.cos(a),math.sin(a),.18));up=Vector((-.18*math.sin(a),.18*math.cos(a),1))
                span=.85+(i%4)*.12
                first=len(vertices)
                for x,y in [(-1,-1),(1,-1),(1,1),(-1,1)]:vertices.append(tuple(center+right*x*span+up*y*span*.72))
                faces.append((first,first+1,first+2,first+3))
                x0=.19 if i%2==0 else .58;y0=.30 if i%3==0 else .65
                coords.extend([(x0,y0),(x0+.37,y0),(x0+.37,y0+.32),(x0,y0+.32)])
        mesh=bpy.data.meshes.new('Clustered fir fronds');mesh.from_pydata(vertices,[],faces);mesh.materials.append(mat);uv=mesh.uv_layers.new()
        for i,loop in enumerate(uv.data):loop.uv=coords[i]
        obj=bpy.data.objects.new('Canopy',mesh);bpy.context.collection.objects.link(obj)
        print('Canopy clusters',len(clusters),flush=True)
    output=root/(name+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',export_yup=True,export_apply=True)
    # SceneKit and glTF both support binary alpha cutout with depth writes. Avoid
    # sorting thousands of translucent foliage cards behind opaque trunks.
    if name=='AlpineFir':
        import struct
        blob=output.read_bytes();length=struct.unpack_from('<I',blob,12)[0];doc=json.loads(blob[20:20+length])
        for material in doc['materials']:
            if material.get('name')=='FirNeedleCutout':material['alphaMode']='MASK';material['alphaCutoff']=.3
        encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4);tail=blob[20+length:]
        output.write_bytes(struct.pack('<III',0x46546c67,2,20+len(encoded)+len(tail))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+tail)
    print('PREPARED',name,flush=True)
