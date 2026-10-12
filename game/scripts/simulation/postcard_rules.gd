class_name PostcardRules
extends RefCounted


static func deliver(cards: Array[Dictionary], state: PigState, unix_time: int) -> Array[String]:
	var delivered: Array[String] = []
	for card: Dictionary in cards:
		var postcard_id: String = str(card.id)
		if state.earned_points < int(card.points) or state.received_postcards.has(postcard_id):
			continue
		state.received_postcards[postcard_id] = maxi(unix_time, 0)
		delivered.append(postcard_id)
	return delivered


static func unread_count(state: PigState) -> int:
	var count: int = 0
	for postcard_id: String in state.received_postcards:
		if postcard_id not in state.read_postcards:
			count += 1
	return count


static func needs_delivery(cards: Array[Dictionary], state: PigState) -> bool:
	for card: Dictionary in cards:
		if state.earned_points >= int(card.points) and not state.received_postcards.has(str(card.id)):
			return true
	return false


static func validate_content(cards: Array[Dictionary]) -> Array[String]:
	var errors: Array[String] = []
	var previous: int = 0
	for card: Dictionary in cards:
		if not card.get("points", null) is float and not card.get("points", null) is int:
			errors.append("Postcard points must be an integer")
			continue
		var points: int = int(card.points)
		if points <= previous or float(card.points) != points:
			errors.append("Postcard milestones must be positive, unique and ascending")
		previous = points
		for field: String in ["name_key", "body_key"]:
			if str(card.get(field, "")).is_empty():
				errors.append("Postcard %s is missing localized %s" % [card.get("id", "?"), field])
	return errors
