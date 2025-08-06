extends VestMeasure

## Measures the maximum of a metric.

var _max: Variant
var _has: bool = false

func _init(p_metric: StringName):
  super(p_metric)

func get_measure_name() -> String:
  return "max"

func get_value() -> Variant:
  return _max

func ingest(value: Variant) -> void:
  _max = max(_max, value) if _has else value
  _has = true

