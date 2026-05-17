extends RefCounted
class_name Loc
static var lang := "zh"
const ZH := {
	# ── Screen titles ──────────────────────────────────────────────────────────
	"READY ROOM":        "出门准备",
	"GIRLFRIEND NIGHT":  "闺蜜局",
	"FIRST EYE":         "第一天眼",
	"PARTY":             "派对",
	"AFTER PARTY":       "派对之后",
	"FUTURE EYE":        "开天眼",
	"WEEK SETTLEMENT":   "周结算",
	"SEASON CLOSE":      "赛季落幕",

	# ── Screen subtitles ───────────────────────────────────────────────────────
	"Invest in yourself before you walk in. You decide who's worth your energy.":
		"踏出门之前先投资自己。谁值得你的精力，你说了算。",
	"Your circle decides which rooms you get into.":
		"你的圈子决定你能进哪个房间。",
	"Surface only. The truth is in the signs, not the words.":
		"只看表面。真相藏在行动里，不在嘴上。",
	"Decide where your energy goes. You can only Date one.":
		"决定精力往哪里放。约会只能选一个。",
	"Your year, your call.":
		"你的这一年，你来定。",

	# ── Section labels ─────────────────────────────────────────────────────────
	"TONIGHT'S BUILD":   "今晚的准备",
	"PERSONA":           "人设",
	"PARTY MAP":         "派对地图",

	# ── CTA buttons ────────────────────────────────────────────────────────────
	"GO TO GIRLFRIEND NIGHT  →": "进闺蜜局  →",
	"CONFIRM  →":                "确认  →",
	"CONTINUE  →":               "继续  →",
	"NEXT WEEK  →":              "下一周  →",
	"NEW SEASON  →":             "新赛季  →",

	# ── Party action buttons (display only; logic keys are English) ────────────
	"ENGAGE":            "试探",
	"BOUNDARY":          "立界限",
	"SOCIAL_PROOF":      "秀社交资本",
	"SOCIAL PROOF":      "秀社交资本",
	"EXIT":              "离场",

	# ── After-party action buttons ─────────────────────────────────────────────
	"date":              "投入",
	"observe":           "观察",
	"test":              "试探任务",
	"cut":               "止损",

	# ── HUD label fragments ────────────────────────────────────────────────────
	"Net worth":         "净值",
	"keyframes":         "关键帧",
	"debts":             "债务",
	"Carried":           "延续",
	"dossier":           "档案",
	"standing":          "站位",
	"risk:":             "风险：",

	# ── LOCKED tag ─────────────────────────────────────────────────────────────
	"  · LOCKED (tier %d)": "  · 未解锁（tier %d）",

	# ── Man names (display names from Content + ids used as display) ──────────
	"Adrian":            "艾德里安",
	"Evan":              "埃文",
	"Leo":               "利奥",
	"adrian":            "艾德里安",
	"evan":              "埃文",
	"leo":               "利奥",

	# ── Man surface labels ─────────────────────────────────────────────────────
	"resource":          "资源型",
	"growth":            "成长型",
	"false_alpha":       "伪强者",
	"high_sugar":        "高糖型",
	"uncertain":         "未知",

	# ── Man risk / opportunity strings ────────────────────────────────────────
	"Control tendency":                         "掌控欲强",
	"Concrete action if you make him earn it":  "让他先付出，才有实际行动",
	"Midnight sugar, no action":                "深夜甜言，零实质行动",
	"Short spike only":                         "短期刺激，别指望更多",
	"Ego-sensitive, low spike":                 "自尊心脆，刺激值低",
	"Cheap to observe, long upside":            "观察成本低，长线有潜力",

	# ── Chat lines ────────────────────────────────────────────────────────────
	"Saturday night?":                          "周六晚上？",
	"Tell me when and where.":                  "告诉我时间地点。",
	"Still awake? Thinking of you.":            "还没睡？我在想你。",
	"It's late.":                               "很晚了。",
	"I kept thinking about what you said.":     "我一直在想你说的那句话。",
	"Go on.":                                   "说下去。",

	# ── Self-investment names ─────────────────────────────────────────────────
	"Beauty Care":       "美容投入",
	"Work Win":          "事业战绩",
	"Solo Reset":        "独处复位",
	"Evidence Study":    "情报研读",

	# ── Persona names ─────────────────────────────────────────────────────────
	"Rare Girl":         "稀缺女孩",
	"Soft Sun":          "暖阳",
	"Power Darling":     "强势宠儿",

	# ── Girlfriend names & roles ──────────────────────────────────────────────
	"Maya":              "玛雅",
	"Claire":            "克莱尔",
	"Nina":              "妮娜",
	"Party Queen":       "派对女王",
	"High-End Circle":   "高端圈层",
	"Sharp Group Chat":  "毒舌群聊",

	# ── Party names ───────────────────────────────────────────────────────────
	"Friday Rooftop":    "周五天台",
	"Gallery Opening":   "画廊开幕",
	"Founders Dinner":   "创始人晚宴",

	# ── PartyEncounter tell lines ─────────────────────────────────────────────
	"He pauses, then: 'Saturday 8, I'll book it.'":
		"他停顿了一下，说：「周六8点，我来订。」",
	"'Don't be so serious, just come over.'":
		"「别那么认真嘛，来找我就行。」",
	"He's prickly, then thoughtful.":
		"他先有点刺儿，然后陷入沉思。",
	"He goes quiet and drifts off.":
		"他沉默了，目光飘向别处。",
	"He steps up, competes for you.":
		"他主动出击，开始争你的注意。",
	"He love-bombs harder, words not plans.":
		"他甜言蜜语轰炸升级，但还是只有话，没有计划。",
	"He warms up; cheap and easy.":
		"他热络起来，不费什么代价。",
	"You step back, hold your energy.":
		"你退后一步，保住自己的精力。",

	# ── ControlEngine sign lines ──────────────────────────────────────────────
	"He's sweeter than ever, but the plan stays vague — busy week, or are you too easy to reach?":
		"他比以往更甜，但计划依然模糊——真的很忙，还是你太容易得到？",
	"You held the line; the ball is in his court.":
		"你守住了界限，球在他那边了。",

	# ── FutureEye result names (display) ─────────────────────────────────────
	"Correct Read":      "看对了",
	"Sugar Trap":        "糖衣陷阱",
	"Slow Upside":       "慢热增值",
	"False Alpha":       "虚假强者",
	"Missed Growth":     "错失成长",

	# ── FutureEye keyframes ───────────────────────────────────────────────────
	"Keeps concrete plans":          "保持具体计划",
	"Public and stable":             "公开且稳定",
	"Standing rises":                "地位在上升",
	"High-return asset":             "高回报资产",
	"Hot then vague":                "热情之后变得模糊",
	"Still no plan":                 "依然没有计划",
	"You spent, he stalled":         "你在付出，他在拖",
	"Net loss":                      "净亏损",
	"Quiet, consistent":             "安静，持续",
	"Becomes visible":               "开始被看见",
	"Real jump":                     "真实的跃升",
	"Compounds":                     "复利增长",
	"Impressive night one":          "第一晚令人印象深刻",
	"Control creeps in":             "掌控欲悄然渗入",
	"Costs exceed status":           "成本超过地位收益",
	"Overhead eats you":             "额外开销把你吃掉",
	"You kept arm's length":         "你保持了距离",
	"He moved on":                   "他已离开",
	"He grew elsewhere":             "他在别处成长了",
	"Upside you skipped":            "你错过的那段上升空间",

	# ── FutureEye mirror line ─────────────────────────────────────────────────
	"His view of you: 'Always available, reorganized her life around me. Sugar source. Held her cheap.'":
		"他眼中的你：「随叫随到，把生活全绕着我转。甜品来源。根本不放在眼里。」",

	# ── Book event names (display) ────────────────────────────────────────────
	"missed_growth":     "错失成长",
	"creditor_pressure": "债主施压",

	# ── SeasonFlow book_for_after snark lines ────────────────────────────────
	"Watch what he does, not what he says.":
		"看他怎么做，别听他怎么说。",
	"Still carrying this one.":
		"这个还挂在账上呢。",

	# ── SeasonFlow book_for_after held-position message pattern ──────────────
	# The engine generates "(still on your book: date)" etc; we can't match the
	# full composed string, so we translate the wrapper and the decision inside.
	# Handled in Screens.gd via _loc_book_msg().


	# ── SeasonFlow [MIRROR] / [BOOK] log prefixes + content ─────────────────
	# These are composed in SeasonFlow; we translate the prefixes and combine
	"[MIRROR] ":         "[镜像] ",
	"[BOOK] ":           "[账本] ",

	# ── Hub shell: face titles ────────────────────────────────────────────────
	"YOU":               "你",
	"SELF-IMPROVEMENT":  "自我提升",
	"SOCIAL MEDIA":      "社交媒体",
	"DATING":            "约会",
	"COLLECTION":        "集卡",
	"ASSET LIST":        "资产清单",

	# ── Hub shell: bottom nav tabs ────────────────────────────────────────────
	"SELF":              "自我",
	"SOCIAL":            "社媒",
	"CARDS":             "集卡",
	"ASSETS":            "资产",

	# ── Hub shell: SELF group headers ─────────────────────────────────────────
	"SELF_INVESTMENTS":  "自我投资",
	"PERSONAS":          "人设",
	"OUTFITS":           "装扮",
	"WORKOUTS":          "运动",

	# ── Hub shell: subtitles ──────────────────────────────────────────────────
	"You decide who's worth your energy.":
		"谁值得你的精力，你说了算。",
	"Invest in yourself before you walk in.":
		"踏出门之前，先投资自己。",
	# NOTE: "Decide where your energy goes. You can only Date one." already
	# exists above (existing key, unchanged) — reused, not duplicated.
	"Nothing booked yet.":
		"暂时没有可约对象。",

	# ── Hub shell: HUD / stat word fragments ──────────────────────────────────
	"ENERGY":            "精力",
	"charm":             "魅力",
	"control":           "掌控",

	# ── Hub shell: build-lock banner ──────────────────────────────────────────
	"Locked in for tonight.": "今晚已定型。",

	# ── Social face (Plan C Task 1) ───────────────────────────────────────────
	# NOTE: "SOCIAL MEDIA", "resource", "growth", "high_sugar" already exist
	# above (existing keys, unchanged) — reused, not duplicated.
	"After you change your look you post. What you post decides who slides in.":
		"换好造型就发出去。你发什么，决定谁来撩你。",
	"POST TONIGHT":      "今晚发帖",
	"Scarce — restrained, fewer but higher-value":
		"克制——少而高质",
	"Validation — chase the feed, more but cheaper":
		"博取认同——多但廉价",
	"(One post per night. Go to PARTY to read who showed up.)":
		"（每晚一帖。去派对看谁来了。）",
	"READ THE COMMENTS": "读评论区",
	"Filed — you read him right.":
		"已归档——你读对了。",
	"Off. Look again.":  "看走眼了，再看看。",
	"A DM: \"hey gorgeous, up late thinking about you 😉\"":
		"一条私信：「美女还没睡呀，一直在想你 😉」",
}
static func t(s: String) -> String:
	if lang != "zh":
		return s
	return ZH.get(s, s)
