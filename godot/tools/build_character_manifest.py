#!/usr/bin/env python3
"""Rebuild the flat character manifest from resources/characters/*.png."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "resources" / "characters"

META = {
    # Source of truth: docs/02_META系统.md §1.1 首发萌宠全表.
    "lucky": {
        "order": 0,
        "name": "默认精灵",
        "subtitle": "幸运吉祥物",
        "accent": "#cc9324",
        "skill_name": "基础提示",
        "skill_desc": "无战斗技能;对局中给基础提示(高亮可走的步,引路降挫败)。",
        "type": "常驻门面·非可玩",
        "growth": "提示克制(卡住才提示)",
        "playable": False,
        "passive": False,
    },
    "borrrower": {
        "order": 1,
        "name": "借贷",
        "subtitle": "核心·首抽必得",
        "accent": "#9d6cf0",
        "skill_name": "借贷",
        "skill_desc": "借一个特效(4连直线/T·L爆炸/5连彩球效果),本关内必须还;不还不算过关。",
        "type": "质变·一局一次",
        "growth": "高级可借更强特效",
        "playable": True,
        "passive": False,
    },
    "timerewind": {
        "order": 2,
        "name": "时间回退",
        "subtitle": "回退最近 5 步",
        "accent": "#c99024",
        "skill_name": "时间回退",
        "skill_desc": "回退最近 5 步。",
        "type": "质变·一局一次",
        "growth": "高级回退更多步",
        "playable": True,
        "passive": False,
    },
    "snapshot": {
        "order": 3,
        "name": "存档快照",
        "subtitle": "存档并跳回",
        "accent": "#7761a9",
        "skill_name": "存档快照",
        "skill_desc": "存一个局面,可一键跳回。",
        "type": "质变·一局一次",
        "growth": "高级可多存",
        "playable": True,
        "passive": False,
    },
    "longswap": {
        "order": 4,
        "name": "隔位对换",
        "subtitle": "相邻 2 步交换",
        "accent": "#2bb6cf",
        "skill_name": "隔位对换",
        "skill_desc": "正常只能换相邻1步,这个能换相邻2步(隔一个)。",
        "type": "质变·一局一次",
        "growth": "—",
        "playable": True,
        "passive": False,
    },
    "gravityflip": {
        "order": 5,
        "name": "重力翻转",
        "subtitle": "反向下落重排",
        "accent": "#536d9a",
        "skill_name": "重力翻转",
        "skill_desc": "翻转盘面重力一次,全部反向下落重排。",
        "type": "质变·一局一次",
        "growth": "—",
        "playable": True,
        "passive": False,
    },
    "colorshield": {
        "order": 6,
        "name": "彩球护盾",
        "subtitle": "保彩球一次",
        "accent": "#6db6ff",
        "skill_name": "彩球护盾",
        "skill_desc": "这局保彩球一次(被碰只掉护盾,彩球保留)。",
        "type": "质变·一局一次",
        "growth": "高级保更多次",
        "playable": True,
        "passive": False,
    },
    "sametypeclear": {
        "order": 7,
        "name": "同类消除",
        "subtitle": "厉害款",
        "accent": "#55c6ba",
        "skill_name": "同类消除",
        "skill_desc": "选一种棋子,消除全场所有该种类。",
        "type": "质变·一局一次",
        "growth": "高级额外触发连锁/给特效",
        "playable": True,
        "passive": False,
    },
    "foresight": {
        "order": 8,
        "name": "预知",
        "subtitle": "求解器玩家化",
        "accent": "#7761a9",
        "skill_name": "预知",
        "skill_desc": "高亮接下来最优的几步走法(基于当前盘面,不剧透掉落)。",
        "type": "质变·一局一次",
        "growth": "低级亮1步,高级亮3-5步",
        "playable": True,
        "passive": False,
    },
    "breaker": {
        "order": 9,
        "name": "破障",
        "subtitle": "清障碍",
        "accent": "#f06b6b",
        "skill_name": "破障",
        "skill_desc": "直接清除场上障碍(冰/锁等)。",
        "type": "质变·一局一次",
        "growth": "破几个看等级:1级破1个→高级破2-3个",
        "playable": True,
        "passive": False,
    },
    "chainbonus": {
        "order": 10,
        "name": "连消奖步",
        "subtitle": "被动·整局生效",
        "accent": "#ff8fc9",
        "skill_name": "连消奖步",
        "skill_desc": "打连锁时奖励步数,递进式;始终靠打连锁技巧才给,不白送。",
        "type": "被动型·整局生效",
        "growth": "高级所需连锁更低",
        "playable": True,
        "passive": True,
    },
    "collector": {
        "order": 11,
        "name": "连击收集",
        "subtitle": "被动·整局生效",
        "accent": "#55c6ba",
        "skill_name": "连击收集",
        "skill_desc": "打连击时额外收集铭文碎片,奖励打连击这个核心爽点。",
        "type": "被动型·整局生效",
        "growth": "高级收集更多",
        "playable": True,
        "passive": True,
    },
}


def display_name(stem: str) -> str:
    return META.get(stem, {}).get("name", stem.replace("_", " ").replace("-", " ").title())


def main() -> int:
    characters = []
    for path in sorted(OUT.glob("*.png")):
        stem = path.stem
        meta = META.get(
            stem,
            {
                "order": 999,
                "name": display_name(stem),
                "subtitle": "文档未定义",
                "accent": "#8b54e8",
                "skill_name": "待定",
                "skill_desc": "该角色尚未写入 docs/02_META系统.md。",
                "type": "未定义",
                "growth": "未定义",
                "playable": True,
                "passive": False,
            },
        )
        with Image.open(path) as img:
            size = list(img.size)
        rel_path = f"resources/characters/{path.name}"
        characters.append(
            {
                "order": meta["order"],
                "id": stem,
                "name": meta["name"],
                "subtitle": meta["subtitle"],
                "accent": meta["accent"],
                "image": rel_path,
                "card": rel_path,
                "portrait": rel_path,
                "skill_name": meta["skill_name"],
                "skill_desc": meta["skill_desc"],
                "type": meta["type"],
                "growth": meta["growth"],
                "playable": meta["playable"],
                "passive": meta["passive"],
                "doc_ref": "docs/02_META系统.md §1.1",
                "image_size": size,
            }
        )
    characters.sort(key=lambda c: (c["order"], c["id"]))

    manifest = {
        "source": "resources/characters/*.png",
        "source_size": None,
        "characters": characters,
    }
    (OUT / "characters.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {len(characters)} characters to {OUT / 'characters.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
