extends Node2D

const N: int = 1; # bit 1
const E: int = 2; # bit 2
const S: int = 4; # bit 3
const W: int = 8; # bit 4

#var rng: RandomNumberGenerator = RandomNumberGenerator.new();

var cell_walls: Dictionary = {
	Vector2(0, -1): N,
	Vector2(1, 0): E,
	Vector2(0, 1): S,
	Vector2(-1, 0): W
};

var tile_size: Vector2 = Vector2(64, 64); # tile size (in pixels)
var width: int = 20; # width of map (in tiles)
var height: int = 11; # height of map (in tiles)

# get a reference of the tile map for convenience

onready var Map: TileMap = $TileMap;

func check_neighbors(cell: Vector2, unvisited: Array) -> Array:
	# Returns an array of cell's unvisited neighbors
	var list: Array = [];
	for n in cell_walls.keys():
		if cell + n in unvisited:
			list.append(cell+n);
	return list;

func make_maze() -> void:
	var unvisited: Array = []; # array of unvisited tiles
	var stack: Array = [];
	#fill the map with solid tiles
	Map.clear();
	for x in range(width):
		for y in range(height):
			unvisited.append(Vector2(x, y));
			Map.set_cellv(Vector2(x, y), N|E|S|W); #0001|0010|0100|1000 = 1111
	
	var current: Vector2 = Vector2(0, 0);
	unvisited.erase(current);
	
	#Execute recursive backtracker algorithm
	
	while !unvisited.empty():
		var neighbors: Array = check_neighbors(current, unvisited);
		if neighbors.size() > 0:
			var next: Vector2 = neighbors[randi() % neighbors.size()];
			stack.append(current);
			# Remove walls from *both* cells
			var dir: Vector2 = next - current;
			var current_walls = Map.get_cellv(current) - cell_walls[dir];
			var next_walls = Map.get_cellv(next) - cell_walls[-dir];
			Map.set_cellv(current, current_walls);
			Map.set_cellv(next, next_walls);
			current = next;
			unvisited.erase(current);
			yield(get_tree(), 'idle_frame'); # Remove this!
		elif stack:
			current = stack.pop_back();

func _ready():
	generate_maze();

func generate_maze():
	#rng.randomize();
	randomize();
	tile_size = Map.cell_size;
	make_maze();

func _input(event):
	var is_just_pressed = event.is_pressed() && !event.is_echo();
	if Input.is_key_pressed(KEY_SPACE) && is_just_pressed:
		generate_maze();
