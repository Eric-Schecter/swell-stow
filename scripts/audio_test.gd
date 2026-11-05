extends SceneTree

func _initialize() -> void:
 call_deferred("check")

func check() -> void:
 var sound := preload("res://scripts/game_audio.gd").new()
 root.add_child(sound)
 await process_frame
 for kind in sound.BANK:
  for stream in sound.streams[kind]:
   assert(stream.get_length()>.05 and stream.mix_rate==44100)
 sound.menu_music()
 assert(sound.music.playing and not sound.loading and not sound.sea.playing,"Title screen must have music before gameplay")
 sound.music.seek(3.0)
 await create_timer(.10).timeout
 sound.reset_audio(true)
 sound.menu_music()
 assert(sound.music.playing and sound.music.get_playback_position()>2.5,"Returning to title must preserve the music phrase")
 sound.set_muted(true)
 assert(sound.music.stream_paused)
 sound.set_muted(false)
 assert(sound.music.playing and not sound.music.stream_paused,"Unmute must work on the title screen")
 sound.begin_audio()
 assert(sound.music.get_playback_position()>2.5,"Start loading must not restart title music")
 sound.play("release")
 sound.impact(1.0,true)
 await create_timer(.06).timeout
 sound.impact(2.0,false)
 assert(sound.sea.playing and sound.music.playing)
 var heavy_voice: AudioStreamPlayer=sound.voices[(sound.voice_index-1)%sound.voices.size()]
 assert(heavy_voice.playing,"Heavy impact must use a real playback voice")
 sound.set_motion(1.0,.3,.2,.4)
 await create_timer(.08).timeout
 assert(sound.slide.playing,"Sliding should produce the friction loop")
 sound.set_paused(true)
 assert(sound.sea.stream_paused and sound.slide.stream_paused and heavy_voice.stream_paused and sound.music.stream_paused)
 sound.set_paused(false)
 assert(not sound.sea.stream_paused and not sound.slide.stream_paused and not sound.music.stream_paused)
 sound.end_audio(true)
 assert(sound.result.playing and not sound.sea.playing and not sound.slide.playing and sound.music.playing)
 var result_stream: AudioStream=sound.result.stream
 sound.play("splash")
 assert(sound.result.playing and sound.result.stream==result_stream,"Late splash must not cut off result audio")
 sound.set_muted(true)
 assert(AudioServer.is_bus_mute(sound.bus_index) and AudioServer.is_bus_mute(sound.music_bus) and not sound.result.playing and sound.music.stream_paused)
 sound.begin_audio()
 assert(not sound.sea.playing and sound.music.stream_paused,"Starting while muted must remain silent")
 sound.set_muted(false)
 assert(sound.sea.playing and sound.music.playing and not sound.music.stream_paused)
 sound.set_paused(true)
 sound.reset_audio()
 sound.begin_audio()
 assert(sound.sea.playing and not sound.sea.stream_paused,"Reset after pause must restart audible ambience")
 sound.music.seek(sound.music.stream.get_length()-.06)
 await create_timer(.22).timeout
 assert(sound.music.playing and sound.music.get_playback_position()<1.0,"Music must wrap at the end without stopping")
 sound.reset_audio()
 assert(not sound.sea.playing and not sound.slide.playing and not sound.result.playing and not sound.music.playing)
 for p in sound.voices: assert(not p.playing)
 sound.queue_free()
 result_stream=null
 heavy_voice=null
 await create_timer(.12).timeout
 print("AUDIO TEST PASS: ElevenLabs WAV, title music before start, seamless title/game transition, music loop+mute+pause+reset, distinct impacts, slide loop, pause/resume, isolated result+splash, mute/unmute, reset after pause, silence on reset")
 quit()
