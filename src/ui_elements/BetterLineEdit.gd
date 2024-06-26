## A LineEdit with a few tweaks to make it nicer to use.
@icon("res://visual/godot_only/BetterLineEdit.svg")
class_name BetterLineEdit extends LineEdit

signal text_change_canceled

const code_font = preload("res://visual/fonts/FontMono.ttf")
const ContextPopup = preload("res://src/ui_elements/context_popup.tscn")

var hovered := false

@export var code_font_tooltip := false  ## Use the mono font for the tooltip.

func _init() -> void:
	context_menu_enabled = false
	caret_blink = true
	caret_blink_interval = 0.6

func _ready() -> void:
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	mouse_exited.connect(_on_mouse_exited)
	text_submitted.connect(release_focus.unbind(1))

func _input(event: InputEvent) -> void:
	if has_focus() and event is InputEventMouseButton:
		if event.is_pressed() and not get_global_rect().has_point(event.position):
			release_focus()
			text_submitted.emit(text)
		elif event.is_released() and first_click and not has_selection():
			first_click = false
			select_all()

var tree_was_paused_before := false
var first_click := false
var text_before_focus := ""

func _on_focus_entered() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	tree_was_paused_before = get_tree().paused
	first_click = true
	text_before_focus = text
	if not tree_was_paused_before:
		get_tree().paused = true

func _on_focus_exited() -> void:
	process_mode = PROCESS_MODE_INHERIT
	first_click = false
	if not tree_was_paused_before:
		get_tree().paused = false
	if Input.is_action_pressed("ui_cancel"):
		text = text_before_focus
		text_change_canceled.emit()


func _on_mouse_exited() -> void:
	hovered = false
	queue_redraw()

func _draw() -> void:
	if editable and hovered and has_theme_stylebox("hover"):
		draw_style_box(get_theme_stylebox("hover"), Rect2(Vector2.ZERO, size))

func _make_custom_tooltip(for_text: String) -> Object:
	if code_font_tooltip:
		var label := Label.new()
		label.begin_bulk_theme_override()
		label.add_theme_font_override("font", code_font)
		label.add_theme_font_size_override("font_size", 13)
		label.end_bulk_theme_override()
		label.text = for_text
		return label
	else:
		return null


func _gui_input(event: InputEvent) -> void:
	mouse_filter = Utils.mouse_filter_pass_non_drag_events(event)
	
	if event is InputEventMouseMotion and event.button_mask == 0:
		hovered = true
		queue_redraw()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			grab_focus()
			var context_popup := ContextPopup.instantiate()
			var btn_arr: Array[Button] = []
			var separator_arr: Array[int] = []
			if editable:
				separator_arr = [2]
				btn_arr.append(Utils.create_btn(tr("Undo"),
						menu_option.bind(LineEdit.MENU_UNDO),
						false, load("res://visual/icons/Undo.svg")))
				btn_arr.append(Utils.create_btn(tr("Redo"),
						menu_option.bind(LineEdit.MENU_REDO),
						false, load("res://visual/icons/Redo.svg")))
				btn_arr.append(Utils.create_btn(tr("Cut"),
						menu_option.bind(LineEdit.MENU_CUT),
						text.is_empty(), load("res://visual/icons/Cut.svg")))
				btn_arr.append(Utils.create_btn(tr("Copy"),
						menu_option.bind(LineEdit.MENU_COPY),
						text.is_empty(), load("res://visual/icons/Copy.svg")))
				btn_arr.append(Utils.create_btn(tr("Paste"),
						menu_option.bind(LineEdit.MENU_PASTE),
						!DisplayServer.clipboard_has(), load("res://visual/icons/Paste.svg")))
			else:
				btn_arr.append(Utils.create_btn(tr("Copy"),
						menu_option.bind(LineEdit.MENU_COPY),
						text.is_empty(), load("res://visual/icons/Copy.svg")))
			
			add_child(context_popup)
			context_popup.setup(btn_arr, true, -1, separator_arr)
			var viewport := get_viewport()
			Utils.popup_under_pos(context_popup, viewport.get_mouse_position(), viewport)
			accept_event()
			# Wow, no way to find out the column of a given click? Okay...
			# TODO Make it so LineEdit caret automatically moves to the clicked position.
