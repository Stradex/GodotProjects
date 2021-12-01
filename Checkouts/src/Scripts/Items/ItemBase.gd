class_name Item
extends Node2D

export var item_name: String;
export var ammount: int = 1;
export var can_pickup: bool = true;

func _ready():
	$Area2D.connect("body_entered", self, "_on_body_entered");

func _on_body_entered(body):
	if can_pickup and (body == Game.get_local_player()):
		body.give(self);
		call_deferred("queue_free");

func get_name() -> String:
	return item_name;

func get_ammount() -> int:
	return ammount;
