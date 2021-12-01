class_name Turret
extends Node2D

const NAME: String = "Turret";
const DEATH_MESSAGE: String = "#str1003"; #Change later
const CLOSEST_PLAYER_CHECK_DELAY: float = 250.0;
const IN_PLAYER_FOV_CHECK_DELAY: float = 250.0;
const UPDATE_SPRITE_DELAY: float = 125.0;
const FIRE_DELAY: float = 2000.0;

export (PackedScene) var projectile = preload("res://src/Entities/Projectiles/DefaultProjectile.tscn");
export var never_dormant: bool = false;
export var aggressive: bool = false;

#Netcode stuff start
var netid: int = -1;
var node_id: int = -1
var NetBoop = Game.Boop_Object.new(self);
#Netcode stuff ends

var Util = Game.Util_Object.new(self);
var active: bool = false;
var is_on_screen: bool = false;
var player_checkfov_countdown = IN_PLAYER_FOV_CHECK_DELAY;
var player_check_countdown = 0.0; #important to start from zero
var update_sprite_countdown = UPDATE_SPRITE_DELAY;
var fire_countdown = FIRE_DELAY;
var currentEnemy: Node2D = null; #Maybe change this in future.
onready var BarrelNode: Position2D = $Barrel;

func _ready():
	Util._ready();
	currentEnemy = Game.get_local_player();
	add_to_group("enemies"); # let's the Netcode know that we are a node that uses netcode
	Game.Network.register_synced_node(self);

func _physics_process(delta):
	
	check_if_in_player_pov(delta);
	if !active && !never_dormant:
		return;
	if !Game.Network.is_client(): #Let the server decide who this turret is aiming at.
		check_player(delta);
	check_attack(delta);
	update_sprite(delta);

func check_attack(delta):
	if fire_countdown <= 0.0:
		fire_countdown = FIRE_DELAY;
		if currentEnemy && aggressive:
			var firedProjectile: Projectile = projectile.instance();
			get_parent().call_deferred("add_child", firedProjectile);
			firedProjectile.fire_to_pos(BarrelNode.global_position, currentEnemy.global_position)
	else:
		fire_countdown-=delta*1000.0;

func update_sprite(delta):
	if update_sprite_countdown <= 0.0:
		update_sprite_countdown = UPDATE_SPRITE_DELAY;
		if !aggressive:
			$Sprite.play("harmless");
			return;
		if currentEnemy:
			adjust_sprite_angle()
	else:
		update_sprite_countdown-=delta*1000.0;

func adjust_sprite_angle():
	var angleToEnemy: float =  rad2deg(self.global_position.angle_to_point(currentEnemy.global_position)); 
	if angleToEnemy >= 0.0:
		return; #Enemy it's in an higher position than the turret
	angleToEnemy = abs(angleToEnemy); #just to make it easier for me
	if angleToEnemy <= 25.0:
		$Sprite.play("angry_90d");
		$Sprite.scale.x = 1;
	elif angleToEnemy <= 55.0:
		$Sprite.play("angry_45d");
		$Sprite.scale.x = 1;
	elif angleToEnemy <= 90.0:
		$Sprite.play("angry_30d");
		$Sprite.scale.x = 1;
	elif angleToEnemy <= 125.0:
		$Sprite.play("angry_30d");
		$Sprite.scale.x = -1;
	elif angleToEnemy <= 155.0:
		$Sprite.play("angry_45d");
		$Sprite.scale.x = -1;
	else:
		$Sprite.play("angry_90d");
		$Sprite.scale.x = -1;

func check_player(delta):
	if player_check_countdown <= 0.0:
		player_check_countdown = CLOSEST_PLAYER_CHECK_DELAY;
		currentEnemy = Game.get_closest_player_to(self); #Update this to make sure that it will take in account solid tiles and stuff
	else:
		player_check_countdown-=delta*1000.0;

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
		is_on_screen = true;
	else:
		is_on_screen = false;

############################
# NETCODE SPECIFIC RELATED #
############################

# TODO: Make this entity active when any player can see it, and not just the local player

func server_send_boop() -> Dictionary:
	if !active && !never_dormant:
		return {}; #only send info for active entities :3
	# todo: some pre-check to see if sending the boop is really necessary
	var boopData = {
		enemy_id = self.currentEnemy.node_id
	};
	return boopData;

func client_process_boop(boopData) -> void:
	self.currentEnemy = Game.Players[boopData.enemy_id];
	
# TO AVOID CRASH IN RELEASE BUILD!
func _exit_tree():
	remove_from_group("enemies"); # let's the Netcode know that we are a node that uses netcode
	Game.Network.unregister_synced_node(self); #solve problem by now
