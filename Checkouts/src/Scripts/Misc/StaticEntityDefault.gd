extends StaticBody2D

export var solid: bool = true;

var init_layer_mask = 0
var init_collision_mask = 0

func enable_collisions():
	collision_mask = init_collision_mask;
	collision_layer = init_layer_mask;
	
func disable_collisions():
	collision_mask = Game.PLAYER_ATTACK_LAYER;
	collision_layer = 0;

func _ready():
	init_collision_mask = collision_mask;
	init_layer_mask = collision_layer;
	
	if !solid:
		disable_collisions();
