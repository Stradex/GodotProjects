extends Node2D

export var speed: float = 25.0;
export var segments: int = 2;
onready var SegmentScene: PackedScene = preload("res://src/Entities/Misc/Doors/misc/segment1.tscn");

var current_segment: int = 0;
var enabled: bool = false;
var segment_size: Vector2 = Vector2.ZERO;
onready var segments_node: Node2D = $segments;

func _ready():
	segment_size = 2.0*($segments/segment1/CollisionShape2D.shape.get_extents());
	for _i in range(1, segments):
		var segment_instance: Node2D = SegmentScene.instance();
		segments_node.call_deferred("add_child", segment_instance);

func enable() -> void:
	enabled = true;

func disable() -> void:
	enabled = false;

func _physics_process(delta):
	if !enabled or current_segment >= segments:
		return;

	if segments_node.position.y < segment_size.y*(current_segment+1):
		segments_node.position.y = clamp(segments_node.position.y + speed*delta, segments_node.position.y, segment_size.y*(current_segment+1)+0.001);
	else:
		current_segment+=1;
		if current_segment < segments:
			segments_node.get_children()[current_segment].position.y = -segments_node.position.y;
