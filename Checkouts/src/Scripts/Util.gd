extends Object

#Features shared for MOST of the entities
const FLOAT_TOLERANCE: float = 0.005; #near insignificant error for float
const BIG_INT: int = 536870912;
var father_node: Node2D;
var init_pos: Vector2;
var init_global_pos: Vector2;
var init_rotation: float; #Radians
var init_global_rotation: float; # Radians

###################################
# Optimization functions: START
# Believe me, these extra functions are worth the extra code
###################################

var optimization_movement_cache: Dictionary = {
	# id
	'start': Vector2.ZERO,
	'end': Vector2.ZERO,
	'time': 0.0,
	'accel_time': 0.0,
	'max_speed': 0.0,
	#optimization
	'speed_mult_vec': Vector2.ZERO,
	'distance': Vector2.ZERO,
	'acceleration': 0.0,
	'accel_dist': 0.0
};

func optimize_move_initial_accel(max_speed: float, accel_time: float, start: Vector2, end: Vector2) -> void:
	if (optimization_movement_cache.start == start) && ((optimization_movement_cache.end == end) && (optimization_movement_cache.max_speed == max_speed) && (optimization_movement_cache.accel_time == accel_time)):
		return; #everything up to date.
		
	optimization_movement_cache.start = start;
	optimization_movement_cache.end = end;
	optimization_movement_cache.max_speed = max_speed;
	optimization_movement_cache.accel_time = accel_time;
	
	#pre-calculate expensive stuff
	optimization_movement_cache.speed_mult_vec = (end-start).normalized();
	if accel_time > 0.0:
		var dist = (end-start).length();
		optimization_movement_cache.distance = dist;

func optimize_move_with_init_accel_and_time(time: float, accel_time: float, start: Vector2, end: Vector2) -> void:
	if (optimization_movement_cache.start == start) && ((optimization_movement_cache.end == end) && (optimization_movement_cache.time == time) && (optimization_movement_cache.accel_time == accel_time)):
		return; #everything up to date.
	#it is necessary to update data
	optimization_movement_cache.start = start;
	optimization_movement_cache.end = end;
	optimization_movement_cache.time = time;
	optimization_movement_cache.accel_time = accel_time;
	
	#pre-calculate expensive stuff
	optimization_movement_cache.speed_mult_vec = (end-start).normalized();
	var dist = (end-start).length();
	optimization_movement_cache.distance = dist;
	if accel_time > 0.0:
		var accel = dist/(accel_time*(time-accel_time));
		optimization_movement_cache.acceleration = accel;
		optimization_movement_cache.accel_dist = 0.5*accel*pow(accel_time, 2.0);

###################################
# Optimization functions: END
###################################

func _init(node: Node2D):
	father_node = node;

func _ready():
	init_pos = father_node.position;
	init_global_pos = father_node.global_position;
	init_rotation = father_node.rotation;
	init_global_rotation = father_node.global_rotation;

func position_can_be_reached(pos: Vector2, exclude_nodes: Array) -> bool:
	var self_global_position: Vector2 = father_node.global_position;
	var vector_to_point: Vector2 = pos - self_global_position;
	var space_state = father_node.get_world_2d().direct_space_state;
	var result = space_state.intersect_ray(self_global_position, self_global_position+vector_to_point, exclude_nodes, father_node.collision_mask);
	if result:
		return false;
	else:
		return true;

func node_can_be_reached(node: Node2D, exclude_nodes: Array) -> bool:
	return position_can_be_reached(node.global_position, exclude_nodes);

#func player_can_be_reached(exclude_nodes: Array = [father_node, Game.Player]) -> bool:
#	return node_can_be_reached(Game.Player, exclude_nodes);

func floatsAreNearEqual(f1: float, f2: float):
	if abs(f1-f2) <= FLOAT_TOLERANCE:
		return true;
	else:
		return false;

func vectorsAreNearEqual(v1: Vector2, v2: Vector2):
	return (v1-v2).length_squared() <= FLOAT_TOLERANCE;

func move_with_initial_accel_and_time(delta: float, time: float, accel_time: float, start: Vector2, end: Vector2) -> void:
	optimize_move_with_init_accel_and_time(time, accel_time, start, end); #to calculate expensive stuff only once.
	
	var speed_mult_vec: Vector2 = optimization_movement_cache.speed_mult_vec;
	var move_velocity: Vector2;
	var current: Vector2 = father_node.position;
	var hf: float = optimization_movement_cache.distance;
	if accel_time <= 0.0:
		move_velocity = (hf/time)*speed_mult_vec;
	else:
		var a = optimization_movement_cache.acceleration; #acceleration calculated with nice equation I made.
		var h = (current - start).length();
		var t=0.0;
		var hao = optimization_movement_cache.accel_dist; 
		if h <= hao:
			t = sqrt(2*h/a);
		elif (h > hao) && h <= (hao + a*accel_time*(time-2*accel_time)):
			t = (h - hao)/(a*accel_time) + accel_time;
		else:
			var c = (h-hao)/a + 1.5*pow(accel_time, 2.0) + 0.5*pow(time, 2.0) -time*accel_time;
			var sqrt_discriminant = sqrt(pow(time, 2.0)-2.0*c);
			t = time- sqrt_discriminant
			
		if t <= (time-accel_time):
			move_velocity = clamp(t, 0.016, accel_time)*a*speed_mult_vec; #clamp is vital
		else:
			move_velocity = clamp(time-t, 0.016, accel_time)*a*speed_mult_vec; #clamp is vital
		
	father_node.position = normalize_position(current, current + move_velocity*delta, end);
	
func move_with_initial_acceleration(delta: float, max_speed: float, accel_time: float, start: Vector2, end:Vector2) -> void:
	optimize_move_initial_accel(max_speed, accel_time, start, end); #to calculate expensive stuff only once.

	var speed_mult_vec: Vector2 = optimization_movement_cache.speed_mult_vec;
	var move_velocity: Vector2;
	var current: Vector2 = father_node.position;
	
	#Get movement velocity
	if accel_time <= 0.0:
		move_velocity = max_speed*speed_mult_vec;
	else:
		var hmid: float = (optimization_movement_cache.distance)/2.0;
		var h: float = hmid - abs(hmid -(end-current).length());
		var v: float = sqrt(abs(2.0*h*max_speed))/accel_time;
		v = clamp(v, 1.0, max_speed); #clamp is vital because this function is based on velocity and not time!! 
		move_velocity = v*speed_mult_vec;
	
	# do the movement
	father_node.position = normalize_position(current, current + move_velocity*delta, end);

func normalize_position(old_pos: Vector2, new_pos: Vector2, end_pos: Vector2) -> Vector2:
	var normalized_pos: Vector2 = new_pos;
	if ((old_pos.x <= end_pos.x) && (new_pos.x > end_pos.x)) || ((old_pos.x >= end_pos.x) && (new_pos.x < end_pos.x)):
		normalized_pos.x = end_pos.x;
	if ((old_pos.y <= end_pos.y) && (new_pos.y > end_pos.y)) || ((old_pos.y >= end_pos.y) && (new_pos.y < end_pos.y)):
		normalized_pos.y = end_pos.y;
	
	return normalized_pos;

func move_with_velocity(delta: float, vel: Vector2) -> void:
	father_node.position += vel*delta;

func stepify_vec2(vec2: Vector2, precision: float) -> Vector2 :
	return Vector2(stepify(vec2.x, precision),stepify(vec2.y, precision));

func stepify_rect2(rectangle: Rect2, precision: float) -> Rect2 :
	return Rect2(stepify_vec2(rectangle.position, precision),stepify_vec2(rectangle.size, precision));

func inside_camera_view(player: Node2D) -> bool:
	if player.is_local_player():
		return Game.get_view_rect2(1.1).has_point(father_node.global_position); 	#1.1 in order to get 10% extra margin
	else:
		return player.client_view_rect.has_point(father_node.global_position);
