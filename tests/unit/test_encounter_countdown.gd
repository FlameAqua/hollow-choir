extends TestCase
## Playtest revision, the move-away countdown (pure state): entering an armed threat's radius starts
## it, leaving cancels it and disarms the threat until the player is well clear, frozen frames hold
## the remaining time, one stable threat owns it, and it expires exactly once.

const S := EncounterCountdown.State


static func _site(id: StringName, distance: float, radius: float = 72.0) -> Dictionary:
	return {"id": id, "distance": distance, "radius": radius}


static func _sites(entries: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(entries)
	return result


func _armed(sites: Array[Dictionary]) -> EncounterCountdown:
	var countdown := EncounterCountdown.new()
	countdown.arm(sites)
	return countdown


func test_entering_starts_and_three_seconds_later_it_expires_once() -> void:
	var away := _sites([_site(&"patrol", 200.0)])
	var near := _sites([_site(&"patrol", 60.0)])
	var countdown := _armed(away)
	assert_eq([countdown.state, countdown.active(), countdown.duration], [S.IDLE, false, 3.0])
	assert_eq(countdown.update(0.5, away, false), &"", "nothing in reach")
	assert_eq(countdown.state, S.IDLE)
	assert_eq(countdown.update(0.5, near, false), &"")
	assert_eq([countdown.state, countdown.site_id, countdown.remaining], [S.COUNTING, &"patrol", 3.0],
		"the frame that enters starts the full countdown")
	var expired: Array[StringName] = []
	var frames := 0
	for frame in 400:
		var result := countdown.update(1.0 / 60.0, near, false)
		frames += 1
		if result != &"":
			expired.append(result)
			break
		assert_eq(countdown.state, S.COUNTING)
	assert_eq(expired, [&"patrol"] as Array[StringName])
	assert_almost_eq(frames / 60.0, 3.0, 0.05, "three seconds of exploration time")
	assert_eq([countdown.state, countdown.active(), countdown.site_id], [S.EXPIRED, false, &""])
	# It never fires again while the player stays there: the site is disarmed.
	for frame in 400:
		assert_eq(countdown.update(1.0 / 60.0, near, false), &"")
	assert_eq(countdown.state, S.IDLE)
	assert_false(countdown.is_armed(&"patrol"))


func test_leaving_cancels_and_hysteresis_prevents_an_immediate_restart() -> void:
	var countdown := _armed(_sites([_site(&"patrol", 200.0)]))
	countdown.update(0.1, _sites([_site(&"patrol", 70.0)]), false)
	countdown.update(1.0, _sites([_site(&"patrol", 50.0)]), false)
	assert_almost_eq(countdown.remaining, 2.0)
	# Stepping out of the radius cancels at once.
	assert_eq(countdown.update(0.1, _sites([_site(&"patrol", 73.0)]), false), &"")
	assert_eq([countdown.state, countdown.active(), countdown.remaining], [S.CANCELLED, false, 0.0])
	assert_false(countdown.is_armed(&"patrol"))
	# Brushing the edge again does not restart it: the player must first be 24 px clear.
	for distance: float in [71.0, 60.0, 80.0, 95.9, 70.0]:
		assert_eq(countdown.update(0.1, _sites([_site(&"patrol", distance)]), false), &"")
		assert_false(countdown.active(), "still disarmed at %.1f" % distance)
	assert_eq(countdown.state, S.IDLE)
	countdown.update(0.1, _sites([_site(&"patrol", 96.5)]), false)
	assert_true(countdown.is_armed(&"patrol"), "re-armed beyond the radius plus %d px" % int(EncounterCountdown.REARM))
	countdown.update(0.1, _sites([_site(&"patrol", 71.0)]), false)
	assert_eq([countdown.state, countdown.remaining], [S.COUNTING, 3.0], "a fresh, full countdown")
	# Standing inside the radius when it is armed (an area load, a return from its battle) counts
	# nothing until the player has walked clear. Interact engages at once instead (WorldHost).
	var underfoot := _armed(_sites([_site(&"patrol", 50.0)]))
	assert_false(underfoot.is_armed(&"patrol"), "standing inside the radius at arming time")
	for frame in 30:
		assert_eq(underfoot.update(0.1, _sites([_site(&"patrol", 50.0)]), false), &"")
	assert_false(underfoot.active())


func test_frozen_frames_hold_the_remaining_time() -> void:
	var near := _sites([_site(&"guard", 40.0)])
	var countdown := _armed(_sites([_site(&"guard", 300.0)]))
	countdown.update(0.1, near, false)
	countdown.update(1.25, near, false)
	assert_almost_eq(countdown.remaining, 1.75)
	# A pause, a modal or a lost focus: any number of frozen frames changes nothing.
	for frame in 500:
		assert_eq(countdown.update(1.0 / 60.0, near, true), &"")
	assert_eq([countdown.state, countdown.active(), countdown.site_id], [S.FROZEN, true, &"guard"])
	assert_almost_eq(countdown.remaining, 1.75, 0.0001, "held, never reset and never advanced")
	# Opening and closing a menu repeatedly cannot keep resetting it either.
	for cycle in 5:
		countdown.update(0.05, near, false)
		countdown.update(0.5, near, true)
	assert_almost_eq(countdown.remaining, 1.5, 0.0001)
	assert_eq(countdown.update(0.05, near, false), &"")
	assert_eq(countdown.state, S.COUNTING)
	# Nothing starts while frozen.
	var idle := _armed(_sites([_site(&"guard", 300.0)]))
	assert_eq(idle.update(1.0, near, true), &"")
	assert_false(idle.active(), "a frozen frame never starts a countdown")
	assert_eq(idle.update(0.1, near, false), &"")
	assert_true(idle.active())


func test_one_stable_threat_owns_the_countdown() -> void:
	var far := _sites([_site(&"alpha", 300.0), _site(&"beta", 300.0)])
	# Overlapping threats: the nearest starts; ties go to the lower id.
	var countdown := _armed(far)
	countdown.update(0.1, _sites([_site(&"beta", 30.0), _site(&"alpha", 50.0)]), false)
	assert_eq(countdown.site_id, &"beta", "the nearest armed threat")
	var tied := _armed(far)
	tied.update(0.1, _sites([_site(&"beta", 40.0), _site(&"alpha", 40.0)]), false)
	assert_eq(tied.site_id, &"alpha", "a tie is decided by id")
	# The owner keeps the countdown even when another threat becomes nearer.
	countdown.update(1.0, _sites([_site(&"beta", 60.0), _site(&"alpha", 10.0)]), false)
	assert_eq([countdown.site_id, countdown.remaining], [&"beta", 2.0])
	# When the owner is left, the other threat in reach starts its own full countdown next frame.
	countdown.update(0.1, _sites([_site(&"beta", 80.0), _site(&"alpha", 10.0)]), false)
	assert_eq(countdown.state, S.CANCELLED)
	countdown.update(0.1, _sites([_site(&"beta", 80.0), _site(&"alpha", 10.0)]), false)
	assert_eq([countdown.site_id, countdown.remaining], [&"alpha", 3.0])
	# Only the owner can expire: one site id, once.
	var expired: Array[StringName] = []
	for frame in 300:
		var result := countdown.update(1.0 / 60.0, _sites([_site(&"beta", 60.0), _site(&"alpha", 10.0)]), false)
		if result != &"":
			expired.append(result)
	assert_eq(expired, [&"alpha"] as Array[StringName], "beta was disarmed by leaving and never re-armed")


func test_cleared_sites_transitions_and_arming_are_deterministic() -> void:
	var near := _sites([_site(&"guard", 40.0)])
	var countdown := _armed(_sites([_site(&"guard", 300.0)]))
	countdown.update(0.1, near, false)
	countdown.update(1.0, near, false)
	# A site that is cleared (no longer listed) cannot keep or expire a countdown.
	assert_eq(countdown.update(5.0, _sites([]), false), &"")
	assert_eq([countdown.state, countdown.active()], [S.CANCELLED, false])
	# A portal or transition cancels explicitly; cancelling twice is harmless.
	var moving := _armed(_sites([_site(&"guard", 300.0)]))
	moving.update(0.1, near, false)
	assert_true(moving.cancel())
	assert_false(moving.cancel())
	assert_eq([moving.state, moving.site_id, moving.remaining], [S.CANCELLED, &"", 0.0])
	# Arming (an area load) drops everything and arms from where the player stands.
	var loaded := _armed(_sites([_site(&"guard", 300.0)]))
	loaded.update(0.1, near, false)
	loaded.arm(_sites([_site(&"guard", 40.0), _site(&"patrol", 400.0)]))
	assert_eq([loaded.state, loaded.active(), loaded.is_armed(&"guard"), loaded.is_armed(&"patrol")], [S.IDLE, false, false, true])
	# An unknown site (never armed) is inert until the player has been clear of it.
	var unknown := EncounterCountdown.new()
	assert_eq(unknown.update(0.1, near, false), &"")
	assert_false(unknown.active())
	# A negative or zero frame time never advances or expires anything.
	var stalled := _armed(_sites([_site(&"guard", 300.0)]))
	stalled.update(0.0, near, false)
	for frame in 100:
		assert_eq(stalled.update(0.0, near, false), &"")
		assert_eq(stalled.update(-1.0, near, false), &"")
	assert_almost_eq(stalled.remaining, 3.0)
	# The readout's fraction is derived from the same numbers.
	var readout := EncounterCountdownReadout.new()
	readout.remaining = 0.75
	readout.duration = 3.0
	assert_almost_eq(readout.fraction(), 0.25)
	readout.duration = 0.0
	assert_almost_eq(readout.fraction(), 0.0)
