import sys, json, wave, numpy as np
import audio as A   # переиспользуем синтезаторы (модуль заодно пересоздаёт soundtrack.wav)
lang = sys.argv[1]
SR = A.SR
tl = json.load(open(f'tt/timeline_{lang}.json')); SC = tl['scenes']; TOTAL = tl['total']
N = int(TOTAL * SR); L = np.zeros(N); R = np.zeros(N)
def place(sig, t, g=1.0, pan=0.0):
    i = int(t * SR)
    if i >= N: return
    sig = sig[:N - i] * g
    L[i:i+len(sig)] += sig * (1 - max(0, pan)); R[i:i+len(sig)] += sig * (1 + min(0, pan))
S = [s['start'] for s in SC]
nf = A.note_freq
prog = [("A2", ["A3","C4","E4"]), ("F2", ["F3","A3","C4"]), ("C3", ["C4","E4","G4"]), ("G2", ["G3","B3","D4"])]
# бит по всему ролику (тише в начале, полный с 2-й сцены, мажорный финал)
t = 0.0; bi = 0
while t < S[7] - 1e-6:
    full = t >= S[1]
    place(A.kick(), t, 0.7 if full else 0.35)
    if bi % 2 == 1 and full: place(A.clap(), t, 0.5)
    place(A.hat(), t + 0.25, 0.4, 0.3)
    if bi % 4 == 0:
        root, ch = prog[(bi // 4) % 4]
        place(A.bass(nf(root), 1.9), t, 0.35)
        place(A.chord([nf(n) for n in ch], 1.9, "saw", 0.05), t, 1.0)
    t += 0.5; bi += 1
place(A.crash(), S[7], 0.6)
place(A.chord([nf(n) for n in ["C3","G3","C4","E4","G4"]], TOTAL - S[7], "saw", 0.1), S[7], 1.0)
place(A.bass(nf("C2"), TOTAL - S[7]), S[7], 0.4)
for k in range(int((TOTAL - S[7]) / 0.5)):
    place(A.kick(), S[7] + k * 0.5, 0.5); place(A.hat(True), S[7] + k * 0.5 + 0.25, 0.3)
# эффекты
for s in S[1:]: place(A.whoosh(0.3, False), s - 0.05, 0.3)
place(A.boom(), S[1] + 2.2, 0.8)
for k in range(10): place(A.pop(1200 + (k % 2) * 200), S[1] + 0.1 + k * 0.17, 0.1)
place(A.whoosh(0.3, True), S[2] + 1.75, 0.7); place(A.boom(), S[2] + 2.05, 0.5); place(A.squeak(), S[2] + 1.9, 0.5)
for k in range(3): place(A.thump(), S[2] + 0.3 + k / 1.6, 0.8); place(A.thump(), S[2] + 0.46 + k / 1.6, 0.5)
for h in [0.5, 1.3, 2.1]: place(A.boom(), S[3] + h, 0.35); place(A.ding(1568), S[3] + h + 0.1, 0.35)
for k, f in enumerate([1568, 1976, 2349, 3136]): place(A.ding(f), S[4] + 1.05 + k * 0.08, 0.4)
place(A.pop(600), S[5] + 0.95, 0.6)
for k, f in enumerate([1319, 1568, 2093]): place(A.ding(f), S[5] + 1.0 + k * 0.07, 0.45)
for k in range(28): place(A.ding(1800 + (k % 6) * 180), S[5] + 1.25 + k * 0.05, 0.18, (k % 3 - 1) * 0.5)
place(A.crash(), S[5] + 1.25, 0.6)
place(A.boom(), S[5] + 1.25, 0.5)
place(A.pop(500), S[6] + 0.9, 0.6); place(A.ding(2093), S[6] + 1.0, 0.5)
for nm, off in [("C5", 0), ("E5", 0.12), ("G5", 0.24), ("C6", 0.36)]: place(A.lead(nf(nm), 0.22), S[6] + 1.45 + off, 0.2)
music = np.stack([L, R], 1)
# голос
def readwav(p):
    w = wave.open(p); sr = w.getframerate()
    x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(float) / 32767
    return np.interp(np.arange(int(len(x) * SR / sr)) * sr / SR, np.arange(len(x)), x)
voice = np.zeros(N)
for i, sc in enumerate(SC):
    v = readwav(f'tt/{lang}_{i}.wav'); v = v - A.lowpass(v, 110)
    v = v / (np.abs(v).max() + 1e-9); v = np.tanh(v * 1.8) / np.tanh(1.8)
    s = int(sc['voice'] * SR); e = min(N, s + len(v)); voice[s:e] += v[:e - s]
env = A.lowpass(np.abs(voice), 6.0); env /= env.max() + 1e-9
gain = 1 - 0.7 * np.clip(env * 3, 0, 1)
music = music / (np.abs(music).max() + 1e-9) * 0.75
mix = music * gain[:, None] + voice[:, None] * 0.95
mix = np.tanh(mix * 1.05); mix = mix / (np.abs(mix).max() + 1e-9) * 0.9
f = int(0.5 * SR); mix[-f:] *= np.linspace(1, 0, f)[:, None]
w = wave.open(f'tt/audio_{lang}.wav', 'wb'); w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
w.writeframes((mix * 32767).astype(np.int16).tobytes()); w.close(); print('ok', lang, TOTAL)
