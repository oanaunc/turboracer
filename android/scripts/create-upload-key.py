#!/usr/bin/env python3
"""Create a unique Afterlight upload key outside the repository. Never replaces keys."""
import json,os,pathlib,secrets,subprocess
folder=pathlib.Path.home()/'.local/share/afterlight/android-upload';folder.mkdir(parents=True,exist_ok=True,mode=0o700)
config=folder/'signing.json';keystore=folder/'upload.keystore'
if config.exists() or keystore.exists():raise SystemExit('Signing files already exist; preserve the current upload key.')
password=secrets.token_urlsafe(32);env=dict(os.environ,AFTERLIGHT_NEW_KEY_PASSWORD=password)
jdk=pathlib.Path('/Applications/Android Studio.app/Contents/jbr/Contents/Home')
subprocess.run([str(jdk/'bin/keytool'),'-genkeypair','-keystore',str(keystore),'-alias','upload','-keyalg','RSA','-keysize','3072','-validity','10000','-storepass:env','AFTERLIGHT_NEW_KEY_PASSWORD','-keypass:env','AFTERLIGHT_NEW_KEY_PASSWORD','-dname','CN=Afterlight Racing Festival, O=Oana Rinaldi, C=RO'],env=env,check=True)
keystore.chmod(0o600)
with config.open('x') as out:json.dump(dict(keystore=str(keystore),storePassword=password,keyPassword=password,alias='upload'),out)
config.chmod(0o600);print('Created Afterlight upload key outside Git.')
