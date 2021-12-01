extends TriggerBase

export var call_function: String;
export var call_args: Array = [];
var players_in: int = 0;

func update_trigger_data():
	.update_trigger_data();
	self.connect("body_entered", self,  "on_body_entered");
	self.connect("area_entered", self,  "on_area_entered");
	self.connect("body_exited", self, "on_body_exited");
	self.connect("area_exited", self,  "on_area_exited");

func all_players_in() -> bool:
	if players_in >= Game.get_active_players_count():
		return true;
	else:
		return false;

func on_body_entered(body):
	if !allow_clientside and Game.Network.is_client():
		return;
	if !body.is_in_group("players_group"):
		return;
	players_in+=1;

	if all_players_in():
		node_call_function(call_function, call_args, delay);
		if trigger_once:
			disconnect_all_methods();
	elif Game.Network.is_multiplayer():
		Game.GUI.info_message("Waiting for all players....");
		
func on_area_entered(area):
	if !allow_clientside and Game.Network.is_client():
		return;
	if !area.is_in_group("players_group"):
		return;
	players_in+=1;
	if all_players_in():
		node_call_function(call_function, call_args, delay);
		if trigger_once:
			disconnect_all_methods();
	elif Game.Network.is_multiplayer():
		Game.GUI.info_message("Waiting for all players....");

func on_body_exited(body):
	if !allow_clientside and Game.Network.is_client():
		return;
	if !body.is_in_group("players_group"):
		return;
	players_in-=1;
		
func on_area_exited(area):
	if !allow_clientside and Game.Network.is_client():
		return;
	if !area.is_in_group("players_group"):
		return;
	players_in-=1;
