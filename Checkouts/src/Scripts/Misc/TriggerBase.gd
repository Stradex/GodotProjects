class_name TriggerBase
extends Area2D

export var node_caller: String = "$CurrentMap";
export var trigger_once: bool = false;
export var wait_time: float = 0.0; #Time until the trigger can be called again
export var delay: float = 0.0; #Time until the trigger can be called again
export var allow_clientside: bool = true; #if true, this can also be activated clientside

var nodeCaller: Node;
var trigger_enabled: bool = true;

onready var tween = $Tween;

func _ready():
	update_trigger_data();

func update_trigger_data():
	disconnect_all_methods();
	nodeCaller = get_node_by_string(node_caller); 

func get_node_by_string(node_string: String) -> Node:
	
	var nodeReturn: Node;
	
	match(node_string):
		#shorthands first
		"$CurrentMap": 
			nodeReturn = Game.CurrentMap;
		"$Player":
			nodeReturn = Game.Players[Game.Network.local_player_id]; #By now just local player activate this, triggers are clientside therefore by now....
		"$Self":
			nodeReturn = self;
		"$Parent":
			nodeReturn = self.get_parent();
		"$Game": #this is probably a dangerous thing to do, maybe we want in a future to specify only which kind of functions can be called using this in the Game singleton
			nodeReturn = Game;
		_:
			nodeReturn = Game.CurrentMap.get_node(NodePath(node_string));
	return nodeReturn;

func has_node_type(nodeEntity: Node, nodeType):
	if nodeEntity is nodeType:
		return true;
	
	var children_of_node = nodeEntity.get_children();
	for child in children_of_node:
		if has_node_type(child, nodeType):
			return true;
		
	return false;

func disconnect_method(action_name: String):
	if self.is_connected(action_name, self, "on_" + action_name):
		self.disconnect(action_name, self, "on_" + action_name);

func node_call_function(call_function: String, call_args: Array, call_delay: float):
	if !trigger_enabled:
		return;
	
	if wait_time > 0.0:
		trigger_enabled = false;
		if tween.is_active():
			tween.remove(self, "enable_trigger");
		tween.interpolate_callback(self, wait_time, "enable_trigger");
		tween.start();

	if call_delay > 0.0:
		var array_data: Array = convert_array_args_to_tween_args(call_args);
		if tween.is_active():
			tween.remove(nodeCaller, call_function);
		tween.interpolate_callback(nodeCaller, call_delay, call_function, array_data[0], array_data[1], array_data[2], array_data[3], array_data[4]);
		tween.start();
	else:
		nodeCaller.callv(call_function, call_args);
		
	trigger_activated();

func enable_trigger():
	trigger_enabled = true; 

func disable_trigger():
	trigger_enabled = false;

func convert_array_args_to_tween_args(array_args: Array) -> Array:
	var tween_array: Array = [];
	for _i in range(5):
		tween_array.append(null);
		
	for i in range(array_args.size()):
		if i >= 5:
			break;
		tween_array[i] = array_args[i];
	return tween_array;


func disconnect_all_methods():
	if self.is_connected("body_entered", self,  "on_body_entered"):
		self.disconnect_method("body_entered");
	if self.is_connected("area_entered", self,  "on_area_entered"):
		self.disconnect_method("area_entered");
	if self.is_connected("body_exited", self,  "on_body_exited"):
		self.disconnect_method("body_exited");
	if self.is_connected("area_exited", self,  "on_area_exited"):
		self.disconnect_method("area_exited");


#######################################
# Methods to be overloaded by childs ##
#######################################

func trigger_activated():
	pass; 

func on_body_entered(body):
	pass;
		
func on_area_entered(area):
	pass;

func on_body_exited(body):
	pass;
		
func on_area_exited(area):
	pass;
