class_name EncounterCountdown
extends RefCounted
## Playtest revision: the move-away countdown that replaces the Engage card. Pure state: the host
## feeds it the distances to the area's uncleared encounter sites each exploration frame, and it
## says which one site (if any) has counted down to zero. It writes nothing, grants nothing and
## launches nothing: the host calls its single entry boundary when update() returns a site.
##
## - A site is armed while the player is away from it; entering an armed site's radius starts the
##   countdown for that site, which then owns it (other sites cannot take it over).
## - Leaving the owner's radius cancels and disarms the site until the player is REARM pixels
##   beyond the radius (hysteresis: brushing the edge cannot restart it every frame).
## - Frozen frames (a modal, a pause, a lost focus, a busy transition) keep the remaining time.
## - Several armed sites in range: the nearest starts, ties by id.

enum State {
	## No site owns the countdown.
	IDLE = 0,
	## A site owns it and time is running.
	COUNTING = 1,
	## A site owns it; time is held until exploration resumes.
	FROZEN = 2,
	## The player left the radius (or the site was cleared, or the area changed) this update.
	CANCELLED = 3,
	## The countdown reached zero this update; the host launches the site once.
	EXPIRED = 4,
}

## Seconds from entering the radius to the encounter.
const DURATION := 3.0
## Pixels beyond a site's radius before it can trigger again.
const REARM := 24.0

var state: State = State.IDLE
## The site that owns the countdown (&"" when none).
var site_id: StringName = &""
var remaining: float = 0.0
var duration: float = DURATION
## site id -> armed.
var _armed: Dictionary = {}


## True while a site owns the countdown.
func active() -> bool:
	return state == State.COUNTING or state == State.FROZEN


func is_armed(id: StringName) -> bool:
	return _armed.get(id, false)


## Forgets everything and re-arms from where the player stands: a site whose radius already holds
## the player (after an area load, or after returning from its battle) stays disarmed until the
## player has walked away. [param sites]: [{id: StringName, distance: float, radius: float}].
func arm(sites: Array[Dictionary]) -> void:
	_armed.clear()
	state = State.IDLE
	site_id = &""
	remaining = 0.0
	for site in sites:
		_armed[site.id] = float(site.distance) > float(site.radius)


## Drops the owner (a portal, a transition, a cleared site). The site is disarmed like any other
## cancelled one. Returns true when a countdown was actually cancelled.
func cancel() -> bool:
	if not active():
		return false
	_armed[site_id] = false
	state = State.CANCELLED
	site_id = &""
	remaining = 0.0
	return true


## Advances one frame. [param sites]: every uncleared encounter site of the area with the player's
## distance to it, [{id, distance, radius}]; a site missing from the list (cleared) cannot own or
## start anything. [param frozen]: exploration is not running this frame. Returns the site whose
## countdown expired this frame (once), or &"".
func update(delta: float, sites: Array[Dictionary], frozen: bool) -> StringName:
	if state == State.CANCELLED or state == State.EXPIRED:
		state = State.IDLE
	var owner: Dictionary = {}
	for site in sites:
		if site.id == site_id:
			owner = site
	if active():
		if owner.is_empty() or float(owner.distance) > float(owner.radius):
			cancel()
			_rearm(sites)
			return &""
		if frozen:
			state = State.FROZEN
			return &""
		state = State.COUNTING
		remaining = maxf(0.0, remaining - maxf(delta, 0.0))
		if remaining > 0.0:
			return &""
		var expired := site_id
		_armed[expired] = false
		state = State.EXPIRED
		site_id = &""
		return expired
	_rearm(sites)
	if frozen:
		return &""
	var best: Dictionary = {}
	for site in sites:
		if not _armed.get(site.id, false) or float(site.distance) > float(site.radius):
			continue
		if best.is_empty() or float(site.distance) < float(best.distance) - 0.01 \
				or (absf(float(site.distance) - float(best.distance)) <= 0.01 and String(site.id) < String(best.id)):
			best = site
	if not best.is_empty():
		site_id = best.id
		remaining = duration
		state = State.COUNTING
	return &""


func _rearm(sites: Array[Dictionary]) -> void:
	for site in sites:
		if float(site.distance) > float(site.radius) + REARM:
			_armed[site.id] = true
