extends Node3D

# Сборка мира, декораций, интерфейса и игровой экономики.
const TerrainScript = preload("res://scripts/terrain.gd")
const PlayerScript = preload("res://scripts/player.gd")
const WormScript = preload("res://scripts/worm.gd")
const ChestScript = preload("res://scripts/chest.gd")

var terrain: MineTerrain
var player: CharacterBody3D
var message_label: Label
var hud_label: Label
var hint_label: Label
var notification_time := 0.0
var coins := 0
var copper := 0
var crystals := 0
var health := 100

func _ready() -> void:
    create_environment()
    terrain = TerrainScript.new()
    add_child(terrain)
    terrain.block_excavated.connect(on_block_excavated)
    player = PlayerScript.new()
    player.position = Vector3(0,3,0)
    add_child(player)
    player.initialize(self,terrain)
    create_surface()
    create_caves()
    create_hud()
    notify("Добро пожаловать! Копай вниз, ищи пещеры и сундуки.")

func _process(delta: float) -> void:
    notification_time -= delta
    if notification_time <= 0 and message_label.text != "":
        message_label.text = ""
    hud_label.text = "РУДОКОП 3D  |  Здоровье %d  |  Монеты %d  |  Медь %d  |  Кристаллы %d  |  Глубина %d м" % [health,coins,copper,crystals,maxi(0,roundi(-player.global_position.y))]
    hint_label.text = "ЛКМ: копать/атаковать     E: сундук     WASD: движение     Пробел: прыжок     Shift: бег     Esc: курсор"

func create_environment() -> void:
    var world := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("9bbdc8")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("91a2bd")
    environment.ambient_light_energy = 0.42
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world.environment = environment
    add_child(world)
    var sunlight := DirectionalLight3D.new()
    sunlight.rotation_degrees = Vector3(-48,-32,-14)
    sunlight.light_energy = 1.25
    sunlight.shadow_enabled = true
    add_child(sunlight)

func create_surface() -> void:
    for x in range(-14,15,4):
        for z in range(-14,15,4):
            if abs(x) < 4 and abs(z) < 4:
                continue
            var pebble := MeshInstance3D.new()
            var mesh := SphereMesh.new()
            mesh.radius = 0.2+float(abs(x*z+x)%4)*0.08
            mesh.height = 0.25
            pebble.mesh = mesh
            pebble.material_override = make_material(Color("c4baa0"))
            pebble.position = Vector3(x+0.7,0.56,z+0.3)
            add_child(pebble)
    add_box(self,Vector3(3,2.2,2),Vector3(0.22,3.5,0.22),Color("53443b"))
    add_glow(Vector3(3,4,2),Color("ffd49a"),2.1,10)

func create_caves() -> void:
    var cave_origins := [Vector3(-5,-9,-4),Vector3(5,-16,4),Vector3(-4,-24,7)]
    for cave_index in range(cave_origins.size()):
        var origin: Vector3 = cave_origins[cave_index]
        add_glow(origin+Vector3(0,1,0),Color("64d4ce") if cave_index == 2 else Color("f1a54a"),1.5,9)
        for index in range(7):
            var angle := index*TAU/7.0
            var crystal := MeshInstance3D.new()
            var prism := CylinderMesh.new()
            prism.top_radius = 0.0
            prism.bottom_radius = 0.28
            prism.height = 1.2
            prism.radial_segments = 5
            crystal.mesh = prism
            crystal.position = origin+Vector3(cos(angle)*3.0,-3.1,sin(angle)*3.0)
            crystal.rotation_degrees = Vector3(12,index*30,15)
            crystal.material_override = make_material(Color("64ddda") if cave_index == 2 else Color("b88ae7"),true)
            add_child(crystal)
        var chest := ChestScript.new()
        chest.position = origin+Vector3(1.1,-3.3,0)
        add_child(chest)
        chest.initialize(self,30+cave_index*35)
        var worm := WormScript.new()
        worm.position = origin+Vector3(-1,-2.3,-1)
        add_child(worm)
        worm.initialize(player,self)

func add_glow(location: Vector3, color: Color, energy: float, light_range: float) -> void:
    var orb := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.22
    sphere.height = 0.44
    orb.mesh = sphere
    orb.material_override = make_material(color,true)
    orb.position = location
    add_child(orb)
    var light := OmniLight3D.new()
    light.position = location
    light.light_color = color
    light.light_energy = energy
    light.omni_range = light_range
    add_child(light)

func make_material(color: Color, glowing: bool = false) -> StandardMaterial3D:
    var result := StandardMaterial3D.new()
    result.albedo_color = color
    result.roughness = 0.85
    if glowing:
        result.emission_enabled = true
        result.emission = color
        result.emission_energy_multiplier = 2.0
    return result

func add_box(parent: Node3D, location: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
    var visual := MeshInstance3D.new()
    var box_mesh := BoxMesh.new()
    box_mesh.size = dimensions
    visual.mesh = box_mesh
    visual.position = location
    visual.material_override = make_material(color)
    parent.add_child(visual)
    return visual

func create_hud() -> void:
    var canvas := CanvasLayer.new()
    add_child(canvas)
    var strip := ColorRect.new()
    strip.color = Color(0.06,0.09,0.13,0.78)
    strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    strip.custom_minimum_size = Vector2(0,52)
    canvas.add_child(strip)
    hud_label = Label.new()
    hud_label.position = Vector2(18,14)
    hud_label.add_theme_font_size_override("font_size",19)
    hud_label.add_theme_color_override("font_color",Color("f8e5b5"))
    canvas.add_child(hud_label)
    var crosshair := Label.new()
    crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    crosshair.text = "+"
    crosshair.add_theme_font_size_override("font_size",28)
    crosshair.position -= Vector2(8,20)
    canvas.add_child(crosshair)
    hint_label = Label.new()
    hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    hint_label.position = Vector2(18,-38)
    hint_label.add_theme_font_size_override("font_size",16)
    canvas.add_child(hint_label)
    message_label = Label.new()
    message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    message_label.position = Vector2(-350,72)
    message_label.custom_minimum_size.x = 700
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message_label.add_theme_font_size_override("font_size",22)
    message_label.add_theme_color_override("font_color",Color("ffe3a0"))
    canvas.add_child(message_label)

func on_block_excavated(block_type: int) -> void:
    match block_type:
        MineTerrain.COPPER:
            copper += 1
            notify("+1 медная руда")
        MineTerrain.GOLD:
            coins += 5
            notify("Золотая жила! +5 монет")
        MineTerrain.CRYSTAL:
            crystals += 1
            notify("Найден редкий кристалл!")

func open_chest(reward: int) -> void:
    coins += reward
    notify("Сундук открыт! +%d монет" % reward)

func damage_player(amount: int) -> void:
    health = maxi(0,health-amount)
    notify("Червь укусил! -%d здоровья" % amount)
    if health == 0:
        health = 100
        player.global_position = Vector3(0,4,0)
        player.velocity = Vector3.ZERO
        notify("Вы вернулись на поверхность.")

func notify(message: String) -> void:
    if message_label != null:
        message_label.text = message
    notification_time = 3.5
