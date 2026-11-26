extends Node2D

const GRAVE_PROPS = preload("res://moon-props.png")
const MOONFALL = preload("res://moonfall.webp")
const WORLD = Vector2(1450, 1000)
const CLASSES = {
 "Wizard": ["Ember Lance", "Frost Nova", "Arcane Focus"],
 "Warrior": ["Shield Bash", "Iron Cyclone", "Bulwark"],
 "Clerk": ["Radiant Brand", "Sanctuary", "Renewal"],
 "Archer": ["Twinshot", "Thorn Volley", "Fleetfoot"]
}
var region = "Briarwood"
var job = "Clerk"
var position_player = Vector2(400, 400)
var hp = 100.0
var foes: Array = []
var trees: Array = []
var grave_props: Array = []
const BURIAL_PLOTS = [
 [245,332,0],[505,316,1],[947,330,2],[1218,475,0],
 [390,514,2],[674,548,0],[920,615,1],[191,782,1],
 [530,751,1],[866,822,2],[1230,832,0]
]
const PLOT_PIECES = [
 [[0,-25,-7],[2,19,7],[4,39,20],[5,-4,18]],
 [[3,-28,-8],[2,8,2],[4,32,18],[5,17,20]],
 [[1,20,-12],[4,-25,8],[5,0,12],[5,-45,16]]
]
var effects: Array = []
var cooldown = [0.0, 0.0, 0.0]
var buff = 0.0
var camera = Vector2.ZERO
var motion = Vector2.ZERO
var stick_center = Vector2.ZERO
var touch_id = -1
var walking = 0.0
var move_amount = 0.0
var facing = Vector2.DOWN
var cast_slot = -1
var cast_remaining = 0.0
const CAST_DURATION = 0.42
var chosen = false
var rng = RandomNumberGenerator.new()

func _ready() -> void:
 rng.seed = 629
 for i in 95:
  var point = Vector2(rng.randf_range(40, 1410), rng.randf_range(40, 960))
  if point.distance_to(position_player) > 100:
   trees.append(point)
 for plot in BURIAL_PLOTS:
  for piece in PLOT_PIECES[plot[2]]:
   grave_props.append({"pos":Vector2(plot[0]+piece[1],plot[1]+piece[2]),"variant":piece[0]})
 for point in [Vector2(520,400),Vector2(660,350),Vector2(420,640),Vector2(760,530),Vector2(880,700),Vector2(1150,400)]:
  foes.append({"pos":point,"hp":65.0,"max":65.0,"attack":0.0})
 queue_redraw()

func _process(delta: float) -> void:
 if not chosen:
  queue_redraw()
  return
 for i in 3:
  cooldown[i] = maxf(0, cooldown[i] - delta)
 buff = maxf(0, buff - delta)
 if job == "Clerk" and buff > 0:
  hp = minf(100, hp + 5 * delta)
 var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
 if motion.length() > 0.05:
  direction = motion
 position_player = (position_player + direction * 150 * delta * (1.4 if job == "Archer" and buff > 0 else 1.0)).clamp(Vector2(20,20),WORLD - Vector2(20,20))
 move_amount = move_toward(move_amount, direction.length(), delta * 8)
 if direction.length() > 0.05:
  facing = direction.normalized()
  walking += delta * 12
 cast_remaining = maxf(0.0, cast_remaining - delta)
 for e in foes:
  if e.hp <= 0:
   continue
  var distance = e.pos.distance_to(position_player)
  if distance < 180 and distance > 25:
   e.pos += e.pos.direction_to(position_player) * 45 * delta
  e.attack = maxf(0, e.attack-delta)
  if distance < 32 and e.attack <= 0:
   hp -= 4 if job == "Warrior" and buff > 0 else 10
   e.attack = 1.5
 for fx in effects:
  fx.life -= delta
 effects = effects.filter(func(f): return f.life > 0)
 if hp <= 0:
  hp = 100
  position_player = Vector2(400,400)
 camera = (position_player - get_viewport_rect().size / 2).clamp(Vector2.ZERO, WORLD - get_viewport_rect().size)
 queue_redraw()

func attack(slot: int) -> void:
 if not chosen or cooldown[slot] > 0:
  return
 if slot == 2:
  cast_slot = slot
  cast_remaining = CAST_DURATION
  buff = 6
  cooldown[slot] = 12
  effects.append({"pos":position_player,"life":0.6,"radius":30.0,"text":"BUFF"})
  return
 var nearby = foes.filter(func(e): return e.hp > 0)
 nearby.sort_custom(func(a,b): return a.pos.distance_to(position_player) < b.pos.distance_to(position_player))
 var range_value = 70.0 if job == "Warrior" else 245.0
 if slot == 0:
  if nearby.is_empty() or nearby[0].pos.distance_to(position_player) > range_value:
   return
  facing = position_player.direction_to(nearby[0].pos)
  damage(nearby[0], 20.0 if job != "Wizard" else 28.0)
  effects.append({"pos":nearby[0].pos,"life":0.35,"radius":18.0,"text":""})
 else:
  var center = position_player
  if job == "Archer":
   if nearby.is_empty() or nearby[0].pos.distance_to(position_player) > 245:
    return
   center = nearby[0].pos
  for e in nearby:
   if e.pos.distance_to(center) < 100:
    damage(e, 26.0)
  if job == "Clerk":
   hp = minf(100,hp+16)
  effects.append({"pos":center,"life":0.5,"radius":100.0,"text":""})
 cast_slot = slot
 cast_remaining = CAST_DURATION
 cooldown[slot] = 0.85 if slot == 0 else 4.0

func damage(e: Dictionary, amount: float) -> void:
 var value = amount * (1.5 if job == "Wizard" and buff > 0 else 1.0)
 e.hp -= value
 effects.append({"pos":e.pos+Vector2(0,-36),"life":0.8,"radius":0.0,"text":str(int(value))})

func change_region() -> void:
 region = "Moonfall" if region == "Briarwood" else "Briarwood"
 position_player = Vector2(720, 780) if region == "Moonfall" else Vector2(400,400)
 camera = (position_player - get_viewport_rect().size / 2).clamp(Vector2.ZERO, WORLD - get_viewport_rect().size)
 effects.clear()
 for e in foes:
  e.hp = e.max
  e.attack = 0.0
 queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode == KEY_M and chosen: change_region()
  if event.keycode == KEY_1: attack(0)
  if event.keycode == KEY_2: attack(1)
  if event.keycode == KEY_3: attack(2)
 if event is InputEventScreenTouch:
  if event.pressed:
   handle_press(event.position,event.index)
  elif event.index == touch_id:
   touch_id = -1
   motion = Vector2.ZERO
 if event is InputEventScreenDrag and event.index == touch_id:
  motion = ((event.position - stick_center) / 55.0).limit_length(1)
 if event is InputEventMouseButton and event.pressed:
  handle_press(event.position,-2)

func handle_press(point: Vector2, index: int) -> void:
 var size = get_viewport_rect().size
 if not chosen:
  for i in 4:
   if Rect2(size.x/2-160,155+i*62,320,48).has_point(point):
    job = CLASSES.keys()[i]
    chosen = true
  return
 if Rect2(size.x-155,12,143,44).has_point(point):
  change_region()
  return
 for i in 3:
  if Rect2(size.x-260+i*82,size.y-80,76,60).has_point(point):
   attack(i)
   return
 if point.x < size.x/2 and point.y > size.y/2 and index >= 0:
  touch_id = index
  stick_center = point

func _draw() -> void:
 var size = get_viewport_rect().size
 if not chosen:
  draw_rect(Rect2(Vector2.ZERO,size),Color("#183c35"))
  draw_string(ThemeDB.fallback_font,Vector2(size.x/2-130,100),"ELDERBELL",HORIZONTAL_ALIGNMENT_LEFT,-1,32,Color("#f4dda6"))
  draw_string(ThemeDB.fallback_font,Vector2(size.x/2-130,130),"Choose your class",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)
  for i in 4:
   var r = Rect2(size.x/2-160,155+i*62,320,48)
   draw_rect(r,Color("#355d4d"))
   draw_string(ThemeDB.fallback_font,r.position+Vector2(14,30),CLASSES.keys()[i],HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color.WHITE)
  return
 draw_set_transform(-camera)
 if region == "Moonfall":
  draw_texture_rect(MOONFALL,Rect2(Vector2.ZERO,WORLD),false)
 else:
  draw_rect(Rect2(Vector2.ZERO,WORLD),Color("#699850"))
  for x in range(0,1450,60):
   for y in range(0,1000,60):
    draw_circle(Vector2(x+((y*3)%47),y+((x*7)%43)),2,Color("#81aa5f"))
  draw_line(Vector2(0,650),Vector2(1450,300),Color("#bd9665"),38,true)
 var objects: Array = []
 for tree in trees if region == "Briarwood" else []:
  objects.append({"y":tree.y,"type":"tree","pos":tree})
 if region == "Moonfall":
  for prop in grave_props:
   objects.append({"y":prop.pos.y,"type":"grave","pos":prop.pos,"variant":prop.variant})
 for e in foes:
  if e.hp>0: objects.append({"y":e.pos.y,"type":"enemy","pos":e.pos,"data":e})
 objects.append({"y":position_player.y,"type":"player","pos":position_player})
 objects.sort_custom(func(a,b): return a.y < b.y)
 for item in objects:
  var p: Vector2 = item.pos
  if item.type == "tree":
   draw_rect(Rect2(p+Vector2(-5,-35),Vector2(10,35)),Color("#594433"))
   draw_circle(p+Vector2(0,-46),25,Color("#2c643f"))
   draw_circle(p+Vector2(-12,-55),16,Color("#3d7950"))
  elif item.type == "grave":
   var prop_scale = 1.4 if item.variant < 2 else 1.0
   var tint = Color(1,1,1,0.45) if p.y >= position_player.y and p.y-position_player.y < 70*prop_scale and absf(p.x-position_player.x)<27*prop_scale else Color.WHITE
   draw_texture_rect_region(GRAVE_PROPS,Rect2(p-Vector2(32,74)*prop_scale,Vector2(64,80)*prop_scale),Rect2(item.variant*64,0,64,80),tint)
  elif item.type == "enemy":
   draw_circle(p+Vector2(0,-9),12,Color("#6eb4ce"))
   draw_circle(p+Vector2(-4,-12),2,Color("#152e3c"))
   draw_circle(p+Vector2(4,-12),2,Color("#152e3c"))
   draw_rect(Rect2(p+Vector2(-17,-31),Vector2(34,5)),Color("#25352f"))
   draw_rect(Rect2(p+Vector2(-17,-31),Vector2(34*maxf(0,item.data.hp)/item.data.max,5)),Color("#e97b64"))
  else:
   draw_player(p)
 for fx in effects:
  if fx.text != "":
   draw_string(ThemeDB.fallback_font,fx.pos,fx.text,HORIZONTAL_ALIGNMENT_CENTER,40,16,Color("#fff1a9"))
  else:
   draw_arc(fx.pos,fx.radius,0,TAU,32,Color("#ffe6a1"),3)
 draw_set_transform(Vector2.ZERO)
 draw_rect(Rect2(12,12,220,48),Color("#173a32"))
 draw_string(ThemeDB.fallback_font,Vector2(24,42),job+"  HP "+str(int(hp)),HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color.WHITE)
 draw_rect(Rect2(size.x-155,12,143,44),Color("#244b3d"))
 draw_string(ThemeDB.fallback_font,Vector2(size.x-148,39),region+" [M]",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)
 for i in 3:
  var r=Rect2(size.x-260+i*82,size.y-80,76,60)
  draw_rect(r,Color("#244b3d"))
  draw_string(ThemeDB.fallback_font,r.position+Vector2(6,22),str(i+1)+" "+CLASSES[job][i].split(" ")[0],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
  if cooldown[i]>0:
   draw_string(ThemeDB.fallback_font,r.position+Vector2(8,45),str(int(ceil(cooldown[i])))+"s",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#ffdc91"))
 if touch_id >= 0:
  draw_arc(stick_center,55,0,TAU,32,Color("#eddbab"),3)
  draw_circle(stick_center+motion*55,18,Color("#719b7a"))

func draw_player(p: Vector2) -> void:
 var run_phase = sin(walking) * move_amount
 var lean = facing * (4.0 * move_amount)
 var bob = absf(run_phase) * 2.0
 var skin = Color("#edbe93")
 var armor = Color("#9e5057") if job == "Warrior" else Color("#7e5591") if job == "Wizard" else Color("#ede0a9") if job == "Clerk" else Color("#559061")
 var hip = p + Vector2(0,-9-bob)
 var shoulder = hip + Vector2(lean.x,-11 + lean.y * 0.35)
 var head = shoulder + Vector2(lean.x * 0.3,-11)
 draw_line(p + Vector2(-4,0),hip + Vector2(-4 + run_phase*4,0),Color("#453746"),4)
 draw_line(p + Vector2(4,0),hip + Vector2(4 - run_phase*4,0),Color("#453746"),4)
 draw_line(hip,shoulder,Color("#372c34"),15)
 draw_line(hip,shoulder,armor,11)
 draw_circle(head,9,Color("#392f37"))
 draw_circle(head + Vector2(0,1),7,skin)
 draw_rect(Rect2(head + Vector2(-7,-8),Vector2(14,5)),Color("#64483d"))
 var sweep = 0.0
 if cast_remaining > 0:
  sweep = sin((1.0-cast_remaining/CAST_DURATION)*PI)
 var side = -1.0 if facing.x < -0.1 else 1.0
 var hand = shoulder + Vector2(side * (8 + 6*sweep),4)
 if job == "Warrior":
  draw_line(shoulder,hand,Color("#d8c8b5"),4)
  if cast_slot == 0 and cast_remaining > 0:
   draw_circle(hand + facing*5,7,Color("#b18c58"))
   draw_circle(hand + facing*5,4,Color("#e8d19f"))
   draw_line(hand + facing*13 + Vector2(-3,-5),hand + facing*13 + Vector2(3,5),Color("#fff2cb"),3)
  else:
   var angle = -PI/3 + sweep * (PI * 1.35 if cast_slot == 1 else 0.4)
   var tip = hand + Vector2(side * sin(angle)*18,-cos(angle)*18)
   draw_line(hand,tip,Color("#d7e4df"),4)
   draw_line(hand + Vector2(-4,1),hand + Vector2(4,1),Color("#b9985a"),3)
   if cast_slot == 1 and cast_remaining > 0:
    draw_arc(p+Vector2(0,-10),27,angle-0.6,angle+1.1,12,Color("#fbe5b6"),3)
   elif cast_slot == 2 and cast_remaining > 0:
    draw_arc(p+Vector2(0,-12),23,0,TAU,20,Color("#ffe1a3"),2)
 else:
  draw_line(shoulder,hand,skin,4)
