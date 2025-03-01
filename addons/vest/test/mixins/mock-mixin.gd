extends VestTestMixin

## Provides mocking for tests
##
## @tutorial(Mocks): https://foxssake.github.io/vest/latest/user-guide/mocks/

# TODO: Fail test case if there's unhandled calls

var _mock_generator := VestMockGenerator.new()
var _mock_handler := VestMockHandler.new()

# Maps Scripts to their mocked counterparts
var _mock_script_cache := {}

## Create a mocked instance of a given script
func mock(script: Script):
	var mocked_script := _get_mock_script(script)
	var mocked_object = mocked_script.new()

	_mock_handler.take_over(mocked_object)
	return mocked_object

## Get calls of a mock object's method
func get_calls_of(method: Callable) -> Array[Array]:
	var result: Array[Array] = []

	for call_data in _mock_handler.get_calls():
		if call_data.method != method:
			continue
		result.append(call_data.args)

	return result

## Start specifying an answer for a mocked method call
func when(method: Callable) -> AnswerBuilder:
	return AnswerBuilder._of(method, self)

func _get_mock_script(script: Script) -> Script:
	if _mock_script_cache.has(script):
		return _mock_script_cache.get(script)
	else:
		var mocked_script := _mock_generator.generate_mock_script(script)
		_mock_script_cache[script] = mocked_script
		return mocked_script

## Builder for specifying [VestMockDefs.Answer] objects
class AnswerBuilder:
	var _test
	var _args: Array = []
	var _method: Callable

	## Set expected arguments
	func with_args(p_args: Array) -> AnswerBuilder:
		_args = p_args
		return self

	## Answer by calling a custom method
	## [br][br]
	## The method will received the passed arguments as an array.
	func then_answer(p_answer_method: Callable) -> void:
		var answer := VestMockDefs.Answer.new()
		answer.expected_method = _method
		answer.expected_args = _args
		answer._answer_method = p_answer_method

		_test._mock_handler.add_answer(answer)

	## Answer with a fixed value
	func then_return(p_answer_value: Variant) -> void:
		var answer := VestMockDefs.Answer.new()
		answer.expected_method = _method
		answer.expected_args = _args
		answer._answer_value = p_answer_value

		_test._mock_handler.add_answer(answer)

	static func _of(p_method: Callable, p_test):
		var builder := AnswerBuilder.new()
		builder._method = p_method
		builder._test = p_test
		return builder
