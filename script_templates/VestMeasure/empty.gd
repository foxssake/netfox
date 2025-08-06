# meta-name: Empty measure
# meta-description: Custom measure with overrideable methods implemented
# meta-default: true

extends _BASE_
class_name _CLASS_

func get_measure_name() -> String:
  return "custom"

func get_value() -> Variant:
  return 0.0

func ingest(value: Variant) -> void:
  pass

