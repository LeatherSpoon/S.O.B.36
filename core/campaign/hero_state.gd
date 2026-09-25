extends Reference
var id = "hero_1"
var name = "Trail Tester"
var space_id = "first_0"
var xp = 0

func to_data():
	return {"id": id, "name": name, "space_id": space_id, "xp": xp}

static func from_data(data):
	var hero = load("res://core/campaign/hero_state.gd").new()
	hero.id = data.id
	hero.name = data.name
	hero.space_id = data.space_id
	hero.xp = int(data.xp)
	return hero
