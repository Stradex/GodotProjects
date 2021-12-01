extends "res://src/Scripts/Misc/TriggerUse.gd"

func trigger_activated():
	.trigger_activated();
	set_on();

func enable_trigger():
	.enable_trigger();
	set_off();

func set_on():
	$Sprite.play("on");
func set_off():
	$Sprite.play("off");
