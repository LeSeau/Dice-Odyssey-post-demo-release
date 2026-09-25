# Builds the placeholder landing knock and the short click rattles from the existing roll
# rattles (sounds/dicerollsound1-3.mp3). Writes 16-bit mono 48 kHz WAVs into sounds/.
import subprocess, wave, numpy as np, sys, os
SR = 48000
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
def load(path):
    out = subprocess.run(["ffmpeg","-v","error","-i",os.path.join(ROOT,path),"-ac","1","-ar",str(SR),"-f","f32le","-"],capture_output=True).stdout
    return np.frombuffer(out, dtype=np.float32).copy()
def write(path, x):
    x = np.clip(x, -1, 1)
    pcm = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(ROOT, path), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
def zero_cross_before(x, i):
    j = i
    while j > 1 and not (x[j-1] <= 0 < x[j] or x[j-1] >= 0 > x[j]):
        j -= 1
    return j
def knock(src, onset_ms, length_ms, fade_ms, thump_db):
    x = load(src)
    s = zero_cross_before(x, int((onset_ms - 4) / 1000 * SR))
    seg = x[s:s + int(length_ms / 1000 * SR)].copy()
    n = len(seg)
    f = int(fade_ms / 1000 * SR)
    seg[n-f:] *= np.linspace(1, 0, f) ** 2
    # Low body under the clack: a short decaying sine with a slight downward sweep, so the
    # knock reads as a die hitting a table rather than a tick. Starts on the clack's peak.
    pk = int(np.argmax(np.abs(seg)))
    t = np.arange(n - pk) / SR
    freq = 150 * np.exp(-t * 6) + 85
    phase = 2 * np.pi * np.cumsum(freq) / SR
    body = np.sin(phase) * np.exp(-t / 0.045)
    body *= 10 ** (thump_db / 20) * np.abs(seg).max()
    seg[pk:] += body
    seg /= np.abs(seg).max()
    seg *= 10 ** (-1.0 / 20)   # peak at -1 dBFS; loudness is set at the call site
    return seg
def shake(src, keep_ms, fade_ms):
    x = load(src)
    seg = x[:int(keep_ms / 1000 * SR)].copy()
    f = int(fade_ms / 1000 * SR)
    seg[-f:] *= np.linspace(1, 0, f) ** 1.5
    return seg   # original level kept: the click keeps the loudness it always had
write("sounds/dice_land_knock_1.wav", knock("sounds/dicerollsound3.mp3", 55, 110, 55, -4.0))
write("sounds/dice_land_knock_2.wav", knock("sounds/dicerollsound3.mp3", 175, 85, 45, -4.0))
write("sounds/dice_roll_shake_1.wav", shake("sounds/dicerollsound1.mp3", 290, 90))
write("sounds/dice_roll_shake_2.wav", shake("sounds/dicerollsound2.mp3", 290, 90))
write("sounds/dice_roll_shake_3.wav", shake("sounds/dicerollsound3.mp3", 290, 90))
print("ok")
