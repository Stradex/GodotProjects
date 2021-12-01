class_name Door
extends Node2D

export var manual: bool = true;
export var trigger_only: bool = false; #only activated by trigger 
var locked: bool = false;

#Netcode stuff start
var netid: int = -1;
var node_id: int = -1
enum NET_EVENTS {
	ATTACK,
	OPENED,
	LOCK,
	UNLOCK
	CLOSED 
};
#Netcode stuff ends

func _ready():
	if trigger_only:
		$TriggerAutomatic.call_deferred("queue_free");
		$TriggerManual.call_deferred("queue_free");
	elif manual:
		$TriggerAutomatic.call_deferred("queue_free");
	else:
		$TriggerManual.call_deferred("queue_free");

	Game.Network.register_synced_node(self);

func toggle():
	if locked:
		return;
	if $Closed.visible:
		open(true);
	else:
		close(true);

func open(send_net_event: bool = false):
	if locked:
		return;
		
	if (manual or trigger_only) and send_net_event:
		Game.Network.net_send_event(self.node_id, NET_EVENTS.OPENED, null);
	$Closed.hide();
	$Open.show();
	$Closed/StaticEntity.disable_collisions();

func close(send_net_event: bool = false):
	if locked:
		return;
		
	if (manual or trigger_only) and send_net_event:
		Game.Network.net_send_event(self.node_id, NET_EVENTS.CLOSED, null);
	$Closed.show();
	$Open.hide();
	$Closed/StaticEntity.enable_collisions();

func lock() -> void:
	if Game.Network.is_multiplayer() and Game.Network.is_server():
		Game.Network.server_send_event(self.node_id, NET_EVENTS.LOCK, null);
	close();
	locked = true;

func unlock() -> void:
	if Game.Network.is_multiplayer() and Game.Network.is_server():
		Game.Network.server_send_event(self.node_id, NET_EVENTS.UNLOCK, null);
	locked = false;
	open();

func server_process_event(eventId : int, eventData) -> void:
	match eventId:
		NET_EVENTS.OPENED:
			open();
		NET_EVENTS.CLOSED:
			close();
		_:
			print("Warning: Received unkwown event");

func client_process_event(eventId : int, eventData) -> void:
	match eventId:
		NET_EVENTS.OPENED:
			open();
		NET_EVENTS.CLOSED:
			close();
		NET_EVENTS.LOCK:
			lock();
		NET_EVENTS.UNLOCK:
			unlock();
		_:
			print("Warning: Received unkwown event");

# TO AVOID CRASH IN RELEASE BUILD!
func _exit_tree():
	Game.Network.unregister_synced_node(self); #solve problem by now
