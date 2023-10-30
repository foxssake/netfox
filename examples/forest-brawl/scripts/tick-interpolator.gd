extends Node
class_name TickInterpolator
# TODO: Add as feature

@export var root: Node = get_parent()
@export var enabled: bool = true
@export var properties: Array[String]
@export var record_first_state: bool = true

var _state_from: Dictionary = {}
var _state_to: Dictionary = {}
var _props: Array[PropertyEntry] = []

var _property_cache: PropertyCache

## Process settings.
##
## Call this after any change to configuration.
func process_settings():
	_property_cache = PropertyCache.new(root)
	
	_state_from = {}
	_state_to = {}

	for property in properties:
		var pe = _property_cache.get_entry(property)
		_props.push_back(pe)

## Check if interpolation can be done.
##
## Even if it's enabled, no interpolation will be done if there are no
## properties to interpolate.
func can_interpolate() -> bool:
	return enabled and not properties.is_empty()

func push_state():
	_state_from = _state_to
	_state_to = PropertySnapshot.extract(_props)

func _ready():
	process_settings()
	NetworkTime.before_tick_loop.connect(_before_tick_loop)
	NetworkTime.after_tick_loop.connect(_after_tick_loop)

	# Wait a frame for any initial setup before recording first state
	if record_first_state:
		await get_tree().process_frame
		push_state()
		push_state()

func _process(delta):
	_interpolate(_state_from, _state_to, NetworkTime.tick_factor, delta)

func _before_tick_loop():
	PropertySnapshot.apply(_state_to, _property_cache)

func _after_tick_loop():
	push_state()

func _interpolate(from: Dictionary, to: Dictionary, f: float, delta: float):
	if not can_interpolate():
		return

	for property in from:
		if not to.has(property): continue
		
		var pe = _property_cache.get_entry(property)
		var a = from[property]
		var b = to[property]
		
		pe.set_value(pe.interpolate.call(a, b, f))
