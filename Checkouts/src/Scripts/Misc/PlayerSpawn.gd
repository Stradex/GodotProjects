extends Node2D

func _enter_tree():
	Game.SpawnPoints.append(self);

func _ready():
	self.visible = false;
