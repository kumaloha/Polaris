# Candy Crush Saga 关卡设计系统深度研究报告

> 主题：CCS 的难度曲线 / 机制引入节奏 / 教学关 / 留存 / 具体关卡剖析 / 设计原理
>
> 方法：多来源交叉印证 —— King 官方设计师访谈（PocketGamer.biz、MobileGamer.biz、Gamedeveloper.com 的 GDC 报道）、Apple App Store 官方设计师专访、Yahoo/King 资深关卡设计师 Rasmus Eriksson 专访、Candy Crush Saga Wiki（Fandom）、King 官方社区、学术/数据科学分析（RPubs、DataCamp 项目、UXP2 Dark Patterns、Yu-kai Chou Octalysis）等。所有来源链接见文末。
>
> 目的：服务 Polaris（gem 消除 match-3 手游）的"关卡生成系统"，核心命题是"关卡设计本身带来留存"。每节末尾给出「对 Polaris 的启示」，文末汇总 10 条可执行结论。

---

## 0. 一句话总览

CCS 的关卡系统不是"一堆谜题的堆叠"，而是一套**以数据为度量、以心流（flow）为理论、以锯齿（sawtooth）难度为节奏、以失败为留存/变现杠杆**的工业化内容流水线。它把"难度"和"乐趣"刻意拆开度量，用 episode 把无限长的内容切成有节奏的"小说章节"，每个新机制都用一关近乎纯净的"教学关"引入，再在段末/版本末放置"难度墙"制造记忆点和社交传播。

---

## 1. Episode / 分段结构：把"无限关卡"切成"有章节的小说"

**基本结构**

- 主线**严格线性**：所有关卡按地图编排进 **episode（章节）**，episode 又归入 world。
- **每个 episode 标准 = 15 关**（早期的 Candy Town 关卡 1–10、Candy Factory 关卡 11–20 是 10 关的例外）。整个游戏现已超过 15000+ 关 / 1500+ episode（HTML5 版统计到约 22505 关 / 1501 episode，且持续更新，King 历史上常态是每周发约 3 个新 episode = 45 个新关）。
- **每个 episode 有独立命名、独立主题、独立吉祥物/故事**（如 Candy Town、Candy Factory、Soda Swamp、Minty Meadow、Gingerbread Glade…），命名常用头韵（alliteration，同首字母）。这把"第 247 关"这种冰冷编号，包装成"我正在穿越薄荷草原"的叙事旅程。

**段末门槛关（episode finale）与"门"机制 —— 这是留存设计的核心之一**

- 早期（HTML5 改版前，约 episode 3 到 63）：**打完一个 episode 的最后一关后，会被"门"卡住**，玩家必须三选一才能进入下一章：
  1. 等 **72 小时**；
  2. 向 **3 个 Facebook/King 好友各要 1 张 ticket（车票）**；
  3. 花金条购买（约 9 gold bars = 3 张票）。
- 这是一个**强制社交/付费/等待的三岔口**：它把"通关进度"变成"必须拉好友进游戏"的病毒裂变引擎，同时制造付费窗口。
- 现代版已大幅弱化：通关 finale 直接进下一章（ticket 门基本取消），社交压力转移到了 lives（命）和排行榜。

**段末关在心理/留存上的作用**

- Yu-kai Chou 的 Octalysis 分析把 episode 末尾关称为 **"boss fight"**：要求玩家在进入新章前"巩固技能"，形成清晰的成就标记（Core Drive 2 Accomplishment）。
- Apple 官方专访里设计师 **Tobias Nyblom** 明确说：**臭名昭著的 Level 65 之所以被刻意做难，正因为它是"第二次更新的最后一关"** —— "我们想在不知道下次更新还要多久的情况下，给玩家一个真正的挑战。"（即：**段末/版本末 = 留存锚点，用一道墙把玩家"焊"在那里**，制造期待与回访。）

> **对 Polaris 的启示**：分段不是排版，而是留存装置。给每段命名 + 主题 + 一个段末"挑战关"，把线性长流程切成"可被记住、可被讲述、有节奏起伏"的章节。段末是放"记忆点"和"社交/回访钩子"的黄金位置。

---

## 2. 难度分级体系：官方四档 + 脚本判定 + 锯齿编排

**官方/社区四档分级**（CCS Wiki，且 King 官方采用类似标签）：

| 档位 | 视觉标识 | 说明 |
|---|---|---|
| **Normal（普通）** | 无 | 大多数关卡 |
| **Hard（难）** | — | 明显高于普通难度 |
| **Super Hard（超难）** | ⛈ 雷暴 emoji，"thunderstorm levels"，约 1645 关 | King 官方标记 |
| **Nightmarishly Hard（噩梦难）** | 🦉 猫头鹰（Odus）emoji，海军蓝配色，约 1643 关 | 评级常达"极难~近乎不可能" |

**关键：分级是数据驱动、脚本自动判定的，不是人手拍脑袋**

- CCS Wiki 明确："**King 不亲自选定任何关卡的难度评级，这是由后台运行的一个脚本完成的。**"
- 判定依据是**胜率（win rate）**：把该关胜率与"普通关基准胜率"对比，**胜率显著下降**就升档标记。
- 评级**会动态调整**：一关如果上线后数据显示太难/太易，会被重新标记甚至重做。
- 学术细分（社区/分析者用的更细的"Difficulty/Reality"量表）：None / Very Easy / Easy / Somewhat Easy / Medium / Somewhat Hard / Hard / Very Hard / Extremely Hard / Nearly Impossible / Variable。

**难度是否刻意 easy/hard 交替形成锯齿？—— 是，且有理论支撑**

- 这就是 **sawtooth（锯齿）难度曲线**：难度沿若干关线性爬升，然后在某一关"瞬间回落"，形如锯齿。**这是 match-3 等休闲关卡游戏的标准做法。**
- 理论基础是 **Csikszentmihalyi 的心流理论**：最佳投入状态是"挑战与玩家技能的平衡"。挑战太大→挫败，太小→无聊，而"无聊的游戏就是被卸载的游戏"。
- 典型实现："难度每 5 关递增，第 6 关回落"形成锯齿 —— **回落关给玩家在一串硬关后喘息**，递增+回落的组合把玩家持续保持在心流带内。
- King 自己用的是另一套词（见第 7 节）：**difficulty / rhythm / flow / hooks 四要素**，其中 **rhythm（节奏）就是"变化体验以维持投入"** —— 本质就是锯齿编排：硬关之间夹软关、不同模式交替、不同长度交替。

> **对 Polaris 的启示**：难度评级应由**胜率脚本自动产出**（你已有量化自检的习惯，正好对口），而不是设计师主观标 Easy/Hard。曲线要做成锯齿而非单调上升：每 4–6 关给一个"放松关"。度量上盯两个量：**胜率（≈是否在心流带）** 和 **时间到放弃/通关（是否还有乐趣）**。

---

## 3. 机制 / 障碍的引入顺序与节奏："新元素 → 教学关"

**引入哲学（来自 King 设计师，Gamedeveloper.com）**

- CCS 关卡是 **2–4 分钟的"小份量"体验**，让玩家"不用太费脑就能放松"。
- 设计师 Philip Lanik："关卡必须是个挑战、并保持是挑战"，但"老玩同样的内容会很无聊" —— 所以**靠不断引入新机制来制造新鲜感（rhythm）**。
- 资深设计师 Rasmus Eriksson 把整个游戏比作 **"toy box（玩具箱）"**：每个人都能找到适合自己的东西，不管你是硬核解谜爱好者还是"只想看看烟花"的休闲玩家。

**机制按"由简到繁、间隔铺开"引入，且每个新元素首次出现时环境被刻意简化（即教学关）**

经多源交叉，关键障碍/元素的首次引入关号（CCS 经多次重排，故有"非官方首现"与"官方教学引入"两个口径）：

| 元素 / 障碍 | 首次/教学引入关 | 备注 |
|---|---|---|
| 单层糖霜 Frosting / Icing | **Level 2** | 最早的 4 个基础障碍之一 |
| 锁住的糖 Locked Candy | 极早期 | 基础 4 障碍之一 |
| 甘草漩涡 Licorice Swirl | 极早期 | 基础 4 障碍之一 |
| 巧克力 Chocolate（会增殖） | 早期；后重排到 **Level 141**（原 Level 51, Minty Meadow） | 会自我复制，教学关用极简环境演示"必须主动清理" |
| 果酱 Jelly（果冻模式核心） | 早期 | Jelly 模式目标物 |
| 橘子酱 Marmalade | 非官方 **Level 70** / 官方教学 **Level 186** | 包裹住糖，需匹配解锁 |
| 糖果炸弹 Candy Bomb | 早期引入 | 倒计时到 0 则直接 game over，等于额外步数限制 |
| 魔法搅拌机 Magic Mixer / Evil Spawner（增殖型 spawner） | **Level 1326**，**Level 1328** 起可生成炸弹 | 高阶 spawner，越晚越毒 |

**教学手法（"新道具→教学关"机制）**

- **首现关 = 简化环境**：新元素第一次出现时，棋盘其他干扰被刻意削减，让玩家在低压力下理解它的行为（例如巧克力增殖、炸弹倒计时）。
- **提示气泡 / 文字 tutorial**：早期关有手把手提示。
- **用单独一关"介绍"一个机制**，再在随后的关里把它与已学机制**组合加难**。
- King 的 **"flow"** 要素就是干这个的：用 hint（提示手）等机制把玩家引导向目标，确保新手不卡在"看不懂"。

**模式（game mode）的引入也是渐进的**，CCS 的官方模式：

- **Moves（步数/分数关）**（已于 2021 淘汰为独立模式）、**Timed（计时关）**（2018 淘汰，被公认最难的模式）、**Jelly（清果冻）**、**Ingredients（掉落原料/坚果樱桃）**、**Candy Order（按订单收集）**、**Mixed（混合模式）**。
- Mixed（同时满足两个目标，如"清果冻+收订单"）现已是最常见类型（约占 38.67%），但它**被刻意放在很靠后**才大量出现（如 Jelly-Order mixed 早期首现于 Level 3807） —— 即**最复杂的目标组合留到玩家已熟练后**。

> **对 Polaris 的启示**：每一个新 gem 类型 / 新障碍 / 新目标，都配一关"几乎纯净"的教学关（弱化其他变量），让玩家**先单独吃透一个变量**；下一关再把它和旧机制组合。机制引入要"由简到繁、拉开间隔、先教后考"。最复杂的"混合目标"留到中后段。

---

## 4. 难度墙：臭名昭著的硬关分布规律与造墙手法

**最被反复提及的"墙"**

- **Level 65**（传奇之墙）：设计师 Tobias Nyblom 亲述，它是"第二次更新的最后一关"，**被刻意做成版本末挑战**；初版甚至比现在更难，后来移除了玩家觉得不公平的"分数要求"，但难度传奇保留至今。造难手法 = **凶狠的巧克力 + 甘草障碍组合**。Nyblom 自嘲上线前最后调参时"自己测试通关可能是运气异常好"。
- 资深设计师 Eriksson 点名的标志性硬关：**Level 31、62、109、190、360、1945、5359**。
- 学术数据分析（DataCamp 项目，基于真实 King 数据集）发现：**Level 8 和 15 是数据上最硬的**（平均 >20 次尝试才过，胜率仅 0.04 / 0.03；其余关 ≤10 次尝试）；Level 5、7、9、11、12 胜率也低（约 0.1）。这说明**早期就埋了几道陡墙**用来筛选/激发"再试一次"。

**造墙的设计手法（多源归纳）**

1. **步数极紧（tight move limit）**：步数压到很低，玩家"必须运气好才能凑出匹配"。这是最常用的造难手段。
2. **颜色数拉满**：棋盘上 5–6 种颜色时，糖果更混乱、匹配更难凑、特殊糖更难造。
3. **增殖型障碍（spawner）**：巧克力 / Magic Mixer / 黑巧克力**不停生成、不可一次清完**，尤其放在尴尬位置时；炸弹 spawner 更狠（倒计时炸弹突然爆）。
4. **炸弹倒计时（Candy Bomb）**：等于额外的隐形步数限制，逼玩家分心去拆弹。
5. **目标本身难造**：Candy Order 关里**某些订单无法靠普通匹配直接产出**（必须先造特殊糖再组合）；Timed 关被公认最难。
6. **运气依赖（randomness）**：低步数 + 随机棋盘 = 同一关有时几步过、有时怎么都过不了 —— 这种**方差本身就是"墙感"和"再试一次"的来源**。
7. **awkward 棋盘形状**：故意把棋盘做成复杂、割裂、通道狭窄的形状，让重力掉落和匹配都别扭。

**分布规律**

- **墙倾向于落在 episode 末 / 版本更新末**（Level 65 是教科书案例：版本末锚点）。
- 现代规则（2022-03-23 后）：**每个 episode 可以有 1 个 nightmarishly hard、1 个 super hard、两者都有、或都没有** —— 即**高难关被有节律地"撒"进章节**，而不是堆在一起。这正是锯齿曲线在 episode 粒度上的实现：每章一两个尖峰，其余是缓坡和回落。

> **对 Polaris 的启示**：墙要"稀疏而规律"地撒，且优先放段末。造墙优先用"步数紧 + 增殖障碍 + 目标难造"的**组合**，而不是单纯堆障碍。但务必用胜率脚本盯住 —— **墙的胜率别低到玩家成片流失**（见第 5、7 节的"既要墙、又要不赶人"平衡）。

---

## 5. 留存与变现：失败被刻意设计成留存/变现杠杆吗？—— 是，但 King 的官方立场更克制

**生命（lives）系统 —— 把"失败"转成"回访冲动"的引擎**

- 5 条命，每失败一关扣 1 条，**每 30 分钟回复 1 条**；可向好友要命、或付费补满。
- 这套被 Yu-kai Chou 命名为 **"Fixed Interval Torture（固定间隔折磨）"**（Octalysis Core Drive 6 稀缺性）：把"失败"立刻转成"等待 / 拉好友 / 付费"三选一，制造"想玩却不能玩"的强烈回访冲动。
- 它同时**控制单次时长、制造天然的再触达节点** —— 把"用完命的挫败"转成"等回血的期待"，反而**提高了总体投入、降低了倦怠**。

**失败 = 变现窗口**

- King 用大数据分析**玩家最可能付费的时刻** —— 典型就是**在某关连续失败多次之后** —— 在那个点推 boosters / 续命 / 加步数。
- 触发心理：**loss aversion（损失厌恶）** + **"just one more try（再试一次）"** + **sunk cost（沉没成本）**。
- 第三方"dark pattern"分析（UXP2）更尖锐地指出一种机制：**游戏会偶尔给"接近不可能"的关**逼玩家买道具/续命；而**如果玩家始终不付费，难度会被悄悄下调以保住可玩性/留存** —— 即一种动态难度调节，对付费者卡墙、对白嫖者放水。（注：这是批评性来源的解读，King 官方从未承认"故意做不可能的关"。）

**随机性如何服务"再试一次的希望"**

- 随机棋盘 + 特殊糖 = **variable reward（可变奖励）**（Octalysis Core Drive 7 不可预测性），每次开局都"这把说不定能成"，触发多巴胺。
- 低步数下的高方差让"差一点就过"（near-miss）频繁发生，near-miss 是最强的"再来一次"驱动之一。

**但 King 官方的立场比"纯变现墙"更克制、更以乐趣为本（重要平衡）**

- King 把 **难度（difficulty）和乐趣（fun）刻意拆开度量**。Jan Wedekind："难度和乐趣天生纠缠……你必须想办法把乐趣从难度里剥离出来。" —— **高流失可能只是因为难，不代表关不好玩**；反之，**简单关流失低，也可能根本不好玩。**
- 度量两把尺：**Time to Pass（通关耗时）** 和 **Time to Abandon（放弃耗时，代表内在动机/投入）**。
- King 会**主动找出"最不好玩的 100 关"系统性修复/删除**，结果是"投入显著提升、玩家留存时间大幅变长"。设计师 Lanik 也承认"我们确实在某些关流失玩家"，但坚持"乐趣关与挑战关的好混搭非常重要"。
- 关键经验法则：**"关卡越长，越不可能好玩"** —— 所以**硬关要短**，长关要格外小心。
- A/B 测试结论很有指导性：**调高难度短期内提升了付费转化，但把关卡调容易反而长期留住了更多玩家**。即"难"是双刃剑：短期变现 vs 长期留存。
- 玩家自己拒绝"跳关"：King 想给卡住的玩家加"skip"功能，但玩家反馈认为**跳关 = 作弊** —— 说明**"靠自己打过去"的成就感本身就是留存**，而不是单纯的折磨。

> **对 Polaris 的启示（这条直接命中你的命题"关卡设计本身带来留存"）**：留存不是靠"做不可能的墙逼付费"，而是靠**把难度和乐趣分开度量**，确保**难关也好玩**（短、有解、有"差一点"的希望）。命系统/等待把失败转成回访节点；随机性提供"再试一次"的希望；但真正的长期留存来自"靠自己打过去的成就感 + 锯齿心流 + 持续的新机制新鲜感"。**A/B 教训：别用难度榨短期付费，会赶走长期玩家。**

---

## 6. 具体关卡剖析：为什么这些设计有效

1. **Level 65（版本末之墙，最经典案例）**
   - 设计意图：**作为版本/更新末的"封关挑战"**，在内容空窗期把玩家留住、制造期待。
   - 手法：**巧克力（增殖）+ 甘草障碍组合** + 当年偏高的分数门槛。
   - 为何有效：它制造了**全球性的"卡 65"集体记忆**和社交话题（设计师本人被陌生人求助十几次），**把一道难关变成了游戏的文化符号和病毒传播点**。后来移除不公平的分数要求、整体调易，说明 King 在"保留传奇/难度感"与"不让玩家觉得不公平"之间反复打磨。**教训：墙可以难，但不能"不公平地难"。**

2. **Level 31（特殊糖教学型硬关）**
   - 设计意图：在早期就**逼玩家学会"造并组合特殊糖"**这一核心高阶技能。
   - 手法：目标要求玩家组合 booster 制造爆炸。
   - 为何有效：它是一道**"技能门槛关"** —— 打过它的人，就掌握了后续所有关都要用的特殊糖组合，**用一道墙完成了一次强制教学**。

3. **Level 62（cascade / 连锁教学）**
   - Eriksson 原话："如果你学会制造大量特殊糖 —— 我们叫 cascade（连锁）—— 这关就能'自己玩一会儿'。"
   - 为何有效：它教玩家**"创造局面让棋盘自动连锁"**的爽感，把"难"转化为"学会一个技巧后突然变简单"的顿悟时刻 —— **这种"卡住→开窍→碾压"的弧线本身就是留存。**

4. **Level 8 / 15（数据上的早期陡墙）**
   - 数据：平均 >20 次尝试、胜率 0.03–0.04，远超其他早期关。
   - 为何（在留存意义上）有效：早期就放陡墙，**筛选并强化"再试一次"行为模式**；数据还显示 Level 15 玩家数异常多（3374），推测**通关后的社交分享带来回流** —— 一道早期墙同时充当了"留存训练器"和"社交传播点"。

5. **Level 360 / 5359（高阶 spawner / blocker 管理）**
   - Eriksson 的通关哲学："**永远优先清掉巧克力、magic mixer、黑巧克力这些会增殖/生长的东西**"（360）；"**尽可能多地清掉棋盘，会让后半段轻松很多**"（5359）。
   - 为何有效：这些关把"**优先级管理 / 先控场再推进**"做成核心解法，**奖励有策略的玩家**（toy box 里给硬核玩家的那一格），而休闲玩家靠多试几次 + 道具也能过 —— **同一关服务不同技能层级的玩家**。

> **对 Polaris 的启示**：好硬关有"**学会一个技巧后豁然开朗**"的结构（62 的 cascade、31 的特殊糖），而不是纯随机折磨。墙要么是"技能门槛关"（强制教学），要么是"版本末锚点"（留存/传播），且都要**可被策略破解**而非纯靠运气。

---

## 7. 权威设计原理：King 设计师 / GDC 怎么说"CCS 关卡是怎么设计的"

**A. King 的四大设计要素（GDC Europe 2016，Jeremy Kang，"Finding the Fun"）**

King 把关卡设计拆成四个概念：

1. **Difficulty（难度）**：贯穿整个进程持续给挑战。
2. **Rhythm（节奏）**：变化体验以维持投入 —— **这就是锯齿曲线/软硬交替/模式交替的官方说法**。
3. **Flow（引导）**：用 hint 等机制把玩家引向目标（确保不卡在"看不懂"）。
4. **Hooks（钩子）**：每关引入一个新花样/twist 制造独特性。

**B. "4 个 T" 的制作流程（同一 GDC 演讲）**

**Theory（理论）→ Thought（构思）→ Tools（工具）→ Testing（测试）**。具体流水线：**level concept（概念）→ layout（布局）→ creation（搭建）→ balancing（平衡）→ testing（测试）→ release**。先在**纸上手绘概念**，再进数字编辑器、再 playtest。

**C. "魔法 + 数据"的双手（核心方法论）**

- Kang 名言：好的关卡设计师需要 **"魔术师的直觉（magical gut）" + 数学/数据分析能力** 两套本事兼备。
- 因为**设计师对难度的感知经常和真实玩家偏差很大** —— "设计师总觉得这关会很赞，但大多数时候并不是。"所以**直觉必须被数据校正**。
- 现状（MobileGamer.biz 2023）：**几乎每一关 CCS 关卡现在都借助 AI 创建** —— 用 AI 在上线前**预测试**关卡难度、理解玩家、做个性化。King 也在 GDC 专门讲过《How King Uses AI in Candy Crush》。

**D. "好关卡"的定义与"剪枝"机制（MobileGamer.biz，King 的 Wedekind / Guardiola）**

- 把**乐趣从难度中剥离**度量（见第 5 节）。
- 两把尺：**Time to Pass** 和 **Time to Abandon**。
- 用 wins/losses/attempts **给玩家技能分层画像**（"几周到几个月就能可靠刻画玩家技能"），再把难度映射到真实玩家体验上。
- **"关卡越长越不可能好玩"**；**硬关要短**。
- **持续剪枝**：系统性找出最差的 100 关修复/重做，换来留存大涨。
- 改一关要看"**对整条进程的涟漪效应（ripple effect）**" —— 关卡不是孤立的，是进程曲线上的一个点。

**E. 数据驱动平衡（贯穿所有来源）**

- 难度评级由**后台脚本按胜率自动判定**，不靠人手。
- 上线后持续用真实数据**重新平衡甚至重做**关卡。
- A/B 测试反复验证"难度 vs 留存 vs 付费"的取舍（难→短期付费↑，易→长期留存↑）。

---

## 对 Polaris（你的关卡生成系统）的 10 条可执行启示

1. **分段即留存装置**：把长流程切成命名 + 主题 + 段末挑战关的"章节"，段末放记忆点/社交钩子/回访锚点。
2. **难度评级用胜率脚本自动判定**，不要人手标 Easy/Hard；持续用线上数据重判、重做。
3. **曲线做成锯齿**：每 4–6 关给一个回落"放松关"，把玩家保持在心流带；用 rhythm（软硬交替 + 模式交替 + 长短交替）维持新鲜感。
4. **拆开度量"难度"与"乐趣"**：盯两把尺 —— 胜率（≈难度/心流）和"放弃耗时/通关耗时"（≈乐趣/投入）。高流失先判断是"太难"还是"不好玩"。
5. **每个新机制配一关"纯净教学关"**：先单独教一个变量，下一关再组合加难；最复杂的混合目标留到中后段。
6. **造墙用组合而非堆障碍**：步数紧 + 增殖障碍 + 目标难造，且**可被策略破解**（"卡住→开窍→碾压"的弧线）；墙要稀疏、规律、优先放段末。
7. **硬关要短**；"关卡越长越不可能好玩"。
8. **失败→回访/变现的转化要克制**：命系统 + 等待把失败转成回访节点，随机性提供"再试一次"的希望，但**别用不公平的墙榨短期付费**（A/B 教训：会赶走长期玩家）。真正的留存来自"靠自己打过去的成就感"。
9. **持续剪枝**：定期找出"最不好玩的 N 关"修复/删除；改一关要评估对整条进程曲线的涟漪效应。
10. **魔法 + 数据 + AI 预测试**：设计师直觉出概念，数据/AI 在上线前预测难度、上线后校正 —— 这正契合你"边对话边编码 + 程序化量化自检"的工作方式。

---

## 来源（Sources）

- [Difficulty — Candy Crush Saga Wiki (Fandom)](https://candycrush.fandom.com/wiki/Difficulty)
- [Hard levels — Candy Crush Saga Wiki](https://candycrush.fandom.com/wiki/Hard_levels)
- [Category: Nightmarishly hard levels — Fandom](https://candycrush.fandom.com/wiki/Category:Nightmarishly_hard_levels)
- [Category: Super hard levels — Fandom](https://candycrush.fandom.com/wiki/Category:Super_hard_levels)
- [Criteria for Hard, Super Hard, and Nightmarishly Hard levels — King Community](https://community.king.com/en/candy-crush-saga/discussion/360672/%EF%B8%8F-criteria-for-hard-super-hard-and-nightmarishly-hard-levels)
- [Level — Candy Crush Saga Wiki](https://candycrush.fandom.com/wiki/Level) ；[Episode — Fandom](https://candycrush.fandom.com/wiki/Episode) ；[Ticket — Fandom](https://candycrush.fandom.com/wiki/Ticket) ；[Lives — Fandom](https://candycrush.fandom.com/wiki/Lives)
- [Mixed Mode levels — Fandom](https://candycrush.fandom.com/wiki/Mixed_Mode_levels) ；[Chocolate — Fandom](https://candycrush.fandom.com/wiki/Chocolate) ；[Marmalade — Fandom](https://candycrush.fandom.com/wiki/Marmalade) ；[Magic Mixer — Fandom](https://candycrush.fandom.com/wiki/Magic_Mixer)
- [Why is level 65 in Candy Crush so hard? — Apple App Store Story（设计师 Tobias Nyblom 专访）](https://apps.apple.com/us/story/id1297938529)
- [Secrets to beating Candy Crush's hardest levels — straight from the game's designer（Rasmus Eriksson 专访，Yahoo）](https://www.yahoo.com/lifestyle/candy-crush-saga-cheat-sheet-114244835.html)
- [Video: King's guide to level design for casual games（Jeremy Kang GDC，Gamedeveloper.com）](https://www.gamedeveloper.com/design/video-king-s-guide-to-level-design-for-casual-games)
- [How King uses magic and data to find the fun in Candy Crush — PocketGamer.biz](https://www.pocketgamer.biz/news/63745/king-on-finding-the-fun-in-candy-crush/)
- [How King defines a 'good' Candy Crush level — and why it constantly prunes the bad ones — MobileGamer.biz](https://mobilegamer.biz/how-king-defines-a-good-candy-crush-saga-level-and-why-it-constantly-prunes-the-bad-ones/)
- [How King balances human and AI-powered design in Candy Crush Saga — MobileGamer.biz](https://mobilegamer.biz/how-king-balances-human-and-ai-powered-design-in-candy-crush-saga/)
- [GDC Vault: How King Uses AI in Candy Crush](https://gdcvault.com/play/1023858/How-King-Uses-AI-in)
- [The processes behind King's Candy Crush — Gamedeveloper.com](https://www.gamedeveloper.com/design/the-processes-behind-king-s-i-candy-crush-i-)
- [Why Is Candy Crush So Addicting? — Yu-kai Chou Octalysis 分析](https://yukaichou.com/gamification-study/game-mechanics-research-candy-crush-addicting/)
- [Candy Crush Saga: Impossible Levels — UXP2 Dark Patterns](https://darkpatterns.uxp2.com/pattern/candy-crush-saga-impossible-levels/)
- [Level Difficulty in Candy Crush Saga（DataCamp 数据科学项目，含胜率/尝试次数）— Medium](https://medium.com/@boyangchen02/level-difficulty-in-candy-crush-saga-datacamp-data-science-project-28b979c402d7) ；[RPubs 版](https://rpubs.com/Sergio_Garcia/candy_crush_saga)
- [Candy Crush Saga: The Game That Made Waiting Fun Again（命系统案例）— Medium](https://medium.com/@chinwe.lucyy/case-study-candy-crush-saga-the-game-that-made-waiting-fun-again-b711a615955d) ；[Candy Crush Saga: A Sweet Journey into Monetization — Gamedeveloper.com](https://www.gamedeveloper.com/design/candy-crush-saga-a-sweet-journey-into-monetization)

---

## 说明 / 局限

Fandom、TV Tropes、Apple Store（部分地区 URL）、King 官方游戏模式页在本次抓取中对自动 WebFetch 返回 403/404，故这些来源的内容以多次 WebSearch 的结构化摘要交叉印证为主（同一事实均有 ≥2 来源支撑）。具体关卡（70、97、147、305 等）的逐关步数/障碍配置，公开权威来源较散，最可靠的是设计师亲述的 65/31/62/360/5359 与数据分析的 8/15；若需要逐关精确配置，建议直接抓取对应 Fandom 单关页（需换用可绕过 403 的抓取方式）。
