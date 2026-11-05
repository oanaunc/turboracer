#!/usr/bin/env python3
"""Build signed Android artifacts without printing signing credentials."""
import pathlib,os,subprocess,json,hashlib,sys,shutil
root=pathlib.Path(__file__).resolve().parents[2];project=root/'android'
subprocess.run([sys.executable,str(project/'scripts/sync-ios-content.py'),'--check'],check=True)
subprocess.run(['node','--test',str(project/'tests/engine.test.mjs')],check=True)
manifest=project/'generated/art-manifest.json'
if not manifest.is_file():raise SystemExit('Export and package the original Apple scenes first.')
art=json.loads(manifest.read_text())
if art['sceneRoutes']!=20 or art['carModels']!=12:raise SystemExit('Incomplete scene export')
c=json.loads((pathlib.Path.home()/'.local/share/afterlight/android-upload/signing.json').read_text());env=dict(os.environ)
for field,var in [('keystore','AFTERLIGHT_KEYSTORE'),('storePassword','AFTERLIGHT_STORE_PASSWORD'),('keyPassword','AFTERLIGHT_KEY_PASSWORD'),('alias','AFTERLIGHT_KEY_ALIAS')]:env[var]=c[field]
env.setdefault('JAVA_HOME','/Applications/Android Studio.app/Contents/jbr/Contents/Home');env.setdefault('ANDROID_HOME',str(pathlib.Path.home()/'Library/Android/sdk'))
subprocess.run([str(project/'gradlew'),'-p',str(project),':app:bundleRelease',':app:lintRelease'],env=env,check=True)
folder=root/'release/google-play';folder.mkdir(exist_ok=True,parents=True)
report={'package':'com.oanarinaldi.afterlight','versionName':'1.0.0','versionCode':1,'art':art}
source=hashlib.sha256()
for file in sorted(list((project/'web').rglob('*'))+list((project/'app/src/main').rglob('*'))):
 if file.is_file():source.update(str(file.relative_to(project)).encode());source.update(file.read_bytes())
report['sourceSHA256']=source.hexdigest()
src=project/'app/build/outputs/bundle/release/app-release.aab';name='Afterlight-1.0.0-1.aab';shutil.copyfile(src,folder/name);report['aab']={'file':name,'sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'bytes':src.stat().st_size}
(folder/'build-info.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
