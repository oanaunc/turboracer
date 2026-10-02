"""Create mobile GLBs from Quaternius' CC0 Downtown City MegaKit Standard."""
import bpy,pathlib
ROOT=pathlib.Path(__file__).resolve().parents[1]/'Resources'/'Models'
SOURCE=pathlib.Path('/tmp/afterlight-citykit/Exports/glTF (Godot)')
for source,name in [('Building_Small_1','CityCorner'),('Building_Medium_2_001','CityMidrise'),('Building_Large_2','CityLandmark'),('Prop_ACUnit','CityAC'),('Prop_Planter_Single','CityPlanter')]:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(SOURCE/(source+'.gltf')))
 for image in bpy.data.images:
  if max(image.size)>1024:image.scale(1024,1024)
 bpy.ops.export_scene.gltf(filepath=str(ROOT/(name+'.glb')),export_format='GLB',export_yup=True,export_apply=True)
 print('CITY',name,flush=True)
