extends Reference
const Hero = preload("res://core/campaign/hero_state.gd")
var id = "campaign_1"
var edition = {"id": "", "status": "unverified"}
var heroes = []
var completed_adventures = 0

func _init():
	heroes = [Hero.new()]

func to_data():
	var result = []
	for hero in heroes:
		result.append(hero.to_data())
	return {"id": id, "edition": edition.duplicate(true), "heroes": result,
		"completed_adventures": completed_adventures}

static func from_data(data):
	var campaign = load("res://core/campaign/campaign_state.gd").new()
	campaign.id = data.id
	campaign.edition = data.edition.duplicate(true)
	campaign.completed_adventures = int(data.completed_adventures)
	campaign.heroes = []
	for hero in data.heroes:
		campaign.heroes.append(Hero.from_data(hero))
	return campaign
