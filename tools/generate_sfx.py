"""Original short, soft gameplay effects. No reference music or external samples."""
from pathlib import Path
import numpy as np
from scipy.signal import lfilter, butter, sosfilt
from scipy.io import wavfile
SR=44100
OUT=Path(__file__).resolve().parents[1]/'assets'/'sfx'
OUT.mkdir(parents=True,exist_ok=True)
rng=np.random.default_rng(120512)
def noise(n,low=2200,high=100):
 x=rng.normal(0,1,n)
 x=sosfilt(butter(2,[high,low],fs=SR,btype='bandpass',output='sos'),x)
 return x/(np.std(x)+1e-9)
def save(name,x,peak=.65,loop=False):
 x=np.asarray(x)
 if x.ndim==1:
  x=np.stack([x,np.roll(x,19)*.985],axis=1)
 x-=np.mean(x,axis=0)
 if not loop:
  k=min(int(.005*SR),len(x)//8)
  x[:k]*=np.linspace(0,1,k)[:,None]
  x[-k:]*=np.linspace(1,0,k)[:,None]
 x*=peak/(np.max(np.abs(x))+1e-9)
 wavfile.write(OUT/(name+'.wav'),SR,np.round(x*32767).astype(np.int16))
 print(f'{name:16} {len(x)/SR:5.2f}s  peak={np.max(abs(x)):.3f} rms={np.sqrt(np.mean(x*x)):.3f}')
def wood(duration,base):
 t=np.arange(round(duration*SR))/SR
 # Damped wooden-bar modes, with a short soft felt-like contact transient.
 s=np.zeros_like(t)
 for h,a,d in [(1,1,.095),(1.79,.32,.047),(2.72,.17,.032),(4.12,.06,.020)]:
  s+=a*np.sin(2*np.pi*base*h*t)*np.exp(-t/d)
 s*=1-np.exp(-t/.0025)
 s+=noise(len(t),2400,400)*np.exp(-t/.016)*.15
 return s
for i,f in enumerate([245,270,292],1): save(f'land-{i}',wood(.24,f),.66)
for i,f in enumerate([164,181],1):
 x=wood(.34,f);t=np.arange(len(x))/SR
 x+=.16*np.sin(2*np.pi*330*t)*np.exp(-t/.08)*(1-np.exp(-t/.004))
 save(f'heavy-{i}',x,.70)
for i,f in enumerate([690,760],1):
 t=np.arange(int(.15*SR))/SR
 x=.6*np.sin(2*np.pi*f*t)*np.exp(-t/.015)*(1-np.exp(-t/.0015))
 x+=.18*np.sin(2*np.pi*410*t)*np.exp(-t/.035)
 x+=noise(len(t),3300,800)*np.exp(-t/.025)*.10
 save(f'release-{i}',x,.49)
t=np.arange(int(.38*SR))/SR
x=np.sin(2*np.pi*(300*t+18*np.sin(t*10)))*np.exp(-t/.09)*(1-np.exp(-t/.009))
x+=noise(len(t),1200,280)*np.exp(-t/.16)*.08
save('creak',x,.46)
for i in range(1,3):
 t=np.arange(int(.68*SR))/SR
 splash=noise(len(t),4400,500)*(1-np.exp(-t/.004))*np.exp(-t/.12)*.24
 bubbles=np.zeros_like(t)
 for start,base in [(0,310),(.075,440),(.16,530),(.27,670)]:
  tt=np.maximum(0,t-start)
  bubbles+=np.sin(2*np.pi*base*(tt+.5*tt*tt))*np.exp(-tt/.045)*(t>=start)*(1-np.exp(-tt/.003))*.30
 save(f'splash-{i}',splash+bubbles,.68)
def chime(name,pitches,gap,duration,peak):
 t=np.arange(int(duration*SR))/SR;x=np.zeros_like(t)
 for j,pitch in enumerate(pitches):
  tt=np.maximum(0,t-j*gap);env=(t>=j*gap)*(1-np.exp(-tt/.004))*np.exp(-tt/.17)
  x+=(np.sin(2*np.pi*pitch*tt)+.15*np.sin(2*np.pi*pitch*2.003*tt))*env*.32
 save(name,x,peak)
chime('balance',[659.25,880],.075,.38,.41)
chime('start',[392,523.25],.085,.42,.48)
chime('success',[523.25,659.25,783.99,1046.5],.11,.95,.59)
chime('failure',[392,329.63,261.63],.10,.68,.52)
chime('ui',[740],.1,.10,.36)
chime('timer',[930],.1,.085,.34)
# Periodic filtered noise for quiet friction. Wrapping uses the same FFT signal.
def periodic_noise(seconds,cut):
 n=int(seconds*SR);freq=np.fft.rfftfreq(n,1/SR)
 spectrum=rng.normal(size=len(freq))+1j*rng.normal(size=len(freq))
 spectrum*=np.exp(-(freq/cut)**2)*(1-np.exp(-(freq/140)**2))
 x=np.fft.irfft(spectrum,n=n);return x/(np.std(x)+1e-9)
t=np.arange(int(1.2*SR))/SR
slide=periodic_noise(1.2,1900)*(.5+.14*np.sin(2*np.pi*t/1.2*9))
slide+=.10*np.sin(2*np.pi*235*t)*(1+.3*np.sin(2*np.pi*t/1.2*4))
save('slide-loop',slide,.43,True)
t=np.arange(int(4*SR))/SR
sea=np.stack([periodic_noise(4,2900),periodic_noise(4,2900)],axis=1)
sea*= (.50+.22*np.sin(2*np.pi*t/4)+.08*np.cos(2*np.pi*t/4*3))[:,None]
save('sea-loop',sea,.40,True)
