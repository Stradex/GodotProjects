class_name NetworkBase
extends Node

# TODO: implement snapshot priority to entities, an array for queue snapshots and all that similar stuff from librecoop here
# to optimize netcode and avoid snapshot overflow in big maps and areas.
# same with events!

const SNAPSHOT_DELAY = 1.0/30.0; #Msec to Sec (20hz)
const MAX_PLAYERS:int = 4;
const SERVER_PORT:int = 27666;
const SERVER_NETID: int = 1;
var clients_connected: Array;
var player_count: int = 1;
const MAX_CLIENT_LATENCY: float = 0.4; #350ms
const MAX_MESSAGE_PING_BUFFER: int = 8; #Average from ammount
const NODENUM_NULL = -1;

var pings: Array; 
var client_latency: float = 0.0;
var ping_counter = 0.0;
var LevelScene: Node = null;
var local_player_id = 0; # 0 = Server
var netentities: Array;

# Netcode optimization: START (TODO in future, by now I just leave these vars and const)
const SV_MAX_SNAPSHOTS: int = 24; #How many snapshots at max to send at once each time using SNAPSHOT_DELAY
const SV_MAX_EVENTS: int = 16; #How many events at max to send at once
var snapshot_list: Array; #elements: Dictionary { net_entity = null, queue_pos = 0}
var saved_event_list: Array; #elements: Dictionary { net_id = -1, queue_pos = 0}
# Netcode optimiaztion: END

#DEBUG ONLY
var boops_sent_at_once: int = 0;
#END DEBUG ONLY

func ready():
	clear();
	Game.get_tree().connect("network_peer_connected", self, "_on_player_connected");
	Game.get_tree().connect("network_peer_disconnected", self, "_on_player_disconnect");
	Game.get_tree().connect("connected_to_server", self, "_cutie_joined_ok");
	Game.get_tree().connect("server_disconnected", self, "_on_server_shutdown");
	
	var timer = Timer.new();
	timer.set_wait_time(SNAPSHOT_DELAY);
	timer.set_one_shot(false)
	timer.connect("timeout", self, "write_boop")
	Game.add_child(timer)
	timer.start()

func clear():
	netentities.clear();
	clients_connected.clear();
	player_count = 0;
	local_player_id = 0;
	saved_event_list.clear();
	for _i in range(MAX_PLAYERS):
		netentities.append(null); 

func _on_server_shutdown():
	stop_networking();
	Game.get_tree().call_deferred("change_scene", "res://src/GUI/MainMenu.tscn");

func _cutie_joined_ok():
	if !Game.is_network_master():
		Game.rpc_id(SERVER_NETID, "game_process_rpc", "server_process_client_question", [Game.get_tree().get_network_unique_id()]);

func _process(_delta):
	pass;
	#if Game.get_tree().has_network_peer() && !Game.is_network_master():
	#	if ping_counter <=  0.0 || ping_counter > 2.0:
	#		client_send_ping(); #resend, just in case.
	#	ping_counter+=delta;

#Jim from ID please implement on_cutie_joined
func _on_player_connected(id):
	if is_server():
		var client_index:int = add_client(id);
		var PlayerToSpawn: Node2D = Game.add_player(id);
		Game.spawn_player(PlayerToSpawn);
		clients_connected[client_index].player_num = PlayerToSpawn.node_id;

#Jim from ID please on_cutie_leave
func _on_player_disconnect(id):
	if is_server():
		clients_connected.remove(find_client_number_by_netid(id));
		player_count-=1;

func add_client(netid: int, num: int = -1) -> int:
	print("Adding client with at position %d with netid %d" % [clients_connected.size(), netid]);
	clients_connected.append({netId = netid, player_num = num, ingame = false})
	player_count+=1;
	return player_count-1;

#only true when client finally loaded the map
func client_is_ingame(clientNum: int) -> bool:
	return clients_connected[clientNum].ingame;

func clients_in_server() -> int:
	return clients_connected.size();

func find_client_number_by_netid(netid: int):
	for i in range(clients_connected.size()):
		if clients_connected[i].netId == netid:
			return i;
	
	return -1;

func find_player_number_by_netid(netid: int):
	for i in range(Game.Players.size()):
		if Game.Players[i] and Game.Players[i].netid == netid:
			return i;
	return -1;

func server_process_client_question(id_client: int):
	var player_num: int = find_player_number_by_netid(id_client);
	send_rpc("new_client_connected", [clients_connected]);
	Game.rpc_id(id_client, "game_process_rpc", "client_receive_answer", [{map_name = Game.get_current_map_path(), player_number = player_num}]);

func client_receive_answer(receive_data: Dictionary):
	print("player number: %d, uniqueid: %d" % [receive_data.player_number, Game.get_tree().get_network_unique_id()]);
	local_player_id = receive_data.player_number;
	Game.add_player(Game.get_tree().get_network_unique_id(), receive_data.player_number);
	Game.change_to_map(receive_data.map_name);

func new_client_connected(new_clients_list: Array):
	clients_connected.clear();
	clients_connected = new_clients_list;
	add_clients_to_map();

func clear_players():
	var is_server: bool = false;
	for info in clients_connected:
		info.ingame = false;
		if info.netId == 1:
			is_server = true;
	if !is_server:
		clients_connected.append({netId = 1, ingame = false})

func client_send_ping():
	ping_counter = 0.0;
	Game.rpc_unreliable_id(SERVER_NETID, "server_receive_ping", Game.get_tree().get_network_unique_id());

remote func server_receive_ping(id_client):
	Game.rpc_unreliable_id(id_client, "client_receive_ping");

remote func client_receive_ping():
	pings.append(ping_counter);
	if pings.size() >= MAX_MESSAGE_PING_BUFFER:
		pings.pop_front();
	ping_counter = 0.0;
	var sum_pings: float = 0.0;
	for ping in pings:
		sum_pings+=ping;
	client_latency = sum_pings / float(pings.size());
	if typeof(LevelScene) != TYPE_NIL:
		LevelScene.update_latency();

func host_server(maxPlayers: int, mapName: String, serverPort: int = SERVER_PORT):
	Game.get_tree().set_network_peer(null); #Destoy any previous networking session
	var host = NetworkedMultiplayerENet.new();
	print(host.create_server(serverPort, maxPlayers));
	Game.get_tree().set_network_peer(host);
	add_client(SERVER_NETID); #adding server as friend client always
	Game.change_to_map(mapName);

func join_server(ip: String):
	ip = ip.replace(" ", "");
	Game.get_tree().set_network_peer(null); #Destoy any previous networking session
	var host = NetworkedMultiplayerENet.new();
	print(host.create_client(ip, SERVER_PORT));
	Game.get_tree().set_network_peer(host);

func stop_networking() -> void:
	Game.get_tree().call_deferred("set_network_peer", null);
	clear();


##################
# UTIL METHODS   #
##################

func is_multiplayer() -> bool:
	return Game.get_tree().has_network_peer();
	
func is_client() -> bool:
	if !Game.get_tree().has_network_peer() || Game.get_tree().is_network_server():
		return false;
	return true;
	
func is_server() -> bool:
	if Game.get_tree().has_network_peer() && !Game.get_tree().is_network_server():
		return false;
	return true;
	
func is_local_player(playerEntity: Node) -> bool:
	if Game.get_tree().has_network_peer() && playerEntity.player_id != local_player_id:
		return false;
	return true;

##################
# NETWORK BOOPS #
##################

func write_boop() -> void:
	if !Game.get_tree().has_network_peer():
		return;

	if Game.get_tree().is_network_server():
		server_send_boop();
	else:
		client_send_boop();

func server_send_boop() -> void:
	if player_count <= 0:
		return;
	boops_sent_at_once = 0;
	for entity in netentities:
		if server_entity_send_boop(entity):
			boops_sent_at_once+=1;

	# UN-COMMENT TO DEBUG
	#if boops_sent_at_once > 0:
	#	print("Sending %d boops" % boops_sent_at_once);

func server_entity_send_boop(entity) -> bool:
	var boop_was_sent: bool = false; #DEBUG ONLY, DELETE LATER
	if entity && entity.has_method("server_send_boop") && entity.is_inside_tree():
		var boopData: Dictionary = entity.server_send_boop();
		if !boopData or boopData.empty():
			return false
		#This loop it's to have unique boop deltas for each client, to avoid bad syncing
		for client in clients_connected:
			if !client or !client.ingame:
				continue;
			if client.netId == SERVER_NETID: #to avoid sending a boop to oneself as server
				continue;
			var clientNum: int = find_client_number_by_netid(client.netId);
			if entity.NetBoop.delta_boop_changed(boopData, clientNum):
				send_rpc_unreliable_id(client.netId, "client_process_boop", [entity.node_id, boopData]);
				boop_was_sent = true;
	return boop_was_sent

func client_send_boop() -> void:
	for entity in netentities:
		client_entity_send_boop(entity)

func client_entity_send_boop(entity) -> void:
	if entity && entity.has_method("client_send_boop") && entity.is_inside_tree():
		var boopData: Dictionary = entity.client_send_boop();
		if !boopData or boopData.empty():
			return;
		if entity.NetBoop.delta_boop_changed(boopData):
			send_rpc_unreliable_id(SERVER_NETID, "server_process_boop", [entity.node_id, boopData]);

func client_process_boop(entityId, message) -> void:
	if entityId < netentities.size() && netentities[entityId] && netentities[entityId].is_inside_tree():
		if netentities[entityId].has_method("client_process_boop"):
			netentities[entityId].client_process_boop(message);
	#else: #Entity exists in server but not in client, lets spawn it
	#	register_sycned_node_by_typenum(nodeNum, entityId);

func server_process_boop(entityId, message) -> void:
	if entityId < netentities.size() && netentities[entityId] && netentities[entityId].is_inside_tree():
		if netentities[entityId].has_method("server_process_boop"):
			netentities[entityId].server_process_boop(message);

##################
# NETWORK EVENTS #
##################

func save_event_to_list(entityId, eventId, eventData, unreliable) -> void:
	saved_event_list.append({evEntId = entityId, evId = eventId, evData = eventData, evUnreliable = unreliable});

func net_send_event(entityId, eventId, eventData=null, unreliable = false) -> void:
	if !is_multiplayer():
		return;
	if is_client():
		client_send_event(entityId, eventId, eventData, unreliable);
	else:
		server_send_event(entityId, eventId, eventData, unreliable);

func client_send_event(entityId, eventId, eventData=null, unreliable = false) -> void:
	print("client sending event...");
	if is_client():
		if unreliable: # When it is not vital to the event to reach the server (not recommended unless necessary)
			send_rpc_unreliable_id(SERVER_NETID, "server_process_event", [entityId, eventId, eventData]);
		else:
			send_rpc_id(SERVER_NETID, "server_process_event", [entityId, eventId, eventData]);

func server_send_event(entityId, eventId, eventData=null, unreliable = false, saveEvent = false) -> void:
	print("server sending event...");
	if is_server():
		if saveEvent:
			save_event_to_list(entityId, eventId, eventData, unreliable);
		if unreliable: # When it is not vital to the event to reach the server (not recommended unless necessary)
			send_rpc_unreliable("client_process_event", [entityId, eventId, eventData]);
		else:
			send_rpc("client_process_event", [entityId, eventId, eventData]);

func server_process_event(entityId, eventId, eventData) -> void:
	if !is_server():
		return;
	print("server receiving event...");
	if entityId < netentities.size() && netentities[entityId] && netentities[entityId].is_inside_tree():
		if netentities[entityId].has_method("server_process_event"):
			netentities[entityId].server_process_event(eventId, eventData);
			
func client_process_event(entityId, eventId, eventData) -> void:
	if !is_client():
		return;
	print("client receiving event...");
	if entityId < netentities.size() && netentities[entityId] && netentities[entityId].is_inside_tree():
		if netentities[entityId].has_method("client_process_event"):
			netentities[entityId].client_process_event(eventId, eventData);

################################
# MAP CHANGE AND LOAD HANDLING #
################################

func add_clients_to_map():
	for client in clients_connected:
		if client.netId == SERVER_NETID: #ignore this one, it's always player0
			continue;
		if is_client():
			print("adding client id %d as player %d" % [client.netId, client.player_num]);
		var PlayerToSpawn: Node2D = Game.add_player(client.netId, client.player_num);
		if Game.CurrentMap && Game.CurrentMap.already_loaded && !PlayerToSpawn.is_inside_tree():
			Game.spawn_player(PlayerToSpawn);

func clear_map_change():
	saved_event_list.clear();
	netentities.clear();
	for client in clients_connected:
		if client.netId == SERVER_NETID: #ignore this one, it's always player0
			continue;
		client.ingame = false;
	for _i in range(MAX_PLAYERS):
		netentities.append(null); 

func change_map(newmap: String) -> void:
	clear_map_change();
	if player_count <= 0 or is_client():
		return;
	send_rpc("server_changed_map", [newmap]);

func map_is_loaded() -> void:
	if !is_multiplayer():
		return;
	#if is_server():
	#	send_rpc("server_changed_map", [Game.get_current_map_path()]);
	if is_client():
		send_rpc_id(SERVER_NETID, "client_map_loaded", [Game.get_tree().get_network_unique_id()]);

func server_changed_map(server_map: String) -> void:
	Game.change_to_map(server_map);

func client_map_loaded(client_netid: int) -> void: #sending all saved events to the new player who joined
	if !is_server():
		return;
	var clientnum: int = find_client_number_by_netid(client_netid);
	clients_connected[clientnum].ingame = true;
	print("Player %d is ready!" % clientnum);
	for savedEvent in saved_event_list:
		if savedEvent.evUnreliable:
			send_rpc_id(client_netid, "client_process_event", [savedEvent.evEntId, savedEvent.evId, savedEvent.evData]);
		else:
			send_rpc_unreliable_id(client_netid, "client_process_event", [savedEvent.evEntId, savedEvent.evId, savedEvent.evData]);

#######################
# NETWORK RPC METHODS #
#######################

func send_rpc_id(id: int, method_name: String, args: Array) -> void:
	if !is_multiplayer():
		print("[Warning] trying to call send_rpc_id during singleplayer");
		return;
	Game.callv("rpc_id", [id, "game_process_rpc", method_name, args]);

func send_rpc_unreliable_id(id: int, method_name: String, args: Array) -> void:
	if !is_multiplayer():
		print("[Warning] trying to call send_rpc_unreliable_id during singleplayer");
		return;
	Game.callv("rpc_unreliable_id", [id, "game_process_rpc", method_name, args])
	
func send_rpc(method_name: String, args: Array) -> void:
	if !is_multiplayer():
		print("[Warning] trying to call send_rpc during singleplayer");
		return;
	Game.callv("rpc", ["game_process_rpc", method_name, args]);

func send_rpc_unreliable(method_name: String, args: Array) -> void:
	if !is_multiplayer():
		print("[Warning] trying to call rpc_unreliable during singleplayer");
		return;
	Game.callv("rpc_unreliable", ["game_process_rpc", method_name, args])

######################
# NET NODES HANDLING #
######################

func register_synced_node(nodeEntity: Node, forceId = NODENUM_NULL ) -> void:
	if !is_multiplayer():
		return;
	var freeIndex = MAX_PLAYERS;
	if forceId >= 0:
		freeIndex = forceId;
		print("Forcing id: " + str(freeIndex));
	else:
		while freeIndex < netentities.size() and netentities[freeIndex]:
			freeIndex+=1;
			
	while freeIndex >= netentities.size(): #dinamic netenities array
		netentities.append(null);

	nodeEntity.node_id = freeIndex;
	netentities[nodeEntity.node_id] = nodeEntity;
	print("Registering entity [ID " + str(freeIndex) + "] : " + nodeEntity.get_class());

func unregister_synced_node(nodeEntity: Node):
	if !is_multiplayer():
		return;
	if nodeEntity.node_id >= netentities.size() or nodeEntity.node_id < 0:
		return;
	print("Unregistering entity [ID " + str(nodeEntity.node_id) + "] : " + nodeEntity.get_class());
	netentities[nodeEntity.node_id] = null;
