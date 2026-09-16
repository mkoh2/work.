extends Node
## Trust is the single resource (GAME_DESIGN.md §5). Easy to lose, hard to
## regain: any drop below the run's prior peak permanently tightens the
## ceiling on how high Trust can ever climb again this run.
##
## UI must only ever read get_normalized() for the bar fill -- there is no
## numeric Trust display anywhere in the game (§5, confirmed bar-only).

signal trust_changed(new_trust: float, ceiling: float)
signal fired # Trust hit 0

const TRUST_MIN := 0.0
const TRUST_MAX := 100.0
const PEAK_CAP_RATIO := 0.75 # ceiling after any drop = 75% of the peak it dropped from


func get_trust() -> float:
	return SaveState.data.get("trust", 50.0)


func get_ceiling() -> float:
	return SaveState.data.get("trust_ceiling", 100.0)


## Bar fill only, 0..1. Never expose the raw number to UI -- see §5.
func get_normalized() -> float:
	return get_trust() / TRUST_MAX


func apply_delta(delta: float) -> void:
	if SaveState.is_terminated():
		return

	var trust: float = get_trust()
	var ceiling: float = get_ceiling()
	var peak: float = SaveState.data.get("trust_peak", trust)

	trust = clampf(trust + delta, TRUST_MIN, ceiling)

	if trust > peak:
		peak = trust
		SaveState.data["trust_peak"] = peak
	elif delta < 0.0 and trust < peak:
		var new_ceiling: float = peak * PEAK_CAP_RATIO
		if new_ceiling < ceiling:
			ceiling = new_ceiling
			SaveState.data["trust_ceiling"] = ceiling
			trust = minf(trust, ceiling)

	SaveState.data["trust"] = trust
	SaveState.save()
	trust_changed.emit(trust, ceiling)

	if trust <= TRUST_MIN:
		SaveState.data["run_state"] = "fired"
		SaveState.save()
		fired.emit()
