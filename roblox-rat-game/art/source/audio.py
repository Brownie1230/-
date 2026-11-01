"""Synthesize trailer soundtrack (music + SFX) synced to trailer.html timings."""
import wave
import numpy as np

SR = 44100
DUR = 22.0
N = int(SR * DUR)
L = np.zeros(N)
R = np.zeros(N)
rng = np.random.default_rng(42)
BEAT = 0.5  # 120 BPM


def note_freq(name):
    names = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3, "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}
    n, o = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((names[n] + (o - 4) * 12) / 12)


def place(sig, t, gain=1.0, pan=0.0):
    i = int(t * SR)
    if i >= N:
        return
    sig = sig[: N - i] * gain
    L[i : i + len(sig)] += sig * (1 - max(0, pan))
    R[i : i + len(sig)] += sig * (1 + min(0, pan))


def env(n, a=0.005, d=0.1, s=0.0, r=0.05, length=None):
    t = np.arange(n) / SR
    e = np.ones(n)
    e = np.where(t < a, t / a, e)
    if length is None:
        length = n / SR
    dec = np.exp(-(t - a) / max(d, 1e-4)) * (1 - s) + s
    e = np.where(t >= a, dec, e)
    rel_start = length - r
    e = np.where(t > rel_start, e * np.clip((length - t) / r, 0, 1), e)
    return e


def osc(freq, dur, kind="sine", vib=0.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = freq * (1 + vib * np.sin(2 * np.pi * 6 * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    if kind == "sine":
        return np.sin(ph)
    if kind == "square":
        return np.sign(np.sin(ph)) * 0.6
    if kind == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1) - 1
    if kind == "tri":
        return 2 * np.abs(2 * ((ph / (2 * np.pi)) % 1) - 1) - 1
    raise ValueError(kind)


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    prev = 0.0
    for i in range(len(x)):
        prev = (1 - a) * x[i] + a * prev
        y[i] = prev
    return y


def noise(dur):
    return rng.uniform(-1, 1, int(dur * SR))


# ---------- drums ----------
def kick():
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    f = 140 * np.exp(-t * 18) + 45
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 9) * 1.0


def clap():
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    x = noise(0.25) * np.exp(-t * 22)
    x[: int(0.01 * SR)] *= 0.5
    return x * 0.5


def hat(open_=False):
    d = 0.18 if open_ else 0.05
    n = int(d * SR)
    t = np.arange(n) / SR
    x = noise(d)
    x = x - lowpass(x, 6000)
    return x * np.exp(-t * (12 if open_ else 70)) * 0.35


def snare():
    n = int(0.2 * SR)
    t = np.arange(n) / SR
    return (noise(0.2) * 0.7 + np.sin(2 * np.pi * 190 * t) * 0.5) * np.exp(-t * 20) * 0.5


def crash():
    d = 1.8
    t = np.arange(int(d * SR)) / SR
    x = noise(d)
    x = x - lowpass(x, 4000)
    return x * np.exp(-t * 2.2) * 0.45


# ---------- instruments ----------
def pluck(freq, dur=0.25, gain=1.0):
    x = osc(freq, dur, "tri") * 0.7 + osc(freq * 2, dur, "sine") * 0.2
    return x * env(len(x), 0.003, 0.08, 0, 0.03) * gain


def bass(freq, dur):
    x = osc(freq, dur, "saw") * 0.6 + osc(freq / 2, dur, "sine") * 0.6
    x = lowpass(x, 700)
    return x * env(len(x), 0.005, 0.25, 0.4, 0.05)


def lead(freq, dur):
    x = osc(freq, dur, "square", vib=0.004) * 0.5 + osc(freq * 2, dur, "tri") * 0.15
    x = lowpass(x, 3500)
    return x * env(len(x), 0.01, 0.2, 0.5, 0.06)


def chord(freqs, dur, kind="saw", gain=0.25):
    x = sum(osc(f, dur, kind, vib=0.003) for f in freqs)
    x = lowpass(x, 2500)
    return x * env(len(x), 0.02, 0.6, 0.6, 0.4) * gain


# ---------- SFX ----------
def whoosh(dur=0.4, up=True):
    t = np.arange(int(dur * SR)) / SR
    x = noise(dur)
    cut = np.linspace(300, 5000, len(x)) if up else np.linspace(5000, 300, len(x))
    y = np.zeros_like(x)
    prev = 0.0
    for i in range(len(x)):
        a = np.exp(-2 * np.pi * cut[i] / SR)
        prev = (1 - a) * x[i] + a * prev
        y[i] = prev
    return y * np.sin(np.pi * t / dur) * 1.4


def pop(freq=600):
    t = np.arange(int(0.12 * SR)) / SR
    f = freq * np.exp(-t * 25) + freq * 0.5
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 30)


def squeak():
    t = np.arange(int(0.22 * SR)) / SR
    f = 2600 + 900 * np.sin(np.pi * t / 0.22) + 200 * np.sin(2 * np.pi * 28 * t)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / 0.22) * 0.5


def boom():
    t = np.arange(int(0.9 * SR)) / SR
    f = 90 * np.exp(-t * 6) + 30
    low = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 4)
    nz = lowpass(noise(0.9), 1500) * np.exp(-t * 6) * 2
    return (low + nz) * 0.9


def sparkle(t0, count=14):
    for k in range(count):
        f = rng.uniform(1800, 4200)
        place(osc(f, 0.18, "sine") * env(int(0.18 * SR), 0.002, 0.05), t0 + rng.uniform(0, 0.8), 0.12, rng.uniform(-0.8, 0.8))


def thump():
    t = np.arange(int(0.18 * SR)) / SR
    return np.sin(2 * np.pi * 55 * t) * np.exp(-t * 18)


def blip(freq):
    x = osc(freq, 0.12, "square") * env(int(0.12 * SR), 0.002, 0.05)
    return x * 0.5


def ding(freq=1568):
    d = 0.8
    x = osc(freq, d, "sine") + 0.4 * osc(freq * 2.01, d, "sine")
    return x * env(len(x), 0.002, 0.3) * 0.5


def siren(t0, t1):
    d = t1 - t0
    t = np.arange(int(d * SR)) / SR
    f = 700 + 350 * np.sin(2 * np.pi * 2.0 * t)
    x = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.25
    x = lowpass(x, 2500)
    place(x * np.clip(t / 0.2, 0, 1), t0, 0.35)


# ================= MUSIC =================
# прогрессия Am F C G (по 2 доли)
prog = [("A2", ["A3", "C4", "E4"]), ("F2", ["F3", "A3", "C4"]), ("C3", ["C4", "E4", "G4"]), ("G2", ["G3", "B3", "D4"])]

# Интро 0–3: крадущиеся щипки
sneak = ["A3", "C4", "E4", "C4", "D4", "E4", "C4", "B3", "A3", "E3", "A3", "B3"]
for i, nm in enumerate(sneak):
    place(pluck(note_freq(nm), 0.2), i * 0.25, 0.45, -0.2 if i % 2 else 0.2)
for i in range(6):
    place(hat(), i * 0.5 + 0.25, 0.5)

# Грув 3–16
melody = [
    ("E5", 0.5), ("A5", 0.5), ("G5", 0.25), ("E5", 0.25), ("D5", 0.5),
    ("C5", 0.5), ("D5", 0.25), ("E5", 0.25), ("C5", 0.5), ("A4", 0.5),
    ("G4", 0.5), ("C5", 0.5), ("E5", 0.25), ("D5", 0.25), ("C5", 0.5),
    ("B4", 0.5), ("D5", 0.5), ("G5", 0.5), ("B4", 0.5),
]
t = 3.0
while t < 16.0 - 1e-6:
    bi = int(round((t - 3.0) / BEAT))
    place(kick(), t, 0.9)
    if bi % 2 == 1:
        place(clap(), t, 0.7)
    place(hat(), t + 0.25, 0.6, 0.3)
    place(hat(), t, 0.3, -0.3)
    if bi % 4 == 0:
        root, ch = prog[(bi // 4) % 4]
        place(bass(note_freq(root), 1.9), t, 0.45)
        place(chord([note_freq(n) for n in ch], 1.9, "saw", 0.07), t, 1.0)
    t += BEAT
# мелодия (дважды)
for start in (4.0, 10.0):
    tt = start
    for nm, d in melody:
        if tt >= 15.9:
            break
        place(lead(note_freq(nm), d * 0.95), tt, 0.22, 0.1)
        tt += d

# Нагнетание 16–17.8: дробь и сирена
roll_t = 16.0
step = 0.25
while roll_t < 17.8:
    place(snare(), roll_t, 0.45 + (roll_t - 16) * 0.2)
    place(kick(), roll_t, 0.5) if abs((roll_t - 16.0) % 0.5) < 1e-6 else None
    roll_t += step
    step = max(0.0625, step * 0.86)
siren(16.0, 17.8)

# Победа 17.8: крэш и фанфары (мажор)
place(crash(), 17.8, 1.0)
place(boom(), 17.8, 0.8)
fan = [("A4", 0.0, 0.25), ("C#5", 0.25, 0.25), ("E5", 0.5, 0.25), ("A5", 0.75, 0.6)]
for nm, off, d in fan:
    place(lead(note_freq(nm), d), 17.8 + off, 0.3)
place(chord([note_freq(n) for n in ["A3", "C#4", "E4", "A4"]], 1.2, "saw", 0.12), 17.8, 1.0)
for k in range(2):
    place(kick(), 18.3 + k * 0.25, 0.8)

# Финал 19–22
place(crash(), 19.0, 0.8)
place(kick(), 19.0, 1.0)
place(chord([note_freq(n) for n in ["C3", "G3", "C4", "E4", "G4"]], 3.0, "saw", 0.12), 19.0, 1.0)
for i, nm in enumerate(["C5", "E5", "G5", "C6"]):
    place(lead(note_freq(nm), 0.22), 19.0 + i * 0.12, 0.2)
place(bass(note_freq("C2"), 2.9), 19.0, 0.5)
for i in range(5):
    place(kick(), 19.5 + i * 0.5, 0.6)
    place(hat(True), 19.75 + i * 0.5, 0.4)

# ================= SFX =================
# появления надписей
for tin in [0.25, 0.55, 3.1, 3.35, 6.65, 6.9, 10.6, 13.1, 13.3, 16.1, 17.8, 19.1, 19.35, 19.6, 19.8]:
    place(whoosh(0.18, True), max(0, tin - 0.12), 0.35)
    place(pop(700), tin + 0.05, 0.35)
# переходы-вспышки
for c in [3.0, 6.5, 10.5, 13.0, 16.0, 19.0]:
    place(whoosh(0.35, False), c - 0.05, 0.3)
place(squeak(), 0.9, 0.5, 0.2)
place(squeak(), 2.2, 0.4, -0.2)
# бег крысы: лапки
for i in range(12):
    place(pop(1200 + (i % 2) * 200), 3.05 + i * 0.13, 0.12)
# взрыв торта
place(boom(), 5.0, 1.0)
sparkle(5.0)
place(ding(1318), 5.45, 0.4)
# погоня
for k in range(6):
    tb = 6.5 + (k + 0.25) / 1.6
    if tb < 10.4:
        place(thump(), tb, 0.9)
        place(thump(), tb + 0.16, 0.6)
place(whoosh(0.3, True), 8.45, 0.9)
place(boom(), 8.75, 0.6)
place(squeak(), 8.6, 0.6, 0.4)
for i in range(8):
    place(pop(1300 + (i % 2) * 250), 8.95 + i * 0.11, 0.12)
# мини-игра: провода
for i in range(4):
    place(blip(note_freq(["C5", "E5", "G5", "C6"][i])), 11.4 + i * 0.38, 0.5)
place(ding(2093), 12.7, 0.6)
# шапки
for i in range(6):
    place(pop(500 + i * 120), 13.0 + i * 0.5, 0.5)
    sparkle(13.0 + i * 0.5, 4)
# финальный "дзынь"
place(ding(1568), 19.6, 0.5)
place(ding(2093), 19.75, 0.4)

# ================= MIX =================
mix = np.stack([L, R], axis=1)
mix = np.tanh(mix * 1.1)
mix /= np.max(np.abs(mix)) + 1e-9
mix *= 0.89
fade = int(0.6 * SR)
mix[-fade:] *= np.linspace(1, 0, fade)[:, None]
pcm = (mix * 32767).astype(np.int16)
with wave.open("soundtrack.wav", "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print("ok", pcm.shape)
