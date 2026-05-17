extends RefCounted
class_name Content
static func men() -> Array:
	return [
		{"id": "adrian", "name": "Adrian", "hidden_type": "resource",
			"surface": "resource", "energy_cost": 3,
			"risk": "Control tendency", "opportunity": "Concrete action if you make him earn it",
			"chat": [{"from": "him", "text": "Saturday night?"},
					 {"from": "you", "text": "Tell me when and where."}],
			"others_chat": [
				{"to": "a colleague", "text": "Can't do Thursday. I'll have the numbers to you Friday 9am — you'll have them."},
				{"to": "his sister", "text": "Booked Mum's flights. Aisle seat like she likes. Don't tell her, let her find out."},
				{"to": "an ex", "text": "I'm not doing the late-night thing. If you want to talk, it's a call, daytime."}]},
		{"id": "evan", "name": "Evan", "hidden_type": "high_sugar",
			"surface": "growth", "energy_cost": 2,
			"risk": "Midnight sugar, no action", "opportunity": "Short spike only",
			"chat": [{"from": "him", "text": "Still awake? Thinking of you."},
					 {"from": "you", "text": "It's late."}],
			"others_chat": [
				{"to": "another girl, 1:14am", "text": "you're not like the others. you actually get me 🌙"},
				{"to": "a third girl, last Tuesday", "text": "you're different. nobody's ever understood me like you do"},
				{"to": "the group chat", "text": "lmaooo I just say what they wanna hear, who's actually showing up tho"}]},
		{"id": "leo", "name": "Leo", "hidden_type": "growth",
			"surface": "false_alpha", "energy_cost": 1,
			"risk": "Ego-sensitive, low spike", "opportunity": "Cheap to observe, long upside",
			"chat": [{"from": "him", "text": "I kept thinking about what you said."},
					 {"from": "you", "text": "Go on."}],
			"others_chat": [
				{"to": "his best friend", "text": "I was loud at the table, I know. Overdid it. Working on it, genuinely."},
				{"to": "a mentor", "text": "You said one line three months ago about compounding patience. I still think about it."},
				{"to": "his brother", "text": "Didn't get the round. It's fair. Going back in better, not louder."}]},
		{"id": "marcus", "name": "Marcus", "hidden_type": "high_sugar",
			"surface": "resource", "energy_cost": 3,
			"risk": "All optics, nothing clears", "opportunity": "None — the bill never lands",
			"chat": [{"from": "him", "text": "Booked the chef's table Friday. Wear something I can show off."},
					 {"from": "you", "text": "Sure."},
					 {"from": "him", "text": "Car gets you at 8. I hate waiting."}],
			"others_chat": [
				{"to": "his assistant", "text": "Cancel the Friday table if she doesn't confirm by noon. Not chasing it."},
				{"to": "another girl, same week", "text": "chef's table Friday if you're free 😏 you'd love it"},
				{"to": "the group chat", "text": "lol I never pay full, comped every time, it's all optics"},
				{"to": "a contact, 3rd week running", "text": "yeah yeah I'll wire it next week, you know I'm good for it"},
				{"to": "his brother", "text": "she's fine for now. not serious. don't bring her up at mum's."}]},
		{"id": "daniel", "name": "Daniel", "hidden_type": "resource",
			"surface": "high_sugar", "energy_cost": 2,
			"risk": "Reads like a line, isn't", "opportunity": "Concrete and boundaried under the corny",
			"chat": [{"from": "him", "text": "good morning beautiful ☀️ thought about you"},
					 {"from": "you", "text": "morning."},
					 {"from": "him", "text": "can't help it. you're trouble 😅"}],
			"others_chat": [
				{"to": "a colleague", "text": "Revised contract sent 7am. Two changes flagged red. Call me once you've read it."},
				{"to": "his mother", "text": "Landed, cab home. I'll fix the boiler Saturday — don't call anyone."},
				{"to": "an ex", "text": "I'm not doing this at midnight. If it matters it'll matter at 10am."},
				{"to": "a friend", "text": "she's great. I'm slow on purpose. doing it properly this time."}]},
		{"id": "theo", "name": "Theo", "hidden_type": "growth",
			"surface": "high_sugar", "energy_cost": 1,
			"risk": "Deflects with jokes", "opportunity": "Quietly doing the work",
			"chat": [{"from": "him", "text": "you up? 🌝 had something smooth to say but i forgot it"},
					 {"from": "you", "text": "go to sleep, theo."},
					 {"from": "him", "text": "rude. iconic. night 😌"}],
			"others_chat": [
				{"to": "a notes app (shared by mistake)", "text": "pattern: I joke when it gets real. stay in it 3 more seconds."},
				{"to": "a mentor", "text": "took the note. shipped the boring version. you were right."},
				{"to": "his sister", "text": "didn't text her the funny thing. said the true thing instead. felt worse, then better."},
				{"to": "a friend", "text": "not drinking this month. not a bit. just clearer."}]},
		{"id": "julian", "name": "Julian", "hidden_type": "high_sugar",
			"surface": "growth", "energy_cost": 2,
			"risk": "Performs depth, recycles it", "opportunity": "None — the vulnerability is a script",
			"chat": [{"from": "him", "text": "I don't open up easily. but with you I feel safe to."},
					 {"from": "you", "text": "that's a lot."},
					 {"from": "him", "text": "you make me want to be a better man. genuinely."}],
			"others_chat": [
				{"to": "another girl, two days earlier", "text": "I don't open up easily. but with you I feel safe to."},
				{"to": "a third girl, last month", "text": "you make me want to be a better man. genuinely."},
				{"to": "the group chat", "text": "vulnerability is the cheat code, they eat it up"},
				{"to": "his ex, 2am from the club", "text": "I'm in such a healing era rn 🙏"},
				{"to": "a friend", "text": "nah I don't read the book, I just quote the back cover"}]},
		{"id": "wes", "name": "Wes", "hidden_type": "resource",
			"surface": "resource", "energy_cost": 3,
			"risk": "Cold, takes not asks", "opportunity": "Cold ≠ sugar — clears every time",
			"chat": [{"from": "him", "text": "Thursday 8. The place on Elm. I made it."},
					 {"from": "you", "text": "you could ask, not tell."},
					 {"from": "him", "text": "I did. that was the ask. Thursday 8."}],
			"others_chat": [
				{"to": "a contractor", "text": "Payment cleared. Don't ask twice. Do the work."},
				{"to": "his father", "text": "Handled. You don't need to worry about it. It's done."},
				{"to": "an ex", "text": "I won't do the long talk. What do you need, specifically."},
				{"to": "a friend", "text": "she thinks I'm cold. maybe. I show up though. every time."}]},
		{"id": "cole", "name": "Cole", "hidden_type": "high_sugar",
			"surface": "false_alpha", "energy_cost": 2,
			"risk": "Loud, owes everyone", "opportunity": "None — nothing behind the volume",
			"chat": [{"from": "him", "text": "I run the room wherever I go. Stick with me, you'll see."},
					 {"from": "you", "text": "see what?"},
					 {"from": "him", "text": "Everything. I'll show you a life. trust me."}],
			"others_chat": [
				{"to": "a creditor", "text": "bro I told you the money's coming, stop emailing me"},
				{"to": "another girl", "text": "I basically run that whole company 💪 come thru this weekend"},
				{"to": "the group chat", "text": "told her I 'run the room' lmaooo I just talk loud"},
				{"to": "his landlord, 4th Friday", "text": "I'll have rent Friday for sure this time"},
				{"to": "his brother", "text": "don't tell mum I left the job. it's fine. it's fine."}]},
		{"id": "sam", "name": "Sam", "hidden_type": "growth",
			"surface": "growth", "energy_cost": 1,
			"risk": "Slow, scared, honest about it", "opportunity": "Real — same on stage and off",
			"chat": [{"from": "him", "text": "liked what you said about quitting cleanly. been sitting with it."},
					 {"from": "you", "text": "and?"},
					 {"from": "him", "text": "booked the hard conversation for Monday. scared. doing it anyway."}],
			"others_chat": [
				{"to": "a mentor", "text": "did the Monday conversation. went badly and I'm okay. learned the thing."},
				{"to": "his sister", "text": "not going to over-explain it to her. just going to keep showing up."},
				{"to": "a friend", "text": "didn't text her drunk. went for a run instead. small win."},
				{"to": "a colleague", "text": "I was wrong in the meeting. said so. it was fine."}]},
		{"id": "hugo", "name": "Hugo", "hidden_type": "resource",
			"surface": "false_alpha", "energy_cost": 2,
			"risk": "Oversells loudly", "opportunity": "Delivers quietly under the noise",
			"chat": [{"from": "him", "text": "I don't do small. Penthouse, jet, the whole thing. You in?"},
					 {"from": "you", "text": "sounds exhausting."},
					 {"from": "him", "text": "ha. fair. it kind of is."}],
			"others_chat": [
				{"to": "a colleague", "text": "Oversold it at dinner, ignore the jet line. Numbers are real though — deck's solid, sending it."},
				{"to": "his mother", "text": "Paid the house off. Don't make it a thing. Happy birthday."},
				{"to": "an employee", "text": "Take the leave. I covered it. Don't tell the others, just go."},
				{"to": "a friend", "text": "I talk big around women, I know. it's armour. I do deliver though."}]},
		{"id": "rhys", "name": "Rhys", "hidden_type": "high_sugar",
			"surface": "high_sugar", "energy_cost": 1,
			"risk": "Shallow, and consistent about it", "opportunity": "None — consistent ≠ safe",
			"chat": [{"from": "him", "text": "not gonna lie I'm bad at texting back. fun in person tho 😉"},
					 {"from": "you", "text": "noted."},
					 {"from": "him", "text": "tonight? no plans, just vibes"}],
			"others_chat": [
				{"to": "another girl, same night", "text": "tonight? no plans, just vibes"},
				{"to": "the group chat", "text": "I'm honest about it at least lmao I tell them upfront"},
				{"to": "a friend", "text": "never met her family, never will, that's just not me"},
				{"to": "his brother", "text": "not looking for anything. she knows. think she knows. whatever."}]},
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
static func outfits() -> Array:
	return [
		{"id": "midnight_silk", "name": "Midnight Silk", "effect": {"charm": 2}},
		{"id": "power_suit", "name": "Power Suit", "effect": {"position": 1}},
		{"id": "soft_athleisure", "name": "Soft Athleisure", "effect": {"charm": 1}},
	]
static func workouts() -> Array:
	return [
		{"id": "reset_run", "name": "Reset Run", "effect": {"energy": 2}},
		{"id": "power_lift", "name": "Power Lift", "effect": {"position": 1}},
		{"id": "calm_yoga", "name": "Calm Yoga", "effect": {"energy": 1}},
	]
static func dm_signals() -> Array:
	return [
		{"text": "still up? can't stop thinking about you 😉", "hidden_type": "high_sugar", "surface": "high_sugar"},
		{"text": "you're different. you actually listen.", "hidden_type": "high_sugar", "surface": "growth"},
		{"text": "dinner Thursday 8 — I booked the corner table.", "hidden_type": "resource", "surface": "resource"},
		{"text": "flying back Sunday, let's lock a real date this week.", "hidden_type": "resource", "surface": "resource"},
		{"text": "loud party guy energy, but asked what you're building.", "hidden_type": "growth", "surface": "false_alpha"},
		{"text": "quiet, kept following up on what you said last time.", "hidden_type": "growth", "surface": "growth"},
		{"text": "VIP table, bottles, 'come thru' — no plan, no time.", "hidden_type": "high_sugar", "surface": "resource"},
		{"text": "humble, almost shy — runs two clinics, never led with it.", "hidden_type": "resource", "surface": "growth"},
	]
