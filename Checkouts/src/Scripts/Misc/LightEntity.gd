extends Node2D

export var light_broken: bool = false;

func _ready():
	$LightIcon.hide(); #Showed only in the editor so we can see it
	update_light();

func update_light():
	if light_broken:
		if !$Timer.is_connected("timeout", self, "_on_Timeout"):
			$Timer.connect("timeout", self, "_on_Timeout");
		$Timer.start();
	else:
		if $Timer.is_connected("timeout", self, "_on_Timeout"):
			$Timer.disconnect("timeout", self, "_on_Timeout");
		$Timer.stop();

func set_light_broken(broken: bool):
	light_broken = broken;
	update_light();

func _on_Timeout():
	$Timer.wait_time = rand_range(0.085, 0.25);
	self.enabled = !self.enabled;
