extends Node
## Entry point: menu -> duel -> results.
## Command-line options (after "--"), used for automated checks:
##   --combat-tests          run the scripted combat tests and quit
##   --autotest              play a full CPU vs CPU duel at high speed and quit
##   --screenshot=<path>     start a CPU duel, save a screenshot after a few seconds and quit
##   --menu-screenshot=<path> save a screenshot of the main menu and quit
##   --side-view / --touch   switch the camera to Classic side view / show touch controls

var _menu: MainMenu
var _match: DuelMatch
var _results: ResultsScreen
var _last_mode := "pvp"
var _args := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else ""
	if _args.has("side-view"):
		GameSettings.camera_mode = GameSettings.CameraMode.CLASSIC_SIDE
	if _args.has("touch"):
		GameSettings.force_touch_controls = true
	if _args.has("combat-tests"):
		var tests := CombatTests.new()
		add_child(tests)
		var failures: int = await tests.run_all(self)
		get_tree().quit(failures)
	elif _args.has("autotest"):
		Engine.time_scale = 8.0
		_start("demo")
		_match.finished.connect(func(r: Dictionary):
			print("AUTOTEST match finished: ", JSON.stringify(r))
			get_tree().quit(0 if r.rounds.size() >= 2 else 1))
	elif _args.has("screenshot"):
		_start(_args.get("mode", "demo") if _args.get("mode", "") != "" else "demo")
		_shoot_after(float(_args.get("delay", "4.5")), _args["screenshot"])
	elif _args.has("menu-screenshot"):
		_show_menu()
		_shoot_after(1.0, _args["menu-screenshot"])
	else:
		_show_menu()


func _shoot_after(seconds: float, path: String) -> void:
	await get_tree().create_timer(seconds).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("Saved screenshot to ", path)
	get_tree().quit()


func _show_menu() -> void:
	_clear()
	_menu = MainMenu.new()
	_menu.start_requested.connect(_start)
	add_child(_menu)


func _start(mode: String) -> void:
	_clear()
	_last_mode = mode
	_match = DuelMatch.new()
	add_child(_match)
	_match.setup({"mode": mode, "fighters": ["ronin_kage", "akane"], "seed": int(_args.get("seed", str(randi() % 100000)))})
	_match.finished.connect(_on_finished)


func _on_finished(result: Dictionary) -> void:
	if _args.has("autotest"):
		return
	_results = ResultsScreen.new()
	add_child(_results)
	_results.show_result(result)
	_results.rematch.connect(func(): _start(_last_mode))
	_results.back_to_menu.connect(_show_menu)


func _clear() -> void:
	for n in [_menu, _match, _results]:
		if n and is_instance_valid(n):
			remove_child(n)   # leave the tree now, so its cleanup can't touch the next screen
			n.queue_free()
	_menu = null
	_match = null
	_results = null
