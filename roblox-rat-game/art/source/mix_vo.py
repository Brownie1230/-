import sys, wave, numpy as np
lang = sys.argv[1]
SR = 44100
def readwav(p):
    w = wave.open(p); sr = w.getframerate(); ch = w.getnchannels()
    x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64) / 32767
    if ch == 2: x = x.reshape(-1, 2)
    return x, sr
music, _ = readwav('soundtrack.wav')
N = len(music)
voice = np.zeros(N)
times = {'en': [0.3, 3.1, 6.65, 10.6, 13.1, 16.1, 17.85, 19.25], 'ru': [0.25, 3.05, 6.6, 10.55, 13.05, 16.05, 17.8, 19.1]}[lang]
def lp(x, fc):
    a = np.exp(-2*np.pi*fc/SR); y = np.zeros_like(x); p = 0.0
    for i in range(len(x)): p = (1-a)*x[i] + a*p; y[i] = p
    return y
for i, t in enumerate(times):
    v, sr = readwav(f'vo/{lang}_{i}.wav')
    v = np.interp(np.arange(int(len(v)*SR/sr))*sr/SR, np.arange(len(v)), v)
    v = v - lp(v, 120)                      # убрать гул
    v = v / (np.max(np.abs(v)) + 1e-9)
    v = np.tanh(v * 2.2) / np.tanh(2.2)     # компрессия, "трейлерный" голос
    d = int(0.09*SR); echo = np.zeros(len(v)+d); echo[:len(v)] += v; echo[d:] += v*0.22
    s = int(t*SR); e = min(N, s+len(echo)); voice[s:e] += echo[:e-s]
# приглушение музыки под голос
env = lp(np.abs(voice), 8.0)
env = env / (env.max() + 1e-9)
gain = 1 - 0.6*np.clip(env*3, 0, 1)
mix = music * gain[:, None] + voice[:, None] * 0.95
mix = np.tanh(mix * 1.05)
mix = mix / (np.abs(mix).max() + 1e-9) * 0.9
f = int(0.5*SR); mix[-f:] *= np.linspace(1, 0, f)[:, None]
w = wave.open(f'soundtrack_{lang}.wav', 'wb'); w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
w.writeframes((mix*32767).astype(np.int16).tobytes()); w.close()
print('ok', lang)
