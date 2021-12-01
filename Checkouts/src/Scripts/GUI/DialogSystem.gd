extends Control

var can_continue: bool = false;

func _ready():
	$HBoxContainer/ContinueButton.connect("pressed", self, "continue_pressed");

func show_message(msg: String):
	$AnimationPlayer.play("show_message");
	$Mensaje.text = msg;
	$HBoxContainer/ContinueButton.disabled = true;
	visible = true;
	can_continue = false;

func message_displayed():
	can_continue = true;
	$HBoxContainer/ContinueButton.disabled = false;

func pause_game():
	get_tree().paused = true

func resume_game():
	visible = false
	get_tree().paused = false
	can_continue = false

func continue_pressed():
	$AnimationPlayer.play("hide_message");

func _input(_event):
	if Input.is_action_just_pressed("ui_accept") && can_continue:
		continue_pressed();
