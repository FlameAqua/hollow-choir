class_name MusicTrack
extends Resource
## One prepared full mix. Tone variants are independent unless a future aligned-layer export
## explicitly supplies a verified sync group; filenames alone never establish alignment.
@export var id: StringName
@export var version: int = 1
@export var tone: StringName = &"base"
@export var stream: AudioStream
## Source-time origin of the prepared stream, so edge trimming cannot shift tone changes.
@export var source_offset_seconds: float = 0.0
@export var gain_db: float = -12.0
@export var crossfade_seconds: float = 3.0
@export var sync_group: StringName = &""

func playable() -> bool:
	return id != &"" and stream != null and stream.get_length() > 0.0

func fade_seconds() -> float:
	return clampf(crossfade_seconds, 0.1, maxf(0.1, stream.get_length() * 0.25))
