"""Prepara música para loop no jogo: corta silêncio do fim/início, emenda fim→começo com crossfade equal-power
de 2 s, ganho estático para −16 LUFS (pico ≤ −1,5 dBTP), exporta OGG q6 e confere o salto no ponto de loop.
Uso: musica_loop.py entrada.mp3 saida.ogg"""
import sys, subprocess, json, numpy as np
src, dst = sys.argv[1], sys.argv[2]; sr = 44100
a = np.frombuffer(subprocess.run(['ffmpeg', '-v', 'error', '-i', src, '-f', 'f32le', '-ac', '2', '-ar', str(sr), '-'],
                                 capture_output=True).stdout, np.float32).reshape(-1, 2).copy()
env = np.abs(a).max(axis=1); thr = 10 ** (-45 / 20)
nz = np.where(env > thr)[0]; a = a[nz[0]:nz[-1] + 1]                       # corta silêncio nas pontas
X = 2 * sr; f = np.linspace(0, 1, X)[:, None]
loop = np.concatenate([a[-X:] * np.sqrt(1 - f) + a[:X] * np.sqrt(f), a[X:-X]])
loop.astype(np.float32).tofile('/tmp/claude-1000/_loop.f32')
m = subprocess.run(['ffmpeg', '-hide_banner', '-f', 'f32le', '-ar', str(sr), '-ac', '2', '-i', '/tmp/claude-1000/_loop.f32',
                    '-af', 'loudnorm=I=-16:TP=-1.5:print_format=json', '-f', 'null', '-'], capture_output=True, text=True).stderr
s0 = m.rindex('{'); j = json.loads(m[s0:m.index('}', s0) + 1]); gain = -16 - float(j['input_i'])
gain = min(gain, -1.5 - float(j['input_tp']))                                # não deixa o pico passar de −1,5 dBTP
subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(sr), '-ac', '2', '-i', '/tmp/claude-1000/_loop.f32',
                '-af', f'volume={gain:.2f}dB', '-c:a', 'libvorbis', '-q:a', '6', dst], check=True)
b = np.frombuffer(subprocess.run(['ffmpeg', '-v', 'error', '-i', dst, '-f', 'f32le', '-ac', '2', '-'], capture_output=True).stdout,
                  np.float32).reshape(-1, 2)
print(f'{dst.split("/")[-1]}: {len(loop)/sr:.2f}s  ganho {gain:+.1f} dB  salto no loop {np.abs(b[0]-b[-1]).max():.4f}  '
      f'variação típica {np.abs(np.diff(b[:sr], axis=0)).mean():.4f}')
