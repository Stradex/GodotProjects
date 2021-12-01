#class_name ??? I don't remember :(
extends KinematicBody2D

const NAME: String = "Roomba";
const DEATH_MESSAGE: String = "#str1003";
const ATTACK_DAMAGE: int = 1;
const MOVE_SPEED: float = 75.0
const RAYCAST_CHECK_DELAY: float = 50.0; #msec
const CHECKATTACK_DELAY: float = 350.0; #msec
const ATTACK_DURATION: float = 2000.0; #msec
const VIEW_ENEMY_DISTANCE: Vector2 = Vector2(350.0, 300.0);
const JUMP_SPEED: float = -400.0;
const ACTIVE_OUTSIDE_SCREEN_TIME: float = 15.0#sec
const SIZE: Vector2 = Vector2(32.0, 32.0); #Useful for jump detection
const CHASE_MIN_DISTANCE: float = 150.0;
const CHASE_CHECK_DELAY: float = 250.0 #msec;
const RUNAWAY_CHECK_DELAY: float = 250.0 #msec;
const CLOSEST_PLAYER_CHECK_DELAY: float = 250.0;
const IN_PLAYER_FOV_CHECK_DELAY: float = 250.0;

const IMPULSE_AIR_FRICTION: float = 100.0;
const IMPULSE_FLOOR_FRICTION: float = 600.0;
const DAMAGE_PROTECTION_TIME: float = 0.5;

export var walk_direction: float = 1.0;
export var never_dormant: bool = false;
export var aggressive: bool = false;
export var can_jump: bool = false;
export var harmless: bool = false;
export var chase: bool = false;
export var run_vel_mult:float = 4.0; 
export var skin: SpriteFrames = preload("res://src/Entities/Enemies/Skins/roomba_normal.tres");
export var health: int = 2;

#- aggressive / speedup
#- chase/turn around (follow you)
#- jump
#- harmless/blushy (do not hurt you at all)

var raycast_check_countdown = RAYCAST_CHECK_DELAY;
var attack_check_countdown = CHECKATTACK_DELAY;
var attacking_countdown = ATTACK_DURATION;
var outside_screen_countdown = ACTIVE_OUTSIDE_SCREEN_TIME;
var chase_check_countdown = CHASE_CHECK_DELAY;
var runaway_check_countdown = RUNAWAY_CHECK_DELAY;
var player_check_countdown = 0.0; #important to start from zero
var player_checkfov_countdown = IN_PLAYER_FOV_CHECK_DELAY;

var attacking: bool = false;
var player_inside_area: bool = false;
var Util = Game.Util_Object.new(self);
var active: bool = false;
var is_on_screen: bool = false;
var can_be_damaged: bool = true;
var runaway: bool = false;
var currentEnemy: Node2D = null; #Maybe change this in future.
var playerInArea: Node2D = null;
var running: bool = false;

var motion: Vector2 = Vector2.ZERO;
var impulse: Vector2 = Vector2.ZERO;
var colbox_size: Vector2 = Vector2.ZERO;
var raycast_length: float = 0.0;

onready var tween: Tween = $Tween;

#Netcode stuff start
var netid: int = -1;
var node_id: int = -1
var NetBoop = Game.Boop_Object.new(self);
enum NET_EVENTS {
	KILLED,
	MAX_EVENTS 
};
#Netcode stuff ends

func _ready():
	add_to_group("enemies"); # let's the Netcode know that we are a node that uses netcode
	currentEnemy = Game.get_local_player();
	Game.Network.register_synced_node(self);
	$PlayerDetection.connect("body_entered", self, "_on_body_entered");
	$PlayerDetection.connect("body_exited", self, "_on_body_exited");
	$PlayerDetection.connect("area_entered", self, "_on_area_entered");
	$VisibilityNotifier2D.connect("screen_entered", self, "_on_enter_screen");
	$VisibilityNotifier2D.connect("screen_exited", self, "_on_exit_screen");
	Util._ready();
	update_sprite();
	$Sprite.set_sprite_frames(skin);
	$Sprite.play("walk");
	colbox_size = 2.0*($CollisionShape2D.shape.get_extents());
	raycast_length = (colbox_size.x/2.0)+4.0;

func _physics_process(delta):
	
	check_if_in_player_pov(delta);
	if !active && !never_dormant:
		return;
		
	if Game.Network.is_client():
		cs_physics_think(delta);
	else:
		physics_think(delta);

func physics_think(delta):
	var friction: float = IMPULSE_FLOOR_FRICTION if (is_on_floor() || is_on_ceiling()) else IMPULSE_AIR_FRICTION;
	if impulse.x > 0.0:
		impulse.x -= delta*friction;
	elif impulse.x < 0.0:
		impulse.x += delta*friction;
	if abs(impulse.x) <= delta*friction:
		impulse.x = 0.0;

	check_player(delta);
	check_dormant(delta);
	check_collisions(delta);
	check_attacks(delta);
	check_damage(delta);
	check_chase(delta);
	fall(delta);
	
	running = attacking || runaway;
	move(delta);

func cs_physics_think(delta):
	var friction: float = IMPULSE_FLOOR_FRICTION if (is_on_floor() || is_on_ceiling()) else IMPULSE_AIR_FRICTION;
	if impulse.x > 0.0:
		impulse.x -= delta*friction;
	elif impulse.x < 0.0:
		impulse.x += delta*friction;
	if abs(impulse.x) <= delta*friction:
		impulse.x = 0.0;

	check_dormant(delta);
	check_collisions(delta);
	check_damage(delta);
	fall(delta);
	move(delta);

func check_player(delta):
	if player_check_countdown <= 0.0:
		player_check_countdown = CLOSEST_PLAYER_CHECK_DELAY;
		currentEnemy = Game.get_closest_player_to(self);
	else:
		player_check_countdown-=delta*1000.0;

func check_chase(delta):
	if !self.chase || self.runaway:
		return;
	if chase_check_countdown <= 0.0:
		chase_check_countdown = CHASE_CHECK_DELAY;
		var dist_to_player: float = (currentEnemy.global_position - self.global_position).length();
		if dist_to_player > CHASE_MIN_DISTANCE && enemy_can_be_reached():
			if currentEnemy.global_position.x > self.global_position.x:
				walk_direction = 1.0;
			else:
				walk_direction = -1.0;
		elif self.harmless:
			walk_direction = 0.0;
		update_sprite();
	else:
		chase_check_countdown-=delta*1000.0;

func run_away_from_player():
	self.runaway = true;
	if currentEnemy.global_position.x > self.global_position.x:
		walk_direction = -1.0;
	else:
		walk_direction = 1.0;
	$Sprite/RunParticles.emitting = true;
	$Sprite/CryParticles.emitting = true;
	update_sprite();

func cs_run_away_from_player():
	self.runaway = true;
	$Sprite/RunParticles.emitting = true;
	$Sprite/CryParticles.emitting = true;

func check_if_in_player_pov(delta) -> void:
	if player_checkfov_countdown > 0.0:
		player_checkfov_countdown-= delta*1000.0;
		return;
	
	player_checkfov_countdown = IN_PLAYER_FOV_CHECK_DELAY;
	var in_player_screen: bool = false;
	for i in range(Game.Players.size()):
		if !Game.Players[i]:
			continue;
		if  Game.Network.is_client() && Game.Players[i] != Game.get_local_player(): #for clients, just check the local player and no more.
			continue;
		if Game.Players[i] && Util.inside_camera_view(Game.Players[i]):
			in_player_screen = true;
			break;
	if in_player_screen:
		active = true;
		if !is_on_screen:
			print("enemy on screen....");
		is_on_screen = true;
	else:
		is_on_screen = false;
	
func _on_enter_screen():
	pass;
func _on_exit_screen():
	pass;

func reset_countdowns():
	attack_check_countdown = CHECKATTACK_DELAY;
	attacking_countdown = ATTACK_DURATION;
	outside_screen_countdown = ACTIVE_OUTSIDE_SCREEN_TIME;

func check_dormant(delta):
	if never_dormant || is_on_screen:
		outside_screen_countdown = ACTIVE_OUTSIDE_SCREEN_TIME;
		return;
	outside_screen_countdown -= delta;
	if (outside_screen_countdown <= 0):
		set_inactive();

func set_inactive():
	$Sprite/RunParticles.emitting = false;
	reset_countdowns(); 
	active = false;

func fall(delta):
	if !self.is_on_floor():
		motion.y += Game.GRAVITY*delta;
		if impulse.y < 0.0:
			impulse.y += Game.GRAVITY*delta;
	else:
		if  motion.y > 0.0:
			motion.y = 0.0;
		if  impulse.y > 0.0:
			impulse.y = 0.0;

func move(delta):
	motion.x = MOVE_SPEED*run_vel_mult if running else MOVE_SPEED;
	motion.x *= walk_direction;
	self.move_and_slide(motion + impulse, Vector2.UP);

func check_collisions(delta):
	raycast_check_countdown-=delta*1000.0;
	if raycast_check_countdown <= 0:
		var current_global_position: Vector2 = global_position;
		current_global_position.y += (colbox_size.y/2.0)-4.0; #4.0 for a margin
		var space_state = get_world_2d().direct_space_state;
		var result = space_state.intersect_ray(current_global_position, current_global_position+walk_direction*Vector2(raycast_length, 0), [self], collision_mask);
		if result:
			if (can_jump_over(delta, current_global_position+walk_direction*Vector2(raycast_length, 0))):
				motion.y = JUMP_SPEED;
			else:
				walk_direction = -walk_direction;
				update_sprite();
		#Random in order to reduce the chances of all checks being called at the same frame, to improve performance
		raycast_check_countdown = rand_range(RAYCAST_CHECK_DELAY-20.0, RAYCAST_CHECK_DELAY+20.0);

func check_attacks(delta):
	if !self.aggressive:
		return;
	if attacking:
		attacking_countdown-= delta*1000.0;
		if (attacking_countdown <= 0):
			attacking = false;
			$Sprite/RunParticles.emitting = false;
			update_sprite();
		return;

	attack_check_countdown-= delta*1000.0;
	if (attack_check_countdown <= 0):
		var vector_to_player: Vector2 = currentEnemy.global_position - self.global_position;
		if (abs(vector_to_player.x) <= VIEW_ENEMY_DISTANCE.x && abs(vector_to_player.y) <= VIEW_ENEMY_DISTANCE.y && enemy_can_be_reached()):
			if vector_to_player.x < 0:
				walk_direction = -1.0;
			else:
				walk_direction = 1.0;
			#motion.y = JUMP_SPEED;
			attacking_countdown = ATTACK_DURATION;
			attacking = true;
			update_sprite();
			$Sprite/RunParticles.emitting = true;
		#Random in order to reduce the chances of all checks being called at the same frame, to improve performance
		attack_check_countdown = rand_range(CHECKATTACK_DELAY-20.0, CHECKATTACK_DELAY+20.0);

func check_damage(delta):
	if !player_inside_area || self.harmless:
		return;
	#print("trying to damage player %d. Local player is %d" % [playerInArea.node_id, Game.get_local_player().node_id]);
	if playerInArea and (playerInArea == Game.get_local_player()): #by now only attack players, change this in future
		playerInArea.hurt(self, ATTACK_DAMAGE);

func update_sprite():
	if attacking && $Sprite.animation != "attack":
		$Sprite.play("attack");
	elif !attacking && ($Sprite.animation != "walk" || !$Sprite.is_playing()):
		$Sprite.play("walk");
	if walk_direction < 0.0 && $Sprite.scale.x < 0.0:
		$Sprite.scale.x = -$Sprite.scale.x;
	elif walk_direction > 0.0 && $Sprite.scale.x > 0.0:
		$Sprite.scale.x = -$Sprite.scale.x;
	elif walk_direction == 0.0:
		$Sprite.stop();

func _on_body_entered(body):
	if body.get_class() == "Player":
		playerInArea = body;
		player_inside_area = true;
		_on_player_entered();
		
func _on_body_exited(body):
	if body.get_class() == "Player":
		playerInArea = null;
		player_inside_area = false;
		_on_player_exited();

func _on_area_entered(area):
	if (area as Area2D).collision_layer & Game.PLAYER_ATTACK_LAYER:
		hurt();

func hurt():
	if !can_be_damaged or Game.Network.is_client(): #Disallow clientside damage in these entities by now
		return;
	impulse = Vector2(walk_direction*JUMP_SPEED, JUMP_SPEED*1.5);
	health-=1;
	if health <= 0:
		$AnimationPlayer.play("death");
	else:
		$AnimationPlayer.play("hurt");
		
	if self.harmless:
		run_away_from_player();
	disable_damage();
	
	if tween.is_active():
		tween.remove(self, "enable_damage");
	tween.interpolate_callback(self, DAMAGE_PROTECTION_TIME, "enable_damage");
	tween.start();

func enable_damage():
	can_be_damaged = true;

func disable_damage():
	can_be_damaged = false;

func killed():
	if Game.Network.is_server():
		Game.Network.server_send_event(self.node_id, NET_EVENTS.KILLED, null, false, true); #null eventData, unreliable = false, saveEvent = true
	call_deferred("queue_free");

func _on_player_entered():
	pass;

func _on_player_exited():
	pass;

func can_jump_over(delta, pos: Vector2) -> bool:
	if !self.can_jump:
		return false;

	var max_jump_time: float = -JUMP_SPEED/(2*Game.GRAVITY);
	if (max_jump_time <= 0.0):
		return false; #negative time... should never happen.

	var current_global_position: Vector2 = global_position;
	var size_offset: Vector2 = Vector2((colbox_size.x/2.0 - 4.0), (colbox_size.y/2.0)-4.0); #4.0 added as a margin-error avoider
	var get_max_jump_height: float = 0.5*Game.GRAVITY*pow(max_jump_time, 2.0)+JUMP_SPEED*max_jump_time;
	var new_pos = Vector2(pos.x, pos.y+get_max_jump_height-size_offset.y);
	current_global_position.y = new_pos.y;

	var space_state = get_world_2d().direct_space_state;
	var result = space_state.intersect_ray(current_global_position, new_pos, [self], collision_mask);
	if result:
		return false;
	else:
		return true;

func enemy_can_be_reached() -> bool:
	
	return Util.node_can_be_reached(currentEnemy, Game.get_active_players() + [self]);
	
############################
# NETCODE SPECIFIC RELATED #
############################

# TODO: Make this entity active when any player can see it, and not just the local player

func server_send_boop() -> Dictionary:
	if !active && !never_dormant:
		return {}; #only send info for active entities :3
	# todo: some pre-check to see if sending the boop is really necessary
	var boopData = {
		 walk_dir = 0.0,
		 position = Vector2(),
		 rotation = Vector2(),
		 impulse = Vector2(),
		 current_enemy = self.currentEnemy.node_id, #playerid
		 running = self.running,
		 attacking = self.attacking,
		 runaway = self.runaway
		
	};
	#stepify iis important to avoid that an insignificant varition of data can lead to a new boop/snapshot
	boopData.walk_dir = stepify(self.walk_direction, 0.01);
	boopData.position = Util.stepify_vec2(self.position, 0.01);
	boopData.impulse = Util.stepify_vec2(self.impulse, 0.01);
	boopData.rotation = stepify(self.rotation, 0.01);
	return boopData;

func client_process_boop(boopData) -> void:
	self.walk_direction = boopData.walk_dir;
	self.position = boopData.position;
	self.rotation = boopData.rotation;
	self.currentEnemy = Game.Players[boopData.current_enemy];
	self.running = boopData.running;
	self.attacking = boopData.attacking;
	self.impulse = boopData.impulse;
	if (self.runaway != boopData.runaway) and boopData.runaway:
		cs_run_away_from_player();
	update_sprite();

func client_process_event(eventId : int, eventData) -> void:
	match eventId:
		NET_EVENTS.KILLED:
			self.killed();
		_:
			print("Warning: Received unkwown event");

# TO AVOID CRASH IN RELEASE BUILD!
func _exit_tree():
	remove_from_group("enemies"); # let's the Netcode know that we are a node that uses netcode
	Game.Network.unregister_synced_node(self); #solve problem by now
