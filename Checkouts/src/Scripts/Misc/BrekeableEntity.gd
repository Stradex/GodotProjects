extends "res://src/Scripts/Misc/StaticEntityDefault.gd"
const DAMAGE_PROTECTION_TIME: float = 0.5; #secs

export var health: int = 1;
onready var tween: Tween = $Tween;

var can_be_damaged: bool = true;

func _ready():
	$Hitzone.connect("area_entered", self, "_on_area_entered");
	$Hitzone.connect("body_entered", self, "_on_body_entered");

func _on_area_entered(area):
	hurt();
		
func _on_body_entered(body):
	pass;

func enable_damage():
	can_be_damaged = true;

func disable_damage():
	can_be_damaged = false;

func hurt():
	if !can_be_damaged:
		return;
	health-=1;
	if health <= 0:
		$AnimatedSprite.play("broken");
	else:
		disable_damage();
		enable_damage_protection_tween()

func enable_damage_protection_tween():
	if tween.is_active():
		tween.remove(self, "enable_damage");
	tween.interpolate_callback(self, DAMAGE_PROTECTION_TIME, "enable_damage");
	tween.start();
