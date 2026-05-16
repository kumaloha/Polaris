extends RefCounted
class_name TestBase
var errors: Array = []
func eq(a, b, m: String) -> void:
	if a != b: errors.append("%s | expected=%s actual=%s" % [m, str(b), str(a)])
func ok(c: bool, m: String) -> void:
	if not c: errors.append(m)
func ge(a, f, m: String) -> void:
	if a < f: errors.append("%s | %s < %s" % [m, str(a), str(f)])
