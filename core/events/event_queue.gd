extends Reference
# Canonical history is persisted. The UI keeps its own non-canonical read cursor.
var history = []

func emit_event(kind, payload = {}):
	var event = {"sequence": history.size() + 1, "type": kind, "payload": payload.duplicate(true)}
	history.append(event)
	return event.duplicate(true)

func to_data():
	return history.duplicate(true)
