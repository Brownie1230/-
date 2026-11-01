import sys, json, wave, numpy as np
import audio as A
lang = sys.argv[1]
SR = A.SR
tl = json.load(open(f'dn/timeline_{lang}.json')); SC = tl['scenes']; TOTAL = tl['total']
N = int(TOTAL * SR); L = np.zeros(N); R = np.zeros(N)
def place(sig, t, g=1.0, pan=0.0):
    i = int(t * SR)
    if i >= N or i < 0: return
    sig = sig[:N - i] * g
    L[i:i+len(sig)] += sig * (1 - max(0, pan)); R[i:i+len(sig)] += sig * (1 + min(0, pan))
nf = A.note_freq
B = 60 / 128
S = [s['start'] for s in SC]
turn = SC[1]['voice'] - 0.2            # повар поворачивается — музыка обрывается
resume = S[2]
def stab(freqs, dur=0.18, g=0.12):
    x = sum(A.osc(f, dur, "saw") for f in freqs); x = A.lowpass(x, 3000)
    return x * A.env(len(x), 0.003, 0.08, 0.2, 0.04) * g
chords = [["A3","C4","E4"], ["F3","A3","C4"], ["G3","B3","D4"], ["E3","G#3","B3"]]
bassline = ["A1","A2","A1","A2","F1","F2","F1","F2","G1","G2","G1","G2","E1","E2","E1","E2"]
t = 0.0; k = 0
while t < TOTAL - 0.3:
    silent = turn <= t < resume - 0.02
    if not silent:
        full = t >= S[1] - 0.01
        place(A.kick(), t, 0.85)
        place(A.hat(True), t + B / 2, 0.35, 0.3)
        place(A.hat(), t + B / 4, 0.2, -0.3); place(A.hat(), t + 3 * B / 4, 0.2, -0.3)
        if k % 2 == 1: place(A.clap(), t, 0.6)
        bn = bassline[(k * 2) % 16]; bn2 = bassline[(k * 2 + 1) % 16]
        place(A.bass(nf(bn), B / 2 * 0.9), t, 0.5); place(A.bass(nf(bn2), B / 2 * 0.9), t + B / 2, 0.45)
        if full or k % 2 == 1:
            place(stab([nf(n) for n in chords[(k // 4) % 4]]), t + B / 2, 1.0)
        if full and k % 8 == 7:
            for j, nm in enumerate(["E5", "G5", "A5", "C6"]): place(A.lead(nf(nm), 0.1), t + j * B / 4, 0.12)
    t += B; k += 1
# эффекты
place(A.whoosh(0.4, False), turn - 0.3, 0.6)          # «скрип пластинки»
place(A.boom(), turn, 1.0); place(A.crash(), turn, 0.4)
for s in S[1:]: place(A.whoosh(0.3, False), s - 0.05, 0.3)
# напряжение после поворота повара: сердцебиение ускоряется + нарастающий свист
hb = SC[1]['voice'] + SC[1]['vdur'] + 0.05
gap = resume - hb
tt = hb; step = 0.42
while tt < resume - 0.15:
    place(A.thump(), tt, 1.0); place(A.thump(), tt + 0.14, 0.6)
    tt += step; step = max(0.24, step * 0.85)
place(A.whoosh(min(0.9, max(0.3, gap)), True), resume - min(0.9, max(0.3, gap)), 0.8)
for j in range(3): place(A.whoosh(0.35, True), S[2] + 0.25 + j * 0.05, 0.5); place(A.squeak(), S[2] + 0.35 + j * 0.12, 0.4, (j - 1) * 0.6)
place(A.thump(), S[3] + 0.2, 0.6)
for j in range(6): place(A.thump(), S[3] + 0.4 + j * 0.42, 0.7); place(A.thump(), S[3] + 0.55 + j * 0.42, 0.45)
place(A.squeak(), SC[3]['end'] - 0.9, 0.6)
place(A.crash(), S[4], 0.7); place(A.ding(1568), S[4] + 0.5, 0.5); place(A.ding(2093), S[4] + 0.6, 0.4)
music = np.stack([L, R], 1)
def readwav(p):
    w = wave.open(p); sr = w.getframerate()
    x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(float) / 32767
    return np.interp(np.arange(int(len(x) * SR / sr)) * sr / SR, np.arange(len(x)), x)
voice = np.zeros(N)
for i, sc in enumerate(SC):
    v = readwav(f'dn/{lang}_{i}.wav'); v = v - A.lowpass(v, 110)
    v = v / (np.abs(v).max() + 1e-9); v = np.tanh(v * 1.8) / np.tanh(1.8)
    s = int(sc['voice'] * SR); e = min(N, s + len(v)); voice[s:e] += v[:e - s]
env = A.lowpass(np.abs(voice), 6.0); env /= env.max() + 1e-9
gain = 1 - 0.65 * np.clip(env * 3, 0, 1)
music = music / (np.abs(music).max() + 1e-9) * 0.8
mix = music * gain[:, None] + voice[:, None] * 0.95
mix = np.tanh(mix * 1.05); mix = mix / (np.abs(mix).max() + 1e-9) * 0.9
f = int(0.4 * SR); mix[-f:] *= np.linspace(1, 0, f)[:, None]
w = wave.open(f'dn/audio_{lang}.wav', 'wb'); w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
w.writeframes((mix * 32767).astype(np.int16).tobytes()); w.close(); print('ok', lang)
