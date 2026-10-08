class_name JsonStore
extends RefCounted


static func read_object(path: String) -> Dictionary:
	var value: Variant = _read(path)
	if value is Dictionary:
		return value as Dictionary
	push_error("Expected JSON object in %s" % path)
	return {}


static func read_array(path: String) -> Array[Dictionary]:
	var value: Variant = _read(path)
	var result: Array[Dictionary] = []
	if not value is Array:
		push_error("Expected JSON array in %s" % path)
		return result
	for item: Variant in value as Array:
		if item is Dictionary:
			result.append(item as Dictionary)
		else:
			push_error("Expected every item in %s to be an object" % path)
	return result


static func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Missing JSON file: %s" % path)
		return null
	var text: String = FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var error: Error = json.parse(text)
	if error != OK:
		push_error("Invalid JSON in %s at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data

