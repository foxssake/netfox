extends VestMeasure

## Measures the sum of a metric.

var _sum: Variant
var _has: bool = false

func _init(p_metric: StringName):
  super(p_metric)

func get_measure_name() -> String:
  return "sum"

func get_value() -> Variant:
  return _sum

func ingest(value: Variant) -> void:
  _sum = _sum + value if _has else value
  _has = true

