extends RefCounted
## Combat tuning. Everything is in fixed 60 Hz frames, metres and metres/second.
## Balance changes go here, not in the fighter code.

const GLOBALS := {
	"max_hp": 100.0,
	"max_stamina": 100.0,
	"stamina_regen": 0.45,       # per frame when not guarding, dashing or sprinting
	"guard_drain": 0.08,         # per frame while holding guard
	"block_stamina_mult": 2.5,   # stamina lost on block = damage * this
	"parry_window": 6,           # guard pressed this many frames before a hit = parry
	"parry_stun": 42,
	"guard_break_stun": 60,      # 1 s
	"combo_window": 4,           # frames to press two buttons "together"
	"walk_speed": 4.5,
	"sprint_speed": 7.5,
	"sprint_cost": 0.35,
	"guard_walk_speed": 1.6,
	"double_tap_frames": 15,
	"dash_frames": 14,
	"dash_invuln_start": 1,
	"dash_invuln_end": 10,
	"dash_speed": 13.0,
	"dash_cooldown": 36,
	"dash_cost": 18.0,
	"charge_frames": 22,         # hold heavy this long for the charged overhead
	"knock_friction": 20.0,
	"hazard_damage": 30.0,
	"hazard_knock_min": 2.5,     # knockback speed needed to get impaled on spikes
	"soft_lock_range": 6.0,
	"round_frames": 3600,        # 60 s rounds
	"rounds_to_win": 2,
}

# anim: which procedural swing the placeholder model plays.
# light: can chain and is beaten by armour. armor_vs_light: light hits don't interrupt it.
const MOVES := {
	"light1": {"startup": 6, "active": 3, "recovery": 11, "damage": 6.0, "range": 1.9, "arc": 120.0,
		"hitstun": 15, "blockstun": 9, "pushback": 1.6, "lunge": 1.6, "hitstop": 3,
		"light": true, "anim": "sweep_l", "sfx": "swing_light"},
	"light2": {"startup": 6, "active": 3, "recovery": 12, "damage": 6.0, "range": 1.9, "arc": 120.0,
		"hitstun": 15, "blockstun": 9, "pushback": 1.6, "lunge": 1.6, "hitstop": 3,
		"light": true, "anim": "sweep_r", "sfx": "swing_light"},
	"light3": {"startup": 7, "active": 4, "recovery": 18, "damage": 6.0, "range": 2.0, "arc": 90.0,
		"hitstun": 22, "blockstun": 11, "pushback": 3.5, "lunge": 2.4, "hitstop": 4,
		"light": true, "anim": "thrust", "sfx": "swing_light"},
	"heavy": {"startup": 15, "active": 4, "recovery": 22, "damage": 14.0, "range": 2.2, "arc": 110.0,
		"hitstun": 24, "blockstun": 14, "pushback": 3.0, "lunge": 2.0, "hitstop": 6,
		"armor_vs_light": true, "anim": "diagonal", "sfx": "swing_heavy"},
	"overhead": {"startup": 8, "active": 5, "recovery": 28, "damage": 25.0, "range": 2.4, "arc": 80.0,
		"hitstun": 34, "blockstun": 20, "pushback": 4.0, "lunge": 2.5, "hitstop": 9,
		"armor_vs_light": true, "anim": "overhead", "sfx": "swing_heavy"},
	"kick": {"startup": 6, "active": 3, "recovery": 15, "damage": 4.0, "range": 1.5, "arc": 90.0,
		"hitstun": 20, "blockstun": 12, "pushback": 7.0, "lunge": 1.0, "hitstop": 4,
		"anim": "kick", "sfx": "dash"},
	"special": {"startup": 9, "active": 5, "recovery": 26, "damage": 17.0, "range": 2.2, "arc": 140.0,
		"hitstun": 32, "blockstun": 16, "pushback": 3.5, "lunge": 4.0, "hitstop": 7,
		"stamina_cost": 25.0, "anim": "rising", "sfx": "swing_heavy"},
	"throw": {"startup": 4, "active": 2, "recovery": 24, "damage": 12.0, "range": 1.5, "arc": 100.0,
		"hitstun": 45, "pushback": 6.0, "lunge": 0.5, "hitstop": 6,
		"is_throw": true, "anim": "throw", "sfx": "dash"},
}
