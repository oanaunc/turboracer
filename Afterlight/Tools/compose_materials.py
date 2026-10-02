"""Reproducible seamless original terrain, tire, and PBR micro-surface maps."""
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]/'Resources/Textures';ROOT.mkdir(exist_ok=True)
rng=np.random.default_rng(712)
N=512
# Periodic Fourier noise ensures neighboring terrain tiles join without seams.
def noise(power):
    f=np.fft.fftfreq(N); k=np.sqrt(f[:,None]**2+f[None,:]**2); k[0,0]=1
    a=rng.normal(size=(N,N)); spectrum=np.fft.fft2(a)*np.power(k,-power)
    spectrum[0,0]=0; v=np.fft.ifft2(spectrum).real
    return (v-v.mean())/(v.std()+1e-8)
def save(name,a):Image.fromarray(np.clip(a,0,255).astype('uint8')).save(ROOT/(name+'.png'))
def normal(name,h,strength):
    x=(np.roll(h,-1,1)-np.roll(h,1,1))*strength;y=(np.roll(h,-1,0)-np.roll(h,1,0))*strength
    v=np.stack([-x,-y,np.ones_like(h)],2);v/=np.linalg.norm(v,axis=2,keepdims=True)
    save(name,(v*.5+.5)*255)
for name,color,power,strength in [('sand',(153,137,106),1.1,.8),('grass',(65,76,44),.7,.5),('rock',(113,111,105),1.6,1.3),('bark',(104,83,60),1.2,.8)]:
    h=noise(power)*.6+noise(.2)*.18
    if name=='bark': h += np.sin(np.arange(N)[None,:]*.32)*.55
    save(name,np.array(color)[None,None,:]+h[:,:,None]*15)
    normal(name+'-normal',h,strength);save(name+'-roughness',np.ones((N,N))*210+h*12)
# Carbon weave and matte rubber; these are generated assets, not external samples.
y,x=np.mgrid[:N,:N];weave=((x//8+y//8)%2)*8+np.sin(x*1.5)*2+np.sin(y*1.5)*2
save('carbon',np.stack([weave+21,weave+24,weave+26],2));normal('carbon-normal',weave/24,.3)
h=noise(.15)*.1 + (((x+y//16*5)%64)<5)*.3
save('rubber',np.stack([h*15+25,h*15+26,h*15+27],2));normal('rubber-normal',h,1.2)
# Brushed metal reflects softly, unlike a flat silver diffuse material.
h=noise(.2)*.06+np.sin(y*2)*.08
normal('alloy-normal',h,.6)
# Neutral grain can be combined with a generated asphalt base-color texture.
h=noise(.15)*.3+noise(.6)*.15
normal('asphalt-normal',h,.45);save('asphalt-roughness',np.ones((N,N))*204+h*20)
# Realistic neutral road fallback until the generated base-color file is copied.
save('asphalt',np.stack([h*14+65,h*14+65,h*14+63],2))
print('Original PBR material maps generated')
h=noise(1.8)*.4+np.sin(x*.15+y*.08)*.15
normal('water-normal',h,.6)
# Original equirectangular daylight panorama for the environment and reflections.
W,H=2048,1024
yy,xx=np.mgrid[:H,:W];t=np.clip(yy/(H*.5),0,1)[:,:,None]
top=np.array([62,110,149.]);horizon=np.array([221,224,212.]);sky=top[None,None,:]*(1-t)+horizon[None,None,:]*t
sky=np.broadcast_to(sky,(H,W,3)).copy()
cloud=np.array(Image.fromarray(np.clip((noise(2.2)*.15+.5)*255,0,255).astype('uint8')).resize((W,H),Image.Resampling.BICUBIC))/255
cloud=np.clip((cloud-.51)*3.8,0,.7)*np.exp(-((yy-330)/165)**2)
sky=sky*(1-cloud[:,:,None])+np.array([243,237,221])[None,None,:]*cloud[:,:,None]
# Warm, compact sun with broad atmospheric glow.
dx=np.minimum(abs(xx-1550),W-abs(xx-1550));dist=np.sqrt(dx**2+(yy-455)**2)
glow=np.exp(-dist/80)*.26;sky=sky*(1-glow[:,:,None])+np.array([255,218,162])[None,None,:]*glow[:,:,None]
sky[dist<11]=[255,247,222]
bottom=yy>H//2;factor=np.clip((yy-H//2)/(H*.5),0,1)[:,:,None]
ground=np.array([109,115,105])[None,None,:]*(1-factor)+np.array([51,56,50])[None,None,:]*factor
sky[bottom]=ground[bottom]
save('sky-coast',sky)
# Window facade atlas, with a separate low-intensity emission mask.
facade=np.zeros((N,N,3))+[34,44,52];emission=np.zeros((N,N,3))
for row in range(12):
    for col in range(12):
        x0=col*42+6;y0=row*42+6
        lit=rng.random()<.36;color=np.array([176,151,103]) if lit else np.array([36,65,81])
        facade[y0:y0+28,x0:x0+27]=color
        if lit:emission[y0:y0+28,x0:x0+27]=color*.55
        facade[y0+13:y0+15,x0:x0+27]=[22,27,30]
        facade[y0:y0+28,x0+12:x0+14]=[22,27,30]
save('facade-night',facade);save('facade-emission',emission)
h=noise(.7)*.16
save('stucco',np.stack([h*10+216,h*10+211,h*10+194],2));normal('stucco-normal',h,.5)
# A full equirectangular night sky, preserving a cool horizon and soft clouds.
night=sky*.22+np.array([2,6,16])[None,None,:]
night[:,:,2]+=8
for _ in range(190):
    sx=int(rng.integers(W));sy=int(rng.integers(H//2-60));night[sy,sx]=[115,135,157]
save('sky-night',night)
