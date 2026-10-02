"""Fetch CC0 botanical sources and select one complete fir for mobile conversion.
Usage: python3 fetch_vegetation.py /tmp/afterlight-environment18
Then run prepare_vegetation.py in Blender with that directory.
"""
import argparse, concurrent.futures, hashlib, json, pathlib, subprocess
parser=argparse.ArgumentParser();parser.add_argument('destination',type=pathlib.Path);args=parser.parse_args()
for name in ['fir_tree_01','shrub_01']:
    folder=args.destination/name;folder.mkdir(parents=True,exist_ok=True)
    api=folder/'files.json'
    subprocess.run(['curl','-sSfL',f'https://api.polyhaven.com/files/{name}','-o',str(api)],check=True)
    catalog=json.loads(api.read_text());asset=catalog['gltf']['1k']['gltf']
    def download(entry):
        relative,info=entry;target=folder/relative;target.parent.mkdir(parents=True,exist_ok=True)
        if not target.exists() or hashlib.md5(target.read_bytes()).hexdigest()!=info['md5']:
            subprocess.run(['curl','-sSfL',info['url'],'-o',str(target)],check=True)
        assert hashlib.md5(target.read_bytes()).hexdigest()==info['md5'],target
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(download,[(name+'.gltf',asset),*asset.get('include',{}).items()]))
    if name=='fir_tree_01':
        alpha=catalog['blend']['1k']['blend']['include']['textures/fir_tree_01_twig_alpha_1k.png']
        download(('textures/fir_tree_01_twig_alpha_1k.png',alpha))
        scene=json.loads((folder/(name+'.gltf')).read_text())
        scene['meshes']=[scene['meshes'][0]];scene['nodes']=[scene['nodes'][0]]
        scene['nodes'][0]['mesh']=0;scene['scenes']=[{'nodes':[0]}];scene['scene']=0
        (folder/'mobile.gltf').write_text(json.dumps(scene))
    print('Verified',name)
