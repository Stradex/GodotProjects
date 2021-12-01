extends ElevatorBase
onready var elev_door: Door = $Door;

func _ready():
	elev_door.unlock();

func move_to_pos(new_pos_index: int):
	if	(current_pos_index != next_pos_index) or (new_pos_index != current_pos_index):
		if elev_door:
			elev_door.lock();
	.move_to_pos(new_pos_index);

func next_pos_reached():
	.next_pos_reached();
	if elev_door:
		elev_door.unlock();
