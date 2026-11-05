extends SceneTree

func _initialize() -> void:
 call_deferred("capture_preview")

func capture_preview() -> void:
 var game=load("res://main.tscn").instantiate()
 root.add_child(game)
 game.set_process(false)
 game.set_physics_process(false)
 game.save_enabled=false
 game.sfx.quiet_tests=true
 game.sfx.reset_audio()
 game.begin()
 # Advance using the same simulation and ordinary release input as actual play.
 for i in range(120*38):
  game.step_world(1.0/120)
  game.demo_input()
  if game.mode=="over": break
 for i in range(100): game.update_visuals()
 game.update_ui()
 await process_frame
 RenderingServer.force_draw(false)
 await process_frame
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png("res://captures/cargo-english-tall.png")
 print("FRAMING PREVIEW: crates=",game.loaded," height=",game.stack_top-game.DECK," mode=",game.mode)
 game.sfx.reset_audio()
 quit()
