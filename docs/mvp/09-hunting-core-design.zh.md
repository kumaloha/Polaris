# Hunting 核心设计文档：女性向派对狩猎 SLG

版本：v1  
状态：当前产品思考、需求调研、场景与玩法设计的汇总稿  
关系：`08-hunting-godot-redesign.zh.md` 是视觉/界面方向稿；本文是产品与玩法主文档。  
名称：英文 **Hunting** / 中文 **猎场** / 日文 **狩場（かりば）** / 韩文 **사냥터**（命名已锁定，详见 `00-mvp-brief.md`）。

## 1. 一句话定位

Hunting 是一个女性向派对狩猎 SLG：玩家投资自己、借闺蜜进入不同圈层、用天眼读取男人证据、在派对中通过边界感和社交证明筛选目标，最后把有限精力投给最可能带来长期回报的关系。

它不是传统“甜甜恋爱模拟器”，也不是工具型“男性鉴定 App”。它的核心幻想是：

- 我能进入更好的局。
- 我能提前看穿男人。
- 我能让高价值男性偏爱我。
- 我能控制关系节奏，而不是被关系消耗。
- 我能把自己的人设、魅力和社交位置经营成资产。
- 我最终能验证：这个男人到底是高回报投资，还是幻想债。

## 2. 产品基调

### 2.1 目标市场

欧美、日韩、港台可作为第一批观察市场。核心共性不是文化表层，而是现代女性对“自主选择关系”的需求更强。

### 2.2 目标用户

主要面向喜欢以下内容的女性用户：

- 女性向恋爱游戏。
- 乙女、互动叙事、角色陪伴。
- 换装、身份塑造、社交经营。
- 情感分析、识人、暧昧拉扯。
- “强男性偏爱我，但我仍然有控制权”的幻想。

### 2.3 体验关键词

- 冷感高级。
- 女性控制感。
- 派对、夜生活、高价值局。
- 男性可被观察、选择、测试、淘汰。
- 闺蜜共同体。
- 投资组合。
- 未来关键帧。

### 2.4 不要做成什么

- 不要做成管理后台。
- 不要做成心理测试 App。
- 不要做成纯文字聊天软件。
- 不要做成男性资料列表。
- 不要做成粉色可爱恋爱小品。
- 不要把“自我提升”做成鸡汤升级按钮。

## 3. 核心需求洞察

以下是产品假设，不是对所有女性的社会学定论。文档中使用“女性需求”时，指目标用户在该类幻想消费中的可设计需求。

### 3.1 幕强

玩家需要男性足够强：有资源、能力、掌控力、稀缺性、社会位置。

游戏表达：

- 男性角色要有身份标签和可见资源。
- 高价值派对中出现更强男性。
- 男人的“强”要通过行动、圈层、选择权体现，而不是数值裸露。

设计风险：

- 如果男性只是帅，没有资源和行动，会变成浅层颜值游戏。
- 如果男性太强且不可驯服，会压迫女性玩家控制感。

### 3.2 偏爱

女性幻想的核心不是“他对所有人都好”，而是“他对大部分人冷，对我例外”。

游戏表达：

- 男人在公开场合克制，在玩家面前给出特殊行动。
- 消息、约会、派对反应要体现例外性。
- 偏爱必须被玩家的选择触发，而不是免费发糖。

可消费点：

- 特殊消息。
- 私人邀请。
- 公开场景中的偏向。
- 未来关键帧中的“他仍然选择我”。

### 3.3 可驯服

现代女性幻想中的强男性不能完全脱离控制。强势男性要有被玩家影响的部分。

游戏表达：

- Boundary 可以改变男人行动。
- Test 可以迫使男人从暧昧变成具体计划。
- Social Proof 可以让男人感到竞争压力。

核心规则：

- 男人越强，越难驯服。
- 驯服不是让男人变弱，而是让他的强服务于玩家。

### 3.4 安全低门槛接触异性

现实中接触异性有风险、尴尬、成本和评价压力。游戏提供低风险练习场。

游戏表达：

- 玩家在派对前有 First Eye，可以看聊天记录和风险。
- 派对中每轮只做一个选择，降低社交复杂度。
- 失败不羞辱玩家，而是转化为“识别经验”。

### 3.5 识别低质量男性

玩家需要“我早就看出来了”的爽点。

游戏表达：

- 男人发消息后，闺蜜吐槽和玩家判断相互验证。
- Evan 这类角色提供高糖低行动样本。
- Feedback 中标出 Sugar Trap、False Alpha 等结果。

注意：

- 不把“所有男性都坏”写成系统结论。
- 游戏要允许真实高回报对象存在，否则投资玩法会失效。

### 3.6 边界感

派对中的主要玩法不是聊天答题，而是把握边界：给多少兴趣、何时拒绝、何时离开、何时借用社交证明。

游戏表达：

- Engage：给一点兴趣，但不交出节奏。
- Boundary：拒绝模糊进入，要求具体行动。
- Social Proof：让目标看到玩家有其他选择。
- Exit：及时离场保护精力。

### 3.7 自我投资和人设

真实自我投资不是“变漂亮 +1”这么薄。它包括外形、工作成果、情绪状态、社交位置、信息能力和叙事人设。

游戏表达：

- Outfit Build：今晚以什么形象出现。
- Self Investment：今晚把资源投在哪里。
- Persona：别人如何理解玩家。
- Girlfriend Support：谁把玩家带进哪个局。

### 3.8 闺蜜共同体

闺蜜不是 NPC 装饰，而是派对供给、情报解释和情绪确认的入口。

游戏表达：

- 没有闺蜜局，就没有更高级派对。
- 闺蜜会提供不同类型支持。
- 派对后闺蜜吐槽是重要奖励。

### 3.9 高回报关系投资

“成长股男人”是反共识但有张力的玩法：短期可能没钱、没气场，但有责任感和能力，长期回报高。

游戏表达：

- Leo 类角色短期低刺激，长期关键帧回报更好。
- 玩家可以 Observe，不必立刻 Date。
- 低成本吊着成长股会触发反噬或失去机会。

### 3.10 未来验证

现实中关系变化可能要几年，但游戏不能让玩家等几年。需要压缩成“未来天眼”。

游戏表达：

- First Eye：投资前，只看资料和聊天证据。
- Future Eye：投资后，才看未来关键帧。
- 关键帧压缩：3 周、6 个月、3 年、10 年。

## 4. 可消费需求排序

### 高频：男性鉴定

原因：

- 每个男人都可以鉴定。
- 每次派对都能产生新样本。
- 聊天记录、行为、消息、未来反馈都能做成重复消费。

玩法承载：

- First Eye。
- Party Encounter。
- After Party Phone。
- Future Eye。

### 中频：自我提升

原因：

- 装扮、人设、闺蜜关系会影响派对入口和男人反应。
- 但玩家不会每 10 秒换一次人设，需要作为阶段性配置。

玩法承载：

- Ready Room。
- Build Closet。
- Girlfriend Night。
- Outfit/Persona 解锁。

### 低频：高额回报投资

原因：

- 关系投资需要更长反馈周期。
- 如果每局都给 10 年结果，会变廉价。

玩法承载：

- Date / Observe / Test / Cut。
- Future Eye。
- Portfolio 结果。

## 5. 竞品调研总结

### 5.1 女性向恋爱游戏的界面共性

调研对象包括《Love and Deepspace》《Tears of Themis》《Mr Love: Queen's Choice》《Mystic Messenger》《Obey Me! Nightbringer》《Ikemen》系列和 Nikki 换装系。

共同点：

- 第一屏通常是角色、邀请函、房间或手机，而不是菜单列表。
- 男性角色通常以大图、卡牌、语音、电话、消息构成陪伴感。
- 关系进展由多个入口组成：聊天、约会、卡牌、剧情、日常互动。
- 换装或卡牌不只是属性，而是身份、场景和幻想资产。
- 手机消息是强沉浸工具，但必须和角色主视觉、场景主视觉交替。

### 5.2 Hunting 的取舍

吸收：

- 男性大图和关键瞬间。
- 手机消息/聊天记录。
- 主屏场景化。
- 换装和人设影响门槛。
- 关系关键帧收藏。

不照搬：

- 不做 3D 战斗。
- 不做真实时间聊天等待。
- 不做大型抽卡和复杂养成。
- 不做法律案件或公司经营主线。
- 不做大衣柜。

### 5.3 调研来源

- Love and Deepspace App Store：Home、Outfit、AR、Journal、With Him、Memories 等系统方向。<https://apps.apple.com/us/app/love-and-deepspace/id6443467666>
- Love and Deepspace Wiki：Date、Playtime、Photo Studio、By Your Side、Affinity。<https://loveanddeepspace.wiki.gg/wiki/Date>
- Tears of Themis App Store：恋爱、调查、卡牌和陪伴系统。<https://apps.apple.com/us/app/tears-of-themis/id1517957388>
- Tears of Themis Invitation：主屏背景/男主互动作为首页资产。<https://progameguides.com/tears-of-themis/what-are-invitations-in-tears-of-themis/>
- Mr Love Phone：SMS、Moments、Calls、Intimacy。<https://mrlove.wiki.gg/wiki/Phone>
- Mr Love Go See Him：主屏互动、衣服、背景、语音。<https://mrlove.wiki.gg/wiki/Go_See_Him>
- Mystic Messenger Chat Room：聊天房和错过聊天机制。<https://mystic-messenger.fandom.com/wiki/Chat_Room_Timings>
- Obey Me! Nightbringer：手机式界面、聊天电话、卡牌关卡推进剧情。<https://obeymewiki.com/wiki/Obey_Me%21_Nightbringer>
- Ikemen 系列玩法：Story Tickets、Avatar Challenge、Intimacy Check。<https://ikemen-revolution.fandom.com/wiki/Gameplay>
- Nikki 换装玩法：Styling Battle、服装属性和主题挑战。<https://lovenikki.fandom.com/wiki/Styling_Battle>

## 6. 核心玩法循环

```text
投资自己
  ↓
经营闺蜜局
  ↓
解锁派对
  ↓
第一天眼看男人证据
  ↓
派对中操作边界和社交证明
  ↓
派对后处理消息和闺蜜吐槽
  ↓
选择 Date / Observe / Test / Cut
  ↓
第二天眼看未来关键帧
  ↓
获得积分、解锁更好 build / 闺蜜 / 派对
```

## 7. 核心数值

### Energy / 精力

限制不能投资所有男人。

来源：

- 初始给定。
- Solo Reset 增加。
- 部分闺蜜局动作消耗。

消耗：

- 派对动作。
- Date。
- Test。

设计原则：

- Energy 是最重要成本。
- 玩家必须经常面对“我不能什么都要”。

### Charm / 魅力

代表外形、气场和吸引力。

来源：

- Outfit。
- Beauty Care。
- Persona。
- Girlfriend Move。

用途：

- 解锁派对。
- 影响主动搭讪男人数量。
- 影响 First Eye 的信息深度。

### Position / 段位

代表社交位置和稀缺性。

来源：

- Work Win。
- 闺蜜支持。
- Social Proof。

用途：

- 解锁高阶派对。
- 提高强男性反应。
- 降低低质量男人纠缠。

### Control / 控制感

代表关系节奏是否在玩家手里。

来源：

- Boundary。
- Ask Plan。
- 成功 Cut。

损失：

- 接受模糊约会。
- 被午夜糖衣拖走。
- 多线消耗过度。

用途：

- Future Eye 判断关系是否增强玩家。

## 8. 场景与玩法设计

### 8.1 Ready Room / 镜前准备

目标：让玩家先投资自己，而不是一上来被男人选择。

画面：

- 夜景镜前。
- 女主大立绘或半身剪影。
- 当前 Outfit。
- 当前 Persona。
- 顶部 HUD：Day / Energy / Charm / Position / Control。
- 底部按钮：去闺蜜局。

玩法：

- 选择 Self Investment。
- 选择 Persona。
- 查看派对门槛预告。

可选 Self Investment：

| 名称 | 真实含义 | 效果 |
| --- | --- | --- |
| Beauty Care | 外形和妆发投入 | Charm +2 |
| Work Win | 事业成果、可展示生活质量 | Position +1 |
| Solo Reset | 睡眠、健身、情绪复位 | Energy +2 |
| Evidence Study | 研究聊天记录和截图 | First Eye +1 clue |

可选 Persona：

| 人设 | 幻想 | 效果 | 风险 |
| --- | --- | --- | --- |
| Rare Girl | 稀缺、不可轻易得到 | Position +1 | 过度主动会破功 |
| Soft Sun | 温暖、让人靠近 | Charm +1 | 容易吸引情绪债 |
| Power Darling | 漂亮但有压迫感 | Boundary 效果增强 | 低自尊男性会防御 |

### 8.2 Girlfriend Night / 闺蜜局

目标：派对不是默认全开，闺蜜是社交供给入口。

画面：

- 酒廊/餐桌背景。
- 三个闺蜜头像。
- 派对地图节点。
- 闺蜜吐槽气泡。

闺蜜类型：

| 闺蜜 | 定位 | 能力 |
| --- | --- | --- |
| Maya | Party Queen | 普通派对入口，能救一次 drain man |
| Claire | High-End Circle | 更高端派对识别，资源男信息更清晰 |
| Nina | Sharp Group Chat | 派对后吐槽更准，降低误判 |

局内动作：

| 动作 | 含义 | 效果 |
| --- | --- | --- |
| Bring Value | 不是蹭局，而是带价值进桌 | Position +1 |
| Trade Receipts | 交换聊天截图和情报 | Energy -1，First Eye +1 clue |
| Scarcity Story | 让自己看起来有选择 | Energy -1，Charm +1，Position +1 |

派对解锁：

| 派对 | 门槛 | 男人池 | 状态 |
| --- | --- | --- | --- |
| Friday Rooftop | Charm 40 / Position 2 | Adrian / Evan / Leo | MVP 默认可解锁 |
| Gallery Opening | Charm 42 / Position 3 | 更高阶资源男 | MVP 可锁定展示 |
| Founders Dinner | Charm 44 / Position 4 | 高压高回报男性 | MVP 可锁定展示 |

### 8.3 Party Map / 派对地图

目标：让派对像关卡，而不是下拉菜单。

玩法：

- 节点展示视觉海报。
- 锁定节点显示差多少 Charm / Position。
- 解锁节点出现男人剪影。
- 玩家选择一个派对进入 First Eye。

设计要点：

- 派对节点必须有“今晚机会”的诱惑。
- 锁定不是失败，而是给自我投资目标。

### 8.4 First Eye / 第一天眼

目标：投资前识别男人。

只展示：

- 男人照片。
- 身份标签。
- Energy Cost。
- Risk。
- Opportunity。
- 近期聊天记录。

不展示：

- 十年后结果。
- 投资回报结论。
- 系统替玩家做决定。

男人样本：

| 男人 | 类型 | 风险 | 机会 |
| --- | --- | --- | --- |
| Adrian | Resource Man | 控制倾向 | 如果尊重边界，会给具体行动 |
| Evan | High-Sugar Performer | 午夜糖衣、低行动 | 短期情绪刺激 |
| Leo | Growth Stock | 自尊敏感、短期低刺激 | 低成本观察可能有长期回报 |

玩家选择：

- Set Primary。
- Set Backup。
- Enter Party。

### 8.5 Party Encounter / 派对闯关

目标：核心高频玩法。玩家不是聊天答题，而是在派对中操作关系边界。

结构：

- 一场派对 6 轮。
- 每轮一个事件。
- 每轮 4 个动作。
- 动作改变 Energy / Position / Control / 男人兴趣。

四个动作：

| 动作 | 玩家行为 | 资源结果 | 关系结果 |
| --- | --- | --- | --- |
| Engage | 给短兴趣 | Energy -1 | Interest + |
| Boundary | 拒绝模糊进入 | Energy -1，Control + | 筛掉低行动男 |
| Social Proof | 借用场内注意力 | Energy -1，Position + | 目标男压力 + |
| Exit | 离开/切桌/闺蜜救场 | 不消耗或少消耗 | 保住人设和精力 |

示例轮次：

| Round | 事件 | 推荐动作 | 结果 |
| --- | --- | --- | --- |
| 1 | Evan 先来搭讪 | Engage | 给短兴趣，不交出整晚 |
| 2 | Adrian 看到你被关注 | Social Proof | 强化稀缺性 |
| 3 | Drain Man 挡路 | Exit | 保精力 |
| 4 | 闺蜜把你拉到更好桌 | Social Proof | Position + |
| 5 | Adrian 给模糊邀请 | Boundary | 测他能否具体行动 |
| 6 | 派对收尾，消息即将开始 | Exit | 留下余韵 |

### 8.6 After Party Phone / 派对后手机

目标：交往一阵子的入口，闺蜜吐槽男人，玩家做投资选择。

画面：

- 手机锁屏。
- 3 条男人消息。
- 闺蜜群聊吐槽。
- 底部关系选择。

男人消息样例：

| 男人 | 消息 | 闺蜜吐槽 |
| --- | --- | --- |
| Adrian | Saturday 8. I'll book the place. | 看他是否守时，比场地更重要 |
| Evan | Still awake? I keep thinking of you. | 他不是深情，是夜里便宜 |
| Leo | I kept thinking about what you said. | 可以观察，但别资助幻想 |

玩家选择：

| 选择 | 含义 | 成本 |
| --- | --- | --- |
| Date | 主投资，只能一个 | Energy 高消耗 |
| Observe | 低成本持仓 | Energy 低/无 |
| Test | 给具体验证任务 | Energy 中等 |
| Cut | 保护精力 | 无 |

### 8.7 Short Date Test / 短约会测试

目标：把“偏爱”具体化。

示例：

Adrian 把晚餐改到更晚，玩家选择：

- Accept：短期顺从，Control 下降。
- Ask Plan：要求明确安排，Control 上升。
- Delay：观察是否追进。
- Cut：停止消耗。

设计原则：

- 偏爱必须落到行动。
- 模糊甜言蜜语不算偏爱。
- 愿意付出确定性才算关系资产。

### 8.8 Future Eye / 第二天眼

目标：快速体验长期关系变化。

触发：

- 只有在玩家做出 Date / Observe / Test 之后出现。
- 不在派对前出现。

展示方式：

- 不做表格。
- 用未来关键帧卡片展示。

关键帧：

| 时间 | 看什么 |
| --- | --- |
| 3 周 | 是否持续行动 |
| 6 个月 | 是否公开、稳定、投入 |
| 3 年 | 事业/资源/关系位置变化 |
| 10 年 | 是否成为高回报关系资产 |

反馈类型：

| 类型 | 含义 |
| --- | --- |
| Correct Read | 看对了，关系增强自己 |
| Sugar Trap | 短期爽，长期消耗 |
| Slow Upside | 短期不刺激，长期回报 |
| False Alpha | 看似强，实际控制成本高 |
| Missed Growth | 玩家低成本吊着成长股，最终失去 |

## 9. 情绪奖励设计

### 9.1 识别奖励

玩家看到 Future Eye 后，获得“我就说吧”的确认感。

### 9.2 偏爱奖励

男人从暧昧变成具体行动，例如：

- 订好时间地点。
- 公开承认。
- 为玩家调整安排。
- 在竞争场景中选择玩家。

### 9.3 控制奖励

玩家通过 Boundary / Test 改变男人行为。

### 9.4 圈层奖励

闺蜜局解锁更好派对。

### 9.5 自我投资奖励

更好 build 让玩家进入之前进不了的局，吸引之前吸引不到的男人。

## 10. MVP 范围

第一版只做 4 个主屏 + 2 个轻弹层：

1. Ready Room。
2. Girlfriend Night + Party Map。
3. First Eye。
4. Party Encounter。
5. After Party Phone 弹层。
6. Future Eye 弹层。

必须有：

- 女主大视觉。
- 男人照片。
- 派对背景。
- 闺蜜选择。
- 派对门槛。
- 6 轮派对选择。
- Date / Observe / Test / Cut。
- 未来关键帧。

暂不做：

- 3D。
- 抽卡。
- 付费。
- 真实时间聊天。
- 大衣柜。
- 完整剧情章节。
- 复杂存档。
- 多语言完整文本库。

## 11. Godot 实现方向

使用 Godot 4 做 2D 竖屏原型。

原因：

- 2D UI/场景迭代轻量，所改即所见。
- 适合快速做女性向视觉布局。
- GDScript 足够支撑 MVP。
- 不背历史工程包袱。

项目结构建议：

```text
Godot/
  project.godot
  scenes/
    hunting_game.tscn
  scripts/
    hunting_game.gd
  assets/
    art/
      Backgrounds/
      Men/
      Outfits/
      ChatSkins/
```

第一版技术原则：

- 先用代码生成 UI，方便快速调整。
- 先复用现有 PNG 占位。
- 首页必须优先做到像游戏。
- 不把完整系统抽象过度。

## 12. 第一眼验收标准

打开游戏 3 秒内，必须成立：

- 这是一个游戏，不是 App。
- 有场景背景。
- 有女主视觉。
- 有派对节点。
- 有资源 HUD。
- 有明确下一步。
- 有“今晚我要去局里”的感觉。

如果第一屏仍然像后台，直接判定失败，不进入后续开发。

## 13. 玩法验收标准

玩家完成一轮后，应该能复述：

- 我为什么不能进高级局。
- 我为什么需要闺蜜。
- 我为什么要投资自己。
- 我为什么不能同时 Date 所有男人。
- 我为什么要先看聊天记录。
- 我为什么要在派对里做 Boundary / Social Proof。
- 我为什么说这个男人值得投或不值得投。

## 14. 内容语气

文本要锋利，但不能变成说教。

推荐语气：

- “他不是深情，是夜里便宜。”
- “模糊邀请不是偏爱，具体安排才是。”
- “你不是来证明自己值得被选，你是来决定谁值得消耗你的精力。”

避免语气：

- 大段心理学解释。
- 道德审判。
- 后台提示语。
- 泛泛鸡汤。

## 15. 下一步

1. 先审本文和 `08-hunting-godot-redesign.zh.md`。
2. 如果方向成立，再画 Godot 首屏 wireframe。
3. 首屏通过后再写 Godot 工程。
4. 每次开发只验证一个场景是否“像游戏”。

