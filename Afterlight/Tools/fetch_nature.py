"""Fetch CC0 Poly Haven nature models (1k glTF) with checksum verification.
Usage: python3 fetch_nature.py /tmp/afterlight-nature
Then convert with Blender: prepare_nature.py.
"""
import argparse, concurrent.futures, hashlib, json, pathlib, subprocess
NAMES = ['jacaranda_tree', 'island_tree_02', 'quiver_tree_01', 'quiver_tree_02', 'coast_rocks_01', 'coast_land_rocks_02',
         'namaqualand_boulder_02', 'namaqualand_boulder_05', 'namaqualand_cliff_01', 'rock_moss_set_01', 'boulder_01',
         'dead_tree_trunk_02', 'shrub_02', 'shrub_04', 'tree_stump_01', 'rock_face_01']
parser = argparse.ArgumentParser(); parser.add_argument('destination', type=pathlib.Path); args = parser.parse_args()
def fetch(name):
    folder = args.destination/name; folder.mkdir(parents=True, exist_ok=True)
    api = folder/'files.json'
    subprocess.run(['curl', '-sSfL', f'https://api.polyhaven.com/files/{name}', '-o', str(api)], check=True)
    asset = json.loads(api.read_text())['gltf']['1k']['gltf']
    for relative, info in [(name+'.gltf', asset), *asset.get('include', {}).items()]:
        target = folder/relative; target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists() or hashlib.md5(target.read_bytes()).hexdigest() != info['md5']:
            subprocess.run(['curl', '-sSfL', info['url'], '-o', str(target)], check=True)
        assert hashlib.md5(target.read_bytes()).hexdigest() == info['md5'], target
    return name
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    for name in pool.map(fetch, NAMES): print('Verified', name, flush=True)
