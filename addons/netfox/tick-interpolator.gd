extends Node
class_name TickInterpolator

@export var root: Node
@export var enabled: bool = true
@export var properties: Array[String]
@export var record_first_state: bool = true
@export var enable_recording: bool = true

var _state_from: Dictionary = {}
var _state_to: Dictionary = {}
var _property_entries: Array[PropertyEntry] = []
var _interpolators: Dictionary = {}

var _property_cache: PropertyCache

## Process settings.
##
## Call this after any change to configuration.
func process_settings():
	_property_cache = PropertyCache.new(root)
	_property_entries.clear()
	_interpolators.clear()
	
	_state_from = {}
	_state_to = {}

	for property in properties:
		var property_entry = _property_cache.get_entry(property)
		_property_entries.push_back(property_entry)
		_interpolators[property] = Interpolators.find_for(property_entry.get_value())

## Check if interpolation can be done.
##
## Even if it's enabled, no interpolation will be done if there are no
## properties to interpolate.
func can_interpolate() -> bool:
	return enabled and not properties.is_empty()

## Record current state for interpolation.
##
## Note that this will rotate the states, so the previous target becomes the new
## starting point for the interpolation. This is automatically called if 
## [code]enable_recording[/code] is true.
func push_state():
	_state_from = _state_to
	_state_to = PropertySnapshot.extract(_property_entries)

## Record current state and transition without interpolation.
func teleport():
	_state_from = PropertySnapshot.extract(_property_entries)
	_state_to = _state_from

func _ready():
	process_settings()
	NetworkTime.before_tick_loop.connect(_before_tick_loop)
	NetworkTime.after_tick_loop.connect(_after_tick_loop)

	# Wait a frame for any initial setup before recording first state
	if record_first_state:
		await get_tree().process_frame
		teleport()

func _process(_delta):
	_interpolate(_state_from, _state_to, NetworkTime.tick_factor)

func _before_tick_loop():
	PropertySnapshot.apply(_state_to, _property_cache)

func _after_tick_loop():
	if enable_recording:
		push_state()
		PropertySnapshot.apply(_state_from, _property_cache)

func _interpolate(from: Dictionary, to: Dictionary, f: float):
	if not can_interpolate():
		return

	for property in from:
		if not to.has(property): continue
		
		var property_entry = _property_cache.get_entry(property)
		var a = from[property]
		var b = to[property]
		var interpolate = _interpolators[property] as Callable
		
		property_entry.set_value(interpolate.call(a, b, f))
