extends ElevatorBase
onready var elev_door: Door = $Door;
onready var elev_door2: Door = $Door2;

export(Array, bool) var door1_unlock: Array; #if true, the door is unlocked when reached the floor in the array index.
export(Array, bool) var door2_unlock: Array; #if true, the door is unlocked when reached the floor in the array index.

func _ready():
	if door1_unlock[0]:
		elev_door.unlock();
	else:
		elev_door.lock();
	if door2_unlock[0]:
		elev_door2.unlock();
	else:
		elev_door2.lock();

func move_to_pos(new_pos_index: int):
	if	(current_pos_index != next_pos_index) or (new_pos_index != current_pos_index):
		elev_door.lock();
		elev_door2.lock();
	.move_to_pos(new_pos_index);

func next_pos_reached():
	.next_pos_reached();
	if door1_unlock[current_pos_index]:
		elev_door.unlock();
	else:
		elev_door.lock();
	if door2_unlock[current_pos_index]:
		elev_door2.unlock();
	else:
		elev_door2.lock();
