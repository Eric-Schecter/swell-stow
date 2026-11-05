import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {resolve} from 'node:path';
const root=fileURLToPath(new URL('..',import.meta.url));
const out=resolve(root,'assets/sfx/elevenlabs');await mkdir(out,{recursive:true});
const ledger=resolve(out,'water-impact-v1.json');
try{const previous=JSON.parse(await readFile(ledger,'utf8'));console.log('Request already recorded: '+previous.status+'. No automatic retry.');process.exit(previous.status==='complete'?0:1);}catch(e){if(e.code!=='ENOENT')throw e;}
const env=await readFile('/Users/eric/Documents/repos/renderer/audio-lab/.env.local','utf8');
const line=env.split(/\r?\n/).find(x=>/^\s*ELEVENLABS_API_KEY\s*=/.test(x));
const key=line?.slice(line.indexOf('=')+1).trim().replace(/^(['"])(.*)\1$/,'$2');
if(!key)throw new Error('ElevenLabs API key is not configured.');
const request={text:'One small heavy wooden cargo crate dropping into calm seawater, close-up natural foley. A short deep watery plop immediately followed by a crisp irregular splash, then a few small dripping droplets. Single impact, compact and gentle for a cozy casual game. Dry isolated sound, no music, voices, cartoon whistles, metallic ringing, engine, or background ocean ambience.',duration_seconds:1.5,prompt_influence:0.65,model_id:'eleven_text_to_sound_v3',loop:false};
const entry={provider:'ElevenLabs',date:new Date().toISOString(),request,status:'started'};
await writeFile(ledger,JSON.stringify(entry,null,2));
try{
 const r=await fetch('https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128',{method:'POST',headers:{'xi-api-key':key,'Content-Type':'application/json'},body:JSON.stringify(request),redirect:'error',signal:AbortSignal.timeout(60000)});
 entry.httpStatus=r.status;entry.requestId=r.headers.get('request-id');entry.characterCost=r.headers.get('character-cost');
 if(!r.ok){entry.status='failed';entry.error=(await r.text()).replaceAll(key,'[redacted]').slice(0,1200);console.log('Generation failed: HTTP '+r.status+' '+entry.error);process.exitCode=1;}
 else{const bytes=Buffer.from(await r.arrayBuffer());if(bytes.length<1000)throw new Error('Audio response is unexpectedly small');await writeFile(resolve(out,'water-impact-v1.mp3'),bytes);entry.status='complete';entry.file='water-impact-v1.mp3';entry.bytes=bytes.length;console.log('ElevenLabs sound effect saved: '+bytes.length+' bytes; credits='+entry.characterCost);}
}catch(e){entry.status='uncertain';entry.error=String(e.message).replaceAll(key,'[redacted]');console.log('Request stopped without retry: '+entry.error);process.exitCode=1;}
await writeFile(ledger,JSON.stringify(entry,null,2).replaceAll(key,'[redacted]'));
