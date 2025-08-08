extends VestMeasure

## Measures the average of a metric.

var _sum: Variant
var _count: int = 0

func _init(p_metric: StringName):
  super(p_metric)

func get_measure_name() -> String:
  return "average"

func get_value() -> Variant:
  return _sum / _count

func ingest(value: Variant) -> void:
  _sum = _sum + value if _count else value
  _count += 1

