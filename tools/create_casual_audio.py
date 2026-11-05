"""Original casual-game loop and water-impact effects, synthesized locally."""
from pathlib import Path
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter,sosfilt,lfilter
ROOT=Path(__file__).resolve().parents[1]; SR=44100
rng=np.random.default_rng(1105)
def filtered(n,lo,hi):
 x=sosfilt(butter(2,[lo,hi],btype='bandpass',fs=SR,output='sos'),rng.normal(size=n))
 return x/(np.std(x)+1e-9)
for v in [1,2]:
 t=np.arange(int(.82*SR))/SR
 # A broad turbulent crown follows a low cavity impact, then irregular drips.
 impact=np.sin(2*np.pi*(66*t+4.0*(1-np.exp(-t/.030))))*np.exp(-t/.062)*(1-np.exp(-t/.0018))*.55
 attack=filtered(len(t),300,6500)*np.exp(-t/.032)*(1-np.exp(-t/.0015))*.42
 crown=filtered(len(t),700,7600)*(t/.06)*np.exp(-t/.075)*.23
 tail=filtered(len(t),1100,5500)*np.exp(-t/.19)*(1-np.exp(-t/.05))*.12
 for start,level in [(.17,.10),(.26,.075),(.38,.045),(.51,.025)]:
  q=np.maximum(0,t-start)
  tail+=filtered(len(t),900,5200)*(t>=start)*(1-np.exp(-q/.001))*np.exp(-q/.018)*level
 x=impact+attack+crown+tail
 stereo=np.stack([x,impact+np.roll(attack+crown+tail,110+v*31)],axis=1)
 stereo[-500:]*=np.linspace(1,0,500)[:,None];stereo-=stereo.mean(axis=0)
 stereo*=.72/np.max(abs(stereo))
 wavfile.write(ROOT/f'assets/sfx/splash-{v}.wav',SR,(stereo*32767).astype(np.int16))
# 100 BPM, 32 bars: a 76.8-second loop of plucked strings and wooden marimba.
BPM=100; BEAT=60/BPM; LENGTH=32*4*BEAT; N=round(LENGTH*SR)
mix=np.zeros((N,2),dtype=np.float64)
def add(midi,start,duration,amp,voice,pan=0):
 f=440*2**((midi-69)/12);t=np.arange(int(duration*SR))/SR
 if voice=='pluck':
  delay=max(2,round(SR/f));excitation=rng.normal(size=delay);excitation-=excitation.mean()
  pulse=np.zeros(len(t));pulse[:delay]=excitation
  den=np.zeros(delay+2);den[0]=1;den[delay]=-.492;den[delay+1]=-.492
  s=lfilter([1],den,pulse);s/=max(np.max(abs(s)),.01)
  s*=np.exp(-t/1.2)
 elif voice=='marimba':
  s=sum(a*np.sin(2*np.pi*f*h*t)*np.exp(-t/d) for h,a,d in [(1,1,.32),(3.98,.10,.07),(9.07,.022,.025)])
  s*=1-np.exp(-t/.003)
 else:
  s=(np.sin(2*np.pi*f*t)+.16*np.sin(2*np.pi*f*2*t))*np.exp(-t/.35)*(1-np.exp(-t/.012))
 s*=np.minimum(1,np.maximum(0,(duration-t)/.025))*amp
 ids=(round(start*SR)+np.arange(len(t)))%N
 for c,gain in enumerate([np.sqrt((1-pan)/2),np.sqrt((1+pan)/2)]): np.add.at(mix[:,c],ids,s*gain)
chords=[([60,64,67,74],36),([57,60,64,67],33),([57,60,62,65],38),([55,59,62,64],31),([57,60,64,65],29),([55,59,62,67],28),([57,60,62,65],26),([55,59,64,69],31)]
melody=[[76,79,None,81,79,76,74,None],[72,None,76,79,76,None,72,69],[74,77,None,81,79,77,74,None],[74,None,76,79,76,74,None,72],[77,81,79,None,76,77,None,74],[76,None,79,83,81,79,None,76],[74,77,76,None,74,72,69,None],[71,None,74,79,77,74,72,None]]
for bar in range(32):
 notes,bass=chords[bar%8];origin=bar*4*BEAT;phrase=bar//8
 for beat in [0,1.5,2.5,3.5]:
  for j,m in enumerate(notes): add(m,origin+beat*BEAT+j*.012,1.5,.055 if beat!=0 else .068,'pluck',-.26+j*.13)
 for beat,m in [(0,bass),(2,bass+7)]: add(m,origin+beat*BEAT,.9,.16,'bass',-.06)
 for k,m in enumerate(melody[bar%8]):
  if m is None or (phrase==0 and k in [3,6]):continue
  add(m,origin+(k*.5+.07)*BEAT,1.0,.115 if k%2==0 else .082,'marimba',.18)
 if phrase in [1,3] and bar%4==3:
  for k,m in enumerate([84,83,81]):add(m,origin+(2.75+k*.375)*BEAT,.65,.027,'marimba',-.35)
 # Small brushed pulses and shakers keep the rhythm buoyant rather than forceful.
 for k in range(8):
  n=int(.10*SR);t=np.arange(n)/SR
  s=filtered(n,3500,11000)*np.exp(-t/.017)*(1-np.exp(-t/.001))*.012
  ids=(round(origin*SR+k*.5*BEAT*SR)+np.arange(n))%N
  np.add.at(mix[:,0],ids,s*.7);np.add.at(mix[:,1],ids,s*.7)
original=mix.copy()
for delay,gain in [(.12,.11),(.27,.075),(.43,.05),(.69,.025)]:mix+=np.roll(original,round(delay*SR),axis=0)[:,::-1]*gain
mix=np.tanh(mix*1.15);mix-=mix.mean(axis=0)
edge=int(.003*SR);ramp=.5-.5*np.cos(np.linspace(0,np.pi,edge))
mix[:edge]*=ramp[:,None];mix[-edge:]*=ramp[::-1,None]
mix*=.74/np.max(abs(mix))
(ROOT/'assets/music').mkdir(exist_ok=True)
wavfile.write(ROOT/'assets/music/harbor-hop.wav',SR,(mix*32767).astype(np.int16))
print('BGM',{'duration':LENGTH,'BPM':BPM,'peak':float(abs(mix).max()),'rms':float(np.sqrt(np.mean(mix**2))),'loop_step':float(abs(mix[0]-mix[-1]).max())})
