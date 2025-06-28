extends Node3D

enum {TO_CAST, WAITING, HOOKED, CAUGHT, MISSED, RESET}
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

@export var progress_slow = 10
@export var progress_med = 5
@export var progress_fast = 1

@export var tension_slow = 0
@export var tension_med = 1
@export var tension_fast = 5

@export var target = 100
@export var max_wait = 256

@export var grace_period: int
var grace_timer = 0

@export var fish_list: Array[Fish]
var current_fish

var next_key
var last_key
var pivot


func _ready() -> void:
	random = RandomNumberGenerator.new()
	random.randomize()

func _process(delta: float) -> void:
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
			if randi() % current_fish.med_chance <= 1 and fish_state != MEDIUM:
				fish_state = MEDIUM
				print("fish changing to medium")
			elif randi() % current_fish.fast_chance <= 1 and fish_state != FAST:
				fish_state = FAST
				print("fish changing to fast")
			elif randi() % current_fish.slow_chance <= 1 and fish_state != SLOW:
				fish_state = SLOW
				print("fish changing to slow")
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
				tension -= 1
			
			if progress >= target:
				state = CAUGHT
			elif tension >= target or progress <= (target / -2):
				state = MISSED
			return
		CAUGHT:
			#display fish cutscene
			rod_animator.stop()
			animator.play("pull")
			print("you caught a " + current_fish.pretty_name)	
			state = RESET
			return
		MISSED:
			#display missed cutscene
			rod_animator.stop()
			animator.play("pull")
			print("you missed a " + current_fish.pretty_name)
			state = RESET
			return
		RESET:
			#reset all the stuff
			print("reset!")
			fish_state = MEDIUM
			progress = 0
			tension = 0
			state = TO_CAST
			return
			
