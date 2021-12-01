class_name GUICanvas
extends CanvasLayer

func _ready():
	add_to_group("has_lang_strings");
	$Parent/DialogSystem.visible = false;
	$Parent/InfoMessages/InfoMessage.visible = false
	$Parent/MessageTimer.connect("timeout", self, "hide_message");
	
	update_lang_strings();

func hide_gui():
	$Parent.hide();

func show_gui():
	$Parent.show();

func update_lang_strings():
	$Parent/DialogSystem/HBoxContainer/Continue.text = Game.get_str("#str0101");

func _process(_delta):
	$Parent/CenterContainer/HBoxContainer/VBoxContainer/FPSLabel.text = "FPS: " + str(Engine.get_frames_per_second());

func hide_message():
	$Parent/DialogSystem/AnimationPlayer.play("hide_message");
	$Parent/MessageTimer.stop();

func display_message(message: String, time: float = 5.0):
	message = Game.get_str(message);
	$Parent/DialogSystem.show_message(message);

func show_pda_message(header: String, msg: String):
	$Parent/PDA/MarginContainer/Messsage/HBoxContainer/Header.text = Game.get_str(header);
	$Parent/PDA/MarginContainer/Messsage/HBoxContainer2/Message.text = Game.get_str(msg);
	$Parent/PDA.show();

func hide_pda():
	$Parent/PDA.hide();

func message_showed():
	$Parent/MessageTimer.start();

func message_hided():
	$Parent/DialogSystem.visible = false;

func update_health(new_health: int):
	$Parent/CenterContainer/HBoxContainer/VBoxContainer/Health.text = Game.get_str("#str0100") + ": " + str(new_health);

func info_message(msg: String, time: float = 5.0):
	$Parent/InfoMessages/InfoMessage.text = msg;
	$Parent/InfoMessagesAnims.play("info_message_show");
	$Parent/InfoMessages/InfoMessage.visible = true;
	var tween: Tween = $Parent/Tween;
	if tween.is_active():
		tween.remove(self, "info_message_hide");
	tween.interpolate_callback(self, time, "info_message_hide");
	tween.start();

func info_message_hide():
	$Parent/InfoMessagesAnims.play("info_message_hide");

func is_pda_open() -> bool:
	return $Parent/PDA.is_visible();

#func _input(_event):
#	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_cancel"):
#		hide_pda();

# TO AVOID CRASH IN RELEASE BUILD!
func _exit_tree():
	if Game.GUI == self:
		Game.GUI = null;
