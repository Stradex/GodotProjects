extends CanvasLayer

var fade_inout_time: float = 1.0;

func _ready():
	$ColorRect.visible = false;
	$Timer.connect("timeout", self, "_on_timer_timeout");

func fade_in(time: float):
	$AnimationPlayer.playback_speed = 1.0/time;
	$AnimationPlayer.play("fade_in");
	$ColorRect.visible = true;
	
func fade_out(time: float):
	$AnimationPlayer.playback_speed = 1.0/time;
	$AnimationPlayer.play("fade_out");
	$ColorRect.visible = true;

func fade_in_out(time: float, wait: float = 0.0):
	fade_inout_time = time/2.0;
	fade_in(fade_inout_time);
	$Timer.stop();
	$Timer.wait_time = fade_inout_time+wait;
	$Timer.start();

func _on_timer_timeout():
	fade_out(fade_inout_time);
	$Timer.stop();
	pass;

func fade_in_end():
	pass;
	
func fade_out_end():
	$ColorRect.visible = false;
	pass;
