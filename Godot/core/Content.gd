extends RefCounted
class_name Content
static func men() -> Array:
	return [
		{"id": "adrian", "name": "Adrian", "hidden_type": "resource",
			"surface": "resource", "energy_cost": 3,
			"risk": "Control tendency", "opportunity": "Concrete action if you make him earn it",
			"chat": [{"from": "him", "text": "Saturday night?"},
					 {"from": "you", "text": "Tell me when and where."}]},
		{"id": "evan", "name": "Evan", "hidden_type": "high_sugar",
			"surface": "growth", "energy_cost": 2,
			"risk": "Midnight sugar, no action", "opportunity": "Short spike only",
			"chat": [{"from": "him", "text": "Still awake? Thinking of you."},
					 {"from": "you", "text": "It's late."}]},
		{"id": "leo", "name": "Leo", "hidden_type": "growth",
			"surface": "false_alpha", "energy_cost": 1,
			"risk": "Ego-sensitive, low spike", "opportunity": "Cheap to observe, long upside",
			"chat": [{"from": "him", "text": "I kept thinking about what you said."},
					 {"from": "you", "text": "Go on."}]},
	]
static func personas() -> Array:
	return [
		{"id": "rare_girl", "name": "Rare Girl", "effect": {"position": 1}, "boundary_bonus": false},
		{"id": "soft_sun", "name": "Soft Sun", "effect": {"charm": 1}, "boundary_bonus": false},
		{"id": "power_darling", "name": "Power Darling", "effect": {}, "boundary_bonus": true},
	]
static func girlfriends() -> Array:
	return [
		{"id": "maya", "name": "Maya", "role": "Party Queen", "tier": 1},
		{"id": "claire", "name": "Claire", "role": "High-End Circle", "tier": 2},
		{"id": "nina", "name": "Nina", "role": "Sharp Group Chat", "tier": 3},
	]
static func parties() -> Array:
	return [
		{"id": "rooftop", "name": "Friday Rooftop", "tier": 1, "men": ["adrian", "evan", "leo"]},
		{"id": "gallery", "name": "Gallery Opening", "tier": 2, "men": ["adrian", "leo"]},
		{"id": "founders", "name": "Founders Dinner", "tier": 3, "men": ["adrian"]},
	]
static func self_investments() -> Array:
	return [
		{"id": "beauty_care", "name": "Beauty Care", "effect": {"charm": 2}},
		{"id": "work_win", "name": "Work Win", "effect": {"position": 1}},
		{"id": "solo_reset", "name": "Solo Reset", "effect": {"energy": 2}},
		{"id": "evidence_study", "name": "Evidence Study", "effect": {"first_eye_depth": 1}},
	]
