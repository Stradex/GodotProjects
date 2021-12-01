class_name ElevatorBase
extends Platform

export var automatic: bool = true;
export var lights: bool = false;

var old_visibility: bool = false;

func _ready():
	old_visibility = self.visible;
	update_lights();
	update_triggers();

func _process(delta):
	if old_visibility != self.visible:
		update_triggers();
		old_visibility = self.visible; 

func enable_lights():
	lights = true
	update_lights()

func disable_lights():
	lights = false;
	update_lights()

func update_triggers():
	if !self.visible:
		$ElevatorButton.disable_trigger();
	else:
		$ElevatorButton.enable_trigger();

func update_lights():
	if lights:
		$Light.visible = true;
	else:
		$Light.visible = false;

func _on_player_enter():
	if automatic:
		$Trigger.trigger_enabled = false;
		move_to_pos(current_pos_index+1);

func next_pos_reached():
	current_pos_index = next_pos_index;
	$Trigger.trigger_enabled = true;

func move_to_next_floor():
	move_to_pos(current_pos_index+1);

func _on_player_leave():
	pass;
