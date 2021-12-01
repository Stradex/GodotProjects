class_name Projectile
extends KinematicBody2D

export var speed: float = 250.0;
export var damage: int = 1;

var velocity: Vector2 = Vector2.ZERO;
var global_spawn_pos: Vector2 = Vector2.ZERO;

func _ready():
	self.global_position = global_spawn_pos;
	$Area2D.connect("area_entered", self, "_on_area_entered");
	$Area2D.connect("body_entered", self, "_on_body_entered");

func _on_area_entered(area):
	if area is TriggerBase:
		return;
	self.call_deferred("queue_free");
func _on_body_entered(body):
	if body.get_class() == "Player":
		(body as Player).hurt(self, 1);
		self.call_deferred("queue_free");
	self.call_deferred("queue_free");

func _physics_process(delta):
	if velocity.length() > 0.0:
		self.position += velocity*delta;

func fire_to_pos(origin: Vector2, destiny: Vector2):
	velocity = (destiny - origin).normalized()*speed;
	self.global_position = origin;
	global_spawn_pos = origin;
