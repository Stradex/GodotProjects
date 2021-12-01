class_name Player
extends KinematicBody2D

# Movement constants
const ACCELERATION: int = 8
const MOVE_SPEED: float = 200.0
const JUMP_SPEED: float = -450.0
const MAX_JUMPS: int = 2
const JUMP_DELAY_MS: int = 250
const JUMP_ADD_DURATION_MS: int = 750
const AIR_FRICTION: float = 25.0;
const FLOOR_FRICTION: float = 500.0;

# Other constants
const DAMAGE_PROTECTION_SEC: float = 1.5; #Seconds of damage protection
const SNAP_VECTOR: Vector2 = Vector2(0, 32.0);
const RESPAWN_TIME: float = 1.0;

var init_layer_mask = 0
var init_collision_mask = 0

var jump_count : int = 0
var jump_add_time_ms : int = 0
var next_jump_time : int = 0
var velocity : Vector2  = Vector2.ZERO
var is_crouched: bool = false;
var damage_protection: bool = false;
var is_jumping: bool = false;
var frozen: bool = false;
var security_level: int = 0;

#friction and impulse code
var was_on_floor: bool = false;
var velocity_impulse: Vector2 = Vector2.ZERO;
var last_floor_velocity: Vector2 = Vector2.ZERO;

onready var stand_collision_box: CollisionPolygon2D = $CollisionNormal
onready var crouch_collision_box: CollisionPolygon2D = $CollisionCrouch
onready var up_raycast: RayCast2D = $UpRayCast;
onready var up_raycast2: RayCast2D = $UpRayCast2;

#Export var
export var health: int = 3;
var initial_health: int = 3;

onready var CurrentWeapon: Node2D = $Sprite/Weapon;
onready var tween: Tween = $Tween;

#Key combo system
const BUFFER_CLEAN_DELAY: float = 0.35; #seconds
var action_buffer_countdown: float = BUFFER_CLEAN_DELAY;
var actions_buffer: Array = [];
var actions_buffer_max: int = 6; #MAX combo size
var combos: Dictionary = {
	"combo_example1": ["move_up", "move_up", "move_left", "move_down"],
	"combo_example2": ["move_left", "move_right", "use", "jump"]
};

var Spawn: Node2D = null;

#Netcode stuff start
var netid: int = -1;
var node_id: int = -1
var NetBoop = Game.Boop_Object.new(self);
enum NET_EVENTS {
	ATTACK,
	MAX_EVENTS 
};

var client_view_rect: Rect2 = Rect2(0, 0, 0, 0);
#Netcode stuff ends

var Util = Game.Util_Object.new(self);

func _ready() -> void:
	init_collision_mask = collision_mask;
	init_layer_mask = collision_layer;
	add_to_group("network_group"); # let's the Netcode know that we are a node that uses netcode
	add_to_group("players_group"); # let's the Netcode know that we are a node that uses netcode
	Util._ready();
	initial_health = health;
	var mapLimits = Game.CurrentMap.get_world_limits();
	$Camera.update_limits(mapLimits.start, mapLimits.end);
	if is_local_player():
		Game.GUI = $Camera/GUI;
		Game.set_active_camera($Camera);
		update_gui();
	else:
		$Camera/GUI.hide_gui();
	Engine.set_target_fps(Engine.get_iterations_per_second()) #Do this in other place later
	CurrentWeapon.disable_damage()
	
	Game.Network.register_synced_node(self, node_id);

func reset_collisions():
	collision_mask = init_collision_mask;
	collision_layer = init_layer_mask;
	
func disable_collisions():
	collision_mask = 0;
	collision_layer = 0;

func _physics_process(delta: float) -> void:
	if frozen:
		return;

	update_velocity(delta)
	update_collision_box()
	friction(delta)

	if !is_jumping:
		move_and_slide_with_snap(velocity + velocity_impulse, 32.0*Vector2.DOWN, 1*Vector2.UP);
	else:
		move_and_slide(velocity + velocity_impulse, Vector2.UP)

func friction(delta: float) -> void:
	if is_on_floor() || is_on_wall():
		velocity_impulse = Vector2.ZERO; #disable friction on floor and wall by now		
	
	if is_on_floor():
		last_floor_velocity = get_floor_velocity();
	elif was_on_floor && !is_on_floor():
		velocity_impulse = last_floor_velocity;
	was_on_floor = is_on_floor();

	var friction: float = FLOOR_FRICTION if (is_on_floor() || is_on_ceiling()) else AIR_FRICTION;
	if abs(velocity_impulse.x) <=  friction*delta:
		velocity_impulse.x = 0.0;
	elif velocity_impulse.x > 0.0:
		velocity_impulse.x -= friction*delta;
	elif  velocity_impulse.x < 0.0:
		velocity_impulse.x += friction*delta;
		
	if abs(velocity_impulse.y) <= friction*delta:
		velocity_impulse.y = 0.0;
	elif velocity_impulse.y > 0.0:
		velocity_impulse.y -= friction*delta;
	elif  velocity_impulse.y < 0.0:
		velocity_impulse.y += friction*delta;

func update_velocity(delta: float ) -> void:
	var time = OS.get_ticks_msec()
	if is_alive():
		jump(time, delta)
		run()
		crouch()
	fall(delta)
	$Sprite.update_animation(velocity, is_crouched);

func update_collision_box():
	if is_crouched && !stand_collision_box.disabled:
		stand_collision_box.disabled = true
		crouch_collision_box.disabled = false
	elif !is_crouched && stand_collision_box.disabled:
		stand_collision_box.disabled = false
		crouch_collision_box.disabled = true

func fall(delta: float) -> void:
	if frozen or is_on_floor():
		if velocity.y > 0.0:
			velocity.y = 0
		return;
	velocity.y += Game.GRAVITY*delta;

func jump(time: int, delta: float) -> void:
	if !is_local_player() or frozen:
		return;

	if is_on_floor() or is_on_ceiling():
		if is_on_floor():
			jump_count = 0
		velocity.y = 0
		is_jumping = false;
	elif jump_count == 0:
		jump_count = 1
	
	if Input.is_action_just_pressed("jump") and (is_on_floor() or jump_count < MAX_JUMPS) and time > next_jump_time:
		handle_first_jump(time)
	elif jump_count > 0 and time < jump_add_time_ms and Input.is_action_pressed("jump"):
		handle_extra_jump(delta)

func handle_first_jump(time: int):
	is_jumping = true;
	velocity.y = JUMP_SPEED;
	jump_count += 1
	next_jump_time = time + JUMP_DELAY_MS
	jump_add_time_ms = time + JUMP_ADD_DURATION_MS

func handle_extra_jump(delta: float):
	velocity.y += JUMP_SPEED*delta

func run() -> void:
	if !is_local_player() or frozen:
		return;
	velocity.x = 0;
	if Input.is_action_pressed("move_right"):
		velocity.x += MOVE_SPEED;
	if Input.is_action_pressed("move_left"):
		velocity.x -= MOVE_SPEED;

func crouch() -> void:
	if !is_local_player() or frozen:
		return;
	if Input.is_action_pressed("crouch"):
		is_crouched = true
		up_raycast.enabled = true
		up_raycast2.enabled = true;
	elif !up_raycast.is_colliding() && !up_raycast2.is_colliding():
		is_crouched = false
		up_raycast.enabled = false;
		up_raycast2.enabled = false;

#friendly movement functions
func crouch_cs() -> void:
	is_crouched = true
	up_raycast.enabled = true
	up_raycast2.enabled = true;
func uncrouch_cs() -> void:
	is_crouched = false
	up_raycast.enabled = false;
	up_raycast2.enabled = false;

func get_camera():
	return $Camera;

func respawn():
	health = initial_health;
	$AnimationPlayer.play("respawn");
	Game.set_active_camera($Camera);
	
	if typeof(Spawn) != TYPE_NIL:
		self.global_position = Spawn.global_position;
	else:
		self.global_position = Util.init_global_pos;
		Game.print_warning("¡No PlayerSpawn found for respawning!");
	self.velocity = Vector2.ZERO;

func hurt_effect():
	velocity.y = JUMP_SPEED;
	move_and_slide(velocity, Vector2.UP);
	$AnimationPlayer.play("hurt");

func hurt(attacker: Node2D, damage: int):
	if !is_local_player(): #just clientside damage.... BY NOW
		return;
	if damage_protection || !is_alive():
		return;
	enable_damage_protection();
	health-= damage;
	update_gui();
	hurt_effect();
	if health <= 0:
		killed(attacker);

func start_attack():
	if is_local_player() or Game.Network.is_server():
		Game.Network.net_send_event(self.node_id, NET_EVENTS.ATTACK, null);
	CurrentWeapon.enable_damage();

func end_attack():
	CurrentWeapon.disable_damage();

func enable_damage_protection():
	damage_protection = true; #Protect the player from receiving damage for a moment
	if tween.is_active():
		tween.remove(self, "disable_damage_protection");
	tween.interpolate_callback(self, DAMAGE_PROTECTION_SEC, "disable_damage_protection");
	tween.start();

func disable_damage_protection():
	$AnimationPlayer.play("idle");
	damage_protection = false;

func killed(attacker: Node2D = null):
	show_death_message(attacker)
	killed_fx()
	#respawn();
	update_gui();

func show_death_message(attacker: Node2D) -> void:
	var deathMsg: String = "";
	if !attacker or attacker.get("DEATH_MESSAGE") == null:
		deathMsg = "Player_name died";
	else:
		deathMsg = Game.get_str(attacker.DEATH_MESSAGE) % ["Player_name", attacker.NAME];
	Game.GUI.info_message(deathMsg);

func killed_fx() -> void:
	$AnimationPlayer.play("teleport");
	if !is_local_player():
		return
	if tween.is_active():
		tween.remove(Game.ViewportFX, "fade_in_out");
		tween.remove(self, "respawn");
	tween.interpolate_callback(Game.ViewportFX, RESPAWN_TIME, "fade_in_out", 1.0, 0.5);
	tween.interpolate_callback(self, RESPAWN_TIME+1.0, "respawn");
	tween.start();

func fade_out() -> void:
	$AnimationPlayer.play("fade_out");

func fade_in() -> void:
	$AnimationPlayer.play("fade_in");

func freeze() -> void:
	self.frozen = true;

func unfreeze() -> void:
	self.frozen = false;

func teleport_to_node(teleport_node: Node2D) -> void:
	self.global_position = teleport_node.global_position;

func is_alive() -> bool:
	return health > 0

func update_gui():
	if !is_local_player():
		return;
	Game.GUI.update_health(health);

#############################
# COMBO SYSTEM CODE		   ##
############################

func _process(delta):
	action_buffer_countdown-= delta;
	if action_buffer_countdown <= 0.0:
		if actions_buffer.size() > 0:
			actions_buffer.pop_back();
		action_buffer_countdown = BUFFER_CLEAN_DELAY;

func _input(event):
	if	!is_local_player():
		return;
		
	if event is InputEventKey && Input.is_action_just_pressed("attack"):
		$WeaponAnims.play("attack_forward");
		if tween.is_active():
			tween.remove(self, "end_attack");
		tween.interpolate_callback(self, 0.4, "end_attack");
		tween.start();
	if event is InputEventKey && event.is_pressed() && !event.is_echo():
		var action_pressed: String = get_action_name_from_scancode(event.scancode);
		if action_pressed.length() > 1:
			action_buffer_countdown = BUFFER_CLEAN_DELAY;
			actions_buffer.push_front(action_pressed);
			if actions_buffer.size() >= actions_buffer_max:
				actions_buffer.pop_back();
			var combo_name: String = check_combo();
			if combo_name.length() > 1:
				execute_combo(combo_name);

func check_combo() -> String:
	for key in combos: 
		if actions_buffer.size() >=  combos[key].size():
			var combo_achieved: bool = true;
			var combo_size: int = combos[key].size();
			for i in range(combo_size):
				#(combo_size-1)-i: this is because otherwise the combo is readed in the wrong order.
				if actions_buffer[i] != combos[key][(combo_size-1)-i]:
					combo_achieved = false;
					break;
			if combo_achieved:
				return key;
	return "";

func get_action_name_from_scancode(scancode: int) -> String:
	var actions: Array = InputMap.get_actions();
	for action in actions:
		var keys: Array = InputMap.get_action_list(action);
		for key in keys:
			if key is InputEventKey && key.scancode == scancode:
				return action;
	return "";

func execute_combo(combo_name: String): 
	print(combo_name);

#########################
# INVENTORY AND PICKUPS #
#########################
#Fix later: it doesn't let me use Item directly as parameter, so I have to add
#that extra ugly line of code to check if the node2d element it's indeed an item
#and then cat it to item :/
func give(item: Node2D) -> void:
	if !(item is Item): 
		return;
	var currentItem: Item = item;
	match(currentItem.get_name().to_lower()):
		"key":
			Game.GUI.info_message(Game.get_str("#str1004") % currentItem.ammount);
			security_level = currentItem.ammount;
		_:
			add_to_inventory(currentItem);
	return;

func get_index_from_inventory(item: Item) -> int:
	var itemName: String = item.get_name().to_lower();
	for i in Game.players_inventory[node_id]:
		if Game.players_inventory[node_id][i] and Game.players_inventory[node_id][i].has_key(itemName):
			return i;
	return -1;

func add_to_inventory(item: Item) -> void:
	var itemIndex: int = get_index_from_inventory(item);
	if itemIndex != -1:
		Game.players_inventory[node_id][itemIndex].ammount += item.ammount;
	else:
		Game.players_inventory[node_id].append({name = item.get_name().to_lower(), ammount = item.get_ammount()}); 


#############################
# NETCODE SPECIFIC RELATED ##
############################

func server_send_boop() -> Dictionary:
	# todo: some pre-check to see if sending the boop is really necessary
	var boopData = {
		 velocity = Vector2(),
		 position = Vector2(),
		 rotation = Vector2(),
		 is_crouched = self.is_crouched,
		 anim_playing = $Sprite.get_current_anim_playing(),
		 is_jumping = self.is_jumping
	};

	 #stepify iis important to avoid that an insignificant varition of data can lead to a new boop/snapshot
	boopData.velocity = Util.stepify_vec2(self.velocity, 0.01);
	boopData.position = Util.stepify_vec2(self.position, 0.01);
	boopData.rotation = stepify(self.rotation, 0.01);

	return boopData;

func client_send_boop() -> Dictionary:
	if !is_local_player():
		return {}; #empty dictionary means don't send nothing
		
	
	var boopData = {
		 velocity = Vector2(),
		 position = Vector2(),
		 rotation = Vector2(),
		 is_crouched = self.is_crouched,
		 anim_playing = $Sprite.get_current_anim_playing(),
		 is_jumping = self.is_jumping,
		 view_rect = Rect2()
	};
	boopData.velocity = Util.stepify_vec2(self.velocity, 0.01);
	boopData.position = Util.stepify_vec2(self.position, 0.01);
	boopData.rotation = stepify(self.rotation, 0.01);
	boopData.view_rect = Util.stepify_rect2(Game.get_view_rect2(), 0.01);
	
	return boopData;

func client_process_boop(boopData) -> void:
	if is_local_player():
		return;
	self.velocity = boopData.velocity;
	self.position = boopData.position;
	self.rotation = boopData.rotation;
	
	if self.is_crouched != boopData.is_crouched:
		if boopData.is_crouched:
			self.crouch_cs();
		else:
			self.uncrouch_cs();
	self.is_jumping = boopData.is_jumping;
	self.is_crouched = boopData.is_crouched
	$Sprite.set_animation(boopData.anim_playing);

func server_process_boop(boopData) -> void:
	if is_local_player():
		return;
	self.velocity = boopData.velocity;
	self.position = boopData.position;
	self.rotation = boopData.rotation;
	
	if self.is_crouched != boopData.is_crouched:
		if boopData.is_crouched:
			self.crouch_cs();
		else:
			self.uncrouch_cs();
			
	self.is_jumping = boopData.is_jumping;
	self.is_crouched = boopData.is_crouched;
	self.client_view_rect = boopData.view_rect;
	$Sprite.set_animation(boopData.anim_playing);

func server_process_event(eventId : int, eventData) -> void:
	match eventId:
		NET_EVENTS.ATTACK:
			if is_local_player():
				return;
			$WeaponAnims.play("attack_forward");
			if tween.is_active():
				tween.remove(self, "end_attack");
			tween.interpolate_callback(self, 0.4, "end_attack");
			tween.start();
		_:
			print("Warning: Received unkwown event");
			
func client_process_event(eventId : int, eventData) -> void:
	match eventId:
		NET_EVENTS.ATTACK:
			if is_local_player():
				return;
			$WeaponAnims.play("attack_forward");
			if tween.is_active():
				tween.remove(self, "end_attack");
			tween.interpolate_callback(self, 0.4, "end_attack");
			tween.start();
		_:
			print("Warning: Received unkwown event");

func is_local_player() -> bool:
	return !Game.Network.is_multiplayer() or (netid == get_tree().get_network_unique_id());

func get_class():
	return "Player";

# TO AVOID CRASH IN RELEASE BUILD!
func _exit_tree():
	remove_from_group("players_group");
	Game.Network.unregister_synced_node(self); #solve problem by now
	Game.Players[node_id] = null;
