"""Download checksum-verified CC0 source assets, preserving source metadata."""
import json, pathlib, subprocess, hashlib
root=pathlib.Path('/tmp/afterlight-environment')
for name in ['coastal_cliff_01','island_tree_01','pine_sapling_small']:
    folder=root/name;folder.mkdir(parents=True,exist_ok=True)
    api=folder/'files.json'
    subprocess.run(['curl','-sSL','--fail','-A','TurboRacer asset research',f'https://api.polyhaven.com/files/{name}','-o',str(api)],check=True)
    files=json.loads(api.read_text());asset=files['gltf']['1k']['gltf']
    for path,info in [(name+'.gltf',asset),*asset.get('include',{}).items()]:
        target=folder/path;target.parent.mkdir(parents=True,exist_ok=True)
        subprocess.run(['curl','-sSL','--fail',info['url'],'-o',str(target)],check=True)
        assert hashlib.md5(target.read_bytes()).hexdigest()==info['md5'],target
    print(name,'verified',flush=True)
