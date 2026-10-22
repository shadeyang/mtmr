# `agentStatusList` 容器组件 —— 设计方案

> 状态：**设计已交付，尚未实现**
> 编写日期：2026-10-22
> 基线版本：build 484（`/Applications/MTMR.app`），commit `17e2d2c`
> 配置文件：`~/Library/Application Support/MTMR/items.json`（保存即热重载）
> 相关文档：`AGENTSTATUS.md`（单项组件）、`README.md`（用户契约）

---

## 0. 本次改动的两条硬性前提

### 0.1 必须是迭代扩展，不得破坏既有功能

`agentStatus` 已经在 build 484 交付并投入使用，**下面这些是既有行为，改动后必须逐一保持不变**：

| 既有行为 | 保持要求 |
|---|---|
| `{"type": "agentStatus"}` 单项用法 | 继续可用，解码结果不变 |
| 脚本 `--slot N` 与 `--json` 单会话输出 | **逐字节不变**（含 ANSI 彩色路径） |
| `TOOL_LABELS` / `classify()` 状态判定 | 不改判定逻辑，只在其外面多包一层 |
| 会话按「首次出现顺序」返回 | 不改成按活动时间排序 |
| agentStatus 三段布局、宽度自适应、无数据隐藏 | 组件内部逻辑一行不改 |
| `ShellScriptRunner` / `shellScriptQueue` | 复用，不重写 |
| 现有 5 个 agentStatus 槽位的 items.json 配置 | 继续可用（即便用户已迁移到容器，旧配置仍能跑） |

任何一条被破坏都算回归。**改动方式是新增 `agentStatusList` 类型，而不是改造 `agentStatus`。**

### 0.2 非 git 文件必须先备份

以下两个文件**不在 git 管理范围内**，回滚时没有历史可依，必须在动手前留基线：

| 文件 | 风险 |
|---|---|
| `~/Library/Application Support/MTMR/items.json` | 唯一运行时配置，改错只能靠备份还原 |
| `~/bin/touchbar_status.py` | 唯一数据源脚本，改错会静默导致所有 agentStatus 无数据 |

本次已完成的基线备份：

```
/tmp/mtmr-agentstatuslist-backup-20261022-172903/
├── files/
│   ├── items.json                    (2318 B)
│   └── touchbar_status.py            (6959 B, 保留可执行位)
└── 指针：/tmp/mtmr-agentstatuslist-backup-latest.txt
```

还原命令：

```bash
BK=/tmp/mtmr-agentstatuslist-backup-20261022-172903/files
cp "$BK/items.json" "$HOME/Library/Application Support/MTMR/items.json"
cp "$BK/touchbar_status.py" "$HOME/bin/touchbar_status.py"
chmod +x "$HOME/bin/touchbar_status.py"
```

> 备份在 `/tmp`，重启会丢。若本次改动跨越较长时间，应把 `files/` 一并拷到长期位置。

---

## 1. 任务范围

### 1.1 需求

把 `agentStatus` 作为另一个组件的单元元素 —— 一个「组件包」整合显示 N 个 agentStatus 的运行状态：

- **不做数量上限控制**
- **按启动的时间顺序**显示
- **折叠态**：默认最多显示 2 个；超出部分用一个数字表示还有多少个未显示（`+N` 徽标）
- **展开态**：在 TouchBar 上点击该组件 → 整个 TouchBar 展开，罗列所有 agentStatus；显示不全时仍可左右拖动
- **展开态最左边**固定一个退回按钮，点击回到折叠态

### 1.2 已核实的事实（本方案的复用依据）

| 事实 | 位置 |
|---|---|
| 整个 TouchBar 是**单个** `NSTouchBarItem`，其 `view` 是 `NSStackView(views:)`，spacing 8 | `TouchBarController.swift:189,198`、`BasicView.swift:38-40` |
| `GroupBarItem.showPopover` 已实现**接管整个 TouchBar** | `GroupBarItem.swift:42-68` |
| `ScrollViewItem` = `NSScrollView(documentView: stackView)`，**左右拖动已是现成能力** | `ScrollViewItem.swift` 全文 15 行 |
| 备选手势：`NSPanGestureRecognizer`（2/3/4 指） | `BasicView.swift:42-53` |
| 脚本已按**会话首次出现顺序**返回 | 脚本 `:127-128` |
| 每次脚本调用解析最多 2MB / 1 万行 | 脚本 `:49,52` |

### 1.3 不要重做

| 需求 | 为什么不用自己写 |
|---|---|
| 左右拖动 | `ScrollViewItem` 已是 `NSScrollView`，直接用 |
| 按启动时间顺序 | 脚本 `load_sessions()` **已经**这么排了，**不要**改成按活动时间 |
| agentStatus 三段布局 / 宽度自适应 / 无数据隐藏 / 状态映射 | 已实现且已修过多轮 bug，一个字不改 |
| 脚本执行与超时 | 复用 `ShellScriptRunner.execute(_:timeout:)` |
| 轮询骨架与 `[weak self]` 约定 | 复用 `AgentStatusBarItem.poll()` 的写法 |

---

## 2. ⚠️ 前置缺陷：契约缺会话 id

**这是功能前提，不是优化项。**

当前 5 字段契约（`project/status/detail/kind/age`）没有会话标识。现在能凑合，是因为每个 widget 的 `--slot N` 是写死的静态映射。但本需求是**动态 N 个**，届时：

```
第 3 轮轮询：会话 A 结束，会话 F 新建
脚本输出 [B, C, D, E, F]        ← 下标整体前移
widget[0] 原本显示 A，现在显示 B
widget[3] 原本显示 D，现在显示 E
```

**结果是用户看到内容随机跳动，且不报任何错。**

脚本里 `s["id"]` 本来就有，只是没输出。`--json-all` 模式**必须带 `id`**，容器**按 id 匹配子 widget，不按下标**。

---

## 3. 红线（违反后静默失效、不报错）

1. **`source` 必须可选（`SourceProtocol?`）** —— `barItemDefinitions()` 用 `try!`。必填会让现存只写 `{"type":"agentStatusList"}` 的配置解码抛错并**直接崩溃**。`shellScriptTitledButton` 的 `source` 是必填，**不能照抄它的必填写法**。
2. **子 widget 绝不能各自轮询** —— 每子项一次脚本调用 = 每轮重复解析 2MB × N。必须**容器单次轮询后分发**。
3. **按 `id` 匹配，不按下标** —— 见第 2 节。
4. **`width` 走 `applyConfiguredWidth(_:)`，不走 `CanSetWidth`** —— `CanSetWidth.setWidth` 只**新增**约束不覆盖，与隐藏用的 `width=0` 同时激活必然冲突。
5. **新方法不能叫 `setWidth`** —— 与 `extension NSCustomTouchBarItem: CanSetWidth` 同名同签名会被判为覆写扩展方法，编译报 *non-'@objc' instance method cannot be overridden*。
6. **展开/折叠必须复用同一批子 widget 实例** —— 重建会丢状态并触发重复轮询。切换时先 `removeFromSuperview()`（一个 view 只能有一个 superview）。
7. **新增 Swift 文件必须在 pbxproj 注册四处** —— PBXBuildFile、PBXFileReference、Widgets group、MTMR 的 Sources build phase。漏任一处**文件不参与编译且不报错**。
8. **`ItemType.identifierBase` 必须新增分支** —— 漏了 widget 不可达，且不会在别处报错。
9. **`Timer(target: self)` 禁用** —— 强引用 target 造成循环引用，实例永不释放，items.json 热重载后旧 widget 残留。用闭包 + `[weak self]`。

---

## 4. 数据契约

### 4.1 脚本新增 `--json-all`

输出**单个 JSON 数组**，每项带 `id`：

```json
[
  {"id":"51fe958f944e","project":"MTMR","status":"working","detail":"Shell","kind":"tool","age":"3m"},
  {"id":"7a2c9d04be1f","project":"other-app","status":"idle","detail":"","kind":"","age":"12s"}
]
```

| 字段 | 说明 |
|---|---|
| `id` | 会话 id，脚本内 `s["id"]` 已有，**本方案新增输出** |
| `project` / `status` / `detail` / `kind` / `age` | 与现有单会话契约完全一致，**不改动** |
| 数组顺序 | 会话首次出现顺序 = 启动时间顺序，**不得重排** |

### 4.2 Swift 侧

`AgentStatusBarItem.Payload` 增加 `let id: String`，其余字段与解码语义不变。

容器内部用：

```swift
private var children: [String: AgentStatusBarItem] = [:]   // session id → 子 widget
private var order: [String] = []                            // 启动顺序的 id 序列
```

---

## 5. 逐文件改动清单

### ① `~/bin/touchbar_status.py`（仓库外）

把现有 `render_json` 拆出可复用的字典构造，只多带 `id`：

```python
def render_dict(s):
    """agentStatus 单会话数据结构；--json 与 --json-all 共用"""
    token, detail, kind, _, _ = classify(s)
    return {
        "id": s["id"], "project": s["project"], "status": token,
        "detail": detail, "kind": kind, "age": age_label(s["age"]),
    }
```

`main()` 中新增分支，**放在 `load_sessions()` 之后、`--slot` 分支之前**：

```python
if "--json-all" in sys.argv:
    print(json.dumps([render_dict(s) for s in sessions], ensure_ascii=False))
    return
```

`--json` 单会话路径改为复用 `render_dict`，输出**完全等价**（回归项，见验收表）。

### ② `MTMR/ItemsParsing.swift`

在 `:279` 旁新增 case：

```swift
case agentStatusList(source: SourceProtocol?, refreshInterval: Double, compactCount: Int)
```

`ItemTypeRaw`（`:337` 附近）新增 `case agentStatusList`；`CodingKeys` 新增 `case compactCount`。

解码分支（`:435` 附近，`case .agentStatus` 之后）：

```swift
case .agentStatusList:
    let source = try container.decodeIfPresent(Source.self, forKey: .source)
    let interval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 5.0
    let compact = try container.decodeIfPresent(Int.self, forKey: .compactCount) ?? 2
    self = .agentStatusList(source: source, refreshInterval: interval, compactCount: compact)
```

### ③ `MTMR/Widgets/AgentStatusListBarItem.swift`（新文件，约 200 行）

```swift
final class AgentStatusListBarItem: NSCustomTouchBarItem, Widget {
    static var name = "agentStatusList"
    static var identifier = "com.toxblh.mtmr.agentStatusList."

    private var children: [String: AgentStatusBarItem] = [:]
    private var order: [String] = []
    private var badgeLabel = NSTextField(labelWithString: "")
    private var backButton: NSTouchBarItem?
    private var isExpanded = false
}
```

核心方法：

| 方法 | 职责 |
|---|---|
| `poll()` | 单次执行脚本 → 解析数组 → 按 id 更新/新建/回收子 widget |
| `reconcile(_ sessions: [Payload])` | 维护 `order` 与 `children`，append-only，新会话追加到末尾 |
| `switchMode(expanded:)` | 折叠 ⇄ 展开，只改 `NSStackView` 的 arrangedSubviews |
| `rebuildStack()` | 按当前模式重建 arrangedSubviews |
| `applyConfiguredWidth(_:)` / `applyVisibility()` | 照抄 `AgentStatusBarItem` 的同名实现 |

折叠态 arrangedSubviews：

```
[ child[order[0]].view ] [ child[order[1]].view ] [ badgeLabel ]     // N > 2 时才有 badge
```

展开态（外面套 `ScrollViewItem`）：

```
[ backButton ] [ child[order[0]].view ] [ child[order[1]].view ] … [ child[order[N-1]].view ]
```

### ④ `MTMR/TouchBarController.swift`

- `ItemType.identifierBase` 新增 `.agentStatusList` 分支
- `makeBarItem` 新增 case，构造 `AgentStatusListBarItem(identifier:source:interval:compactCount:)`
- `width` 应用处（约 `:415`）加分支，**先判具体类型**：

```swift
if let listItem = barItem as? AgentStatusListBarItem {
    listItem.applyConfiguredWidth(value)
} else if let agentStatusItem = barItem as? AgentStatusBarItem {
    agentStatusItem.applyConfiguredWidth(value)
} else if let widthBarItem = barItem as? CanSetWidth {
    widthBarItem.setWidth(value: value)
}
```

### ⑤ `MTMR/Widgets/AgentStatusBarItem.swift`

- `Payload` 增加 `let id: String`
- 新增 `apply(session:)`：由容器直接推送已解析好的 payload，**不自己轮询**
- 保留现有 `init(identifier:source:interval:)` 走自轮询路径，两种模式共存

### ⑥ `MTMR.xcodeproj/project.pbxproj`

新文件注册四处（见红线 7）。

### ⑦ `README.md`

新增 `agentStatusList` 章节。**README 是用户契约，任何新增配置键必须在同一次改动里补齐。**

### ⑧ items.json（仓库外）

把现有 5 个 `agentStatus` 槽替换为 1 个 `agentStatusList`。**替换前确认第 0.2 节备份已就位。**

---

## 6. 关键实现细节

### 为什么折叠/展开用 in-place 切换

`GroupBarItem.showPopover` 走的是 `dismissTouchBar` + `presentSystemModal`，会有消失再出现的闪烁。本组件两种状态都在同一个 `basicView` 内完成 —— 只改 `NSStackView` 的 arrangedSubviews，不碰 TouchBar 生命周期。展开态顶部的退回按钮也**不需要 dismiss**，直接切回折叠布局。

### 为什么复用同一批子 widget 实例

`ScrollViewItem` 直接取 `items.compactMap { $0.view }` 塞进 `NSScrollView`。展开时把**同一批 child 的 view 重新挂到滚动栈**即可 —— 不重建、不重复轮询、不丢状态。代价是切换时必须先从旧父视图移除。

### 徽标边界

- `hidden = order.count - compactCount <= 0`，此时徽标不占位
- `order.count <= compactCount` 时**整个容器不可点**（避免「点进去发现就这些」）
- 徽标文本 `+N`

### 会话回收

脚本不再输出某 `id`（会话结束）时：
- 折叠态：直接从 `order` 移除并 `removeFromSuperview()`
- 展开态正在显示时：同样移除，滚动位置需要 clamp 防止越界

**不要**用「墓碑占位」—— TouchBar 宽度有限，占位会让布局长期浪费空间。

### 拖动手势风险（最大未验证项）

`NSScrollView` 在 TouchBar item 内是否响应拖动，**必须真机确认**。若某些 macOS 版本上不响应，备选方案是复用 `BasicView.swift:42-53` 的 `NSPanGestureRecognizer`，手动改 `scrollView.contentView.scrollPoint`。

**这是本方案唯一没有把握的环节，建议先做最小验证再铺开实现。**

### 轮询开销反而下降

现状 5 个槽位各跑一次脚本 = 每轮解析 5 次日志。改成容器单次轮询分发后，**开销从 5× 降到 1×**，且与会话数量无关。

---

## 7. 验收标准

| 验收项 | 本机可验证 | 需 TouchBar 硬件 |
|---|:-:|:-:|
| 脚本 `--json-all` 输出合法 JSON 数组、含 `id`、顺序为启动顺序 | ✅ | — |
| **回归**：脚本 `--json` 单会话输出与改动前完全一致 | ✅ | — |
| **回归**：脚本 ANSI 彩色输出与改动前完全一致 | ✅ | — |
| `{"type":"agentStatusList"}` 无 source 时不崩溃 | ✅ | — |
| **回归**：`{"type":"agentStatus"}` 仍能解码且行为不变 | ✅ | — |
| **回归**：现有 5 槽位 items.json 仍能正常加载 | ✅ | — |
| 新增解码单测（`agentStatusList` 带 / 不带 source / compactCount 缺省） | ✅ | — |
| 构建通过 + 既有 13 个单测全绿 | ✅ | — |
| 折叠态显示 2 个 + `+N` | ❌ | ✅ |
| 展开态全屏罗列、最左有退回按钮 | ❌ | ✅ |
| 展开态左右拖动 | ❌ | ✅ |
| 点击退回恢复折叠态 | ❌ | ✅ |
| 会话增删时内容不错位（按 id 匹配生效） | ❌ | ✅ |

可执行验证：

```bash
# 数据源
python3 ~/bin/touchbar_status.py --json-all | python3 -m json.tool | head -20
python3 ~/bin/touchbar_status.py --slot 0 --json          # 回归
python3 ~/bin/touchbar_status.py --slot 0 | cat -v        # ANSI 回归

# 构建与测试
xcodebuild -project MTMR.xcodeproj -scheme MTMR -configuration Debug \
  -destination 'platform=macOS,arch=arm64' ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  MACOSX_DEPLOYMENT_TARGET=12.0 CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="" ENABLE_HARDENED_RUNTIME=NO -derivedDataPath /tmp/mtmr-dd build

xcodebuild test -project MTMR.xcodeproj -scheme 'UnitTests'
```

---

## 8. 参考实现位置

| 需要什么 | 去哪抄 |
|---|---|
| 接管 / 切回整个 TouchBar | `GroupBarItem.swift:42-68` |
| 左右拖动容器 | `ScrollViewItem.swift`（全文 15 行） |
| 备用的拖动手势 | `BasicView.swift:42-53`（2/3/4 指 `NSPanGestureRecognizer`） |
| 单次轮询 + 分发 | `AgentStatusBarItem.poll()`（已用 `[weak self]` + `shellScriptQueue`） |
| 宽度自持 + 无数据隐藏 | `AgentStatusBarItem.applyConfiguredWidth(_:)` / `applyVisibility()` |
| 状态符号与颜色映射 | `AgentStatusBarItem.presentation(for:)` / `style(for:)` |
| 子项数据更新 | `AgentStatusBarItem.update(project:status:age:statusColor:)` |
| 新 widget 的三个隐性坑 | 记忆 `mtmr-newwidget-registration-pitfalls` |
| 宽度约束冲突的来龙去脉 | 记忆 `mtmr-custombutton-width-conflict` |

---

## 9. 待决定的问题（实现前需要确认）

1. **展开态是「只有列表 + 退回按钮」还是「保留原有亮度/音量等条目」？**
   当前按需求原文「全 TouchBar 展开、罗列所有 agentStatus」理解为**完全替换**。

2. **折叠态宽度怎么定？** —— **已定（2026-10-22）：子项定宽 + 容器总宽按子项求和。**
   2 个自适应 agentStatus + 徽标 → 宽度不可预测，故新增 `itemWidth` 键定**每个子组件的固定宽度**；
   容器总宽 = 可见子项宽度求和（含徽标），**只剩一个会话时容器宽度就等于那一个子组件的宽度**。
   原 `width` 键**降级为容器总宽上限**：放不下时从尾部少显示几个子项并计入 `+N` 徽标，
   **不压缩已显示的子项** —— 子项宽度是 required 约束，压缩会直接撞上宽度约束冲突。
   不写 `itemWidth` 时完整保留旧行为（子项内容自适应，`width` 作容器总宽）。

3. **`+N` 徽标是否可点，还是只有容器主体可点？**
   当前按「点击该组件」实现为容器整体可点，徽标属于容器一部分。

4. **`compactCount` 是否要做成可配置键？**
   方案默认 2。若固定为 2 可省掉一个配置键，但用户明确说过「默认最多只显示两个」——「默认」二字暗示可改。

---

## 10. 回滚

| 范围 | 方式 |
|---|---|
| 仓库内文件 | `git checkout -- <路径>`，或退到 tag `agentstatus-data-source-2026-10-22`（build 484 状态） |
| `items.json` | 用第 0.2 节备份覆盖 |
| `touchbar_status.py` | 用第 0.2 节备份覆盖，并 `chmod +x` |

**回滚后必须重新部署到 `/Applications` 并验证二进制**，构建机为 Mac14,7 无 TouchBar，
本机只能验到「编译通过 + 契约测试通过」，**视觉一律需在有 TouchBar 的机器上确认**。