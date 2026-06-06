"""
方向A：把米黄羊皮纸底融入暗黑紫金调。
保留米黄(暖底衬冷色宝石内容最跳) + 边缘紫晕染 + 压暗降饱和 + 隐约魔法纹/星点。
形状从金框 parchment_panel.png 的 alpha 轮廓取，100% 贴合，零误差。

用法: /opt/homebrew/bin/python3 make_parchment_fused.py
依赖: pip install pillow numpy scipy --break-system-packages
"""
import numpy as np
from PIL import Image
from scipy import ndimage

SRC = 'parchment_panel.png'   # 形状+米黄纹理来源(已有金框面板)
OUT = 'parchment_fused.png'

src = Image.open(SRC).convert('RGBA')
arr = np.array(src); H, W = arr.shape[:2]
alpha = arr[:, :, 3]
shape = (alpha > 30)
inner = ndimage.binary_erosion(shape, iterations=14)   # 金边宽度
gold_edge = shape & ~inner

base = arr[:, :, :3].astype(np.float32).copy()         # 原米黄(保留纸纹)

# 边缘紫晕染：越靠边越紫
dist_in = ndimage.distance_transform_edt(inner)
dmax = dist_in.max() or 1
edge_factor = np.clip(1 - (dist_in/(dmax*0.45)), 0, 1)
purple = np.array([60, 40, 95], dtype=np.float32)
ef = edge_factor[:, :, None] * 0.55        # 晕染强度 —— 想更融入调大(更紫)，想更保留米黄调小
base = base*(1-ef) + purple[None,None,:]*ef

# 压暗 + 降饱和，沉入暗黑调
base = base * 0.82                          # 压暗 —— 想更暗调小(如0.75)，更亮调大
gray = base.mean(axis=2, keepdims=True)
base = base*0.85 + gray*0.15                # 降饱和

# 隐约紫色魔法纹路(中心区)
np.random.seed(11)
neb = ndimage.gaussian_filter(np.random.randn(H, W), sigma=18)
neb = (neb-neb.min())/(neb.max()-neb.min())
base = base + (neb[:,:,None]-0.5)*16*np.array([0.5,0.3,0.9])[None,None,:]*(1-edge_factor[:,:,None])

# 隐约星点
stars = np.zeros((H, W))
n = int(H*W*0.0004)                          # 星点密度
ys = np.random.randint(0,H,n); xs = np.random.randint(0,W,n)
for i in range(n): stars[ys[i],xs[i]] = 0.4+np.random.rand()*0.4
stars = ndimage.gaussian_filter(stars, sigma=1.0)*180
base = base + stars[:,:,None]*np.array([0.9,0.85,1.0])[None,None,:]

base = np.clip(base, 0, 255)
out = np.zeros((H, W, 4), np.uint8)
out[:,:,:3] = base.astype(np.uint8)
out[gold_edge, :3] = arr[gold_edge, :3]      # 金边保留原色
out[:,:,3] = np.where(shape, 255, 0).astype(np.uint8)
Image.fromarray(out, 'RGBA').save(OUT)
print('saved', OUT)
