extends CharacterBody3D

# Управление от первого лица и удар киркой. Руки, ноги и инструмент — 3D-модели.
const WALK_SPEED := 5.0
const RUN_SPEED := 8.0
const JUMP_SPEED := 5.4
const GRAVITY := 18.0
const REACH := 4.6
const ATTACK_INTERVAL := 0.28

var game: Node3D
var terrain: MineTerrain
var camera: Camera3D
var view_model: Node3D
var attack_timer := 0.0
var swing_time := 0.0
var walking_time := 0.0

func _ready() -> void:
    collision_layer = 2
    collision_mask = 1
    var capsule := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.32
    shape.height = 1.75
    capsule.shape = shape
    capsule.position.y = 0.87
    add_child(capsule)
    camera = Camera3D.new()
    camera.current = true
    camera.position.y = 1.58
    add_child(camera)
    var lamp := SpotLight3D.new()
    lamp.light_color = Color("fff0d3")
    lamp.light_energy = 3.1
    lamp.spot_range = 15.0
    lamp.spot_angle = 53.0
    camera.add_child(lamp)
    create_body_parts()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func initialize(game_node: Node3D, mine_terrain: MineTerrain) -> void:
    game = game_node
    terrain = mine_terrain

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x*0.0025)
        camera.rotate_x(-event.relative.y*0.0025)
        camera.rotation.x = clampf(camera.rotation.x,-1.5,1.5)
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_ESCAPE:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
        elif event.keycode == KEY_E:
            interact()
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
        else:
            use_pickaxe()

func _physics_process(delta: float) -> void:
    attack_timer = maxf(0.0,attack_timer-delta)
    swing_time = maxf(0.0,swing_time-delta)
    if not is_on_floor():
        velocity.y -= GRAVITY*delta
    elif Input.is_key_pressed(KEY_SPACE):
        velocity.y = JUMP_SPEED
    var horizontal_input := Vector2.ZERO
    if Input.is_key_pressed(KEY_W):
        horizontal_input.y -= 1
    if Input.is_key_pressed(KEY_S):
        horizontal_input.y += 1
    if Input.is_key_pressed(KEY_A):
        horizontal_input.x -= 1
    if Input.is_key_pressed(KEY_D):
        horizontal_input.x += 1
    horizontal_input = horizontal_input.normalized()
    var direction := (global_transform.basis*Vector3(horizontal_input.x,0,horizontal_input.y)).normalized()
    var speed := RUN_SPEED if Input.is_key_pressed(KEY_SHIFT) else WALK_SPEED
    velocity.x = direction.x*speed
    velocity.z = direction.z*speed
    move_and_slide()
    walking_time += delta*horizontal_input.length()*speed
    var bob := sin(walking_time*8.0)*0.015 if horizontal_input.length()>0 else 0.0
    view_model.position.y = bob-(sin((0.35-swing_time)*13.0)*0.08 if swing_time>0 else 0.0)
    view_model.rotation.z = -sin((0.35-swing_time)*13.0)*0.5 if swing_time>0 else 0.0
    if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        use_pickaxe()

func raycast_target() -> Dictionary:
    var origin := camera.global_position
    var destination := origin-camera.global_transform.basis.z*REACH
    var query := PhysicsRayQueryParameters3D.create(origin,destination)
    query.exclude = [get_rid()]
    return get_world_3d().direct_space_state.intersect_ray(query)

func use_pickaxe() -> void:
    if attack_timer>0:
        return
    attack_timer = ATTACK_INTERVAL
    swing_time = 0.35
    var target := raycast_target()
    if target.is_empty():
        return
    var collider: Object = target.collider
    if collider is StaticBody3D and collider.has_meta("chest"):
        game.notify("Нажми E, чтобы открыть сундук")
    elif collider.has_method("receive_damage"):
        collider.receive_damage(1)
    elif collider is StaticBody3D and collider.get_parent() == terrain:
        var block_position := Vector3i((target.position-target.normal*0.06).round())
        terrain.excavate(block_position)

func interact() -> void:
    var target := raycast_target()
    if target.is_empty():
        return
    var collider: Object = target.collider
    if collider is StaticBody3D and collider.has_meta("chest"):
        collider.get_meta("chest").open()

func create_body_parts() -> void:
    view_model = Node3D.new()
    camera.add_child(view_model)
    # Перед камерой видны рукава, кисти и кирка.
    add_part(view_model,Vector3(0.48,-0.58,-0.73),Vector3(0.28,0.32,0.65),Color("526c83"),Vector3(-35,0,-20))
    add_part(view_model,Vector3(0.42,-0.65,-1.05),Vector3(0.22,0.23,0.29),Color("dca47c"))
    add_part(view_model,Vector3(-0.56,-0.61,-0.78),Vector3(0.28,0.32,0.62),Color("526c83"),Vector3(-30,0,17))
    add_part(view_model,Vector3(-0.52,-0.69,-1.02),Vector3(0.21,0.22,0.26),Color("dca47c"))
    add_part(view_model,Vector3(0.45,-0.32,-1.22),Vector3(0.075,1.42,0.075),Color("a47644"),Vector3(32,0,-25),true)
    add_part(view_model,Vector3(0.58,0.28,-1.38),Vector3(0.93,0.21,0.22),Color("a6bbc5"),Vector3(0,0,-26))
    add_part(view_model,Vector3(0.12,0.37,-1.39),Vector3(0.28,0.12,0.18),Color("d9e3e7"),Vector3(0,0,-26))
    # Ноги закреплены ниже уровня глаз и появляются при взгляде вниз.
    var legs := Node3D.new()
    legs.position = Vector3(0,-1.6,0)
    camera.add_child(legs)
    add_part(legs,Vector3(-0.19,0.35,0.12),Vector3(0.3,0.9,0.34),Color("475e6d"))
    add_part(legs,Vector3(0.19,0.35,0.12),Vector3(0.3,0.9,0.34),Color("475e6d"))
    add_part(legs,Vector3(-0.19,-0.15,-0.08),Vector3(0.32,0.24,0.55),Color("3b3032"))
    add_part(legs,Vector3(0.19,-0.15,-0.08),Vector3(0.32,0.24,0.55),Color("3b3032"))

func add_part(parent: Node3D, location: Vector3, dimensions: Vector3, color: Color, angles: Vector3 = Vector3.ZERO, cylinder: bool = false) -> void:
    var part := MeshInstance3D.new()
    part.mesh = CylinderMesh.new() if cylinder else BoxMesh.new()
    part.position = location
    part.scale = dimensions
    part.rotation_degrees = angles
    var surface := StandardMaterial3D.new()
    surface.albedo_color = color
    surface.roughness = 0.83
    surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    part.material_override = surface
    parent.add_child(part)
