# Hunting Godot 设计稿 v2：派对狩猎恋爱 SLG

状态：重做设计稿，暂缓继续写代码。上一版最大问题是“功能表单化”：它能说明系统，但第一眼不像游戏。本稿把界面从管理后台重构为女性向恋爱/经营游戏的竖屏场景。

## 0. 调研结论

### 参考游戏

| 参考 | 可借鉴的设计语言 | Hunting 应该吸收什么 | 不照搬什么 |
| --- | --- | --- | --- |
| Love and Deepspace / 恋与深空 | 高质量男性主视觉、Home/Date/Photo/By Your Side/Memory 体系，男人不是列表，是“可陪伴对象” | 男人必须大图出现；关系推进要有“陪伴感”和可收藏关键帧；Home 不能像菜单 | 3D 高成本、战斗系统规模 |
| Tears of Themis / 未定事件簿 | 主屏 Invitation、案件调查、卡牌辩论、角色个人线 | 主屏要像“邀请函/场景海报”；派对中的社交判断可做成回合制对抗 | 法律题材、复杂剧情解谜 |
| Mr Love: Queen's Choice / 恋与制作人 | Phone/SMS/Moments/Calls、Karma 卡、公司经营 | 手机消息是关系反馈核心；卡牌不是数值表，而是男人瞬间/证据/回忆 | 制作公司主线和重养成负担 |
| Mystic Messenger | 实时聊天房、来电、错过聊天的 FOMO | “男人发消息”要像真的弹进来；派对后消息比复盘更有沉浸感 | 真实时间等待，MVP 不做 |
| Obey Me! Nightbringer | 手机式主界面、聊天/电话、用关卡推进剧情 | “手机”和“关卡地图”可以共存；聊天是奖励也是剧情入口 | 节奏音游部分 |
| Ikemen 系列 | 路线选择、Story Ticket、Avatar Challenge、Intimacy Check | 女主装扮/人设应成为门槛，而不是装饰；亲密和剧情节点用挑战卡住 | 纯读章节和票券等待 |
| Nikki 换装系 | 穿搭有属性、主题挑战、衣服是玩法核心 | 自我投资要具体到 outfit/build；Charm 不是一个抽象数值，而是搭配结果 | 大衣柜规模，MVP 只做 3 套默认 build |

### 调研提炼

1. 女性向恋爱游戏第一屏通常不是“功能入口”，而是“一个人/一段关系/一个场景”。
2. 男性角色必须以视觉资产占据屏幕重心，只有文字资料会立刻变成工具 App。
3. 手机聊天是强沉浸组件，但它不能独占游戏；要和场景、角色、关卡交替出现。
4. 装扮如果只加属性会很弱，必须服务于“我是谁、我能进什么局、谁会被我吸引”。
5. 派对不应是列表选择，而应是地图节点/关卡房间/可进入场景。
6. 反馈不能像报表，要像未来预告片：短视频感、关键帧、命运分叉。

## 1. 产品定位

一句话：Hunting 是一个“投资男人 + 投资自己”的女性向派对狩猎 SLG。

核心体验不是“谈恋爱模拟器”，而是：

- 我先把自己打造成某种人。
- 我通过闺蜜进入某种局。
- 我用天眼提前看男人的聊天证据。
- 我在派对里用边界感和社交证明筛人。
- 我决定把精力投给谁。
- 我看未来关键帧验证自己有没有看对。

## 2. 美术方向

### 关键词

- 冷感高级
- 夜生活
- 高价值局
- 女性控制感
- 男性可被观察、可被选择、可被淘汰
- 不甜腻，不粉，不可爱，不办公室

### 画面比例

竖屏 9:16。以 iPhone 为主。

### 视觉结构

每个主场景采用“三层画面”：

1. 背景层：派对、镜前、车内、酒廊、手机屏。
2. 角色层：女主装扮立绘、男人半身图、闺蜜头像。
3. 游戏 HUD：能量、魅力、段位、选择按钮、目标提示。

UI 永远叠在场景上，不出现大面积白底表格。

## 3. 核心资源

### Energy / 精力

限制玩家不能每个男人都投。

- 派对中行动消耗。
- 派对后 Date 消耗更多。
- 低精力时只能 Observe / Cut。

### Charm / 魅力

由装扮、自我投资、人设共同决定。

- 决定能不能进入更好派对。
- 决定哪些男人会主动靠近。
- 决定 First Eye 中可见的信息深度。

### Position / 段位

代表社交位置和稀缺性。

- 闺蜜局提升。
- 派对中 Social Proof 提升。
- 高段位派对需要 Position 门槛。

### Control / 控制感

派对和关系中的边界结果。

- Boundary 成功增加。
- Date 中接受模糊安排会下降。
- Feedback 中用于判断“关系有没有被自己掌控”。

## 4. 场景总览

```text
Ready Room
  ↓
Girlfriend Night
  ↓
Party Map
  ↓
First Eye
  ↓
Party Encounter
  ↓
After Party Phone
  ↓
Future Eye / Portfolio
```

MVP 可以合并 `Girlfriend Night` 和 `Party Map` 在一个屏幕，但视觉上必须表现为“解锁派对节点”，不是表格。

## 5. 主界面设计

### 5.1 Ready Room / 镜前准备

用途：投资自己，建立今晚人设。

画面：

```text
┌──────────────────────────────┐
│ Day 01  Energy 8  Charm 40   │
│ Position 1  Control 0        │
├──────────────────────────────┤
│                              │
│     夜景镜前 / 女主立绘        │
│                              │
│  当前人设：Rare Girl          │
│  今晚目标：进入 Rooftop       │
│                              │
├──────────────────────────────┤
│ Outfit Build                 │
│ [Midnight Silk] [Work Win]   │
│ [Evidence Study]             │
├──────────────────────────────┤
│         去闺蜜局              │
└──────────────────────────────┘
```

交互：

- 点女主：打开装扮 build。
- 点自我投资卡：切换今晚 build。
- 点人设标签：切换 Rare Girl / Soft Sun / Power Darling。
- 大按钮：进入闺蜜局。

设计要求：

- 女主立绘/剪影必须大，占屏幕 40% 以上。
- 资源显示是 HUD，不是卡片表格。
- 文字少，按钮大。

### 5.2 Build Closet / 自我投资

用途：把“自我提升”做成真实选择，而不是抽象鸡汤。

可选 build：

| Build | 视觉 | 效果 | 代价 |
| --- | --- | --- | --- |
| Beauty Care | 黑裙、光泽妆发 | Charm +2 | 无 |
| Work Win | 西装、文件夹、冷淡妆 | Position +1 | 更少男人主动靠近 |
| Solo Reset | 浴袍/睡眠/健身 | Energy +2 | Charm 不变 |
| Evidence Study | 手机、聊天记录、截图 | First Eye +1 clue | 派对气场不提升 |

关键：这些不是“升级按钮”，而是今晚的 build。玩家要觉得自己在出门前做战术配置。

### 5.3 Girlfriend Night / 闺蜜局

用途：派对供给入口。

画面：

```text
┌──────────────────────────────┐
│ 酒廊桌面 / 三个闺蜜头像        │
├──────────────────────────────┤
│ Maya   Claire   Nina          │
│ 派对女王  高端圈  毒舌群聊      │
├──────────────────────────────┤
│ 今日局内动作                  │
│ [Bring Value] [Trade Receipts]│
│ [Scarcity Story]              │
├──────────────────────────────┤
│ 派对地图                      │
│ Rooftop  UNLOCKED             │
│ Gallery  LOCKED               │
│ Founders LOCKED               │
└──────────────────────────────┘
```

交互：

- 选择闺蜜改变派对入口。
- 选择局内动作改变 Charm / Position / First Eye。
- 点派对节点查看门槛和男人池。

情绪：

- 玩家不是“申请派对”，而是“被带进更好的局”。
- 闺蜜吐槽要锋利，形成女性共同识别男人的快感。

### 5.4 Party Map / 派对地图

用途：让派对像关卡。

节点：

| 节点 | 门槛 | 男人池 | 视觉 |
| --- | --- | --- | --- |
| Friday Rooftop | Charm 40 / Position 2 | Adrian / Evan / Leo | 夜景 rooftop |
| Gallery Opening | Charm 42 / Position 3 | 资源男更多 | 白盒画廊 |
| Founders Dinner | Charm 44 / Position 4 | 高回报高压男人 | 酒店私宴 |

设计：

- 地图节点用海报卡/霓虹坐标，不用普通列表。
- 锁定节点显示差多少 Charm / Position。
- 解锁后出现男人剪影，未开 First Eye 前不显示完整信息。

### 5.5 First Eye / 第一天眼

用途：派对前看男人资料和聊天记录。

画面：

```text
┌──────────────────────────────┐
│ Rooftop Intel                │
├──────────────────────────────┤
│  男人大图卡 Carousel          │
│  Adrian / Resource Man       │
│  Cost 3 Energy               │
│  Risk: Control tendency      │
├──────────────────────────────┤
│ 手机聊天皮肤                  │
│ him: Saturday night?          │
│ you: You always make plans?   │
│ clue: concrete action         │
├──────────────────────────────┤
│ [Primary] [Backup] [Enter]    │
└──────────────────────────────┘
```

规则：

- First Eye 只看资料，不做未来预测。
- 最好的资料永远是聊天记录。
- 手机皮肤按地区变化：中国微信，日韩台 Line，其他 WhatsApp。

### 5.6 Party Encounter / 派对闯关

用途：核心玩法，玩边界感和社交证明。

画面：

```text
┌──────────────────────────────┐
│ Round 2/6  Energy 6          │
├──────────────────────────────┤
│  派对背景                     │
│  左：女主剪影                 │
│  右：目标男人                 │
│  中：当前事件文本气泡          │
├──────────────────────────────┤
│ Interest Meter / Pressure     │
├──────────────────────────────┤
│ [Engage] [Boundary]           │
│ [Social Proof] [Exit]         │
└──────────────────────────────┘
```

动作：

| 动作 | 含义 | 效果 |
| --- | --- | --- |
| Engage | 给一点兴趣 | 男方 Interest +，Energy -1 |
| Boundary | 拒绝模糊进入 | Control +，可能筛掉低质量男 |
| Social Proof | 借用场内注意力 | Position +，目标男压力 + |
| Exit | 离开/切桌/让闺蜜救场 | 保精力，可能错过机会 |

要点：

- 每轮只有一个事件，一个选择。
- 不是答题，而是“场内操作”。
- 男人要有反应动画/状态变化，哪怕 MVP 只有文字反馈，也要放在男人气泡里。

### 5.7 After Party Phone / 派对后手机

用途：短期交往、闺蜜吐槽、投资选择。

画面：

```text
┌──────────────────────────────┐
│ 手机锁屏：3 unread            │
├──────────────────────────────┤
│ Adrian: Saturday 8. I'll book │
│ Evan: Still awake?            │
│ Leo: I kept thinking...       │
├──────────────────────────────┤
│ 闺蜜群聊吐槽                  │
│ Nina: He is cheap at night.   │
├──────────────────────────────┤
│ [Date] [Observe] [Test] [Cut] │
└──────────────────────────────┘
```

规则：

- Date 只能选一个主投资对象。
- Observe 是低成本持仓。
- Test 是给一个明确验证任务。
- Cut 是保护精力。

### 5.8 Future Eye / 第二天眼

用途：投资后反馈，不和 First Eye 混在一起。

画面不是报表，而是未来关键帧：

```text
┌──────────────────────────────┐
│ FUTURE EYE                   │
├──────────────────────────────┤
│ 3 Weeks  He keeps concrete    │
│ 6 Months You are visible      │
│ 3 Years  Career jump          │
│ 10 Years Portfolio return     │
├──────────────────────────────┤
│ Result: Correct Read          │
│ Energy ROI + / Fantasy Debt - │
└──────────────────────────────┘
```

反馈类型：

- Correct Read：看对了，关系增强自己。
- Sugar Trap：短期爽，长期消耗。
- Slow Upside：短期不刺激，长期回报。
- False Alpha：看似强，实际控制成本高。

## 6. Godot MVP 页面优先级

第一轮只做 4 个核心屏，不做完整 7 屏：

1. Ready Room：必须像游戏，解决第一眼问题。
2. Girlfriend Night + Party Map：闺蜜局解锁派对。
3. First Eye：男人照片 + 聊天证据。
4. Party Encounter：6 回合社交战。

After Party Phone 和 Future Eye 可以先做轻量弹层，但视觉语言要先定。

## 7. 第一轮实现规格

Godot 4，2D，竖屏 1170x2532 参考分辨率。

文件结构：

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

技术策略：

- 用 GDScript 代码生成 UI，方便快速改版。
- 用现有 PNG 临时资产占位，不等完整美术。
- 首页必须全屏背景 + 女主 outfit 图 + HUD + 地图节点。
- 不写复杂架构，不背历史迁移包袱。

## 8. 设计验收标准

第一眼：

- 不像 App，不像后台，不像表格。
- 能看到女主、派对场景、可进入节点、资源 HUD。
- 主要按钮在底部，符合手游操作。

玩法：

- 玩家知道：我为什么不能进高级局。
- 玩家知道：闺蜜为什么重要。
- 玩家知道：装扮/人设为什么是投资自己。
- 玩家知道：男人是猎物/资产，不是通讯录联系人。

情绪：

- 有“我在准备去局里”的代入。
- 有“姐妹带我进更好圈子”的社交爽点。
- 有“我提前看穿男人”的控制爽点。
- 有“我把精力投给谁”的投资感。

## 9. 当前不做

- 不做 3D。
- 不做真实时间聊天。
- 不做抽卡。
- 不做付费。
- 不做大衣柜。
- 不做完整剧情章节。
- 不做复杂存档。

先把“游戏界面”和“核心循环”做对。

## 10. 调研来源

- Love and Deepspace App Store：版本记录显示 Home、Outfit、AR、Journal、With Him、Memories 等系统方向。<https://apps.apple.com/us/app/love-and-deepspace/id6443467666>
- Love and Deepspace Wiki：Date menu、Playtime、Photo Studio、By Your Side、Affinity 等结构。<https://loveanddeepspace.wiki.gg/wiki/Date>
- Tears of Themis App Store： romance x detective x adventure、调查、陪伴、卡牌系统更新。<https://apps.apple.com/us/app/tears-of-themis/id1517957388>
- Tears of Themis Invitation 资料：主屏背景/男主互动作为首页核心资产。<https://progameguides.com/tears-of-themis/what-are-invitations-in-tears-of-themis/>
- Mr Love Phone 系统：SMS、Moments、Calls、Intimacy。<https://mrlove.wiki.gg/wiki/Phone>
- Mr Love Go See Him：主屏互动、衣服、背景、语音。<https://mrlove.wiki.gg/wiki/Go_See_Him>
- Mystic Messenger Chat Room：实时聊天房和错过聊天机制。<https://mystic-messenger.fandom.com/wiki/Chat_Room_Timings>
- Obey Me! Nightbringer：手机式界面、聊天电话、卡牌关卡推进剧情。<https://obeymewiki.com/wiki/Obey_Me%21_Nightbringer>
- Ikemen 系列玩法参考：Story Tickets、Avatar Challenge、Intimacy Check。<https://ikemen-revolution.fandom.com/wiki/Gameplay>
- Nikki 换装玩法参考：Styling Battle、服装属性和主题挑战。<https://lovenikki.fandom.com/wiki/Styling_Battle>
