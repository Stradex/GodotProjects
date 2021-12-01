extends TriggerBase
#extends "res://src/Scripts/Misc/TriggerBase.gd"

export var call_function_enter: String;
export var call_args_enter: Array = [];
export var call_function_exit: String;
export var call_args_exit: Array = [];
export var activated_by: String = "$Player" ;

var activatedBy: Node = null;
var group_activator: String = "";
var activated_by_group: bool = false;

func get_group_activator_name(activated_by_string: String) -> String:
	match(activated_by_string):
		"$Players":
			return "players_group";
		"$Enemies":
			return "enemies";
	print("[Warning] Unkwown group at get_group_activator_name...");
	return "error";

func is_activated_by_group(activated_by_string: String) -> bool:
	match(activated_by_string):
		"$Players":
			return true;
		"$Enemies":
			return true;
	return false;

func update_trigger_data():
	.update_trigger_data();
	if call_function_enter.length() > 1 || call_function_exit.length() > 1:
		activated_by_group = is_activated_by_group(activated_by);

		if activated_by_group:
			group_activator = get_group_activator_name(activated_by);
		else:
			activatedBy = get_node_by_string(activated_by); # By default

		if call_function_enter.length() > 1:
			if activated_by_group:
				self.connect("body_entered", self,  "on_body_entered");
				self.connect("area_entered", self,  "on_area_entered");
			else:
				if has_node_type(activatedBy, PhysicsBody2D):
					self.connect("body_entered", self,  "on_body_entered");
				else:
					self.connect("area_entered", self,  "on_area_entered");
				
		if call_function_exit.length() > 1:
			if activated_by_group:
				self.connect("body_exited", self, "on_body_exited");
				self.connect("area_exited", self,  "on_area_exited");
			else:
				if has_node_type(activatedBy, PhysicsBody2D):
					self.connect("body_exited", self, "on_body_exited");
				else:
					self.connect("area_exited", self,  "on_area_exited");

func on_body_entered(body):
	if !allow_clientside and Game.Network.is_client():
		return;
	if activated_by_group:
		if !body.is_in_group(group_activator):
			return;
	else:
		if body != activatedBy:
			return;

	node_call_function(call_function_enter, call_args_enter, delay);
	if trigger_once:
		disconnect_method("body_entered");

func on_area_entered(area):
	if !allow_clientside and Game.Network.is_client():
		return;
	if activated_by_group:
		if !area.is_in_group(group_activator):
			return;
	else:
		if area != activatedBy:
			return;

	node_call_function(call_function_enter, call_args_enter, delay);
	if trigger_once:
		disconnect_method("area_entered");

func on_body_exited(body):
	if !allow_clientside and Game.Network.is_client():
		return;
	if activated_by_group:
		if !body.is_in_group(group_activator):
			return;
	else:
		if body != activatedBy:
			return;

	node_call_function(call_function_exit, call_args_exit, delay);
	if trigger_once:
		disconnect_method("body_exited");

func on_area_exited(area):
	if !allow_clientside and Game.Network.is_client():
		return;
	if activated_by_group:
		if !area.is_in_group(group_activator):
			return;
	else:
		if area != activatedBy:
			return;

	node_call_function(call_function_exit, call_args_exit, delay);
	if trigger_once:
		disconnect_method("area_exited");
