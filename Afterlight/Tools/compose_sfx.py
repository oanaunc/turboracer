"""Synthesise Afterlight's one-shot race effects as 44.1 kHz mono WAV files.

All sounds are original and generated here from noise and oscillators:
impact (metal crunch), takedown (heavier crash with glass), nitro
(ignition whoosh), land (suspension thump), whoosh (near-miss pass-by).
Run: python3 Afterlight/Tools/compose_sfx.py
"""
import numpy as np, wave, pathlib

SR = 44100
rng = np.random.default_rng(7)
out = pathlib.Path(__file__).resolve().parents[1] / "Resources"

def t(seconds): return np.arange(int(SR*seconds))/SR
def env(x, attack, decay):
    a = np.minimum(1, x/max(attack, 1e-4)); return a*np.exp(-x/decay)
def lowpass(sig, cutoff):
    k = 1-np.exp(-2*np.pi*cutoff/SR); y = np.zeros_like(sig); acc = 0.0
    for i, s in enumerate(sig): acc += (s-acc)*k; y[i] = acc
    return y
def bandpass(sig, lo, hi): return lowpass(sig, hi)-lowpass(sig, lo)
def save(name, sig):
    sig = sig/np.max(np.abs(sig))*0.9
    with wave.open(str(out/f"{name}.wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((sig*32767).astype(np.int16).tobytes())

# Metal impact: low body thump, bright crunch and a short panel ring.
x = t(0.7); n = rng.standard_normal(len(x))
thump = np.sin(2*np.pi*(70*x-30*x*x))*env(x, 0.002, 0.09)
crunch = bandpass(n, 900, 5200)*env(x, 0.001, 0.06)
ring = sum(np.sin(2*np.pi*f*x)*a for f, a in [(612, 0.5), (1347, 0.35), (2210, 0.2)])*env(x, 0.003, 0.22)
save("impact", thump*1.2+crunch*1.4+ring*0.35)

# Takedown: two crunches, a heavier body hit and scattering glass.
x = t(1.3); n = rng.standard_normal(len(x))
hit = np.sin(2*np.pi*(55*x-18*x*x))*env(x, 0.002, 0.18)
crunch = bandpass(n, 700, 4500)*(env(x, 0.001, 0.08)+0.7*env(np.maximum(0, x-0.11), 0.001, 0.1)*(x > 0.11))
glass = np.zeros_like(x)
for _ in range(40):
    s = rng.uniform(0.05, 0.9); f = rng.uniform(3500, 9000); d = rng.uniform(0.01, 0.05)
    xs = np.maximum(0, x-s); glass += np.sin(2*np.pi*f*xs)*np.exp(-xs/d)*(x > s)*rng.uniform(0.1, 0.3)
save("takedown", hit*1.4+crunch*1.3+glass*0.6)

# Nitro ignition: rising filtered whoosh with a pop.
x = t(1.1); n = rng.standard_normal(len(x))
sweep = np.zeros_like(x); acc = 0.0
for i, s in enumerate(n):
    cutoff = 300+3500*min(1, x[i]/0.5); k = 1-np.exp(-2*np.pi*cutoff/SR); acc += (s-acc)*k; sweep[i] = acc
pop = np.sin(2*np.pi*90*x)*env(x, 0.001, 0.05)
save("nitro", sweep*env(x, 0.08, 0.5)*2+pop*0.8)

# Landing: suspension thump and tyre chirp.
x = t(0.5); n = rng.standard_normal(len(x))
save("land", np.sin(2*np.pi*(60*x-20*x*x))*env(x, 0.002, 0.12)*1.3+bandpass(n, 1200, 2600)*env(x, 0.004, 0.05)*0.9)

# Near miss: Doppler pass-by of a rival car.
x = t(0.9); n = rng.standard_normal(len(x))
d = 1/(1+((x-0.4)/0.12)**2)
tone = np.sin(2*np.pi*np.cumsum(np.where(x < 0.4, 220, 160))/SR)
save("whoosh", (bandpass(n, 300, 2000)*1.2+tone*0.3)*d)
print("wrote", [p.name for p in out.glob("*.wav")])
