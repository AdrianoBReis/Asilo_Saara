extends Node3D

const WALK_SPEED := 4.4
const LOOK_SENSITIVITY := 0.0023
const MAX_SANITY := 100.0
const MEDICINE_RANGE := 2.4

var sanity := 78.0
var flashlight_energy := 100.0
var meeting_remaining := 0.0
var isolation_remaining := 0.0
var game_time := 0.0
var medicine_cooldown := 0.0
var flashlight_on := true
var mouse_captured := false
var player: CharacterBody3D
var head: Node3D
var flashlight: SpotLight3D
var sanity_bar: ProgressBar
var sanity_label: Label
var status_label: Label
var prompt_label: Label
var meeting_panel: PanelContainer
var countdown_label: Label
var vote_label: Label
var distortion: ColorRect
var corridor_lights: Array[OmniLight3D] = []
var medicine: Node3D

func _ready() -> void:

	_create_world()
	_create_player()
	_create_interface()
	_capture_mouse()

func _create_world() -> void:

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("07100e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("607b66")
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.75
	env.fog_enabled = true
	env.fog_light_color = Color("30453c")
	env.fog_density = 0.012
	environment.environment = env
	add_child(environment)

	# The wide central corridor and its two patient rooms.
	_floor(Vector3(0, -0.1, -2), Vector3(8, 0.2, 27), Color("26302a"))
	_wall(Vector3(-4, 1.8, -2), Vector3(0.22, 3.8, 27))
	_wall(Vector3(4, 1.8, -2), Vector3(0.22, 3.8, 27))
	_wall(Vector3(0, 3.75, -2), Vector3(8, 0.18, 27), Color("343c32"))
	_wall(Vector3(0, 1.8, 11.5), Vector3(8, 3.8, 0.22))
	_add_room(Vector3(-6.8, 0, -4.5), "QUARTO 07")
	_add_room(Vector3(6.8, 0, -4.5), "QUARTO 08")
	_add_infirmary(Vector3(0, 0, 8.5))

	for z in [-10.0, -4.0, 2.0, 8.0]:
		var light := OmniLight3D.new()
		light.position = Vector3(0, 3.35, z)
		light.light_color = Color("dbe6a1")
		light.light_energy = 1.5
		light.omni_range = 8.5
		light.shadow_enabled = true
		add_child(light)
		corridor_lights.append(light)

	for z in [-8.0, -2.0, 4.0]:
		_sign(Vector3(-3.82, 2.45, z), "ALA B", false)
		_sign(Vector3(3.82, 2.45, z), "NÃO CONFIE", true)

	var red_light := OmniLight3D.new()
	red_light.position = Vector3(0, 2.5, 10.5)
	red_light.light_color = Color("a91b1b")
	red_light.light_energy = 2.0
	red_light.omni_range = 5.0
	add_child(red_light)

func _create_player() -> void:

	player = CharacterBody3D.new()
	player.position = Vector3(0, 0.9, -9)
	add_child(player)
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.75
	collider.shape = shape
	player.add_child(collider)
	head = Node3D.new()
	head.position.y = 0.55
	player.add_child(head)
	var camera := Camera3D.new()
	camera.current = true
	camera.fov = 72.0
	head.add_child(camera)
	flashlight = SpotLight3D.new()
	flashlight.position = Vector3(0.18, -0.1, 0)
	flashlight.light_color = Color("d9e7bd")
	flashlight.light_energy = 3.2
	flashlight.spot_range = 15.0
	flashlight.spot_angle = 27.0
	flashlight.shadow_enabled = true
	camera.add_child(flashlight)

func _create_interface() -> void:

	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	var title := Label.new()
	title.text = "ASILO DA PARANOIA"
	title.position = Vector2(35, 27)
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color("e6e4c1"))
	root.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "ALA B  •  03:14  •  NINGUÉM ESTÁ SEGURO"
	subtitle.position = Vector2(37, 60)
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color("91a78b"))
	root.add_child(subtitle)

	var sanity_caption := Label.new()
	sanity_caption.text = "SANIDADE"
	sanity_caption.position = Vector2(35, 645)
	sanity_caption.add_theme_font_size_override("font_size", 14)
	root.add_child(sanity_caption)
	sanity_bar = ProgressBar.new()
	sanity_bar.position = Vector2(35, 670)
	sanity_bar.size = Vector2(235, 15)
	sanity_bar.max_value = MAX_SANITY
	sanity_bar.show_percentage = false
	root.add_child(sanity_bar)
	sanity_label = Label.new()
	sanity_label.position = Vector2(280, 666)
	sanity_label.add_theme_font_size_override("font_size", 15)
	root.add_child(sanity_label)
	status_label = Label.new()
	status_label.position = Vector2(35, 700)
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color("bac6ad"))
	root.add_child(status_label)

	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.position = Vector2(250, 600)
	prompt_label.size = Vector2(780, 30)
	prompt_label.add_theme_font_size_override("font_size", 16)
	prompt_label.add_theme_color_override("font_color", Color("f5ecc4"))
	root.add_child(prompt_label)
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.position = Vector2(634, 348)
	crosshair.add_theme_font_size_override("font_size", 22)
	root.add_child(crosshair)

	distortion = ColorRect.new()
	distortion.color = Color(0.45, 0.03, 0.03, 0.0)
	distortion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	distortion.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(distortion)
	_create_meeting_panel(root)

func _create_meeting_panel(root: Control) -> void:

	meeting_panel = PanelContainer.new()
	meeting_panel.position = Vector2(350, 150)
	meeting_panel.size = Vector2(580, 410)
	meeting_panel.visible = false
	root.add_child(meeting_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 13)
	meeting_panel.add_child(box)
	var heading := Label.new()
	heading.text = "REUNIÃO DE EMERGÊNCIA"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	box.add_child(heading)
	countdown_label = Label.new()
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.add_theme_font_size_override("font_size", 17)
	box.add_child(countdown_label)
	var rule := Label.new()
	rule.text = "Apenas observação. Nenhuma prova é confiável.\nQuem deve ser isolado?"
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule.add_theme_font_size_override("font_size", 16)
	box.add_child(rule)
	for suspect in ["MARA  •  estava no porão", "OTÁVIO  •  recusou o remédio", "NINGUÉM  •  ainda não sei"]:
		var button := Button.new()
		button.text = suspect
		button.custom_minimum_size = Vector2(0, 43)
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_cast_vote.bind(suspect))
		box.add_child(button)
	vote_label = Label.new()
	vote_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vote_label.add_theme_color_override("font_color", Color("e8d57a"))
	box.add_child(vote_label)

func _process(delta: float) -> void:

	game_time += delta
	medicine_cooldown = maxf(0.0, medicine_cooldown - delta)
	_update_lights()
	if isolation_remaining > 0.0:
		isolation_remaining -= delta
		prompt_label.text = "ISOLAMENTO • respire. Você está seguro... por enquanto."
		if isolation_remaining <= 0.0:
			prompt_label.text = "Você voltou. Eles ainda estão observando."
		return
	if meeting_remaining > 0.0:
		meeting_remaining -= delta
		countdown_label.text = "Discussão aberta: %02d segundos" % ceili(meeting_remaining)
		if meeting_remaining <= 0.0:
			meeting_panel.visible = false
			prompt_label.text = "A reunião acabou. Ninguém sabe se a decisão foi certa."
		return
	_update_sanity(delta)
	_update_interaction()
	if game_time >= 240.0:
		_start_meeting()
		game_time = 0.0

func _physics_process(_delta: float) -> void:

	if meeting_remaining > 0.0 or isolation_remaining > 0.0:
		return
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (player.global_transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()
	player.velocity.x = direction.x * WALK_SPEED
	player.velocity.z = direction.z * WALK_SPEED
	player.velocity.y = -0.1
	player.move_and_slide()

func _input(event: InputEvent) -> void:

	if event is InputEventMouseButton and event.pressed and not mouse_captured:
		_capture_mouse()
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		mouse_captured = false
	if event is InputEventMouseMotion and mouse_captured and meeting_remaining <= 0.0:
		player.rotate_y(-event.relative.x * LOOK_SENSITIVITY)
		head.rotate_x(-event.relative.y * LOOK_SENSITIVITY)
		head.rotation.x = clampf(head.rotation.x, -1.35, 1.35)
	if event.is_action_pressed("flashlight"):
		flashlight_on = not flashlight_on
		flashlight.visible = flashlight_on and flashlight_energy > 0.0
	if event.is_action_pressed("interact"):
		_take_medicine()
	if event.is_action_pressed("meeting"):
		_start_meeting()

func _update_sanity(delta: float) -> void:

	var darkness_multiplier := 1.5 if not flashlight.visible else 1.0
	var isolation_multiplier := 1.35 if player.position.z > 5.0 else 1.0
	sanity = maxf(0.0, sanity - delta * (0.83 / 60.0) * darkness_multiplier * isolation_multiplier * 10.0)
	if flashlight_on and flashlight_energy > 0.0:
		flashlight_energy = maxf(0.0, flashlight_energy - delta * 1.3)
		flashlight.visible = flashlight_energy > 0.0
	else:
		flashlight_energy = minf(100.0, flashlight_energy + delta * 3.0)
	var paranoia := 1.0 - sanity / MAX_SANITY
	distortion.color.a = paranoia * 0.28 * (0.65 + sin(Time.get_ticks_msec() * 0.006) * 0.35)
	if sanity < 30.0:
		head.rotation.z = sin(Time.get_ticks_msec() * 0.012) * 0.008
	else:
		head.rotation.z = 0.0
	sanity_bar.value = sanity
	sanity_label.text = "%d%%" % roundi(sanity)
	var state := "ESTÁVEL" if sanity > 70 else "INQUIETO" if sanity > 45 else "PARANOIA ATIVA"
	status_label.text = "%s  •  Lanterna %d%%  •  [F]" % [state, roundi(flashlight_energy)]

func _update_interaction() -> void:

	var distance := player.global_position.distance_to(medicine.global_position) if medicine else 999.0
	if distance < MEDICINE_RANGE:
		prompt_label.text = "[E] TOMAR NEUROSTATINA-X  •  " + ("disponível" if medicine_cooldown <= 0.0 else "dispensador vazio")
	elif sanity < 30.0:
		prompt_label.text = "Você ouviu isso? Parecia a voz de Mara... atrás da parede."
	else:
		prompt_label.text = "[R] chamar reunião  •  Não há verdade absoluta."

func _take_medicine() -> void:

	if medicine and player.global_position.distance_to(medicine.global_position) < MEDICINE_RANGE and medicine_cooldown <= 0.0:
		sanity = minf(MAX_SANITY, sanity + 25.0)
		medicine_cooldown = 10.0
		prompt_label.text = "Neurostatina-X administrada. Por que você se sente pior?"

func _start_meeting() -> void:

	if meeting_remaining > 0.0 or isolation_remaining > 0.0:
		return
	meeting_remaining = 60.0
	meeting_panel.visible = true
	vote_label.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_captured = false

func _cast_vote(suspect: String) -> void:

	vote_label.text = "Voto registrado: " + suspect + ". A decisão é irreversível."
	meeting_remaining = 0.0
	meeting_panel.visible = false
	if not suspect.begins_with("NINGUÉM"):
		isolation_remaining = 12.0
		sanity = maxf(0.0, sanity - 15.0)
	_capture_mouse()

func _capture_mouse() -> void:

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_captured = true

func _floor(position: Vector3, size: Vector3, color: Color) -> void:

	_box(position, size, color)

func _wall(position: Vector3, size: Vector3, color := Color("425047")) -> void:

	_box(position, size, color)

func _box(position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:

	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	instance.material_override = material
	instance.position = position
	add_child(instance)
	var body := StaticBody3D.new()
	body.position = position
	var collision := CollisionShape3D.new()
	var collision_shape := BoxShape3D.new()
	collision_shape.size = size
	collision.shape = collision_shape
	body.add_child(collision)
	add_child(body)
	return instance

func _add_room(origin: Vector3, label_text: String) -> void:

	_floor(origin + Vector3(0, -0.1, 0), Vector3(5.4, 0.2, 5.5), Color("30362f"))
	_wall(origin + Vector3(-2.7, 1.8, 0), Vector3(0.18, 3.8, 5.5))
	_wall(origin + Vector3(2.7, 1.8, 0), Vector3(0.18, 3.8, 5.5))
	_wall(origin + Vector3(0, 1.8, -2.7), Vector3(5.4, 3.8, 0.18))
	_wall(origin + Vector3(0, 3.75, 0), Vector3(5.4, 0.18, 5.5), Color("343c32"))
	_box(origin + Vector3(0.8, 0.45, -0.8), Vector3(1.2, 0.8, 2.1), Color("667061"))
	_box(origin + Vector3(0.8, 1.0, -0.8), Vector3(1.4, 0.12, 2.3), Color("d0c9ae"))
	_sign(origin + Vector3(0, 2.3, 2.62), label_text, false)

func _add_infirmary(origin: Vector3) -> void:

	_wall(origin + Vector3(-3.8, 1.8, 0), Vector3(0.18, 3.8, 5.8), Color("59665a"))
	_wall(origin + Vector3(3.8, 1.8, 0), Vector3(0.18, 3.8, 5.8), Color("59665a"))
	_wall(origin + Vector3(0, 1.8, 2.8), Vector3(7.6, 3.8, 0.18), Color("59665a"))
	_box(origin + Vector3(-2.4, 0.7, 0.8), Vector3(1.2, 1.4, 2.2), Color("80917e"))
	medicine = _box(origin + Vector3(0, 1.0, 1.8), Vector3(0.75, 1.8, 0.35), Color("d4e6b6"))
	medicine.name = "DispensadorDeRemedio"
	var light := OmniLight3D.new()
	light.position = origin + Vector3(0, 2.7, 1.0)
	light.light_color = Color("e8d57a")
	light.light_energy = 2.2
	light.omni_range = 6.0
	add_child(light)
	_sign(origin + Vector3(0, 2.3, 2.65), "ENFERMARIA • MEDICAÇÃO", false)

func _sign(position: Vector3, text_value: String, red: bool) -> void:

	var label := Label3D.new()
	label.text = text_value
	label.position = position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.008
	label.font_size = 38
	label.modulate = Color("b82121") if red else Color("d3d9a3")
	label.outline_size = 3
	add_child(label)

func _update_lights() -> void:

	for index in corridor_lights.size():
		corridor_lights[index].light_energy = 1.35 + sin(game_time * 4.3 + index * 1.7) * 0.28
