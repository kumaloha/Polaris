# Candy Crush Saga 机制元素完整研究报告

> 用途：为 gem 消除 match-3 手游的「关卡生成系统」彻底学透 Candy Crush Saga (CCS) 的机制元素。
> 研究方法：Fandom wiki、TV Tropes、官方 Zendesk 帮助页对直接抓取(WebFetch)返回 403，因此本报告通过 WebSearch 提取这些权威源的内容片段，并用可抓取的攻略站(BlueStacks、cheats 站、easygameguide、without-the-sarcasm)做交叉印证。凡多来源一致的结论为高置信度；单一来源或版本敏感的细节会注明。
> 注意：CCS 自 2021 年做过大规模关卡重制，部分早期 blocker(爆米花/太妙龙卷风/神秘糖)已被替换或下线——这对"学机制设计原理"仍有价值，下文会标注。

---

## 块一 · 特殊糖果(Special Candies)

CCS 把特殊糖果分两类：**玩家可生成的**(条纹/包装/颜色炸弹)和**不可玩家生成、只能由关卡机制/道具产出的**(果冻鱼/椰子轮/UFO)。

### 1. 特殊糖果枚举：生成条件 / 单独引爆效果 / 视觉

| 特殊糖果 | 生成条件 | 单独引爆效果 | 视觉表现 |
|---|---|---|---|
| **条纹糖 Striped Candy** | 同色 **4 连**直线消除。**横排 4 连 → 生成竖条纹(清列)**，**竖排 4 连 → 生成横条纹(清行)**（条纹方向与你消除的方向相同，引爆方向与条纹纹理垂直） | 清除其所在的**整行或整列**（取决于条纹朝向）。横条纹清一整行，竖条纹清一整列 | 糖果表面带平行白色条纹；条纹横/竖标示其引爆轴 |
| **包装糖 Wrapped Candy** | 同色 **5 连 L 形或 T 形**消除（两条线交叉，产生一个拐角） | 像炸弹一样**两次爆炸**：先炸自身周围 **3×3 = 8 格**，糖果下落后**再爆一次**周围 3×3。一个包装糖实际清两波 | 糖果被一层彩色"糖纸"裹住，方块状外观 |
| **颜色炸弹 Color Bomb（官方拼写 Colour Bomb）** | 同色 **5 连直线**消除（横或竖一条直线 5 个） | 与任意糖果交换时，**清除全盘所有与被交换糖果同色的糖果**。若是被动引爆(被其他特效波及)，则自动选取**当前盘面数量最多的颜色**来清除 | 黑色/深色球体，表面布满彩色巧克力豆斑点(sprinkles)，不带任何单一颜色 |
| **果冻鱼 Jelly Fish** | **玩家无法直接生成**。来自糖果炮(Candy Cannon，level 39 起可吐鱼)或对应道具/booster。后期(level 5352)有专门的果冻鱼分发器 | 触发后**数条鱼游出**，每条游向并吃掉一个**随机的关卡目标格**(通常是果冻 jelly、订单糖等)；若盘面目标少于 3 个，则只游出 1~2 条吃随机糖 | 彩色小鱼形糖果，激活时鱼"游"过棋盘 |
| **椰子轮 Coconut Wheel** | **玩家无法生成**，只出现在**运料(ingredients)类关卡**，由机制投放 | 激活后旋转，把**紧邻它的 3 个糖果变成条纹糖并立即引爆**；本身可沿移动方向滚动并持续转化路径上的糖 | 椰子/车轮造型，会滚动 |
| **UFO** | 关卡机制产出(非玩家生成) | 与一个糖果交换 → 该糖果被移除，并从 UFO 与该糖所占的两格各**移除一层果冻 jelly**。**UFO + 包装糖**：UFO 生成 **3 个包装糖**，这些包装糖不仅做 3×3 爆炸，还会清掉它们所在行/列的糖 | 飞碟造型 |

补充要点(高置信度，多源一致)：
- 颜色炸弹**单独**其实是"弱"特效，因为生成难(要 5 连)，但一旦与别的特效组合，威力指数级放大——这是 CCS 的核心设计张力。
- 条纹方向规则在关卡设计里很重要：**你怎么消，就决定生成什么朝向的条纹**，高玩借此预先布局清行还是清列。

---

### 2. ⭐ 特殊糖果组合矩阵(最关键)

把两个特殊糖果**交换到相邻位置**触发"组合(combo)"，效果远强于各自单独引爆。下表逐对列全。

| 组合 | 具体效果 | 爽感 / 威力定位 |
|---|---|---|
| **条纹 + 条纹** | 在交点同时清除**一整行 + 一整列**，形成一个"十字/加号(+)"。两条线从交汇点向四方铺开（一个清列、一个清行） | 入门级爽感。可清整盘约一行一列；但**清不掉甘草(licorice)等抗性 blocker** |
| **条纹 + 包装** | 形成**加宽十字**：沿行、沿列各清除，但**每个方向的爆破带宽 3 格**（即清 **3 行 + 3 列**，"3 格宽的十字"）。比条纹+条纹大约**大 3 倍** | 高爽感、性价比极高，是最实用的中等组合之一 |
| **条纹 + 颜色炸弹** | 颜色炸弹引爆，把**全盘所有"与那颗条纹糖同色"的糖果统统变成条纹糖**（朝向随机），然后这些条纹糖**逐一连续引爆**，制造大量随机的行/列爆破 | 极强。若盘面该色糖很多，可清掉大半个棋盘；视觉上"连环条纹炸"非常爽 |
| **包装 + 包装** | 以两颗包装糖为中心，各向外清除**2 格见方的范围**（即每颗波及周围 **5×5 区域**、约 16 个相邻格），并随糖果下落产生额外爆炸 | 大范围团块清除，覆盖面比条纹组合更"实心"，适合清成片果冻/糖霜 |
| **包装 + 颜色炸弹** | 颜色炸弹引爆，把**全盘所有"与那颗包装糖同色"的糖果变成包装糖并全部引爆**（一连串 3×3 爆炸），等效"该色全员包装爆"。（另有来源把它近似描述为"两次独立颜色炸弹效果，其中第二次是随机色"——这是旧版/简化说法，**现行版本以"全色转包装糖连环爆"为准**） | 顶级 AOE。常常一步清关，是公认最暴力的组合之一 |
| **颜色炸弹 + 颜色炸弹** | **清空整个棋盘**——所有糖果(及多数可被清除的元素)被一次性引爆 | 最强组合。地图级清场，但因两个颜色炸弹都极难凑出而罕见 |
| **颜色炸弹 + 普通糖**（颜色炸弹的常规用法，本质也是一种交换） | 清除**全盘所有与被交换普通糖同色**的糖果 | 基础但可靠的"减色"手段，常用于把盘面砍到只剩少数颜色，再为更大组合铺路 |
| **果冻鱼 + 条纹/包装/颜色炸弹** | 鱼的数量/威力被放大：组合后游出**更多鱼**，且每条鱼到达目标处会触发对应特效（条纹→落点清行/列；包装→落点 3×3 爆；颜色炸弹→更激进地点名目标）。鱼优先扑向**关卡目标格**(果冻/订单) | 精准制导型清除，对"指定目标"类关卡极有用 |
| **果冻鱼 + 果冻鱼** | 游出**更多鱼**、覆盖更多随机目标 | 中等，偏目标清除而非范围爆破 |
| **UFO + 包装糖** | UFO 生成 **3 个包装糖**，每个不仅 3×3 爆，还**额外清掉所在行/列** | 复合爆破，UFO 专属彩蛋组合 |

#### 矩阵设计原理(给关卡生成系统的洞察)
- **三种可生成特效 × 三种 = 6 个核心有序对(去重后 6 种)**，构成一张"可控难度旋钮"。设计关卡时，blocker 的布置与"玩家能否凑出某组合"直接挂钩——例如把目标埋在角落，逼玩家追求"条纹+包装"的宽十字。
- 组合的**爽感梯度**是刻意设计的：条纹+条纹(小) → 条纹+包装/包装+包装(中) → 颜色炸弹系(大) → 双颜色炸弹(清场)。这条梯度同时是**稀有度梯度**(越强越难凑)，构成正反馈奖励曲线。
- **抗性机制**：甘草漩涡、糖霜等对某些特效有抵抗（如条纹组合清不掉甘草），让"组合不是万能钥匙"，是关卡保持挑战的关键。

---

## 块二 · 障碍(Blockers)

CCS 官方把 blocker 定义为"阻止玩家触及/移动糖果的次级棋盘元素"。按行为分**静态(static)**(只占位、需多击清除)与**动态(dynamic)**(扩散/生成/倒计时/移动)。

### 静态 / 多层击破类

| Blocker | 机制(如何清除/几击) | 静/动态 | 设计原理(它出什么"题") | 引入阶段 |
|---|---|---|---|---|
| **果冻 Jelly(单层/双层)** | 不是阻挡物而是**目标层**：在其上方做一次消除清掉一层。**单层 jelly** 一次消除即清；**双层 jelly** 需在该格上方**消除两次**。鱼/特效也能削层 | 静态 | CCS 最基础的"覆盖式目标"——"清光所有果冻"作为通关条件，迫使玩家**控制消除落点**而非乱消 | jelly 关是最早的核心关型；**double jelly 约 level 9 起**（2021 重制后 level 6 已从 jelly 关改为订单关） |
| **糖霜 / 糖衣 Icing(官方名 Regular Icing；旧称 meringue/frosting/whipped cream)** | **相邻消除或被特效命中**削一层。**多层糖霜 Multilayered Frosting** 需多次命中（逐步上到 **5 层**）。注意：糖霜**不会自己下落**，下方糖被清也不掉落 | 静态 | 最常见、最"温和"的占位 blocker——把棋盘**切割**成区域，限制糖果连通与下落路径，制造"先打通通道"的题 | **多层糖霜约 level 9** 首次出现；5 层版从 Peppermint Palace 到 Candy Clouds 区间引入 |
| **甘草漩涡 Liquorice Swirl(Licorice Swirl / Liquorice Wheels)** | **相邻消除或特效命中一次即清**。但它**对部分特殊糖果有抗性**(不像普通糖那样被随意波及)，且**会随棋盘下落**(占据糖果列、跟着掉) | 半动态(本身随重力下落，但不主动扩散) | 最常见的甘草类阻挡。**占据一个糖位但不能被匹配**，污染消除布局；下落特性让它在棋盘里"流动捣乱" | 第 4 章 Chocolate Mountains，**约 level 36** 首次作为新元素 |
| **甘草锁 Liquorice Lock(Liquorice X / Licorice Lock)** | 锁住**一个糖果**，使其**不能移动、不能被相邻消除、不能下落**。需**用锁内的糖和另外 2 个同色糖凑成一次消除**(即正常匹配锁里的糖)，或用**特效**打破锁 | 静态 | 把一个关键糖/特效/炸弹"冻结"在原地，制造"必须先解锁才能用"的题；常和炸弹/订单叠加 | 早期即引入(与早期甘草元素同期) |
| **果酱 Marmalade** | 把**一个糖果或特殊糖果**包在果酱里：被包的糖**不能移动**，但**可以参与匹配**或被特效命中来剥掉果酱。剥掉后里面的糖(常是特殊糖/炸弹)被释放 | 静态 | "frosting + lock 的混合体"。常用来**把一个已生成的特殊糖果或炸弹封住**，逼玩家先解封再利用——既是阻挡也是"延迟奖励" | **约 level 186**(Marmalade Mirage 章 186–200)正式作为主元素引入 |
| **太妃糖蛋糕炸弹 / 蛋糕炸弹 Cake Bomb** | **2×2 不可通行块**，分 4 象限、共 **8 段**。相邻消除或特效打入 → 毁掉 1–2 段；**8 段全毁 → 整块爆炸，清空全盘所有糖果，并给所有 blocker 削一层**。是**击破次数最多**的 blocker | 静态(爆炸时全图效果) | "蓄力清场装置"——它是个**正向**的大障碍：清掉它代价高，但回报是全盘清扫。制造"持续敲它 vs 先打别处"的取舍题 | 较后期，**约 level 366** 首次出现 |
| **华夫饼 Waffle (Waffle Cookie，主要在 Friends Saga；CCS 部分关也有同类多层饼)** | **匹配/特效/颜色炸弹**逐层清除，最多 **5 层** | 静态 | 高血量占位块，纯粹拉长清理时间、压缩步数预算 | 中后期 |
| **糖果宝箱 / 糖箱 Sugar Chest** | 锁住内含物(糖/钥匙/目标)的箱子，需**多次命中**打开(有多层版，如五层糖箱属高难)；常与**糖钥匙 Sugar Key**配对——钥匙触发后开箱 | 静态(多层) | "钥匙—锁"配对玩法：把目标藏进箱，逼玩家先拿钥匙/敲箱，制造**两步依赖**的题 | 后期高难元素(五层糖箱属"最难 blocker"之列) |
| **甘草壳 / 爆米花 Licorice Shell(取代了旧的 Popcorn)** | **吸收**条纹糖、条纹/包装组合的冲击(挡特效)；需多次普通消除/特效逐层敲破 | 静态 | "特效海绵"——专门**削弱玩家的特效输出**，逼玩家用普通消除硬啃，是反"一招通关"的设计。**旧版爆米花 Popcorn** 行为类似(还曾免疫蛋糕炸弹、且鱼不靠近)，后被甘草壳替代 | 爆米花为早/中期旧元素，现以甘草壳形式存在 |

### 动态 / 扩散 · 生成 · 倒计时 · 移动类

| Blocker | 机制 | 动态行为 | 设计原理 | 引入阶段 |
|---|---|---|---|---|
| **巧克力 Chocolate** | **每回合(没清掉巧克力的那一步)增殖一格**，向相邻空格/糖位蔓延。**相邻做一次消除**可清掉接触到的巧克力(且当回合不再增殖) | **扩散**(dynamic) | 经典"时间压力"机制：你**每一步都必须分心压制它**，否则它吞噬棋盘。制造"清目标 vs 控巧克力"的双线管理题 | 早期(**约 level 9 区段**起作为主障碍；后期 level 147 起还能成为订单目标) |
| **巧克力喷泉 / 生成器 Chocolate Fountain(及黑巧克力喷泉)** | **永远无法被永久清除**：即便把盘面巧克力全清光，它**每做一次"非巧克力"消除就再吐一块新巧克力**。本体不可破坏 | **生成器**(spawner) | 把"控巧克力"变成**永不停歇的持续压力**——玩家无法一劳永逸，只能边压边推进目标。是 CCS 最臭名昭著的难点之一 | **约 level 156** 起 |
| **炸弹 / 糖果炸弹 Candy Bomb(Bomb)** | 糖果上印有**倒计时数字 = 剩余步数**。把它包含进一次消除即**拆除**；若数字归零仍未拆 → **该炸弹爆炸 = 立即失败(整局判负)**。同一关里炸弹的初始步数是**固定值** | **倒计时**(dynamic) | 最纯粹的"硬时限"：在步数/目标之外再压一条**必须优先处理**的支线，强行打乱玩家的最优清除顺序 | **约 level 97** 引入(level 97 教学炸弹会进一步压缩步数)；**level 98** 首次出现被果酱/甘草锁封住的炸弹。道具 "Bomb Cooler" 在 level 97 解锁，可给全盘炸弹 +5 步 |
| **糖果炮 Candy Cannon** | 棋盘边缘的**发射器**：当其正下方糖果被清除后，就**吐出新元素**到棋盘——可吐运料(ingredients)、甘草漩涡、糖钥匙、**糖果炸弹**、神秘糖、**果冻鱼(level 39 起)**、**颜色炸弹(level 85 起)**，甚至后期(2346/4946/5352)吐条纹/包装/颜色炸弹/果冻鱼 | **生成器**(spawner，定向投放) | 关卡的"补给/威胁源"：既能持续投放玩家**需要护送的运料**，也能持续投放**新威胁(炸弹)**。让棋盘成为"流水线"，制造源源不断的输入 | 糖果炮本身较早；不同产出物按上述各自级别解锁 |
| **魔法搅拌器 Magic Mixer** | 几回合后**向相邻格生成 blocker**(巧克力或糖霜等)。相邻消除/特效命中会让它**掉螺丝(受损)并延迟 1 步**再生成；其下方还可藏果冻 | **生成器**(spawner) | "巧克力喷泉的可压制版"——**周期性制造新障碍**，但玩家可通过持续骚扰来拖延它，制造"压制节奏管理"的题 | **约 level 1326** 起(很后期) |
| **传送带 Conveyor Belt** | 整条带子上的糖果**每走一步就沿固定方向(横或竖)平移一格**，到边缘**循环/绕回**。糖果位置不断变化 | **移动**(dynamic) | 彻底改变"位置稳定"的前提：你计划的匹配下一步就被传走，必须**预判平移后的布局**。常和运料结合("把料运到出口") | 中期 |
| **太妃龙卷风 Toffee Tornado** | **每回合随机跳到新格**，**不能被匹配**；离开后会在原格留下"裂缝"，使糖果**1 回合内无法落入**该格。落在 blocker 上会**削其一层**(但**不清果冻**)。无法被永久清除，但**可用特殊糖果使其失能约 5 回合** | **移动 + 破坏**(dynamic) | 随机捣乱源：制造**不可预测性**，打乱玩家的精确规划，是高方差难度元素 | 旧元素，**2015 年底(Hoax Hollow 之后)从常规关移除**，2016 年活动中偶现后彻底下线 |
| **神秘糖 Mystery Candy** | 被消除/触发时**随机变成**另一种东西(普通糖、特殊糖、blocker、运料等) | **随机生成**(dynamic) | 随机性奖励/惩罚，制造"开盲盒"的变数 | 第 17 章 Chocolate Barn，**约 level 231** 引入；**2021 年 4 月已从所有关卡移除** |
| **UFO**(也归为 blocker/特殊互动元素) | 见块一：交换可移除一层果冻；UFO+包装糖生成 3 个增强包装糖 | 半动态 | 既是障碍也是工具的双面元素 | 中后期 |

---

## 给"关卡生成系统"的设计原理总结

1. **目标 vs 阻挡的二分**：CCS 的关卡 = 一组**目标元素**(果冻、运料护送、订单、清炸弹) + 一组**阻挡元素**(blocker)。难度来自"目标被 blocker 包裹/隔离"的程度，而非单纯消除数量。

2. **静态 blocker 调"空间"，动态 blocker 调"时间"**：
   - 静态(糖霜/甘草/果酱/糖箱/蛋糕炸弹) → 切割棋盘、增加击破次数、制造空间谜题。
   - 动态(巧克力/喷泉/炸弹/搅拌器/传送带/龙卷风) → 施加每回合压力、倒计时、随机性，制造时间与节奏谜题。
   - 一个好关卡通常**两类各取一两个叠加**，形成"既要清空间又要抢时间"的张力。

3. **特效组合矩阵是难度的"解法空间"**：blocker 的布置本质是在限制/引导玩家能凑出哪种组合。抗特效的 blocker(甘草壳/甘草漩涡)用来**封堵"一招通关"**，保证组合不是万能钥匙。

4. **引入节奏(教学曲线)**：单层 jelly → 巧克力(level 9 区) → 甘草(36) → 炸弹(97/98) → 果酱(186) → 蛋糕炸弹(366) → 喷泉/搅拌器/糖箱(更后期)。**每引入一个新 blocker，先给一关"纯教学"，再逐步与旧元素叠加**——这是 CCS 关卡生成最值得借鉴的节奏控制。

5. **生成器类(喷泉/搅拌器/糖果炮)= 无限关卡内容源**，让有限棋盘产生持续输入流，是延长关卡张力、制造"管理型"玩法的核心装置。

---

## 来源(已交叉印证)

### 特殊糖果 / 组合矩阵
- [Special Candy — Candy Crush Saga Wiki (Fandom)](https://candycrush.fandom.com/wiki/Special_Candy)
- [Colour Bomb (special candy) — Fandom](https://candycrush.fandom.com/wiki/Colour_Bomb_(special_candy))
- [Jelly Fish (special candy) — Fandom](https://candycrush.fandom.com/wiki/Jelly_Fish_(special_candy))
- [UFO — Candy Crush Saga Wiki (Fandom)](https://candycrush.fandom.com/wiki/UFO)
- [How can I create Special Candies? — 官方 Zendesk](https://candycrush.zendesk.com/hc/en-us/articles/211939685-How-can-I-create-Special-Candies)
- [Learn all about Special Candies! — 官方 Zendesk](https://candycrush.zendesk.com/hc/en-us/articles/360000754697-Learn-all-about-Special-Candies)
- [Learn all about the Color Bomb — 官方 Zendesk](https://candycrush.zendesk.com/hc/en-us/articles/13940218109469-Learn-all-about-the-Color-Bomb)
- [Candy Crush Saga Special Candy Combos — Without the Sarcasm](https://www.withoutthesarcasm.com/posts/candy-crush-saga-special-candy-combos/)
- [Special Candy Combinations — candycrush-cheats.com](https://candycrush-cheats.com/special-candy-combinations/)
- [All the Boosters and Special Candies — BlueStacks](https://www.bluestacks.com/blog/game-guides/candy-crush/ccs-booster-guide-en.html)

### Blockers
- [Blocker — Candy Crush Saga Wiki (Fandom)](https://candycrush.fandom.com/wiki/Blocker)
- [Which Blockers can I find in the game? — 官方 Zendesk](https://candycrush.zendesk.com/hc/en-us/articles/360000754717-Which-Blockers-can-I-find-in-the-game)
- [Liquorice Lock — Fandom](https://candycrush.fandom.com/wiki/Liquorice_Lock)
- [Liquorice Swirl — Fandom](https://candycrush.fandom.com/wiki/Liquorice_Swirl)
- [Marmalade — Fandom](https://candycrush.fandom.com/wiki/Marmalade)
- [Regular Icing — Fandom](https://candycrush.fandom.com/wiki/Regular_Icing)
- [Multilayered Frosting — Fandom](https://candycrush.fandom.com/wiki/Multilayered_Frosting)
- [Chocolate — Fandom](https://candycrush.fandom.com/wiki/Chocolate)
- [Magic Mixer — Fandom](https://candycrush.fandom.com/wiki/Magic_Mixer)
- [What does the Magic Mixer do? — Zendesk](https://candycrush.zendesk.com/hc/en-us/articles/360002011778-What-does-the-Magic-Mixer-do)
- [Candy Bomb — Fandom](https://candycrush.fandom.com/wiki/Candy_Bomb)
- [Candy Cannon — Fandom](https://candycrush.fandom.com/wiki/Candy_Cannon)
- [Cake Bomb — Fandom](https://candycrush.fandom.com/wiki/Cake_Bomb)
- [Toffee Tornado — Fandom](https://candycrush.fandom.com/wiki/Toffee_Tornado)
- [Mystery Candy — Fandom](https://candycrush.fandom.com/wiki/Mystery_Candy)
- [Candy Crush Blockers and Obstacles — candycrush-cheats.com](https://candycrush-cheats.com/blockers/)
- [Blockers — easygameguide](https://candycrushfriends.easygameguide.com/blockers/blockers.html)（含多层 blocker 层数参考）
- [GDC 2020: how King learned from RPGs to create blockers — Pocket Tactics](https://www.pockettactics.com/candy-crush-soda-saga/blockers)

---

## 重要可信度提示
- **组合矩阵**为本报告最稳的部分，6 个核心组合在官方 Zendesk + Fandom + 多攻略站完全一致；"包装+颜色炸弹"存在新旧版描述差异，已在表中注明，以现行"全色转包装连环爆"为准。
- **引入级别(level 数字)** 因 CCS 多次重制会漂移，应视为"阶段参考"而非硬编码：建议把它们当作**教学节奏的相对顺序**(jelly → 巧克力 → 甘草 → 炸弹 → 果酱 → 蛋糕炸弹 → 生成器类)来用。
- **爆米花 Popcorn、太妃龙卷风 Toffee Tornado、神秘糖 Mystery Candy** 是已被替换/下线的历史元素——对学习"机制设计原理"仍有价值，但若要复刻"现行 CCS"则可降低优先级。
