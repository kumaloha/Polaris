# Candy Crush Saga 关卡类型 / 目标模式（Game Modes）深度研究报告

> 研究方法：交叉印证 Candy Crush Saga Fandom Wiki、King 官方 Zendesk 帮助文档、PocketGamer.biz 对 King 设计师的访谈、社区论坛及多个攻略站。下文先讲清一个**关键前提**——"关卡类型"在不同 King 产品里是不同的东西，必须分清，否则会把规则张冠李戴。
>
> 研究目的：为 Polaris 的 gem 消除 match-3 手游设计「关卡生成系统」，把 CCS 的关卡设计彻底学透。

---

## 〇、前提：先分清三套"关卡类型体系"（极其重要）

很多资料（和直觉）会把若干模式混在一起，它们实际上分属**三款不同的游戏**。设计自己的系统时，必须知道每个模式的"原生宿主"，因为同名模式在不同作品里规则不同：

| 游戏 | 原生关卡类型 |
|---|---|
| **Candy Crush Saga（主作，2012）** | Moves / Timed（已废弃）、Clear the Jelly、Bring Down the Ingredients、Candy Order（Collect the Orders）、Mixed Mode、Rainbow Rapids |
| **Candy Crush Soda Saga（2014）** | Soda、Frosting（救小熊）、Honey、Chocolate、Bubble Gum、Bubble、Jam（Spread the Jam 起源于此） |
| **Candy Crush Friends Saga（2018）** | Free the Animals、Free the Octopuses、Dunk the Cookies、Fill the Empty Hearts、Spread the Jam |

所以：
- **"Spread the Jam"** 是 Soda/Friends 的模式（不是主作原生）；
- **"Dunk the Cookie"** 是 Friends 的模式；
- **"Bubblegum Troll"** 严格说是一个**角色/道具（character & booster）**而非关卡目标；
- **"Chocolate Box"** 在主作里**不是一个独立关卡目标类型**（Chocolate 是 Soda 的模式、或主作里的一种障碍/活动元素）。

下面会全部讲到，但会标清归属。本报告**主体聚焦 CCS 主作**（核心研究对象），Soda/Friends 模式作为扩展对照单列。

来源：[Level Types – CCS Wiki](https://candycrush.fandom.com/wiki/Level_Types)、[What are the different game modes? – Soda Saga Zendesk](https://candycrushsoda.zendesk.com/hc/en-us/articles/115000941085-What-are-the-different-game-modes)、[Candy Crush Friends Saga – iMore](https://www.imore.com/candy-crush-friends-saga-everything-you-need-know)

---

## 一、CCS 主作关卡类型全枚举（历史 + 现在）

CCS 官方把关卡类型归为 **7 类**，其中 2 类已绝版：

1. **Moves（达标分数 / Reach the Target Score）** — 已绝版（2021-08-31）
2. **Timed（限时达标分数）** — 已绝版（2018-05-02）
3. **Clear the Jelly（清果冻）** — 现役
4. **Bring Down the Ingredients（运送原料下落）** — 现役
5. **Candy Order / Collect the Orders（收集订单）** — 现役
6. **Mixed Mode（混合模式）** — 现役，占比最大
7. **Rainbow Rapids（彩虹急流 / 接通水路）** — 现役，最新、最稀有

来源：[Level Types – CCS Wiki](https://candycrush.fandom.com/wiki/Level_Types)、[Level – CCS Wiki](https://candycrush.fandom.com/wiki/Level)

---

## 二、逐个关卡类型：规则 + 布局 + 体验 + 设计原理

### 1. Moves（达标分数）—— 已绝版的"祖宗模式"

**精确规则**：给定固定步数，用完步数前达到 1 星目标分数即赢；分数不够则输。纯粹"在有限步数内尽量高分"。

**典型布局**：通常是开阔、少障碍的棋盘——它是第 1 关、教学关的形态，让新手专注理解"三消=得分"这一最基础循环。

**玩家体验**：最轻松、最"刷"的一类。社区公认它是**最简单的关卡类型**。

**设计原理与历史**：它是初代教学骨架，但随着游戏成熟，King 认为它**体验单薄、与现代关卡设计脱节、表现不佳（underperforming）**。2021-07-13 几乎所有剩余 Moves 关被批量改造成其他类型，2021-08-31 最后 25 关被重做，该类型正式绝版。

> 设计教训：**"只看分数"的目标太抽象**——玩家看不到"我在改变棋盘上的什么"，缺乏具象的进度反馈，所以被淘汰。这对做新游戏是核心警示：目标要**可视化、有空间感**。

来源：[Moves levels – CCS Wiki](https://candycrush.fandom.com/wiki/Moves_levels)

### 2. Timed（限时达标分数）—— 最难、最早被砍

**精确规则**：在倒计时内达到目标分数。无步数限制，但有时间压力；棋盘上常有"+5 秒糖果"延长时间。

**典型布局**：强调快速连消的开阔棋盘。

**玩家体验**：紧张、肾上腺素型。被社区列为**主观最难**的类型之一（手速 + 运气双重压力）。

**设计原理与移除原因**：因**大量负面反馈**被砍，2018-05-02 移除最后的限时关；Flash 停服后旧版本才残留。多次"恢复 Timed"的社区提议都被否决。

> 设计教训：**时间压力与休闲三消的"放松、可暂停思考"内核冲突**。手游用户在地铁、碎片时间玩，限时会逼他们"不能停下来想"，反而制造焦虑而非乐趣。**休闲消除的本质是"低压力的脑力满足"，限时破坏了这一点。**

来源：[Timed levels – CCS Wiki](https://candycrush.fandom.com/wiki/Timed_levels)、[Redesigning – CCS Wiki](https://candycrush.fandom.com/wiki/Redesigning)

### 3. Clear the Jelly（清果冻）—— 最经典、最有"空间策略"的模式

**精确规则**：棋盘部分格子被一层（单层）或两层（**double jelly**，白色，需消两次）果冻覆盖。在覆盖果冻的格子上方完成消除即清除该处果冻；**清光全部果冻**即赢，且要在步数内同时达最低分。Double jelly 从第 9 关引入，是大多数果冻关的常态。

**典型布局**：果冻常被刻意放在**角落、边缘、被障碍（甘草锁、巧克力、传送带）包围**的难够到处——逼玩家不能只在中间乱消，而要**把消除"导向"特定坐标**。

**收尾（Sugar Crush）**：清光果冻时触发 Sugar Crush，剩余每步生成 candy fish / 条纹 / 包裹糖并自动引爆加分（见第三节）。**Jelly fish 一条清 3 格果冻，且能隔着障碍打到果冻**（甘草漩涡 / 锁除外），是清残余果冻的利器；与 Color Bomb 组合可生成一群同色 jelly fish 扑向果冻。

**独特体验 + 设计原理**：这是 CCS 最具**"目标空间化"**的模式——目标不是抽象分数，而是**棋盘上看得见的、有明确坐标的待清除区域**。

> 它解决了 Moves 模式"目标抽象"的问题：玩家每一步都能看到"还剩这几块没清"，**进度可视、即时反馈、有终点感**。难点在于**够到难够到的格子**，这制造了真正的**位置规划 / 路径思考**——是策略性最强的基础模式之一。

来源：[Jelly levels – CCS Wiki](https://candycrush.fandom.com/wiki/Jelly_levels)、[Jelly – CCS Wiki](https://candycrush.fandom.com/wiki/Jelly)

### 4. Bring Down the Ingredients（运送原料下落）—— 重力与路径规划

**精确规则**：棋盘上有"原料"（经典为**樱桃 cherries** 和**榛子 / 坚果 hazelnut**），玩家要把它们一路**下移到棋盘底部带绿色向下箭头的出口（exit）**；让所有原料落出出口、并在步数内达最低分即赢。原料只能靠"消除它下方的糖果使其因重力下落"或特殊糖果推动来移动。

**典型布局**：原料常生成在顶部，出口在底部特定列；中途布满障碍（巧克力会吞掉底部糖果甚至围死原料、传送带改变下落方向、被锁住的列）。

**关键策略（也是设计意图）**：
- **条纹糖（竖向）是神器**：一条竖条纹能把一个原料从顶部直接拉到底，所以玩家要学会"为原料制造垂直通道"。
- 有时要**牺牲做特殊糖果的机会**，专注把原料往出口推。
- 要**同时开多个下落通道**，让尽量多原料同时在场。
- 优先快速清掉巧克力，否则它会围堵原料。

**独特体验 + 设计原理**：它把三消变成一道**"物流 / 重力解谜"**——你不是在比分数，而是在**操纵重力与棋盘结构，把目标物从 A 点送到 B 点**。

> 设计价值：引入了**"运送"这一全新动词**，和"清除"完全不同的心智模型。玩家要逆向思考"我消哪里能让原料下落一格"，这是一种**因果链规划**，策略深度高。出口数量、障碍布局给了设计师极大的难度调控空间。

来源：[Ingredients levels – CCS Wiki](https://candycrush.fandom.com/wiki/Ingredients_levels)、[GamesRadar 15 essential tips](https://www.gamesradar.com/candy-crush-saga-tips/)、[Bring down ingredients – CCS All Help](https://candycrushsagaallhelp.blogspot.com/2012/12/bring-down-ingredients.html)

### 5. Candy Order / Collect the Orders（收集订单）—— 最灵活的"清单收集"框架

**精确规则**：侧边栏给出一张"订单清单"，玩家要在步数内**收集 / 消除指定数量的指定对象**。订单种类极多——官方称有 **40+ 种独特订单**，包括：
- **颜色糖订单**（如"红糖 ×20"，靠普通消除累计）；
- **特殊糖订单**（如"3 个 Color Bomb"，必须造出对应特殊糖）；
- **组合订单**（如"条纹+包裹""条纹+Color Bomb""双条纹"——**颜色不限**，只看组合类型）；
- **障碍 / 次级元素订单**（如清掉 X 个甘草、爆掉 X 个糖果炸弹 / icing 等）。

收集满全部订单即赢，步数用尽未满则输。标志是**粉色对勾**图标。

**典型布局**：布局服务于订单——若要"造 3 个 Color Bomb"，棋盘会给足同色糖让玩家有机会凑 5 连；若要"收集障碍"，则铺满该障碍。

**独特体验 + 设计原理**：这是 CCS 最**"模块化、可无限拓展"**的目标框架。

> 它的天才之处在于：**一套 UI（清单 + 计数器）能承载几乎任意目标**。设计师想考验玩家什么，就往订单里塞什么——想逼玩家练"造特殊糖"就下特殊糖订单，想教某个新障碍就下该障碍订单。**它把"目标"变成了一个可配置的数据表**，极大降低了出新关的成本，又能制造丰富多变的挑战。对做「关卡生成系统」，这是**最值得借鉴的范式**：用一个通用的"订单/需求"数据结构驱动海量关卡变体。

来源：[Game Modes - Collect the orders – CCS Zendesk](https://candycrush.zendesk.com/hc/en-us/articles/115004468849-Game-Modes-Collect-the-orders)、[Candy Order levels – CCS Wiki](https://candycrush.fandom.com/wiki/Candy_Order_levels)、[Order – CCS Wiki](https://candycrush.fandom.com/wiki/Order)

### 6. Mixed Mode（混合模式）—— 占比最大的"复合目标"

**精确规则**：一关同时含**两个或更多不同类型的目标**，必须**全部完成**才算赢（如：既要清光果冻 **又** 要运下所有原料 **又** 要收满订单）。目前有**6 种可玩的混合组合形式**，来自 Jelly / Ingredients / Order 三大基础类型的两两及三者组合。代表性里程碑：Level 1695 是首个六色 + magic mixer 的混合关。

**占比**：**最主流的类型**。不同口径数据：约占全部关卡的 **36.47% ～ 38.67%**（累计约 8054 次出现）；当前趋势是**每个 episode 含 6–10 个混合关，9 个最常见**。

**体验 + 设计原理**：被社区评为**当今最难的类型**。

> 原理：混合模式是 King **用已有积木拼出复杂度**的手段。它不需要发明新机制，只要把"清果冻 + 运原料 + 收订单"叠在一关，就立刻产生**多目标资源分配难题**——玩家步数有限，必须决定"先推原料还是先清角落果冻"，还要兼顾订单。这种**目标间的相互争夺**正是高阶策略性的来源，也是为什么它既是难度天花板、又是占比主力（成熟玩家需要的深度都靠它供给）。

来源：[Mixed Mode levels – CCS Wiki](https://candycrush.fandom.com/wiki/Mixed_Mode_levels)、[Level Types – CCS Wiki](https://candycrush.fandom.com/wiki/Level_Types)

### 7. Rainbow Rapids（彩虹急流 / 接通水路）—— 最新、最稀有的"连通解谜"

**精确规则**：棋盘上有一个**彩虹水龙头（faucet，起点）**和一个**彩虹模具（mold，终点）**，一道彩虹要从龙头流到模具，但被**障碍（blockers）阻断**。玩家通过在障碍旁做消除（或用条纹+包裹等连锁、道具）**清掉挡路的障碍**，让彩虹接通流到模具即赢。**关键**：不必清掉棋盘上所有障碍，**只需清掉挡在彩虹路径上的那些**。

**历史**：最新类型，首现于第 476 个 episode "Snowy Suburbs"，首关为 **Level 7119**。

**占比**：**最稀有**，仅约占全部关卡的 **2.82%**。

**体验 + 设计原理**：它把目标变成**"接通一条路径"**——一种"修水管 / 连通图"式的解谜。

> 设计价值：相比"清光全部 X"，它引入了**"只清关键路径"的选择性目标**——玩家要识别哪些障碍在路径上、哪些可以无视，这是一种**优先级判断**，比无脑全清更动脑。作为最新模式，它体现 King 仍在**为老玩家持续注入新鲜目标动词（flow / connect）**以对抗倦怠。占比极低说明它是**"调味品"而非主菜**。

来源：[Rainbow Rapids levels – CCS Wiki](https://candycrush.fandom.com/wiki/Rainbow_Rapids_levels)、[How does the Rainbow Rapids game mode work? – CCS Zendesk](https://candycrush.zendesk.com/hc/en-us/articles/360008932258-How-does-the-Rainbow-Rapids-game-mode-work)

---

## 三、收尾机制：Sugar Crush（所有类型共享的"爽点引擎"）

完成目标的瞬间触发 Sugar Crush，把**剩余步数转化为奖励烟花**：

- 每剩 1 步，在棋盘生成一个 candy fish / 条纹糖 / 包裹糖，**每个 +3000 分**（CCS 主作口径；Jelly Saga 口径为每步基础约 6000 分）；
- 然后棋盘上所有特殊糖**自动从左上到右下、按"candy fish → 包裹 → 条纹 → Color Bomb → 上色糖"的顺序逐个引爆**，连锁炸开（阅读顺序：从左到右、从上到下）。
- **注意**：若用完最后一步刚好通关、且棋盘无特殊糖，则 CCS 主作不触发 Sugar Crush。

**设计原理**：这是把"省步数"这一隐形效率，转化为**一段华丽、可观赏、有声效（"Sugar Crush!"语音）的多巴胺收尾**。它奖励玩家"高效通关"，同时给每一关一个**情绪高潮的句号**——无论目标类型是什么，结尾的爽感是统一的。这对留存极重要：**最后留给玩家的记忆是"爽"，而不是"刚才好难"。**

来源：[Sugar Crush – CCS Wiki](https://candycrush.fandom.com/wiki/Sugar_Crush)、[Sugar Crush – Jelly Wiki](https://candycrushjelly.fandom.com/wiki/Sugar_Crush)

---

## 四、哪些模式"设计感/策略性强"，哪些偏"刷"，为什么

**策略性 / 设计感强（强烈推荐借鉴）：**
- **Bring Down the Ingredients**：因果链 + 重力 + 路径规划，是"运送"心智模型，深度最高。
- **Clear the Jelly（尤其 double + 难够到布局）**：目标空间化 + 位置规划，经典且耐玩。
- **Mixed Mode**：多目标资源争夺，难度天花板，深度全靠它。
- **Candy Order（组合/特殊糖订单）**：逼玩家主动"制造"而非被动"清除"，并能精确考核特定技巧。
- **Rainbow Rapids**：选择性路径判断（清关键、忽略无关）。

**偏"刷" / 低策略：**
- **Moves（达标分数）**：目标抽象、无空间感，几乎纯运气连消 → **已被淘汰**，是反面教材。
- **Candy Order 里的"纯颜色糖订单"**（如"红糖 ×50"）：本质就是多消、靠量堆，策略弱。
- **Timed**：策略不弱但**用焦虑而非思考制造难度**，与休闲内核冲突 → **已被淘汰**。

**判定规律（提炼出的设计准则）**：

> **一个目标越"空间化、需要把消除导向特定坐标/方向"，策略性越强；越是"只看总数/总分"，越偏刷。** "运送""接通""清特定区域""造特定组合"都是高策略动词；"累计数量""达到分数"是低策略动词。

来源：综合 [Level Types – CCS Wiki](https://candycrush.fandom.com/wiki/Level_Types)、[Moves levels – CCS Wiki](https://candycrush.fandom.com/wiki/Moves_levels)、[Timed levels – CCS Wiki](https://candycrush.fandom.com/wiki/Timed_levels)

---

## 五、类型在游戏进程中的占比变化与"轮换制造新鲜感"

**当前 CCS 全量占比（约略）**：Mixed ≈ 36–39%（绝对主力）｜Jelly / Ingredients / Order 各占可观份额（构成基础三类）｜Rainbow Rapids ≈ 2.82%（最稀有，调味）｜Moves / Timed = 0%（绝版）。

**进程演化逻辑（"复杂度阶梯 / complexity staircase"）**——这是 King 设计师亲述的核心方法论：

1. **由简到繁、逐级引入**：新手早期只遇到简单目标（早年是 Moves / 单层 Jelly）和简单障碍；老玩家才会碰到 double jelly、混合多目标、新障碍。"新关卡通常混搭近期新障碍与老牌障碍"，**既不淹没新人，又能持续挑战老手**。

2. **每个 episode 内部"难易交错"**，不是单调递增——episode 里混着轻松关和硬关，让玩家有喘息也有挑战，**节奏起伏**。

3. **新模式靠"稀有度"保新鲜**：像 Rainbow Rapids 这种新动词占比压得很低，**偶尔出现一次才有惊喜感**；如果天天出就麻木了。

4. **障碍/机制必须"赚得入场资格"**：设计师明确表示——**任何新障碍/机制都要提供"独特行为或交互"，而不能只是已有东西的换皮**；现代障碍要"制造有趣的选择，而非单纯阻挡"。同理推及目标模式：每种模式都要带来**不同的核心动词/心智模型**才有存在价值（清除/运送/收集/接通各不相同）。

5. **数据驱动调难**：King 用 **bot 大规模模拟试玩**预估每关难度与通过率，再发布；但官方强调 **AI 只是辅助、不替代人类判断**，因为 bot 抓不到"手感"。真人试玩 + 线上玩家数据仍是核心。AI 也用来生成草稿关、批量探索机制组合，但人类设计师保留最终创作决定权。

> **轮换制造新鲜感的本质**：King 用**少数几个"动词"（清/运/收/接）× 海量"障碍与布局变量" × 混合叠加**，组合爆炸出上万关；再靠**复杂度阶梯**控制每个玩家在每个时刻只接触"略高于当前能力"的组合。新鲜感不来自"无穷多新规则"，而来自**已知积木的新排列 + 偶尔点缀的新动词**。

来源：[Crafting Candy Crush's difficulty: the "complexity staircase" – PocketGamer.biz](https://www.pocketgamer.biz/crafting-candy-crushs-difficulty-blockers-level-design-ai-and-the-complexity-staircase/)、[Mixed Mode levels – CCS Wiki](https://candycrush.fandom.com/wiki/Mixed_Mode_levels)

---

## 六、扩展对照：Soda Saga 与 Friends Saga 的关卡类型（其余模式的真正出处）

虽非主作，但若干常被提及的模式在这两作，且它们演示了**"同一三消引擎如何用不同目标动词派生出整套新游戏"**——对做关卡系统极有启发。

### Candy Crush Soda Saga（7 类）

- **Soda（汽水）**：消除"汽水瓶"释放汽水，把**液面升到棋盘顶部**（含"漂浮熊"变体：液面升高让熊浮到目标线上）。独特点：**棋盘液面会上升，糖果在液面上方/下方行为不同**，引入"液体物理"维度。
- **Frosting / Ice（救小熊）**：限定步数内，靠在冰霜旁消除**敲碎冰霜、找出藏在下面的指定数量小熊**。
- **Honey（蜂蜜）**：解救被蜂蜜困住的熊，**在蜂蜜旁消除逐层剥离**。
- **Chocolate（巧克力）**：清光所有巧克力；**若一回合没消到巧克力，它会再生长一格**（蔓延机制）。
- **Bubble Gum（泡泡糖）**：嚼掉所有泡泡糖，规则类似巧克力——**没消到就蔓延一格**。
- **Bubble（泡泡）**：把熊**顶到糖串/目标线以上**。
- **Jam（Spread the Jam，铺果酱起源）**：棋盘随机一格初始带果酱，**每次在带果酱格成功消除，果酱就蔓延到相邻消除处**，直到**铺满全盘**即赢。**铁律**：在没有果酱的格子消除不会扩散——所以每关至少有一个"免费果酱格"做种子。Color Bomb、Swedish Fish 能加速扩散。完成时触发 Sugar Crush。

来源：[Soda Saga game modes – Zendesk](https://candycrushsoda.zendesk.com/hc/en-us/articles/115000941085-What-are-the-different-game-modes)、[Jam levels – Soda Wiki](https://candycrushsoda.fandom.com/wiki/Jam_levels)、[Jam levels – community.king.com](https://community.king.com/en/candy-crush-friends-saga/discussion/285902/jam-levels-goal-types-general-strategy-trivia)

### Candy Crush Friends Saga（5 类）

- **Free the Animals（解救动物）**：Puffler 动物被困冰下，消除解救它们。
- **Free the Octopuses（解救章鱼）**：章鱼困在果冻里，在被困章鱼旁消除**逐层切开果冻**，清光全部层数、放出所有章鱼即赢。
- **Dunk the Cookies（蘸饼干）**：在饼干**下方消除使其因重力下落**，把所有饼干一路引导到棋盘底部的**融化巧克力河**里"蘸"进去即赢（与 CCS Ingredients 同源的"运送 + 重力"动词）。
- **Fill the Empty Hearts（填满空心）**：把心形（或其他形状）的空模具**填满**即赢。
- **Spread the Jam（铺果酱）**：用水果酱铺满棋盘（同 Soda 的 Jam 动词）。

补充：

- **Bubblegum Troll** 在 CCS / Friends 里是**角色 + booster（道具）**，不是关卡目标——它会随机在棋盘投放泡泡糖、能打到难够到的角落、清障碍很强，但落点随机且按对角线移动，需要规划；在 Friends 里作为可玩角色时，每次直击会让目标多移动两步。
- **"Chocolate Box"** 在 CCS 主作里**不是一个独立关卡目标类型**（Chocolate 是 Soda 的模式、或主作里的一种障碍/活动元素），检索未发现它作为正式 game mode 的规则。

来源：[Candy Crush Friends Saga – iMore](https://www.imore.com/candy-crush-friends-saga-everything-you-need-know)、[Types of Friends Levels – community.king.com](https://community.king.com/en/candy-crush-friends-saga/discussion/324953/types-of-candy-crush-friends-levels)、[Cookie levels – Friends Wiki](https://candycrushfriends.fandom.com/wiki/Cookie_levels)、[Bubblegum Troll (booster) – CCS Wiki](https://candycrush.fandom.com/wiki/Bubblegum_Troll_(booster))

---

## 七、给「关卡生成系统」的可直接落地的提炼

1. **目标要空间化、可视化**：抛弃纯分数目标（Moves 被淘汰的教训）。用"清光看得见的 X""把 Y 送到 Z""接通一条路"这种**棋盘上有明确坐标/方向的目标**，进度反馈即时，策略性自然涌现。

2. **用一个通用"订单/需求"数据结构驱动海量变体**（Candy Order 范式）：把目标做成可配置数据表（要什么、要多少），一套 UI 承载几十种目标，极大降低出关成本。

3. **少数动词 × 大量障碍布局 × 混合叠加 = 组合爆炸**：不要堆砌无穷多新规则。3–4 个核心动词（清/运/收/接）+ 丰富障碍 + Mixed Mode 叠加，就能产出上万关并维持深度。

4. **复杂度阶梯**：每个玩家在每个时刻只接触"略高于当前能力"的组合；新手简单、老手才解锁 double / mixed / 新障碍；episode 内难易交错。

5. **新机制要"赚得入场资格"**：每个新目标/障碍必须带来**独特动词或交互**，不能换皮；新模式靠**低占比保稀有惊喜**。

6. **统一的"爽点收尾"（Sugar Crush）**：无论目标类型，结尾都给一段把剩余资源转成华丽烟花的高潮，让玩家记住"爽"。

7. **慎用时间压力**：限时与休闲消除"低压力脑力满足"的内核冲突（Timed 被淘汰），除非做专门的竞速玩法，否则别作为主目标。

8. **数据驱动调难**：用 bot / 模拟大规模预估通过率，但保留人类对"手感"的最终判断。

---

## 主要来源汇总

- **CCS Wiki**：[Level Types](https://candycrush.fandom.com/wiki/Level_Types)｜[Level](https://candycrush.fandom.com/wiki/Level)｜[Jelly levels](https://candycrush.fandom.com/wiki/Jelly_levels)｜[Ingredients levels](https://candycrush.fandom.com/wiki/Ingredients_levels)｜[Candy Order levels](https://candycrush.fandom.com/wiki/Candy_Order_levels)｜[Mixed Mode levels](https://candycrush.fandom.com/wiki/Mixed_Mode_levels)｜[Rainbow Rapids levels](https://candycrush.fandom.com/wiki/Rainbow_Rapids_levels)｜[Moves levels](https://candycrush.fandom.com/wiki/Moves_levels)｜[Timed levels](https://candycrush.fandom.com/wiki/Timed_levels)｜[Sugar Crush](https://candycrush.fandom.com/wiki/Sugar_Crush)
- **King 官方 Zendesk**：[Collect the orders](https://candycrush.zendesk.com/hc/en-us/articles/115004468849-Game-Modes-Collect-the-orders)｜[Rainbow Rapids](https://candycrush.zendesk.com/hc/en-us/articles/360008932258-How-does-the-Rainbow-Rapids-game-mode-work)｜[Soda Saga game modes](https://candycrushsoda.zendesk.com/hc/en-us/articles/115000941085-What-are-the-different-game-modes)
- **设计方法论**：[PocketGamer.biz – complexity staircase 设计师访谈](https://www.pocketgamer.biz/crafting-candy-crushs-difficulty-blockers-level-design-ai-and-the-complexity-staircase/)
- **扩展作**：[Friends Saga – iMore](https://www.imore.com/candy-crush-friends-saga-everything-you-need-know)｜[Friends 关卡类型 – King 社区](https://community.king.com/en/candy-crush-friends-saga/discussion/324953/types-of-candy-crush-friends-levels)
- **攻略/策略**：[GamesRadar 15 tips](https://www.gamesradar.com/candy-crush-saga-tips/)｜[Bring down ingredients – CCS All Help](https://candycrushsagaallhelp.blogspot.com/2012/12/bring-down-ingredients.html)

---

## 研究方法说明 / 数据可信度

- 研究中 Fandom / 部分 Zendesk 页面对直接抓取返回 403，故采用搜索引擎对这些页面的结构化摘要并多源交叉印证。
- CCS 占比类数字（如 Mixed 36.47% vs 38.67%）在 Wiki 不同页面有口径差异，已并列标注，供参考量级而非当作精确常数。
- Sugar Crush 分值（3000 vs 6000）在 CCS 主作与 Jelly Saga 口径不同，已注明。
