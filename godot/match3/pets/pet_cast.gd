class_name PetCast
extends Node2D
## 宠物施法控制器基类（契约 C, docs/11 §4.2-4.3）。
##
## 实例由 level.gd 经 PetRegistry 创建并 add_child 挂在 level 之下：
##   换关 free(level 子树) → _exit_tree → cancel() → 绑在 self 上的 tween 自动死
##   → 跨代回调在结构上不可能发生（取代旧 _kill_time_rabbit_cast 手工清理 + cast_tween meta）。
##
## 锁协议（读写锁只在 level.gd，本类只发信号）：
##   cast_started   → level: 上输入锁 (_busy / cast_pending = true)
##   cast_committed → level: 技能效果已落地, 同步棋盘视图 (_render_board + _refresh_hud)
##   cast_finished  → level: 演出全部结束(含归位/取消), 释放锁
##
## headless(not inside_tree) 路径：start_cast 时不在树内 → 不跑 tween,
##   直接 _apply_effect() + emit committed/finished；rig 仍构建(结构测试需观察帧序列/道具)。

signal cast_started
signal cast_committed
signal cast_finished

enum State { IDLE, CASTING, COMMITTED, RETIRED }

var _state: int = State.IDLE
var _tween: Tween = null              # 绑定在 self 上：create_tween() 即可, self free 即死
var _finished_emitted: bool = false

## ── 模板方法（基类实现, 子类勿覆写）──

## 启动施法。返回 false 表示拒绝(非 IDLE 或子类 _can_cast 否决)。
func start_cast() -> bool:
	if _state != State.IDLE:
		return false
	if not _can_cast():
		return false
	_state = State.CASTING
	emit_signal("cast_started")
	_build_visuals()
	if is_inside_tree():
		_tween = create_tween()
		_run_cast(_tween)
	else:
		# 无树(headless/测试): 不跑 tween, 直接落地效果并立即收尾。
		# rig 不在此回收——随 self(level 子树) 释放, 且结构测试要观察 rig 的帧序列/道具。
		_commit()
		_finish()
	return true

## 任何状态可调：杀 tween → 立即回收演出 → 复原头像 → 若未发过 finished 则补发 → RETIRED。
## 幂等：重复调用(无 tween/已 RETIRED)不崩。
func cancel() -> void:
	if _state == State.RETIRED:
		_dispose_visuals()
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_dispose_visuals()
	_restore_avatar()
	_state = State.RETIRED
	if not _finished_emitted:
		_finished_emitted = true
		emit_signal("cast_finished")

func _exit_tree() -> void:
	cancel()   # 换关兜底, 结构性根治跨代回调(review C2)

## ── tween 回调挂钩点(子类在 _run_cast 里 tween_callback 到这两个)──

## 效果落地点：调 _apply_effect()，成功则 emit committed。
func _commit() -> void:
	if _state != State.CASTING:
		return
	if _apply_effect():
		emit_signal("cast_committed")
	_state = State.COMMITTED

## 演出收尾点：复原头像 + 回收演出 + emit finished。
func _finish() -> void:
	if _finished_emitted:
		return
	_restore_avatar()
	_state = State.RETIRED
	_finished_emitted = true
	emit_signal("cast_finished")

## ── 子类钩子（默认空实现）──

## 是否允许施法(子类查 board 状态等)。默认允许。
func _can_cast() -> bool:
	return true

## 组装演出节点树(精灵/道具/特效)。在 emit cast_started 之后、tween 编排之前调用一次。
func _build_visuals() -> void:
	pass

## 用传入的 tween 编排施法演出。子类负责在中点 tween_callback(_commit)、末尾 tween_callback(_finish)。
func _run_cast(_tween_arg: Tween) -> void:
	pass

## 技能落地：调 board.skill_*，返回是否生效。
func _apply_effect() -> bool:
	return false

## 复原头像位显示(取消/结束共用)。
func _restore_avatar() -> void:
	pass

## 回收演出节点(取消/兜底共用)。子类清理挂在别处(如 skill_bar)的可视节点。
func _dispose_visuals() -> void:
	pass
