## Plays sounds for sim events. The sounds are generated in code (no audio
## files needed yet); swap them for recorded sounds later by assigning
## AudioStreams to the `streams` dictionary.
##
## 💡 Generating simple sounds: a sound is a list of numbers (samples), 22050
## per second. "Noise" (random samples) sounds like an impact; a sine wave
## sounds like a tone. Fading the volume out ("decay") makes it short and punchy.
class_name FightSounds
extends Node

const Event := FightState.Event
const RATE := 22050
const VOICES := 8  # how many sounds can overlap

var streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7  # same "random" noise every run
	streams[Event.HIT] = _impact(0.18, 90.0, 0.9)
	streams[Event.BLOCK] = _impact(0.08, 400.0, 0.5)
	streams[Event.PARRY] = _tone([1320.0, 1980.0], 0.45, 0.5)
	streams[Event.THROW] = _impact(0.12, 70.0, 0.6)
	streams[Event.THROW_BREAK] = _tone([880.0, 1100.0], 0.25, 0.4)
	streams[Event.KO] = _impact(0.9, 45.0, 1.0)
	streams[Event.ROUND_START] = _tone([220.0, 330.0, 440.0], 1.2, 0.45)
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


func play(event: Dictionary) -> void:
	var stream: AudioStream = streams.get(event.type)
	if stream == null:
		return
	var player := _players[_next]
	_next = (_next + 1) % VOICES
	player.stream = stream
	# Heavier hits sound lower; slight random pitch keeps repeats from sounding robotic.
	var weight := clampf(event.amount / 100.0, 0.3, 2.5)
	player.pitch_scale = clampf(1.25 - weight * 0.2, 0.7, 1.3) * _rng.randf_range(0.95, 1.05)
	player.volume_db = -6.0
	player.play()


## Noise burst + low "thump" sine, fading out quickly.
func _impact(seconds: float, thump_hz: float, thump_mix: float) -> AudioStreamWAV:
	var count := int(seconds * RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t := float(i) / RATE
		var decay := exp(-t * 18.0 / seconds)
		var noise := _rng.randf_range(-1.0, 1.0) * exp(-t * 60.0)
		var thump := sin(TAU * thump_hz * t * (1.0 - t)) * thump_mix
		samples[i] = (noise * 0.7 + thump) * decay
	return _to_wav(samples)


## A chord of sine tones with a bell-like fade.
func _tone(freqs: Array, seconds: float, volume: float) -> AudioStreamWAV:
	var count := int(seconds * RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t := float(i) / RATE
		var v := 0.0
		for f in freqs:
			v += sin(TAU * f * t)
		samples[i] = v / freqs.size() * volume * exp(-t * 4.0 / seconds)
	return _to_wav(samples)


func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav
