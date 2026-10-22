extends Node3D
class_name MineTerrain

# Мир состоит из блоков. При копании обновляются только затронутые чанки.
signal block_excavated(block_type: int)

const HALF_SIZE := 15
const DEPTH := 31
const CHUNK_SIZE := 8
const EMPTY := 0
const SOIL := 1
const STONE := 2
const COPPER := 3
const GOLD := 4
const CRYSTAL := 5
const DIRECTIONS := [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD]
const QUADS := [
    [Vector3(0.5,-0.5,-0.5),Vector3(0.5,-0.5,0.5),Vector3(0.5,0.5,0.5),Vector3(0.5,0.5,-0.5)],
    [Vector3(-0.5,-0.5,0.5),Vector3(-0.5,-0.5,-0.5),Vector3(-0.5,0.5,-0.5),Vector3(-0.5,0.5,0.5)],
    [Vector3(-0.5,0.5,-0.5),Vector3(0.5,0.5,-0.5),Vector3(0.5,0.5,0.5),Vector3(-0.5,0.5,0.5)],
    [Vector3(-0.5,-0.5,0.5),Vector3(0.5,-0.5,0.5),Vector3(0.5,-0.5,-0.5),Vector3(-0.5,-0.5,-0.5)],
    [Vector3(0.5,-0.5,0.5),Vector3(-0.5,-0.5,0.5),Vector3(-0.5,0.5,0.5),Vector3(0.5,0.5,0.5)],
    [Vector3(-0.5,-0.5,-0.5),Vector3(0.5,-0.5,-0.5),Vector3(0.5,0.5,-0.5),Vector3(-0.5,0.5,-0.5)]
]
const CAVES := [Vector4(-5,-9,-4,5), Vector4(5,-16,4,5), Vector4(-4,-24,7,5)]

var blocks: Dictionary = {}
var chunks: Dictionary = {}
var noise := FastNoiseLite.new()
var terrain_material := StandardMaterial3D.new()

func _ready() -> void:
    noise.seed = 32591
    noise.frequency = 0.18
    terrain_material.vertex_color_use_as_albedo = true
    terrain_material.roughness = 0.95
    for x in range(-HALF_SIZE, HALF_SIZE + 1):
        for z in range(-HALF_SIZE, HALF_SIZE + 1):
            for depth in range(DEPTH):
                var position := Vector3i(x,-depth,z)
                if is_cave(position):
                    continue
                var ore_seed: int = absi(x * 92821 + z * 68917 + depth * 17389 + x * z * 2137) % 113
                var block_type := STONE
                if depth < 4:
                    block_type = SOIL
                elif depth >= 22 and ore_seed > 109:
                    block_type = CRYSTAL
                elif depth >= 16 and ore_seed < 3:
                    block_type = GOLD
                elif depth >= 9 and ore_seed < 9:
                    block_type = COPPER
                blocks[position] = block_type
    var all_chunks := {}
    for position in blocks:
        all_chunks[chunk_key(position)] = true
    for key in all_chunks:
        rebuild_chunk(key)

func is_cave(position: Vector3i) -> bool:
    var point := Vector3(position)
    for chamber in CAVES:
        if point.distance_to(Vector3(chamber.x,chamber.y,chamber.z)) < chamber.w + noise.get_noise_3d(point.x,point.y,point.z)*1.2:
            return true
    for corridor in range(CAVES.size()-1):
        var origin := Vector3(CAVES[corridor].x,CAVES[corridor].y,CAVES[corridor].z)
        var destination := Vector3(CAVES[corridor+1].x,CAVES[corridor+1].y,CAVES[corridor+1].z)
        var difference := destination-origin
        var progress := clampf((point-origin).dot(difference)/difference.length_squared(),0.0,1.0)
        if point.distance_to(origin+difference*progress) < 2.3+noise.get_noise_3d(point.x,point.y,point.z)*0.6:
            return true
    return false

func chunk_key(position: Vector3i) -> Vector3i:
    return Vector3i(floori(float(position.x)/CHUNK_SIZE),floori(float(position.y)/CHUNK_SIZE),floori(float(position.z)/CHUNK_SIZE))

func block_at(position: Vector3i) -> int:
    return int(blocks.get(position,EMPTY))

func excavate(position: Vector3i) -> bool:
    var block_type := block_at(position)
    if block_type == EMPTY:
        return false
    blocks.erase(position)
    var affected := {chunk_key(position):true}
    for direction in DIRECTIONS:
        affected[chunk_key(position+direction)] = true
    for key in affected:
        rebuild_chunk(key)
    block_excavated.emit(block_type)
    return true

func rebuild_chunk(key: Vector3i) -> void:
    if chunks.has(key):
        chunks[key].queue_free()
        chunks.erase(key)
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var colors := PackedColorArray()
    var indices := PackedInt32Array()
    for x in range(CHUNK_SIZE):
        for y in range(CHUNK_SIZE):
            for z in range(CHUNK_SIZE):
                var position := key*CHUNK_SIZE+Vector3i(x,y,z)
                var block_type := block_at(position)
                if block_type == EMPTY:
                    continue
                for face in range(6):
                    if block_at(position+DIRECTIONS[face]) != EMPTY:
                        continue
                    var start := vertices.size()
                    var base_color := block_color(block_type)
                    var variation := 0.84+float(absi(position.x * 31 + position.y * 47 + position.z * 71) % 17)/100.0
                    if face == 2:
                        variation *= 1.16
                    if face == 3:
                        variation *= 0.72
                    for corner in QUADS[face]:
                        vertices.append(Vector3(position)+corner)
                        normals.append(Vector3(DIRECTIONS[face]))
                        colors.append(Color(base_color.r*variation,base_color.g*variation,base_color.b*variation))
                    # Порядок индексов задаёт внешнюю сторону каждой грани.
                    indices.append_array(PackedInt32Array([start,start+2,start+1,start,start+3,start+2]))
    if vertices.is_empty():
        return
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    mesh.surface_set_material(0,terrain_material)
    var body := StaticBody3D.new()
    body.collision_layer = 1
    var visual := MeshInstance3D.new()
    visual.mesh = mesh
    body.add_child(visual)
    var collision := CollisionShape3D.new()
    collision.shape = mesh.create_trimesh_shape()
    body.add_child(collision)
    add_child(body)
    chunks[key] = body

func block_color(block_type: int) -> Color:
    match block_type:
        SOIL:
            return Color("8c6042")
        COPPER:
            return Color("bc7247")
        GOLD:
            return Color("d8a94a")
        CRYSTAL:
            return Color("6ccbc6")
        _:
            return Color("686b75")
