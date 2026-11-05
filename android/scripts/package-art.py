#!/usr/bin/env python3
"""Package private Apple scene exports with AES-GCM; plaintext stays outside Git."""
import pathlib,json,os,sys,shutil,hashlib,zlib
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from PIL import Image
root=pathlib.Path(__file__).resolve().parents[2]
source=pathlib.Path(sys.argv[1]);out=root/'android/festival_art/src/main/assets/art';out.mkdir(parents=True,exist_ok=True)
assert (source/'library.json').is_file(),'Scene export must finish before packaging'
private=pathlib.Path.home()/'.local/share/afterlight/android-art';private.mkdir(parents=True,exist_ok=True,mode=0o700)
keyfile=private/'asset-key.bin'
if not keyfile.exists():
    with keyfile.open('xb') as file:file.write(os.urandom(32))
    keyfile.chmod(0o600)
key=keyfile.read_bytes();aes=AESGCM(key)
java=root/'android/generated/java/com/oanarinaldi/afterlight/GeneratedAssetKey.java';java.parent.mkdir(parents=True,exist_ok=True)
java.write_text('package com.oanarinaldi.afterlight; final class GeneratedAssetKey { static final byte[] KEY = new byte[] {'+','.join(str(b if b<128 else b-256) for b in key)+'}; }\n')
# Preserve alpha, but cap GPU texture size to 2048px for mobile memory.
# Export originals remain available privately for higher-end quality tiers.
from io import BytesIO
required={'library.json','studio.json'}|{f'car-{i}.json' for i in range(12)}|{f'route-{i}.json' for i in range(20)}
def references(value):
    if isinstance(value,dict):
        for name,item in value.items():
            if name in ('file','image','index') and isinstance(item,str):required.add(item)
            references(item)
    elif isinstance(value,list):
        for item in value:references(item)
for name in list(required):references(json.loads((source/name).read_text()))
count=0
for name in sorted(required):
    file=source/name
    if not file.is_file():continue
    data=file.read_bytes()
    if file.suffix=='.png':
        image=Image.open(BytesIO(data))
        if max(image.size)>2048:
            image.thumbnail((2048,2048),Image.Resampling.LANCZOS);buf=BytesIO();image.save(buf,format='PNG',optimize=True);data=buf.getvalue()
    nonce=os.urandom(12);packed=nonce+aes.encrypt(nonce,zlib.compress(data,9),None)
    target=out/(file.name+'.pack')
    target.write_bytes(packed);count+=1
for file in out.glob('*.pack'):
    if file.name[:-5] not in required:file.unlink()
media=root/'android/generated/assets/media';media.mkdir(parents=True,exist_ok=True)
resources=root/'Afterlight/Resources'
for folder,patterns in [('Music',['*.mp3']),('Circuits',['*.jpg']),('Story',['*.png']),('', ['*.wav'])]:
    for pattern in patterns:
        for file in (resources/folder).glob(pattern):shutil.copyfile(file,media/file.name)
shutil.copyfile(resources/'AssetCredits.txt',media/'AssetCredits.txt')
report={'files':count,'sourceLibrarySHA256':hashlib.sha256((source/'library.json').read_bytes()).hexdigest(),'sceneRoutes':len(list(source.glob('route-*.json'))),'carModels':len(list(source.glob('car-*.json'))),'maxTextureSize':2048}
(root/'android/generated/art-manifest.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
