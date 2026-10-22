extends CharacterBody3D

# Враг чувствует персонажа поблизости, ползёт к нему и кусает.
var target: CharacterBody3D
var game
var hit_points := 3
var cooldown := 0.0
var animation_time := 0.0
var segments: Array[MeshInstance3D] = []

func _ready() -> void:
    collision_layer = 4
    collision_mask = 1
    var collision := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.42
    shape.height = 1.2
    collision.shape = shape
    collision.position.y = 0.55
    add_child(collision)
    for index in range(5):
        var segment := MeshInstance3D.new()
        var sphere := SphereMesh.new()
        sphere.radius = 0.43-float(index)*0.04
        sphere.height = sphere.radius*2.0
        segment.mesh = sphere
        segment.position = Vector3(0,0.58,index*0.43)
        var material := StandardMaterial3D.new()
        material.albedo_color = Color("b45463") if index%2==0 else Color("8e3b54")
        segment.material_override = material
        add_child(segment)
        segments.append(segment)
    var eye := MeshInstance3D.new()
    var eye_mesh := SphereMesh.new()
    eye_mesh.radius = 0.12
    eye.mesh = eye_mesh
    eye.position = Vector3(0,0.72,-0.37)
    var eye_surface := StandardMaterial3D.new()
    eye_surface.albedo_color = Color("ffe391")
    eye_surface.emission_enabled = true
    eye_surface.emission = Color("ffe391")
    eye.material_override = eye_surface
    add_child(eye)

func initialize(player: CharacterBody3D, game_node: Node3D) -> void:
    target = player
    game = game_node

func _physics_process(delta: float) -> void:
    if target == null:
        return
    cooldown = maxf(0.0,cooldown-delta)
    animation_time += delta
    var difference := target.global_position-global_position
    var horizontal := Vector3(difference.x,0,difference.z)
    if horizontal.length()<8 and absf(difference.y)<3:
        var direction := horizontal.normalized()
        velocity.x = direction.x*2.15
        velocity.z = direction.z*2.15
        if horizontal.length()>0.15:
            look_at(global_position-direction,Vector3.UP)
        if horizontal.length()<1.2 and cooldown<=0:
            cooldown = 1.5
            game.damage_player(12)
    else:
        velocity.x = move_toward(velocity.x,0,delta*5)
        velocity.z = move_toward(velocity.z,0,delta*5)
    if not is_on_floor():
        velocity.y -= 17.0*delta
    move_and_slide()
    for index in range(segments.size()):
        segments[index].position.y = 0.58+sin(animation_time*7-index*0.8)*0.1

func receive_damage(amount: int) -> void:
    hit_points -= amount
    if hit_points<=0:
        game.coins += 3
        game.notify("Червь побеждён! +3 монеты")
        queue_free()
    else:
        game.notify("Попадание по червю!")
