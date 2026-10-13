extends RefCounted
## Character stats. Every fighter shares the core moveset; only these numbers,
## the special, finisher and voice differ (specials and finishers come later).

const FIGHTERS := {
	"ronin_kage": {"name": "Ronin Kage", "hp": 100.0, "speed": 1.0, "damage": 1.0,
		"color": Color(0.72, 0.12, 0.10), "trim": Color(0.15, 0.08, 0.06)},
	"akane": {"name": "Akane", "hp": 95.0, "speed": 1.1, "damage": 0.95,
		"color": Color(0.16, 0.30, 0.78), "trim": Color(0.92, 0.88, 0.80)},
}
