extends Area2D

var init_collision_layer: int = 0;
var init_collision_mask: int = 0;

func _ready():
	init_collision_layer = self.collision_layer;
	init_collision_mask = self.collision_mask;
	disable_damage();

func enable_damage():
	self.collision_layer = init_collision_layer;
	self.collision_mask = init_collision_layer;
	$CollisionPolygon2D.disabled = false;
	self.monitorable = true;
	self.monitoring = true;

func disable_damage():
	self.collision_layer = 0;
	self.collision_mask = 0;
	$CollisionPolygon2D.disabled = true;
	self.monitorable = false;
	self.monitoring = false;
