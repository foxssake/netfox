extends Object
class_name VestMockDefs

## Grouping class for mock definition primitives.
##
## See [VestMockDefs.Answer][br]
## See [VestMockDefs.Call][br]

## Mock answer definition
##
## Each answer manages a mock method. When this method is called, instead of
## running the underlying code, the answer provides a response.
class Answer:
	## The method this instance provides the answers for
	var expected_method: Callable

	## The expected arguments for providing the answers.
	## [br][br]
	## May be empty, in which case any and all parameters are accepted.
	var expected_args: Array = []

	var _answer_value: Variant
	var _answer_method: Callable

	func _get_specificity() -> int:
		return expected_args.size()

	func _is_answering(method: Callable, args: Array) -> bool:
		if method != expected_method:
			return false
		if method.get_object() != expected_method.get_object():
			return false
		if expected_args.is_empty():
			return true
		if args.size() != expected_args.size():
			return false
		if args == expected_args:
			print("Arg match!")
			return true

		# Do a lenient check, so users don't trip on unexpected diffs, like
		# [2, 4] != [2., 4.]
		var lenient_actual := args.map(func(it): return _map_lenient(it))
		var lenient_expected := expected_args.map(func(it): return _map_lenient(it))
		if lenient_actual == lenient_expected:
			return true
		return false

	func _get_answer(args: Array) -> Variant:
		if _answer_method:
			return _answer_method.call(args)
		else:
			return _answer_value

	func _map_lenient(value: Variant) -> String:
		if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
			return "%.8f" % [value]
		return str(value)

	func _to_string() -> String:
		return "Answer { %s.%s(%s) }" % [expected_method.get_object(), expected_method.get_method(), expected_args]

## A recorded method call
class Call:
	## The method that was called
	var method: Callable

	## The arguments used for calling the method
	var args: Array = []
