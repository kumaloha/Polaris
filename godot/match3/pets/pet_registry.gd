class_name PetRegistry
extends RefCounted
## 技能名 → 宠物施法类 的映射（契约 C, docs/11 §4.7）。
##
## 加一只宠物 = 新增一个 PetCast 子类文件 + 在 PETS 加一行。
## level.gd 的 _on_skill_pressed 经 cast_for() 查类, 零 match 字符串分支硬编码。

const TimeRabbitCast := preload("res://match3/pets/time_rabbit.gd")
const RaccoonMinerCast := preload("res://match3/pets/raccoon_miner.gd")

const PETS := {
	"时间回退": TimeRabbitCast,
	"破障": RaccoonMinerCast,
}

## 按 SKILLS[idx].skill 字符串查对应宠物施法类。无映射返回 null。
static func cast_for(skill_name: String) -> Script:
	return PETS.get(skill_name, null)

## 该技能是否由宠物施法控制器接管(用于 dispatch 分流)。
static func has_pet(skill_name: String) -> bool:
	return PETS.has(skill_name)
