extends FrontDoor

func _ready():
	$security.frame = self.security_level;
