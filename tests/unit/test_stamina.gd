extends TestCase
## V0.5 sprint stamina (pure state): from full, sprinting lasts five seconds; not sprinting refills
## in proportion to what is missing, five seconds from empty; an emptied meter blocks sprinting until
## the input is released (no flicker while it stays held); only actual sprint travel spends it.

const FRAME := 1.0 / 60.0


## Sprints (input held, travel achieved) until the meter stops allowing it; returns the seconds.
static func _sprint_until_empty(stamina: Stamina) -> float:
	var seconds := 0.0
	for frame in 1200:
		if not stamina.can_sprint(true):
			break
		stamina.update(FRAME, true)
		seconds += FRAME
	return seconds


## Refills without sprinting until full; returns the seconds.
static func _rest_until_full(stamina: Stamina) -> float:
	var seconds := 0.0
	for frame in 1200:
		if stamina.is_full():
			break
		stamina.can_sprint(false)
		stamina.update(FRAME, false)
		seconds += FRAME
	return seconds


func test_a_full_meter_sprints_for_five_seconds() -> void:
	var stamina := Stamina.new()
	assert_eq([stamina.value, stamina.exhausted, stamina.sprinting], [1.0, false, false])
	assert_almost_eq(_sprint_until_empty(stamina), Stamina.DRAIN_SECONDS, 2.0 * FRAME)
	assert_almost_eq(stamina.value, 0.0, 0.0001)
	assert_true(stamina.exhausted)


func test_refilling_takes_time_in_proportion_to_what_was_used() -> void:
	var empty := Stamina.new()
	_sprint_until_empty(empty)
	assert_almost_eq(_rest_until_full(empty), Stamina.RECOVER_SECONDS, 2.0 * FRAME, "five seconds from empty")
	var half := Stamina.new()
	for frame in roundi(Stamina.DRAIN_SECONDS * 0.5 / FRAME):
		half.can_sprint(true)
		half.update(FRAME, true)
	assert_almost_eq(half.value, 0.5, 0.01)
	assert_almost_eq(_rest_until_full(half), Stamina.RECOVER_SECONDS * 0.5, 2.0 * FRAME, "half the meter, half the time")
	assert_false(half.exhausted, "only emptying it exhausts")


func test_an_empty_meter_waits_for_the_input_to_be_released() -> void:
	var stamina := Stamina.new()
	_sprint_until_empty(stamina)
	# Still held: no sprint at all (never a frame of sprint, frame of walk), while the meter refills.
	for frame in 90:
		assert_false(stamina.can_sprint(true), "frame %d" % frame)
		stamina.update(FRAME, false)
	assert_almost_eq(stamina.value, 90.0 * FRAME / Stamina.RECOVER_SECONDS, 0.001, "it refills meanwhile")
	assert_true(stamina.exhausted)
	# Let go for one frame, press again: sprinting resumes on what has refilled.
	assert_false(stamina.can_sprint(false))
	stamina.update(FRAME, false)
	assert_false(stamina.exhausted)
	assert_true(stamina.can_sprint(true))


func test_only_achieved_sprint_travel_spends_it() -> void:
	var stamina := Stamina.new()
	stamina.value = 0.6
	# Held but standing still, or pushing into a wall: the caller reports no travel.
	for frame in 30:
		assert_true(stamina.can_sprint(true))
		stamina.update(FRAME, false)
	assert_false(stamina.sprinting)
	assert_almost_eq(stamina.value, 0.6 + 30.0 * FRAME / Stamina.RECOVER_SECONDS, 0.0001, "not spending means refilling")
	stamina.update(FRAME, true)
	assert_true(stamina.sprinting)
	stamina.update(0.0, true)
	assert_false(stamina.sprinting, "a zero-length frame spends nothing")
	stamina.reset()
	assert_eq([stamina.value, stamina.exhausted, stamina.sprinting], [1.0, false, false])
