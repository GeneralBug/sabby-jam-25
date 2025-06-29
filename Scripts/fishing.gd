extends Node3D

enum {TO_CAST, WAITING, HOOKED, CAUGHT, MISSED, AWAITING, RESET}
var state = RESET
enum {SLOW, MEDIUM, FAST}
var fish_state = MEDIUM
var reeling = false

var progress = 0
var tension = 0

var timer = 0
var random

@export var animator: AnimationPlayer
@export var rod_animator: AnimationPlayer
@export var hud_animator: AnimationPlayer
@export var fish_animator: AnimationPlayer

@export var progress_slow = 10
@export var progress_med = 5
@export var progress_fast = 1

@export var tension_slow = 1
@export var tension_med = 5
@export var tension_fast = 10

@export var target = 100
@export var max_wait = 256

@export var grace_period: int
var grace_timer = 0

@export var fish_list: Array[Fish]
var current_fish

var next_key
var last_key
var pivot

@export var fish_ui_picture: TextureRect
@export var fish_ui_label: RichTextLabel
@export var fish_ui_size: RichTextLabel

var done_fisheye = false
var missed = false

@export var missed_picture: CompressedTexture2D
@export var missed_text: String

@export var bar_progress: TextureProgressBar
@export var bar_tension: TextureProgressBar

@export var fish_thoughts: Array[String]
@export var thought_bubble_text: RichTextLabel

@export var canvas: CanvasLayer

var format_string = "{size} cm"

func _ready() -> void:
	random = RandomNumberGenerator.new()
	random.randomize()
	fish_animator.play("fish shmovement")
	
	bar_progress.max_value = target
	bar_tension.max_value = target

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("fullscreen"):
		var mode := DisplayServer.window_get_mode()
		var is_window: bool = mode != DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if is_window else DisplayServer.WINDOW_MODE_WINDOWED)
	
	if Input.is_action_just_pressed("hide_ui"):
		canvas.visible = !canvas.visible
	
	if Input.is_action_pressed("quit_to_desktop"):
		get_tree().quit()
	
	bar_progress.value = float(progress)
	bar_tension.value = float(tension)
	
	match state:
		TO_CAST:
			print("waiting to cast!")
			#wait for cast, then change state to WAITING and start timer
			if Input.is_action_just_pressed("cast"):
				next_key = "action_left"
				last_key = "action_right"
				print("casting!")
				animator.play("casting")
				var passed = false
				while !passed:
					current_fish = fish_list[randi() % fish_list.size()]
					print("trying to make a " + current_fish.pretty_name)
					if (randi() % current_fish.rarity) <= 1:
						passed = true
				#TODO: PLAY CASTING ANIMATION
				print("picked " + current_fish.pretty_name + ", waiting...")
				timer = (randi() % max_wait) + 128
				state = WAITING
			return
		WAITING:
			#once timer is done, change to HOOKED
			timer -= 1
			if timer <= 0:
				print("hooked!")
				state = HOOKED
			return
		HOOKED:
			#first, check if player is reeling (pressing alternate button to last time)
			if Input.is_action_just_pressed(next_key):
				pivot = last_key
				last_key = next_key
				next_key = pivot
				reeling = true
				grace_timer = 0
				print("reeling, next key is " + next_key)
			else:
				grace_timer += 1
				if grace_timer >= grace_period:
					reeling = false
			#THEN, check fish state and change counters accordingly
			
			#TODO: this feels fucking nasty, please fix
			if current_fish.med_chance != -1 and randi() % current_fish.med_chance <= 1 and fish_state != MEDIUM:
				fish_state = MEDIUM
				print("fish changing to medium")
			elif current_fish.slow_chance != -1 and randi() % current_fish.slow_chance <= 1 and fish_state != SLOW:
				fish_state = SLOW
				print("fish changing to slow")
			elif current_fish.fast_chance != -1 and randi() % current_fish.fast_chance <= 1 and fish_state != FAST:
				fish_state = FAST
				print("fish changing to fast")

			rod_animator.play("rod_bob")
			match fish_state:
				SLOW:
					animator.play("slow_bobber")
					if reeling:
						progress += progress_slow
						tension += tension_slow
				MEDIUM:
					animator.play("med_bobber")
					if reeling:
						progress += progress_med
						tension += tension_med
				FAST:
					animator.play("fast_bobber")
					if reeling:
						progress += progress_fast
						tension += tension_fast
			if !reeling:
				progress -= 1
				tension -= 2
			
			if progress >= target:
				state = CAUGHT
			elif tension >= target or progress <= (target / -2):
				state = MISSED
			return
		CAUGHT:
			#display fish cutscene
			rod_animator.stop()
			animator.play("pull")
			var size = randf_range(0.01, 200.0)
			fish_ui_picture.texture = current_fish.picture
			fish_ui_label.text = current_fish.pretty_name
			print(size)
			fish_ui_size.text = format_string.format({"size":"%0.2f" % size})
			print(fish_ui_size.text)
			hud_animator.play("scroll down")
			
			print("you caught a " + current_fish.pretty_name)	
			state = AWAITING
			return
		MISSED:
			#display missed cutscene
			rod_animator.stop()
			animator.play("pull")
			print("you missed a " + current_fish.pretty_name)
			fish_ui_picture.texture = missed_picture
			fish_ui_label.text = missed_text
			fish_ui_size.text = ""
			hud_animator.play("scroll down")
			missed = true
			state = AWAITING
			return
		AWAITING:
			if Input.is_action_just_pressed("cast") && missed:
				hud_animator.play("scroll up")
				state = RESET
			elif Input.is_action_just_pressed("cast") && !done_fisheye:
				thought_bubble_text.text = fish_thoughts[randi() % fish_thoughts.size()]
				hud_animator.play("fisheye_enable")
				done_fisheye = true
			elif Input.is_action_just_pressed("cast") && done_fisheye:
				hud_animator.play("fisheye_disable")
				hud_animator.queue("scroll up")
				state = RESET
			return
		RESET:
			#reset all the stuff
			print("reset!")
			fish_state = MEDIUM
			progress = 0
			tension = 0
			missed = false
			done_fisheye = false
			state = TO_CAST
			return
