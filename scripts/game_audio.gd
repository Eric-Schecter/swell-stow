extends Node

const ROOT := "res://assets/sfx/"
const BANK := {
 "release":["release-1","release-2"], "land":["land-1","land-2","land-3"],
 "heavy":["heavy-1","heavy-2"], "splash":["elevenlabs/water-plunge-v2"],
 "creak":["creak"], "balance":["balance"], "start":["start"],
 "success":["success"], "failure":["failure"], "ui":["ui"], "timer":["timer"]
}
const LEVELS := {"release":-9.0,"land":-6.5,"heavy":-6.0,"splash":-5.5,"creak":-14.0,"balance":-15.0,"start":-11.0,"success":-8.0,"failure":-9.0,"ui":-15.0,"timer":-18.0}
var streams: Dictionary = {}
var choices: Dictionary = {}
var event_counts: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var result: AudioStreamPlayer
var interface_voice: AudioStreamPlayer
var sea: AudioStreamPlayer
var slide: AudioStreamPlayer
var music: AudioStreamPlayer
var music_bus := -1
var music_level := -18.0
var music_wanted := false
var duck_time := 0.0
var muted := false
var quiet_tests := false
var loading := false
var paused := false
var slide_amount := 0.0
var slide_level := -70.0
var tick_time := 0.0
var creak_time := 0.0
var balance_time := 0.0
var last_impact := -10.0
var last_splash := -10.0
var clock_time := 0.0
var voice_index := 0
var bus_index := -1

func _ready() -> void:
 bus_index=AudioServer.get_bus_index("CargoSFX")
 if bus_index<0:
  AudioServer.add_bus()
  bus_index=AudioServer.bus_count-1
  AudioServer.set_bus_name(bus_index,"CargoSFX")
 AudioServer.set_bus_volume_db(bus_index,-3.0)
 music_bus=AudioServer.get_bus_index("CargoMusic")
 if music_bus<0:
  AudioServer.add_bus()
  music_bus=AudioServer.bus_count-1
  AudioServer.set_bus_name(music_bus,"CargoMusic")
 AudioServer.set_bus_volume_db(music_bus,0.0)
 for kind in BANK:
  var bank: Array[AudioStreamWAV]=[]
  for sample in BANK[kind]:
   var stream := load(ROOT+sample+".wav") as AudioStreamWAV
   assert(stream!=null,"Missing SFX: "+sample)
   bank.append(stream)
  streams[kind]=bank
  choices[kind]=0
 for i in range(10): voices.append(player("Voice%02d"%i))
 result=player("Result")
 interface_voice=player("Interface")
 sea=player("Sea")
 slide=player("Sliding")
 sea.stream=loop_stream("sea-loop")
 slide.stream=loop_stream("slide-loop")
 music=player("Music")
 music.bus="CargoMusic"
 var bgm := (load("res://assets/music/harbor-hop.wav") as AudioStreamWAV).duplicate() as AudioStreamWAV
 bgm.loop_mode=AudioStreamWAV.LOOP_FORWARD
 bgm.loop_begin=0
 bgm.loop_end=int(bgm.get_length()*bgm.mix_rate)
 music.stream=bgm
 music.volume_db=music_level
 sea.volume_db=-32
 slide.volume_db=-70

func player(title: String) -> AudioStreamPlayer:
 var p := AudioStreamPlayer.new()
 p.name=title
 p.bus="CargoSFX"
 p.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
 add_child(p)
 return p

func loop_stream(title: String) -> AudioStreamWAV:
 var stream := (load(ROOT+title+".wav") as AudioStreamWAV).duplicate() as AudioStreamWAV
 stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
 stream.loop_begin=0
 stream.loop_end=int(stream.get_length()*stream.mix_rate)
 return stream

func play(kind: String) -> void:
 event_counts[kind]=int(event_counts.get(kind,0))+1
 if quiet_tests or muted: return
 if paused and kind!="ui": return
 if kind in ["land","heavy","splash"]: duck_time=.18
 if kind=="splash":
  if clock_time-last_splash<.075: return
  last_splash=clock_time
 if kind in ["land","heavy"]:
  if clock_time-last_impact<.028: return
  last_impact=clock_time
 var p: AudioStreamPlayer
 if kind in ["success","failure"]: p=result
 elif kind=="ui": p=interface_voice
 else:
  p=voices[voice_index%voices.size()]
  voice_index+=1
 var bank: Array=streams[kind]
 var index: int=int(choices[kind])%bank.size()
 choices[kind]=index+1
 p.stream=bank[index]
 p.volume_db=float(LEVELS[kind])
 # Small deterministic variations keep repeated wooden impacts from sounding identical.
 p.pitch_scale=1.0+float(index-1)*.025 if kind in ["land","heavy","release"] else 1.0
 p.stream_paused=false
 p.play()

func reset_audio(keep_music: bool=false) -> void:
 for p in voices:
  p.stop()
  p.stream_paused=false
 result.stop()
 interface_voice.stop()
 if not keep_music:
  music.stop()
  music_wanted=false
 music.stream_paused=muted
 music_level=-18.0
 duck_time=0
 sea.stop()
 slide.stop()
 sea.stream_paused=false
 slide.stream_paused=false
 paused=false
 loading=false
 slide_amount=0
 slide_level=-70
 slide.volume_db=-70
 creak_time=0
 tick_time=0
 balance_time=0
 last_impact=-10
 last_splash=-10

func menu_music() -> void:
 music_wanted=true
 music_level=-21.0
 music.stream_paused=muted
 if quiet_tests or muted: return
 if not music.playing:
  music.volume_db=music_level
  music.play()

func begin_audio() -> void:
 loading=true
 paused=false
 music_wanted=true
 music_level=-18.0
 if not quiet_tests and not muted:
  sea.play()
  music.stream_paused=false
  if not music.playing: music.play()
 play("start")

func impact(mass: float, correcting: bool) -> void:
 play("heavy" if mass>1.5 else "land")
 if correcting and balance_time<=0:
  play("balance")
  balance_time=.45

func set_motion(sliding: float, heel: float, angular_speed: float, remaining: float) -> void:
 slide_amount=clampf(sliding,0,1)
 if quiet_tests or muted or paused or not loading: return
 if absf(heel)>.24 and absf(angular_speed)>.05 and creak_time<=0:
  play("creak")
  creak_time=1.1
 if remaining>0 and remaining<.62 and tick_time<=0:
  play("timer")
  tick_time=.25

func set_paused(value: bool) -> void:
 paused=value
 for p in voices: p.stream_paused=value
 sea.stream_paused=value
 slide.stream_paused=value
 music.stream_paused=value or muted
 play("ui")

func set_muted(value: bool) -> void:
 muted=value
 AudioServer.set_bus_mute(bus_index,value)
 AudioServer.set_bus_mute(music_bus,value)
 music.stream_paused=value or paused
 if value:
  for p in voices: p.stop()
  result.stop()
  interface_voice.stop()
  sea.stop()
  slide.stop()
 elif loading and not quiet_tests:
  sea.play()
  sea.stream_paused=paused
 if not value and music_wanted and not quiet_tests:
  if not music.playing: music.play()
  music.stream_paused=paused

func end_audio(success: bool) -> void:
 loading=false
 music_level=-25.0
 slide_amount=0
 slide.stop()
 sea.stop()
 play("success" if success else "failure")

func _process(dt: float) -> void:
 clock_time+=dt
 if paused: return
 duck_time=maxf(0,duck_time-dt)
 if not quiet_tests:
  var target_db: float=music_level-4.0*(duck_time/.18)
  music.volume_db=lerpf(music.volume_db,target_db,1-exp(-dt*12))
 creak_time=maxf(0,creak_time-dt)
 tick_time=maxf(0,tick_time-dt)
 balance_time=maxf(0,balance_time-dt)
 if not loading or quiet_tests or muted: return
 var wanted: float=-24.0+linear_to_db(maxf(.001,slide_amount)) if slide_amount>.035 else -70.0
 slide_level=lerpf(slide_level,wanted,1-exp(-dt*14))
 slide.volume_db=slide_level
 if slide_level> -58 and not slide.playing: slide.play()
 elif slide_level< -58 and slide.playing: slide.stop()
