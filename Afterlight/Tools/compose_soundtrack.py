"""Original deterministic 32-bar synth score. No samples or external recordings."""
import math, wave, array, pathlib, random
rate=22050; bpm=108; beat=60/bpm; bars=32; duration=bars*4*beat
samples=array.array('f',[0]) * int(duration*rate)
random.seed(42)
def note(midi): return 440*2**((midi-69)/12)
def tone(start,length,midi,volume,kind):
    begin=int(start*rate); count=int(length*rate); f=note(midi)
    for j in range(count):
        if begin+j>=len(samples): break
        t=j/rate; phase=2*math.pi*f*t; env=min(1,t/0.015)*min(1,(length-t)/0.1)
        if kind=='pad': value=(math.sin(phase)+0.3*math.sin(phase*2.002)+0.15*math.sin(phase*3))/1.45
        elif kind=='bass': value=math.sin(phase)+0.2*math.sin(phase*2)
        else: value=math.sin(phase)*math.exp(-t*6)+0.2*math.sin(phase*2)*math.exp(-t*9)
        samples[begin+j]+=value*env*volume
chords=[(45,57,60,64),(41,53,57,60),(48,60,64,67),(43,55,59,62)]
for bar in range(bars):
    chord=chords[(bar//2)%4]; start=bar*4*beat
    for n in chord[1:]: tone(start,4.2*beat,n,0.052,'pad')
    for step in range(8):
        tone(start+step*beat/2,beat*0.40,chord[0],0.12,'bass')
        tone(start+step*beat/2,beat*0.7,chord[1+step%3]+12,0.055,'bell')
    for b in range(4):
        begin=int((start+b*beat)*rate)
        for j in range(int(0.18*rate)):
            if begin+j<len(samples):
                t=j/rate; samples[begin+j]+=0.23*math.sin(2*math.pi*(48*t+6*(1-math.exp(-t*35))))*math.exp(-t*25)
    for step in range(8):
        begin=int((start+step*beat/2)*rate)
        for j in range(int(0.05*rate)):
            if begin+j<len(samples): samples[begin+j]+=(random.random()*2-1)*0.035*math.exp(-j/rate*80)
    if bar%2:
        for b in [1,3]:
            begin=int((start+b*beat)*rate)
            for j in range(int(0.12*rate)):
                if begin+j<len(samples): samples[begin+j]+=(random.random()*2-1)*0.07*math.exp(-j/rate*30)
output=pathlib.Path(__file__).resolve().parents[1]/'Resources/afterlight.wav'
with wave.open(str(output),'wb') as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
    w.writeframes(array.array('h',(int(math.tanh(v)*26000) for v in samples)).tobytes())
print(output)
# A seamless engine loop and a short collectible chime, also synthesized from scratch.
for filename,seconds in [('engine',1),('spark',0.3)]:
    frames=array.array('h')
    for j in range(int(rate*seconds)):
        t=j/rate
        if filename=='engine':
            value=(math.sin(2*math.pi*80*t)+0.4*math.sin(2*math.pi*160*t)+0.2*math.sin(2*math.pi*240*t)) * 0.16
        else: value=(math.sin(2*math.pi*880*t)+0.4*math.sin(2*math.pi*1320*t))*math.exp(-t*13)*min(1,t/0.005)*0.25
        frames.append(int(value*24000))
    with wave.open(str(output.parent/(filename+'.wav')),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(frames.tobytes())
