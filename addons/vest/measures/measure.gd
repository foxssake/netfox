class_name VestMeasure

## Base class for implementing measures.
##
## During benchmarks, the benchmarked code may emit custom metrics. Measures
## listen to these metrics, and aggregate the many emitted values into a single
## value, that can be included in the test report.
## [br][br]
## For example, a measure may simply count the number of emissions, calculate
## the average of the emitted values, or keep track of the minimum and maximum
## value emitted.

var _metric: StringName = &""

func _init(p_metric: StringName):
	_metric = p_metric

## Get the name of the metric this measure tracks.
func get_metric_name() -> StringName:
	return _metric

## Get the name of the measure.
## [br][br]
## [i]override[/i]
func get_measure_name() -> String:
	return ""

## Get the value of the measure.
## [br][br]
## [i]override[/i]
func get_value() -> Variant:
	return null

## Ingest an emitted metric value.
## [br][br]
## [i]override[/i]
func ingest(_value: Variant) -> void:
	pass
