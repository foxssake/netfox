extends RefCounted
class_name VestMockHandler

## Manages mock instances

var _answers: Array[VestMockDefs.Answer] = []
var _calls: Array[VestMockDefs.Call] = []
var _unhandled_calls: Array[VestMockDefs.Call] = []

## Take over a mock instance, recording its calls and providing its answers
func take_over(what: Object):
	what.__vest_mock_handler = self

## Register an answer
func add_answer(answer: VestMockDefs.Answer):
	_answers.append(answer)

## Get all recorded mock calls
func get_calls() -> Array[VestMockDefs.Call]:
	return _calls

## Get all recorded mock calls to which there were no registered answers
func get_unhandled_calls() -> Array[VestMockDefs.Call]:
	return _unhandled_calls

func _handle(method: Callable, args: Array):
	var call_data := VestMockDefs.Call.new()
	call_data.method = method
	call_data.args = args

	var possible_answers = _answers\
		.filter(func(it): return it._is_answering(method, args))
	possible_answers.sort_custom(func(a, b): return a._get_specificity() > b._get_specificity())

	if possible_answers.is_empty():
		_unhandled_calls.append(call_data)
		return

	var answer := possible_answers.front() as VestMockDefs.Answer
	_calls.append(call_data)
	return answer._get_answer(args)
