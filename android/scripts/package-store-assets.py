#!/usr/bin/env python3
"""Make Google Play sizes from the original icon and actual Android UI captures."""
from pathlib import Path
from PIL import Image,ImageOps
root=Path(__file__).resolve().parents[2];release=root/'release/google-play';qa=release/'qa';store=release/'store-assets';store.mkdir(parents=True,exist_ok=True)
icon=Image.open(root/'Afterlight/Resources/Assets.xcassets/AppIcon.appiconset/Icon.png').convert('RGB');icon.resize((512,512),Image.Resampling.LANCZOS).save(store/'icon-512.png',optimize=True)
home=Image.open(qa/'phone-01-home.png').convert('RGB');ImageOps.fit(home,(1024,500),Image.Resampling.LANCZOS).save(store/'feature-1024x500.png',optimize=True)
for prefix in ['phone','tablet']:
 folder=store/prefix;folder.mkdir(exist_ok=True)
 for source,name in [('01-home','01-paddock'),('02-garage','02-garage'),('04-world','03-world-tour'),('03-story','04-crew'),('06-race','05-racing'),('08-results','06-results')]:
  file=qa/f'{prefix}-{source}.png';assert file.is_file(),f'Missing actual runtime capture: {file}'
  image=Image.open(file).convert('RGB');assert max(image.size)<=3840
  image.save(folder/f'{name}.png',optimize=True)
print('Prepared original icon, 1024×500 feature graphic, six phone and six tablet screenshots.')
