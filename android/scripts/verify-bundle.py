#!/usr/bin/env python3
"""Validate the signed Play AAB and make a device-specific production APK set.
Usage: python3 android/scripts/verify-bundle.py /path/to/official/bundletool.jar emulator-5660
"""
import json,pathlib,subprocess,os,sys,zipfile,hashlib,tempfile
root=pathlib.Path(__file__).resolve().parents[2];folder=root/'release/google-play'
aab=folder/'Afterlight-1.0.0-1.aab';info=json.loads((folder/'build-info.json').read_text())
assert hashlib.sha256(aab.read_bytes()).hexdigest()==info['aab']['sha256']
java='/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/java';jar=pathlib.Path(sys.argv[1]).resolve();device=sys.argv[2]
subprocess.run([java,'-jar',str(jar),'validate','--bundle='+str(aab)],check=True,stdout=subprocess.DEVNULL)
manifest=subprocess.check_output([java,'-jar',str(jar),'dump','manifest','--bundle='+str(aab),'--module=base'],text=True)
assert 'targetSdkVersion="36"' in manifest and 'minSdkVersion="29"' in manifest
assert 'android.permission.INTERNET' not in manifest and 'AD_ID' not in manifest
assert 'android:debuggable="true"' not in manifest
art=subprocess.check_output([java,'-jar',str(jar),'dump','manifest','--bundle='+str(aab),'--module=festival_art'],text=True)
assert 'install-time' in art
(folder/'AndroidManifest-release.xml').write_text(manifest)
(folder/'festival-art-manifest.xml').write_text(art)
subprocess.run(['/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/jarsigner','-verify',str(aab)],check=True,stdout=subprocess.DEVNULL)
c=json.loads((pathlib.Path.home()/'.local/share/afterlight/android-upload/signing.json').read_text());env=dict(os.environ)
env['ANDROID_HOME']=str(pathlib.Path.home()/'Library/Android/sdk')
output=root/'build/Afterlight-production.apks'
with tempfile.TemporaryDirectory(prefix='afterlight-signing-') as temp:
 store=pathlib.Path(temp)/'store';key=pathlib.Path(temp)/'key'
 for file,field in [(store,'storePassword'),(key,'keyPassword')]:file.write_text(c[field]);file.chmod(0o600)
 subprocess.run([java,'-jar',str(jar),'build-apks','--bundle='+str(aab),'--output='+str(output),'--overwrite','--connected-device','--device-id='+device,'--ks='+c['keystore'],'--ks-key-alias='+c['alias'],'--ks-pass=file:'+str(store),'--key-pass=file:'+str(key)],env=env,check=True)
with zipfile.ZipFile(output) as files:
 apks=files.namelist();assert any('festival_art' in p and p.endswith('.apk') for p in apks)
report={'bundleValidated':True,'jarSignatureVerified':True,'targetSdk':36,'minSdk':29,'debuggable':False,'internetPermission':False,'installTimeAssetPack':True,'apkSet':'build/Afterlight-production.apks','apkEntries':apks}
(folder/'bundle-validation.json').write_text(json.dumps(report,indent=2)+'\n');print('Verified signed production bundle and install-time asset split.')
