class_name PCG #Global tools for procedural generated content
extends Object

# Only static and const stuff

# Cardinal bitflags, really useful.
const N: int = 1;
const NE: int = 2;
const E: int = 4;
const SE: int = 8;
const S: int = 16;
const SW: int = 32;
const W: int = 64;
const NW: int = 128;

const ALL_DIR: int = N | NE | E | SE | S | SW | W | NW; # All 8 directions
const DIAG_DIR: int = NE | SE | SW | NW; # Diagonal directions only
const HOR_AND_VER_DIR: int = ALL_DIR - DIAG_DIR; # Horizontal and vertical directions

const DIRS: Dictionary = { # The keys are vectors 2D, which is awesome and handy
	Vector2(0, -1): N,
	Vector2(1, -1): NE,
	Vector2(1, 0): E,
	Vector2(1, 1): SE,
	Vector2(0, 1): S,
	Vector2(-1, 1): SW,
	Vector2(-1, 0): W,
	Vector2(-1, -1): NW
};

static func get_cell_from_world_pos(pos_world: Vector2, cell_size: Vector2) -> Vector2:
	return Vector2(int(floor(pos_world.x/cell_size.x)), int(floor(pos_world.y/cell_size.y)));

static func get_world_pos_from_cell(cell: Vector2, cell_size: Vector2) -> Vector2:
	return Vector2(cell.x*cell_size.x, cell.y*cell_size.y);

static func get_world_pos_from_cell_centered(cell: Vector2, cell_size: Vector2) -> Vector2:
	return Vector2(0.5*cell_size.x*(2.0*cell.x+1),  0.5*cell_size.y*(2.0*cell.y+1));

static func get_random_direction(rng: RandomNumberGenerator, bit_mask: int) -> Vector2:
	var directions: Array = [];
	for c_dir in DIRS.keys():
		if (DIRS[c_dir] & bit_mask):
			directions.append(c_dir)
	return directions[rng.randi()%directions.size()]; # A random value between 0 and 3

static func substract_cells_from_rec2(cells: Array, rect: Rect2, min_size: int = 0) -> Array:
	var copy_cells: Array = cells.duplicate(true) # To don't modify the parameter directly
	for x in rect.size.x:
		for y in rect.size.y:
			if copy_cells.size() <= min_size:
				break
			var i: int = copy_cells.find(Vector2(x + rect.position.x, y+rect.position.y))
			if i != -1:
				copy_cells.remove(i)
	return copy_cells

static func get_grid_array_size(grid_array: Array) -> Vector2:
	if grid_array.size() == 0:
		return Vector2.ZERO
	return Vector2(grid_array.size(), grid_array[0].size())

static func is_in_grid_array_bounds(grid_array: Array, pos: Vector2, margin_start: Vector2 = Vector2.ZERO, margin_end: Vector2 = Vector2.ZERO) -> bool:
	var start: Vector2 = margin_start
	var end: Vector2 = get_grid_array_size(grid_array) - margin_end
	if (pos.x < start.x or pos.y < start.y or pos.x >= end.x or pos.y >= end.y):
		return false
	return true

#Obtain an vector 2 array with the cells, but not the values of each cell!
static func get_cells_from_grid_array(grid_array: Array) -> Array:
	var grid_size: Vector2 = get_grid_array_size(grid_array)
	var cells: Array = []
	for x in grid_size.x:
		for y in grid_size.y:
			cells.append(Vector2(x, y))
	return cells

#all_cells is not a grid, but an array with all the vectors inside a grid
static func get_neighbors(cell: Vector2, all_cells: Array, bitmask: int = ALL_DIR, mult: int = 1) -> Array:
	var neighbors: Array = []
	for n in DIRS.keys():
		if (bitmask & DIRS[n]) and (cell+n*mult in all_cells):
			neighbors.append(cell+n*mult)
	return neighbors

static func generate_maze_path(grid_array: Array, tile_id: int, erase_fraction: float = 0.0, start_point: Vector2 = Vector2.ZERO, filter_grid: Array = [], rng: RandomNumberGenerator = RandomNumberGenerator.new(), margin_start: Vector2 = Vector2.ZERO) -> Array:
	var copy_array: Array = grid_array.duplicate(true)
	var unvisited: Array = []
	var stack: Array = []
	var bounds: Vector2 = get_grid_array_size(copy_array)
	var x_start: int = 0 if (int(start_point.x) % 2 == 0) else 1
	var y_start: int = 0 if (int(start_point.y) % 2 == 0) else 1
	for x in range(x_start, bounds.x, 2):
		for y in range(y_start, bounds.y, 2):
			if x < margin_start.x or y < margin_start.y or x >= (bounds.x-margin_start.x) or y >= (bounds.y-margin_start.y):
				continue;
			if is_in_grid_array_bounds(filter_grid, Vector2(x, y)) and filter_grid[x][y] != -1:
				continue
			unvisited.append(Vector2(x, y))
	var current: Vector2 = start_point
	unvisited.erase(current)
	
	while !unvisited.empty():
		var neighbors: Array = get_neighbors(current, unvisited, HOR_AND_VER_DIR, 2)
		if neighbors.size() > 0:
			var next: Vector2 = neighbors[rng.randi() % neighbors.size()]
			stack.append(current)
			#Add tile to both cells, current and next
			var dir: Vector2 = next - current
			copy_array[current.x][current.y] = tile_id
			copy_array[next.x][next.y] = tile_id
			#insert tile in intermediate cell (since using step 2)
			var intermediate_cell: Vector2 = current+dir/2
			copy_array[intermediate_cell.x][intermediate_cell.y] = tile_id
			current = next
			unvisited.erase(current)
		elif stack:
			current = stack.pop_back()
		else:
			break
	return copy_array

# Use walkers to generate a PCG path
# max iterations = the limit of iterations in order to avoid lag or infinite loop
# tile_id = the tile id to set in the grid for the walker
# percent_to_complete: how much percent of the grid we want to complete
# grid array = the array to use by the walkers to generate a path
# start_point = where the walker starts
# null_id (-1) = the id of the tile that allows the walker to know that is not interacting with a wall
# filter_grid ([]) = an array grid with the same size of grid_array where the walkers can't walk over
static func generate_path_with_walkers(grid_array: Array, max_iterations: int, tile_id: int, percent_to_complete: float, rng: RandomNumberGenerator = RandomNumberGenerator.new(), start_point: Vector2 = Vector2.ZERO, filter_grid: Array = []) -> Array: 
	var copy_array: Array = grid_array.duplicate(true)
	
	var itr: int = 0
	var walkers: Array = []
	var walker_max_count = 3;
	var walker_spawn_chance = 0.25;
	var walker_direction_chance = 0.4;
	var walker_destroy_chance = 0.2;
	var max_same_dir = 6;
	var bounds: Vector2 = get_grid_array_size(copy_array)
	walkers.append(Walker.new(get_random_direction(rng, HOR_AND_VER_DIR), start_point))
	copy_array[start_point.x][start_point.y] = tile_id
	var n_tiles: int = 0
	while itr < max_iterations:
		var failed: bool = false
		#Check chance for destroying
		if walkers.size() > 1 and rng.randf() < walker_destroy_chance:
			walkers.remove(rng.randi()%walkers.size())

		#Check chance for spawning
		for i in range(walkers.size()):
			if rng.randf() < walker_spawn_chance and walkers.size() < walker_max_count:
				walkers.append(Walker.new(get_random_direction(rng, HOR_AND_VER_DIR), walkers[i].get_current_pos()))

		for i in range(walkers.size()):
			var next_pos: Vector2 = walkers[i].get_next_pos()
			#making sure we are not moving out of bounds
			var dir_itr: int = 0
			while (!is_in_grid_array_bounds(copy_array, next_pos, Vector2(1,1), Vector2(1, 1)) or (filter_grid.size() > 0 and filter_grid[next_pos.x][next_pos.y] != -1)):
				if dir_itr >= 5:
					if !walkers[i].move_back():
						if walkers.size() <= 1:
							failed = true
						walkers.remove(i)
					break
				walkers[i].change_to_next_dir(HOR_AND_VER_DIR)
				next_pos = walkers[i].get_next_pos()
				dir_itr+=1

			if dir_itr >= 5:
				break
			walkers[i].move()
			if  rng.randf() >= walker_direction_chance or walkers[i].get_same_dir_count() >= max_same_dir:
				walkers[i].set_dir(get_random_direction(rng, HOR_AND_VER_DIR))
				
			if copy_array[next_pos.x][next_pos.y] != tile_id:
				copy_array[next_pos.x][next_pos.y] = tile_id
				n_tiles+=1
				if float(n_tiles)/float(bounds.x*bounds.y) >= percent_to_complete:
					walkers.clear()
					return copy_array
		if failed:
			print("[FATAL ERROR] walker failed!!") #Maybe this should be  an assert
			break
		itr+=1
	walkers.clear()
	return copy_array
