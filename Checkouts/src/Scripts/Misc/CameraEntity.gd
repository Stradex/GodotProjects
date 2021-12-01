class_name CameraEntity
extends Camera2D

const MIN_MOVE_PRECISION: float = 1.0;

var move_step: Vector2;
var next_zoom: Vector2;
var next_pos: Vector2;
var moving_to: bool = false;
var Util = Game.Util_Object.new(self);

#For camera interpolation
#var i_start_pos: Vector2 = Vector2.ZERO;
#var i_end_pos: Vector2 = Vector2.ZERO;
#var i_time: float = 0.25; #Default time for movement interpolation

const MAX_FOLLOW_SPEED: float = 8.0;

var i_speed: float = 4.0;
var i_speed_incr: float = 0.0;

func _ready():
	next_pos = position;
	next_zoom = zoom;
	Util._ready();

func _physics_process(delta):
	if moving_to:
		interpolate_movement(delta);
	interpolate_zoom(delta);

func interpolate_movement(delta):
	if i_speed <= MAX_FOLLOW_SPEED:
		i_speed+=delta*i_speed_incr;
	position = position.linear_interpolate(next_pos, delta * i_speed);
	if (position - next_pos).length() <= MIN_MOVE_PRECISION:
		moving_to = false;

func interpolate_zoom(delta: float) -> void:
	if	next_zoom != zoom:
		if next_zoom.x > zoom.x:
			zoom.x = clamp(zoom.x + move_step.x*delta, zoom.x, next_zoom.x);
		else:
			zoom.x = clamp(zoom.x + move_step.x*delta, next_zoom.x, zoom.x);
		if next_zoom.y > zoom.y:
			zoom.y = clamp(zoom.y + move_step.y*delta, zoom.y, next_zoom.y);
		else:
			zoom.y = clamp(zoom.y + move_step.y*delta, next_zoom.y, zoom.y);

func update_limits(start: Vector2, end:Vector2) -> void:
	limit_left = int(start.x);
	limit_top = int(start.y);
	limit_right = int(end.x);
	limit_bottom = int(end.y);

func change_zoom_interpolated(new_scale: float, seconds: float) -> void:
	move_step.x = (new_scale - zoom.x)/seconds;
	move_step.y = (new_scale - zoom.y)/seconds;
	next_zoom = Vector2(new_scale, new_scale);

func move_to(to: Vector2, interpolated: bool, speed: float = 4.0):
	i_speed = speed;
	i_speed_incr = speed;
	if interpolated:
		moving_to = true;
		next_pos.x = to.x;
		next_pos.y = to.y;
	else:
		position.x = to.x;
		position.y = to.y;

func move_from(from: Vector2, to: Vector2, speed: float = 4.0):
	position = from;
	move_to(to, true, speed);

func move_to_node2d(point: Node2D, interpolated: bool, speed: float = 4.0):
	var to: Vector2 = point.global_position - get_parent().global_position;
	move_to(to, interpolated, speed);

func move_from_node2d(point: Node2D, to: Vector2, speed: float = 4.0):
	var from: Vector2 = point.global_position -  get_parent().global_position;
	move_from(from, to, speed);
	
func move_from_node2d_to_node2d(point_from: Node2D, point_to: Node2D, speed: float = 4.0):
	var from: Vector2 = point_from.global_position -  get_parent().global_position;
	var to = point_to.global_position - get_parent().global_position;
	move_from(from, to, speed);

func _exit_tree():
	if Game.ActiveCamera == self:
		Game.ActiveCamera = null;
