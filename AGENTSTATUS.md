# `agentStatus` 组件使用说明

> 适用版本：**build 459**（本机 `/Applications/MTMR.app`）
> 配置文件：`~/Library/Application Support/MTMR/items.json`（保存即生效，MTMR 会热重载）
> 源文件：`MTMR/Widgets/AgentStatusBarItem.swift`
> 编写日期：2026-10-22

---

## 1. 组件是什么

TouchBar 上的一条三段式状态栏，用于显示编码 agent 的当前活动：

```
╭──────────────────────────────────────────────────╮
│  项目名（可滚动）        ┃ 状态 ┃    时长          │
╰──────────────────────────────────────────────────╯
   ←──── 吸收全部余量 ────→  ↑     ↑
                          按内容  按内容
```

- 整体：三个段共用**一个圆角背景**（圆角半径 6pt，`bordered: false` 时背景透明）
- 分割：段与段之间各有一条 **1pt 竖线**，高 15pt（行高的一半），白色 22% 透明度
- 内边距：三段**各自左右各留 10pt**（`segmentPadding`）
- **中段与右段按内容自适应**：宽度 = 该段文本实测宽度 + 20pt（两侧各 10pt），
  且禁止伸缩（hugging 与抗压缩均为 required）。状态符号短、时长文本长短不一，
  两段各自贴合自己的内容，不会互相挤占
- **左段吸收全部余量**：hugging 与抗压缩都设为 `defaultLow`，
  所以总宽有余时它先增长，空间不足时它最先被压窄
- **总宽度不变**：由 items.json 的 `width` 固定，三段宽度之和恒等于它
- 左段：项目名，超长时**跑马灯滚动**而非截断
- 中段：状态符号 + 颜色
- 右段：已活动时长

**同一水平线**：三个标签都是 `NSTextField`、同一字号、且被约束为**等高 30pt** 并在各自
段内垂直居中。几何完全一致，因此文字基线落在同一条线上。

字体统一 15pt Regular 白字。

**不可点击** —— 它继承 `NSCustomTouchBarItem`，**不支持 `actions`**。

---

## 2. 当前版本实际生效的配置键

| 键 | 类型 | 默认 | 生效 | 说明 |
|---|---|---|---|---|
| `type` | string | — | ✅ | 固定填 `"agentStatus"` |
| `align` | `"left"` / `"center"` / `"right"` | `"center"` | ✅ | 贴哪一侧。默认居中 |
| `width` | number | 见 §4 | ✅ | **整个 widget** 的宽度，单位 pt |
| `bordered` | bool | `true` | ✅ | `false` 时去掉圆角背景，仅保留竖线分割 |
| `matchAppId` | string | — | ✅ | 正则。仅当前台 app 的 bundle id 匹配时显示 |

**注意**：`background`、`image`、`title` 对本组件**无效** —— 这些键只对
`CustomButtonTouchBarItem` 生效，本组件不是它的子类。`actions` / `action` /
`longAction` 同理，解析了但不会挂上。

---

## 3. ⚠️ 当前**写了也没用**的键

这一节最重要，否则会白写配置。

| 键 | 状态 | 后果 |
|---|---|---|
| `source` | **未实现** | 被静默忽略，无任何报错 |
| `refreshInterval` | **未实现** | 被静默忽略，无任何报错 |

原因：`ItemType.agentStatus` 目前**没有关联值**，解码分支
（`MTMR/ItemsParsing.swift:435-436`）是：

```swift
case .agentStatus:
    self = .agentStatus
```

`JSONDecoder` 会忽略 `CodingKeys` 之外的键。写 `"source": {...}` 不报错、不警告、也不生效。

**因此：当前版本无论怎么配这个组件，TouchBar 上永远是占位值
`agent` / `○` / `--`（写死在 `MTMR/Widgets/AgentStatusBarItem.swift:32-33`）。**

---

## 4. 宽度计算

`width` 固定的是**整个圆角背景**的总宽。三段宽度之和恒等于它：

```
总宽 = 左段 + 1 + 中段 + 1 + 右段

中段 = ceil(状态文本宽度) + 20
右段 = ceil(时长文本宽度) + 20
左段 = 总宽 - 中段 - 右段 - 2
```

**左段是唯一可变的**。状态与时长换文本时，中段/右段宽度随之变化，
左段自动补足差额 —— 总宽不变，项目名段的可用宽度随内容浮动。

| `width` | 左段可用宽度（状态 `●`、时长 `3m` 时） | 说明 |
|---|---|---|
| 260 | 约 155 | 长项目名，不需要滚动 |
| 226 | 约 121 | 常用值 |
| 180 | 约 75 | 多数项目名会触发滚动 |
| 150 | 约 45 | 只适合短名字 |

左段有 **40pt 下限**（`minimumProjectWidth`）。`width` 过小以致左段压到 40pt 以下时，
会出现约束冲突日志且布局异常 —— 此时把 `width` 调大，或缩短时长文本的格式。

未设 `width` 时，左段的 120pt 约束存在但优先级是 `defaultHigh`（750），
容器宽度由 Auto Layout 按内容推导。**实际默认总宽需在有 TouchBar 的机器上目视确认**
—— 无 TouchBar 硬件的开发机无法验证。若布局异常，显式给一个 `width` 即可确定行为。

`width` 建议不小于 150 —— 再小会把左段压到 40pt 下限以下。

---

## 5. 跑马灯滚动行为

- **触发条件**：`项目名渲染宽度 > 左段可视宽度` **且** `项目名字符数 ≥ 2`
- **节拍**：0.25 秒字符轮转一次（`AgentStatusBarItem.swift:21`）
- 项目名变短后自动停表并恢复完整显示
- 判定发生在 `DispatchQueue.main.async` 里，因为要等 Auto Layout 算完才知道是否溢出

**⚠️ 一个会影响观感的坑（给接入层实现者）**：`update()` 每次调用都会先停表再重新评估
（`:99` → `:113`）。如果数据接入层每轮轮询都无条件调 `update()`，跑马灯会
**每 5 秒被重置回项目名开头**，表现为反复从头滚。接入层必须
**先比对 project/status/age 三值，仅在变化时才调 `update()`**。

---

## 6. items.json 示例

放进 preset 数组里即可：

```json
[
  { "type": "agentStatus", "align": "left", "width": 200 }
]
```

带 app 过滤和居中：

```json
[
  {
    "type": "agentStatus",
    "align": "center",
    "width": 240,
    "matchAppId": "com.googlecode.iterm2|com.mitchellh.ghostty"
  }
]
```

放在 `group` 里（可与其它按钮组合）：

```json
[
  {
    "type": "group",
    "items": [
      { "type": "escape" },
      { "type": "agentStatus", "width": 200 }
    ]
  }
]
```

⚠️ `matchAppId` 里的 `|` 是正则或运算。JSON 字符串中反斜杠需转义（`\\.`）。

---

## 7. 热重载行为

- `items.json` 保存后 MTMR 立即重建整个 TouchBar，**无需重启 app**
- 若改动**不涉及** `agentStatus` 这一条，实例会被保留
  （`TouchBarController.didItemsChange` 判定，见 commit `06325ba`），跑马灯不会被打断
- 只要改了 `agentStatus` 条目的内容（哪怕只是顺序），identifier 会重新生成
  （`identifierBase + timestamp + UUID`），旧实例销毁、新实例重建，滚动位置归零
- **没有去重机制** —— 写两条 `agentStatus` 就是两个 widget，各自独立

---

## 8. 待实现部分的契约

以下**尚未实现**，是数据接入层需要落地的部分。目标形态：

```json
{
  "type": "agentStatus",
  "align": "left",
  "width": 200,
  "source": { "filePath": "~/.config/mtmr-agent-status.sh" },
  "refreshInterval": 5
}
```

`source` 复用已有的 `Source` 结构，支持 `filePath` / `inline` / `base64`，`~` 自动展开。
MTMR 会用 `$SHELL -c`（回退 `/bin/bash`）周期性执行它。

### 8.1 脚本 stdout 契约 —— 单行 JSON，三个字段全部必填

```json
{"project": "MTMR", "status": "working", "age": "3m"}
```

- `project`：项目名原文，**不截断**（超长时由跑马灯处理）
- `status`：下表中的 token 之一
- `age`：已渲染好的短字符串（如 `3m`、`1h20m`、`--`），
  **由脚本负责格式化**，Swift 侧不做时间计算

### 8.2 status token → 符号 + 颜色映射

符号与颜色由 **Swift 侧** 映射，不要让脚本输出符号或颜色 ——
AppKit 类型不外泄到 shell 层。

| token | 符号 | `NSColor` | 含义 |
|---|---|---|---|
| `idle` | `○` | `.systemGray` | 空闲 |
| `working` | `●` | `.systemGreen` | 执行中 |
| `waiting` | `◐` | `.systemOrange` | 等待用户输入 |
| `done` | `✓` | `.systemBlue` | 已完成 |
| `error` | `✗` | `.systemRed` | 出错 |
| 其它 / 缺失 | `●` | `.white` | 兜底 |

### 8.3 运行时约束

- 脚本必须以 **exit 0** 结束，否则视为失败，保留上一次成功显示
- 脚本耗时必须**显著小于** `refreshInterval` —— 超时会被 MTMR 按间隔强杀
- `refreshInterval` 建议不低于 3 秒
- 脚本输出恰好是 `error` 这一行会被判为失败

### 8.4 实现要点速查

| 需要的东西 | 参考实现位置 |
|---|---|
| 脚本执行 + 超时终止 + 失败判定 | `MTMR/ShellScriptTouchBarItem.swift:93` `execute(_:)` |
| 轮询调度骨架 | `MTMR/ShellScriptTouchBarItem.swift:37` `refreshAndSchedule()` |
| serial queue | `MTMR/ShellScriptTouchBarItem.swift:135` `DispatchQueue.shellScriptQueue` |
| JSON 解码结构体写法 | `MTMR/ShellScriptTouchBarItem.swift:15` `ScriptResult` |
| `Source`（filePath/inline/base64 + `~` 展开） | `MTMR/ItemsParsing.swift`，`struct Source` |
| 跑马灯字符轮转 | `MTMR/Widgets/MusicBarItem.swift`，`marquee()` |

三条红线：

1. `init(identifier:)` 必须写 `override` —— `NSCustomTouchBarItem` 已声明该指定初始化器
2. 新建源文件必须在 `project.pbxproj` 注册**四处**（PBXBuildFile / PBXFileReference /
   Widgets group / Sources build phase），漏任何一处文件不参与编译且**不报任何错**。
   建议直接把代码写进已有的 `AgentStatusBarItem.swift`，规避此风险
3. 轮询用 `[weak self]`，**不要**用 `Timer(target: self)` —— 强引用会阻止 dealloc，
   导致 items.json 热重载替换实例后脚本永远停不下来

---

## 9. 自检清单

- [ ] 是否只用了 §2 里列出的键（`type` / `align` / `width` / `matchAppId`）？
      其余键对本组件无效
- [ ] 是否清楚当前无法显示真实数据？§3 是硬约束
- [ ] `width` 是否按 §4 的公式留足左段空间（`width ≥ 160` 起步）？
- [ ] 期望的显示效果若依赖真实数据，是否已注明依赖尚未实现的接入层？
- [ ] 是否知道开发机（Mac14,7，13" M2）**没有 TouchBar 硬件**，
      本机只能验证配置解析，不能验证渲染？

---

## 10. 已知接线位置

已完成的接线（**勿重复实现**）：

| 位置 | 内容 |
|---|---|
| `MTMR/Widgets/AgentStatusBarItem.swift:12` | `class AgentStatusBarItem: NSCustomTouchBarItem, Widget` |
| `MTMR/Widgets/AgentStatusBarItem.swift:99` | `update(project:status:age:statusColor:)` —— 接入层入口 |
| `MTMR/ItemsParsing.swift:279` | `case agentStatus` |
| `MTMR/ItemsParsing.swift:337` | `ItemTypeRaw.agentStatus` |
| `MTMR/ItemsParsing.swift:435-436` | 解码分支 |
| `MTMR/TouchBarController.swift:62-63` | `identifierBase` |
| `MTMR/TouchBarController.swift:389-390` | `createItem` 构造 |
| `README.md` | `#### agentStatus` 段落 |
| `MTMRTests/ParseConfigTests.swift` | `testAgentStatus` |

---

**一句话总结**：这个组件目前是一个**渲染好但没有数据源的空壳**。
`items.json` 里只有 `type` / `align` / `width` / `matchAppId` 生效；
要显示真实的项目名、状态和时长，还需要先实现 §8 描述的数据接入层。