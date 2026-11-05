"""Original procedural composition; reference audio is not used in rendering."""
import numpy as np
from scipy.io import wavfile
from scipy.signal import lfilter
from pathlib import Path
SR=44100; BPM=108; BEAT=60/BPM; BARS=32; LENGTH=BARS*4*BEAT; N=round(LENGTH*SR)
rng=np.random.default_rng(1205); mix=np.zeros((N,2),np.float64)
def note(m): return 440*2**((m-4-69)/12)
def add(m,start,duration,amp,voice='keys',pan=0):
 t=np.arange(int(duration*SR))/SR; f=note(m)
 if voice=='keys':
  s=sum(v*np.sin(2*np.pi*f*h*t)*np.exp(-t/d) for h,v,d in [(1,1,1.7),(2,.27,.65),(3,.09,.35),(4,.025,.2)])
  s*=1-np.exp(-t/.008)
 elif voice=='bell':
  s=(np.sin(2*np.pi*f*t)+.25*np.sin(2*np.pi*f*2.003*t)*np.exp(-t/.3))*np.exp(-t/1.15)*(1-np.exp(-t/.004))
 elif voice=='pad':
  s=(np.sin(2*np.pi*f*t)+.25*np.sin(2*np.pi*f*1.002*t)+.12*np.sin(2*np.pi*f*2*t))
  s*=np.minimum(t/.65,1)*np.minimum((duration-t)/.9,1)*.55
 else:
  s=(np.sin(2*np.pi*f*t)+.17*np.sin(2*np.pi*f*2*t))*np.exp(-t/.65)*(1-np.exp(-t/.018))
 s*=np.minimum((duration-t)/.025,1)*amp
 i=round(start*SR); inds=(i+np.arange(len(t)))%N
 np.add.at(mix[:,0],inds,s*np.sqrt((1-pan)/2)); np.add.at(mix[:,1],inds,s*np.sqrt((1+pan)/2))
def drum(start,kind,amp):
 t=np.arange(int(.3*SR))/SR
 if kind=='kick': s=np.sin(2*np.pi*(49*t+38*.026*(1-np.exp(-t/.026))))*np.exp(-t/.075)
 else:
  noise=rng.normal(size=len(t)); noise=lfilter([1,-1],[1,-.25],noise)
  s=noise*np.exp(-t/(.022 if kind=='hat' else .05))*.25
 i=round(start*SR); ids=(i+np.arange(len(t)))%N
 for c in range(2): np.add.at(mix[:,c],ids,s*amp)
# Voicings transposed to Bb major; two contrasting original phrases.
chords=[([50,57,61,64,69],38),([49,57,59,64,69],37),([47,54,57,61,66],35),([43,54,57,62,66],31)]
melodies=[[78,76,73,None,71,73,76,69],[73,None,76,81,78,76,None,73],[74,73,69,66,None,69,73,76],[74,None,71,69,66,None,69,73], [78,None,81,85,83,81,78,None],[76,78,81,None,76,73,71,None],[74,78,76,73,69,None,73,71],[69,None,66,69,73,71,None,76]]
for bar in range(BARS):
 chord,bass=chords[bar%4]; origin=bar*4*BEAT; phase=bar//8
 for j,m in enumerate(chord): add(m,origin,4*BEAT+.8,.035,'pad',(j-2)*.22)
 for k in range(8):
  m=chord[[1,2,3,4,2,3,1,3][k]]+12
  add(m,origin+k*.5*BEAT,2,.075*(1 if k%2==0 else .8),'keys',-.25 if k%2==0 else .22)
 for k in [0,2.5]: add(bass,origin+k*BEAT,1.5,.14,'bass')
 for k,m in enumerate(melodies[(bar%8)]):
  if m is not None and (phase>0 or k in [0,2,5]): add(m,origin+(k*.5+.125)*BEAT,2.4,.09,'bell',.12)
 for k in range(4):
  drum(origin+k*BEAT,'kick',.1 if k%2==0 else .045)
  if k in [1,3]: drum(origin+k*BEAT,'snare',.055)
  if phase>0:
   drum(origin+(k+.5)*BEAT,'hat',.055)
 if phase==2:
  add(chord[3]+24,origin+3.25*BEAT,2,.035,'bell',-.4)
# Circular stereo delay and diffuse reverb preserve exact looping.
dry=mix.copy()
for seconds,gain in [(.333,.15),(.5,.1),(.743,.07),(1.127,.045),(1.63,.025)]:
 mix+=np.roll(dry,round(seconds*SR),axis=0)[:,::-1]*gain
mix=np.tanh(mix*1.2); mix-=mix.mean(axis=0); mix*=.84/np.max(np.abs(mix))
Path('audio').mkdir(exist_ok=True)
wavfile.write('audio/lighthouse-drift-loop.wav',SR,(mix*32767).astype(np.int16))
print({'duration':LENGTH,'bpm':BPM,'peak':float(abs(mix).max()),'rms':float(np.sqrt(np.mean(mix**2))),'boundary_step':float(np.max(abs(mix[0]-mix[-1])))})
