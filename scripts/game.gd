extends Node3D

const DECK := 0.57
const HALF_WIDTH := 2.0
const GRAVITY := 15.0
const COLORS := [Color("e7ac94"),Color("aebdd7"),Color("a8c9b7"),Color("e7cc91"),Color("c6b4d8")]
var ship: Node3D
var boom: Node3D
var cable: MeshInstance3D
var trolley: Node3D
var target: Node3D
var prediction: Node3D
var water_inside: MeshInstance3D
var cargo: Array[Dictionary] = []
var falling: Array[Dictionary] = []
var debris: Array[Dictionary] = []
var ripples: Array[Dictionary] = []
var active: Dictionary = {}
var clock_time := 0.0
var roll := 0.0
var roll_speed := 0.0
var flood := 0.0
var capsize_time := 0.0
var loaded := 0
var lost := 0
var serial := 0
var best := 0
var mode := "ready"
var paused := false
var moment := 0.0
var load_mass := 0.0
var draft := 0.0
var feedback_time := 0.0
var wake_time := 0.0
var max_gap := 0.0
var last_release := 0.0
var releases := 0
var hull_art: Node3D
var ui: Control
var hud: Label
var headline: Label
var description: Label
var feedback: Label
var stats: Label
var next_info: Label
var hint: Label
var action: Button
var flood_bar: ProgressBar
var balance_marker: ColorRect
var balance_center: ColorRect
var cam: Camera3D
var tests := false
var demo := false
var bad_demo := false
var demo_duration := 26.0
var demo_intro := 0.0
var intro_elapsed := 0.0
var demo_ending := false
var captured := false
var pending_capture := false
var save_enabled := true
var peak_roll := 0.0
var high_heel_time := 0.0
var wave_phase := 0.0
var stack_top := DECK
var height_moment := 0.0
var hoist_y := 3.45
var gantry_posts: Array[MeshInstance3D] = []
var upper_rail: MeshInstance3D
var sfx: Node
var sound_button: Button
func material(color: Color) -> StandardMaterial3D:
 var m := StandardMaterial3D.new()
 m.albedo_color = color
 m.roughness = 0.78
 return m

func block_mesh(size: Vector3) -> ArrayMesh:
 var st := SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 st.set_smooth_group(-1)
 var b: float = min(0.045, min(size.x, min(size.y,size.z))*0.19)
 var rings: Array = []
 for data in [[-size.y/2,b],[ -size.y/2+b,0.0],[size.y/2-b,0.0],[size.y/2,b]]:
  var x: float = size.x/2-data[1]
  var z: float = size.z/2-data[1]
  var c: float = b*0.65
  rings.append([Vector3(-x+c,data[0],-z),Vector3(x-c,data[0],-z),Vector3(x,data[0],-z+c),Vector3(x,data[0],z-c),Vector3(x-c,data[0],z),Vector3(-x+c,data[0],z),Vector3(-x,data[0],z-c),Vector3(-x,data[0],-z+c)])
 for r in range(3):
  for i in range(8):
   var j := (i+1)%8
   for v in [rings[r][i],rings[r+1][j],rings[r+1][i],rings[r][i],rings[r][j],rings[r+1][j]]:
    st.add_vertex(v)
 for i in range(1,7):
  for v in [rings[0][0],rings[0][i+1],rings[0][i],rings[3][0],rings[3][i],rings[3][i+1]]:
   st.add_vertex(v)
 st.generate_normals()
 return st.commit()

func box(size: Vector3, pos: Vector3, color: Color, parent: Node = self) -> MeshInstance3D:
 var mesh := MeshInstance3D.new()
 mesh.mesh = block_mesh(size)
 mesh.material_override = material(color)
 # Tiny straps and deck markings should not create moving sub-pixel shadows.
 if minf(size.x,minf(size.y,size.z))<.10:
  mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 parent.add_child(mesh)
 mesh.position = pos
 return mesh

func cylinder(radius: float, height: float, pos: Vector3, color: Color, parent: Node=self) -> MeshInstance3D:
 var n := MeshInstance3D.new()
 var mesh := CylinderMesh.new()
 mesh.top_radius=radius
 mesh.bottom_radius=radius
 mesh.height=height
 mesh.radial_segments=24
 n.mesh=mesh
 n.material_override=material(color)
 parent.add_child(n)
 n.position=pos
 return n

func _ready() -> void:
 var args := OS.get_cmdline_user_args()
 tests="--self-test" in args
 demo="--demo" in args
 bad_demo="--bad" in args
 for a in args:
  if a.begins_with("--duration="): demo_duration=float(a.get_slice("=",1))
  if a.begins_with("--menu-intro="): demo_intro=float(a.get_slice("=",1))
 save_enabled=not tests and not demo
 if save_enabled and FileAccess.file_exists("user://cargo-best.txt"):
  var f := FileAccess.open("user://cargo-best.txt",FileAccess.READ)
  best=int(f.get_as_text())
 sfx=preload("res://scripts/game_audio.gd").new()
 sfx.quiet_tests=tests
 add_child(sfx)
 make_world()
 make_ui()
 reset_run()
 DisplayServer.window_set_title("Swell & Stow")
 DisplayServer.window_move_to_foreground()
 if tests: run_tests()
 elif demo:
  RenderingServer.set_render_loop_enabled(false)
  if demo_intro<=0: begin()
 elif OS.has_feature("web") and "--web-launch" in args:
  begin()

func make_world() -> void:
 var env := WorldEnvironment.new()
 env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR
 env.environment.background_color=Color("c2d8d3")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color("fff5e8")
 env.environment.ambient_light_energy=0.34
 add_child(env)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees=Vector3(-54,-27,0)
 sun.light_color=Color("fff0db")
 sun.light_energy=0.42
 sun.shadow_enabled=true
 # One shadow map avoids cascade transitions while the camera follows the heap.
 sun.directional_shadow_mode=0
 sun.directional_shadow_max_distance=28
 sun.shadow_bias=.08
 sun.shadow_normal_bias=1.0
 sun.shadow_blur=1.6
 sun.shadow_opacity=.62
 add_child(sun)
 cam=Camera3D.new()
 cam.projection=Camera3D.PROJECTION_ORTHOGONAL
 cam.size=11.6
 cam.far=45.0
 add_child(cam)
 cam.position=Vector3(8,9.5,12)
 cam.look_at(Vector3(.2,1.0,0))
 box(Vector3(180,.18,180),Vector3(0,-.62,0),Color("8dbdc1"))
 # Fixed dock and a travelling bridge crane: cargo is fed from the pier.
 box(Vector3(2.5,.64,9.0),Vector3(5.5,-.03,0),Color("d8cfb3"))
 box(Vector3(2.65,.12,9.1),Vector3(5.45,.36,0),Color("eddbb9"))
 for z in range(-4,5):
  box(Vector3(2.6,.02,.025),Vector3(5.43,.43,float(z)),Color("ccbea1"))
 for z in [-2.65,2.65]:
  gantry_posts.append(box(Vector3(.22,4.05,.22),Vector3(4.38,2.4,z),Color("97b6ad")))
  box(Vector3(.52,.12,.5),Vector3(4.38,.53,z),Color("729b98"))
 upper_rail=box(Vector3(.3,.22,5.9),Vector3(4.38,4.45,0),Color("b1c7b6"))
 boom=Node3D.new()
 add_child(boom)
 box(Vector3(7.8,.18,.22),Vector3(.55,4.5,0),Color("e2c08d"),boom)
 box(Vector3(7.8,.035,.08),Vector3(.55,4.62,0),Color("f7deac"),boom)
 trolley=Node3D.new()
 add_child(trolley)
 box(Vector3(.45,.23,.42),Vector3.ZERO,Color("7d9d9a"),trolley)
 cable=MeshInstance3D.new()
 var cm := material(Color("617f80"))
 cm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 cm.cull_mode=BaseMaterial3D.CULL_DISABLED
 cable.material_override=cm
 cable.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(cable)
 ship=Node3D.new()
 add_child(ship)
 hull_art=Node3D.new()
 ship.add_child(hull_art)
 box(Vector3(4.1,.83,5.8),Vector3(0,-.02,-.15),Color("b6c9bf"),hull_art)
 box(Vector3(4.16,.17,5.85),Vector3(0,.26,-.15),Color("e5a590"),hull_art)
 box(Vector3(3.98,.18,5.65),Vector3(0,.48,-.12),Color("f0dfbc"),hull_art)
 # Bow is a broad, softly faceted wedge, facing the foreground.
 var bow := MeshInstance3D.new()
 var vertices := [Vector3(-2.05,-.42,2.72),Vector3(2.05,-.42,2.72),Vector3(0,-.32,3.82),Vector3(-2.05,.42,2.72),Vector3(2.05,.42,2.72),Vector3(0,.4,3.82)]
 var st := SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 st.set_smooth_group(-1)
 for i in [3,4,5,0,2,1,0,1,4,0,4,3,1,2,5,1,5,4,2,0,3,2,3,5]: st.add_vertex(vertices[i])
 st.generate_normals()
 bow.mesh=st.commit()
 var bm := material(Color("b6c9bf"))
 bm.cull_mode=BaseMaterial3D.CULL_DISABLED
 bow.material_override=bm
 hull_art.add_child(bow)
 for x in [-2.0,2.0]:
  box(Vector3(.12,.24,5.9),Vector3(x,.67,-.12),Color("ecdbc1"),hull_art)
  for z in [-1.8,0,1.8]:
   cylinder(.12,.13,Vector3(x,.06,z),Color("6f9393"),hull_art).rotation_degrees.z=90
  for j in range(4):
   box(Vector3(.015,.025,.25),Vector3(x*1.032,-.2+float(j)*.12,1.9),Color("eef0d9"),hull_art)
 for z in [-.67,.67]:
  box(Vector3(3.7,.012,.035),Vector3(0,.58,z),Color("cbbf9f"),hull_art)
 box(Vector3(.035,.012,4.0),Vector3(0,.58,0),Color("e0c99f"),hull_art)
 box(Vector3(2.4,.65,.7),Vector3(0,.92,-2.5),Color("f5e8ca"),hull_art)
 box(Vector3(2.6,.12,.88),Vector3(0,1.32,-2.5),Color("e2a792"),hull_art)
 for x in [-.75,0,.75]:
  box(Vector3(.48,.28,.02),Vector3(x,1.0,-2.13),Color("89a6ad"),hull_art)
 cylinder(.12,.5,Vector3(.65,1.62,-2.5),Color("88aaa3"),hull_art)
 cylinder(.15,.08,Vector3(.65,1.89,-2.5),Color("efd19b"),hull_art)
 water_inside=box(Vector3(3.7,.025,3.8),Vector3(0,.59,0),Color("92c5cd"),ship)
 water_inside.visible=false
 target=Node3D.new()
 ship.add_child(target)
 prediction=Node3D.new()
 ship.add_child(prediction)
 for i in range(3):
  var n := make_crate(1.0,COLORS[i])
  n.position=Vector3(5.2+float(i%2)*.9,.8+float(i/2)*.65,-1.0+float(i)*1.0)
 for i in range(3):
  var ring := MeshInstance3D.new()
  var torus := TorusMesh.new()
  torus.inner_radius=4.2+float(i)*1.0
  torus.outer_radius=torus.inner_radius+.016
  torus.rings=64
  torus.ring_segments=6
  ring.mesh=torus
  ring.material_override=material(Color("b0d0cb"))
  ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  add_child(ring)
  ring.position=Vector3(-1,-.52,0)

func outline(parent: Node3D, size: float, color: Color) -> void:
 for x in [-size/2,size/2]: box(Vector3(.025,.014,size),Vector3(x,0,0),color,parent)
 for z in [-size/2,size/2]: box(Vector3(size,.014,.025),Vector3(0,0,z),color,parent)

func make_crate(mass: float, color: Color) -> Node3D:
 var node := Node3D.new()
 add_child(node)
 var size: float=.72 if mass<1.5 else .9
 box(Vector3(size,size*.78,size),Vector3.ZERO,color,node)
 for x in [-size*.32,size*.32]:
  box(Vector3(.065,size*.8+.012,size+.018),Vector3(x,0,0),Color("efdfb9"),node)
 box(Vector3(size+.025,.06,size+.025),Vector3(0,-size*.23,0),Color("c4aa88"),node)
 if mass>1.5:
  var label := Label3D.new()
  label.font=load("res://assets/fonts/Nunito.ttf")
  label.text="2t"
  label.font_size=32
  label.pixel_size=.007
  label.outline_size=0
  label.modulate=Color("746658")
  node.add_child(label)
  label.position=Vector3(0,0,size/2+.02)
 return node
func reset_run() -> void:
 sfx.reset_audio(true)
 sfx.menu_music()
 for c in cargo: c.node.queue_free()
 for c in falling: c.node.queue_free()
 for c in debris: c.node.queue_free()
 for r in ripples: r.node.queue_free()
 if not active.is_empty(): active.node.queue_free()
 cargo.clear()
 falling.clear()
 debris.clear()
 ripples.clear()
 active={}
 roll=0
 roll_speed=0
 flood=0
 capsize_time=0
 clock_time=0
 loaded=0
 lost=0
 serial=0
 moment=0
 load_mass=0
 draft=0
 peak_roll=0
 high_heel_time=0
 feedback_time=0
 max_gap=0
 last_release=0
 releases=0
 wave_phase=0
 stack_top=DECK
 height_moment=0
 hoist_y=3.45
 paused=false
 mode="ready"
 action.text="Start loading"
 action.show()
 headline.text="Endless cargo stacking"
 description.text="Every crate changes the balance. Tall stacks sway more."
 feedback.text="Load the lighter side to keep the ship balanced."
 update_ship_transform()
 var start_focus := camera_focus()
 cam.position=start_focus+Vector3(7.8,8.5,12)
 cam.look_at(start_focus)
 boom.position=Vector3.ZERO
 upper_rail.position.y=4.45
 for post in gantry_posts:
  post.scale=Vector3.ONE
  post.position.y=2.4
 target.hide()
 prediction.hide()
 cable.hide()
 trolley.hide()
 update_ui()

func begin() -> void:
 if mode=="over": reset_run()
 if mode!="ready": return
 mode="loading"
 sfx.begin_audio()
 action.hide()
 headline.text="Watch the tilt. Click to release."
 description.text="Time each drop and counterweight the lighter side."
 spawn_load()

func spawn_load() -> void:
 serial+=1
 var period: int=4 if loaded<20 else (3 if loaded<40 else 2)
 var mass: float=2.0 if serial%period==0 else 1.0
 var size: float=.72 if mass<1.5 else .9
 var row: int=(serial-1)%5
 var side: float=-1.0 if serial%2==1 else 1.0
 var node := make_crate(mass,COLORS[(serial-1)%COLORS.size()])
 active={"node":node,"mass":mass,"size":size,"row":row,"side":side,"age":0.0,"x":side*3.18,"z":float(row-2)*.80,"vx":0.0,"id":serial}
 node.position=Vector3(active.x,hoist_y,active.z)
 target.show()
 prediction.show()
 cable.show()
 trolley.show()

func activate() -> void:
 if paused: return
 if mode in ["ready","over"]: begin()
 elif mode=="loading": release_load()

func release_load() -> void:
 if mode!="loading" or paused or active.is_empty(): return
 releases+=1
 sfx.play("release")
 max_gap=maxf(max_gap,clock_time-last_release)
 last_release=clock_time
 var node: Node3D=active.node
 falling.append({"node":node,"mass":active.mass,"size":active.size,"row":active.row,"velocity":Vector3(active.vx*.12,-.1,0),"age":0.0})
 active={}
 spawn_load()

func weigh_cargo() -> void:
 moment=0
 load_mass=0
 height_moment=0
 stack_top=DECK
 for c in cargo:
  moment+=c.mass*c.x
  load_mass+=c.mass
  height_moment+=c.mass*maxf(0,c.y-DECK)
  stack_top=maxf(stack_top,c.y+c.size*.39)

func update_ship_transform() -> void:
 draft=minf(.43,load_mass*.014)
 ship.position=Vector3(sin(clock_time*.9)*.10,-.04-draft+sin(clock_time*1.8)*.025,0)
 ship.rotation.z=-roll


func recommended_x(mass: float) -> float:
 var effective_moment: float=moment+sin(roll)*height_moment*.055
 return clampf(-effective_moment/maxf(mass,1.0)*.72-roll*.35-roll_speed*.45,-1.22,1.22)

func predict_point() -> Vector3:
 if active.is_empty(): return Vector3.ZERO
 var start: Vector3=ship.to_local(active.node.position)
 var velocity: Vector3=ship.basis.inverse()*Vector3(active.vx*.12,-.1,0)
 var gravity_y: float=maxf(.1,GRAVITY*cos(roll))
 var gravity_x: float=GRAVITY*sin(roll)
 var half: float=active.size*.39
 var t: float=(velocity.y+sqrt(maxf(0,velocity.y*velocity.y+2*gravity_y*(start.y-DECK-half))))/gravity_y
 var best_time := t
 var support := DECK
 for c in cargo:
  if absf(c.z-active.z)>=.55: continue
  var top: float=c.y+c.size*.39
  if top+half>start.y+.015: continue
  var seconds: float=(velocity.y+sqrt(maxf(0,velocity.y*velocity.y+2*gravity_y*(start.y-top-half))))/gravity_y
  if seconds<0 or seconds>=best_time: continue
  var x: float=start.x+velocity.x*seconds+.5*gravity_x*seconds*seconds
  if absf(x-c.x)<(c.size+active.size)*.43:
   best_time=seconds
   support=top
 var x: float=start.x+velocity.x*best_time+.5*gravity_x*best_time*best_time
 return Vector3(x,support+.025,active.z)

func support_height(x: float,z: float,size: float,ignore_id: int=-1,below: float=INF) -> float:
 var support := DECK
 for c in cargo:
  if c.node.get_instance_id()==ignore_id: continue
  if absf(c.z-z)<.55 and absf(c.x-x)<(c.size+size)*.43:
   var top: float=c.y+c.size*.39
   if top<=below+.08: support=maxf(support,top)
 return support

func land_crate(c: Dictionary, local: Vector3) -> void:
 var node: Node3D=c.node
 var before := moment
 var impact: float=absf(c.velocity.y)*c.mass
 # Landing on a side produces a roll impulse before the new weight keeps pulling.
 roll_speed+=local.x*impact*.012
 node.reparent(ship)
 var height: float=support_height(local.x,local.z,c.size)+c.size*.39
 cargo.append({"node":node,"mass":c.mass,"size":c.size,"x":local.x,"z":local.z,"y":height,"v":c.velocity.x*.25+roll_speed*.12,"vy":0.0,"row":c.row})
 node.position=Vector3(local.x,height,local.z)
 node.rotation=Vector3.ZERO
 loaded+=1
 if loaded>best:
  best=loaded
  if save_enabled:
   var best_file := FileAccess.open("user://cargo-best.txt",FileAccess.WRITE)
   if best_file: best_file.store_string(str(best))
 weigh_cargo()
 sfx.impact(c.mass,absf(moment)<absf(before)-.12)
 
 if absf(moment)<absf(before)-.12:
  feedback.text="Counterweight added. Balance recovering."
 elif absf(moment)<.55:
  feedback.text="Balanced load ✦ Keep going"
 else:
  feedback.text="%s-heavy %+.1f · Load the %s side next" % ["Right" if moment>0 else "Left",moment,"Left" if moment>0 else "Right"]
 feedback_time=1.4

func lose_crate(node: Node3D, velocity: Vector3, from_deck: bool) -> void:
 var global_pose := node.global_transform
 node.reparent(self)
 node.global_transform=global_pose
 debris.append({"node":node,"velocity":velocity,"age":0.0,"splashed":false})
 lost+=1
 feedback.text="%s · Lost %d/4" % ["Crate slid overboard" if from_deck else "Crate lost overboard",lost]
 feedback_time=1.6
 if lost>=4: finish(false,"Too much cargo lost","Four crates lost. Try another run.")

func step_world(dt: float) -> void:
 if mode!="loading" or paused: return
 clock_time+=dt
 weigh_cargo()
 var pressure: float=1.0+minf(float(loaded)*.018+clock_time*.005,1.8)
 wave_phase+=dt*(1.55-minf(float(loaded)*.004,.45))
 var wave: float=(sin(wave_phase)*.16+sin(clock_time*2.85+.8)*.065)*pressure
 var inertia: float=1.0+minf(load_mass*.030,1.6)+minf(height_moment*.006,1.2)
 roll_speed+=(moment*.22+sin(roll)*height_moment*.012+wave-roll*2.4-roll_speed*1.55)/inertia*dt
 roll+=roll_speed*dt
 peak_roll=maxf(peak_roll,absf(roll))
 if absf(roll)>.28: high_heel_time+=dt
 update_ship_transform()
 hoist_y=move_toward(hoist_y,maxf(3.45,ship.position.y+stack_top+2.8),dt*3.5)
 # Released loads fall immediately, while the next load is already sweeping.
 if not active.is_empty():
  active.age+=dt
  var sweep: float=1.40+minf(float(loaded)*.014,1.2)
  active.x=active.side*3.18*cos(active.age*sweep)
  active.vx=-active.side*3.18*sweep*sin(active.age*sweep)
  active.node.position=Vector3(active.x,hoist_y+sin(clock_time*1.9)*.035,active.z)
 for i in range(falling.size()-1,-1,-1):
  var c: Dictionary=falling[i]
  c.age+=dt
  c.velocity.y-=GRAVITY*dt
  c.node.position+=c.velocity*dt
  c.node.rotation.z+=c.velocity.x*dt*.07
  var local: Vector3=ship.to_local(c.node.position)
  var support: float=support_height(local.x,local.z,c.size)
  if absf(local.x)<HALF_WIDTH-.10 and absf(local.z)<2.0 and local.y-c.size*.39<=support and c.velocity.y<0:
   falling.remove_at(i)
   land_crate(c,local)
  elif c.node.position.y<-.38:
   falling.remove_at(i)
   lose_crate(c.node,c.velocity,false)
 for i in range(cargo.size()-1,-1,-1):
  var c: Dictionary=cargo[i]
  # Static friction holds the cargo until a substantial heel; gravity then slides it downhill.
  var gravity_slide: float=sin(roll)*9.0
  var static_limit: float=2.15/(1.0+maxf(0,c.y-DECK)*.045)
  if absf(gravity_slide)>static_limit:
   c.v+=(gravity_slide-signf(gravity_slide)*1.65)*dt
  elif absf(c.v)>.01:
   c.v=move_toward(c.v,0,1.7*dt)
  c.x+=c.v*dt
  c.vy-=GRAVITY*dt
  var support: float=support_height(c.x,c.z,c.size,c.node.get_instance_id(),c.y-c.size*.39+.1)
  c.y+=c.vy*dt
  if c.y-c.size*.39<=support:
   c.y=support+c.size*.39
   c.vy=0
  if absf(c.x)>HALF_WIDTH+.08:
   var v := Vector3(c.v,-.2,0).rotated(Vector3.FORWARD,-roll)
   cargo.remove_at(i)
   lose_crate(c.node,v,true)
  else:
   c.node.position=Vector3(c.x,c.y,c.z)
 # Neighbouring boxes can push one another, rather than pass through each other.
 for i in range(cargo.size()):
  for j in range(i+1,cargo.size()):
   var a: Dictionary=cargo[i]
   var b: Dictionary=cargo[j]
   if absf(a.z-b.z)>.55 or absf(a.y-b.y)>.2: continue
   var separation: float=(a.size+b.size)*.48
   var dx: float=b.x-a.x
   if absf(dx)<separation and absf(dx)>.001:
    var push: float=(separation-absf(dx))*.5
    a.x-=signf(dx)*push
    b.x+=signf(dx)*push
    var combined: float=(a.v*a.mass+b.v*b.mass)/(a.mass+b.mass)
    a.v=combined
    b.v=combined
 weigh_cargo()
 var left_edge: float=ship.to_global(Vector3(-HALF_WIDTH,DECK,0)).y
 var right_edge: float=ship.to_global(Vector3(HALF_WIDTH,DECK,0)).y
 var submerged: float=-.50-minf(left_edge,right_edge)
 if submerged>0:
  flood+=submerged*dt*43.0
 elif absf(roll)<.15:
  flood=maxf(0,flood-dt*1.7)
 if absf(roll)>.65: capsize_time+=dt
 else: capsize_time=maxf(0,capsize_time-dt*1.5)
 if capsize_time>.55 or flood>=100:
  finish(false,"The ship lost balance","Counterweight the lighter side before the cargo starts sliding.")

func _physics_process(dt: float) -> void:
 if tests or demo: return
 step_world(dt)

func demo_input() -> void:
 if mode!="loading" or active.is_empty(): return
 var landing := predict_point()
 var desired: float=recommended_x(active.mass)
 if bad_demo: desired=1.22
 # Include a pair of deliberate right-heavy loads before active correction.
 elif releases in [1,2]: desired=.92
 if (active.vx>0 and landing.x>=desired) or (active.vx<0 and landing.x<=desired): release_load()

func _process(dt: float) -> void:
 if tests: return
 if demo and mode=="ready":
  intro_elapsed+=dt
  if intro_elapsed>=demo_intro: begin()
 var slide_speed := 0.0
 for c in cargo: slide_speed=maxf(slide_speed,absf(c.v))
 sfx.set_motion(slide_speed*.8,roll,roll_speed,0.0)
 if demo and not paused and clock_time<demo_duration:
  for i in range(4):
   step_world(1.0/120)
   demo_input()
 if not paused:
  feedback_time=maxf(0,feedback_time-dt)
  update_effects(dt)
 update_visuals()
 update_ui()
 if demo: RenderingServer.force_draw(false,1.0/30.0)
 if demo and not demo_ending:
  if not captured and loaded>=25:
   captured=true
   save_capture("res://captures/cargo-rising.png")
  if mode=="over" or clock_time>=demo_duration:
   demo_ending=true
   if not pending_capture:
    await save_capture("res://captures/cargo-rising-"+("failure" if bad_demo else "final")+".png")
   await get_tree().create_timer(2.2).timeout
   print("SFX EVENTS: ",sfx.event_counts)
   print("DEMO PASS: loaded=",loaded," lost=",lost," peak_heel=",rad_to_deg(peak_roll)," max_input_gap=",max_gap," time=",clock_time," mode=",mode)
   sfx.reset_audio()
   await get_tree().process_frame
   get_tree().quit()

func camera_focus() -> Vector3:
 var rise_margin: float=clampf((stack_top-3.0)*.25,0,.9)
 return Vector3(1.4,maxf(.25,hoist_y-3.05+rise_margin),-.5)

func update_visuals() -> void:
 if active.is_empty():
  cable.hide()
  target.hide()
  prediction.hide()
  return
 var p: Vector3=active.node.position
 boom.position.z=lerpf(boom.position.z,p.z,.17 if not paused else 0)
 boom.position.y=p.y-3.45
 upper_rail.position.y=p.y+1.0
 for post in gantry_posts:
  var length: float=p.y+.6
  post.scale.y=length/4.05
  post.position.y=.42+length*.5
 trolley.position=Vector3(p.x,p.y+1.03,p.z)
 var mesh := ImmediateMesh.new()
 mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
 var bottom := p+Vector3(0,active.size*.39,0)
 for side in [-1,1]:
  var a := Vector3(p.x+side*.22,p.y+.97,p.z)
  var b := bottom+Vector3(side*.22,0,0)
  for v in [a+Vector3(-.012,0,0),a+Vector3(.012,0,0),b+Vector3(.012,0,0),a+Vector3(-.012,0,0),b+Vector3(.012,0,0),b+Vector3(-.012,0,0)]: mesh.surface_add_vertex(v)
 mesh.surface_end()
 cable.mesh=mesh
 var good_x: float=recommended_x(active.mass)
 target.position=Vector3(good_x,support_height(good_x,active.z,active.size)+.024,active.z)
 prediction.position=predict_point()
 water_inside.visible=flood>8
 water_inside.scale.x=clampf(flood/70.0,.05,1)
 # Follow the growing heap without shrinking crates into unreadable dots.
 var focus := camera_focus()
 var desired := focus+Vector3(7.8,8.5,12)
 var blend: float=0.0 if paused else .10
 cam.position=cam.position.lerp(desired,blend)
 cam.look_at(cam.position-Vector3(7.8,8.5,12))

func update_effects(dt: float) -> void:
 for i in range(debris.size()-1,-1,-1):
  var d: Dictionary=debris[i]
  d.age+=dt
  d.velocity.y-=GRAVITY*dt
  d.node.position+=d.velocity*dt
  d.node.rotation+=Vector3(.3,.1,.4)*dt
  if d.node.position.y<-.5 and not d.splashed:
   d.splashed=true
   splash(d.node.position)
  if d.node.position.y< -3 or d.age>2.5:
   d.node.queue_free()
   debris.remove_at(i)
 for i in range(ripples.size()-1,-1,-1):
  var r: Dictionary=ripples[i]
  r.age+=dt
  r.node.scale=Vector3.ONE*(.2+r.age*.8)
  r.node.transparency=minf(1,r.age/1.2)
  if r.age>1.2:
   r.node.queue_free()
   ripples.remove_at(i)

func splash(p: Vector3) -> void:
 sfx.play("splash")
 var n := MeshInstance3D.new()
 var torus := TorusMesh.new()
 torus.inner_radius=.35
 torus.outer_radius=.4
 torus.rings=24
 torus.ring_segments=6
 n.mesh=torus
 n.material_override=material(Color("dcecdf"))
 n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(n)
 n.position=Vector3(p.x,-.51,p.z)
 ripples.append({"node":n,"age":0.0})

func finish(_success: bool,title: String,detail: String) -> void:
 if mode!="loading": return
 mode="over"
 sfx.end_audio(false)
 headline.text=title
 description.text=detail
 feedback.text="%d loaded · %.1f m high · %d lost" % [loaded,stack_top-DECK,lost]
 action.text="Try again"
 action.show()
 target.hide()
 prediction.hide()
 if loaded>best:
  best=loaded
  if save_enabled:
   var f := FileAccess.open("user://cargo-best.txt",FileAccess.WRITE)
   if f: f.store_string(str(best))

func toggle_pause() -> void:
 if mode!="loading": return
 paused=not paused
 sfx.set_paused(paused)

func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_ESCAPE: toggle_pause()
  elif event.keycode in [KEY_SPACE,KEY_ENTER]: activate()
 elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
  if mode=="loading": release_load()
 elif event is InputEventScreenTouch and event.pressed:
  if mode=="loading": release_load()
func ui_line(text: String,size: int,y: float,color: Color=Color("36535a")) -> Label:
 var n := Label.new()
 n.text=text
 n.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 n.add_theme_font_size_override("font_size",size)
 n.add_theme_color_override("font_color",color)
 n.mouse_filter=Control.MOUSE_FILTER_IGNORE
 ui.add_child(n)
 n.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
 n.position.y=y
 return n

func make_ui() -> void:
 var layer := CanvasLayer.new()
 add_child(layer)
 ui=Control.new()
 layer.add_child(ui)
 ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var theme := Theme.new()
 theme.default_font=load("res://assets/fonts/Nunito.ttf")
 ui.theme=theme
 hud=ui_line("",24,18)
 hud.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
 hud.offset_left=24
 stats=ui_line("",13,53,Color("587871"))
 stats.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
 stats.offset_left=25
 headline=ui_line("",23,92)
 description=ui_line("",14,127,Color("5b7873"))
 next_info=ui_line("",13,25,Color("587871"))
 balance_marker=ColorRect.new()
 ui.add_child(balance_marker)
 balance_marker.hide()
 feedback=ui_line("",16,0)
 feedback.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 feedback.offset_top=-43
 feedback.offset_bottom=-19
 hint=ui_line("Click / Space to drop · Esc to pause",12,0,Color("587871"))
 hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 hint.offset_top=-21
 hint.offset_bottom=-3
 action=Button.new()
 ui.add_child(action)
 action.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
 action.offset_left=-115
 action.offset_right=115
 action.offset_top=-105
 action.offset_bottom=-63
 action.focus_mode=Control.FOCUS_NONE
 action.add_theme_font_size_override("font_size",18)
 action.add_theme_color_override("font_color",Color("415b5b"))
 var style := StyleBoxFlat.new()
 style.bg_color=Color("eed5a6")
 style.set_corner_radius_all(21)
 action.add_theme_stylebox_override("normal",style)
 action.pressed.connect(activate)
 sound_button=Button.new()
 sound_button.text="Sound"
 ui.add_child(sound_button)
 sound_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
 sound_button.offset_left=-82
 sound_button.offset_right=-24
 sound_button.offset_top=18
 sound_button.offset_bottom=54
 sound_button.focus_mode=Control.FOCUS_NONE
 sound_button.add_theme_font_size_override("font_size",13)
 sound_button.pressed.connect(toggle_sound)

func toggle_sound() -> void:
 sfx.set_muted(not sfx.muted)
 sound_button.text="Muted" if sfx.muted else "Sound"
 if not sfx.muted: sfx.play("ui")

func update_ui() -> void:
 hud.visible=mode!="ready"
 stats.visible=mode!="ready"
 hud.text="%d %s  ·  %.1f m" % [loaded,"crate" if loaded==1 else "crates",stack_top-DECK]
 stats.text="Heel %.1f°  ·  Lost %d/4  ·  Water %d%%" % [absf(rad_to_deg(roll)),lost,int(flood)]
 headline.visible=mode=="over" or paused
 description.visible=mode=="over"
 hint.hide()
 feedback.hide()
 next_info.hide()
 if not active.is_empty():
  next_info.text="%.0ft" % active.mass
 if mode=="loading":
  headline.text="Paused · Esc to resume" if paused else ""
  feedback.add_theme_color_override("font_color",Color("a36e57") if absf(roll)>.3 else Color("496d62"))

func save_capture(path: String) -> void:
 pending_capture=true
 await get_tree().process_frame
 get_viewport().get_texture().get_image().save_png(path)
 print("CAPTURE PASS: ",path," loaded=",loaded," heel=",rad_to_deg(roll)," moment=",moment)
 pending_capture=false

func test_drop_at(x: float) -> void:
 active.node.position=ship.to_global(Vector3(x,stack_top+2.8,active.z))
 active.vx=0.0
 release_load()
 for i in range(100): step_world(1.0/120)

func run_tests() -> void:
 begin()
 var first_id: int=active.id
 active.node.position=ship.to_global(Vector3(1.0,3.4,active.z))
 active.vx=0.0
 release_load()
 assert(active.id!=first_id and falling.size()==1 and active.age==0,"Next load must be available while old crate falls")
 for i in range(190): step_world(1.0/120)
 assert(loaded==1 and moment>.7 and roll>.02,"Off-centre landing must create real persistent heel")
 var before := moment
 test_drop_at(-1.0)
 assert(absf(moment)<absf(before)*.5,"Opposite load must counterweight previous cargo")
 var carried_roll := roll
 var carried_speed := roll_speed
 release_load()
 assert(roll==carried_roll and roll_speed==carried_speed,"Next release must not reset boat state")
 toggle_pause()
 var old_clock := clock_time
 step_world(.5)
 assert(clock_time==old_clock)
 toggle_pause()
 reset_run()
 begin()
 var waiting_id: int=active.id
 var initial_direction: float=active.side
 var returned := false
 for i in range(120*8):
  step_world(1.0/120)
  if active.vx*initial_direction>0: returned=true
 assert(returned and active.id==waiting_id and releases==0 and falling.is_empty(),"The same crate must return without automatic release")
 assert(clock_time>7.9 and absf(roll)>.001,"Waiting must keep waves and ship motion active")
 release_load()
 assert(releases==1 and active.id!=waiting_id and falling.size()==1,"Player can release the retained crate after waiting")
 # Player policy uses the same predicted landing and ordinary release as real play.
 reset_run()
 begin()
 bad_demo=false
 for i in range(120*90):
  step_world(1.0/120)
  demo_input()
  if mode=="over": break
 print("ENDLESS RUN: loaded=",loaded," height=",stack_top-DECK," lost=",lost," heel=",rad_to_deg(roll)," flood=",flood," mode=",mode)
 assert(loaded>20,"Ordinary loading must build a genuine growing heap beyond 20 crates")
 assert(stack_top>3.45 and hoist_y>5,"Crates and crane must rise beyond the old crane height")
 assert(cargo.size()==loaded-lost,"Landed crates must remain visible, never be transferred away")
 var previous_top := stack_top
 var old_roll := roll
 var old_speed := roll_speed
 weigh_cargo()
 assert(stack_top==previous_top and roll==old_roll and roll_speed==old_speed)
 reset_run()
 begin()
 bad_demo=true
 for i in range(120*50):
  step_world(1.0/120)
  demo_input()
  if mode=="over": break
 print("BIAS RUN: loaded=",loaded," lost=",lost," peak=",rad_to_deg(peak_roll)," flood=",flood," mode=",mode)
 assert(mode=="over" and peak_roll>.25,"Repeated same-side cargo must cause a physical failure cascade")
 activate()
 assert(mode=="loading" and loaded==0 and lost==0 and cargo.is_empty())
 assert(hoist_y==3.45 and stack_top==DECK and height_moment==0 and roll==0)
 print("SELF TEST PASS: falling+next input overlap, inherited heel+momentum, counterweight recovery, repeat swings without auto-drop, endless progression, growing visible heap+height torque+hoist tracking, cumulative overload, pause, restart")
 get_tree().quit()
