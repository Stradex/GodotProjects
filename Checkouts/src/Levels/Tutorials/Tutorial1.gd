extends Level

func lock_door_1():
	$PlayerSpawn.global_position = $Points/Checkpoints/Checkpoint1.global_position;
	$Entities/Doors/Door.lock();
