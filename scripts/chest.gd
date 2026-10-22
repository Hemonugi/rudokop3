extends Node3D

# Награда за сундук выдаётся только при первом открытии.
var game
var reward := 0
var opened := false
var lid: MeshInstance3D

func _ready() -> void:
    var body := StaticBody3D.new()
    body.set_meta("chest",self)
    add_child(body)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(1.25,0.9,0.85)
    collision.shape = shape
    body.add_child(collision)
    make_box(body,Vector3(0,-0.16,0),Vector3(1.25,0.62,0.85),Color("754b2f"))
    lid = make_box(body,Vector3(0,0.27,0),Vector3(1.32,0.25,0.9),Color("a3753a"))
    make_box(body,Vector3(0,-0.1,0.45),Vector3(0.2,0.33,0.07),Color("ecd188"))
    make_box(body,Vector3(-0.54,-0.15,0),Vector3(0.1,0.65,0.92),Color("ddae5e"))
    make_box(body,Vector3(0.54,-0.15,0),Vector3(0.1,0.65,0.92),Color("ddae5e"))

func initialize(game_node: Node3D, reward_coins: int) -> void:
    game = game_node
    reward = reward_coins

func open() -> void:
    if opened:
        game.notify("Этот сундук уже пуст.")
        return
    opened = true
    lid.position.y += 0.55
    lid.rotation_degrees.x = -35
    game.open_chest(reward)

func make_box(parent: Node3D, location: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = dimensions
    part.mesh = mesh
    part.position = location
    var surface := StandardMaterial3D.new()
    surface.albedo_color = color
    part.material_override = surface
    parent.add_child(part)
    return part
