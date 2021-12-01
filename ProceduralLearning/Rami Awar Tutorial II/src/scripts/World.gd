extends Node

onready var dirt_tilemap = $DirtTileMap;
onready var wall_tiemap = $WallTileMap;

var rng: RandomNumberGenerator = RandomNumberGenerator.new();

var CellSize: Vector2 = Vector2(16, 16);
var width: int = 512/CellSize.x; #Tile pos instead of pixels
var height: int = 288/CellSize.y; #Tile pos instead of pixels
var grid: Array = [];
var walkers: Array = [];
var max_walkers: int = 5;

class Walker:
	var dir: Vector2;
	var pos: Vector2;
	
	func _init(n_dir: Vector2, n_pos: Vector2):
		dir = n_dir;
		pos = n_pos;

var Tiles = {
	"Empty": -1,
	"Wall": 0,
	"Floor": 1
};

enum RandomPath {
	NONE,
	PRESERVE_DIR,
	MULTIPLE,
	LIMIT_EXPLORED
}

func _init_walkers(ammount: int):
	walkers = [];
	for i in range(ammount):
		var walker = Walker.new(GetRandomDirection(), Vector2(width/2, height/2));
		walkers.append(walker);

func _init_grid():
	grid = [];
	for x in width:
		grid.append([]);
		for y in height:
			grid[x].append(Tiles.Empty);
	#creates bi-dimensional array, grid, filled with -1 (aka Tiles.Empty)

func GetRandomDirection() -> Vector2:
	var directions: Array = [[-1, 0], [1, 0], [0, 1], [0,-1]];
	var direction: Array = directions[rng.randi()%4]; # A random value between 0 and 3
	return Vector2(direction[0], direction[1]);

func is_dir_in_bounds(dir: Vector2, bound_start: Vector2, bound_end: Vector2) -> bool:
	if (dir.x >= bound_start.x and dir.x < bound_end.x
		and dir.y >= bound_start.y and dir.y < bound_end.y):
		return true;
	else:
		return false;

func _create_random_path_default(max_iterations: int):
	var itr = 0;
	var walker: Vector2 = Vector2(width/2, height/2);
	
	while itr < max_iterations:
		# Perform random walk
		# 1- Choose random direction
		# 2- Check that direction is in bounds
		# 3- move in that direction
		var random_direction = GetRandomDirection();
		if is_dir_in_bounds(walker + random_direction, Vector2.ZERO, Vector2(width, height)):
			walker+= random_direction;
			grid[walker.x][walker.y] = Tiles.Floor;
			itr+=1;

func _create_random_path_preserve(max_iterations: int, max_steps_direction: int):
	var itr = 0;
	var walker: Vector2 = Vector2.ZERO;
	var current_stride: int = 0;
	var current_direction = Vector2.ZERO;
	
	while itr < max_iterations:
		# Perform random walk
		# 1- Choose random direction
		# 2- Check that direction is in bounds
		# 3- move in that direction
		if current_stride == 0:
			var random_direction = GetRandomDirection();
			if is_dir_in_bounds(walker + random_direction, Vector2.ZERO, Vector2(width, height)):
				walker+= random_direction;
				current_direction = random_direction;
				grid[walker.x][walker.y] = Tiles.Floor;
				current_stride+=1;
		else:
			current_stride+=1;
			if current_stride == max_steps_direction:
				current_stride = 0;
			if is_dir_in_bounds(walker + current_direction, Vector2.ZERO, Vector2(width, height)):
				walker+= current_direction;
				grid[walker.x][walker.y] = Tiles.Floor;
		itr+=1;

func _create_random_path_multiple(max_iterations: int):
	var itr: int = 0;
	while itr < max_iterations:
		#Perform random walk
		#1- Choose random direction
		#2- Check that direction is in bounds
		#3- move in that direction
		for i in range(walkers.size()):
			var random_direction: Vector2 = GetRandomDirection();
			if is_dir_in_bounds(walkers[i].pos + random_direction, Vector2.ZERO, Vector2(width, height)):
				walkers[i].dir = random_direction;
				walkers[i].pos += walkers[i].dir;
				grid[walkers[i].pos.x][walkers[i].pos.y] = Tiles.Floor
				itr+=1;
				
func _create_random_path_limit_explored(max_iterations: int):
	var walker_max_count = 3;
	var walker_spawn_chance = 0.25;
	var walker_direction_chance = 0.5;
	var walker_destroy_chance = 0.2;
	var fill_percent = 0.5;
	var itr: int = 0;
	var n_tiles: int = 0;
	while itr < max_iterations:
		#Perform random walk
		#1- Choose random direction
		#2- Check that direction is in bounds
		#3- move in that direction
		
		#Change direction, with chance
		for i in range(walkers.size()):
			if rng.randf() < walker_direction_chance:
				walkers[i].dir = GetRandomDirection();

		#Random: Maybe destroy walker?
		for i in range(walkers.size()):
			if rng.randf() < walker_destroy_chance && walkers.size() > 1:
				walkers.remove(i);
				break; # Destroy only one walker per iteration

		# Spawn new walkers, with chance
		for i in range(walkers.size()):
			if rng.randf() < walker_spawn_chance && walkers.size() < walker_max_count:
				walkers.append(Walker.new(GetRandomDirection(), walkers[i].pos));
		
		#Advance walkers 
		for i in range(walkers.size()):
			if is_dir_in_bounds(walkers[i].pos + walkers[i].dir, Vector2.ZERO, Vector2(width, height)):
				walkers[i].pos += walkers[i].dir;
				if grid[walkers[i].pos.x][walkers[i].pos.y]  == Tiles.Empty:
					grid[walkers[i].pos.x][walkers[i].pos.y] = Tiles.Floor;
					n_tiles += 1;
					if float(n_tiles)/float(width*height) >= fill_percent:
						return;
		itr+=1;

func _create_random_path(path_type: int):
	match path_type:
		RandomPath.NONE:
			_create_random_path_default(1000);
		RandomPath.PRESERVE_DIR:
			_create_random_path_preserve(1000, 4);
		RandomPath.MULTIPLE:
			_init_walkers(max_walkers);
			_create_random_path_multiple(1000);
		RandomPath.LIMIT_EXPLORED:
			_init_walkers(1);
			_create_random_path_limit_explored(1000);

func _spawn_tiles():
	for x in width:
		for y in height:
			match grid[x][y]:
				Tiles.Empty:
					pass;
				Tiles.Floor:
					dirt_tilemap.set_cellv(Vector2(x, y), 0);
				Tiles.Wall:
					pass;
	# The update_bitmask_region it's necessary to make the
	# Autotile work with autogenerated maps
	dirt_tilemap.update_bitmask_region();
	wall_tiemap.update_bitmask_region();

func _clear_tilemaps():
	for x in width:
		for y in height:
			dirt_tilemap.clear();
			wall_tiemap.clear();
	
	dirt_tilemap.update_bitmask_region();
	wall_tiemap.update_bitmask_region();

func _ready():
	_generate_map(RandomPath.NONE);

func _generate_map(path_type: int):
	rng.randomize();
	_init_grid();
	_clear_tilemaps();
	_create_random_path(path_type);
	_spawn_tiles();

func _input(event):
	var just_pressed: bool = event.is_pressed() && !event.is_echo();
	if Input.is_key_pressed(KEY_1) && just_pressed:
		_generate_map(RandomPath.NONE);
	elif Input.is_key_pressed(KEY_2) && just_pressed:
		_generate_map(RandomPath.PRESERVE_DIR);
	elif Input.is_key_pressed(KEY_3) && just_pressed:
		_generate_map(RandomPath.MULTIPLE);
	elif Input.is_key_pressed(KEY_4) && just_pressed:
		_generate_map(RandomPath.LIMIT_EXPLORED);
