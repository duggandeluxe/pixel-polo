extends Node
## Headless checks and the screenshot harness. Exit code 1 on any failed check.
##   godot --headless --path game -- --test all
##   godot --headless --path game -- --test shots | possessions | matches
##   godot --headless --path game -- --test tutorial    (the tutorial, all four parts played through)
##   godot --headless --path game -- --test career_tutorial   (a new career's tutorial: pop-ups, SKIP, TRAINING COMPLETE; no Coaching Tips)
##   godot --headless --path game -- --test leadpass    (lead passes on the break: run onto it, never turn back)
##   godot --headless --path game -- --test star_fx     (HOT star animations, Developer Mode, the roster formation)
##   godot --headless --path game -- --test hot_reveal  (the postgame HOT star reveal and its Developer Mode preview)
##   godot --headless --path game -- --test tempo       (team skill: shot pace, one speed per shot, passing tempo)
##   godot --headless --path game -- --test attrs       (player attributes: ratings, gameplay, saves, upgrades)
##   godot --headless --path game -- --test progression (star steps, ten-box upgrades, dynamic classes, potential)
##   godot --headless --path game -- --test development (XP, hidden levels, tokens, training, injuries, AI, saves)
##   godot --headless --path game -- --test xp_update   (XP Development Update 2.0: no cap, class XP, stats, mandatory upgrades)
##   godot --headless --path game -- --test coaching    (Coaching: gameplan, scouting, top targets, PRESS + your drop, the halftime adjustment)
##   godot --headless --path game -- --test glory   (the Road to Glory: school cards, tiers, achievements, the profile)
##   godot --path game -- --test glory_png <outdir>   (its screens, and the layouts at four screen shapes)
##   godot --path game -- --test coaching_png <outdir>  (Coaching, scouting, the two-button bar, halftime, the adjustment)
##   godot --headless --path game -- --test dev_balance [seasons] (the development season simulation report)
##   godot --headless --path game -- --test team_ovr (2.0 team overall, first rosters from the original OVR)
##   godot --headless --path game -- --test hot_card    (HOT stars everywhere alike, the card flip, momentum, the HOT tip)
##   godot --headless --path game -- --test keeper_timing (stars in the in-game tag, the keeper's timed dive, low / high shots)
##   godot --headless --path game -- --test goal_show   (a goal's show: stages, scorer, board, clock, skip, stats once)
##   godot --headless --path game -- --test bar_hit     (BAR-IN! / BAR-DOWN!: the pick, the share, the ricochet, counted once)
##   godot --headless --path game -- --test ai          (the AI keeper's dives, centre play, difficulty as decisions, DYNAMIC)
##   godot --headless --path game -- --test ai_balance [n] (the balancing numbers: keeper, centre, difficulty)
##   godot --headless --path game -- --test keeper_overhaul (keeper anticipation, reaction, panic recovery; the first pass into the centre)
##   godot --headless --path game -- --test keeper_overhaul_balance [n] (bot matches: their keeper's reactions, first-pass centre entries)
##   godot --headless --path game -- --test keeper_measure [n] (their keeper's save rates by range, placement, pace, hold, reaction)
##   godot --path game -- --test ai_keeper_png <outdir>  (their keeper on your shots: his lean, a reaction dive, a panic)
##   godot --headless --path game -- --test man_down    (the 6 on 5 zone: lanes, stepping out, shifting as a unit)
##   godot --headless --path game -- --test formations  (the five defensive formations, pressing, fouls, tips, the dropper, the bar)
##   godot --headless --path game -- --test piston      (piston pressure, the one-arm block and red X, penalties from behind, the dev labs)
##   godot --headless --path game -- --test shot_stick (the shooting stick: mapping, the slingshot's shot, touches)
##   godot --path game -- --test shot_stick_png <outdir> (the stick at rest, pulled, after the shot)
##   godot --path game -- --test piston_png <outdir>    (the DEFENSIVE TESTING and SPECIAL GOAL EFFECTS labs at their moments)
##   godot --headless --path game -- --test formation_balance [n] (their attack against each of your formations)
##   godot --headless --path game -- --test formation_trace <formation 0-4> [n] (developer: possessions traced line by line)
##   godot --path game -- --test formation_png <outdir>  (the formation bar, each formation, their call on your attack)
##   godot --path game -- --test shots_png <outdir>      (screenshots, needs a window)
##   godot --path game -- --test goal_png <outdir>       (a goal going in at each end, the quarter card)
##   godot --path game -- --test penalty_png <outdir>    (the 5 m formation, the shootout, their keeper's guess)
##   godot --path game -- --test keeper_png <outdir>     (your keeper: tracking, both lunges, the block, a corner save)

var failures := 0
var checks := 0

func run(args: Array) -> void:
	var mode: String = args[0] if args.size() > 0 else "all"
	# (the suites stage formations by hand; the foul a real call makes first is --test refinement's,
	# and refine_measure's and the bot matches' own)
	Play.instant_drops = not mode in ["refine_measure", "defense_ai_balance", "formation_balance"]
	match mode:
		"shots":
			test_shots()
		"possessions":
			test_possessions()
		"matches":
			test_matches()
		"aim":
			test_aim()
			test_shot_line()
			await test_calls()
		"sprint":
			test_sprint()
		"defense":
			test_defense()
		"traits":
			test_traits()
		"compile":
			test_compile("res://src")
		"duel":
			test_duel()
			test_home_dive()
		"penalties":
			test_penalties()
			test_keeper_dive()
		"breakout":
			test_breakout()
		"centre":
			test_center()
		"rules":
			load("res://tests/rules_test.gd").new().run(self)
		"update":
			load("res://tests/update_test.gd").new().run(self)
		"leadpass":
			load("res://tests/lead_pass_test.gd").new().run(self)
		"counter":
			load("res://tests/counter_test.gd").new().run(self)
		"tutorial":
			await load("res://tests/tutorial_test.gd").new().run(self)
		"career_tutorial":
			await load("res://tests/career_tutorial_test.gd").new().run(self)
		"formation":
			test_formation()
		"blocks":
			test_blocks()
			test_guard()
		"banners":
			await test_banners()
		"clock":
			await test_clock()
		"results":
			await test_results()
		"summary":
			await test_summary()
		"profile":
			await test_profile()
		"moments":
			test_moments()
		"gameplay":
			test_gameplay()
		"career":
			test_career(int(args[1]) if args.size() > 1 else 3)
		"balance":
			load("res://tests/balance.gd").new().run(self, int(args[1]) if args.size() > 1 else 6)
		"form":
			await load("res://tests/form_test.gd").new().run(self)
		"attrs":
			await load("res://tests/attr_test.gd").new().run(self)
		"progression":
			await load("res://tests/progression_test.gd").new().run(self)
		"development":
			await load("res://tests/development_test.gd").new().run(self)
		"xp_update":
			await load("res://tests/xp_update_test.gd").new().run(self)
		"coaching":
			await load("res://tests/coaching_test.gd").new().run(self)
		"glory":
			await load("res://tests/glory_test.gd").new().run(self)
		"ratings":
			await load("res://tests/roster_ratings_test.gd").new().run(self)
		"postgame":
			await load("res://tests/postgame_test.gd").new().run(self)
		"fouls":
			await load("res://tests/fouls_test.gd").new().run(self)
		"division_measure":
			load("res://tests/division_measure.gd").new().run(self)
		"division_png":
			await load("res://tests/division_shots.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"divisions":
			await load("res://tests/division_test.gd").new().run(self)
		"record_book_expansion_gen":
			load("res://tests/record_book_expansion_gen.gd").new().run(self)
		"record_book_gen":
			load("res://tests/record_book_gen.gd").new().run(self)
		"refinement":
			await load("res://tests/refinement_test.gd").new().run(self)
		"refine_measure":
			await load("res://tests/refinement_measure.gd").new().run(self, int(args[1]) if args.size() > 1 else 200)
		"sim_parity":
			await load("res://tests/sim_parity_test.gd").new().run(self)
		"rollout":
			load("res://tests/rollout_test.gd").new().run(self)
		"red_x":
			load("res://tests/red_x_test.gd").new().run(self)
		"wing_lob":
			load("res://tests/wing_lob_test.gd").new().run(self)
		"center_rebound":
			load("res://tests/center_rebound_test.gd").new().run(self)
		"man_down":
			load("res://tests/man_down_zone_test.gd").new().run(self)
		"hibernation_png":
			await load("res://tests/hibernation_shots.gd").run(self, args[1] if args.size() > 1 else "/tmp")
		"man_up_png":
			await load("res://tests/man_up_cam_shots.gd").run(self, args[1] if args.size() > 1 else "/tmp")
		"all_teams":
			await load("res://tests/all_teams_test.gd").new().run(self)
		"school_cards":
			await load("res://tests/school_cards_test.gd").new().run(self)
		"school_cards_png":
			await load("res://tests/school_cards_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"conf_rebrand":
			await load("res://tests/conference_rebrand_test.gd").new().run(self)
		"season_path":
			await load("res://tests/season_path_test.gd").new().run(self)
		"season_path_png":
			await load("res://tests/season_path_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"reset":
			await load("res://tests/reset_test.gd").new().run(self)
		"standings_board":
			await load("res://tests/standings_board_test.gd").new().run(self)
		"standings_board_png":
			await load("res://tests/standings_board_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"shot_power":
			load("res://tests/shot_power_test.gd").new().run(self)
		"shot_trail_png":
			await load("res://tests/shot_power_test.gd").trail_shots(self, args[1] if args.size() > 1 else "/tmp")
		"postgame_png":
			await load("res://tests/postgame_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"glory_png":
			await load("res://tests/glory_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"coaching_png":
			await load("res://tests/coaching_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"xp_update_png":
			await load("res://tests/xp_update_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"dev_png":
			await load("res://tests/development_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"xp_maturity":
			load("res://tests/xp_maturity_test.gd").new().run(self)
		"dev_career":
			load("res://tests/dev_career_test.gd").report(self, int(args[1]) if args.size() > 1 else 5, int(args[2]) if args.size() > 2 else 4040)
		"live_xp":
			load("res://tests/live_xp_probe.gd").report(self, int(args[1]) if args.size() > 1 else 12)
		"dev_balance":
			load("res://tests/development_test.gd").balance(self, int(args[1]) if args.size() > 1 else 1)
		"team_ovr":
			await load("res://tests/team_ovr_test.gd").new().run(self)
		"hot_card":
			await load("res://tests/hot_card_test.gd").new().run(self)
		"roster_visual":
			await load("res://tests/roster_visual_test.gd").new().run(self)
		"ai":
			load("res://tests/ai_overhaul_test.gd").new().run(self)
		"formations":
			await load("res://tests/formation_test.gd").new().run(self)
		"piston":
			await load("res://tests/piston_test.gd").new().run(self)
		"shot_stick":
			await load("res://tests/shot_stick_test.gd").new().run(self)
		"goalie_tweaks":
			await load("res://tests/goalie_tweaks_test.gd").new().run(self)
		"goalie_tweaks_png":
			await load("res://tests/goalie_tweaks_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"shot_stick_png":
			await load("res://tests/shot_stick_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"piston_png":
			await load("res://tests/piston_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"formation_png":
			await load("res://tests/formation_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"formation_trace":
			load("res://tests/formation_test.gd").trace(self, int(args[1]), int(args[2]) if args.size() > 2 else 4)
		"formation_balance":
			load("res://tests/formation_test.gd").balance(self, int(args[1]) if args.size() > 1 else 200)
		"ai_balance":
			Difficulty.cpu_neutral = "nocpu" in args
			load("res://tests/ai_overhaul_test.gd").balance(self, int(args[1]) if args.size() > 1 else 8)
		"defense_ai_balance":
			load("res://tests/defense_measure.gd").report(self, int(args[1]) if args.size() > 1 else 12, args.size() > 2 and args[2] == "both")
		"keeper_overhaul":
			load("res://tests/keeper_overhaul_test.gd").new().run(self)
		"defense_ai":
			load("res://tests/defense_ai_test.gd").new().run(self)
		"keeper_overhaul_balance":
			load("res://tests/keeper_overhaul_test.gd").balance(self, int(args[1]) if args.size() > 1 else 8)
		"keeper_measure":
			load("res://tests/keeper_measure.gd").report(self, int(args[1]) if args.size() > 1 else 20000)
		"keeper_timing":
			load("res://tests/keeper_timing_test.gd").new().run(self)
		"shot_height":
			var m: Dictionary = load("res://tests/keeper_timing_test.gd").measure(int(args[1]) if args.size() > 1 else 24000)
			print("shot height: their keeper %s, your keeper %s (all %.3f)" % [str(m.ai), str(m.duel), m.duel_all])
		"star_fx":
			await load("res://tests/star_fx_test.gd").new().run(self)
		"hot_reveal":
			await load("res://tests/hot_reveal_test.gd").new().run(self)
		"goal_show":
			await load("res://tests/goal_show_test.gd").new().run(self)
		"goal_show_png":
			await load("res://tests/goal_show_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"bar_hit":
			await load("res://tests/bar_hit_test.gd").new().run(self)
		"bar_hit_png":
			await load("res://tests/bar_hit_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"shot_clock_png":
			await load("res://tests/shot_clock_shots.gd").run(self, args[1] if args.size() > 1 else "/tmp")
		"callout_png":
			await load("res://tests/callout_shots.gd").run(self, args[1] if args.size() > 1 else "/tmp")
		"tempo":
			load("res://tests/tempo_test.gd").new().run(self)
		"tempo_png":
			await load("res://tests/tempo_shots.gd").run(self, args[1] if args.size() > 1 else "/tmp")
		"form_calibrate":
			load("res://tests/form_calibrate.gd").new().run(self, int(args[1]) if args.size() > 1 else 40, int(args[2]) if args.size() > 2 else 0)
		"conf_awards":
			await load("res://tests/conf_awards_test.gd").new().run(self)
		"conf_awards_png":
			await load("res://tests/conf_awards_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"sim_stats":
			load("res://tests/sim_stats_test.gd").new().run(self)
		"sim_stats_measure":
			var m: Dictionary = load("res://tests/sim_stats_test.gd").measure(self, int(args[1]) if args.size() > 1 else 20)
			print("per side, played [to, st, ex, ed]: %s   simulated: %s   top scorer's share: %.3f, of a season: %.3f" % [str(m.played), str(m.simmed), float(m.top_share), float(m.season_share)])
		"dynasty_hub":
			await load("res://tests/dynasty_hub_test.gd").new().run(self)
		"star_display":
			await load("res://tests/star_display_test.gd").new().run(self)
		"roster_current":
			await load("res://tests/roster_current_test.gd").new().run(self)
		"hot_stars":
			await load("res://tests/hot_stars_test.gd").new().run(self)
		"economy":
			await load("res://tests/economy_test.gd").new().run(self)
		"hot_balance":
			await load("res://tests/hot_balance_test.gd").new().run(self)
		"visual_shop":
			await load("res://tests/visual_shop_test.gd").new().run(self)
		"starting_seven":
			await load("res://tests/starting_seven_test.gd").new().run(self)
		"starting_seven_png":
			await load("res://tests/starting_seven_shots.gd").run(self, args[1] if args.size() > 1 else "/tmp")
		"fine_logos":
			await load("res://tests/fine_logos_test.gd").new().run(self)
		"fine_logos_png":
			await load("res://tests/fine_logos_shots.gd").run(self, args[1] if args.size() > 1 else "/tmp")
		"replay":
			await load("res://tests/replay_test.gd").new().run(self)
		"goal_crowd":
			await load("res://tests/goal_crowd_test.gd").new().run(self)
		"stage4":
			await load("res://tests/stage4_test.gd").new().run(self)
		"stage4_png":
			await load("res://tests/stage4_shots.gd").run(self, args[1] if args.size() > 1 else "/tmp")
		"goal_crowd_png":
			await load("res://tests/goal_crowd_shots.gd").run(self, args[1] if args.size() > 1 else "/tmp")
		"replay_png":
			await load("res://tests/replay_shots.gd").run(self, args[1] if args.size() > 1 else "/tmp")
		"shop_png":
			await load("res://tests/shop_shots.gd").run(self, args[1] if args.size() > 1 else "/tmp")
		"pregame":
			await load("res://tests/pregame_test.gd").new().run(self)
		"pregame_png":
			await load("res://tests/pregame_shots.gd").run(self, args[1] if args.size() > 1 else "/tmp")
		"hot_balance_measure":
			Store.reset_for_tests()
			var mults: Array = [1.0, PlayerForm.HOT_STAR_ACQUISITION_MULTIPLIER] if args.size() < 3 else Array(String(args[2]).split(",")).map(func(x): return float(x))
			load("res://tests/hot_balance_test.gd").new().measure(int(args[1]) if args.size() > 1 else 2, mults, [811, 812, 813, 814])
		"hot_stars_png":
			await load("res://tests/hot_stars_shots.gd").run(self, args[1] if args.size() > 1 else "/tmp")
		"long_term_dev":
			load("res://tests/long_term_dev_test.gd").new().run(self)
		"positions":
			await load("res://tests/positions_test.gd").new().run(self)
		"positions_png":
			await load("res://tests/positions_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"legacy_png":
			await load("res://tests/legacy_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"coach_stakes":
			await load("res://tests/coach_stakes_test.gd").new().run(self)
		"coach_stakes_png":
			await load("res://tests/coach_stakes_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"weekly_show":
			await load("res://tests/weekly_show_test.gd").new().run(self)
		"weekly_show_png":
			await load("res://tests/weekly_show_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"ncsa_preview":
			load("res://tests/ncsa_preview_test.gd").new().run(self)
		"ncsa_preview_png":
			await load("res://tests/ncsa_preview_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"team_trophies":
			await load("res://tests/team_trophy_test.gd").new().run(self)
		"team_trophies_png":
			await load("res://tests/team_trophy_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"legacy":
			await load("res://tests/legacy_test.gd").new().run(self)
		"title_png":
			await load("res://tests/title_shots.gd").run(self, args[1] if args.size() > 1 else "/tmp")
		"roster_needs_png":
			await load("res://tests/roster_needs_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"roster_needs":
			await load("res://tests/roster_needs_test.gd").new().run(self)
		"settings":
			await load("res://tests/settings_test.gd").new().run(self)
		"settings_png":
			await load("res://tests/settings_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"challenge_show":
			await load("res://tests/challenge_show_test.gd").new().run(self)
		"challenge_show_png":
			await load("res://tests/challenge_show_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"challenge_lab":
			await load("res://tests/challenge_lab_test.gd").new().run(self)
		"challenge_lab_png":
			await load("res://tests/challenge_lab_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"title_fit":
			await load("res://tests/title_fit_test.gd").new().run(self)
		"title_fit_png":
			await load("res://tests/title_fit_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"recruit_cards":
			await load("res://tests/recruit_cards_test.gd").new().run(self)
		"recruit_cards_png":
			await load("res://tests/recruit_cards_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"coach_lab":
			await load("res://tests/coach_lab_test.gd").new().run(self)
		"coach_lab_png":
			await load("res://tests/coach_lab_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"record_lab":
			await load("res://tests/record_lab_test.gd").new().run(self)
		"record_lab_png":
			await load("res://tests/record_lab_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"difficulty_balance":
			load("res://tests/difficulty_balance_test.gd").new().run(self)
		"coaching_events_png":
			await load("res://tests/coaching_events_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"coaching_events":
			await load("res://tests/coaching_events_test.gd").new().run(self)
		"trophy_nav":
			await load("res://tests/trophy_nav_test.gd").run(self)
		"trophy_png":
			await load("res://tests/trophy_shots.gd").run(self, args[1] if args.size() > 1 else "/tmp")
		"national_awards":
			load("res://tests/national_awards_test.gd").new().run(self)
		"national_measure":
			load("res://tests/national_measure.gd").report(self, int(args[1]) if args.size() > 1 else 2, int(args[2]) if args.size() > 2 else 61)
		"weekly_awards":
			load("res://tests/weekly_awards_test.gd").new().run(self)
		"conf_awards_measure":
			load("res://tests/award_measure.gd").report(self, int(args[1]) if args.size() > 1 else 3, int(args[2]) if args.size() > 2 else 61)
		"hometowns":
			await load("res://tests/hometown_test.gd").new().run(self)
		"accolades":
			await load("res://tests/accolades_test.gd").new().run(self)
		"bracket":
			await load("res://tests/bracket_test.gd").new().run(self)
		"bracket_png":
			await load("res://tests/bracket_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"records_png":
			await load("res://tests/dynasty_hub_test.gd").records_shots(self, args[1] if args.size() > 1 else "/tmp")
		"dynasty_hub_png":
			await load("res://tests/dynasty_hub_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"bench":
			load("res://tests/bench_test.gd").new().run(self)
		"home_waters":
			await load("res://tests/home_waters_test.gd").new().run(self)
		"home_waters_png":
			await load("res://tests/home_waters_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"portraits":
			load("res://tests/portrait_test.gd").new().run(self)
		"portraits_png":
			await load("res://tests/portrait_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"recruiting", "credit_economy":
			await load("res://tests/credit_economy_test.gd").new().run(self)
		"engine":
			await load("res://tests/engine_test.gd").new().run(self, int(args[1]) if args.size() > 1 else 20000)
		"names":
			await load("res://tests/team_names_test.gd").new().run(self)
		"teams":
			test_teams()
			test_season()
			test_postseason()
			await test_picker_ovr()
			test_ovr_effect()
			await test_realign()
		"screens":
			await test_screens()
		"slots":
			await test_slots()
		"mp":
			await test_mp(args.slice(1))
		"form_png":
			await load("res://tests/form_shots.gd").run(self, args[1] if args.size() > 1 else "/tmp")
		"star_fx_png":
			await load("res://tests/star_fx_shots.gd").run(self, args[1] if args.size() > 1 else "/tmp")
		"hot_reveal_png":
			await load("res://tests/hot_reveal_shots.gd").run(self, args[1] if args.size() > 1 else "/tmp")
		"attr_png":
			await load("res://tests/attr_shots.gd").run(self, args[1] if args.size() > 1 else "/tmp")
		"roster_png":
			await load("res://tests/roster_shots.gd").run(self, args[1] if args.size() > 1 else "/tmp")
		"career_png":
			await load("res://tests/career_shots.gd").run(self, args[1] if args.size() > 1 else "/tmp")
		"recruiting_png", "credit_economy_png":
			await load("res://tests/credit_economy_test.gd").shots(self, args[1] if args.size() > 1 else "/tmp")
		"tutorial_png":
			await load("res://tests/tutorial_shots.gd").run(self, args[1] if args.size() > 1 else "/tmp")
		"slots_png":
			await load("res://tests/slot_shots.gd").run(self, args[1] if args.size() > 1 else "/tmp")
		"profile_png":
			await load("res://tests/profile_shots.gd").run(self, args[1] if args.size() > 1 else "/tmp")
		"shots_png":
			await load("res://tests/shot_harness.gd").run(self, args[1] if args.size() > 1 else "/tmp", args.slice(2))
		"goal_png":
			await load("res://tests/goal_shots.gd").run(self, args[1] if args.size() > 1 else "/tmp")
		"penalty_png":
			await load("res://tests/penalty_shots.gd").run(self, args[1] if args.size() > 1 else "/tmp")
		"ai_keeper_png":
			await load("res://tests/ai_keeper_shots.gd").run(self, args[1] if args.size() > 1 else "/tmp")
		"keeper_png":
			await load("res://tests/keeper_shots.gd").run(self, args[1] if args.size() > 1 else "/tmp")
		"stats":
			load("res://tests/match_stats.gd").new().run(self, int(args[1]) if args.size() > 1 else 60)
		"offense":
			if args.size() > 1:
				load("res://tests/offense_stats.gd").new().run(self, int(args[1]), false, float(args[2]) if args.size() > 2 else Difficulty.MEDIUM)
			else:
				test_offense()
		_:
			test_compile("res://src")
			test_shots()
			test_possessions()
			load("res://tests/tempo_test.gd").new().run(self)
			test_aim()
			test_shot_line()
			await test_calls()
			test_sprint()
			test_defense()
			test_offense()
			test_blocks()
			test_guard()
			test_traits()
			test_matches()
			test_gameplay()
			await test_clock()
			test_duel()
			test_penalties()
			test_breakout()
			test_center()
			load("res://tests/rules_test.gd").new().run(self)
			load("res://tests/update_test.gd").new().run(self)
			test_formation()
			test_keeper_dive()
			test_home_dive()
			test_career(2)
			await load("res://tests/credit_economy_test.gd").new().run(self)
			load("res://tests/portrait_test.gd").new().run(self)
			await load("res://tests/home_waters_test.gd").new().run(self)
			load("res://tests/bench_test.gd").new().run(self)
			await load("res://tests/dynasty_hub_test.gd").new().run(self)
			await load("res://tests/star_display_test.gd").new().run(self)
			await load("res://tests/roster_current_test.gd").new().run(self)
			await load("res://tests/hot_stars_test.gd").new().run(self)
			await load("res://tests/economy_test.gd").new().run(self)
			await load("res://tests/refinement_test.gd").new().run(self)
			await load("res://tests/hot_balance_test.gd").new().run(self)
			await load("res://tests/pregame_test.gd").new().run(self)
			await load("res://tests/visual_shop_test.gd").new().run(self)
			await load("res://tests/fine_logos_test.gd").new().run(self)
			await load("res://tests/starting_seven_test.gd").new().run(self)
			await load("res://tests/replay_test.gd").new().run(self)
			await load("res://tests/goal_crowd_test.gd").new().run(self)
			await load("res://tests/stage4_test.gd").new().run(self)
			load("res://tests/long_term_dev_test.gd").new().run(self)
			await load("res://tests/positions_test.gd").new().run(self)
			await load("res://tests/conf_awards_test.gd").new().run(self)
			test_teams()
			await load("res://tests/team_names_test.gd").new().run(self)
			test_season()
			test_postseason()
			await test_picker_ovr()
			test_ovr_effect()
			await test_realign()
			await load("res://tests/engine_test.gd").new().run(self)
			await load("res://tests/form_test.gd").new().run(self)
			await load("res://tests/attr_test.gd").new().run(self)
			await load("res://tests/progression_test.gd").new().run(self)
			await load("res://tests/development_test.gd").new().run(self)
			await load("res://tests/xp_update_test.gd").new().run(self)
			await load("res://tests/coaching_test.gd").new().run(self)
			await load("res://tests/glory_test.gd").new().run(self)
			await load("res://tests/roster_ratings_test.gd").new().run(self)
			await load("res://tests/postgame_test.gd").new().run(self)
			await load("res://tests/fouls_test.gd").new().run(self)
			await load("res://tests/sim_parity_test.gd").new().run(self)
			load("res://tests/rollout_test.gd").new().run(self)
			await load("res://tests/all_teams_test.gd").new().run(self)
			await load("res://tests/team_ovr_test.gd").new().run(self)
			await load("res://tests/star_fx_test.gd").new().run(self)
			await load("res://tests/hot_card_test.gd").new().run(self)
			await load("res://tests/roster_visual_test.gd").new().run(self)
			await load("res://tests/hot_reveal_test.gd").new().run(self)
			load("res://tests/keeper_timing_test.gd").new().run(self)
			await test_screens()
			await test_slots()
			await test_banners()
			await load("res://tests/goal_show_test.gd").new().run(self)
			await load("res://tests/bar_hit_test.gd").new().run(self)
			await test_results()
			await test_summary()
			await test_profile()
			test_moments()
			load("res://tests/lead_pass_test.gd").new().run(self)
			load("res://tests/counter_test.gd").new().run(self)
			await load("res://tests/tutorial_test.gd").new().run(self)
			await load("res://tests/career_tutorial_test.gd").new().run(self)
			load("res://tests/ai_overhaul_test.gd").new().run(self)
			load("res://tests/keeper_overhaul_test.gd").new().run(self)
			await load("res://tests/formation_test.gd").new().run(self)
			await load("res://tests/piston_test.gd").new().run(self)
			await load("res://tests/shot_stick_test.gd").new().run(self)
			await load("res://tests/goalie_tweaks_test.gd").new().run(self)
			load("res://tests/defense_ai_test.gd").new().run(self)
	print("\n%d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

# ------------------------------------------------------------------ formation discipline
## The settled attack keeps its shape: every man off the ball stays near his spot, a release
## is short (PlayAI.RELEASE_MAX) and one man at a time, and he comes back to his spot after it.
## Counters and the breakout aren't held to it. Both attacks: theirs (OffenseAI) and yours.
func test_formation() -> void:
	print("formation discipline")
	var teams := _teams()
	var worst_hold := 0.0      # a man neither releasing nor chasing: furthest off his spot
	var worst_release := 0.0   # a man on a release: furthest off his spot
	var releases := 0
	var together := 0          # frames with two off-ball men releasing at once
	var settled := 0.0
	var back := 0
	var ended := 0
	for i in 16:
		var f := MatchFlow.new(teams[0], teams[1], 900 + i, MatchState.QUARTER_MIN)
		var theirs := i % 2 == 0
		if theirs:
			f._start_defense(Play.Kind.HALF_COURT)
			f.auto_keeper = 0.5
		else:
			f._start_attack(Play.Kind.HALF_COURT)
		var p := f.play
		var was := {}
		var off_at_end := {}
		var arrived := {}   # (a man still swimming in from the set-up hasn't got a spot to hold yet)
		var t := 0.0
		while not p.over and t < 25.0:
			if theirs:
				f.tick_defense(1.0 / 30.0)
			else:
				f.tick_attack(1.0 / 30.0)
			t += 1.0 / 30.0
			if p.over or p.carry or p.breakout or p.counter_t > 0.0 or p.man_up > 0.0 or t < 2.0:
				continue
			settled += 1.0 / 30.0
			var on := 0
			for a: Swimmer in p.attackers:
				if a.out or a.tag == "C" or a == p.holder:
					continue
				var d := a.pos.distance_to(a.home)
				if d < PlayAI.SPOT_MAX + 0.3:
					arrived[a] = true
				var busy := (p.ball.state == Ball.State.PASS and a == p.ball.receiver) or p.ball.state == Ball.State.LOOSE \
					or p.ball.state == Ball.State.SHOT or a.called > 0.0 or not arrived.has(a)
				if a.drive_t > 0.0:
					on += 1
					worst_release = maxf(worst_release, d)
					if not was.get(a, false):
						releases += 1
					off_at_end[a] = 1.5   # watch him for 1.5 s after it
				elif off_at_end.has(a):
					off_at_end[a] -= 1.0 / 30.0
					if off_at_end[a] <= 0.0:
						off_at_end.erase(a)
						ended += 1
						if d < PlayAI.SPOT_MAX + 0.5:
							back += 1
				elif not busy:
					worst_hold = maxf(worst_hold, d)
				was[a] = a.drive_t > 0.0
			if on > 1:
				together += 1
	print("  %.0f s settled: %d releases, off-ball men up to %.2f m off their spots, releasing up to %.2f m, back on the spot after %d/%d"
		% [settled, releases, worst_hold, worst_release, back, ended])
	check(releases > 0, "the attack makes releases")
	check(releases / settled < 1.0 / 3.0, "releases are occasional (one per %.1f s)" % (settled / maxf(releases, 1)))
	check(worst_release <= PlayAI.RELEASE_MAX + 0.6, "a release is short (%.2f m)" % worst_release)
	check(worst_hold <= PlayAI.SPOT_MAX + 1.2, "off-ball men hold their spots (%.2f m)" % worst_hold)
	check(together == 0, "one release at a time (%d frames with two)" % together)
	check(ended > 0 and back >= ended * 0.8, "after a release he's back on his spot (%d/%d)" % [back, ended])
	# the spots stay apart: no two men's spots (and so no two men holding them) crowd each other
	var homes := PlaySetup.HOME_6V6.values()
	var closest := INF
	for a in homes.size():
		for b in range(a + 1, homes.size()):
			closest = minf(closest, (homes[a] as Vector2).distance_to(homes[b]))
	check(closest - 2.0 * PlayAI.SPOT_MAX > 1.0, "spots far enough apart that men holding them never crowd (%.1f m)" % closest)
	# a release is cut short at RELEASE_MAX
	var g := MatchFlow.new(teams[0], teams[1], 950, MatchState.QUARTER_MIN)
	g._start_attack(Play.Kind.HALF_COURT)
	var two := PlaySetup._by_tag(g.play, "2")
	check(PlayAI.release_to(two, Geo.goal_center()).distance_to(two.home) <= PlayAI.RELEASE_MAX + 1e-4, "a release towards the goal stops RELEASE_MAX off his spot")

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("  FAIL: " + what)

func check_between(v: float, lo: float, hi: float, what: String) -> void:
	check(v >= lo and v <= hi, "%s = %.3f, expected %.2f..%.2f" % [what, v, lo, hi])

## Loads every script with the autoloads present, so a parse error fails the run.
func test_compile(dir: String) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			var scr: Script = load(dir + "/" + f)
			check(scr != null and scr.can_instantiate(), "script compiles: " + dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		test_compile(dir + "/" + d)

# ------------------------------------------------------------------ shot model
func _goal_rate(from: Vector2, aim_y: float, pressure: float, keeper_y: float, penalty := false, ctx := {}) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var goals := 0
	var n := 3000
	for i in n:
		var r := ShotModel.resolve(from, aim_y, 0.8, 65.0, pressure, [] as Array[Vector2], keeper_y, 62.0, rng, penalty, {}, ctx)
		if r.outcome == "goal":
			goals += 1
	return goals / float(n)

func test_shots() -> void:
	print("shot model")
	# (since the keeper overhaul their keeper reacts to the ball once he's seen it (KeeperAI): from 5 m
	# a corner is mostly in before he can get there, one straight at him is mostly his)
	check_between(_goal_rate(Vector2(25, 10), 11.2, 5.0, 10.0), 0.55, 0.92, "open 5 m, corner")
	check_between(_goal_rate(Vector2(25, 10), 10.1, 5.0, 10.0, false, {"dive_side": 0}), 0.0, 0.1, "5 m straight at a keeper who goes up")
	check_between(_goal_rate(Vector2(25, 10), 10.1, 5.0, 10.0), 0.0, 0.5, "5 m straight at him: he blocks most of them (bar an early guess)")
	check_between(_goal_rate(Vector2(23, 10), 11.2, 5.0, 10.0), 0.4, 0.7, "7 m, corner: he has to guess it")
	var guessed := _goal_rate(Vector2(23, 10), 11.2, 5.0, 10.0, false, {"dive_side": 1})
	check(guessed < _goal_rate(Vector2(23, 10), 11.2, 5.0, 10.0) * 0.6, "7 m, corner: guess it and he has a good share of them (%.2f)" % guessed)
	check_between(_goal_rate(Vector2(27, 9), 11.2, 3.0, 9.8), 0.60, 0.90, "open drive at 3 m")
	check_between(_goal_rate(Vector2(25, 10), 11.1, 9.0, 10.0, true), 0.6, 0.85, "penalty")   # (0.64 since the keeper overhaul: he still guesses, his reach is a little better at shoulder height)
	check(_goal_rate(Vector2(28, 15), 8.8, 2.0, 10.9) < _goal_rate(Vector2(28, 10.5), 8.8, 2.0, 10.1),
		"a sharp angle is harder than a central look")
	# a defender in the lane blocks
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var blocks := 0
	var set_guard := {"pos": Vector2(25.0, 10.15), "defense": 50, "strength": 50, "speed": 50, "on_ball": true, "ready": true}
	for i in 500:
		var r := ShotModel.resolve(Vector2(24, 10), 11.0, 0.8, 65.0, 1.0, [set_guard], 10.0, 62.0, rng)
		if r.outcome == "block":
			blocks += 1
	check(blocks > 250, "a defender straight in the lane blocks most shots (%d/500)" % blocks)

# ------------------------------------------------------------------ possessions
func _teams() -> Array:
	return [League.make_team(2, 1), League.make_team(3, 1)]

func _run_play(p: Play, rng: RandomNumberGenerator) -> float:
	var t := 0.0
	var think := 0.0
	var dt := 1.0 / 30.0
	while not p.over and t < 60.0:
		think -= dt
		if think <= 0.0:
			think = PlayBot.THINK_EVERY
			var d := PlayBot.think(p, rng)
			if not d.is_empty():
				p.throw(d.target, d.power)
		p.step(dt)
		t += dt
	return t

func test_possessions() -> void:
	print("possessions")
	# a few pairings of mid-table clubs, so one lucky roster (a star keeper) can't swing it
	var pairings := [[League.make_team(2, 1), League.make_team(3, 1)], [League.make_team(1, 2), League.make_team(4, 2)],
		[League.make_team(3, 3), League.make_team(2, 3)]]
	for kind in [Play.Kind.HALF_COURT, Play.Kind.COUNTER, Play.Kind.PENALTY]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 100 + kind
		var tally := {}
		var longest := 0.0
		var n := 300
		var shots := 0
		var blocks := 0
		for i in n:
			var teams: Array = pairings[i % pairings.size()]
			var p := Play.new(teams[0], teams[1], kind, rng)
			var t := _run_play(p, rng)
			longest = maxf(longest, t)
			var o := String(p.result.get("outcome", "unfinished"))
			tally[o] = int(tally.get(o, 0)) + 1
			shots += p.events.filter(func(e): return e.k == "shot").size()
			blocks += p.events.filter(func(e): return e.k == "block").size()
		print("  kind %d: %s  (longest %.1fs, %d shots, %d blocked)" % [kind, str(tally), longest, shots, blocks])
		check(not tally.has("unfinished"), "every possession ends (kind %d)" % kind)
		check(longest < 45.0, "no possession outlives the shot clock plus resets (kind %d)" % kind)
		var goals: float = tally.get("goal", 0) / float(n)
		match kind:
			Play.Kind.HALF_COURT:
				# (0.50 before the AI overhaul: their keeper now guesses instead of reading the ball)
				check_between(goals, 0.18, 0.72, "half-court goal rate with the bot")
			Play.Kind.COUNTER:
				check_between(goals, 0.3, 0.8, "counterattack goal rate with the bot")
			Play.Kind.PENALTY:
				# their keeper guesses a side (ShotModel.GUESS_DEPTH): right, and he has most of them
				check_between(goals, 0.45, 0.8, "penalty goal rate with the bot")

# ------------------------------------------------------------------ aiming
## Your shot goes exactly where you aim it: pulled back from the centre and both wings, at the
## middle of the goal, both corners, just wide of each post and across the cage, with the keeper
## anywhere and defenders about. The crossing point is the aim, every frame of the flight is on
## that line, and so is wherever it stops (net, keeper, block, wide). The AI keeps its spread.
func test_shot_line() -> void:
	print("shot line")
	var teams := _teams()
	var aim := AimGuide.new()
	var start := Vector2(240, 150)
	var froms := {"centre": Vector2(24.5, 10.0), "left wing": Vector2(26.8, 5.2), "right wing": Vector2(26.8, 14.8),
		"2 m": Vector2(28.0, 10.0)}
	var aims := {"middle": 10.0, "upper corner": 8.65, "lower corner": 11.35, "just wide high": 8.2,
		"just wide low": 11.8}
	var worst_cross := 0.0
	var worst_line := 0.0
	var worst_end := 0.0
	var shots := 0
	var outcomes := {}
	var bad := []
	for fname in froms:
		var from: Vector2 = froms[fname]
		var targets: Dictionary = aims.duplicate()
		# across the cage: from a wing, to the far corner
		if from.y < 9.0:
			targets["across the cage"] = 11.3
		elif from.y > 11.0:
			targets["across the cage"] = 8.7
		for tname in targets:
			var cy: float = targets[tname]
			for sd in 40:
				var rng := RandomNumberGenerator.new()
				rng.seed = 7100 + sd
				var p := Play.new(teams[0], teams[1], Play.Kind.HALF_COURT, rng)
				p.holder.pos = from
				if fname == "2 m":
					p.holder.tag = "C"   # the centre's power shot doesn't pull it in either
				p.keeper.pos.y = Geo.GOAL_Y + rng.randf_range(-1.1, 1.1)
				p.catch_t = 0.0 if sd % 3 == 0 else INF   # catch and shoot too
				for i in p.defenders.size():
					# some right in the lane, some anywhere
					var u := rng.randf_range(0.2, 0.85)
					var on_lane := from.lerp(Vector2(Geo.GOAL_X, cy), u) + Vector2(0.0, rng.randf_range(-0.6, 0.6))
					p.defenders[i].pos = on_lane if i < 2 else Vector2(rng.randf_range(20.0, 28.5), rng.randf_range(3.0, 17.0))
				var cross := Vector2(Geo.GOAL_X, cy)
				var aim_pt := from + (cross - from).normalized() * (from.distance_to(cross) + rng.randf_range(0.5, 4.0))
				aim.begin(0, start)
				aim.now = start + AimGuide.pull_for(p.holder, aim_pt)
				var mode := p.shoot_at(aim.target(p.holder), aim.power(p.holder))
				if mode != "shot":
					bad.append("%s / %s: %s" % [fname, tname, mode])
					continue
				shots += 1
				var res: Dictionary = p.ball.shot
				worst_cross = maxf(worst_cross, absf(float(res.cross_y) - cy))
				var dir := (cross - from).normalized()
				var off_line := func(q: Vector2) -> float: return absf((q - from).cross(dir))
				worst_end = maxf(worst_end, maxf(off_line.call(p.ball.from), off_line.call(p.ball.to)))
				var t := 0.0
				while p.ball.state == Ball.State.SHOT and t < 3.0:
					p.step(1.0 / 60.0)
					t += 1.0 / 60.0
					if p.ball.state == Ball.State.SHOT or String(res.outcome) == "goal":
						worst_line = maxf(worst_line, off_line.call(p.ball.pos))
				outcomes[res.outcome] = int(outcomes.get(res.outcome, 0)) + 1
	print("  %d shots, outcomes %s" % [shots, str(outcomes)])
	print("  furthest from the aim: crossing %.5f m, in flight %.5f m, start/end %.5f m" % [worst_cross, worst_line, worst_end])
	check(bad.is_empty(), "every aimed pull is a shot (%s)" % ", ".join(bad))
	check(worst_cross < 0.0001, "your shot crosses the goal line exactly where you aimed (%.5f m off)" % worst_cross)
	check(worst_line < 0.001, "...and flies along exactly that line all the way (%.5f m off)" % worst_line)
	check(worst_end < 0.001, "...from his hand to wherever it stops (%.5f m off)" % worst_end)
	check(outcomes.has("miss") and outcomes.has("goal") and outcomes.has("block"),
		"aimed wide it misses, aimed in it can score, a hand in the lane still blocks it")
	# the same aim, different dice: the same line every time
	var crossings := {}
	for sd in 30:
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = 300 + sd
		var p2 := Play.new(teams[0], teams[1], Play.Kind.HALF_COURT, rng2)
		p2.holder.pos = Vector2(25.0, 7.0)
		for d in p2.defenders:
			d.pos = Vector2(12.0, 2.0)
		p2.shoot_at(Vector2(31.0, 11.6), 0.9)
		crossings[snappedf(float(p2.ball.shot.cross_y), 0.00001)] = true
	check(crossings.size() == 1, "a full pull is just as true: no wobble, whatever the shooter's rating (%d lines)" % crossings.size())
	# the AI's throws keep their spread
	var ai_ys := {}
	for sd in 30:
		var rng3 := RandomNumberGenerator.new()
		rng3.seed = 500 + sd
		var p3 := Play.new(teams[0], teams[1], Play.Kind.HALF_COURT, rng3)
		p3.holder.pos = Vector2(25.0, 7.0)
		p3.throw(Vector2(31.0, 11.6), 0.9)
		if p3.ball.state == Ball.State.SHOT:
			ai_ys[snappedf(float(p3.ball.shot.cross_y), 0.001)] = true
	check(ai_ys.size() > 10, "the AI's shots still have their spread (%d different lines)" % ai_ys.size())

## The slingshot: the same pull moves the aim the same distance both ways, a pass aimed near
## a teammate finds him where he's swimming to, and a tiny pull throws nothing.
func test_aim() -> void:
	print("aim")
	var teams := _teams()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var p := Play.new(teams[0], teams[1], Play.Kind.HALF_COURT, rng)
	var aim := AimGuide.new()
	var start := Vector2(240, 150)
	aim.begin(0, start)
	aim.now = start + Vector2(-30, 0)
	var along := aim.target(p.holder).distance_to(p.holder.pos)
	aim.now = start + Vector2(0, -30)
	var across := aim.target(p.holder).distance_to(p.holder.pos)
	check(is_equal_approx(along, across), "a pull aims as far across the pool as along it (%.2f vs %.2f)" % [along, across])
	aim.now = start + AimGuide.pull_for(p.holder, Vector2(26.0, 12.0))
	check(aim.target(p.holder).distance_to(Vector2(26.0, 12.0)) < 0.01, "pull_for aims where it says")
	var mate: Swimmer = null
	for a in p.attackers:
		if a != p.holder and a.tag == "1":
			mate = a
	mate.vel = Vector2(1.5, -0.5)
	var info := p.aim_info(mate.pos + Vector2(0.0, 0.4))
	check(info.receiver == mate, "aiming just off a teammate passes to him")
	var flight := p.holder.pos.distance_to(mate.pos) / p.pass_speed(p.holder)
	var lead := Geo.clamp_in_pool(mate.pos + mate.vel * flight)
	check((info.point as Vector2).distance_to(lead) < 0.01, "the pass leads him to where he's swimming")
	aim.now = start + Vector2(6, 3)
	check(not aim.long_enough(), "a tiny pull is no throw")
	check(aim.power() < 0.5 and AimGuide.FULL_PULL <= 75.0, "full power is a short pull")
	# a shot's power is the pull past the goal, wherever he shoots from
	var near := Swimmer.new(p.holder.player, Swimmer.Side.US)
	near.pos = Vector2(27.0, 10.0)
	var far := Swimmer.new(p.holder.player, Swimmer.Side.US)
	far.pos = Vector2(23.0, 10.0)
	aim.now = start + AimGuide.pull_for(near, Vector2(Play.SHOT_ZONE_X + 0.5, 10.5))
	var p_near := aim.power(near)
	aim.now = start + AimGuide.pull_for(far, Vector2(Play.SHOT_ZONE_X + 0.5, 10.5))
	var p_far := aim.power(far)
	check(absf(p_near - p_far) < 0.05 and p_far < 0.6, "a just-reaching shot is soft from 3 m and from 7 m (%.2f, %.2f)" % [p_near, p_far])
	aim.now = start + AimGuide.pull_for(far, Vector2(Play.SHOT_ZONE_X + 4.5, 10.5))
	check(aim.power(far) > 0.95, "pulling 4 m past the goal is full power")
	# tap to pass, pull back to shoot: one gesture, one action
	var rng3 := RandomNumberGenerator.new()
	rng3.seed = 5
	var v := PoolView.new()
	var tp := Play.new(teams[0], teams[1], Play.Kind.HALF_COURT, rng3)
	v.snap_to(PoolView.attack_focus(tp.ball.pos))
	var passer := tp.holder
	var target_mate: Swimmer = null
	for a in tp.attackers:
		if a != passer and a.pos.x < 26.0:
			target_mate = a
	var mate_px := v.to_screen(target_mate.pos) + Vector2(0, -4)
	# taps become pool spots through the camera, wherever it is and whichever way the pool faces
	var spot = AimGuide.tap_spot(v, v.to_screen(Vector2(20.0, 6.0)))
	check(spot != null and (spot as Vector2).distance_to(Vector2(20.0, 6.0)) < 0.1, "a tap on the water is that spot in the pool")
	var mv := PoolView.new()
	mv.mirror = true
	mv.snap_to(Vector2(8.0, 12.0))
	var mspot = AimGuide.tap_spot(mv, mv.to_screen(Vector2(7.0, 13.0)))
	check(mspot != null and (mspot as Vector2).distance_to(Vector2(7.0, 13.0)) < 0.1, "...with the camera moved and the pool mirrored too")
	check(AimGuide.tap_spot(v, Vector2(240, 4)) == null, "a tap on the scoreboard is no pass")
	var deck := PoolView.new()
	deck.snap_to(Vector2(28.0, 18.0))
	check(AimGuide.tap_spot(deck, deck.to_screen(Vector2(31.5, 20.8))) == null, "a tap on the deck outside the pool is no pass")
	check(not tp.can_pass_at(Vector2(-1.0, 10.0)) and not tp.can_pass_at(Vector2(15.0, 21.0)), "no pass to outside the pool")
	check(not tp.can_pass_at(passer.pos + Vector2(0.3, 0.0)), "tapping the ball carrier is no self-pass")
	# one gesture, one action: a wobble is a tap, a pull is a pull, never both
	aim.begin(0, mate_px)
	aim.now = mate_px + Vector2(3, -2)
	check(aim.is_tap() and not aim.long_enough(), "a slight wobble is still a tap, not a pull")
	aim.now = mate_px + Vector2(8, 5)
	check(aim.is_tap() and not aim.long_enough(), "a bigger wobble is still a tap")
	var gesture_ok := true
	for px in range(0, 40):
		aim.now = mate_px + Vector2(px * 0.5, px * 0.2)
		if aim.is_tap() == aim.long_enough():
			gesture_ok = false
	check(gesture_ok, "every release is exactly one of a tap or a pull")
	aim.now = mate_px + AimGuide.pull_for(passer, target_mate.pos)
	check(not aim.is_tap(), "a pull is not a tap")
	check(tp.shoot_at(aim.target(passer), aim.power(passer)) == "pass" and tp.holder == passer \
		and tp.ball.state == Ball.State.HELD, "a pull aimed at a teammate throws nothing")
	# 1) a tap on a teammate: the ball goes to where he was tapped, not where he's swimming
	target_mate.vel = Vector2(1.5, 1.0)
	var tapped := target_mate.pos
	check(tp.pass_at(tapped) and tp.ball.state == Ball.State.PASS and tp.holder == null, "a tap on a teammate passes")
	check(tp.ball.to.distance_to(tapped) < 0.01, "...to the spot tapped, not leading him")
	check(tp.ball.receiver == target_mate, "...and he goes for it")
	check(not tp.pass_at(tapped + Vector2(1, 0)), "no second pass while the ball is in the air")
	var pen := Play.new(teams[0], teams[1], Play.Kind.PENALTY, rng3)
	check(not pen.can_pass_at(pen.holder.pos + Vector2(-3.0, 2.0)), "no passing on a penalty")
	# 2-4, 6) open water, ahead of and behind a teammate, and far across the pool: exactly there
	for spot_to: Vector2 in [Vector2(18.0, 3.0), target_mate.pos + Vector2(2.5, 0.0), target_mate.pos + Vector2(-2.5, 0.0), Vector2(3.0, 17.0)]:
		var lp := Play.new(teams[0], teams[1], Play.Kind.HALF_COURT, RandomNumberGenerator.new())
		check(lp.pass_at(spot_to) and lp.ball.to.distance_to(Geo.clamp_in_pool(spot_to)) < 0.01, "a tap at %s passes exactly there" % str(spot_to))
		var from: Vector2 = lp.ball.from
		lp.step(1.0 / 30.0)
		var heading := (lp.ball.pos - from).normalized().dot((spot_to - from).normalized())
		check(heading > 0.99, "...and the ball heads that way (%.3f)" % heading)
	# 5, 10) open water: the ball lands loose and whoever gets there first has it
	var tally := {"lead": [0, 0, 0], "marked": [0, 0, 0], "defender": [0, 0, 0]}   # ours, theirs, went loose
	for sd in 90:
		var r4 := RandomNumberGenerator.new()
		r4.seed = 700 + sd
		var op := Play.new(teams[0], teams[1], Play.Kind.HALF_COURT, r4)
		var case: String = ["lead", "marked", "defender"][sd % 3]
		var to := Vector2.ZERO
		if case != "defender":
			# 2 m into the space in front of a wing, towards the goal; "lead": he's beaten his man
			var wing: Swimmer = null
			for a in op.attackers:
				if a != op.holder and a.tag in ["1", "5"]:
					wing = a
			to = wing.pos + (Geo.goal_center() - wing.pos).normalized() * 2.0
			if case == "lead":
				for d in op.defenders:
					if d.mark == wing:
						d.pos = wing.pos + Vector2(-4.0, 0.0)
						d.target = d.pos
		else:
			# dropped right on a defender with nobody of ours near
			var dd := op.defenders[1]
			dd.pos = Vector2(19.0, 3.0)
			to = Vector2(19.3, 3.3)
		op.pass_at(to)
		var guard := 0
		var saw_loose := false
		while not op.over and op.holder == null and guard < 600:
			op.step(1.0 / 30.0)
			saw_loose = saw_loose or op.ball.state == Ball.State.LOOSE
			guard += 1
		var row: Array = tally[case]
		if op.over:
			row[1] += 1
		elif op.holder != null:
			row[0] += 1
		if saw_loose:
			row[2] += 1
	print("  passes into space (ours, theirs, went loose of 30): open teammate %s, marked teammate %s, on a defender %s" \
		% [str(tally.lead), str(tally.marked), str(tally.defender)])
	var mine: int = tally.lead[0]
	var theirs: int = tally.defender[1]
	check(tally.lead[2] + tally.defender[2] > 10, "a pass nobody catches lands as a loose ball")
	check(mine > 10, "a teammate swims onto a pass into the space ahead of him")
	check(theirs > 0, "a defender can intercept or recover a pass dropped near him")
	# ball down he swims it to his spot; pull back and he lifts it and stops; ease off, it's down
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 8
	var q := Play.new(teams[0], teams[1], Play.Kind.HALF_COURT, rng2)
	var h := q.holder
	var d0 := h.pos.distance_to(h.home)
	for _i in 45:
		q.step(1.0 / 30.0)
	check(q.holder == h, "nobody took the ball off him in 1.5 s")
	check(h.pos.distance_to(h.home) < d0 - 1.0, "ball down, he swims it to his spot (%.1f -> %.1f m)" % [d0, h.pos.distance_to(h.home)])
	check(q.ball.z < 0.1, "the ball is on the water while he swims with it")
	q.raise_ball(true)
	for _i in 20:
		q.step(1.0 / 30.0)
	check(h.vel.length() < 0.4, "ball up, he stops to throw")
	check(q.ball.z > 0.7, "ball up is over his head (z %.2f)" % q.ball.z)
	q.events.clear()
	q.raise_ball(false)
	check(q.events.any(func(e): return e.k == "ball_down"), "easing off puts the ball back in the water")

## DRIVE▾: each call sends the right man, flat out; tapping the button and the strip never
## starts an aim.
func test_calls() -> void:
	print("drive calls")
	var teams := _teams()
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var p := Play.new(teams[0], teams[1], Play.Kind.HALF_COURT, rng)
	check(p.holder.tag == "3", "the point has the ball at the start")
	check(p.drive_candidate("left").tag == "4" and p.drive_candidate("right").tag == "2", "left sends the 4, right the 2")
	check(p.drive_candidate("middle") == null, "no middle drive while the point has the ball")
	var who := p.call_drive("right")
	check(who != null and who.drive_t > 0.0 and who.called > 0.0, "a called drive starts now")
	for _i in 15:
		p.step(1.0 / 30.0)
	var others := p.attackers.filter(func(a): return a != who and a != p.holder)
	check(others.all(func(a): return who.speed() >= a.speed()), "the called man is the fastest in the water")
	var pm := Play.new(teams[0], teams[1], Play.Kind.HALF_COURT, rng)
	pm._exclusion(pm.defenders[0])
	check(pm.drive_candidate("left") == null, "no drive calls on a power play")
	# the screen: the button and the strip swallow their taps
	Game.goto("match", {"us": League.make_team(3), "them": League.make_team(0), "seed": 12, "minutes": 2.0, "level": 0.5})
	await get_tree().process_frame
	var ms = Game.current_screen
	ms.flow.sprint_done(true)
	for _i in 4:
		await get_tree().process_frame
	var tap := func(at: Vector2, down: bool) -> void:
		var e := InputEventScreenTouch.new()
		e.position = at
		e.pressed = down
		ms._input(e)
	tap.call(ms.calls.button.get_center(), true)
	tap.call(ms.calls.button.get_center(), false)
	check(ms.calls.open and not ms.aim.active, "DRIVE opens the strip without starting an aim")
	var p2: Play = ms.flow.play
	var mate: Swimmer = p2.drive_candidate("left")
	tap.call((ms.calls.rows["left"] as Rect2).get_center(), true)
	tap.call((ms.calls.rows["left"] as Rect2).get_center(), false)
	check(not ms.calls.open and not ms.aim.active and mate.drive_t > 0.0, "picking LEFT sends him and throws nothing")
	Game.save_settings()
	Game.goto("title")
	await get_tree().process_frame

# ------------------------------------------------------------------ the sprint
## Everyone starts on their own goal line; tapping about five times a second is an even race
## against a normal team, mashing wins it, not tapping loses it; MP's remote sprinter lines up.
func test_sprint() -> void:
	print("sprint")
	var teams := _teams()
	var s := Sprint.new(teams[0], teams[1], 3.0)
	for b in s.bodies():
		var line := Sprint.SPRINTER_X if b.side == Swimmer.Side.US else Geo.LENGTH - Sprint.SPRINTER_X
		check(absf(b.pos.x - line) <= 0.95, "everyone starts on his own goal line (%.1f)" % b.pos.x)
	check(is_equal_approx(s.progress(), 0.0), "the sprinter hasn't moved before the whistle")
	s.set_remote(0.0)
	check(is_equal_approx(s.theirs.pos.x, Geo.LENGTH - Sprint.SPRINTER_X), "a remote sprinter starts on his line")
	var rate := func(taps_per_s: float) -> float:
		var wins := 0
		for i in 200:
			var rng := RandomNumberGenerator.new()
			rng.seed = 300 + i
			var f := MatchFlow.new(teams[0], teams[1], 300 + i, 4.0)
			var sp := Sprint.new(f.us, f.them, f.their_sprint_speed())
			var dt := 1.0 / 60.0
			var next_tap := 0.0
			var tt := 0.0
			while not sp.done and tt < 20.0:
				if sp.started() and taps_per_s > 0.0 and tt >= next_tap:
					sp.tap()
					next_tap = tt + 1.0 / taps_per_s * rng.randf_range(0.8, 1.2)
				sp.step(dt)
				tt += dt
			if sp.we_won:
				wins += 1
		return wins / 200.0
	var even: float = rate.call(5.0)
	print("  wins: 0 taps %.2f, 5 taps/s %.2f, 8 taps/s %.2f" % [rate.call(0.0), even, rate.call(8.0)])
	check(rate.call(0.0) < 0.05, "not tapping loses the sprint")
	check_between(even, 0.25, 0.85, "five taps a second is a race")
	check(rate.call(8.0) > even, "tapping faster wins more")

# ------------------------------------------------------------------ defence
## Your defence is the AI's: you only keep goal. Steals are rare and earned: a pass right
## through a defender is picked off far more often than one at the edge of his reach, and the
## man on the ball strips it only from in front of him, rarely, unless the holder dawdles.
## Then their possessions against the AI defence and the bot keeper: they all end, and score at
## a believable rate.
func test_defense() -> void:
	print("defence")
	var teams := _teams()
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var q := Play.new(teams[1], teams[0], Play.Kind.HALF_COURT, rng)
	q.defending = true
	check(not ("ctrl" in q) and not ("ctrl_target" in q), "defending, no field player of yours takes orders")
	# every defender has a man and swims to him by himself
	var t0 := 0.0
	var starts := q.defenders.map(func(d: Swimmer): return d.pos)
	while t0 < 1.0:
		q.step(1.0 / 30.0)
		t0 += 1.0 / 30.0
	check(q.defenders.all(func(d: Swimmer): return d.mark != null), "the AI marks every one of their men")
	var moved := 0
	for i in q.defenders.size():
		if q.defenders[i].pos.distance_to(starts[i]) > 0.05:
			moved += 1
	check(moved >= 4, "your defenders swim by themselves (%d moved)" % moved)
	# a pass through a defender vs one at the edge of his reach
	var chance_at := func(off: float) -> float:
		var c := Play.new(teams[0], teams[1], Play.Kind.HALF_COURT, rng)
		c.ball.from = Vector2(20.0, 10.0)
		c.ball.to = Vector2(26.0, 10.0)
		c.ball.passer = c.holder
		var d: Swimmer = c.defenders[1]
		d.pos = Vector2(23.0, 10.0 + off)
		return c._intercept_chance(d, 0.5)
	var through: float = chance_at.call(0.0)
	var edge: float = chance_at.call(0.48)
	print("  pick-off chance: through him %.2f, at the edge of his reach %.2f" % [through, edge])
	check(through > 0.0 and through <= 0.55, "a pass through him can be picked off, but not every time")
	check(edge < through * 0.35, "a pass at the edge of his reach is much safer")
	# the press: a man who moves it on is rarely stripped; one who dawdles is more often
	var stripped := func(secs: float) -> int:
		var n := 0
		for sd in 300:
			var sp := _staged(Vector2(24.0, 10.0), Vector2(24.8, 10.0), 900 + sd, true)
			_mark_holder(sp, sp.defenders[0])
			sp.raise_ball(true)
			var tt := 0.0
			while tt < secs and not sp.over:
				sp.step(1.0 / 30.0)
				tt += 1.0 / 30.0
			if sp.over and String(sp.result.outcome) == "steal":
				n += 1
		return n
	var quick: int = stripped.call(1.5)
	var dawdle: int = stripped.call(10.0)
	print("  stripped holding it 1.5 s: %d/300, 10 s: %d/300" % [quick, dawdle])
	check(quick <= 12, "moving it on quickly, the press rarely strips him")
	check(dawdle > quick * 3 and dawdle > 0, "holding it too long under pressure gets it stripped")
	# their possessions: the bot defends and keeps
	var tally := {}
	var longest := 0.0
	var n := 200
	var counted := true
	for i in n:
		var f := MatchFlow.new(teams[0], teams[1], 500 + i, 8.0)
		f._start_defense(Play.Kind.HALF_COURT)
		longest = maxf(longest, f.auto_defense(0.5))
		var o := String(f.play.result.get("outcome", "unfinished"))
		tally[o] = int(tally.get(o, 0)) + 1
		var how := String(f.play.result.get("text", ""))
		tally[how] = int(tally.get(how, 0)) + 1
		if o == "goal" and f.state.shots[1] < 1:
			counted = false
	print("  their possessions: %s  (longest %.1fs)" % [str(tally), longest])
	check(not tally.has("unfinished"), "every one of their possessions ends")
	check(longest < 45.0, "none outlives the shot clock plus resets")
	check(counted, "their goals are counted as shots")
	# (more accurate shooting, and the centre's defender doesn't block: a bit more than it was; and
	# a fed centre's shot that's fouled and doesn't go in keeps the possession going, 6 on 5)
	check_between(tally.get("goal", 0) / float(n), 0.25, 0.6, "their goal rate against the AI defence")
	check(tally.get("steal", 0) > 0, "the defence still steals some")
	# (0.105 before the AI overhaul; your beaten defenders now also go for the ball: CenterDefense)
	check(tally.get("steal", 0) / float(n) < 0.15, "...but only now and then")

## Their attack plays to score (OffenseAI), over 40 bot matches: it shoots in good time and never
## runs out the shot clock, swings the ball without ping-ponging it, and shoots from all over.
func test_offense() -> void:
	print("their offense")
	var t: Dictionary = load("res://tests/offense_stats.gd").new().run(self, 40)
	var g := func(k: String) -> float: return float(t.get(k, 0.0))
	var poss := maxf(1.0, g.call("poss"))
	var fs: Array = t.first_shot
	fs.sort()
	var in_window := fs.filter(func(x): return x >= 3.0 and x <= 15.0).size() / maxf(1.0, fs.size())
	check(g.call("shotclock") / poss < 0.01, "their shot clock violations are rare (%d in %d)" % [int(g.call("shotclock")), int(poss)])
	check(g.call("set_shot") / maxf(1.0, g.call("set")) > 0.8, "most settled possessions end in a shot")
	# (a fed centre now goes up rather than being whistled on the catch, so a possession that gets
	# the ball inside ends a little sooner)
	check_between(fs[fs.size() / 2], 6.5, 13.0, "median seconds to their first shot (settled)")
	check(in_window > 0.85, "settled possessions get a shot off in 3-15 s (%.0f%%)" % (100.0 * in_window))
	check(fs[fs.size() - 1] <= 25.0, "...and none waits for the end of the shot clock")
	check(g.call("pingpong") / maxf(1.0, g.call("passes")) < 0.12, "little passing straight back (%.0f%% of passes)" % (100.0 * g.call("pingpong") / maxf(1.0, g.call("passes"))))
	check_between(g.call("passes") / poss, 1.5, 4.0, "passes per possession")
	# (your keeper shades to the ball now (MatchFlow.TRACK_MAX), and they read it: more cross-cage
	# from the flats, a few less from the centre, so the bar is 4% of their shots, not 5%)
	var spots := ["sh_C", "sh_wing", "sh_flat", "sh_point"].filter(func(k): return g.call(k) >= 0.04 * g.call("shots"))
	check(spots.size() == 4, "they shoot from the centre, the wings, the flats and the point")
	check(g.call("sh_out6") == 0.0 and g.call("our_out6") == 0.0 and g.call("our_shots") > 0.0,
		"no AI shot from outside 6 m, theirs or the bot's (%d, %d)" % [int(g.call("sh_out6")), int(g.call("our_out6"))])
	check(g.call("catch_shoot") > 0.3 * g.call("shots"), "plenty of catch and shoot")
	check(g.call("drives") + g.call("stride") > 0.0, "they drive into open water")
	check(g.call("moving") / maxf(1.0, g.call("samples")) > 0.6, "their men off the ball keep moving")
	# (real-time 2:00 quarters: about 1.8x the possessions of the old 1.5x clock, the same rate per possession)
	check_between(g.call("goals") / 40.0, 9.0, 17.0, "their goals per game")
	check_between(g.call("goals") / poss, 0.3, 0.6, "their goals per possession")

# ------------------------------------------------------------------ blocks and the keeper
## A defender of the given ratings at `pos`, as ShotModel sees him: a help defender.
func _blk(pos: Vector2, dfn: int = 60, stren: int = 60, spd: int = 60) -> Dictionary:
	return {"pos": pos, "defense": dfn, "strength": stren, "speed": spd, "i": 0}

## The shooter's own guard: `ready` once he's pressed him for Play.GUARD_TIME.
func _guard(pos: Vector2, ready: bool, dfn: int = 60, stren: int = 60, spd: int = 60) -> Dictionary:
	var b := _blk(pos, dfn, stren, spd)
	b["on_ball"] = true
	b["ready"] = ready
	return b

## {block, goal, save, attempts, moved_up, moved_down}: rates over n shots.
func _shot_mix(from: Vector2, aim_y: float, power: float, blockers: Array, keeper_y: float = 10.0,
		keeping: float = 62.0, n: int = 2000) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var out := {"block": 0.0, "goal": 0.0, "save": 0.0, "attempts": 0.0, "moved_up": 0.0, "moved_down": 0.0}
	for i in n:
		var r := ShotModel.resolve(from, aim_y, power, 65.0, from.distance_to(blockers[0].pos) if not blockers.is_empty() else 5.0,
			blockers, keeper_y, keeping, rng)
		var o := String(r.outcome)
		if o == "parry":
			o = "save"
		if out.has(o):
			out[o] += 1.0 / n
		if not (r.attempts as Array).is_empty():
			out.attempts += 1.0 / n
		if float(r.keeper_end_y) > keeper_y + 0.1:
			out.moved_up += 1.0 / n
		elif float(r.keeper_end_y) < keeper_y - 0.1:
			out.moved_down += 1.0 / n
	return out

## A possession set up by hand: the shooter at `at`, defender 0 at `d_at` (the rest out of the
## way), their keeper in the middle of his goal.
func _staged(at: Vector2, d_at: Vector2, seed_value: int, defending := false) -> Play:
	var teams := _teams()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var p := Play.new(teams[0], teams[1], Play.Kind.HALF_COURT, rng)
	p.defending = defending
	p.holder.pos = at
	# the staged man is a help defender, not the centre's (who doesn't block: Play.CENTER_DEFENDER_BLOCKS)
	var swap := p.defenders[0].mark
	p.defenders[0].mark = p.defenders[1].mark
	p.defenders[1].mark = swap
	for i in p.defenders.size():
		p.defenders[i].pos = d_at if i == 0 else Vector2(12.0 + i, 2.0 + i)
	p.keeper.pos = Vector2(Geo.KEEPER_X, Geo.GOAL_Y)
	return p

## Makes `d` the man with the ball's guard (swapping marks), already pressing him for `secs`.
func _press(p: Play, d: Swimmer, secs: float) -> void:
	_mark_holder(p, d)
	d.guard_on = p.holder
	d.guard_t = secs

func _mark_holder(p: Play, d: Swimmer) -> void:
	for o in p.defenders:
		if o.mark == p.holder and o != d:
			o.mark = d.mark
	d.mark = p.holder

## Steps a play `secs` with the ball held up (the holder stays put).
func _hold(p: Play, secs: float) -> void:
	p.raise_ball(true)
	var t := 0.0
	while t < secs - 0.001 and not p.over and p.ball.state == Ball.State.HELD:
		p.step(1.0 / 60.0)
		t += 1.0 / 60.0

## Their attack with defender 0 goal-side of the shooter at `at` and on him.
func _guarded(at: Vector2, seed_value: int) -> Play:
	var p := _staged(at, at + Vector2(0.75, 0.05), seed_value, true)
	_mark_holder(p, p.defenders[0])
	return p

## The on-ball pressure rule: the shooter's guard needs Play.GUARD_TIME of unbroken pressure
## before he can block (or even go for) the shot; the help in the lane needs none.
func test_guard() -> void:
	print("on-ball pressure")
	var from := Vector2(24.0, 10.0)
	var rng := RandomNumberGenerator.new()
	# A, D) caught and shot: his guard, even a 99, gets nothing on it, and an open lane is open
	rng.seed = 41
	var guard_tries := 0
	var guard_blocks := 0
	for i in 2000:
		var r := ShotModel.resolve(from, 10.9, 0.8, 65.0, 0.8, [_guard(from + Vector2(0.8, 0.1), false, 99, 99, 99)], 10.0, 62.0, rng)
		guard_tries += (r.attempts as Array).size()
		guard_blocks += 1 if String(r.outcome) == "block" else 0
	check(guard_blocks == 0, "an unready guard (rated 99) never blocks (%d)" % guard_blocks)
	check(guard_tries == 0, "...and doesn't even go for it (%d)" % guard_tries)
	# B) pressing long enough: he can block, and his rating matters
	var weak := _shot_mix(from, 10.9, 0.8, [_guard(from + Vector2(0.8, 0.1), true, 30, 30, 30)])
	var strong := _shot_mix(from, 10.9, 0.8, [_guard(from + Vector2(0.8, 0.1), true, 95, 90, 90)])
	print("  ready guard blocks: weak %.2f  strong %.2f" % [weak.block, strong.block])
	check(weak.block > 0.2 and strong.block > weak.block + 0.05, "a ready guard blocks, a better one more")
	check(strong.block < 0.98, "...but never every shot")
	# C) the guard's not ready, but the centre defender sits in the lane: he can block it
	rng.seed = 43
	var by_help := 0
	var by_guard := 0
	for i in 2000:
		var bs := [_guard(Vector2(24.8, 10.1), false), _blk(Vector2(26.8, 10.3))]
		bs[0]["i"] = 0
		bs[1]["i"] = 1
		var r := ShotModel.resolve(Vector2(24.0, 10.0), 10.9, 0.8, 65.0, 0.8, bs, 10.0, 62.0, rng)
		if String(r.outcome) == "block":
			if int(r.blocker) == 1:
				by_help += 1
			else:
				by_guard += 1
	print("  catch and shoot through the hole: help blocks %d/2000, guard %d" % [by_help, by_guard])
	check(by_guard == 0 and by_help > 200, "catch and shoot: the help in the lane still blocks, the guard can't")
	# a crowd is a couple of chances, not a wall: two in the lane block more than one, a third
	# behind them only gets a go when the ball's out of the first man's reach
	var lane_a := _blk(Vector2(25.6, 10.25))
	var lane_b := _blk(Vector2(26.8, 10.4))
	var lane_c := _blk(Vector2(27.6, 10.6))
	var pa: float = _shot_mix(Vector2(23.0, 10.0), 10.9, 0.8, [lane_a]).block
	var pb: float = _shot_mix(Vector2(23.0, 10.0), 10.9, 0.8, [lane_b]).block
	var both: float = _shot_mix(Vector2(23.0, 10.0), 10.9, 0.8, [lane_a, lane_b]).block
	var three: float = _shot_mix(Vector2(23.0, 10.0), 10.9, 0.8, [lane_a, lane_b, lane_c]).block
	check(both > maxf(pa, pb) and three >= both and three < both + 0.05,
		"two in the lane block more than one, a third adds little (%.2f, %.2f -> %.2f, %.2f)" % [pa, pb, both, three])
	# E) a ready guard behind him gets nothing
	var behind := _shot_mix(from, 10.9, 0.8, [_guard(from + Vector2(-0.7, 0.1), true, 99, 99, 99)])
	check(behind.attempts == 0.0, "a guard behind the shooter never goes for it")
	# the clock in a live play: 1 s isn't enough, 2 s is (on a play no whistle interrupts: held
	# contact can draw an ordinary foul by then, DefenseFormation.FOUL_SETTLE, and he gives room)
	var p: Play = null
	var d0: Swimmer = null
	var at1 := -1.0
	var ready1 := true
	for sd in range(51, 71):
		p = _guarded(from, sd)
		d0 = p.defenders[0]
		_hold(p, 1.0)
		at1 = d0.guard_t
		ready1 = p.guard_ready(d0, p.holder)
		_hold(p, 1.1)
		if not p.events.any(func(e): return String(e.k) == "foul"):
			break
	check(p.on_ball_guard(p.holder) == d0, "the guard is the man marking the ball")
	check(absf(at1 - 1.0) < 0.05 and not ready1, "after 1 s of pressure he can't block yet (%.2f s)" % at1)
	check(p.guard_ready(d0, p.holder), "after 2 s he can (%.2f s)" % d0.guard_t)
	# nobody else near him counts pressure
	check(p.defenders.slice(1).all(func(o: Swimmer): return o.guard_t == 0.0), "only his guard counts pressure")
	# F) he drops off at 1.5 s and comes back: the clock starts over (on a play no whistle or
	# steal interrupts: a foul makes him give room by design)
	var gone_ok := false
	var again_ok := false
	var again_t := 0.0
	for sd in range(52, 72):
		p = _guarded(from, sd)
		d0 = p.defenders[0]
		_hold(p, 1.5)
		# (off to the side and back, so he comes back round him: dead behind, he'd shove the
		# shooter in towards the goal trying to swim through him)
		d0.pos = p.holder.pos + Vector2(-1.2, 2.4)
		p.step(1.0 / 60.0)
		gone_ok = d0.guard_t == 0.0
		var back := 0.0
		while d0.guard_t == 0.0 and back < 3.0 and not p.over:
			p.step(1.0 / 60.0)
			back += 1.0 / 60.0
		_hold(p, 1.0)
		if p.over or p.freeze > 0.0 or d0.back_off > 0.0:
			continue
		again_ok = d0.guard_t > 0.0 and not p.guard_ready(d0, p.holder)
		again_t = d0.guard_t
		break
	check(gone_ok, "out of range, his pressure is gone")
	check(again_ok, "back on him, he starts again from nothing (%.2f s)" % again_t)
	# a switch: the defenders swap men, and neither keeps the old pressure on the ball
	p = _staged(from, from + Vector2(0.75, 0.05), 53)
	d0 = p.defenders[0]
	_press(p, d0, 2.5)
	var d1 := p.defenders[1]
	d1.pos = from + Vector2(0.8, -0.3)
	var swap := d1.mark
	d1.mark = d0.mark
	d0.mark = swap
	p.step(1.0 / 60.0)
	check(d0.guard_t == 0.0 and d0.guard_on == null, "after a switch his old pressure is gone")
	check(p.on_ball_guard(p.holder) == d1 and not p.guard_ready(d1, p.holder), "...and the new man starts from nothing")
	# a pass: every clock starts over; the catcher's guard starts from nothing
	p = _guarded(from, 54)
	d0 = p.defenders[0]
	_hold(p, 2.5)
	p.raise_ball(false)
	var mate: Swimmer = p.attackers[2]
	p._pass(p.lead_point(mate), mate)
	p.step(1.0 / 60.0)
	check(p.defenders.all(func(o: Swimmer): return o.guard_t == 0.0), "a pass resets every guard's pressure")
	# a new possession starts everyone at zero
	var fresh := Play.new(_teams()[0], _teams()[1], Play.Kind.HALF_COURT, rng)
	check(fresh.defenders.all(func(o: Swimmer): return o.guard_t == 0.0 and o.guard_on == null), "a new possession: no pressure carried over")
	# the centre's guard wrestles him all along: no wait on him
	var centre: Swimmer = fresh.attackers[0]
	check(centre.tag == "C" and fresh.guard_ready(fresh.defenders[0], centre), "the centre's guard can block him at once")
	# live shots after 0.3, 1, 2.5 and 3 s of pressure: who goes for it, who blocks it
	for secs in [0.3, 1.0, 2.5, 3.0]:
		var tries := 0
		var blocked := 0
		var shots := 0
		for sd in 60:
			var q := _guarded(from, 700 + sd)
			_hold(q, secs)
			if q.ball.state != Ball.State.HELD or q.over:
				continue
			shots += 1
			q._shoot(10.9 if sd % 2 == 0 else 9.4, 0.8)
			var sh: Dictionary = q.ball.shot
			for a in sh.attempts:
				if int(a.i) == 0:
					tries += 1
			if String(sh.outcome) == "block" and int(sh.blocker) == 0:
				blocked += 1
		print("  shot after %.1f s of pressure: guard went for %d/%d, blocked %d" % [secs, tries, shots, blocked])
		if secs < Play.GUARD_TIME:
			check(tries == 0 and blocked == 0, "after %.1f s the guard can't block (no arm up either)" % secs)
		else:
			check(blocked > 5, "after %.1f s the guard blocks some (%d/%d)" % [secs, blocked, shots])
			check(blocked < shots, "...not all")
	# a real catch and shoot: the pass lands, he shoots at once, his guard can't touch it
	var cs_guard := 0
	var cs_shots := 0
	for sd in 80:
		var q := Play.new(_teams()[0], _teams()[1], Play.Kind.HALF_COURT, RandomNumberGenerator.new())
		q.rng.seed = 800 + sd
		var mate2: Swimmer = q.attackers[2]
		var g: Swimmer = null
		for d in q.defenders:
			if d.mark == mate2:
				g = d
		g.pos = mate2.pos + (Geo.goal_center() - mate2.pos).normalized() * 0.8
		q._pass(mate2.pos, mate2)
		var guard := 0
		while q.ball.state == Ball.State.PASS and guard < 120:
			q.step(1.0 / 60.0)
			guard += 1
		if q.holder != mate2 or q.over:
			continue
		g.pos = mate2.pos + (Geo.goal_center() - mate2.pos).normalized() * 0.8
		_hold(q, 0.3)
		if q.holder != mate2 or q.over or q.freeze > 0.0:
			continue
		cs_shots += 1
		q._shoot(Geo.GOAL_Y, 0.8)
		for a in q.ball.shot.attempts:
			if q.defenders[int(a.i)] == g:
				cs_guard += 1
	check(cs_shots > 20 and cs_guard == 0, "catch and shoot: the catcher's guard gets no hand to it (%d shots, %d tries)" % [cs_shots, cs_guard])

func test_blocks() -> void:
	print("blocks and the keeper")
	var from := Vector2(24.0, 10.0)
	# 1) the man on the ball, pressing him long enough: he goes for it and blocks plenty, not all
	var on_ball := _shot_mix(from, 10.9, 0.8, [_guard(from + Vector2(0.8, 0.1), true)])
	print("  on the ball: %s" % str(on_ball))
	check(on_ball.attempts > 0.95, "a defender set in front of the shooter goes for every shot")
	check_between(on_ball.block, 0.45, 0.95, "a defender set in front blocks most shots, not all")
	# ...but where the shot goes matters: away from his hand, he gets less of it
	var placed := _shot_mix(from, 8.8, 0.8, [_guard(from + Vector2(0.8, 0.35), true)])
	check(placed.block < on_ball.block - 0.2, "a shot placed away from his hand is blocked less (%.2f vs %.2f)" % [placed.block, on_ball.block])
	# 2) an open lane: defenders off to the side don't block
	var open := _shot_mix(from, 11.0, 0.8, [_blk(Vector2(25.0, 6.5)), _blk(Vector2(27.0, 14.5))])
	check(open.block < 0.01, "an open lane is not blocked (%.3f)" % open.block)
	# 3) a centre defender in the hole between shooter and goal, not marking him, can block
	var hole := _shot_mix(Vector2(23.0, 10.0), 10.9, 0.8, [_blk(Vector2(26.8, 10.3))])
	var hole_weak := _shot_mix(Vector2(23.0, 10.0), 10.9, 0.8, [_blk(Vector2(26.8, 10.3), 35, 35, 35)])
	var hole_strong := _shot_mix(Vector2(23.0, 10.0), 10.9, 0.8, [_blk(Vector2(26.8, 10.3), 90, 85, 85)])
	print("  hole defender blocks: weak %.2f  average %.2f  strong %.2f" % [hole_weak.block, hole.block, hole_strong.block])
	check_between(hole.block, 0.1, 0.7, "a centre defender in the lane blocks some")
	check(hole_strong.block > hole.block and hole.block > hole_weak.block, "better defenders block more")
	# 4) beside or behind the shooter: no block, no attempt
	var beside := _shot_mix(from, 11.0, 0.8, [_guard(from + Vector2(0.0, -0.9), true)])
	var behind := _shot_mix(from, 11.0, 0.8, [_guard(from + Vector2(-0.8, 0.0), true), _blk(from + Vector2(-1.5, 0.3))])
	check(beside.block == 0.0 and behind.block == 0.0, "a defender beside or behind him never blocks")
	check(beside.attempts == 0.0 and behind.attempts == 0.0, "...and doesn't even go for it")
	# 5, 6) the keeper goes the way the ball goes once he's seen it (KeeperAI): no random way
	var ways := {"right": 0, "wrong": 0, "early": 0}
	var wrng := RandomNumberGenerator.new()
	wrng.seed = 31
	for i in 600:
		var aim := 11.2 if i % 2 == 0 else 8.8
		var wr := ShotModel.resolve(Vector2(25.0, 10.0), aim, 0.8, 65.0, 5.0, [], 10.0, 62.0, wrng)
		if String(wr.gk.kind) != "react":
			ways.early += 1   # (he'd gone before he saw it: KeeperAI's anticipation)
			continue
		var way := 1 if aim > 10.0 else -1
		ways.right += int(int(wr.guess) == way)
		ways.wrong += int(int(wr.guess) == -way)
	print("  reacting to the ball: the way it went %d, the other way %d (gone early %d)" % [ways.right, ways.wrong, ways.early])
	check(ways.right > 0 and ways.wrong == 0, "once he's seen it he goes the way it's aimed, never the other way")
	# 7) straight at him: his body (or his block straight up) has more of those than of a corner
	var at_him := _shot_mix(Vector2(25.0, 10.0), 10.05, 0.8, [])
	check(at_him.save > 0.1, "a shot straight at the keeper: he still has the ones he stays big for (%.2f)" % at_him.save)
	# 8) a hard shot into the far corner: it often goes in; his rating matters
	var corner := _shot_mix(Vector2(24.5, 10.5), 8.7, 1.0, [], 10.2)
	var corner_elite := _shot_mix(Vector2(24.5, 10.5), 8.7, 1.0, [], 10.2, 92.0)
	var corner_poor := _shot_mix(Vector2(24.5, 10.5), 8.7, 1.0, [], 10.2, 30.0)
	print("  hard corner goals: poor keeper %.2f  average %.2f  elite %.2f" % [corner_poor.goal, corner.goal, corner_elite.goal])
	# (since the keeper overhaul a hard ball into the far corner from 5.5 m is mostly past anybody before
	# he's there: the rating counts, but less than on the shots he has time for; see keeper_measure)
	check_between(corner_elite.goal, 0.15, 0.65, "a hard corner shot still beats an elite keeper sometimes")
	check(corner_poor.goal > corner.goal and corner.goal > corner_elite.goal and corner_poor.goal > corner_elite.goal + 0.03, "better keepers save more")
	# seeing where it's going (KeeperAI.recognize_time): about 0.28 s for the best, 0.48 for the worst
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var best_t := 0.0
	var worst_t := 0.0
	for i in 40:
		best_t += float(ShotModel.resolve(Vector2(23, 10), 11.0, 0.8, 65.0, 5.0, [], 10.0, 95.0, rng).reaction) / 40.0
		worst_t += float(ShotModel.resolve(Vector2(23, 10), 11.0, 0.8, 65.0, 5.0, [], 10.0, 15.0, rng).reaction) / 40.0
	check_between(best_t, 0.15, 0.27, "an elite keeper sees where it's going about a fifth of a second after the release")
	check(worst_t > best_t + 0.08 and worst_t < 0.42, "a poor keeper takes a good deal longer (%.2f s)" % worst_t)
	# 9) a block in a live play: the ball comes off his hand and keeps moving, his arm is up
	var blocked := 0
	var arm_up := true
	var deflects := true
	var consistent := true
	for sd in 40:
		var p := _staged(from, from + Vector2(0.75, 0.05), 300 + sd)
		var d0 := p.defenders[0]
		_press(p, d0, Play.GUARD_TIME + 0.5)
		p._shoot(10.9, 0.8)
		var sh: Dictionary = p.ball.shot
		var saw_arm := false
		var guard := 0
		while p.ball.state == Ball.State.SHOT and guard < 200:
			p.step(1.0 / 60.0)
			saw_arm = saw_arm or absf(d0.dive) >= 0.2
			guard += 1
		for a in sh.attempts:
			# no block shown where the ball doesn't reach him, no block without a hit
			if bool(a.hit) != (String(sh.outcome) == "block" and int(sh.blocker) == int(a.i)):
				consistent = false
		if String(sh.outcome) != "block":
			continue
		blocked += 1
		arm_up = arm_up and saw_arm
		var hit_at := p.ball.pos
		for _i in 6:
			p.step(1.0 / 60.0)
		deflects = deflects and p.ball.state == Ball.State.LOOSE and p.ball.pos.distance_to(hit_at) > 0.2
	check(blocked > 10, "a set defender blocks shots in a live play (%d/40)" % blocked)
	check(arm_up, "a blocker's arm is up when the ball gets to him")
	check(deflects, "a blocked ball comes off his hand and keeps moving")
	check(consistent, "only the defender who got a hand to it blocks it")
	# 10) a defender who doesn't get a hand to it: the shot goes on and the keeper has his go
	var rng10 := RandomNumberGenerator.new()
	rng10.seed = 5
	var missed_then_keeper := 0
	for i in 3000:
		var r := ShotModel.resolve(Vector2(23.0, 10.0), 10.9, 0.8, 65.0, 5.0, [_blk(Vector2(26.8, 10.6), 40, 40, 40)], 10.0, 62.0, rng10)
		if not (r.attempts as Array).is_empty() and String(r.outcome) in ["save", "parry", "goal"]:
			if float(r.reaction) < 1.0:
				missed_then_keeper += 1
	check(missed_then_keeper > 100, "a missed block still leaves the keeper his save (%d)" % missed_then_keeper)
	# 11) their attack: your defenders block, your keeper gets the shots that get through
	var teams := _teams()
	var their_blocks := 0
	var duels := 0
	for i in 60:
		var f := MatchFlow.new(teams[0], teams[1], 900 + i, 8.0)
		f._start_defense(Play.Kind.HALF_COURT)
		f.auto_keeper = 0.5
		var t := 0.0
		while not f.play.over and t < 60.0:
			f.tick_defense(1.0 / 30.0)
			t += 1.0 / 30.0
			their_blocks += f.events.filter(func(e): return e.k == "block").size()
			duels += f.events.filter(func(e): return e.k == "duel").size()
			f.events.clear()
	check(their_blocks > 0, "defending, your defenders block some of their shots (%d)" % their_blocks)
	check(duels > 0, "...and your keeper gets the ones that get through (%d)" % duels)
	# 12) your attack: their defenders block, their keeper saves
	var mine := {}
	for sd in 120:
		var p := _staged(Vector2(24.0, 10.5), Vector2(25.0, 10.6) if sd % 2 == 0 else Vector2(26.5, 13.0), 600 + sd)
		p._shoot(8.75 if sd % 4 < 2 else 11.25, 0.75)
		var guard := 0
		while p.ball.state == Ball.State.SHOT and guard < 200:
			p.step(1.0 / 60.0)
			guard += 1
		var o := String(p.ball.shot.outcome)
		mine[o] = int(mine.get(o, 0)) + 1
	print("  your shots: %s" % str(mine))
	check(mine.get("block", 0) > 5, "your shots into a defender get blocked")
	# (corners from 6 m with no look at you first: since the keeper overhaul mostly past him before he's there)
	check(mine.get("save", 0) + mine.get("parry", 0) > 2 and mine.get("goal", 0) > 5, "their keeper saves some, you score some")

# ------------------------------------------------------------------ the full-time panel
func _tap_button(ms, label: String) -> bool:
	for b in ms.buttons:
		if String(b[1]) == label:
			ms._press((b[0] as Rect2).get_center(), 0)
			return true
	return false

func test_results() -> void:
	print("full-time panel")
	# the records on the panel are the ones the season ends up with
	var c := Career.new_game("WAGN", "A", "B", 55)
	c.catch_up()
	var opp: PoloTeam = c.opponent()
	var pred := c.records_after(true)
	var st := MatchState.new()
	st.score = [4, 2]
	c.finish_my_game(st.box(c.team()))
	var real_us := "%s (%s)" % [c.record_text(), c.conf_record_text()]
	var real_them := "%s (%s)" % [c.record_text(opp.id), c.conf_record_text(opp.id)]
	check(pred.us == real_us, "your record on the panel is the season's (%s vs %s)" % [pred.us, real_us])
	check(pred.them == real_them, "theirs too (%s vs %s)" % [pred.them, real_them])
	# a conference game counts in the conference record
	var c2 := Career.new_game("WAGN", "A", "B", 56)
	var guard := 0
	while not (c2.has_game() and bool(c2.my_game().get("c", false))) and guard < 60:
		if c2.has_game():
			c2.finish_my_game(MatchState.new().box(c2.team()))
		else:
			c2.end_week()
		guard += 1
	check(c2.has_game() and bool(c2.my_game().get("c", false)), "the season reaches a conference game")
	if c2.has_game() and bool(c2.my_game().get("c", false)):
		c2.catch_up()   # (as the game preview does: the week's earlier days are played first)
		var opp2: PoloTeam = c2.opponent()
		var p2 := c2.records_after(false)
		var st2 := MatchState.new()
		st2.score = [1, 3]
		c2.finish_my_game(st2.box(c2.team()))
		check(p2.us == "%s (%s)" % [c2.record_text(), c2.conf_record_text()] and p2.them == "%s (%s)" % [c2.record_text(opp2.id), c2.conf_record_text(opp2.id)],
			"a conference game's records on the panel match the table (%s, %s; now %s (%s), %s (%s))" % [p2.us, p2.them, c2.record_text(), c2.conf_record_text(), c2.record_text(opp2.id), c2.conf_record_text(opp2.id)])
	# the box score counts the real events: blocks, steals (no loose balls or keeper claims)
	var teams := _teams()
	var seen_blocks := [0, 0]
	var seen_steals := [0, 0]
	var f := MatchFlow.new(teams[0], teams[1], 4242, MatchState.QUARTER_MIN)
	f.auto_keeper = 0.5
	f.sprint_done(true)
	var think := 0.0
	var loops := 0
	while f.phase in [MatchFlow.Phase.ATTACK, MatchFlow.Phase.DEFENSE] and loops < 40:
		loops += 1
		var defending := f.phase == MatchFlow.Phase.DEFENSE
		var t := 0.0
		while not f.play.over and t < 60.0:
			if defending:
				f.tick_defense(1.0 / 30.0)
			else:
				think -= 1.0 / 30.0
				if think <= 0.0:
					think = PlayBot.THINK_EVERY
					var d := PlayBot.think(f.play, f.rng)
					if not d.is_empty():
						f.play.throw(d.target, d.power)
				f.tick_attack(1.0 / 30.0)
			for e in f.events:
				if e.k == "block":
					seen_blocks[0 if defending else 1] += 1
			f.events.clear()
			t += 1.0 / 30.0
		var oc := String(f.play.result.get("outcome", ""))
		if MatchState.is_steal(oc, f.play.result):
			seen_steals[0 if defending else 1] += 1
		if defending:
			f.defense_done()
		else:
			f.attack_done()
	print("  a quarter: blocks %s, steals %s" % [str(f.state.blocks), str(f.state.steals)])
	check(f.state.blocks == seen_blocks, "blocks counted from the blocks that happened (%s vs %s)" % [str(f.state.blocks), str(seen_blocks)])
	check(f.state.steals == seen_steals, "steals counted from real steals only (%s vs %s)" % [str(f.state.steals), str(seen_steals)])
	# the panel in a real match screen
	Game.match_cfg = {"us": teams[0], "them": teams[1], "seed": 9}
	Game.goto("match", Game.match_cfg)
	await get_tree().process_frame
	var ms = Game.current_screen
	ms.flow.state.score = [3, 5]
	ms.flow.state.shots = [9, 12]
	ms.flow.state.blocks = [2, 1]
	ms.flow.phase = MatchFlow.Phase.FINAL
	ms._process(1.0 / 30.0)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var rp: ResultsPanel = ms.results
	check(rp != null and not rp.open, "full time: the panel is up, details hidden")
	check(rp.stats[0] == [9, 12] and rp.stats[1] == [3, 5] and rp.stats[4] == [2, 1], "it shows this game's numbers")
	var labels: Array = ms.buttons.map(func(b): return String(b[1]))
	check(labels == ["DETAILS", "REMATCH", "CONTINUE >"], "DETAILS, REMATCH, CONTINUE (%s)" % str(labels))
	_tap_button(ms, "DETAILS")
	check(not rp.open, "a tap left over from the last play doesn't open it")
	for _i in 15:
		ms._process(1.0 / 30.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var collapsed: Rect2 = rp.rect(Vector2(480, 270))
	var cont_y: float = (ms.buttons[2][0] as Rect2).position.y
	_tap_button(ms, "DETAILS")
	check(rp.open, "DETAILS opens it")
	for _i in 30:
		ms._process(1.0 / 30.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var expanded: Rect2 = rp.rect(Vector2(480, 270))
	check(is_equal_approx(rp.k, 1.0) and expanded.size.y > collapsed.size.y + 60, "it grows to show the stats")
	check(expanded.end.y <= 270.0 and expanded.position.y >= 24.0, "...staying on screen, clear of the scoreboard (%s)" % str(expanded))
	check(String(ms.buttons[0][1]) == "HIDE DETAILS" and (ms.buttons[2][0] as Rect2).position.y > cont_y + 25, "HIDE DETAILS, and CONTINUE moved down with it")
	# rapid taps: it just turns round, never breaks
	for i in 8:
		rp.toggle()
		rp.step(0.03)
	check(rp.k >= 0.0 and rp.k <= 1.0 and rp.open, "rapid taps leave it in one piece")
	for _i in 30:
		ms._process(1.0 / 30.0)
	await get_tree().process_frame
	await get_tree().process_frame
	_tap_button(ms, "HIDE DETAILS")
	for _i in 30:
		ms._process(1.0 / 30.0)
	check(not rp.open and rp.k == 0.0 and rp.rect(Vector2(480, 270)) == collapsed, "HIDE DETAILS rolls it back up")
	for sz in [Vector2(480, 270), Vector2(584, 270), Vector2(480, 320)]:
		rp.k = 1.0
		var rr := rp.rect(sz)
		check(rr.position.x >= 0.0 and rr.end.x <= sz.x and rr.end.y <= sz.y and rr.position.y >= 24.0, "fits a %dx%d screen opened" % [sz.x, sz.y])
		rp.k = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	_tap_button(ms, "CONTINUE >")
	await get_tree().process_frame
	check(Game.current_name == "title", "CONTINUE leaves a quick match for the menu")

# ------------------------------------------------------------------ the post-game summary
## Tap, tap, CONTINUE: one stage per tap, never two, and UP NEXT names the real next game.
## (The HOT reveal between FINAL and the round: tests/hot_reveal_test.gd.)
func test_summary() -> void:
	print("post-game summary")
	Store.reset_for_tests()
	Game.career = Career.new_game("WAGN", "A", "B", 57)
	var c := Game.career
	var guard := 0
	while not (c.has_game() and bool(c.my_game().get("c", false))) and guard < 60:
		if c.has_game():
			c.finish_my_game(MatchState.new().box(c.team()))
		else:
			c.end_week()
		guard += 1
	var st := MatchState.new()
	st.score = [6, 3]
	st.saves = [9, 5]
	var scorer: PoloPlayer = c.team().starters()[3]   # a perimeter man (the centre is expected to draw exclusions)
	scorer.form = [1, 1]   # two good games behind him: a third makes the run that heats him up
	for _i in 4:
		st.goal_by[0].append(scorer)
		st.shot_by[0].append(scorer)
	var wallet0 := c.wallet()
	c.last_summary = c.finish_my_game(st.box(c.team(), c.opponent()))
	check(int(c.last_summary.cr_before) == wallet0, "the summary knows the CR from before the game")
	var nxt := c.next_game()
	Store.starter_offered = true
	Game.goto("game_summary")
	await get_tree().process_frame
	await get_tree().process_frame
	var scr = Game.current_screen
	check(Game.current_name == "game_summary" and scr.stage == 0, "the summary opens on FINAL")
	check(scr.won and Schedule.score_text(scr.g, scr.s.home) == "6-3", "it shows this game's result")
	check(scr.league.size() > 0 and scr.league.all(func(gg): return gg != scr.g), "the rest of the conference's week, not your game")
	check(scr.league_title == "AROUND THE %s" % c.conf_abbr(), "conference play: AROUND THE %s" % c.conf_abbr())
	check(scr.league.all(func(gg): return (c.teams[gg.h] as PoloTeam).conf == c.team().conf or (c.teams[gg.a] as PoloTeam).conf == c.team().conf),
		"...with this conference's games")
	check(scr.bits.size() > 0, "a win gets its confetti")
	scr.t = 0.05
	scr.tap(Vector2(10, 10))
	check(scr.stage == 0, "a tap while the score is still landing does nothing")
	check(scr.form.size() == 7 and scr.form.all(func(r): return r.has("raw") and r.has("exp") and r.has("pm") and r.has("grade") and r.has("after")), "the seven are still graded: RAW, EXP, +/-, grade and form")
	var top: Dictionary = scr.form.filter(func(r): return r.p == scorer)[0]
	check(float(top.raw) >= 12.0 - 0.5 * 3 and int(top.grade) == PlayerForm.GOOD and top.after == PlayerForm.HOT, "4 goals from 4 shots: GOOD, his third in a row, and he's HOT (%+.1f vs %+.1f)" % [float(top.raw), float(top.exp)])
	scr.t = 1.0
	scr.tap(Vector2(10, 10))
	check(scr.stage == 1 and scr.heaters.any(func(h): return h.p == scorer), "a tap anywhere: he heated up, so the HOT reveal")
	scr.tap(Vector2(10, 10))
	check(scr.stage == 1, "a second tap straight away can't skip a stage")
	scr.t = 0.5
	scr.tap(Vector2(10, 10))
	check(scr.stage == 2, "another tap skips the reveal: the conference results")
	scr.t = 2.0
	scr.tap(Vector2(10, 10))
	check(scr.stage == 3, "another tap: UP NEXT")
	scr.t = 0.0
	check(scr.cr_shown() == scr.cr_before, "UP NEXT starts from the CR before the game")
	scr.t = 0.36 * 1.6 + 0.4
	var mid_cr: int = scr.cr_shown()
	check(mid_cr >= scr.cr_before and mid_cr <= scr.cr_after, "...counts up as the bar fills (%d)" % mid_cr)
	scr.t = 2.0
	check(scr.cr_shown() == scr.cr_after and scr.cr_after == c.wallet(), "...and ends on the CR now (%d)" % scr.cr_after)
	await get_tree().process_frame
	await get_tree().process_frame
	scr.tap(Vector2(2, 2))
	check(Game.current_name == "game_summary", "on UP NEXT, only CONTINUE continues")
	check(scr.cont_rect.size.x > 0.0, "CONTINUE is on screen")
	var wk := c.week
	scr.tap(scr.cont_rect.get_center())
	await get_tree().process_frame
	await get_tree().process_frame
	check(Game.current_name == "postgame_review", "CONTINUE goes on to the POSTGAME REVIEW")
	# UP NEXT named the game that really comes next (later this week, or next week)
	if not c.has_game():
		c.end_week()
	if nxt.get("tbd", false) or nxt.is_empty():
		check(true, "next game: %s" % str(nxt))
	else:
		var mg := c.my_game()
		var real_opp: String = mg.a if mg.h == c.school else mg.h
		check(c.week >= wk and c.week <= wk + 1 and real_opp == String(nxt.opp) and (mg.h == c.school) == bool(nxt.home),
			"UP NEXT was the real next game (%s)" % String(nxt.opp))
	# week one is non-conference: the whole country's results
	Game.career = Career.new_game("WAGN", "A", "B", 58)
	var c3 := Game.career
	check(c3.has_game() and not bool(c3.my_game().get("c", true)), "week one opens with a non-conference game")
	if c3.has_game() and not bool(c3.my_game().get("c", true)):
		var day := int(c3.my_game().d)
		var st3 := MatchState.new()
		st3.score = [2, 4]
		c3.last_summary = c3.finish_my_game(st3.box(c3.team()))
		Game.goto("game_summary")
		await get_tree().process_frame
		var s3 = Game.current_screen
		check(s3.league_title == "AROUND COLLEGE WATER POLO" and s3.league.size() == c3.cur().games.filter(func(gg): return int(gg.d) == day).size() - 1,
			"a non-conference game: AROUND COLLEGE WATER POLO, every other game that day")
		check(not s3.won and s3.bits.size() > 0, "a loss gets its blue drift")
	Game.goto("title")
	await get_tree().process_frame

# ------------------------------------------------------------------ the player profile
func test_profile() -> void:
	print("player profile")
	Store.reset_for_tests()
	Game.career = Career.new_game("WAGN", "A", "B", 61)
	var c := Game.career
	c.add_credits(500, "test")
	var team := c.team()
	var ids: Array = team.roster.map(func(q): return q.id)
	# the numbers: what isn't kept shows "-", save % from the games where both were kept
	check(load("res://src/ui/screens/player.gd").stat_text({"gp": 3}, "bl") == "-", "blocks not kept yet: -")
	check(load("res://src/ui/screens/player.gd").stat_text({"gp": 3, "sv": 20}, "sv%") == "-", "no goals allowed kept: no save %")
	check(load("res://src/ui/screens/player.gd").stat_text({"sva": 30, "ga": 10}, "sv%") == "75.0%", "save % = saves / (saves + allowed)")
	check(load("res://src/ui/screens/player.gd").stat_text({}, "g") == "0", "goals have always been kept: 0, not -")
	# a played game keeps the new numbers: your keeper's goals allowed, your blockers' blocks
	var st := MatchState.new()
	st.score = [5, 3]
	st.saves = [9, 4]
	var blocker: PoloPlayer = team.starters()[2]
	st.block_by[0].append(blocker)
	st.block_by[0].append(blocker)
	var box := st.box(team)
	box["injury_roll"] = false   # an injury would change who starts, and this is about the numbers
	c.finish_my_game(box)
	check(int(team.keeper().stats.get("ga", -1)) == 3 and int(team.keeper().stats.get("sva", -1)) == 9, "your keeper: 3 allowed, 9 saves")
	check(int(blocker.stats.get("bl", -1)) == 2, "your blocker: 2 blocks")
	check(team.starters().slice(1).all(func(x: PoloPlayer): return x.stats.has("bl")), "every field starter's blocks are kept from now on")
	var opp_gk_tracked := c.teams.values().filter(func(t2: PoloTeam): return t2 != team and t2.keeper().stats.has("ga")).size()
	check(opp_gk_tracked > 0, "the rest of the league's keepers keep goals allowed too")
	# the screen
	Game.goto("player", {"id": team.keeper().id, "list": ids})
	await get_tree().process_frame
	await get_tree().process_frame
	var scr = Game.current_screen
	check(Game.current_name == "player" and scr.p == team.keeper(), "the profile opens on the keeper")
	scr._process(1.0)
	# an upgrade (XP development: +1 to one attribute, up to its own ceiling, for one upgrade
	# token, tapped on its filled cyan box): in place, the attribute up one, the token spent, the
	# credits untouched, the box flashing, his OVERALL up a quarter
	var key: String = scr.p.key_ratings()[0]
	Attributes.set_ceiling(scr.p, key, 10.0)
	Attributes.set_value(scr.p, key, minf(scr.p.attr(key), 8.0))
	scr.p.tokens = 1
	var before: float = scr.p.attr(key)
	var wallet0 := c.wallet()
	var ovr0: float = scr.p.rating10()
	var ceil0: float = scr.p.potential10()
	scr._buy(key)
	check(Game.current_screen == scr and is_equal_approx(scr.p.attr(key), before + 1.0) and c.wallet() == wallet0 and scr.p.tokens == 0,
		"an upgrade: +1 for one token, no credits, on the same screen")
	check(String(scr.up.get("key", "")) == key and is_equal_approx(float(scr.up.from), before) and is_equal_approx(float(scr.up.to), before + 1.0), "...and its row animates from %.1f to %.1f" % [before, before + 1.0])
	check(is_equal_approx(scr.p.rating10(), ovr0 + 0.25) and is_equal_approx(scr.p.stars, Attributes.stars_of(scr.p.rating10())),
		"+0.25 OVERALL (one attribute is a quarter of it), his stars read again from it")
	check(is_equal_approx(scr.p.potential10(), ceil0), "an upgrade doesn't move his POTENTIAL")
	var again: float = scr.p.attr(key)
	scr._buy(key)
	check(is_equal_approx(scr.p.attr(key), again) and scr.p.tokens == 0, "no token left: another tap does nothing")
	# no count limit but tokens: a field player with room takes a dozen upgrades, one token each
	var fp: PoloPlayer = team.starters()[1]
	for fk in fp.key_ratings():
		fp.attr_pot[fk] = 10.0
		fp.attrs[fk] = 5.0
	Attributes.sync(fp)
	fp.tokens = 12
	var bought := 0
	for i in 12:
		var bk: String = fp.key_ratings()[i % fp.key_ratings().size()]
		var w0 := c.wallet()
		var r0 := fp.attr(bk)
		if c.boost(fp, bk) and is_equal_approx(fp.attr(bk), r0 + 1.0) and c.wallet() == w0:
			bought += 1
	check(bought == 12 and fp.tokens == 0, "twelve upgrades across his attributes, each +1 for one token (%d)" % bought)
	check(fp.rating10() <= fp.potential10(), "...and his CURRENT never passes his POTENTIAL")
	# MAXED at 10; at its own ceiling refused, and no token spent
	fp.tokens = 2
	Attributes.set_value(fp, "sho", 10.0)
	check(c.boost_limit(fp, "sho") == "MAXED" and not c.boost(fp, "sho") and fp.tokens == 2, "an attribute at 10 is MAXED")
	Attributes.set_ceiling(fp, "pas", fp.attr("pas"))
	var hr0 := fp.attr("pas")
	check(c.boost_limit(fp, "pas") == "CEILING" and not c.boost(fp, "pas") and fp.tokens == 2 and is_equal_approx(fp.attr("pas"), hr0),
		"an upgrade past his ceiling for it is refused, and no token is spent")
	for fk in fp.key_ratings():
		fp.attr_pot[fk] = 10.0
		fp.attrs[fk] = 5.0
	Attributes.sync(fp)
	# no tokens: no cyan box to tap; a token: one in every row with room
	fp.tokens = 0
	Game.goto("player", {"id": fp.id, "list": ids})
	await get_tree().process_frame
	scr = Game.current_screen
	var boost_buttons := func() -> Array:
		var out: Array = []
		var stack: Array = [scr.body]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is Button and not n.is_queued_for_deletion() and String(n.name).begins_with("Up_") and (n as Button).visible:
				out.append(n)
			stack.append_array(n.get_children())
		return out
	var bb: Array = boost_buttons.call()
	check(bb.is_empty(), "no upgrade tokens: no box to buy")
	fp.tokens = 1
	scr._refresh()
	await get_tree().process_frame
	bb = boost_buttons.call()
	check(bb.size() == fp.key_ratings().size() and bb.all(func(b): return not b.disabled), "a token: every attribute with room has its cyan box")
	check(bb.all(func(b): return b.size.x == (bb[0] as Button).size.x), "...all the same size")
	# purchases stay through a save and a new season
	var saved_r := fp.rating("passing")
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	var fp2: PoloPlayer = back.team().find_id(fp.id)
	check(fp2.rating("passing") == saved_r and fp2.tokens == fp.tokens and fp2.xp_level == fp.xp_level, "upgrades and tokens survive a save")
	back.start_season()
	check(fp2.rating("passing") == saved_r and fp2.tokens == fp.tokens, "a new season: same ratings, tokens kept")
	# no FORM, TRAIT, LAST GAME, numeric overall or hidden level on the page (form shows on the roster)
	var page_text := []
	var tstack: Array = [scr.body]
	while not tstack.is_empty():
		var n: Node = tstack.pop_back()
		if n is Label:
			page_text.append((n as Label).text)
		tstack.append_array(n.get_children())
	var gone := RegEx.create_from_string("FORM|TRAIT|LAST GAME|OVR|CEILING|MAXED|LEVEL|\\bLV\\b|\\d+\\.\\d")
	check(not page_text.any(func(x): return gone.search(String(x)) != null), "the page shows no form, trait, ratings as numbers, levels or MAXED (%s)" % [page_text])
	Game.goto("player", {"id": team.keeper().id, "list": ids})
	await get_tree().process_frame
	scr = Game.current_screen
	# an injury: no banner, no recovery button, no rush recovery; the note says what it is
	var hurt: PoloPlayer = scr.p
	Development.heal(hurt)
	hurt.tokens = 0
	var rng_i := RandomNumberGenerator.new()
	rng_i.seed = 5
	Development.injure(hurt, rng_i, "moderate")
	var wallet1 := c.wallet()
	scr._refresh()
	await get_tree().process_frame
	check(not scr.has_method("_rush") and not "folding" in scr, "no injury banner, recovery button or rush recovery on the page")
	var head: Control = scr.find_child("Heading_PLAYER_ATTRIBUTES", true, false)
	check(head != null and String(head.get_meta("aside")) == "INJURED — MODERATE HEAD" and c.wallet() == wallet1, "the injury is noted in words over the boxes (%s)" % (String(head.get_meta("aside")) if head else "-"))
	Development.heal(hurt)
	Game.goto("title")
	await get_tree().process_frame

# ------------------------------------------------------------------ the game clock
## Four 2:00 quarters; the clock runs in real time with live play (1.0x).
func test_clock() -> void:
	print("game clock")
	var st := MatchState.new()
	check(st.clock_text() == "2:00", "a game starts at 2:00 (%s)" % st.clock_text())
	# the clock runs at 1.25x: a 2:00 quarter is 96 real seconds of play
	var marks := {8.0: "1:50", 16.0: "1:40", 48.0: "1:00", 96.0: "0:00"}
	var done := 0.0
	for real in [8.0, 16.0, 48.0, 96.0]:
		st.run(real - done)
		done = real
		check(st.clock_text() == marks[real], "%d real seconds in: %s (%s)" % [real, marks[real], st.clock_text()])
	check(st.quarter_over(), "96 real seconds is a whole quarter")
	st.run(5.0)
	check(st.clock == 0.0 and st.clock_text() == "0:00", "the clock never goes below 0:00")
	for q in range(2, 5):
		st.next_quarter()
		check(st.quarter == q and st.clock_text() == "2:00", "Q%d starts at 2:00" % q)
	# a live possession: 10 s of play takes 12.5 s off the game clock and the shot clock; the
	# swimmers run at normal speed
	var teams := _teams()
	var f := MatchFlow.new(teams[0], teams[1], 77, MatchState.QUARTER_MIN)
	f._start_attack(Play.Kind.COUNTER)   # no swim-in time taken off
	var p := f.play
	var c0 := f.state.clock
	var sc0 := p.shot_clock
	var h := p.holder
	var top := h.top_speed
	var moved := 0.0
	var last := h.pos
	for _i in 300:
		f.tick_attack(1.0 / 30.0)
		moved = maxf(moved, h.pos.distance_to(last) * 30.0)
		last = h.pos
		if p.over or p.holder != h:
			break
	check(p.holder == h and not p.over, "nobody took the ball in 10 s")
	# (a foul whistle in there stops both clocks: compare with the live seconds actually played)
	print("  10 real seconds: %.2f s live, %.2f s off the game clock, %.2f s off the shot clock" % [p.elapsed, c0 - f.state.clock, sc0 - p.shot_clock])
	check(p.elapsed > 8.0 and p.elapsed <= 10.01, "the play ran in real time (%.2f s live)" % p.elapsed)
	check(absf((c0 - f.state.clock) - p.elapsed * MatchState.CLOCK_SPEED) < 0.05, "the game clock lost 1.25x the live time")
	check(absf((sc0 - p.shot_clock) - p.elapsed * MatchState.CLOCK_SPEED) < 0.05, "the shot clock lost the same")
	check(moved <= top * 1.3 + 0.01 and h.top_speed == top, "swimmers swim at their normal speed (%.2f m/s, top %.2f)" % [moved, top])
	check(Engine.time_scale == 1.0, "the engine runs at normal speed")
	# stoppages: a whistle stops the clock, play on starts it again
	p.freeze = 1.0
	var c1 := f.state.clock
	for _i in 15:
		f.tick_attack(1.0 / 30.0)
	check(f.state.clock == c1, "a whistle stops the clock")
	for _i in 45:
		f.tick_attack(1.0 / 30.0)
	check(f.state.clock < c1 - 0.5, "it runs again after the whistle")
	# a goal stops it: nothing runs between the end of a possession and the next
	p._finish("goal", "GOAL!", {"scorer": h.player})
	var c2 := f.state.clock
	for _i in 30:
		f.tick_attack(1.0 / 30.0)
	check(f.state.clock == c2, "the clock is stopped after a goal")
	# a quarter: runs out at 0:00, the next one starts at 2:00
	var g := MatchFlow.new(teams[0], teams[1], 78, MatchState.QUARTER_MIN)
	g._start_attack(Play.Kind.COUNTER)
	g.state.clock = 3.0
	for d in g.play.defenders:
		d.pos.x = 2.0   # nobody gets back to him: this is about the clock
	var guard := 0
	while not g.play.over and guard < 300:
		g.tick_attack(1.0 / 30.0)
		guard += 1
	check(g.play.over and g.state.clock == 0.0, "the quarter runs out at 0:00 (%s)" % g.state.clock_text())
	check(guard >= 70 and guard <= 74, "3 game seconds go in 2.4 real seconds (%d frames)" % guard)
	g.attack_done()
	check(g.phase == MatchFlow.Phase.BREAK, "the quarter break follows")
	g.break_done()
	check(g.state.quarter == 2 and g.state.clock_text() == "2:00" and g.phase == MatchFlow.Phase.SPRINT, "Q2 starts at 2:00 with a sprint")
	# pausing the match screen freezes the clock
	Game.match_cfg = {"us": teams[0], "them": teams[1], "seed": 9}
	Game.goto("match", Game.match_cfg)
	await get_tree().process_frame
	var ms = Game.current_screen
	check(is_equal_approx(ms.flow.state.clock, MatchState.QUARTER_MIN * 60.0), "a match from the menus has 2:00 quarters")
	ms.flow._start_attack(Play.Kind.COUNTER)
	ms._process(1.0 / 30.0)
	ms.paused = true
	var c3: float = ms.flow.state.clock
	for _i in 60:
		ms._process(1.0 / 30.0)
	check(ms.flow.state.clock == c3, "pausing freezes the game clock")
	ms.paused = false
	Game.goto("title")
	await get_tree().process_frame

# ------------------------------------------------------------------ event banners
## The big plays get the GOAL! banner treatment, one at a time, by priority; only real
## events trigger them, and they never stop the play.
func _feed(ms, p: Play) -> void:
	ms.flow.events.clear()
	for e in p.events:
		ms.flow.events.append(e)
	p.events.clear()
	ms._handle_events()

func test_banners() -> void:
	print("gameplay callouts")
	# the component on its own: one style, priority, timing, no repeats
	var b := EventBanner.new()
	var dur := EventBanner.DUR
	check(dur >= 0.8 and dur <= 1.2, "every callout is up about a second")
	var want := {"goal": ["GOAL!", "ffd83d"], "steal": ["STEAL!", "45dfff"], "block": ["BLOCK!", "ffd83d"],
		"save": ["SAVE!", "45dfff"], "exclusion": ["EXCLUSION!", "ff4545"], "penalty": ["PENALTY!", "ff4545"],
		"turnover": ["TURNOVER!", "ffffff"], "timeout": ["TIMEOUT!", "ffd83d"], "foul": ["FOUL!", "ffffff"]}
	for k in want:
		b.clear()
		b.event(k)
		check(b.text() == want[k][0] and (b.cur.col as Color).to_html(false) == want[k][1], "%s in its colour" % want[k][0])
		b.step(dur + 0.01)
		check(b.is_empty(), "%s goes by itself" % want[k][0])
	var order := ["goal", "penalty", "exclusion", "block", "steal", "turnover"]
	for x in order.size():
		for y in range(x + 1, order.size()):
			b.clear()
			b.event(order[x])
			b.event(order[y])
			check(b.kind() == order[x], "%s isn't interrupted by %s" % [order[x], order[y]])
	b.clear()
	b.event("block")
	b.event("steal")
	b.show("WIDE!")
	check(b.kind() == "block", "nothing smaller cuts a callout short")
	b.step(dur + 0.01)
	check(b.text() == "STEAL!", "...the bigger one waiting shows next; a stale plain one is dropped")
	b.step(dur + 0.01)
	check(b.is_empty(), "...and then nothing")
	b.clear()
	b.event("save")
	b.step(0.4)
	b.event("save")
	check(is_equal_approx(float(b.cur.t), 0.4), "the same callout twice doesn't show twice")
	b.clear()
	b.show("DRIVE LEFT!")
	b.event("foul")
	check(b.kind() == "foul", "a named event replaces a plain callout")
	# in a real match screen, from the real events
	Game.match_cfg = {"us": League.make_team(2, 1), "them": League.make_team(3, 1), "seed": 9, "minutes": 2.0}
	Game.goto("match", Game.match_cfg)
	await get_tree().process_frame
	var ms = Game.current_screen
	var f: MatchFlow = ms.flow
	var new_attack := func() -> Play:
		f._start_attack(Play.Kind.HALF_COURT)
		ms.banner.clear()
		return f.play
	var new_defense := func() -> Play:
		f._start_defense(Play.Kind.HALF_COURT)
		ms.banner.clear()
		return f.play
	# 1) you score, 2) they score
	var p: Play = new_attack.call()
	p._finish("goal", "GOAL!", {"scorer": p.attackers[1].player})
	_feed(ms, p)
	check(ms.goal_show.active() and ms.goal_show.side == 0 and ms.banner.is_empty(), "your goal: the goal show (GOAL!), not a callout")
	p = new_defense.call()
	p._finish("goal", "GOAL!", {"scorer": p.attackers[1].player})
	_feed(ms, p)
	check(ms.goal_show.active() and ms.goal_show.side == 1 and ms.banner.is_empty(), "their goal: the goal show (GOAL!)")
	# 3) you steal it, 4) they steal it from you (picked off)
	p = new_defense.call()
	p._turnover(p._marker(p.holder), "STOLEN!", "steal")
	_feed(ms, p)
	check(ms.banner.kind() == "steal" and ms.banner.text() == "STEAL!", "your steal: STEAL!")
	p = new_attack.call()
	p._turnover(p.defenders[2], "PICKED OFF!", "steal")
	_feed(ms, p)
	check(ms.banner.kind() == "steal", "their steal: STEAL!")
	# 9) a loose ball picked up, or the keeper claiming a pass, is no steal
	p = new_attack.call()
	p._turnover(p.defenders[2], "THEIR BALL", "turnover")
	_feed(ms, p)
	check(ms.banner.kind() == "turnover", "a loose-ball pickup is no STEAL!: TURNOVER!")
	p = new_attack.call()
	p._turnover(p.keeper, "KEEPER CLAIMS IT", "steal")
	_feed(ms, p)
	check(ms.banner.kind() == "turnover", "the keeper claiming a pass is no STEAL!: TURNOVER!")
	p = new_defense.call()
	p._turnover(p.keeper, "KEEPER CLAIMS IT", "steal")
	_feed(ms, p)
	check(ms.banner.kind() == "turnover", "...nor your keeper claiming theirs")
	# saves (and a parry), fouls, exclusions, penalties: the same strip
	p = new_attack.call()
	p._finish("save", "SAVED!", {"shooter": p.attackers[1].player})
	_feed(ms, p)
	check(ms.banner.kind() == "save", "their keeper saves: SAVE!")
	p = new_attack.call()
	p.events.append({"k": "rebound", "text": "PARRIED!"})
	_feed(ms, p)
	check(ms.banner.kind() == "save", "a parry: SAVE!")
	p = new_attack.call()
	p.events.append({"k": "foul"})
	_feed(ms, p)
	check(ms.banner.kind() == "foul", "a foul: FOUL!")
	p = new_defense.call()
	p.events.append({"k": "exclusion", "text": "EXCLUSION"})
	_feed(ms, p)
	check(ms.banner.kind() == "exclusion", "an exclusion: EXCLUSION!")
	p = new_attack.call()
	p._finish("penalty", "PENALTY!", {"fouled": p.attackers[1].player})
	_feed(ms, p)
	check(ms.banner.kind() == "penalty", "a penalty: PENALTY!")
	check(not ("flash" in ms), "no second callout system on the screen")
	# 5, 6) a block either way; 10) block then the defender gathers it: BLOCK!, then the result
	p = new_attack.call()
	p.events.append({"k": "block", "by": p.defenders[0].player, "at": p.ball.pos})
	_feed(ms, p)
	check(ms.banner.kind() == "block" and ms.banner.text() == "BLOCK!", "their defender blocks you: BLOCK!")
	p._turnover(p.defenders[0], "THEIR BALL", "turnover")
	_feed(ms, p)
	check(ms.banner.kind() == "block", "the pickup straight after doesn't cut the block's banner short")
	ms.banner.step(dur + 0.01)
	check(ms.banner.text() == "TURNOVER!", "...then the result shows")
	p = new_defense.call()
	p.events.append({"k": "block", "by": p.defenders[1].player, "at": p.ball.pos})
	_feed(ms, p)
	check(ms.banner.kind() == "block", "your defender blocks them: BLOCK!")
	# 11) a goal after a block: GOAL! wins
	p._finish("goal", "GOAL!", {"scorer": p.attackers[1].player})
	_feed(ms, p)
	check(ms.goal_show.active() and ms.banner.is_empty(), "a goal straight after a block: the goal show takes over")
	# 12) the game goes on under a block's banner, and taps still play
	p = new_attack.call()
	ms._process(1.0 / 30.0)   # the screen sees the new possession start
	p.events.append({"k": "block", "by": p.defenders[0].player, "at": p.ball.pos})
	_feed(ms, p)
	var before := p.elapsed
	for _i in 10:
		ms._process(1.0 / 30.0)
	check(p.elapsed > before and not ms.banner.is_empty(), "the play runs on under the banner")
	ms._press(Vector2(200, 150), 0)
	check(ms.aim.active, "a touch under the banner still starts a pass or a shot")
	ms.aim.cancel()
	for _i in 30:
		ms._process(1.0 / 30.0)
	check(ms.banner.kind() != "block", "the block's banner goes by itself")
	# 7, 8) only a real touch is a block: a missed attempt or a keeper save sends no block event
	var block_events_ok := true
	var misses := 0
	var saves := 0
	for sd in 120:
		var q := _staged(Vector2(23.0, 10.0), Vector2(26.6, 10.0 + (sd % 7) * 0.12), 1200 + sd)
		q._shoot(8.9 if sd % 2 == 0 else 11.1, 0.8)
		var sh: Dictionary = q.ball.shot
		var guard := 0
		while q.ball.state == Ball.State.SHOT and guard < 200:
			q.step(1.0 / 60.0)
			guard += 1
		var sent := q.events.filter(func(e): return e.k == "block").size()
		if sent != (1 if String(sh.outcome) == "block" else 0):
			block_events_ok = false
		if not (sh.attempts as Array).is_empty() and String(sh.outcome) != "block":
			misses += 1
		if String(sh.outcome) in ["save", "parry"]:
			saves += 1
	check(block_events_ok, "a BLOCK! only when a defender touches the ball")
	check(misses > 5 and saves > 5, "...not for the %d missed attempts or the %d keeper saves" % [misses, saves])
	Game.goto("title")
	await get_tree().process_frame

# ------------------------------------------------------------------ players: tiers and traits
## Traits come from ratings alone (the same every time), only good players get one, saves
## keep them and old saves get them filled in; 76+ OVR players are a minority of every league.
func test_traits() -> void:
	print("traits")
	# (2.0: a trait comes from his attributes: one of the best, OVERALL 9+, with the attribute it's
	# about maxed out)
	var mk := func(pos: int, sht: float, pas: float, stren: float, dfn: float, lefty := false) -> PoloPlayer:
		var q := AttrBench.player({"sho": sht, "pas": pas, "str": stren, "dfn": dfn}, false, {}, pos)
		q.lefty = lefty
		return q
	check(Traits.best_for(mk.call(PoloPlayer.Pos.WING, 10, 9, 9, 9)) == "cannon", "a big shooter is a CANNON")
	check(Traits.best_for(mk.call(PoloPlayer.Pos.DRIVER, 9.6, 9.5, 9, 9, true)) == Traits.best_for(mk.call(PoloPlayer.Pos.DRIVER, 9.6, 9.5, 9, 9)), "a lefty's trait is a righty's: no lefty bonus")
	check(Traits.best_for(mk.call(PoloPlayer.Pos.CENTER, 9.5, 9, 10, 9.5)) == "wrestler", "a strong center is a WRESTLER")
	var fast: PoloPlayer = mk.call(PoloPlayer.Pos.DRIVER, 7, 7, 7, 7)
	fast.speed = 90
	check(Traits.best_for(fast) == "jet", "a fast driver is a JET")
	check(Traits.best_for(mk.call(PoloPlayer.Pos.UTILITY, 10, 6, 6, 6)) == "", "a sniper who isn't one of the best has no trait")
	check(Traits.best_for(mk.call(PoloPlayer.Pos.UTILITY, 5, 5, 5, 5)) == "", "an ordinary player has no trait")
	var gk := AttrBench.player({"com": 9, "lun": 9, "blk": 10, "leg": 9}, true)
	check(Traits.best_for(gk) == "wall" and Traits.best_for(gk) == Traits.best_for(gk), "a great keeper is a WALL, every time")
	# a career: the seven-man rosters are built to their stars (a five-star rates highest), traits
	# are a minority and survive a save, an old save gets them filled in
	var c := Career.new_game("WAGN", "A", "B", 55)
	var all: Array = []
	for id in c.teams:
		all.append_array((c.teams[id] as PoloTeam).roster)
	var traited := all.filter(func(q: PoloPlayer): return q.trait_id != "").size()
	var by_star := {}
	for q: PoloPlayer in all:
		by_star[q.stars] = (by_star.get(q.stars, []) as Array) + [q.overall()]
	var avg := func(a: Array) -> float: return a.reduce(func(x, v): return x + v, 0.0) / maxf(1.0, a.size())
	print("  %d players: %d with a trait; overall by stars %s" % [all.size(), traited, ", ".join(by_star.keys().map(func(k): return "%.1f*: %.1f" % [k, avg.call(by_star[k])]))])
	check_between(traited / float(all.size()), 0.04, 0.15, "players with a trait are a minority")
	var tiers: Array = by_star.keys()
	tiers.sort()
	var rising := tiers.size() >= 3
	for i in range(1, tiers.size()):
		rising = rising and avg.call(by_star[tiers[i]]) > avg.call(by_star[tiers[i - 1]])
	check(rising, "the more stars, the better his ratings (%s)" % [tiers])
	# one 0-99 rating everywhere: CURRENT never above CEILING; stars are separate (PlayerForm)
	check(all.all(func(q: PoloPlayer): return q.ovr() >= 0 and q.ovr() <= 99 and q.ceiling() >= q.ovr() and q.ceiling() <= 99),
		"every player: 0 <= CURRENT <= CEILING <= 99")
	check(all.all(func(q: PoloPlayer): return q.stars >= 0.0 and q.stars <= 5.0 and q.pot_stars >= q.stars and q.pot_stars <= 5.0), "every player's CURRENT and POTENTIAL stars are 0-5, POTENTIAL at least CURRENT")
	for pos in PoloPlayer.Pos.values():
		var w := PoloPlayer.new()
		w.pos = pos
		for k in ["shoot", "passing", "speed", "strength", "defense", "keeping"]:
			w.set(k, 100)
		check(is_equal_approx(w.overall(), 100.0), "%s weights add up to 100%%" % PoloPlayer.POS_LONG[pos])
	var cap := PoloPlayer.new()
	cap.pos = PoloPlayer.Pos.GK
	cap.keeping = 100
	cap.passing = 100
	cap.speed = 100
	cap.pot = 120.0
	check(cap.ovr() == 99 and cap.ceiling() == 99, "OVR and CEILING top out at 99")
	var gk2 := PoloPlayer.new()
	gk2.pos = PoloPlayer.Pos.GK
	gk2.keeping = 70
	gk2.passing = 40
	gk2.speed = 40
	check(gk2.ovr() == 64, "a keeper is mostly his keeping (70 / 40 / 40 -> %d)" % gk2.ovr())
	# the recruiting market: eight prospects from the start, unscouted
	var rc := Career.new_game("WAGN", "A", "B", 64)
	check(rc.market.size() == Recruiting.MARKET_SIZE and not rc.market.any(func(r): return r.has("sc")), "a new career has its recruiting market (no scouting)")
	check(traited > 0 and traited < all.size() / 3, "traits are for the good players (%d of %d)" % [traited, all.size()])
	var d := c.to_dict()
	var c2 := Career.from_dict(JSON.parse_string(JSON.stringify(d)))
	var same := true
	for id in c.teams:
		var r1: Array = (c.teams[id] as PoloTeam).roster
		var r2: Array = (c2.teams[id] as PoloTeam).roster
		for i in r1.size():
			if (r1[i] as PoloPlayer).trait_id != (r2[i] as PoloPlayer).trait_id:
				same = false
	check(same, "a save keeps every trait")
	var old: Dictionary = JSON.parse_string(JSON.stringify(d))
	old.v = 1
	for id in old.teams:
		for pd in old.teams[id].roster:
			pd.erase("trait_id")
	var c3 := Career.from_dict(old)
	var filled := true
	for id in c3.teams:
		for q: PoloPlayer in (c3.teams[id] as PoloTeam).roster:
			if q.trait_id != Traits.best_for(q):
				filled = false
	check(filled, "an old save gets its traits filled in from the ratings")

# ------------------------------------------------------------------ shooting, counters, clock, stats
## Goal rate for one shot situation (ShotModel alone: no field defenders).
func _rate(from: Vector2, aim_y: float, keeper_y: float, ctx: Dictionary = {}, pressure := 5.0, n := 3000) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var goals := 0
	for i in n:
		if ShotModel.resolve(from, aim_y, 0.8, 65.0, pressure, [], keeper_y, 62.0, rng, false, {}, ctx).outcome == "goal":
			goals += 1
	return goals / float(n)

## Their attack set up in the half court, the ball with `tag`, and his defender takes it off him.
func _steal_from(tag: String, seed_value: int) -> Play:
	var teams := _teams()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var p := Play.new(teams[0], teams[1], Play.Kind.HALF_COURT, rng)
	for s in p.bodies():
		if not s.keeper:
			s.pos = s.home if s.side == Swimmer.Side.US else s.mark.pos + (Geo.goal_center() - s.mark.pos).normalized() * 1.0
		s.pos += Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3))
	var a := PlaySetup._by_tag(p, tag)
	p.give_ball(a)
	var d := p._marker(a)
	p._turnover(d, "STOLEN!", "steal")
	return p

func test_gameplay() -> void:
	print("shooting")
	var cs := {"catch_t": 0.3}
	# 1) catch and shoot beats holding it, fading out after the window; never automatic
	var held := _rate(Vector2(24.5, 10.5), 11.2, 10.0)
	var caught := _rate(Vector2(24.5, 10.5), 11.2, 10.0, cs)
	var late := _rate(Vector2(24.5, 10.5), 11.2, 10.0, {"catch_t": 0.75})
	var gone := _rate(Vector2(24.5, 10.5), 11.2, 10.0, {"catch_t": 2.5})
	print("  5.5 m corner: held %.2f, caught and shot %.2f, after 0.75 s %.2f, after 2.5 s %.2f" % [held, caught, late, gone])
	check(caught > held + 0.04, "catch and shoot scores more often than a held ball")
	check(late > held and late < caught, "the catch-and-shoot bonus fades after the window")
	check(absf(gone - held) < 0.02, "...and is gone once he's held it")
	check(caught < 0.95, "a catch and shoot is not an automatic goal")
	check(ShotModel.catch_shoot(0.45) == 1.0 and ShotModel.catch_shoot(1.0) == 0.0 and ShotModel.catch_shoot(INF) == 0.0,
		"full bonus for 0.5 s after the catch, gone by 1 s")
	# 2) cross-cage: from the wing, the far post beats the near post, more so with the keeper cheating
	var wing := Vector2(25.5, 13.5)
	var far_shaded := _rate(wing, 8.8, 10.7)
	var far_central := _rate(wing, 8.8, 10.0)
	var near_shaded := _rate(wing, 11.2, 10.7)
	var near_open := _rate(wing, 11.2, 9.3)   # the near post with the keeper cheating the other way
	print("  wing: far post %.2f (keeper on the near post) / %.2f (keeper central), near post %.2f" % [far_shaded, far_central, near_shaded])
	# (since the keeper overhaul he reacts to the ball rather than guessing: from the wing at 5.7 m
	# neither post is his in time unless he went early, so the near post is no longer the safe one
	# for him it was when his guess covered it; the cross-cage edge is the keeper's shading, below)
	check(far_shaded > far_central + 0.15, "cross-cage is best with the keeper on the near post")
	check(ShotModel.cross_cage(wing, 8.8, 10.7) > ShotModel.cross_cage(wing, 8.8, 10.0), "the cross-cage factor follows the keeper")
	check(ShotModel.cross_cage(Vector2(24.0, 10.1), 8.8, 10.0) == 0.0, "straight on there's no cross-cage")
	check(ShotModel.cross_cage(Vector2(29.0, 16.0), 8.8, 10.7) < ShotModel.cross_cage(wing, 8.8, 10.7), "from a very sharp angle it fades out")
	check(ShotModel.cross_cage(wing, 11.2, 10.7) == 0.0, "the near post is no cross-cage shot")
	check(near_open >= near_shaded, "the open near post (keeper cheating away) is a good shot too")
	check(_rate(Vector2(28.0, 15.5), 8.8, 10.9, {}, 2.0) < _rate(Vector2(26.0, 12.0), 8.8, 10.4, {}, 2.0), "a poor angle is still harder")
	# 3) the keeper's position decides it: out of position he can't make the save
	var beaten := _rate(Vector2(26.0, 10.5), 8.7, 11.0)
	var set_there := _rate(Vector2(26.0, 10.5), 8.7, 9.0)
	print("  4 m to 8.7: keeper at 11.0 %.2f, keeper at 9.0 %.2f" % [beaten, set_there])
	check(beaten > 0.7 and beaten > set_there + 0.15, "the keeper's position decides it (%.2f vs %.2f)" % [beaten, set_there])
	var pb := _rate(Vector2(28.3, 10.2), 11.25, 9.0, {}, 0.8)
	check(pb > 0.8, "point blank into the corner he's left open is no save (%.2f)" % pb)
	# 4) the centre's defender doesn't block shots; a help defender in the same spot does
	var help_blocks := 0
	var centre_blocks := 0
	for sd in 200:
		for centre in [false, true]:
			var q := _staged(Vector2(24.0, 10.5), Vector2(25.0, 10.6), 3000 + sd)
			if centre:
				var swap := q.defenders[0].mark
				q.defenders[0].mark = q.defenders[1].mark
				q.defenders[1].mark = swap   # back on the centre
			q._shoot(11.25, 0.75)
			if String(q.ball.shot.outcome) == "block":
				if centre:
					centre_blocks += 1
				else:
					help_blocks += 1
	print("  in the lane: help defender blocked %d/200, the centre's defender %d/200" % [help_blocks, centre_blocks])
	check(centre_blocks == 0 and help_blocks > 20, "the centre's defender never blocks; a help defender does")
	check(not Play.CENTER_DEFENDER_BLOCKS, "centre-defender blocks are switched off (one constant)")
	# 5) no position bonus: the old centre-only power shot is gone. A close-range chance is
	# dangerous from where it is (tests/ai_overhaul_test.gd: close range, its aiming tolerance)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var any_power := false
	for i in 2000:
		var r := ShotModel.resolve(Vector2(28.0, 10.0), 11.2, 0.8, 65.0, 0.8, [], 10.3, 62.0, rng, false, {}, {"center": true})
		any_power = any_power or bool(r.power_shot)
	check(not any_power, "no shot is a power shot for being the centre's")

	print("counterattacks")
	# 6-8) off real steals in whole matches: not every steal a break, a man up on every one, nobody
	# back uncommon (steals are rare now, so the variety is checked on forced steals below)
	var numbers := {}
	var carriers := {}
	var changes := 0
	var breaks := 0
	for i in 40:
		var teams := [League.make_team(i % 8, 0), League.make_team((i + 3) % 8, 0)]
		var f := MatchFlow.new(teams[0], teams[1], 2000 + i, MatchState.QUARTER_MIN)
		var steps := 0
		while f.phase != MatchFlow.Phase.FINAL and steps < 200000:
			steps += 1
			match f.phase:
				MatchFlow.Phase.SPRINT:
					f.sprint_done(f.rng.randf() < 0.5)
				MatchFlow.Phase.ATTACK, MatchFlow.Phase.DEFENSE:
					if f.phase == MatchFlow.Phase.ATTACK:
						_run_flow_attack(f)
					else:
						f.auto_defense(0.5)
					var o := String(f.play.result.get("outcome", ""))
					if f.phase == MatchFlow.Phase.ATTACK:
						f.attack_done()
					else:
						f.defense_done()
					if o in ["steal", "turnover"] and f.play != null and f.phase in [MatchFlow.Phase.ATTACK, MatchFlow.Phase.DEFENSE]:
						changes += 1
						if f.play.kind == Play.Kind.COUNTER:
							breaks += 1
							var k := "%d on %d" % [f.play.break_n.x, f.play.break_n.y]
							numbers[k] = int(numbers.get(k, 0)) + 1
							carriers[f.play.holder.player] = true
				MatchFlow.Phase.SHOOTOUT_THEM:
					f.their_ball_done()
				MatchFlow.Phase.THEIR_SHOT:
					f.auto_duel(0.5)
					f.duel_done()
				MatchFlow.Phase.BREAK:
					f.break_done()
	print("  %d steals and turnovers, %d breaks: %s, %d different carriers" % [changes, breaks, str(numbers), carriers.size()])
	check(breaks > 0 and breaks < changes, "some steals are breaks, some just the ball")
	var open_breaks := int(numbers.get("3 on 0", 0)) + int(numbers.get("2 on 0", 0)) + int(numbers.get("1 on 0", 0))
	check(open_breaks <= changes * 0.05 and open_breaks <= breaks * 0.3,
		"nobody back is uncommon (%d of %d changes of possession, %d of %d breaks)" % [open_breaks, changes, open_breaks, breaks])
	var level_break := false
	for k: String in numbers:
		var parts := k.split(" on ")
		if int(parts[0]) <= int(parts[1]):
			level_break = true
	check(not level_break, "every counter off a real steal has a man up")
	# a steal forced at a random moment of a live possession: varied numbers, varied carriers
	var f_numbers := {}
	var f_carriers := {}
	var f_breaks := 0
	for sd in 600:
		var fr := RandomNumberGenerator.new()
		fr.seed = 6000 + sd
		var lp := Play.new(_teams()[0], _teams()[1], Play.Kind.HALF_COURT, fr)
		var stop := fr.randf_range(0.5, 12.0)
		var lt := 0.0
		var think := 0.0
		while lt < stop and not lp.over:
			think -= 1.0 / 30.0
			if think <= 0.0:
				think = PlayBot.THINK_EVERY
				var dd := PlayBot.think(lp, fr)
				if not dd.is_empty() and lp.aim_info(dd.target).mode == "pass":
					lp.throw(dd.target, dd.power)   # (passes only: keep the ball alive)
			lp.step(1.0 / 30.0)
			lt += 1.0 / 30.0
		if lp.over or lp.holder == null or lp.ball.state != Ball.State.HELD:
			continue
		lp._turnover(lp._marker(lp.holder), "STOLEN!", "steal")
		var c := Play.new(lp.them, lp.us, Play.Kind.COUNTER, fr, lp.snapshot())
		if c.kind == Play.Kind.COUNTER:
			f_breaks += 1
			f_numbers["%d on %d" % [c.break_n.x, c.break_n.y]] = true
			f_carriers[c.holder.player] = true
	print("  forced steals in live play: %d breaks: %s, %d different carriers" % [f_breaks, str(f_numbers.keys()), f_carriers.size()])
	check(f_numbers.size() >= 3, "breaks come in different numbers")
	check(f_carriers.size() >= 8, "different players lead the break")
	# 7) steals at the top of their arc: usually the defence is getting back
	var contested := 0
	var top_breaks := 0
	var tops := {}
	for sd in 200:
		var lost := _steal_from("3", 4000 + sd)
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = 5000 + sd
		var c := Play.new(lost.them, lost.us, Play.Kind.COUNTER, rng2, lost.snapshot())
		if c.kind == Play.Kind.COUNTER:
			top_breaks += 1
			if c.break_n.y >= 1:
				contested += 1
			var k := "%d on %d" % [c.break_n.x, c.break_n.y]
			tops[k] = int(tops.get(k, 0)) + 1
	print("  steals at the top: %d of 200 breaks: %s" % [top_breaks, str(tops)])
	check(top_breaks > 0 and contested >= top_breaks * 0.75, "a break off a steal at the top usually has defenders getting back (%d/%d)" % [contested, top_breaks])
	# 9-10) the carrier swims it in to 3 m (never parking it further out while the break is on),
	# then the attack sets up: he takes it back out, the centre goes to 2 m
	var reached := 0
	var stalled := 0
	var settled_ok := 0
	var tried := 0
	for sd in 60:
		var rng3 := RandomNumberGenerator.new()
		rng3.seed = 6000 + sd
		var teams := _teams()
		var p := Play.new(teams[0], teams[1], Play.Kind.COUNTER, rng3)
		if p.kind != Play.Kind.COUNTER:
			continue   # level numbers: no break
		var carrier := p.holder
		var still := 0.0
		var t := 0.0
		while p.carry and not p.over and t < 12.0 and p.holder == carrier:
			p.step(1.0 / 30.0)
			still = still + 1.0 / 30.0 if carrier.speed() < 0.3 and Geo.range_to_goal(carrier.pos) > Play.COUNTER_STOP + 0.5 else 0.0
			if still > 0.5:
				stalled += 1
				break
			t += 1.0 / 30.0
		if p.over or p.holder != carrier or p.carry:
			continue   # stolen, fouled, or stalled (counted)
		tried += 1
		if Geo.range_to_goal(carrier.pos) <= Play.COUNTER_STOP + 0.3:
			reached += 1
		var ok := false
		for _i in 300:
			if p.over or p.holder != carrier:
				ok = true   # (a turnover in the settled attack is fine: it got there)
				break
			p.step(1.0 / 30.0)
			var centre := PlaySetup._by_tag(p, "C")
			var out_ok := carrier.tag == "C" or Geo.range_to_goal(carrier.pos) > Play.COUNTER_STOP + 1.0
			if out_ok and centre.pos.distance_to(centre.home) < 1.5 and not p.carry and p.rotating == null:
				ok = true
				break
		if ok:
			settled_ok += 1
	print("  carriers: %d breaks ran out, %d of them swam it in to 3 m, %d stalled short, %d set up after" % [tried, reached, stalled, settled_ok])
	check(stalled == 0, "the carrier never parks it short of 3 m while the break is on")
	check(reached > 0 and reached >= tried * 0.25, "breaks that hold go all the way in to 3 m")
	check(settled_ok >= tried * 0.9, "an unfinished counter turns into the settled attack")
	# level numbers are never a counter; a man up always is. While it's on, the defence swims
	# back, and the counter never runs on without its man up.
	var made := 0
	var level := 0
	var level_ok := true
	var ran_on := false
	var back_start := 0.0
	var back_later := 0.0
	var watched := 0
	for sd in 300:
		var rng5 := RandomNumberGenerator.new()
		rng5.seed = 7000 + sd
		var cq := Play.new(_teams()[0], _teams()[1], Play.Kind.COUNTER, rng5)
		var bn := cq.break_n
		if bn.x <= bn.y:
			level += 1
			if cq.kind == Play.Kind.COUNTER or cq.carry:
				level_ok = false
			continue
		made += 1
		if cq.kind != Play.Kind.COUNTER or not cq.carry:
			level_ok = false
		var even_for := 0.0
		var t0 := 0.0
		var xs0 := 0.0
		for d in cq.defenders:
			xs0 += d.pos.x
		while cq.carry and not cq.over and t0 < 2.0:
			cq.step(1.0 / 30.0)
			t0 += 1.0 / 30.0
			even_for = even_for + 1.0 / 30.0 if (cq.carry and cq.ball.state == Ball.State.HELD and not cq.is_break()) else 0.0
			if even_for > Play.BREAK_CHECK + 0.05:
				ran_on = true
		if t0 >= 2.0 and not cq.over:
			var xs1 := 0.0
			for d in cq.defenders:
				xs1 += d.pos.x
			watched += 1
			back_start += xs0 / cq.defenders.size()
			back_later += xs1 / cq.defenders.size()
	print("  made-up turnovers: %d breaks, %d level (normal possessions)" % [made, level])
	check(made > 0 and level > 0, "some turnovers are breaks, some level")
	check(level_ok, "level numbers never start a counter; a man up always does")
	check(not ran_on, "a counter ends within a look once the advantage is gone")
	check(watched > 0 and back_later > back_start + 2.0, "the defence swims back on a counter (%.1f -> %.1f m)" % [back_start / maxf(watched, 1), back_later / maxf(watched, 1)])
	# a counter that's run out of numbers ends by itself
	var rng4 := RandomNumberGenerator.new()
	rng4.seed = 77
	var cp := Play.new(_teams()[0], _teams()[1], Play.Kind.COUNTER, rng4)
	for d in cp.defenders:
		d.pos = Vector2(27.0, d.pos.y)
	cp.step(1.0 / 30.0)
	for _i in 30:
		cp.step(1.0 / 30.0)
	check(not cp.carry, "the counter ends once the whole defence is back")

	print("catch and shoot glow")
	# the glow is the bonus: on at the catch, fading out by 1 s, gone the moment he shoots
	var gteams := _teams()
	var grng := RandomNumberGenerator.new()
	grng.seed = 91
	var cg := Play.new(gteams[0], gteams[1], Play.Kind.HALF_COURT, grng)
	check(cg.catch_glow() == 0.0, "no glow on a ball he didn't catch from a pass")
	var catcher := PlaySetup._by_tag(cg, "2")
	cg._catch(catcher, true)
	cg.freeze = 0.0   # (no catch foul for this check)
	check(cg.catch_glow() == 1.0, "a completed pass lights him up at once")
	var matched := true
	var at_07 := 0.0
	var tt := 0.0
	while tt < 1.2:
		cg.step(1.0 / 30.0)
		tt += 1.0 / 30.0
		if cg.holder != catcher or cg.over:
			break
		if absf(cg.catch_glow() - ShotModel.catch_shoot(cg.catch_t)) > 0.0001:
			matched = false
		if absf(tt - 0.7) < 0.02:
			at_07 = cg.catch_glow()
	check(matched, "the glow is exactly the shooting bonus every frame")
	check(at_07 > 0.2 and at_07 < 1.0, "fading by 0.7 s (%.2f)" % at_07)
	check(cg.holder != catcher or cg.catch_glow() == 0.0, "held past the window, the glow is gone")
	# shooting in the window: the shot carries the bonus (the flash, trail and heavier sound)
	var cs_play := Play.new(gteams[0], gteams[1], Play.Kind.HALF_COURT, grng)
	var shooter := PlaySetup._by_tag(cs_play, "2")
	cs_play._catch(shooter, true)
	cs_play.freeze = 0.0
	cs_play.step(1.0 / 30.0)
	cs_play._shoot(11.0, 0.8)
	var sev := cs_play.events.filter(func(ee): return ee.k == "shot")
	check(sev.size() == 1 and float(sev[0].catch_shoot) > 0.9 and float(cs_play.ball.shot.catch_shoot) > 0.9, "a catch and shoot is flagged on the shot")
	check(cs_play.catch_glow() == 0.0, "the glow is off the moment he shoots")
	check(cs_play.release_t == 0.0 and cs_play.release_by == shooter, "a catch and shoot sets off the white ring on the shooter")
	for _i in 9:
		cs_play.step(1.0 / 30.0)
	check(cs_play.release_t >= PoolArt.RING_TIME and PoolArt.RING_TIME <= 0.25 and PoolArt.RING_FLASH < PoolArt.RING_TIME,
		"the white ring is gone within 0.25 s, its flash sooner")
	check(cg.release_t == INF and cg.release_by == null, "catching a pass never sets off the white ring")
	var hp2 := Play.new(gteams[0], gteams[1], Play.Kind.HALF_COURT, grng)
	hp2._shoot(11.0, 0.8)
	check(float(hp2.ball.shot.catch_shoot) == 0.0, "a held ball's shot isn't")
	check(hp2.release_t == INF and hp2.release_by == null, "a held ball's shot gets no white ring")
	check(PoolArt.TRAIL_TIME < 0.5 and PoolArt.FLASH_TIME < PoolArt.TRAIL_TIME, "the shot's flash and trail are brief")

	print("possession clock")
	# 11-12) a change of possession takes 10 s off the game clock, once, and the same off the next
	# shot clock (30 -> 20); a goal doesn't, and the shot clock starts over at 30
	var teams2 := _teams()
	var cases := {"steal": 0, "goal": 0}
	for what in ["steal", "goal", "save", "miss"]:
		var g := MatchFlow.new(teams2[0], teams2[1], 333, MatchState.QUARTER_MIN)
		g._start_attack(Play.Kind.HALF_COURT)
		var gp := g.play
		match what:
			"steal":
				gp._turnover(gp._marker(gp.holder), "STOLEN!", "steal")
			"goal":
				gp._finish("goal", "GOAL!", {"scorer": gp.holder.player})
			"save":
				gp._finish("save", "SAVED!", {"shooter": gp.holder.player})
			"miss":
				gp._finish("miss", "WIDE!", {"shooter": gp.holder.player})
		var c0 := g.state.clock
		g.attack_done()
		var swim := MatchFlow.SWIM_IN_TIME if g.play.kind == Play.Kind.HALF_COURT else 0.0
		var off := c0 - g.state.clock
		var want := swim + (MatchState.TURNOVER_TIME if what != "goal" else 0.0)
		check(absf(off - want) < 0.001, "%s: %.1f s off the game clock (%.1f expected)" % [what, off, want])
		var sc_want := Play.SHOT_CLOCK - (MatchState.TURNOVER_TIME if what != "goal" else 0.0)
		check(g.play.shot_clock == sc_want, "%s: the shot clock starts at %.0f (%.1f)" % [what, sc_want, g.play.shot_clock])
	# a pass, a shot that's still live: nothing off
	var h := MatchFlow.new(teams2[0], teams2[1], 334, MatchState.QUARTER_MIN)
	h._start_attack(Play.Kind.HALF_COURT)
	var c1 := h.state.clock
	var hp := h.play
	var mate: Swimmer = null
	for a in hp.attackers:
		if a != hp.holder and a.tag == "2":
			mate = a
	hp.pass_at(mate.pos)
	for _i in 30:
		h.tick_attack(1.0 / 30.0)
	check(absf((c1 - h.state.clock) - hp.elapsed * MatchState.CLOCK_SPEED) < 0.01, "a pass takes only the live time off")
	# at 0:03 the deduction runs the quarter out, never below 0:00
	var e := MatchFlow.new(teams2[0], teams2[1], 335, MatchState.QUARTER_MIN)
	e._start_attack(Play.Kind.HALF_COURT)
	e.state.clock = 3.0
	e.play._turnover(e.play._marker(e.play.holder), "STOLEN!", "steal")
	e.attack_done()
	check(e.state.clock == 0.0 and e.phase == MatchFlow.Phase.BREAK, "a steal at 0:03 ends the quarter (%s)" % e.state.clock_text())
	# their attack too
	var dd := MatchFlow.new(teams2[0], teams2[1], 336, MatchState.QUARTER_MIN)
	dd._start_defense(Play.Kind.HALF_COURT)
	var dc0 := dd.state.clock
	dd.play._turnover(dd.play._marker(dd.play.holder), "STOLEN!", "steal")
	dd.defense_done()
	var dswim := MatchFlow.SWIM_IN_TIME if dd.play.kind == Play.Kind.HALF_COURT else 0.0
	check(absf((dc0 - dd.state.clock) - (MatchState.TURNOVER_TIME + dswim)) < 0.001, "your steal takes 10 s off too")

	print("exclusions drawn")
	# 13) every exclusion credits the man who drew it, once, and it reaches the box score
	var x := MatchFlow.new(teams2[0], teams2[1], 337, MatchState.QUARTER_MIN)
	x._start_attack(Play.Kind.HALF_COURT)
	var xp := x.play
	var centre_man := PlaySetup._by_tag(xp, "C")
	xp._exclusion(xp._marker(centre_man), centre_man)
	x.tick_attack(1.0 / 30.0)
	x.tick_attack(1.0 / 30.0)
	check(x.state.exclusions[0] == 1 and x.state.excl_drawn_by[0] == [centre_man.player], "the exclusion is credited to the centre who drew it, once")
	var panel := ResultsPanel.new().setup(x.state, {})
	var row := ResultsPanel.ROWS.find("EXCLUSIONS DRAWN")
	check(row >= 0 and panel.stats[row] == [1, 0], "the full-time DETAILS show exclusions drawn")
	check(ResultsPanel.BASE_H + ResultsPanel.STATS_H <= 240.0, "the opened panel still fits the screen")
	var box := x.state.box(x.us)
	check(box.excl_drawn == [centre_man.player], "the box score hands it to the career")
	# defending, your AI defenders still get excluded: their centre, fed, draws it holding the ball,
	# before he shoots
	var drawn := 0
	var credited := true
	for sd in 60:
		var lq := _center_play(4400 + sd, true)
		var lc := PlaySetup._by_tag(lq, "C")
		lq.give_ball(PlaySetup._by_tag(lq, "2"))
		lq._pass(lq.lead_point(lc), lc)
		while lq.ball.state == Ball.State.PASS:
			lq.step(1.0 / 60.0)
		if lq.holder != lc:
			continue
		for _i in 50:
			lq.step(1.0 / 60.0)
		var ev := lq.events.filter(func(ee): return ee.k == "exclusion")
		if not ev.is_empty():
			drawn += 1
			credited = credited and ev[0].drawn_by == lc.player
	check(drawn > 5, "their centre draws exclusions off your AI defence (%d/60)" % drawn)
	check(credited, "...credited to the centre who drew them")
	# a career game: the stat lands on the player
	var car := Career.new_game("WAGN", "A", "B", 71)
	var st := MatchState.new()
	st.score = [3, 2]
	var drawer: PoloPlayer = car.team().starters()[1]
	st.excl_drawn_by[0] = [drawer, drawer]
	car.finish_my_game(st.box(car.team()))
	check(drawer.stat("ed") == 2 and int(drawer.totals.get("ed", 0)) == 2, "two exclusions drawn on his season and career line")
	var others_kept := car.team().starters().slice(1).all(func(q: PoloPlayer): return q.stats.has("ed"))
	check(others_kept, "every field starter's exclusions drawn are kept from now on")
	var ps = load("res://src/ui/screens/player.gd")
	check(ps.stat_text({"gp": 3}, "ed") == "-" and ps.stat_text({"ed": 4}, "ed") == "4", "the player page shows them (- until kept)")

# ------------------------------------------------------------------ whole matches
## Plays the current attack through MatchFlow so the clock and box score run.
func _run_flow_attack(f: MatchFlow) -> float:
	var t := 0.0
	var think := 0.0
	var dt := 1.0 / 30.0
	while not f.play.over and t < 60.0:
		think -= dt
		if think <= 0.0:
			think = PlayBot.THINK_EVERY
			var d := PlayBot.think(f.play, f.rng)
			if not d.is_empty():
				f.play.throw(d.target, d.power)
		f.tick_attack(dt)
		t += dt
	f.events.clear()
	return t

func test_matches() -> void:
	print("matches")
	var totals := 0
	var n := 30
	var shootouts := 0
	for i in n:
		var teams := [League.make_team(i % 8, 0), League.make_team((i + 3) % 8, 0)]
		var f := MatchFlow.new(teams[0], teams[1], 1000 + i, MatchState.QUARTER_MIN)
		var steps := 0
		while f.phase != MatchFlow.Phase.FINAL and steps < 200000:
			steps += 1
			match f.phase:
				MatchFlow.Phase.SPRINT:
					f.sprint_done(f.rng.randf() < 0.5)
				MatchFlow.Phase.ATTACK:
					check(_run_flow_attack(f) < 60.0, "attack ends")
					f.attack_done()
				MatchFlow.Phase.DEFENSE:
					check(f.auto_defense(0.5) < 60.0, "their attack ends")
					f.defense_done()
				MatchFlow.Phase.SHOOTOUT_THEM:
					f.their_ball_done()
				MatchFlow.Phase.THEIR_SHOT:
					f.auto_duel(0.5)
					f.duel_done()
				MatchFlow.Phase.BREAK:
					f.break_done()
		check(f.phase == MatchFlow.Phase.FINAL, "match %d reaches the final whistle" % i)
		check(f.state.quarter == 4, "match %d plays four quarters" % i)
		check(f.state.winner() != -1, "match %d has a winner (shootout breaks ties)" % i)
		check(f.state.shots[1] >= f.state.score[1] and f.state.shots[0] >= f.state.score[0],
			"match %d: every goal was a shot (%s shots, %s goals)" % [i, f.state.shots, f.state.score])
		if f.state.in_shootout:
			shootouts += 1
		totals += f.state.score[0] + f.state.score[1]
	var avg := totals / float(n)
	print("  average total goals %.1f, shootouts %d/%d" % [avg, shootouts, n])
	check_between(avg, 8.0, 30.0, "average goals per match")

# ------------------------------------------------------------------ career
## Autopilot: sims every game for `seasons` seasons and checks the season holds together.
func test_career(seasons: int) -> void:
	print("career")
	Store.reset_for_tests()
	var c := Career.new_game("WAGN", "Test", "Coach", 4242)
	Game.career = c
	check(c.teams.size() == 30, "30 schools")
	check(c.team().roster.size() == c.roster_cap(c.school), "a full roster to start (the seven and three subs)")
	check(c.schedule.size() == 17, "17 weeks: 10 regular, 3 conference tournament, 4 NCSA")
	for id in c.teams:
		var n := 0
		for r in c.schedule.slice(0, Schedule.REGULAR_WEEKS):
			for g in r.games:
				if g.h == id or g.a == id:
					n += 1
		if n != Schedule.REGULAR_GAMES:
			check(false, "%s plays 16 regular-season games (%d)" % [id, n])
			break
	var start_ovr := _avg_ovr(c.team())
	var titles := 0
	var played_weeks := 0
	for s in seasons:
		var label := c.season_label()
		var guard := 0
		while c.season_label() == label and guard < 40:
			guard += 1
			_take_offer(c)
			c.queue.clear()
			while c.has_game():
				var out := c.sim_my_game()
				check(out.game.r != null, "my game has a result")
				played_weeks += 1
			_autopilot_recruit(c)
			c.end_week()
			_make_cuts(c)
			_buy_something(c)
		check(guard < 40, "season %s ends" % label)
		var h: Dictionary = c.history[c.history.size() - 1]
		check(int(h.w) + int(h.l) == Schedule.REGULAR_GAMES, "16 regular-season games in %s (%d-%d)" % [h.year, h.w, h.l])
		if String(h.finish) == "NCSA champions":
			titles += 1
		var fr: Array = c.team().roster.filter(func(p): return p.year == 1)
		print("  %s %s %d-%d (conf %d-%d, #%d)  %s   CR %d  ovr %.1f  FR %d (%s)  prestige %d" % [h.year, h.team, h.w, h.l, h.cw, h.cl, h.rank, h.finish, c.credits, _avg_ovr(c.team()), fr.size(), ",".join(fr.map(func(p): return str(roundi(p.overall())))), int(c.team().prestige)])
		# regular-season tables add up
		var wins := 0
		var losses := 0
		for id in c.teams:
			wins += int(c.table[id].w)
			losses += int(c.table[id].l)
		check(wins == losses, "table wins == losses")
		check(c.team().roster.size() >= Career.ROSTER_MAX and c.team().roster.size() <= c.roster_cap(c.school), "roster locked at 7 to 10 (%d)" % c.team().roster.size())
		for id in c.teams:
			if id != c.school and (c.teams[id].roster.size() < Career.ROSTER_MAX or c.teams[id].roster.size() > c.roster_cap(id)):
				check(false, "%s roster is not 7-10 (%d)" % [id, c.teams[id].roster.size()])
		check(c.market.size() == Recruiting.MARKET_SIZE and c.incoming.is_empty() and c.refreshes == 0, "a new recruiting market (%d), last season's signings joined" % c.market.size())
	check(played_weeks >= seasons * Schedule.REGULAR_GAMES, "played every regular-season game")
	# awards every season, and record books that hold up
	check(c.awards.size() >= seasons * 4, "awards handed out every season (%d)" % c.awards.size())
	var nb := Records.ncsa_book(c)
	check(nb.size() == Records.KEYS.size(), "the NCSA book has every record")
	var broken := 0
	for k in nb:
		if str(nb[k].year).length() > 4:
			broken += 1
	print("  NCSA records broken in %d seasons: %d of %d" % [seasons, broken, nb.size()])
	for k in ["game_goals", "season_goals", "season_saves"]:
		print("    %s: %d by %s (%s)" % [Records.NAMES[k], int(nb[k].v), nb[k].name, nb[k].year])
	for aw in c.awards.slice(0, 5):
		print("    award %s %s: %s (%s)" % [aw.year, aw.award, aw.name, aw.team])
	check(broken <= nb.size() - 2, "most NCSA records survive a few seasons")
	# save round trip
	var d := c.to_dict()
	var c2 := Career.from_dict(JSON.parse_string(JSON.stringify(d)))
	var s1 := JSON.stringify(d, "", true)
	var s2 := JSON.stringify(c2.to_dict(), "", true)
	check(s1 == s2, "save round-trips exactly")
	if s1 != s2:
		var l1 := s1.split(",")
		var l2 := s2.split(",")
		var shown := 0
		for i in mini(l1.size(), l2.size()):
			if l1[i] != l2[i] and shown < 8:
				shown += 1
				print("    save diff: ", l1[i].substr(0, 90), "  VS  ", l2[i].substr(0, 90))
	check(c2.team().name == c.team().name and c2.week == c.week, "loaded career matches")
	# an injury lowers his attributes but he still plays (and still starts) until a recovery week
	var c5 := Career.new_game("MSMU", "A", "B", 9)
	var hurt: PoloPlayer = c5.team().starters()[2]
	c5._injure(hurt, "minor")
	c5.training.focus = "balanced"
	c5.end_week()
	check(hurt.is_available() and hurt.is_injured() and c5.team().starters().has(hurt), "an injured player still plays and keeps his place")
	# a round counts into the standings once, even if the week is simmed again after your game
	var c4 := Career.new_game("GWU", "A", "B", 5)
	while c4.has_game():
		c4.sim_my_game()
	c4.sim_week_without_me()   # the rest of the week (days after your last game)
	var before := JSON.stringify(c4.table)
	c4.sim_week_without_me()
	check(JSON.stringify(c4.table) == before, "re-simming a played week doesn't double the standings")
	var counted := 0
	for id in c4.table:
		counted += int(c4.table[id].w) + int(c4.table[id].l)
	check(counted == 2 * c4.cur().games.size(), "every game of the week counted once (%d)" % counted)
	check(c4.game_done_this_week(), "the hub knows the game is done")
	# the playoff field is complete when it's built
	var c3 := Career.new_game("HURST", "A", "B", 99)
	while c3.week < 14:
		c3.queue.clear()
		while c3.has_game():
			c3.sim_my_game()
		c3.end_week()
	check(c3.schedule[10].games.size() == 10, "conference quarterfinals: 0 + 2 + 4 + 3 + 1 games")
	check(c3.schedule[11].games.size() == 10, "5 conference tournaments, 2 semis each")
	check(c3.schedule[12].games.size() == 5, "5 conference finals")
	check(c3.schedule[13].games.size() == 4, "NCSA first round: seeds 5-12")
	check((c3.season.nat_seeds as Array).size() == 12, "12 NCSA seeds")
	var champs: Array = c3.season.conf_champs
	for ch in champs:
		check(ch in c3.season.nat_seeds, "conference champion %s gets a bid" % ch)
	print("  start ovr %.1f -> %.1f after %d seasons, %d NCSA titles" % [start_ovr, _avg_ovr(c.team()), seasons, titles])
	_test_roster_cap()
	Game.career = null

# ------------------------------------------------------------------ the 30 schools
## abbreviation: [team name (as shown), university, home, colours]
const SPEC_SCHOOLS := {
	"CULA": ["Los Angeles Bears", "California University–Los Altos", "Los Altos, California", "Blue / Gold"],
	"CUSC": ["Los Angeles Spartans", "California University–Sacramento Coast", "Sacramento, California", "Cardinal / Gold"],
	"STAM": ["Stanford Redwoods", "Santa Teresa Agriculture & Medicine", "Santa Teresa, California", "Cardinal Red / White"],
	"ALC": ["Berkeley Golden Grizzlies", "Academy of Learning California", "Berkeley, California", "Navy / Gold"],
	"FORDU": ["Bronx Lambs", "Ford Riverdale University", "Bronx, New York", "Maroon / White"],
	"ICU": ["Irvine Aardvarks", "Irvine Coastal University", "Irvine, California", "Blue / Gold"],
	"PRIN": ["Princeton Bengals", "Pricetown Ridge Institute of New Jersey", "Princeton, New Jersey", "Orange / Black"],
	"CUSD": ["San Diego Sea Kings", "California University–San Diego", "San Diego, California", "Navy / Gold"],
	"LMMU": ["Los Angeles Mountain Lions", "Los Marina Memorial University", "Los Marina, California", "Crimson / Navy"],
	"LBSC": ["Long Beach Barracudas", "Long Beach Shoreline College", "Long Beach, California", "Black / Gold"],
	"UPAC": ["Stockton Bengals", "University of Pacific Athletic Coast", "Stockton, California", "Orange / Black"],
	"UCDS": ["Davis Mustangs", "University of California–Davis State", "Davis, California", "Blue / Gold"],
	"PPCU": ["Malibu Breakers", "Pepper Pacific Coast University", "Malibu, California", "Blue / Orange"],
	"CCSB": ["Santa Barbara Bulls", "California College–Santa Barbara", "Santa Barbara, California", "Blue / Gold"],
	"CRBU": ["Riverside Knights", "California Riverside–Baptist University", "Riverside, California", "Navy / Gold"],
	"SJCU": ["San Jose Warriors", "San José California University", "San José, California", "Blue / Gold"],
	"NANA": ["Annapolis Mariners", "National American Naval Academy", "Annapolis, Maryland", "Navy / Gold"],
	"SCCU": ["Santa Clara Stallions", "Santa Clara Coastal University", "Santa Clara, California", "Red / White"],
	"HVRD": ["Cambridge Redhawks", "Haverford Valley Research Division", "Cambridge, Massachusetts", "Crimson / White"],
	"SMCC": ["Moraga Highlanders", "Sierra Mountain Coastal College", "Moraga, California", "Red / Blue"],
	"BROW": ["Providence Grizzlies", "Bayview River Oceanic & Wildlife Institute", "Providence, Rhode Island", "Brown / Red / White"],
	"CSFU": ["Fullerton Mammoths", "California State–Fullerton University", "Fullerton, California", "Blue / Orange / White"],
	"USAF": ["Colorado Springs Skyhawks", "United States American Flight Academy", "Colorado Springs, Colorado", "Blue / Silver"],
	"BUCK": ["Lewisburg Buffalo", "Buffalo Creek University", "Lewisburg, Pennsylvania", "Orange / Blue"],
	"HURST": ["Erie Lakehawks", "Harbor University of Regional Science & Technology", "Erie, Pennsylvania", "Green / White"],
	"WAGN": ["Staten Island Hawks", "Waterfront Academy of Greater New York", "Staten Island, New York", "Green / White"],
	"GWU": ["Washington Patriots", "Georgetown Waterfront University", "Washington, D.C.", "Buff / Blue"],
	"MSMU": ["Emmitsburg Highlanders", "Maryland Summit Mountain University", "Emmitsburg, Maryland", "Blue / White"],
	"IONA": ["New Rochelle Irish", "Institute of Northern Academics", "New Rochelle, New York", "Maroon / Gold"],
	"LIUB": ["Brooklyn Hammerheads", "Long Island Brooklyn University", "Brooklyn, New York", "Blue / Gold"],
}
## The official team ratings (OVR) every career starts with.
const SPEC_OVR := {
	"CULA": 91, "CUSC": 90, "STAM": 89, "ALC": 88,
	"LBSC": 82, "CUSD": 81, "ICU": 78, "CRBU": 77, "CCSB": 75, "CSFU": 70,
	"SJCU": 83, "PPCU": 79, "UCDS": 78, "LMMU": 77, "UPAC": 76, "SCCU": 72, "USAF": 71, "SMCC": 70,
	"FORDU": 86, "NANA": 74, "GWU": 73, "BUCK": 69, "WAGN": 68, "MSMU": 67, "HURST": 62,
	"PRIN": 80, "HVRD": 76, "BROW": 74, "IONA": 66, "LIUB": 65,
}
const SPEC_CONFS := {
	"MPSF": ["CULA", "CUSC", "STAM", "ALC"],
	"BIGWEST": ["ICU", "CUSD", "CCSB", "LBSC", "CSFU", "CRBU"],
	"WCC": ["LMMU", "PPCU", "UPAC", "SCCU", "SJCU", "USAF", "UCDS", "SMCC"],
	"MAWPC": ["FORDU", "BUCK", "NANA", "GWU", "WAGN", "MSMU", "HURST"],
	"NWPC": ["PRIN", "HVRD", "BROW", "IONA", "LIUB"],
}
const EAST_CONFS := ["MAWPC", "NWPC"]

## The school database: names, colours, fonts and the scoreboard; the exact team ratings; the
## five conferences; every school as a new career; caps; a game against every school.
func test_teams() -> void:
	print("teams")
	Store.reset_for_tests()
	check(Colleges.SCHOOLS.size() == 30, "exactly 30 schools (%d)" % Colleges.SCHOOLS.size())
	var ids := {}
	for s in Colleges.SCHOOLS:
		var sid: String = s.short
		check(not ids.has(sid), "%s is unique" % sid)
		ids[sid] = true
		check(SPEC_SCHOOLS.has(sid), "%s is one of the 30" % sid)
		if not SPEC_SCHOOLS.has(sid):
			continue
		var spec: Array = SPEC_SCHOOLS[sid]
		check(s.name == spec[0] and String(s.name).ends_with(" " + String(s.mascot)), "%s is the %s" % [sid, spec[0]])
		check(not s.has("school") and s.city == spec[2], "%s: no university name kept; %s" % [sid, s.city])
		var n_cols := String(spec[3]).split(" / ").size()
		check((3 if s.has("c3") else 2) == n_cols, "%s has its %d colours" % [sid, n_cols])
		for k in ["c1", "c2", "c3"]:
			if s.has(k):
				check(String(s[k]).is_valid_html_color() and String(s[k]).length() == 6, "%s %s is a colour" % [sid, k])
		check(TeamLogo.spec(s).mark != "", "%s has a mark" % sid)
		for f in [UI.font_body, UI.font_caps, UI.font_big]:
			for txt in [s.name, s.city, String(s.name).to_upper()]:
				for ch in String(txt):
					if not (f as Font).has_char(ch.unicode_at(0)):
						check(false, "%s: '%s' has no glyph in %s" % [sid, ch, (f as FontFile).resource_path])
		check(UI.text_width(sid, 8, "caps") <= 30.0, "%s fits the scoreboard (%.0f px)" % [sid, UI.text_width(sid, 8, "caps")])
	check(Colleges.school("IONA").name == "New Rochelle Irish", "IONA are the New Rochelle Irish")
	# 1-7: the exact team ratings, in the data and in a new career
	for sid in ["CULA", "CUSC", "STAM", "ALC", "FORDU", "HURST"]:
		check(int(Colleges.school(sid).ovr) == SPEC_OVR[sid], "%s has OVR %d" % [sid, SPEC_OVR[sid]])
	check(SPEC_OVR.size() == 30 and SPEC_OVR.keys().all(func(sid): return int(Colleges.school(sid).get("ovr", -1)) == SPEC_OVR[sid]), "all 30 ratings are in the data as given")
	for seed in [3, 77, 2026]:
		var cc := Career.new_game("WAGN", "A", "B", seed)
		# (a team that's already played its first game may have spent its upgrades: XP 2.0)
		var played := {}
		for g in cc.cur().games:
			if g.r != null:
				played[g.h] = true
				played[g.a] = true
		var wrong: Array = SPEC_OVR.keys().filter(func(sid): return cc.teams[sid].initial_strength_target != SPEC_OVR[sid] or (not played.has(sid) and cc.teams[sid].overall_display() != SPEC_OVR[sid]))
		check(wrong.is_empty(), "career seed %d: every team's first roster shows its exact OVR %s" % [seed, str(wrong)])
	# 8-9: the five conferences
	check(Colleges.CONFERENCES.size() == 5, "5 conferences")
	for cid in SPEC_CONFS:
		var members: Array = Colleges.schools_in(cid).map(func(m): return m.short)
		members.sort()
		var want: Array = SPEC_CONFS[cid].duplicate()
		want.sort()
		check(members == want, "%s is %s" % [Colleges.conference(cid).name, ", ".join(want)])
	check(SPEC_CONFS.keys().map(func(cid): return Colleges.schools_in(cid).size()) == [4, 6, 8, 7, 5], "conference sizes 4, 6, 8, 7, 5")
	check(Colleges.conference("MPSF").name == "Pacific Elite Conference" and Colleges.conference("BIGWEST").name == "Golden Coast Conference" and Colleges.conference("WCC").name == "Western Water Polo Conference" and Colleges.conference("MAWPC").name == "Atlantic Water Polo Conference" and Colleges.conference("NWPC").name == "Northeast Coast Conference", "the conferences' names")
	for cid in SPEC_CONFS:
		check((Colleges.region(cid) == "east") == (cid in EAST_CONFS), "%s is in the %s" % [cid, Colleges.region(cid)])
	# every school can be picked, with a full roster
	for sid in ids:
		var cc := Career.new_game(sid, "A", "B", 3)
		check(cc.school == sid and cc.team().is_player and cc.teams.size() == 30, "%s can start a career" % sid)
		var t := cc.team()
		check(t.roster.size() == cc.roster_cap(sid) and t.starters().size() == PoloTeam.STARTERS and t.keeper().is_keeper(), "%s has a full roster (seven and its three subs)" % sid)
		check(Colors_equal(t.c1, Color(Colleges.school(sid).c1)) and Colors_equal(t.c2, Color(Colleges.school(sid).c2)), "%s wears its colours" % sid)
	# caps: a light primary changes to its second colour against white caps
	var c := Career.new_game("WAGN", "A", "B", 4242)
	var white := Color("f2f2e9")
	check(c.teams["GWU"].cap_against(white) == c.teams["GWU"].c2 and c.teams["GWU"].trim_against(white) == c.teams["GWU"].c1, "GWU wear blue caps against white")
	check(c.teams["CULA"].cap_against(white) == c.teams["CULA"].c1, "CULA wear blue")
	# a game against every school, to the final whistle
	for id in c.teams:
		if id == c.school:
			continue
		var f := MatchFlow.new(c.team(), c.teams[id], 500 + id.hash() % 1000, MatchState.QUARTER_MIN)
		_finish_flow(f)
		check(f.phase == MatchFlow.Phase.FINAL and f.state.winner() != -1, "a full game against %s" % id)
	Game.career = null

static func Colors_equal(a: Color, b: Color) -> bool:
	return a.to_html(false) == b.to_html(false)

## 10-14: the regular season, for several careers: 16 games each (240 in all) in 10 weeks,
## every conference opponent (twice in the MPSF, home and away), coast to coast, no team over
## three games a week or one a day, 6-10 home games, no non-conference pair twice, road trips.
func test_season() -> void:
	print("season")
	Store.reset_for_tests()
	var examples := {}
	var spread_seeds := 0   # seeds where somebody has 6 or 10 home games (about 1 draw in 3)
	for seed in [4242, 1, 99, 2027, 31337]:
		var c := Career.new_game("CULA", "A", "B", seed)
		var reg: Array = c.schedule.slice(0, Schedule.REGULAR_WEEKS)
		check(c.schedule.size() == 17 and reg.all(func(r): return r.kind == "reg") and c.schedule.slice(10).all(func(r): return Schedule.is_playoff(r)), "seed %d: 10 regular-season weeks, then 7 playoff rounds" % seed)
		var all: Array = []
		for w in reg.size():
			for g in reg[w].games:
				all.append([w, g])
		check(all.size() == 240, "seed %d: 240 regular-season games (%d)" % [seed, all.size()])
		var games_of := {}
		var homes := {}
		var meet := {}
		var nonconf := {}
		var week_load := {}
		var days := {}
		var west_opps := {}
		var trips := 0
		for id in c.teams:
			games_of[id] = 0
			homes[id] = 0
			west_opps[id] = {}
		var away_west := {}   # east team -> week -> away games in the West
		for e in all:
			var w: int = e[0]
			var g: Dictionary = e[1]
			var h: String = g.h
			var a: String = g.a
			var same_conf: bool = c.teams[h].conf == c.teams[a].conf
			check(bool(g.c) == same_conf, "seed %d: %s-%s is %s" % [seed, h, a, "conference" if same_conf else "non-conference"])
			games_of[h] += 1
			games_of[a] += 1
			homes[h] += 1
			var key := [h, a] if h < a else [a, h]
			meet[str(key)] = int(meet.get(str(key), 0)) + 1
			if not same_conf:
				check(not nonconf.has(str(key)), "seed %d: %s and %s meet once out of conference" % [seed, h, a])
				nonconf[str(key)] = true
			for t in [h, a]:
				var wk := "%s|%d" % [t, w]
				week_load[wk] = int(week_load.get(wk, 0)) + 1
				var dk := "%s|%d|%d" % [t, w, int(g.d)]
				check(not days.has(dk), "seed %d: %s plays once on day %d of week %d" % [seed, t, int(g.d), w + 1])
				days[dk] = true
			var he: bool = c.teams[h].conf in EAST_CONFS
			var ae: bool = c.teams[a].conf in EAST_CONFS
			if he != ae:
				var east: String = h if he else a
				var west: String = a if he else h
				west_opps[east][west] = true
				if not examples.has(east) and seed == 4242:
					examples[east] = "%s at %s" % [a, h]
				if not he:   # the East team is away, in the West
					var k2 := "%s|%d" % [east, w]
					away_west[k2] = int(away_west.get(k2, 0)) + 1
		for k2 in away_west:
			if away_west[k2] >= 2:
				trips += 1
		var bad16: Array = games_of.keys().filter(func(id): return games_of[id] != 16)
		check(bad16.is_empty(), "seed %d: every team plays exactly 16 %s" % [seed, str(bad16)])
		check(week_load.values().all(func(n): return n <= 3), "seed %d: nobody plays more than 3 games in a week" % seed)
		var home_bad: Array = homes.keys().filter(func(id): return homes[id] < 6 or homes[id] > 10)
		check(home_bad.is_empty(), "seed %d: 6-10 home games for everyone %s" % [seed, str(home_bad)])
		var home_far: Array = homes.keys().filter(func(id): return homes[id] < 7 or homes[id] > 9)
		if not home_far.is_empty():
			spread_seeds += 1
		# every conference opponent, the right number of times
		for cid in SPEC_CONFS:
			var m: Array = SPEC_CONFS[cid]
			var times := 2 if cid == "MPSF" else 1
			for i in m.size():
				for j in range(i + 1, m.size()):
					var key := [m[i], m[j]] if m[i] < m[j] else [m[j], m[i]]
					check(int(meet.get(str(key), 0)) == times, "seed %d: %s and %s meet %d time(s) in the %s" % [seed, m[i], m[j], times, cid])
			if times == 2:
				for i in m.size():
					for j in range(i + 1, m.size()):
						var hosts: Array = all.filter(func(e): return (e[1].h == m[i] and e[1].a == m[j]) or (e[1].h == m[j] and e[1].a == m[i])).map(func(e): return e[1].h)
						check(hosts.size() == 2 and hosts[0] != hosts[1], "seed %d: %s-%s home and away" % [seed, m[i], m[j]])
		var conf_games := {"MPSF": 6, "BIGWEST": 5, "WCC": 7, "MAWPC": 6, "NWPC": 4}
		for id in c.teams:
			var n := all.filter(func(e): return bool(e[1].c) and (e[1].h == id or e[1].a == id)).size()
			check(n == conf_games[c.teams[id].conf], "seed %d: %s plays %d conference games (%d)" % [seed, id, conf_games[c.teams[id].conf], n])
		# coast to coast: every Eastern team plays the fewest Western teams the conferences allow
		var cross := 0
		for id in c.teams:
			if not c.teams[id].conf in EAST_CONFS:
				continue
			cross += west_opps[id].size()
			# its non-conference games minus the other Eastern conference's teams
			var nonconf_n: int = 16 - conf_games[c.teams[id].conf]
			var east_other: int = c.teams.keys().filter(func(u): return c.teams[u].conf in EAST_CONFS and c.teams[u].conf != c.teams[id].conf).size()
			check(west_opps[id].size() == nonconf_n - east_other and west_opps[id].size() == 5, "seed %d: %s plays %d Western teams (the fewest possible)" % [seed, id, west_opps[id].size()])
		check(cross == 60, "seed %d: 60 coast-to-coast games (%d)" % [seed, cross])
		check(trips >= 3, "seed %d: Eastern teams travel west for two or three games at a time (%d trips)" % [seed, trips])
	check(spread_seeds <= 2, "home games are 7-9 for everyone in most seasons (%d of 5 have a 6 or a 10)" % spread_seeds)
	print("  coast to coast: %s" % ", ".join(examples.values().slice(0, 8)))
	Game.career = null

## Plays a career's season on to week `to` (every game of yours simmed).
func _sim_to(c: Career, to: int) -> void:
	var guard := 0
	var y := c.year
	while c.week < to and c.year == y and guard < 200:
		guard += 1
		c.queue.clear()
		while c.has_game():
			c.sim_my_game()
		c.end_week()

## 15-16: the conference tournaments (everyone in, by conference record, the byes) and the
## 12-team NCSA Championship.
func test_postseason() -> void:
	print("postseason")
	Store.reset_for_tests()
	for seed in [5, 64, 808]:
		var c := Career.new_game("NANA", "A", "B", seed)
		_sim_to(c, 10)
		var qf: Dictionary = c.schedule[10]
		check(qf.kind == "conf_qf" and Schedule.drawn(qf), "seed %d: the conference tournaments are drawn after week 10" % seed)
		var expect_qf := {"MPSF": 0, "BIGWEST": 2, "WCC": 4, "MAWPC": 3, "NWPC": 1}
		for cid in SPEC_CONFS:
			var seeds: Array = c.season.conf_seeds[cid]
			check(seeds == Schedule.conf_table(c.teams, c.table, cid), "seed %d: %s seeded by conference record" % [seed, cid])
			check(seeds.size() == SPEC_CONFS[cid].size(), "seed %d: every %s team is in its tournament" % [seed, cid])
			var games: Array = qf.games.filter(func(g): return c.teams[g.h].conf == cid)
			check(games.size() == expect_qf[cid], "seed %d: %s quarterfinals: %d games" % [seed, cid, expect_qf[cid]])
			var pairs: Array = games.map(func(g): return [seeds.find(g.h) + 1, seeds.find(g.a) + 1])
			pairs.sort()
			var want: Array = {"MPSF": [], "BIGWEST": [[3, 6], [4, 5]], "WCC": [[1, 8], [2, 7], [3, 6], [4, 5]],
				"MAWPC": [[2, 7], [3, 6], [4, 5]], "NWPC": [[4, 5]]}[cid]
			check(pairs == want, "seed %d: %s quarterfinal seeds %s (better seed at home)" % [seed, cid, str(pairs)])
		_sim_to(c, 11)
		var sf: Dictionary = c.schedule[11]
		for cid in SPEC_CONFS:
			var seeds: Array = c.season.conf_seeds[cid]
			var games: Array = sf.games.filter(func(g): return c.teams[g.h].conf == cid)
			check(games.size() == 2, "seed %d: %s has two semifinals" % [seed, cid])
			check(games.all(func(g): return seeds.find(g.h) < seeds.find(g.a)), "seed %d: %s semifinals at the better seed" % [seed, cid])
			var byes: Array = seeds.slice(0, 8 - seeds.size())
			check(byes.all(func(b): return games.any(func(g): return g.h == b or g.a == b)), "seed %d: %s's bye teams %s play the semifinals" % [seed, cid, str(byes)])
			if cid == "NWPC":
				var ids_in: Array = []
				for g in games:
					ids_in.append_array([g.h, g.a])
				check(ids_in.has(seeds[2]) and games.any(func(g): return (g.h == seeds[1] and g.a == seeds[2])), "seed %d: NWPC 2 v 3 in a semifinal" % seed)
		_sim_to(c, 13)
		check(c.schedule[12].games.size() == 5, "seed %d: five conference finals" % seed)
		var field: Array = c.season.nat_seeds
		check(field.size() == 12, "seed %d: a 12-team NCSA Championship" % seed)
		check((c.season.conf_champs as Array).size() == 5 and c.season.conf_champs.all(func(ch): return ch in field), "seed %d: the 5 conference champions get bids" % seed)
		check(field.filter(func(id): return not id in c.season.conf_champs).size() == 7, "seed %d: 7 at-large bids" % seed)
		var r1: Dictionary = c.schedule[13]
		var r1_pairs: Array = r1.games.map(func(g): return [field.find(g.h) + 1, field.find(g.a) + 1])
		r1_pairs.sort()
		check(r1.kind == "nat_r1" and r1_pairs == [[5, 12], [6, 11], [7, 10], [8, 9]], "seed %d: first round 5-12, 6-11, 7-10, 8-9 %s" % [seed, str(r1_pairs)])
		check(r1.games.all(func(g): return field.find(g.h) >= 4 and field.find(g.a) >= 4), "seed %d: seeds 1-4 have byes" % seed)
		_sim_to(c, 14)
		var qf2: Dictionary = c.schedule[14]
		var hosts: Array = qf2.games.map(func(g): return field.find(g.h) + 1)
		hosts.sort()
		check(qf2.games.size() == 4 and field.slice(0, 4).all(func(b): return qf2.games.any(func(g): return g.h == b or g.a == b)), "seed %d: seeds 1-4 join in the quarterfinals" % seed)
		check(qf2.games.all(func(g): return field.find(g.h) < field.find(g.a)), "seed %d: the better seed hosts" % seed)
		_sim_to(c, 16)
		check(c.schedule[15].games.size() == 2 and c.schedule[16].games.size() == 1, "seed %d: semifinals, then the final" % seed)
		var finalists: Array = [c.schedule[16].games[0].h, c.schedule[16].games[0].a]
		_sim_to(c, 17)
		check(c.history.size() == 1 and c.phase == "done" and c.year == Career.START_YEAR, "seed %d: the season ends: done, NEXT SEASON to come" % seed)
		var guard := 0
		while c.year == Career.START_YEAR and guard < 20:
			guard += 1
			c.queue.clear()
			c.end_week()
			_make_cuts(c)
		check(c.year == Career.START_YEAR + 1 and c.phase == "season" and c.week == 0, "seed %d: after the off-season the next season begins" % seed)
	Game.career = null

## 17: the picker shows every team's exact OVR (in the panel: the cards show OFF and DEF since the
## Road to Glory, see glory_test).
func test_picker_ovr() -> void:
	print("picker")
	Store.reset_for_tests()
	Game.career = null
	Game.progress = Progression.fresh()
	Game.goto("new_career")
	await get_tree().process_frame
	var scr = Game.current_screen
	var rows: Array = scr.card_order().map(func(id): return scr.cards[id])
	check(rows.size() == 30 and scr.cards.size() == 30, "the picker lists 30 schools")
	var named := {}
	for sid in SPEC_OVR:
		var texts: Array = scr.cards[sid].find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
		named[sid] = Colleges.place(sid).to_upper() in texts and String(Colleges.school(sid).mascot).to_upper() in texts and not sid in texts
	check(named.values().all(func(v): return v), "every card shows its school's name (never its id) %s" % str(named.keys().filter(func(k): return not named[k])))
	var first: Array = rows[0].find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	var top: String = Game.progress.picker_groups(scr.preview.teams)[0].ids[0]
	check(Colleges.place(top).to_upper() in first and Game.progress.is_unlocked(top), "the strongest open school heads the list (%s; the locked ones follow, see glory_test)" % top)
	for sid in SPEC_OVR:
		var t: PoloTeam = scr.preview.teams[sid]
		var off: Control = scr.cards[sid].find_child("StarsOFF", true, false)
		var dfn: Control = scr.cards[sid].find_child("StarsDEF", true, false)
		if off == null or dfn == null or float(off.get_meta("stars")) != scr.card_stars(t.offense_display()) or float(dfn.get_meta("stars")) != scr.card_stars(t.defense_display()):
			check(false, "%s's card shows its OFF and DEF in stars" % sid)
	Game.goto("title")
	await get_tree().process_frame

## 18: the players decide games, never a number: two copies of a roster play the same whatever
## their original rating says, a roster with better attributes wins more, an 83 beats a 74 most
## of the time, and upsets still happen.
func test_ovr_effect() -> void:
	print("ovr in games")
	Store.reset_for_tests()
	var c := Career.new_game("WAGN", "A", "B", 9)
	var rng := RandomNumberGenerator.new()
	var base: PoloTeam = c.teams["UPAC"]
	var same := PoloTeam.from_dict(base.to_dict())
	var relabelled := PoloTeam.from_dict(base.to_dict())
	relabelled.initial_strength_target = 99.0
	var stronger := PoloTeam.from_dict(base.to_dict())
	for p: PoloPlayer in stronger.roster:
		for k in p.key_ratings():
			Attributes.set_ceiling(p, k, minf(Attributes.MAX, p.attr(k) + 2.0))
			Attributes.set_value(p, k, p.attr(k) + 2.0)
	check(stronger.rating() > base.rating() + 10.0, "better attributes, a higher rating (%.1f vs %.1f)" % [stronger.rating(), base.rating()])
	var wins := [0, 0, 0]
	for k in 3:
		rng.seed = 1
		var t: PoloTeam = [same, relabelled, stronger][k]
		for i in 600:
			if GameSim.play(t, base, rng.randi()).winner == 0:
				wins[k] += 1
	print("  vs UPAC: an identical roster %d/600, the same with target 99 %d/600, +2 every attribute %d/600" % wins)
	check(wins[1] == wins[0], "an original rating alone changes nothing (%d vs %d)" % [wins[1], wins[0]])
	check(wins[2] > wins[0] + 60, "better players win more games (%d vs %d)" % [wins[2], wins[0]])
	# nine points apart (at 20+ the scoring engine makes an upset all but impossible)
	var top: PoloTeam = c.teams["SJCU"]
	var low: PoloTeam = c.teams["NANA"]
	var upsets := 0
	rng.seed = 7
	for i in 400:
		if GameSim.play(top, low, rng.randi()).winner == 1:
			upsets += 1
	print("  NANA (74) won at SJCU (83) %d times in 400" % upsets)
	check(upsets > 0 and upsets < 80, "the 83 wins most, upsets still happen (%d/400)" % upsets)
	# over whole seasons the better teams win more
	var w_hi := 0
	var g_hi := 0
	var w_lo := 0
	var g_lo := 0
	for seed in [1, 2, 3]:
		var cc := Career.new_game("WAGN", "A", "B", seed)
		_sim_to(cc, 10)
		for id in cc.teams:
			var r: Dictionary = cc.table[id]
			if SPEC_OVR[id] >= 85:
				w_hi += int(r.w)
				g_hi += int(r.w) + int(r.l)
			elif SPEC_OVR[id] <= 70:
				w_lo += int(r.w)
				g_lo += int(r.w) + int(r.l)
	var p_hi := float(w_hi) / g_hi
	var p_lo := float(w_lo) / g_lo
	print("  regular seasons: OVR 85+ win %.0f%%, OVR 70 and under %.0f%%" % [p_hi * 100, p_lo * 100])
	check(p_hi > 0.6 and p_lo < 0.45 and p_lo > 0.05, "the ratings show in the standings")

func _finish_flow(f: MatchFlow) -> void:
	var steps := 0
	while f.phase != MatchFlow.Phase.FINAL and steps < 200000:
		steps += 1
		match f.phase:
			MatchFlow.Phase.SPRINT:
				f.sprint_done(f.rng.randf() < 0.5)
			MatchFlow.Phase.ATTACK:
				_run_flow_attack(f)
				f.attack_done()
			MatchFlow.Phase.DEFENSE:
				f.auto_defense(0.5)
				f.defense_done()
			MatchFlow.Phase.SHOOTOUT_THEM:
				f.their_ball_done()
			MatchFlow.Phase.THEIR_SHOT:
				f.auto_duel(0.5)
				f.duel_done()
			MatchFlow.Phase.BREAK:
				f.break_done()

## A career saved before the current conferences: one game a week, the conference round
## robin after `nonconf` non-conference weeks, then the old playoffs (top 4 in each
## conference, 8 in the NCSA). `confs` gives each team's conference.
func _old_career(school_id: String, seed_value: int, schools: Array, confs: Dictionary, nonconf: int) -> Career:
	var c := Career.new()
	c.rng.seed = seed_value
	c.school = school_id
	c.coach.first = "Old"
	c.coach.last = "Coach"
	for s in schools:
		var t := PoloTeam.new()
		t.id = s.short
		t.name = s.name
		t.mascot = s.mascot
		t.c1 = Color(s.c1)
		t.c2 = Color(s.c2)
		t.conf = confs[s.short]
		t.prestige = float(s.prestige)
		t.is_player = s.short == school_id
		CollegeGen.make_roster_18(t, c.rng, c.new_id)   # (an old save's roster: around its prestige)
		t.trim_to(PoloTeam.STARTERS)
		CollegeGen.award_scholarships(t, Career.SCHOL_MAX)
		c.teams[t.id] = t
	c.start_season()
	# the schedule as those saves have it
	var by_conf := {}
	for id in c.teams:
		var cf: String = c.teams[id].conf
		if not by_conf.has(cf):
			by_conf[cf] = []
		by_conf[cf].append(id)
	var cids: Array = by_conf.keys()
	cids.sort()
	var flat: Array = []
	for cf in cids:
		by_conf[cf].sort()
		flat.append_array(by_conf[cf])
	var half := flat.size() / 2
	var rounds: Array = []
	for r in nonconf:
		var games: Array = []
		for i in half:
			games.append({"h": flat[i], "a": flat[half + (i + r) % half], "r": null})
		rounds.append({"kind": "nonconf", "name": "FALL INVITATIONAL", "games": games})
	var n: int = by_conf[cids[0]].size()
	for r in n - 1:
		var games: Array = []
		for cf in cids:
			var ids_c: Array = by_conf[cf]
			var rot := [ids_c[0]]
			for k in range(1, n):
				rot.append(ids_c[1 + (k - 1 + r) % (n - 1)])
			for i in n / 2:
				games.append({"h": rot[i], "a": rot[n - 1 - i], "r": null})
		rounds.append({"kind": "conf", "name": "CONFERENCE PLAY", "games": games})
	for k in ["conf_semi", "conf_final", "nat_qf", "nat_sf", "nat_final"]:
		rounds.append({"kind": k, "name": Schedule.ROUND_NAMES[k], "games": []})
	c.schedule = rounds
	return c

## The first 30-school layout (v2): five conferences of six, 5 + 5 weeks.
const V2_CONFS := {"GCF": ["CULA", "CUSC", "STAM", "ALC", "PPCU", "LBSC"], "SSC": ["ICU", "CUSD", "LMMU", "CCSB", "CRBU", "CSFU"],
	"WPA": ["UPAC", "UCDS", "SJCU", "SCCU", "SMCC", "USAF"], "NCC": ["FORDU", "PRIN", "HVRD", "BROW", "IONA", "LIUB"],
	"CAC": ["NANA", "BUCK", "HURST", "WAGN", "GWU", "MSMU"]}

func _v2_career(school_id: String, seed_value: int) -> Career:
	var confs := {}
	for cf in V2_CONFS:
		for id in V2_CONFS[cf]:
			confs[id] = cf
	return _old_career(school_id, seed_value, Colleges.SCHOOLS, confs, 5)

## Plays an old save's season to its end (its old playoffs included).
func _finish_old_season(c: Career) -> int:
	var label := c.season_label()
	var guard := 0
	while c.season_label() == label and guard < 40:
		guard += 1
		while c.has_game():
			c.sim_my_game()
		c.end_week()
		_make_cuts(c)
	return guard

## 19: old saves. The season in progress plays out as it was saved (one game a week, the old
## playoffs), then the save moves onto the five conferences and the 16-game season; the old file
## is kept.
func test_realign() -> void:
	print("realign")
	Store.reset_for_tests()
	var c := _v2_career("FORDU", 12)
	c.sim_my_game()
	c.end_week()
	var d0: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	c = Career.from_dict(d0)
	check(c.conf_name() == "Northeast Coast Conference" and c.week == 1 and c.needs_realign(), "a 5 x 6 save loads mid-season in its old conference")
	check(c.teams.keys().all(func(id): return c.teams[id].ratings() == PoloTeam.from_dict(d0.teams[id]).ratings()), "...rated from its own players straight away (never the school table)")
	Game.career = c
	for q in Game.career.upgrades_due(): Development.ai_spend(q)   # (XP 2.0: upgrades are spent before the hub moves on)
	for scr in ["hub", "conference", "schedule", "records", "matchup"]:
		Game.goto(scr)
		await get_tree().process_frame
		check(Game.current_name == scr, "old save: %s opens" % scr)
	var keep: Array = c.team().roster.filter(func(p): return p.year < 4).map(func(p): return p.id)
	var hist0: int = c.history.size()
	check(_finish_old_season(c) < 40, "the old season plays to its end, old playoffs and all")
	check(c.history.size() == hist0 + 1 and c.history[-1].team == "FORDU", "the season's history stays with the school (%s)" % c.history[-1].team)
	check(c.realigned and not c.needs_realign(), "the off-season realigns it")
	check(c.teams.size() == 30 and c.school == "FORDU" and c.team().is_player and c.team().conf == "MAWPC", "30 schools; yours moves to its conference")
	var stayed: Array = keep.filter(func(pid): return c.team().find_id(pid) != null)
	check(stayed.size() == keep.size(), "the returning players stay with the program: there's no transfer portal (%d of %d)" % [stayed.size(), keep.size()])
	check(c.teams.keys().all(func(id): return c.teams[id].conf == Colleges.school(id).conf), "every team gets its new conference")
	check(c.records.school.keys().all(func(id): return c.teams.has(id)), "school record books stay with the schools")
	check(c.queue.any(func(q): return q.get("title", "") == "NCSA REALIGNMENT"), "the coach is told")
	check(c.schedule.size() == 17 and c.week == 0, "a full new season is drawn")
	for id in c.teams:
		var n := 0
		for r in c.schedule.slice(0, 10):
			n += r.games.filter(func(g): return g.h == id or g.a == id).size()
		check(n == 16, "%s has 16 games after the realignment" % id)
	var d := c.to_dict()
	var c2 := Career.from_dict(JSON.parse_string(JSON.stringify(d)))
	check(JSON.stringify(c2.to_dict()) == JSON.stringify(d), "a realigned save round-trips")
	Game.career = null
	# the save file: the last old one is kept beside the realigned one
	var dir := "user://test_realign/"
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + f))
	var saved_dir := Game.save_dir
	var saved_slot := Game.slot
	Game.save_dir = dir
	Game.test_mode = false
	var old := _v2_career("HURST", 5)
	Game.career = old
	Game.slot = 2
	Game.save_career()
	var old_text := FileAccess.get_file_as_string(Game.slot_path(2))
	_finish_old_season(old)
	check(old.school == "HURST" and not old.needs_realign(), "the old save realigns")
	Game.save_career()
	check(FileAccess.get_file_as_string(dir + Game.BACKUP_PATH % 2) == old_text, "the old save is kept as a backup")
	check(Game.load_career(2) and Game.career.school == "HURST" and not Game.career.needs_realign(), "the realigned save loads")
	# a career at a school no longer in the game: refused, shown as a problem, its file untouched
	var gone: Dictionary = JSON.parse_string(old_text)
	gone.school = "GONE"
	var gone_text := JSON.stringify(gone)
	var gf := FileAccess.open(Game.slot_path(3), FileAccess.WRITE)
	gf.store_string(gone_text)
	gf.close()
	Game.career = null
	check(not Game.load_career(3) and Game.career == null, "a save at a removed school isn't opened")
	check(bool(Game.slot_summary(3).get("damaged", false)), "...its slot shows SAVE PROBLEM")
	var cached := ConfigFile.new()
	cached.load(dir + Game.SLOTS_CFG)
	cached.set_value("slots", "sum_3", {"team": "Old Name", "school": "GONE", "season": 2, "record": "", "mtime": FileAccess.get_modified_time(Game.slot_path(3))})
	cached.save(dir + Game.SLOTS_CFG)
	check(bool(Game.slot_summary(3).get("damaged", false)), "...from a summary cached before the removal too")
	check(FileAccess.get_file_as_string(Game.slot_path(3)) == gone_text, "...and the file stays as it was")
	Game.test_mode = true
	Game.save_dir = saved_dir
	Game.slot = saved_slot
	Game.career = null
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + f))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))

## Seven-man rosters: one keeper and six field players, all seven play (two hurt still play
## when there's no bench), and older saves with bigger rosters (8 in version 4, 16 in version 2)
## are cut once, on load (to seven; your own program keeps up to ten, its bench), and stay that
## way through the off-seasons.
func _test_roster_cap() -> void:
	var c := Career.new_game("WAGN", "A", "B", 77)
	for id in c.teams:
		var t: PoloTeam = c.teams[id]
		check(t.roster.size() == c.roster_cap(id), "%s starts with 7 (yours 10: three subs)" % id)
		check(t.starters().size() == 7 and t.starters().all(func(p): return t.roster.has(p)), "%s plays all 7" % id)
		var seven := t.starters()
		var shape := seven.map(func(p): return p.pos)
		var ok := true
		for pos in CollegeGen.ROSTER_SHAPE:
			ok = ok and shape.count(pos) == int(CollegeGen.ROSTER_SHAPE[pos])
		check(ok, "%s has the seven-man shape (GK, C, 2MD, 2 ATK, 2 WG)" % id)
		var years := seven.map(func(p): return p.year)
		check([years.count(1), years.count(2), years.count(3), years.count(4)] == [2, 2, 2, 1], "%s has four classes: 2 FR, 2 SO, 2 JR, 1 SR" % id)
		check(t.roster.filter(func(p): return p.schol).size() == Career.SCHOL_MAX, "%s has 4 on scholarship" % id)
	var me: PoloTeam = c.teams["CULA"]   # (an AI program: no bench)
	var st := me.starters()
	var rq := RandomNumberGenerator.new()
	Development.injure(st[1], rq, "moderate")
	Development.injure(st[3], rq, "moderate")
	check(me.starters().size() == 7 and me.starters().has(st[1]) and me.starters().has(st[3]), "two hurt: they play hurt, still 7")
	Development.injure(st[0], rq, "moderate")
	check(me.starters()[0] == st[0], "a hurt keeper still keeps goal")
	for q in [st[0], st[1], st[3]]:
		Development.heal(q)
	# an old save (version 4): eight on every roster (from the 18-man days), no scholarships or
	# hometowns, the old recruiting board. It's upgraded on load: the starting seven, the same rating.
	var c18 := Career.new_game("WAGN", "A", "B", 77)
	for id in c18.teams:
		var t: PoloTeam = c18.teams[id]
		CollegeGen.make_roster_18(t, c18.rng, c18.new_id, float(Colleges.school(id).ovr))
		t.lineup = []
	var old := _as_v4(c18, 8)
	var ratings := {}
	var starter_ids := {}
	for id in old.teams:
		var t := PoloTeam.from_dict(old.teams[id])
		ratings[id] = t.rating()
		starter_ids[id] = t.starters().map(func(q: PoloPlayer): return q.id)
	var c2 := Career.from_dict(JSON.parse_string(JSON.stringify(old)))
	Game.career = c2
	check(c2.upgraded and c2.trimmed, "an old 8-man save is upgraded on load, and cut to seven (yours keeps its eighth on the bench)")
	var same_rating := true
	var same_start := true
	for id in c2.teams:
		var t: PoloTeam = c2.teams[id]
		check(t.roster.size() == (8 if id == c2.school else Career.ROSTER_MAX) and t.roster.filter(func(q): return q.is_keeper()).size() == 1, "%s cut to 7 (yours keeps 8), one keeper" % id)
		check(t.roster.filter(func(q: PoloPlayer): return q.schol).size() == Career.SCHOL_MAX, "%s: 4 scholarships" % id)
		check(t.roster.all(func(q: PoloPlayer): return q.region != "" and q.home != ""), "%s: everyone has a hometown" % id)
		same_rating = same_rating and absf(t.rating() - float(ratings[id])) < 0.001
		var ids: Array = t.roster.map(func(q: PoloPlayer): return q.id)
		same_start = same_start and (starter_ids[id] as Array).all(func(pid): return ids.has(pid))
	check(same_rating, "every team rating is exactly what it was")
	check(same_start, "every starting seven is kept")
	check(c2.converted and c2.market.size() == Recruiting.MARKET_SIZE and c2.incoming.is_empty(), "the old board is gone: the recruiting market opens (%d), nobody had committed" % c2.market.size())
	var c3 := Career.from_dict(JSON.parse_string(JSON.stringify(c2.to_dict())))
	check(not c3.upgraded and not c3.trimmed and JSON.stringify(c3.to_dict()) == JSON.stringify(c2.to_dict()), "an upgraded save loads unchanged")
	# a save from the 16-man days (version 2): cut to its starting seven too
	var older := _as_v4(c18, 16)
	older.v = 2
	var c4 := Career.from_dict(JSON.parse_string(JSON.stringify(older)))
	check(c4.trimmed and c4.upgraded, "a 16-man save is cut to its seven and upgraded")
	check(c4.teams.values().all(func(t: PoloTeam): return t.roster.size() == c4.roster_cap(t.id)), "...to 7 everywhere (yours to 10, a full bench)")
	var sizes: Array = []
	for _s in 3:
		var label := c2.season_label()
		var guard := 0
		while c2.season_label() == label and guard < 40:
			guard += 1
			c2.queue.clear()
			while c2.has_game():
				c2.sim_my_game()
			_autopilot_recruit(c2)
			c2.end_week()
			_make_cuts(c2)
		c2.game_over = false
		sizes.append(c2.team().roster.size())
		for id in c2.teams:
			var t: PoloTeam = c2.teams[id]
			var cap := c2.roster_cap(id)
			check(t.roster.size() >= Career.ROSTER_MAX and t.roster.size() <= cap and t.roster.filter(func(q): return q.is_keeper()).size() in range(1, c2.keeper_cap(id) + 1), "%s has 7 (yours up to 10) after the roster lock, its keepers" % id)
	print("  upgraded save, roster after each season: ", sizes)

## `c` saved the way version 4 had it: `n` on each roster (the core first), players without
## scholarships or hometowns, the old recruiting board (two of them offered), none of the
## recruiting year. n = 16 also brings back the old depth for a version-2 save.
func _as_v4(c: Career, n: int) -> Dictionary:
	var d := c.to_dict()
	d.v = 4
	for id in d.teams:
		var roster: Array = (d.teams[id].roster as Array).slice(0, n)
		for pd in roster:
			for k in ["schol", "home", "region"]:
				pd.erase(k)
		d.teams[id].roster = roster
	var board: Array = []
	for i in 40:
		var r := Recruiting.new_recruit(c)
		var pd: Dictionary = (r.p as PoloPlayer).to_dict()
		for k in ["schol", "home", "region"]:
			pd.erase(k)
		board.append({"p": pd, "stars": (r.p as PoloPlayer).stars, "interest": 20.0 + i, "offered": i < 2, "visited": i == 0, "called": 1 if i < 3 else 0, "committed": ""})
	d.recruits = board   # (the oldest saves' board: dropped on load, like all the old recruiting)
	for k in ["phase", "market", "incoming", "refreshes", "cr_claims"]:
		d.erase(k)
	return d

func _avg_ovr(t: PoloTeam) -> float:
	var s := t.starters()
	var total := 0.0
	for p in s:
		total += p.overall()
	return total / maxf(1.0, s.size())

## The autopilot coach spends on the cheapest facility or staff upgrade it can afford.
func _buy_something(c: Career) -> void:
	var best := ""
	var cost := 99999
	for k in Career.FAC_ORDER:
		var fc := c.facility_cost(k)
		if fc > 0 and fc < cost:
			best = "f:" + k
			cost = fc
	for k in Career.STAFF_ORDER:
		var sc := c.staff_cost(k)
		if sc > 0 and sc < cost:
			best = "s:" + k
			cost = sc
	if best != "" and c.wallet() >= cost:
		if best.begins_with("f:"):
			c.upgrade_facility(best.substr(2))
		else:
			c.hire_staff(best.substr(2))

## The autopilot coach takes the first job offer that comes.
func _take_offer(c: Career) -> void:
	for q in c.queue:
		if q.type == "offers" and not (q.offers as Array).is_empty():
			var best: String = q.offers[0]
			print("    takes the job at %s (%d)" % [best, int(c.teams[best].prestige)])
			Offseason.take_job(c, best)
			return

## The autopilot recruits like a careful player would: it saves its credits all season, then,
## the season done, signs the best stars it can pay for without going over next season's cap
## (the free refresh first if nobody on the market fits), up to the season's limit.
func _autopilot_recruit(c: Career) -> void:
	if c.phase != "done":
		return
	for _i in Recruiting.SIGN_MAX:
		var buy: Array = c.market.filter(func(r): return Recruiting.sign_block(c, r) == "" and Recruiting.over_by(c, 1) == 0)
		if buy.is_empty() and Recruiting.refresh_cost(c) == 0 and Recruiting.over_by(c, 1) == 0:
			Recruiting.refresh(c)
			buy = c.market.filter(func(r): return Recruiting.sign_block(c, r) == "")
		if buy.is_empty():
			return
		buy.sort_custom(func(a, b): return (a.p as PoloPlayer).stars > (b.p as PoloPlayer).stars)
		Recruiting.sign(c, buy[0])

## The autopilot's roster cuts (the game never cuts for you; a test coach has to): the weakest
## player it may cut, again and again, then on to the next season.
func _make_cuts(c: Career) -> void:
	var guard := 0
	while c.phase == "cuts" and not Offseason.roster_legal(c) and guard < 20:
		guard += 1
		var can: Array = c.team().roster.filter(func(p: PoloPlayer): return Offseason.cut_block(c, p) == "")
		if can.is_empty():
			break
		can.sort_custom(func(a: PoloPlayer, b: PoloPlayer): return a.overall() < b.overall())
		Offseason.cut(c, can[0])
	Offseason.finish_cuts(c)

# ------------------------------------------------------------------ the season schedule
## The schedule table: real rounds, Saturday dates, this week outlined, results where played.
func _check_schedule(c: Career) -> void:
	var sched = load("res://src/ui/screens/schedule.gd")
	check(sched.date_text(2026, 0, "reg") == "SEP 5" and sched.date_text(2026, 0, "reg", 0) == "SEP 4" and sched.date_text(2026, 0, "reg", 2) == "SEP 6", "week 1 of 2026-27: the first weekend in September, Friday to Sunday")
	check(sched.date_text(2026, 12, "conf_final") == "NOV 28" and sched.date_text(2026, 13, "nat_r1") == "DEC 12", "a week off before the NCSA Championship")
	var week0 := c.week
	for _i in 2:
		while c.has_game():
			c.sim_my_game()
		c.end_week()
	Game.goto("schedule")
	await get_tree().process_frame
	var rows: Array = Game.current_screen._rows()
	var mine := 0
	for i in Schedule.REGULAR_WEEKS:
		mine += c.my_games(c.schedule[i]).size()
	var empty_weeks := range(Schedule.REGULAR_WEEKS).filter(func(i): return c.my_games(c.schedule[i]).is_empty()).size()
	check(rows.size() == mine + empty_weeks + 7, "a row for each of the 16 games, each week without one, and the 7 playoff rounds (%d)" % rows.size())
	check(mine == Schedule.REGULAR_GAMES, "16 games on the table")
	# the first column is the game number now (GAME 1-16), not the week
	var next_no := Schedule.games_played(c.schedule, c.school) + 1
	var now: Array = rows.filter(func(d): return d.now)
	check(now.size() == 1 and (int(now[0].wk) == next_no or (now[0].wk == "" and now[0].opp == "BYE")), "one row is now: game %d" % next_no)
	check(String(now[0].result) == "< THIS WEEK", "...marked THIS WEEK")
	var played: Array = rows.filter(func(d): return d.wk != "" and int(d.wk) < next_no)
	check(played.all(func(d): return String(d.result).begins_with("W ") or String(d.result).begins_with("L ")), "the weeks played show their results")
	check(String(rows[rows.size() - 1].opp) == "TBD" and String(rows[rows.size() - 1].result) == "-", "the NCSA final is TBD until it's drawn")
	var saved := c.week
	c.week = c.schedule.size()
	check(Game.current_screen._rows().all(func(d): return not d.now), "season over: no week is highlighted")
	c.week = saved

# ------------------------------------------------------------------ career slots
## Five independent saves in a scratch folder (never the player's own): the old single save
## moves into a slot and is kept, CONTINUE takes the career played last, deleting empties only
## its slot, and the title and SELECT CAREER screens show what's there.
func test_slots() -> void:
	print("slots")
	var dir := "user://test_slots/"
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + f))
	var saved_dir := Game.save_dir
	var saved_career := Game.career
	var saved_slot := Game.slot
	Game.save_dir = dir
	Game.career = null
	Game.slot = 0
	Game.test_mode = false   # saving and the migration are off in tests; this folder is a scratch one
	Game._migrated = false
	check(not Game.has_save() and Game.last_slot() == 0 and Game.first_free_slot() == 1, "no careers in an empty folder")
	# the old single save moves into slot 1 and the original is kept beside it
	var old := Career.new_game("WAGN", "Old", "Save", 11)
	old.sim_my_game()
	old.end_week()
	var old_text := JSON.stringify(old.to_dict())
	var lf := FileAccess.open(dir + Game.LEGACY_SAVE_PATH, FileAccess.WRITE)
	lf.store_string(old_text)
	lf.close()
	Game._migrated = false
	check(Game.slot_exists(1) and Game.last_slot() == 1, "the old save moves into slot 1")
	check(not FileAccess.file_exists(dir + Game.LEGACY_SAVE_PATH) and FileAccess.get_file_as_string(dir + Game.LEGACY_KEPT_PATH) == old_text, "the original is kept, renamed")
	check(FileAccess.get_file_as_string(Game.slot_path(1)) == old_text, "slot 1 holds it byte for byte")
	var sm1 := Game.slot_summary(1)
	check(sm1.get("team", "") == old.team().name and int(sm1.get("season", 0)) == 1 and sm1.get("record", "") == old.record_text(), "slot 1's summary: team, season, record (%s)" % str(sm1))
	# a second career in slot 3, played after slot 1
	Game.slot = 3
	Game.career = Career.new_game("CULA", "New", "Coach", 22)
	Game.save_career()
	check(Game.slot_exists(3) and not Game.slot_exists(2) and Game.last_slot() == 3, "a new career in slot 3 is the one played last")
	# both load on their own, each with its own team and progress
	check(Game.load_career(1) and Game.slot == 1 and Game.career.school == "WAGN" and Game.career.week == old.week, "slot 1 loads its own career")
	check(Game.last_slot() == 1, "loading slot 1 makes it the last played")
	Game.career.credits = 999
	Game.save_career()
	check(Game.load_career(3) and Game.career.school == "CULA" and Game.career.credits != 999, "slot 3 isn't touched by slot 1's save")
	check(Game.load_career(1) and Game.career.credits == 999, "slot 1 kept its own change")
	check(not Game.load_career(2), "an empty slot doesn't load")
	# the title: CONTINUE (enabled) and NEW CAREER only, the icons up top
	Game.test_mode = true
	Game.goto("title")
	await get_tree().process_frame
	await get_tree().process_frame
	var labels := _button_texts(Game.current_screen)
	check(labels.has("CONTINUE") and labels.has("NEW CAREER") and not labels.has("QUICK MATCH") and not labels.has("MULTIPLAYER"), "title: CONTINUE and NEW CAREER only (%s)" % str(labels))
	var cont := _find_button(Game.current_screen, "CONTINUE")
	check(cont != null and not cont.disabled, "CONTINUE is on with a career saved")
	var icons: Array = Game.current_screen.get_children().filter(func(n): return n is Button and n.icon != null)
	check(icons.size() == 2 and icons.all(func(b: Button): return b.get_global_rect().position.y < 40.0), "help and settings sit in the top corners")
	# SELECT CAREER: five slots, DELETE on the two that are full
	Game.goto("careers")
	await get_tree().process_frame
	await get_tree().process_frame
	var scr := Game.current_screen
	var cards := range(1, 6).map(func(n): return scr.find_child("Slot%d" % n, true, false))
	check(cards.all(func(cd): return cd != null), "five slot cards")
	check(scr.find_child("Delete1", true, false) != null and scr.find_child("Delete3", true, false) != null and scr.find_child("Delete2", true, false) == null, "DELETE only on full slots")
	# deleting asks first, then empties only that slot
	Game.test_mode = false
	(scr.find_child("Delete3", true, false) as Button).pressed.emit()
	check(Game.slot_exists(3), "DELETE asks before deleting")
	var dlg: Control = Game.overlay.get_child(Game.overlay.get_child_count() - 1)
	(_find_button(dlg, "DELETE") as Button).pressed.emit()
	check(not Game.slot_exists(3) and Game.slot_exists(1) and Game.last_slot() == 1, "confirming deletes slot 3 only")
	# an empty slot starts a new career there, never over another
	Game.test_mode = true
	Game.goto("careers")
	await get_tree().process_frame
	(Game.current_screen.find_child("Slot2", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	check(Game.current_name == "new_career" and Game.slot == 2 and Game.career == null, "an empty slot opens NEW CAREER for that slot")
	Game.test_mode = false
	Game.current_screen._start()
	check(Game.slot_exists(2) and Game.slot_exists(1) and FileAccess.get_file_as_string(Game.slot_path(1)) != "", "the new career goes to slot 2, slot 1 stays")
	await get_tree().create_timer(0.5).timeout   # out of test mode the screen change fades: let it land
	check(Game.current_name == "drill", "and it opens with the tutorial")
	Game.test_mode = true
	# and with nothing saved, CONTINUE is off
	Game.delete_slot(1)
	Game.delete_slot(2)
	Game.goto("title")
	await get_tree().process_frame
	cont = _find_button(Game.current_screen, "CONTINUE")
	check(cont != null and cont.disabled and not Game.has_save(), "no career: CONTINUE is off")
	Game.save_dir = saved_dir
	Game.career = saved_career
	Game.slot = saved_slot
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + f))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))

func _button_texts(n: Node) -> Array:
	var out := []
	for b in n.find_children("*", "Button", true, false):
		if (b as Button).text != "":
			out.append((b as Button).text)
	return out

func _find_button(n: Node, text: String) -> Button:
	for b in n.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			return b
	return null

# ------------------------------------------------------------------ screens
## Opens every career screen and plays one career game on autoplay to the summary.
## Script errors show up in the output as SCRIPT ERROR lines; the checks cover the flow.
func test_screens() -> void:
	print("screens")
	Store.reset_for_tests()
	Game.career = Career.new_game("WAGN", "Test", "Coach", 77)
	var c := Game.career
	for scr in ["hub", "matchup", "more", "roster", "training", "facilities", "coaching", "scout", "recruiting", "schedule", "conference", "records", "store", "visual_shop", "settings", "form_lab", "tempo_lab", "howto", "new_career", "careers", "title", "quick_match"]:
		Game.goto(scr)
		for _i in 3:
			await get_tree().process_frame
		check(Game.current_name == scr and is_instance_valid(Game.current_screen), "screen opens: " + scr)
	Game.goto("player", {"id": c.team().roster[0].id})
	await get_tree().process_frame
	check(Game.current_name == "player", "player card opens")
	# a career game, played by the bot to the final whistle
	var played_g := c.my_game()
	var played_home := c.is_home()
	Game.match_cfg = {"us": c.team(), "them": c.opponent(), "seed": 5, "minutes": 1.0, "career": true,
		"home": c.is_home(), "pool": c.venue().id, "autoplay": true}
	Game.goto("match", Game.match_cfg)
	await get_tree().process_frame
	var ms = Game.current_screen
	var guard := 0
	while ms.flow.phase != MatchFlow.Phase.FINAL and guard < 20000:
		guard += 1
		ms._process(1.0 / 30.0)
		if ms.flow.phase in [MatchFlow.Phase.SHOOTOUT_THEM, MatchFlow.Phase.BREAK]:
			ms._press(Vector2(10, 10), 0)
			ms._press(Vector2(10, 10), 0)
	check(ms.flow.phase == MatchFlow.Phase.FINAL, "career game reaches full time")
	var final_score: Array = ms.flow.state.score.duplicate()
	ms._process(1.0 / 30.0)   # the screen's next frame puts the panel up
	check(ms.results != null and not ms.results.records.is_empty(), "the full-time panel shows the season records")
	# Android Back on the full-time card continues; it must never turn into a forfeit
	ms._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	ms._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().process_frame
	await get_tree().process_frame
	check(Game.current_name == "game_summary", "summary after the game")
	check(played_g.r != null, "the result is recorded")
	var rec: Array = played_g.r.s if played_g.r != null else [-1, -1]
	var mine: Array = [rec[0], rec[1]] if played_home else [rec[1], rec[0]]
	check(mine == final_score, "Back at full time keeps the real score (%s vs %s)" % [mine, final_score])
	var gp := 0
	for p in c.team().roster:
		gp += p.stat("gp")
	check(gp >= 7 and gp <= c.team().roster.size(), "the seven, and any sub who went in, credited with a game (%d)" % gp)
	var wk := c.week
	Game.current_screen._continue()
	await get_tree().process_frame
	await get_tree().process_frame
	check(Game.current_name == "postgame_review", "the POSTGAME REVIEW comes after the summary")
	check(c.week == wk, "the week isn't over until you leave the postgame")
	var lk = Game.current_screen
	for _i in 3:
		await get_tree().process_frame
	lk._continue()
	for _i in 2:
		await get_tree().process_frame
	if Game.current_name == "coach_event":   # (a coaching event, sometimes: answer it)
		Game.current_screen.pick = 0
		Game.current_screen._confirm()
		Game.current_screen._leave()
		await get_tree().process_frame
	var more := c.has_game() if c.week == wk else false
	check(c.week == wk + 1 or (c.week == wk and more), "leaving the postgame ends the week after your last game of it")
	check(Game.current_name == "hub", "back to the hub")
	for _i in 3:
		await get_tree().process_frame
	# the hub: the timeline opens the season schedule, the conference table the standings
	for tap in [["The whole season schedule", "schedule"], ["Full standings and playoffs", "conference"]]:
		Game.goto("hub", {}, false)
		await get_tree().process_frame
		var hit: Array = Game.current_screen.find_children("*", "Button", true, false).filter(func(b): return b.tooltip_text == tap[0])
		check(hit.size() == 1, "the hub has one '%s' tap" % tap[0])
		if hit.size() == 1:
			(hit[0] as Button).pressed.emit()
			await get_tree().process_frame
			check(Game.current_name == tap[1], "...and it opens %s" % tap[1])
			Game.current_screen.on_back()
			await get_tree().process_frame
			check(Game.current_name == "hub", "...and back returns to the hub")
	await _check_schedule(c)
	Game.career = null

# ------------------------------------------------------------------ multiplayer
## One side of a two-process match (tools/test_mp.sh runs both). Bots play every attack and
## tap the sprints; both processes print an MPRES line that must match.
##   --test mp host|join lan|online [minutes] [time_scale]
func test_mp(a: Array) -> void:
	var role: String = a[0] if a.size() > 0 else "host"
	var link: String = a[1] if a.size() > 1 else "lan"
	var minutes := float(a[2]) if a.size() > 2 else 0.5
	Engine.time_scale = float(a[3]) if a.size() > 3 else 3.0
	Game.test_mode = true
	Game.settings.mp_name = "BOT" + role.to_upper().substr(0, 1)
	Net.match_params = {"autoplay": true}
	Net.cfg.minutes = minutes
	var tree := get_tree()
	var err := OK
	if a.has("badcode"):
		# a wrong room code must say so, not "can't reach the server"
		var why := [""]
		Net.join_failed.connect(func(r): why[0] = r)
		check(Net.join({"code": "ZZZZ"}, "online") == OK, "a join opens")
		var w := 0
		while why[0] == "" and w < 600:
			await tree.process_frame
			w += 1
		print("  join failed: ", why[0])
		check(why[0].begins_with("No room"), "a wrong code says there's no such room (%s)" % why[0])
		Engine.time_scale = 1.0
		return
	var code_file := "user://mp_test_code.txt"
	if link == "online" and role == "host" and a.has("code"):
		# room-code flow: the host shares its code (through a file here), the guest types it
		DirAccess.remove_absolute(ProjectSettings.globalize_path(code_file))
		err = Net.host("online")
		var w := 0
		while Net.room_code() == "" and w < 600:
			await tree.process_frame
			w += 1
		var f := FileAccess.open(code_file, FileAccess.WRITE)
		f.store_string(Net.room_code())
		f.close()
		print("  room code ", Net.room_code())
	elif link == "online" and a.has("code"):
		var w := 0
		while not FileAccess.file_exists(code_file) and w < 1200:
			await tree.process_frame
			w += 1
		await tree.create_timer(0.3).timeout
		var code := FileAccess.get_file_as_string(code_file).strip_edges()
		err = Net.join({"code": code}, "online")
	elif link == "online":
		err = Net.join({"quick": true}, "online")
	elif role == "host":
		err = Net.host(link)
	else:
		await tree.create_timer(1.0).timeout
		err = Net.join({"addr": "127.0.0.1", "port": LanTransport.PORT, "name": "HOST"}, "lan")
	check(err == OK, "%s %s opens" % [role, link])
	var waited := 0.0
	while Net.game == null and waited < 30.0:
		if Net.can_start():
			Net.start_match()
		await tree.process_frame
		waited += tree.root.get_process_delta_time() / Engine.time_scale
	check(Net.game != null, "the match starts")
	if Net.game == null:
		return
	var g: MpMatch = Net.game
	print("  I am side %d (%s), %s" % [g.me, "host" if g.is_host() else "guest", link])
	var frames := [0]
	var events := [0]
	var duels := [0, 0]   # [their shots I saved or let in, my shots they called]
	g.remote_frame.connect(func(_f): frames[0] += 1)
	g.remote_event.connect(func(e):
		events[0] += 1
		if String(e.get("k", "")) == "duel":
			duels[0] += 1)
	g.remote_verdict.connect(func(_o, _s, _n): duels[1] += 1)
	var shots_dir := ""
	for x in a:
		if String(x).begins_with("shots="):
			shots_dir = String(x).substr(6)
	var leave_after := -1.0
	for x in a:
		if String(x).begins_with("leave="):
			leave_after = float(String(x).substr(6))
	if leave_after > 0.0:
		# walk out mid-match: the other phone must finish with a forfeit win
		await tree.create_timer(leave_after * Engine.time_scale).timeout
		print("  leaving mid-match")
		Net.leave()
		Engine.time_scale = 1.0
		check(true, "left")
		return
	var shot_watch := false
	var shot_mine := false
	waited = 0.0
	while g.phase != MpMatch.Phase.FINAL and waited < 400.0 and Net.active():
		await tree.process_frame
		waited += tree.root.get_process_delta_time() / Engine.time_scale
		if shots_dir != "" and g.phase == MpMatch.Phase.ATTACK and Net.now_ms() > g.go_at + 2500.0:
			if g.att != g.me and not shot_watch:
				shot_watch = true
				await _mp_shot(shots_dir, "mp_watch")
			elif g.att == g.me and not shot_mine:
				shot_mine = true
				await _mp_shot(shots_dir, "mp_attack")
	check(g.phase == MpMatch.Phase.FINAL, "the match reaches full time")
	if g.forfeit:
		check(g.winner == g.me, "the phone that stayed wins by forfeit")
	else:
		check(g.seq >= 4, "several possessions were played (%d)" % g.seq)
		check(frames[0] > 20, "watched the other phone's attacks live (%d frames)" % frames[0])
		check(events[0] > 0, "heard the other phone's shots and saves (%d)" % events[0])
		print("  keeper duels: defended %d, called by them %d" % [duels[0], duels[1]])
		check(duels[0] + duels[1] > 0, "shots went to the other phone's keeper")
	print(g.result_line())
	await tree.create_timer(1.5).timeout
	Net.leave()
	Engine.time_scale = 1.0

func _mp_shot(dir: String, name: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	print("  shot " + name)

# ------------------------------------------------------------------ the keeper duel
## Goal rates of their shots for keepers who never dive, dive late and loosely, and dive well,
## at each difficulty. A good dive has to matter; no dive must still save some.
func test_duel() -> void:
	print("keeper duel (goals per shot)")
	var shooter := PoloPlayer.new()
	shooter.shoot = 62
	var gk := PoloPlayer.new()
	gk.pos = PoloPlayer.Pos.GK
	gk.keeping = 62
	var rates := {}
	for lv in [0.0, 0.5, 1.0]:
		var line := "  level %.1f:" % lv
		for skill in [0.0, 0.4, 0.7, 1.0]:
			var rng := RandomNumberGenerator.new()
			rng.seed = 5
			var brng := RandomNumberGenerator.new()
			brng.seed = 6
			var goals := 0
			var n := 2000
			for i in n:
				var from: Vector2 = OppSim.SPOTS[i % OppSim.SPOTS.size()][1] + Vector2(0, rng.randf_range(-2.0, 2.0))
				var d := KeeperDuel.new().setup(shooter, gk, from, 0.0, rng, lv)
				if d.auto(skill, brng) == "goal":
					goals += 1
			rates["%s:%s" % [lv, skill]] = goals / float(n)
			line += "  skill %.1f %.2f" % [skill, goals / float(n)]
		print(line)
	# no dive: only the ones that miss, or come straight at him (KeeperDuel.BODY_R), stay out
	check_between(rates["0.5:0.0"], 0.65, 0.92, "no dive at medium: nearly everything on target goes in")
	check_between(rates["0.5:0.4"], 0.35, 0.65, "a loose, late dive at medium")
	check_between(rates["0.5:1.0"], 0.1, 0.35, "a great keeper at medium still concedes some")
	check(rates["0.0:0.4"] == rates["0.5:0.4"] and rates["0.5:0.4"] == rates["1.0:0.4"],
		"the difficulty never changes your keeper's dive, their shooter's wind-up or his accuracy")
	# committing early against a good shooter is a gamble
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 9
	var early := 0
	for i in 1000:
		var d := KeeperDuel.new().setup(shooter, gk, Vector2(5.0, 10.0), 0.0, rng2, 0.0)
		d.tap(Geo.GOAL_Y + (1.2 if i % 2 == 0 else -1.2))
		while not d.done():
			d.step(0.01)
		if d.outcome == "goal":
			early += 1
	print("  guessing a corner during the wind-up: %.2f goals" % (early / 1000.0))
	check(early / 1000.0 > rates["0.5:0.7"], "guessing early is worse than reacting")

# ------------------------------------------------------------------ penalties
## The 5 m formation (one defender either side of the shooter, everybody else staggered just past
## half pool, nobody moving), the shootout (only the shooter and the keeper), and their keeper's dive: a
## 50/50 guess at the release, never from the aim, committed to all the way.
func test_penalties() -> void:
	print("penalties")
	var teams := _teams()
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var p := Play.new(teams[0], teams[1], Play.Kind.PENALTY, rng)
	var sh := p.holder
	check(sh == p.taker and sh.pos == Vector2(Geo.FIVE_M, Geo.GOAL_Y), "the shooter is on the 5 m line, square to the goal")
	check(p.keeper.pos == Vector2(Geo.KEEPER_X, Geo.GOAL_Y), "their keeper starts in the middle of his goal")
	var beside := p.defenders.filter(func(d: Swimmer): return absf(d.pos.x - Geo.FIVE_M) < 1.0)
	check(beside.size() == 2, "two defenders beside the shooter (%d)" % beside.size())
	check(beside.filter(func(d: Swimmer): return d.pos.y < Geo.GOAL_Y).size() == 1
		and beside.filter(func(d: Swimmer): return d.pos.y > Geo.GOAL_Y).size() == 1, "exactly one on each side of him")
	var ys := beside.map(func(d: Swimmer): return d.pos.y - Geo.GOAL_Y)
	ys.sort()
	check(ys.size() == 2 and is_equal_approx(ys[0], -2.2) and is_equal_approx(ys[1], 2.2) and beside.all(func(d: Swimmer): return d.pos.x < Geo.FIVE_M), "...symmetric, wide of him and a little back (%s)" % str(ys))
	var field := p.attackers + p.defenders
	check(field.all(func(s: Swimmer): return s == sh or s.pos.x <= sh.pos.x + 0.01), "nobody between the shooter and the goal")
	var halfway := field.filter(func(s: Swimmer): return not beside.has(s) and s != sh)
	check(halfway.size() == 9 and halfway.all(func(s: Swimmer): return s.pos.x >= Geo.HALF and s.pos.x <= Geo.HALF + 2.0),
		"everybody else lines up just past half pool")
	check(halfway.any(func(s: Swimmer): return s.pos.x != halfway[0].pos.x), "...staggered, not in a dead straight line")
	# the match camera on the penalty (the 480 px canvas): the shooter and the goal in the picture,
	# only the edge of the half-pool line (a body is 16 px across)
	var pv := PoolView.new()
	pv.snap_to(PoolView.attack_focus(p.ball.pos))
	var xs := halfway.map(func(s: Swimmer): return pv.to_screen(s.pos).x)
	check(xs.all(func(x): return x < 8.0) and xs.any(func(x): return x > -8.0),
		"the half-pool line is just in at the left edge (%s)" % str(xs))
	check(pv.to_screen(sh.pos).x > 200.0 and pv.to_screen(Vector2(Geo.GOAL_X, Geo.GOAL_Y)).x < pv.width, "...with the shooter and the goal in shot")
	var tight := INF
	var all_b := p.bodies()
	for i in all_b.size():
		for j in range(i + 1, all_b.size()):
			tight = minf(tight, all_b[i].pos.distance_to(all_b[j].pos))
	check(tight >= 1.4, "nobody overlaps (closest pair %.2f m)" % tight)
	var before := field.map(func(s: Swimmer): return s.pos)
	for i in 60:
		p.step(1.0 / 60.0)
	check(field.map(func(s: Swimmer): return s.pos) == before, "nobody moves before the shot")
	# their keeper's guess: from what he can see (KeeperAI: a shooter square on, 5 m out), never the
	# aim; LEFT and RIGHT alike, UP now and then; whichever way, all the way
	var lefts := 0
	var rights := 0
	var ups := 0
	var right_saves := 0
	var right := 0
	var wrong_saves := 0
	var wrong := 0
	var committed := true
	var blind := true
	var n := 2000
	for i in n:
		var r1 := RandomNumberGenerator.new()
		r1.seed = 500 + i
		var r2 := RandomNumberGenerator.new()
		r2.seed = 500 + i
		var aim_y := Geo.GOAL_Y + (1.2 if i % 2 == 0 else -1.2)
		var a := ShotModel.resolve(Vector2(Geo.FIVE_M, Geo.GOAL_Y), aim_y, 0.8, 65.0, 9.0, [], Geo.GOAL_Y, 62.0, r1, true, {}, {"exact": true})
		var b := ShotModel.resolve(Vector2(Geo.FIVE_M, Geo.GOAL_Y), Geo.GOAL_Y * 2.0 - aim_y, 0.8, 65.0, 9.0, [], Geo.GOAL_Y, 62.0, r2, true, {}, {"exact": true})
		blind = blind and a.read_side == b.read_side and a.anticipated == b.anticipated   # the same dice, the other corner: the same guess
		var g := float(a.read_side)
		match int(g):
			-1:
				lefts += 1
			0:
				ups += 1
			1:
				rights += 1
		# (from 5 m every keeper guesses, KeeperAI: he's gone before he can read it; a panic claws back, never across)
		committed = committed and int(a.anticipated) == int(g) and (g == 0.0 or (float(a.keeper_end_y) - Geo.GOAL_Y) * g > -KeeperDive.PANIC_WALL.x)
		var saved := String(a.outcome) in ["save", "parry"]
		if signf(aim_y - Geo.GOAL_Y) == g:
			right += 1
			right_saves += int(saved)
		else:
			wrong += 1
			wrong_saves += int(saved)
	print("  guesses left %.2f right %.2f up %.2f; saves: guessed right %.2f, wrong %.2f" % [lefts / float(n), rights / float(n), ups / float(n),
		right_saves / float(maxi(1, right)), wrong_saves / float(maxi(1, wrong))])
	check(absf(lefts - rights) / float(n) < 0.06, "their keeper goes left and right alike against a shooter square on")
	check_between(ups / float(n), 0.1, 0.4, "...and up now and then")
	check(blind, "the guess doesn't depend on where you aim")
	check(committed, "he always goes the way he guessed, however the ball goes (a panic claws back, never across)")
	check(right_saves / float(maxi(1, right)) > 0.5 and wrong_saves == 0, "guess right and he saves most; guess wrong and it's in")
	# a normal shot is anticipated the same way: never from the aim
	var blind2 := true
	for i in 300:
		var r3 := RandomNumberGenerator.new()
		r3.seed = 70 + i
		var r4 := RandomNumberGenerator.new()
		r4.seed = 70 + i
		blind2 = blind2 and int(ShotModel.resolve(Vector2(25, 9), 11.2, 0.8, 65.0, 5.0, [], 10.0, 62.0, r3, false, {}, {"hold": 1.5}).read_side) \
			== int(ShotModel.resolve(Vector2(25, 9), 8.8, 0.8, 65.0, 5.0, [], 10.0, 62.0, r4, false, {}, {"hold": 1.5}).read_side)
	check(blind2, "a normal shot's anticipation isn't read off the aim either (his reaction, after the release, is)")
	# a penalty Play: he goes at the release, one way only, and the screen shows where he is
	var moves_ok := true
	for i in 40:
		var pr := RandomNumberGenerator.new()
		pr.seed = 900 + i
		var pp := Play.new(teams[0], teams[1], Play.Kind.PENALTY, pr)
		pp.shoot_at(Vector2(Geo.GOAL_X, Geo.GOAL_Y + (1.3 if i % 3 == 0 else -0.9)), 0.8)
		var g := float(pp.ball.shot.guess)   # (the way he went: his guess, or the ball if he read it first)
		var last := pp.keeper.pos.y
		var t := 0.0
		while not pp.over and t < 3.0:
			pp.step(1.0 / 60.0)
			t += 1.0 / 60.0
			var dy := pp.keeper.pos.y - last
			var clawing: bool = (pp.keeper.pose != null and pp.keeper.pose.turned() and pp.keeper.pose.t >= pp.keeper.pose.turn_t) \
				or pp.ball.shot.get("reposed", false)   # (a lean the wrong way, corrected: a new dive)
			if not clawing and (dy * g < -0.0001 or (g == 0.0 and absf(dy) > 0.0001)):
				moves_ok = false
			if clawing and g != 0.0 and (pp.keeper.pos.y - Geo.GOAL_Y) * g < -KeeperDive.PANIC_WALL.x:
				moves_ok = false
			last = pp.keeper.pos.y
			if pp.ball.state != Ball.State.SHOT:
				break
		var leaned := String(pp.ball.shot.gk.kind) == "panic" and absf(pp.keeper.pos.y - Geo.GOAL_Y) < KeeperDive.PANIC_WALL.x   # (up, then a lean towards it)
		if (g != 0.0 and signf(pp.keeper.pos.y - Geo.GOAL_Y) != g) or (g == 0.0 and not leaned and not is_equal_approx(pp.keeper.pos.y, Geo.GOAL_Y)):
			moves_ok = false
	check(moves_ok, "in play he dives the way he guessed and never turns back, bar a panic's claw back (never across)")
	# the shootout: only the shooter and the keeper
	var f := MatchFlow.new(teams[0], teams[1], 77, MatchState.QUARTER_MIN)
	f.state.in_shootout = true
	f._start_attack(Play.Kind.PENALTY)
	var bs := f.play.bodies()
	check(f.play.shootout and bs.size() == 2 and bs.has(f.play.taker) and bs.has(f.play.keeper), "a shootout penalty is just the shooter and the keeper")
	check(f.play.taker.pos == Vector2(Geo.FIVE_M, Geo.GOAL_Y) and f.play.keeper.pos.y == Geo.GOAL_Y, "...on the 5 m line, the keeper in the middle")
	f.play.shoot_at(Vector2(Geo.GOAL_X, Geo.GOAL_Y + 1.2), 0.8)
	check(f.play.ball.shot.has("read") and int(f.play.ball.shot.guess) in [-1, 0, 1], "...and their keeper picks a way to go")
	while not f.play.over:
		f.tick_attack(1.0 / 60.0)
	check(f.play.bodies().size() == 2, "...all the way to the end of it")
	var goal := String(f.play.result.outcome) == "goal"
	f.attack_done()
	check(f.state.shootout[0] == (1 if goal else 0) and f.phase == MatchFlow.Phase.SHOOTOUT_THEM, "the shootout score and their turn follow")
	f.their_ball_done()
	check(f.duel != null and f.duel.penalty and f.duel.keeper_y == Geo.GOAL_Y, "your keeper starts their penalty in the middle")
	# a normal penalty in a match isn't a shootout one
	var f2 := MatchFlow.new(teams[0], teams[1], 78, MatchState.QUARTER_MIN)
	f2._start_attack(Play.Kind.PENALTY)
	check(not f2.play.shootout and f2.play.bodies().size() == 13, "a 5 m penalty in the game has everybody in the water")
	# ...and the two never mix: a shootout kick after a game penalty has nobody beside him, and a
	# game penalty after the shootout flag is cleared has its defenders back
	var f3 := MatchFlow.new(teams[0], teams[1], 79, MatchState.QUARTER_MIN)
	f3._start_attack(Play.Kind.PENALTY)
	f3.state.in_shootout = true
	f3._start_attack(Play.Kind.PENALTY)
	var tk := f3.play.taker
	var others3 := (f3.play.attackers + f3.play.defenders).filter(func(s): return s != tk)
	check(f3.play.shootout and others3.all(func(s: Swimmer): return s.pos.x < 10.0), "a shootout kick: nobody beside the shooter or at half pool")
	f3.state.in_shootout = false
	f3._start_attack(Play.Kind.PENALTY)
	check(not f3.play.shootout and f3.play.bodies().size() == 13, "...and a game penalty after it is the game formation again")

## A steal, either way: while the banner is up the team that won it turns at once and goes for
## the other goal (nobody on it ever drifts back towards his own), the team that lost it turns and
## gets back; the next possession is decided from where everybody was at the steal, and its
## attack sets off forwards (a counter if it's a man up, otherwise the normal set-up).
func test_breakout() -> void:
	print("steals: the breakout")
	var teams := _teams()
	var dt := 1.0 / 60.0
	var hold := 1.5   # MatchScreen.END_HOLD
	var counters := 0
	for side in ["yours", "theirs"]:
		var back_win := 0.0     # fastest a winner swam towards his own goal
		var slow_win := 0       # winners not yet away up the pool at the end of the banner
		var slow_lose := 0      # losers not yet swimming back
		var snap_ok := true
		var back_next := 0.0    # the next attack, its first half second: fastest back the wrong way
		for seed_i in 25:
			var f := MatchFlow.new(teams[0], teams[1], 300 + seed_i, MatchState.QUARTER_MIN)
			f.auto_keeper = 0.5
			if side == "yours":
				f._start_attack(Play.Kind.HALF_COURT)   # your attack: they steal it
			else:
				f._start_defense(Play.Kind.HALF_COURT)  # theirs: your AI defence steals it
			var p := f.play
			for i in 150:   # set up and moving
				if side == "yours":
					f.tick_attack(dt)
				else:
					f.opp_hold = -99.0   # (he holds it, so the steal is ours to make)
					f.tick_defense(dt)
			if p.over or p.holder == null:
				continue
			var thief := p._marker(p.holder)
			if thief == null:
				thief = p.defenders[0]
			p._turnover(thief, "STOLEN!", "steal")
			var at := {}
			for s in p.attackers + p.defenders:
				at[s.player] = Vector2(Geo.LENGTH - s.pos.x, s.pos.y)
			var t := 0.0
			while t < hold:
				if side == "yours":
					f.tick_attack(dt)
				else:
					f.tick_defense(dt)
				t += dt
				for d in p.defenders:
					back_win = maxf(back_win, d.vel.x)
			for d in p.defenders:
				if d.vel.x > -0.8:
					slow_win += 1
			for a in p.attackers:
				if a.vel.x > -0.3:
					slow_lose += 1
			var snap := p.snapshot()
			for pl in at:
				snap_ok = snap_ok and snap.pos[pl].is_equal_approx(at[pl])
			if side == "yours":
				f.attack_done()
			else:
				f.defense_done()
			if f.play == null or f.phase in [MatchFlow.Phase.BREAK, MatchFlow.Phase.FINAL]:
				continue
			var q := f.play
			if q.kind == Play.Kind.COUNTER:
				counters += 1
			t = 0.0
			while t < 0.5 and not q.over:
				if f.phase == MatchFlow.Phase.ATTACK:
					f.tick_attack(dt)
				else:
					f.opp_hold = -99.0
					f.tick_defense(dt)
				t += dt
				for a in q.attackers:
					if not a.out:
						back_next = maxf(back_next, -a.vel.x)
		print("  %s ball stolen: winners' worst drift back %.2f m/s, %d slow away; %d losers slow to turn; next attack's worst back %.2f m/s" % [side, back_win, slow_win, slow_lose, back_next])
		check(back_win <= 0.01, "%s steal: the team that won it never swims back towards its own goal" % side)
		check(slow_win == 0, "%s steal: ...and is away up the pool before the banner's gone" % side)
		check(slow_lose == 0, "%s steal: the team that lost it has turned and is getting back" % side)
		check(snap_ok, "%s steal: the next possession picks up from where everybody was at the steal" % side)
		check(back_next < 0.3, "%s steal: the next attack sets off forwards" % side)
	print("  (%d of the next possessions were counters)" % counters)

## The set attack and the centre: the umbrella spread out with the point just outside 6 m (in
## both attacks), the centre's guard holding a side rather than following the ball, swinging it
## to open the entry, and what a ball in from each side does. Then where a steal was made: top
## line a break (3 on 2, 2 on 1, now and then 1 on 0), bottom line straight into the set attack.
func test_center() -> void:
	print("the set attack and the centre")
	var h := PlaySetup.HOME_6V6
	var arc := ["5", "4", "3", "2", "1"]
	var tight := INF
	for i in 4:
		tight = minf(tight, (h[arc[i]] as Vector2).distance_to(h[arc[i + 1]]))
	check(h["3"].x < Geo.SIX_M and h["3"].x > Geo.SIX_M - 1.0, "the point's spot is just outside 6 m (%.1f m out)" % (Geo.GOAL_X - h["3"].x))
	check(tight >= 3.2, "the perimeter is spread out: at least 3.2 m between neighbours (%.1f)" % tight)
	var mirrored := true
	for pair in [["1", "5"], ["2", "4"]]:
		var a: Vector2 = h[pair[0]]
		var b: Vector2 = h[pair[1]]
		mirrored = mirrored and is_equal_approx(a.x, b.x) and is_equal_approx(a.y - Geo.GOAL_Y, Geo.GOAL_Y - b.y)
	check(mirrored, "the umbrella is the same on both sides of the pool")
	# both attacks, live: the point's never sent inside 6 m in the set-up; the centre's guard
	# holds a side, and only goes round once the ball's been on the other side a while
	var point_in := 0
	var point_n := 0
	var point_why := ""
	var held_n := 0
	var guard_n := 0
	var flips := 0
	var quickest := INF
	var entries := {}
	var feeds := {}
	for i in 24:
		var teams := [League.make_team(i % 8, 0), League.make_team((i + 3) % 8, 0)]
		var f := MatchFlow.new(teams[0], teams[1], 8800 + i, MatchState.QUARTER_MIN)
		f.auto_keeper = 0.5
		var theirs := i % 2 == 0
		if theirs:
			f._start_defense(Play.Kind.HALF_COURT)
		else:
			f._start_attack(Play.Kind.HALF_COURT)
		var p := f.play
		var c := PlaySetup._by_tag(p, "C")
		var pt := PlaySetup._by_tag(p, "3")
		var last_side := 0
		var since := 0.0
		var g0: Swimmer = null
		var flipped := false
		var drove := 0.0
		var t := 0.0
		var think := 0.0
		var brng := RandomNumberGenerator.new()
		brng.seed = 31 + i
		while not p.over and t < 25.0 and f.phase in [MatchFlow.Phase.ATTACK, MatchFlow.Phase.DEFENSE]:
			if theirs:
				f.tick_defense(1.0 / 30.0)
			else:
				think -= 1.0 / 30.0
				if think <= 0.0:
					think = PlayBot.THINK_EVERY
					var dd := PlayBot.think(p, brng, p.openness(p.holder) < 1.2 if p.holder != null else false)
					if not dd.is_empty():
						p.throw(dd.target, dd.power)
				f.tick_attack(1.0 / 30.0)
			t += 1.0 / 30.0
			since += 1.0 / 30.0
			if p.man_up > 0.0 or p.carry or p.freeze > 0.0:
				continue
			# (not chasing a loose ball, or the frame it was picked up, and not on or just off a drive)
			drove = 0.0 if pt.drive_t > 0.0 or p.ball.state == Ball.State.LOOSE else drove + 1.0 / 30.0
			if pt != p.holder and pt != p.ball.receiver and drove > 0.1 and t > 4.0:
				point_n += 1
				if pt.target.x > PlaySetup.POINT_MAX_X + 1e-3:
					point_in += 1
					if point_why == "":
						point_why = "%s at %s -> %s, ball %d, holder %s, rotating %s, theirs %s" % [p.elapsed, pt.pos, pt.target, p.ball.state,
							p.holder.tag if p.holder else "-", p.rotating != null, theirs]
			var g := p._center_guard(c)
			# (set: not still swimming in with his man on his back, PlayAI._center_trail)
			if g != null and c != p.holder and not PlayAI.center_swimming_in(p, c):
				guard_n += 1
				if Play.center_side_held(g, c) != 0:
					held_n += 1
			# the side he's chosen to hold (where he's going, so a bump on the way round isn't a flip)
			if g != null and g == g0 and g.cside != 0:
				if last_side != 0 and g.cside != last_side:
					flips += 1
					if flipped:
						quickest = minf(quickest, since)   # (from his last switch to this one)
					flipped = true
					since = 0.0
				last_side = g.cside
			elif g != null and g0 == null:
				g0 = g
				last_side = g.cside
				since = 0.0
			if theirs and p.holder != null and p.holder != c and p.ball.state == Ball.State.HELD:
				var e := p.center_entry(p.holder.pos, c)
				if e == "open" and p.entry_closing(c):
					e = "closing"
				entries[e] = int(entries.get(e, 0)) + 1
			if p.ball.state == Ball.State.PASS and p.ball.receiver == c and p.ball.t * p.ball.dur < 1.0 / 30.0 + 1e-4:
				var k := ("theirs " if theirs else "yours ") + p.entry
				feeds[k] = int(feeds.get(k, 0)) + 1
	print("  the point inside 6 m in the set-up: %d of %d looks; the centre's guard on a side %.0f%% of the time, %d switches (quickest %.1f s after the last)" % [point_in, point_n, 100.0 * held_n / maxf(1.0, guard_n), flips, quickest])
	print("  their man with the ball, the entry: %s; balls into the centre: %s" % [str(entries), str(feeds)])
	check(point_n > 0 and point_in == 0, "the point never sets up inside 6 m " + point_why)
	check(held_n > guard_n * 0.6, "the centre's guard holds a side most of the time")
	check(flips > 1 and quickest >= PlayAI.CENTER_SWITCH + PlayAI.CENTER_SWITCH_WAIT.y - 0.05, "...and never flips straight back (%.1f s)" % quickest)
	# a swing: ball on the left (4), the guard settles on that side; swung to the right (2), the
	# entry from there is open, and stays open a moment; then he comes round and it's his
	for defending in [false, true]:
		var who := "theirs" if defending else "yours"
		var sp := _center_play(91, defending)
		var c := PlaySetup._by_tag(sp, "C")
		var left := PlaySetup._by_tag(sp, "4")
		var right := PlaySetup._by_tag(sp, "2")
		sp.give_ball(left)
		_hold(sp, 2.5)
		var g := sp._center_guard(c)
		check(g != null and Play.center_side_held(g, c) == -1, "%s: the ball on the left, the centre's guard is on the left of him" % who)
		check(sp.center_entry(left.pos, c) == "fronted" and sp.center_entry(right.pos, c) == "open",
			"%s: ...so from the left it's his, from the right it's open" % who)
		sp.raise_ball(false)
		sp._pass(sp.lead_point(right), right)
		var t := 0.0
		while sp.ball.state == Ball.State.PASS and t < 2.0:
			sp.step(1.0 / 60.0)
			t += 1.0 / 60.0
		check(sp.holder == right and sp.center_entry(right.pos, c) == "open", "%s: swung to the right, the entry from there is open" % who)
		_hold(sp, 0.6)
		check(sp.center_entry(right.pos, c) == "open", "%s: ...and still is a beat later (he doesn't flip at once)" % who)
		_hold(sp, 3.0)
		check(Play.center_side_held(sp._center_guard(c), c) == 1 and sp.center_entry(right.pos, c) == "fronted",
			"%s: given time, he comes round to the right and shuts it" % who)
	# the entry itself: into the side he's on (he's in the lane), he picks it off, every time; from
	# the open side the centre has it, a real entry (he draws his exclusion going up: test_rules).
	# Same rules for both teams.
	for defending in [false, true]:
		var who := "theirs" if defending else "yours"
		var tally := {"fronted": {}, "open": {}}
		for kind in ["fronted", "open"]:
			for sd in 200:
				var ep := _center_play(1200 + sd, defending)
				var c := PlaySetup._by_tag(ep, "C")
				var from := PlaySetup._by_tag(ep, "2")
				var g := ep._center_guard(c)
				var side := 1 if kind == "fronted" else -1
				g.cside = side
				g.pos = c.pos + Vector2(-PlayAI.CENTER_UP, side * PlayAI.CENTER_SIDE)
				g.target = g.pos
				ep.give_ball(from)
				if ep.center_entry(from.pos, c) != kind:
					continue
				ep._pass(ep.lead_point(c), c)
				var t := 0.0
				while ep.ball.state == Ball.State.PASS and t < 2.0:
					ep.step(1.0 / 60.0)
					t += 1.0 / 60.0
				var out := "catch" if ep.center_fed == c else "catch, not fed"
				if ep.over:
					out = String(ep.result.outcome)
				elif ep.man_up > 0.0:
					out = "exclusion"
				elif ep.holder != c:
					out = "other"
				tally[kind][out] = int(tally[kind].get(out, 0)) + 1
		var fr: Dictionary = tally.fronted
		var op: Dictionary = tally.open
		var fn := 0
		var on := 0
		for k in fr:
			fn += int(fr[k])
		for k in op:
			on += int(op[k])
		print("  %s: into the side he's on %s; from the open side %s" % [who, str(fr), str(op)])
		# (his hands on it every time; DefenseFormation.FRONT_LOOSE of them knocked loose under his nose)
		var loose := int(fr.get("other", 0))
		check(fn > 150 and int(fr.get("steal", 0)) + loose == fn and int(fr.get("steal", 0)) > fn / 2 and loose > 0,
			"%s: fed into the side the centre's guard is on, it's never the centre's: picked off, or knocked loose (%d of %d)" % [who, loose, fn])
		check(on > 150 and int(op.get("steal", 0)) == 0, "%s: from the open side it's never picked off by his guard" % who)
		check(int(op.get("catch", 0)) == on, "%s: ...the centre catches it, a real entry, and nobody's whistled before he shoots" % who)
	_test_steal_lines()

## A half-court possession, everybody on his spot and his man, the centre's guard on him.
func _center_play(seed_value: int, defending: bool) -> Play:
	var teams := _teams()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var p := Play.new(teams[0], teams[1], Play.Kind.HALF_COURT, rng)
	p.defending = defending
	for a in p.attackers:
		a.pos = a.home
		a.target = a.home
	for d in p.defenders:
		d.pos = d.mark.pos + (Geo.goal_center() - d.mark.pos).normalized() * (0.55 if d.mark.tag == "C" else 1.0)
		d.target = d.pos
	p.drive_timer = 99.0
	return p

func _test_steal_lines() -> void:
	# top line (the perimeter: 2, 3, 4): a break, in the numbers asked for, led by different men
	var numbers := {}
	var tops := 0
	var groups := {}   # the 3 on 2s from each spot, by who's in them
	var spot_n := {}
	for tag in ["2", "3", "4"]:
		for sd in 200:
			var lost := _steal_from(tag, 9100 + sd)
			var rng := RandomNumberGenerator.new()
			rng.seed = 9500 + sd
			var c := Play.new(lost.them, lost.us, Play.Kind.COUNTER, rng, lost.snapshot())
			if sd == 0:
				check(c.steal_line == "top", "a steal from %s is a top-line steal" % tag)
			tops += 1
			if c.kind != Play.Kind.COUNTER:
				continue
			var k := "%d on %d" % [c.break_n.x, c.break_n.y]
			numbers[k] = int(numbers.get(k, 0)) + 1
			var men: Array = []
			for a in c.attackers:
				if a.pos.x >= c.holder.pos.x - Play.BREAK_TRAIL:
					men.append(a.tag)
			men.sort()
			if c.break_n.x == 3:
				groups[tag + str(men)] = int(groups.get(tag + str(men), 0)) + 1
				spot_n[tag] = int(spot_n.get(tag, 0)) + 1
	var share := func(k: String) -> float: return float(numbers.get(k, 0)) / maxf(1.0, tops)
	var top_group := 0.0
	for k: String in groups:
		top_group = maxf(top_group, float(groups[k]) / float(spot_n[k.left(1)]))
	print("  top-line steals: %d: %s (3 on 2 %.0f%%, 2 on 1 %.0f%%, 1 on 0 %.0f%%), %d different threes leading a 3 on 2" % [tops, str(numbers),
		100.0 * share.call("3 on 2"), 100.0 * share.call("2 on 1"), 100.0 * share.call("1 on 0"), groups.size()])
	check(numbers.keys().all(func(k): return k in ["3 on 2", "2 on 1", "1 on 0"]), "a top-line steal is a 3 on 2, a 2 on 1 or a 1 on 0")
	check_between(share.call("3 on 2"), 0.45, 0.65, "3 on 2, the most common")
	check_between(share.call("2 on 1"), 0.25, 0.45, "2 on 1, common too")
	check_between(share.call("1 on 0"), 0.04, 0.16, "1 on 0, now and then")
	print("  off the same spot the commonest three is in %.0f%% of its 3 on 2s (the men nearest the ball go)" % (100.0 * top_group))
	# steals at random moments of live play: who leads the break changes with where it happens
	var trios := {}
	var live := 0
	for sd in 400:
		var fr := RandomNumberGenerator.new()
		fr.seed = 12000 + sd
		var lp := Play.new(_teams()[0], _teams()[1], Play.Kind.HALF_COURT, fr)
		var stop := fr.randf_range(0.5, 12.0)
		var lt := 0.0
		var think := 0.0
		while lt < stop and not lp.over:
			think -= 1.0 / 30.0
			if think <= 0.0:
				think = PlayBot.THINK_EVERY
				var dd := PlayBot.think(lp, fr)
				if not dd.is_empty() and lp.aim_info(dd.target).mode == "pass":
					lp.throw(dd.target, dd.power)
			lp.step(1.0 / 30.0)
			lt += 1.0 / 30.0
		if lp.over or lp.holder == null or lp.ball.state != Ball.State.HELD:
			continue
		lp._turnover(lp._marker(lp.holder), "STOLEN!", "steal")
		var c := Play.new(lp.them, lp.us, Play.Kind.COUNTER, fr, lp.snapshot())
		if c.kind != Play.Kind.COUNTER or c.break_n.x != 3:
			continue
		live += 1
		var men: Array = []
		for a in c.attackers:
			if a.pos.x >= c.holder.pos.x - Play.BREAK_TRAIL:
				men.append(a.player.get_instance_id())
		men.sort()
		trios[str(men)] = int(trios.get(str(men), 0)) + 1
	var commonest := 0
	for k in trios:
		commonest = maxi(commonest, int(trios[k]))
	print("  live top-line 3 on 2s: %d, led by %d different threes (the commonest %d times)" % [live, trios.size(), commonest])
	check(live > 20 and trios.size() >= live * 0.4 and commonest <= live * 0.15, "not the same three leading every counter")
	# bottom line (the wings, the centre): never a break, straight into the set attack
	var bottoms := 0
	var breaks := 0
	for tag in ["1", "5", "C"]:
		for sd in 100:
			var lost := _steal_from(tag, 9900 + sd)
			var rng := RandomNumberGenerator.new()
			rng.seed = 9950 + sd
			var c := Play.new(lost.them, lost.us, Play.Kind.COUNTER, rng, lost.snapshot())
			bottoms += 1
			if c.kind == Play.Kind.COUNTER or c.carry or c.steal_line != "bottom":
				breaks += 1
	print("  bottom-line steals: %d, %d of them a break" % [bottoms, breaks])
	check(breaks == 0, "a bottom-line steal is never a break: the team that won it sets up")
	# ...and the set-up is a short swim forwards into the umbrella, nobody swimming back
	var lost1 := _steal_from("1", 77)
	var f := MatchFlow.new(lost1.them, lost1.us, 4242, MatchState.QUARTER_MIN)
	f._start_attack(Play.Kind.COUNTER, lost1.snapshot())
	var q := f.play
	var back := 0.0
	var t := 0.0
	while t < 1.5 and not q.over:
		q.step(1.0 / 30.0)
		t += 1.0 / 30.0
		for a in q.attackers:
			back = maxf(back, -a.vel.x)
	check(q.kind == Play.Kind.HALF_COURT and back < 0.3, "after a bottom-line steal they swim straight into the set attack (worst back %.2f m/s)" % back)

## Your keeper: he shades towards the ball by himself (a little, smoothly, never past
## MatchFlow.TRACK_MAX), stops when they shoot, and every save is a dive you tap: LEFT, CENTRE or
## RIGHT, a lunge you can follow (full stretch in 0.12 s), locked once it starts, one per shot, saving only
## what the body and arm you see can reach; then he holds it, gets back and tracks again.
## Your keeper dives `side` in good time for duel `d`'s shot: the ball arriving `into` of the way
## through his window (after their wind-up, if there is one).
static func timed_dive(d: KeeperDuel, side: int, into: float = 0.3) -> void:
	while d.state == KeeperDuel.State.WINDUP:
		d.step(0.005)
	while d.t < d.flight - d.ideal_up(into) * d.slowmo and not d.done():
		d.step(0.0025)
	d.dive(side)

func test_keeper_dive() -> void:
	print("your keeper: tracking and the dive")
	var teams := _teams()
	# 1) tracking: within range, smooth, frozen on the shot, and never a dive or a save by itself
	var in_range := true
	var smooth := true
	var tracked := 0.0
	var frozen := true
	var auto_saves := 0
	var wide_auto_saves := 0
	var auto_dive := false
	var duels := 0
	for i in 12:
		var f := MatchFlow.new(teams[0], teams[1], 300 + i, MatchState.QUARTER_MIN)
		f._start_defense(Play.Kind.PENALTY if i % 4 == 3 else Play.Kind.HALF_COURT)
		var k := f.play.keeper
		check(k.pos == Vector2(Geo.KEEPER_X, Geo.GOAL_Y), "a new defence starts your keeper in the middle")
		var t := 0.0
		var last := k.pos.y
		while not f.play.over and t < 60.0:
			var shot_up := f.play.ball.state == Ball.State.SHOT
			var y0 := k.pos.y
			var dl := f.duel
			f.tick_defense(1.0 / 30.0)
			if dl != null and dl.done() and dl.saved() and not dl.tapped:
				auto_saves += 1
				if absf(dl.cross_y - dl.keeper_start) > KeeperDuel.BODY_R + 1e-4:
					wide_auto_saves += 1
			if f.duel != null:
				duels += 1
			if shot_up and f.keeper_anim == null and k.pose == null and k.pos.y != y0:
				frozen = false
			if absf(k.pos.y - Geo.GOAL_Y) > MatchFlow.TRACK_MAX + 1e-4:
				in_range = false
			if absf(k.pos.y - last) > MatchFlow.TRACK_SPEED / 30.0 + 1e-4:
				smooth = false
			tracked = maxf(tracked, absf(k.pos.y - Geo.GOAL_Y))
			if k.pose != null and k.pose.side != KeeperDive.CENTRE:
				auto_dive = true
			last = k.pos.y
			t += 1.0 / 30.0
	print("  tracking: up to %.2f m off the middle (max %.2f)" % [tracked, MatchFlow.TRACK_MAX])
	check(in_range, "tracking never takes him more than TRACK_MAX off the middle")
	check(tracked > 0.15, "...but he does shade towards the ball (%.2f m)" % tracked)
	check(smooth, "tracking is a gradual shuffle, never a jump")
	check(frozen, "a shot in the air: the tracking stops")
	check(not auto_dive, "no tap: he never dives by himself")
	check(duels > 0 and wide_auto_saves == 0, "no tap: only shots straight at him are stopped (%d duel frames, %d body blocks)" % [duels, auto_saves])
	check(absf(MatchFlow.track_target(Vector2(25.0, 2.0)) - Geo.GOAL_Y) <= MatchFlow.TRACK_MAX
		and MatchFlow.track_target(Vector2(25.0, 2.0)) < Geo.GOAL_Y and MatchFlow.track_target(Vector2(25.0, 18.0)) > Geo.GOAL_Y,
		"he shades to the ball's side")
	# 2) the zones: the middle third of the mouth is a block, either side a dive (off the ends too)
	check(KeeperDive.zone_for(Geo.GOAL_Y) == KeeperDive.CENTRE and KeeperDive.zone_for(Geo.GOAL_Y + 0.45) == KeeperDive.CENTRE,
		"the middle third of the goal is CENTRE")
	check(KeeperDive.zone_for(Geo.GOAL_Y - 1.0) == KeeperDive.LEFT and KeeperDive.zone_for(Geo.GOAL_Y - 4.0) == KeeperDive.LEFT,
		"the top of the goal, and above it, is LEFT")
	check(KeeperDive.zone_for(Geo.GOAL_Y + 1.0) == KeeperDive.RIGHT and KeeperDive.zone_for(Geo.GOAL_Y + 4.0) == KeeperDive.RIGHT,
		"the bottom, and below it, is RIGHT")
	var v := PoolView.new()
	v.snap_to(Vector2(3.5, Geo.GOAL_Y))
	var mouth_top := v.to_screen(Vector2(0.0, Geo.GOAL_Y - Geo.GOAL_HALF), KeeperDive.BALL_Z).y
	var mouth_mid := v.to_screen(Vector2(0.0, Geo.GOAL_Y), KeeperDive.BALL_Z).y
	var mouth_bot := v.to_screen(Vector2(0.0, Geo.GOAL_Y + Geo.GOAL_HALF), KeeperDive.BALL_Z).y
	check(KeeperDive.zone_at_screen(v, mouth_top + 2) == KeeperDive.LEFT and KeeperDive.zone_at_screen(v, mouth_mid) == KeeperDive.CENTRE
		and KeeperDive.zone_at_screen(v, mouth_bot - 2) == KeeperDive.RIGHT, "a tap is read off the goal as it's drawn")
	# 3) the timing: a beat to react, the rise to full stretch at 0.17 s, up for his window (0.34 s
	# at an average 5), falling back by 0.67 s, recovered by 0.89 s, eased
	var dv := KeeperDive.new(KeeperDive.LEFT, Geo.GOAL_Y, 0.75, 0.5)
	var track: Array[float] = []
	for i in 91:
		dv.t = i * 0.01
		track.append(dv.ext())
	check(track[0] == 0.0 and track[4] == 0.0 and track[6] > 0.15, "a beat to react (0.05 s), then he goes: a sixth of the way out 10 ms later (%.2f)" % track[6])
	check(track[9] > 0.5 and track[9] < 0.8, "...more than half out at 0.09 s, but no jump (%.2f)" % track[9])
	check(is_equal_approx(track[17], 1.0) and track[16] < 1.0, "full stretch at 0.17 s, not before")
	check(track[20] == 1.0 and track[50] == 1.0, "held at full stretch for his window, to 0.51 s")
	check(track[60] < 1.0 and track[60] > 0.0 and track[67] == 0.0, "falling from 0.51 s, back in the water by 0.67 s")
	dv.t = 0.8
	check(dv.phase() == KeeperDive.Phase.RECOVER and not dv.done() and dv.reach() == 0.0, "then recovering: no reach, and no new dive yet")
	dv.t = 0.9
	check(dv.done(), "...ready again by 0.89 s")
	var biggest_first: bool = track[6] - track[5] > track[10] - track[9]
	var no_jump := true
	for i in range(51, 91):
		no_jump = no_jump and absf(track[i] - track[i - 1]) < 0.2
	check(biggest_first, "explosive: the biggest step is the first one (ease-out)")
	check(no_jump, "the fall is smooth: no snapping back")
	dv.t = dv.extend_time()
	check(dv.body_y() < Geo.GOAL_Y - 0.7 and dv.tip_y() < Geo.GOAL_Y - 1.2, "a LEFT dive goes up the screen, body and hand")
	var dr := KeeperDive.new(KeeperDive.RIGHT, Geo.GOAL_Y, 0.75, 0.5)
	dr.t = dr.extend_time()
	check(is_equal_approx(dr.body_y() - Geo.GOAL_Y, Geo.GOAL_Y - dv.body_y()), "a RIGHT dive is the same dive, mirrored")
	var dc := KeeperDive.new(KeeperDive.CENTRE, Geo.GOAL_Y, 0.75, 0.5)
	dc.t = dc.extend_time()
	check(dc.body_y() == Geo.GOAL_Y and dc.covers(Geo.GOAL_Y + 0.35) >= 0.0 and dc.covers(Geo.GOAL_Y - 0.35) >= 0.0
		and dc.covers(Geo.GOAL_Y + 1.1) < 0.0, "a CENTRE block stays put and covers the middle, not the corners")
	# 4) the save is the dive you see: right way saves the corner, wrong way never does
	var corner := Geo.GOAL_Y - 1.2
	check(dv.covers(corner) >= 0.0, "full stretch the right way: the corner is saved")
	check(dr.covers(corner) < 0.0 and dc.covers(corner) < 0.0, "the wrong way, or a block: the corner is in")
	var both := true
	for y10 in range(-20, 21):
		var y := Geo.GOAL_Y + y10 * 0.1
		if dr.covers(y) >= 0.0 and y < dr.body_y() - KeeperDive.TRAIL_R - 1e-4:
			both = false
		if dv.covers(y) >= 0.0 and (y < dv.tip_y() - 1e-4 or y > dv.body_y() + KeeperDive.TRAIL_R + 1e-4):
			both = false
	check(both, "nothing is saved past his fingertips or behind his dive")
	# a late dive: still a save if he's nearly up and the ball is close to him; still reacting, no
	var gk := PoloPlayer.new()
	gk.pos = PoloPlayer.Pos.GK
	gk.keeping = 70
	var late := KeeperDuel.new().setup_given(gk, Vector2(25.0, 10.0), Geo.GOAL_Y + 0.9, 0.4, Geo.GOAL_X, Geo.GOAL_Y, 0.0)
	while late.t < 0.4 - 0.15 * late.slowmo:
		late.step(0.005)
	late.dive(KeeperDive.RIGHT)
	while not late.done():
		late.step(0.005)
	check(late.saved() or late.through, "a late dive (0.15 s on screen before it arrives, still rising) still gets to one close in")
	var reacting := KeeperDuel.new().setup_given(gk, Vector2(25.0, 10.0), Geo.GOAL_Y + 0.9, 0.4, Geo.GOAL_X, Geo.GOAL_Y, 0.0)
	while reacting.t < 0.4 - 0.03 * reacting.slowmo:
		reacting.step(0.005)
	reacting.dive(KeeperDive.RIGHT)
	while not reacting.done():
		reacting.step(0.005)
	check(not reacting.saved() and reacting.timing() == "late", "...30 ms before it, he's still reacting: in, and it's TOO LATE")
	var too_late := KeeperDuel.new().setup_given(gk, Vector2(25.0, 10.0), Geo.GOAL_Y + 1.4, 0.4, Geo.GOAL_X, Geo.GOAL_Y, 0.0)
	while too_late.t < 0.4 - 0.01 * too_late.slowmo:
		too_late.step(0.0025)
	too_late.dive(KeeperDive.RIGHT)
	while not too_late.done():
		too_late.step(0.0025)
	check(not too_late.saved(), "...but one tapped as it arrives can't reach the corner")
	# 4b) only where it crosses the line counts, never how high: no tap, a shot straight at him is
	# blocked (the block pose plays); wide of his body it's in; a dive the right way saves the
	# corners at either end, a dive that can't get there doesn't
	for off in [0.0, 0.2, -0.25]:
		var at_him := KeeperDuel.new().setup_given(gk, Vector2(25.0, 10.0), Geo.GOAL_Y + 0.3 + off, 0.4, Geo.GOAL_X, Geo.GOAL_Y + 0.3, 0.0)
		while not at_him.done():
			at_him.step(0.01)
		check(at_him.saved() and at_him.anim != null and at_him.anim.side == KeeperDive.CENTRE,
			"no tap, %.2f m off his body: blocked, with the block pose" % off)
	for off in [0.5, -0.7]:
		var past := KeeperDuel.new().setup_given(gk, Vector2(25.0, 10.0), Geo.GOAL_Y + off, 0.4, Geo.GOAL_X, Geo.GOAL_Y, 0.0)
		while not past.done():
			past.step(0.01)
		check(past.outcome == "goal", "no tap, %.1f m wide of him: in" % off)
	for side in [KeeperDive.LEFT, KeeperDive.RIGHT]:
		var c := KeeperDuel.new().setup_given(gk, Vector2(25.0, 10.0), Geo.GOAL_Y + side * 1.2, 0.4, Geo.GOAL_X, Geo.GOAL_Y, 0.0)
		timed_dive(c, side)
		while not c.done():
			c.step(0.01)
		# (2.0: in his hands; BLOCKING then decides whether it stays out, so it can still squirm through)
		check(c.saved() or c.through, "a dive the right way in time gets to the %s corner" % ("top" if side < 0 else "bottom"))
	var shaded := KeeperDuel.new().setup_given(gk, Vector2(25.0, 10.0), Geo.GOAL_Y + 1.4, 0.4, Geo.GOAL_X, Geo.GOAL_Y - MatchFlow.TRACK_MAX, 0.0)
	timed_dive(shaded, KeeperDive.RIGHT)
	while not shaded.done():
		shaded.step(0.01)
	check(not shaded.saved(), "shaded to the far post, the near corner is out of his reach: in")
	# 5) a dive runs its course: the direction locked, no second dive while it's running
	var one := KeeperDuel.new().setup_given(gk, Vector2(25.0, 10.0), Geo.GOAL_Y - 1.1, 0.5, Geo.GOAL_X, Geo.GOAL_Y, 0.0)
	one.step(0.05)
	one.dive(KeeperDive.RIGHT)
	var first := one.anim
	one.dive(KeeperDive.LEFT)
	one.tap(Geo.GOAL_Y - 1.0)
	while not one.done():
		one.step(0.01)
	check(one.anim == first and one.anim.side == KeeperDive.RIGHT and not one.saved(), "repeated taps do nothing: one dive, locked, the wrong way and it's in")
	var f2 := MatchFlow.new(teams[0], teams[1], 9, MatchState.QUARTER_MIN)
	f2._start_defense(Play.Kind.HALF_COURT)
	var last := KeeperDive.new(KeeperDive.LEFT, Geo.GOAL_Y, 0.75, 0.5)
	last.t = 0.3
	f2.keeper_anim = last
	f2._open_duel({"from": Vector2(25.0, 10.0), "cross_y": Geo.GOAL_Y + 1.0, "flight": 0.4, "keeper_y": Geo.GOAL_Y, "n": 1})
	f2.dive_side(KeeperDive.RIGHT)
	check(f2.duel.anim == last and f2.duel.anim.side == KeeperDive.LEFT, "no new dive while he's still in the last")
	# 6) after a dive in a live defence: up, falling, recovered (no teleport), then tracking again
	var f3 := MatchFlow.new(teams[0], teams[1], 11, MatchState.QUARTER_MIN)
	f3._start_defense(Play.Kind.HALF_COURT)
	var k3 := f3.play.keeper
	f3.keeper_anim = KeeperDive.new(KeeperDive.RIGHT, k3.pos.y, 0.75, 0.5)
	var max_step := 0.0
	var prev := k3.pos.y
	var back_t := -1.0
	for i in 60:
		f3._steer_keeper(1.0 / 60.0)
		max_step = maxf(max_step, absf(k3.pos.y - prev))
		prev = k3.pos.y
		if back_t < 0.0 and f3.keeper_anim == null:
			back_t = (i + 1) / 60.0
	check(back_t > 0.87 and back_t < 0.93 and absf(k3.pos.y - Geo.GOAL_Y) <= MatchFlow.TRACK_MAX, "fallen and recovered after 0.89 s, back in his goal (%.2f s)" % back_t)
	check(max_step < 0.4, "the dive and recovery move him in steps, never a jump back to the middle (%.2f m)" % max_step)

## The home team's keeper dives ShotModel.HOME_DIVE times faster, nothing else: the same
## reaction, read, reach and ball, in your goal (the duel) and theirs (ShotModel and Play).
func test_home_dive() -> void:
	print("home keeper dive")
	var shooter := PoloPlayer.new()
	shooter.shoot = 62
	var gk := PoloPlayer.new()
	gk.pos = PoloPlayer.Pos.GK
	gk.keeping = 62
	check(is_equal_approx(ShotModel.HOME_DIVE, 1.3), "the home dive is 30% faster")
	# 1) your goal: the same duel, home and away, dived to each corner from close and long range
	var froms := [Vector2(3.0, 10.5), Vector2(8.0, 8.0)]
	var synced := true
	for from: Vector2 in froms:
		for side in [KeeperDive.LEFT, KeeperDive.RIGHT]:
			var duels: Array = []
			for home in [false, true]:
				var rng := RandomNumberGenerator.new()
				rng.seed = 21
				var d := KeeperDuel.new().setup(shooter, gk, from, 0.0, rng, 0.0)
				d.home = home
				duels.append(d)
			var away: KeeperDuel = duels[0]
			var hd: KeeperDuel = duels[1]
			check(hd.reach == away.reach and hd.lunge == away.lunge and hd.windup == away.windup,
				"home duel keeper: same reach, lunge and wind-up")
			check(hd.cross_y == away.cross_y and hd.flight == away.flight, "home duel: the same shot")
			for d: KeeperDuel in duels:
				while d.state == KeeperDuel.State.WINDUP:
					d.step(0.01)
				d.dive(side)
			check(is_equal_approx(away.anim.extend_time(), hd.anim.extend_time() * 1.3), "home keeper is at full stretch 1.3x sooner")
			# what's drawn is where he saves from
			for d: KeeperDuel in duels:
				while not d.done():
					d.step(0.01)
				if d.on_target and (d.anim.covers(d.cross_y) >= 0.0) != d.saved():
					synced = false
	check(synced, "the duel's save is decided by the body and arm that are drawn")
	# better on average, but not automatic
	var rates := [0.0, 0.0]
	for j in 2:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var brng := RandomNumberGenerator.new()
		brng.seed = 6
		var goals := 0
		for i in 2000:
			var from: Vector2 = OppSim.SPOTS[i % OppSim.SPOTS.size()][1] + Vector2(0, rng.randf_range(-2.0, 2.0))
			var d := KeeperDuel.new().setup(shooter, gk, from, 0.0, rng, 0.0)
			d.home = j == 1
			if d.auto(0.4, brng) == "goal":
				goals += 1
		rates[j] = goals / 2000.0
	print("  duel goals per shot: away keeper %.2f, home keeper %.2f" % [rates[0], rates[1]])
	check(rates[1] <= rates[0], "the home keeper saves at least as many")
	check(rates[1] > 0.2, "...and still concedes plenty")
	# 2) their goal: ShotModel, home and away, the same seed: the same pick, a quicker dive
	var same := true
	var faster := true
	var saves_home := 0
	var saves_away := 0
	for from in [Vector2(27.0, 10.5), Vector2(21.0, 7.0), Vector2(24.0, 13.0)]:
		for aim in [Geo.GOAL_Y - 1.2, Geo.GOAL_Y + 1.2]:
			for sd in 30:
				var res: Array = []
				for home in [false, true]:
					var rng := RandomNumberGenerator.new()
					rng.seed = 700 + sd
					res.append(ShotModel.resolve(from, aim, 0.8, 65.0, 5.0, [], 10.0, 62.0, rng, false, {},
						{"home_keeper": home, "catch_t": 0.2 if sd % 3 == 0 else INF}))
				var a: Dictionary = res[0]
				var h: Dictionary = res[1]
				same = same and a.cross_y == h.cross_y and a.reaction == h.reaction and a.speed == h.speed \
					and a.catch_shoot == h.catch_shoot and int(a.read_side) == int(h.read_side)   # (his read; a quicker dive may choose differently)
				faster = faster and is_equal_approx(float(h.dive.quick), float(a.dive.quick) * 1.3)
				saves_away += int(String(a.outcome) in ["save", "parry"])
				saves_home += int(String(h.outcome) in ["save", "parry"])
	check(same, "home keeper (their goal): same shot, reaction, catch-and-shoot delay and pick")
	check(faster, "home keeper (their goal): his push off and rise are 1.3x as quick")
	check(saves_home >= saves_away, "home keeper (their goal): saves at least as many (%d vs %d)" % [saves_home, saves_away])
	# 3) in a live play the drawn keeper is the dive the save was decided with, smoothly
	var drawn := true
	var glide := true
	for sd in 40:
		var p := _staged(Vector2(22.0 + (sd % 3) * 2.0, 10.0), Vector2(5.0, 5.0), 800 + sd)
		p.home_keeper = sd % 2 == 0
		p._shoot(Geo.GOAL_Y + (1.1 if sd % 4 < 2 else -1.1), 0.8)
		var sh: Dictionary = p.ball.shot
		var guard := 0
		while p.ball.state == Ball.State.SHOT and guard < 300:
			var y0 := p.keeper.pos.y
			p.step(1.0 / 60.0)
			if p.ball.state == Ball.State.SHOT:
				glide = glide and absf(p.keeper.pos.y - y0) <= 0.3   # (the lunge itself: an ease-out, fastest off the mark)
				if p.keeper.pose != null:
					drawn = drawn and p.keeper.pose.side == int(sh.guess)
			guard += 1
		if String(sh.outcome) in ["save", "parry"]:
			drawn = drawn and absf(p.keeper.pos.y - float(sh.keeper_end_y)) < 0.25   # (within a frame of his dive)
	check(glide, "the play's keeper moves with his dive, no snapping")
	check(drawn, "the play's keeper is drawn diving the way he went, and ends where the save was decided")
	# 4) the right keeper gets it: yours when you're at home, theirs when you're away
	var teams := _teams()
	for home in [true, false]:
		var f := MatchFlow.new(teams[0], teams[1], 31, 8.0)
		f.home = home
		f._start_attack(Play.Kind.HALF_COURT)
		check(f.play.home_keeper == not home, "attacking (home %s): their keeper is the home one only when you're away" % home)
		f._start_defense(Play.Kind.HALF_COURT)
		check(f.play.home_keeper == home, "defending (home %s): your keeper is the home one only at home" % home)

# ------------------------------------------------------------------ cards, press
## Every card choice and press answer runs through the effects engine, many times, and
## leaves the career in bounds.
func test_moments() -> void:
	print("moments")
	var c := Career.new_game("LIUB", "A", "B", 21)
	Game.career = c
	var all: Array = []
	for cd in CardsData.CARDS:
		for ch in cd.choices:
			all.append(ch.effects)
		check(Moments.fill(String(cd.text), c.team().roster[0]).replace(CreditCoin.TAG, "").find("{") < 0, "card %s fills its names" % cd.id)
	for i in 400:
		var p: PoloPlayer = c.team().roster[i % c.team().roster.size()]
		c.apply_effects(all[i % all.size()], p)
		check(LockerData.chips(all[i % all.size()]).size() >= 0, "chips")
	check(not "momentum" in c and not "fans" in c and not "morale" in c.team().roster[0], "no fans, morale or momentum (removed)")
	check(c.team().roster.all(func(p): return p.shoot <= Training.RATING_CAP), "ratings stay capped")
	# contexts
	check(Moments.context(true, 6, false, "conf") == "big_win", "a 6-goal win is a big win")
	check(Moments.context(false, -1, false, "conf") == "close_loss", "losing by one is close")
	check(Moments.context(false, -4, false, "nat_qf") == "out", "a playoff loss ends the season")
	check(Moments.context(true, 1, true, "conf_final") == "title", "winning the final is a title")
	# a season of cards and press reaches the queue
	var cards := 0
	# (over three careers, so one unlucky run of dice - a card is a 35% chance a week - can't fail it)
	for sd in [31, 32, 33]:
		var c2 := Career.new_game("WAGN", "A", "B", sd)
		Game.career = c2
		while c2.week < 10:
			while c2.has_game():
				c2.sim_my_game()
			c2.end_week()
			for q in c2.queue:
				if q.type == "card":
					cards += 1
			c2.queue.clear()
	print("  in 3 x 10 weeks: %d cards" % cards)
	check(cards >= 1 and not "pick_press" in Moments.new(), "cards turn up (the press conference is gone)")
	Game.career = null
