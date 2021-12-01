extends "res://src/Scripts/Misc/BrekeableEntity.gd"

func hurt():
	.hurt();
	$AnimationPlayer.play("hit");
