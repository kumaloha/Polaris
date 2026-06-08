#!/usr/bin/env python3
# 棋盘对齐自检: 量化"魔法书书页金框内沿"与"棋子分布"的像素偏差。
# 用法: /opt/homebrew/bin/python3 godot/tools/check_align.py godot/_shot_v02.png
# 期望: 棋子bbox 在书页内框内居中, 左右边距对称、上下边距对称(差值≈0)。
import sys, statistics
from PIL import Image

path = sys.argv[1] if len(sys.argv) > 1 else "godot/_shot_v02.png"
im = Image.open(path).convert("RGB")
W, H = im.size
px = im.load()

def is_page(r, g, b):      # 米黄书页/格(暖黄)
    return r > 205 and 165 < g < 246 and 110 < b < 200 and (r - b) > 48
def is_gold(r, g, b):      # 金框
    return r > 175 and 110 < g < 205 and b < 135 and (r - b) > 85
def is_purple(r, g, b):    # 紫书脊
    return 55 < r < 165 and g < 95 and 95 < b < 205
def is_sky(r, g, b):       # 天空(浅蓝/浅黄渐变, 高亮低饱和)
    return b > 195 and g > 200
def is_gem(r, g, b):       # 彩色棋子(高饱和, 排除暖黄书页/金框)
    mx, mn = max(r, g, b), min(r, g, b)
    if mx - mn < 70:
        return False
    if is_page(r, g, b) or is_gold(r, g, b):
        return False
    return True

# ---- 书页金框内沿(米黄起始) ----
def page_left(y):
    for x in range(W):
        if is_page(*px[x, y]): return x
    return -1
def page_right(y):
    for x in range(W - 1, -1, -1):
        if is_page(*px[x, y]): return x
    return -1
def page_top(x):
    for y in range(H):
        if is_page(*px[x, y]): return y
    return -1
def page_bot(x):
    for y in range(H - 1, -1, -1):
        if is_page(*px[x, y]): return y
    return -1

band = range(int(H * 0.40), int(H * 0.60), 6)
Ls = [v for v in (page_left(y) for y in band) if v > 0]
Rs = [v for v in (page_right(y) for y in band) if v > 0]
pageL = int(statistics.median(Ls)); pageR = int(statistics.median(Rs))
xcol_l = int(pageL + (pageR - pageL) * 0.25)
xcol_r = int(pageL + (pageR - pageL) * 0.75)
Ts = [v for v in (page_top(x) for x in (xcol_l, xcol_r)) if v > 0]
Bs = [v for v in (page_bot(x) for x in (xcol_l, xcol_r)) if v > 0]
pageT = min(Ts); pageB = max(Bs)
print("书页内框(金框内沿): L=%d R=%d T=%d B=%d  宽=%d 高=%d" %
      (pageL, pageR, pageT, pageB, pageR - pageL, pageB - pageT))

# ---- 棋子分布 bbox ----
xs, ys = [], []
for y in range(int(H * 0.22), H, 2):
    for x in range(0, W, 2):
        if is_gem(*px[x, y]):
            xs.append(x); ys.append(y)
if not xs:
    print("未检出棋子"); sys.exit(1)
gemL, gemR, gemT, gemB = min(xs), max(xs), min(ys), max(ys)
print("棋子bbox:          L=%d R=%d T=%d B=%d" % (gemL, gemR, gemT, gemB))

mL, mR, mT, mB = gemL - pageL, pageR - gemR, gemT - pageT, pageB - gemB
print("书页内框→棋子边距:  左=%d 右=%d 上=%d 下=%d" % (mL, mR, mT, mB))
print("对称性: 左右差=%+d  上下差=%+d  (理想≈0)" % (mL - mR, mT - mB))
overshoot = [n for n, v in (("左", mL), ("右", mR), ("上", mT), ("下", mB)) if v < 0]
if overshoot:
    print("!! 棋子溢出书页内框: " + ",".join(overshoot))
tol = 8
ok = abs(mL - mR) <= tol and abs(mT - mB) <= tol and not overshoot
print("判定: " + ("对齐 OK" if ok else "未对齐 — 需修正"))
