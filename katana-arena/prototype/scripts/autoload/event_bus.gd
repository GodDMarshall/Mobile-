extends Node
## One place that gameplay announces what happened. The HUD, sound, announcer and
## camera listen here, so new systems (kill streaks, netcode) can plug in without touching combat code.

## result: "hit", "kill", "block", "parry", "guard_break", "armor", "evade", "throw"
signal attack_resolved(attacker: Node, defender: Node, move_name: String, result: String, damage: float)
signal hazard_hit(victim: Node, killed: bool)
signal fighter_killed(victim: Node, killer: Node, cause: String)
signal round_started(round_number: int)
signal fight_began
signal round_ended(winner: Node, reason: String)
signal match_ended(winner: Node)
