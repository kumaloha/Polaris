extends RefCounted
# 极简 headless 测试基类：测试脚本 extends 它，用 assert_* 记录失败。
# runner.gd 反射调用所有 test_* 方法，failures 非空即失败。

var failures: Array = []

func assert_eq(actual, expected, msg := "") -> void:
	if actual != expected:
		failures.append("assert_eq: expected %s, got %s  %s" % [str(expected), str(actual), msg])

func assert_ne(actual, unexpected, msg := "") -> void:
	if actual == unexpected:
		failures.append("assert_ne: did not expect %s  %s" % [str(unexpected), msg])

func assert_true(cond: bool, msg := "") -> void:
	if not cond:
		failures.append("assert_true failed  %s" % msg)

func assert_false(cond: bool, msg := "") -> void:
	if cond:
		failures.append("assert_false failed  %s" % msg)
