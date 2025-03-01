extends RefCounted
class_name VestMockGenerator

## Generates mocks for existing scripts
##
## @tutorial(Mocks): https://foxssake.github.io/vest/latest/user-guide/mocks/

# TODO: Support getters and setters?

## Generate a mocked version of a script
func generate_mock_script(script: Script) -> Script:
	var dummy_script := preload("res://addons/vest/mocks/vest-mock-dummy.gd") as Script
	var mock_script := dummy_script.duplicate() as Script
	mock_script.source_code = generate_mock_source(script)
	mock_script.reload()

	return mock_script

## Generate the source code for mocking a script
func generate_mock_source(script: Script) -> String:
	var mock_source := PackedStringArray()

	mock_source.append("extends \"%s\"\n\n" % [script.resource_path])
	mock_source.append("var __vest_mock_handler: VestMockHandler\n\n")

	for method in script.get_script_method_list():
		var method_name := method["name"] as String
		var method_args = method["args"]

		if method_name.begins_with("@"):
			# Getter or setter, don't generate as method
			continue

		var arg_defs := []

		for arg in method_args:
			var arg_name = arg["name"]
			arg_defs.append(arg_name)

		var arg_def_string := ", ".join(arg_defs)

		mock_source.append(
			("func %s(%s):\n" +
			"\treturn __vest_mock_handler._handle(%s, [%s])\n\n") %
			[method_name, arg_def_string, method_name, arg_def_string]
		)

	return "".join(mock_source)
