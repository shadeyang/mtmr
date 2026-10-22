//
//  AgentStatusListBarItem.swift
//  MTMR
//
//  Copyright © 2018 Anton Palgunov. All rights reserved.
//

import AppKit

/// agentStatus 容器：把 N 个 `AgentStatusBarItem` 作为单元元素整合显示。
///
/// 折叠态显示前 `compactCount` 个，超出部分用 `+N` 徽标表示还有多少个未显示；
/// 点击容器展开，在 TouchBar 上罗列全部并可左右拖动，最左侧一个退回按钮。
///
/// 宽度策略：`itemWidth` 定每个子组件的固定宽度，不写则各子项按内容自适应。
/// 折叠态**恒显示前 `compactCount` 个**会话，不因宽度不足少显示 —— 容器总宽 =
/// 可见子项宽度求和 + 徽标，所以只剩一个会话时容器宽度就等于那一个子项的宽度。
/// `width` 只管展开态：作为展开容器总宽的上限，避免吃掉整条 TouchBar 挤压旁边的元素。
///
/// 容器**单次轮询**脚本后按 session id 分发 —— 子项一律不自行轮询，否则每个子项
/// 一次调用等于每轮重复解析整份日志。匹配靠 `id` 不靠下标：会话集合会增删，
/// 按下标匹配每轮都会错位（详见 AGENTSTATUSLIST.md 第 2 节）。
class AgentStatusListBarItem: NSCustomTouchBarItem, Widget, CanSetBordered {
    static var name: String = "agentStatusList"
    static var identifier: String = "com.toxblh.mtmr.agentStatusList."

    /// 容器自身没有可见外框，这个开关下发给每个子项
    var isBordered: Bool = true

    /// 脚本 `--json-all` 输出数组中的一项
    private struct Session: Decodable {
        let id: String
        let project: String
        let status: String
        let detail: String?
        let kind: String?
        let age: String
    }

    private static let badgeFont = NSFont.systemFont(ofSize: 15, weight: .semibold)
    private static let backFont = NSFont.systemFont(ofSize: 17, weight: .regular)
    private static let backWidth: CGFloat = 44
    private static let spacing: CGFloat = 8
    private static let minimumBadgeWidth: CGFloat = 20
    /// 展开态滚动区下限：NSScrollView 没有固有尺寸，给 0 会塌成一条缝
    private static let minimumScrollWidth: CGFloat = 120
    /// 展开态子项之间的间距，与 ScrollViewItem 内 stack 的 spacing 保持一致
    private static let innerSpacing: CGFloat = 1
    /// 展开态取不到 window 宽度时的兜底（13"/15" TouchBar 均为 1085pt）
    private static let fallbackBarWidth: CGFloat = 1085

    private let scriptSource: String?
    private let interval: TimeInterval
    private let compactCount: Int

    private var children: [String: AgentStatusBarItem] = [:]
    /// 会话 id 的**首次出现顺序** = 启动顺序，只追加不重排
    private var order: [String] = []
    private var isExpanded = false

    private let stack = NSStackView()
    private let badge = NSTextField(labelWithString: "")
    private var backItem: NSCustomTouchBarItem?
    private var scrollWidthConstraint: NSLayoutConstraint?
    /// 展开态的滚动容器跨重建存活 —— 重建会连带丢掉用户的滚动位置
    private var expandedScrollItem: ScrollViewItem?
    private var clickProxy: ClickProxy?

    /// 手势识别器会**强引用** target。直接传 self 会形成
    /// `self → view → recognizer → self` 的环，实例永不释放：items.json 热重载后
    /// 旧容器残留在 TouchBar 上，新旧两个容器叠着显示。代理只持弱引用。
    private final class ClickProxy: NSObject {
        private weak var owner: AgentStatusListBarItem?
        init(owner: AgentStatusListBarItem) { self.owner = owner }

        @objc func handleTap() { owner?.toggleExpanded() }
        @objc func handleCollapse() { owner?.collapse() }
    }

    /// 自有宽度约束，不走 CanSetWidth —— 那条路径只新增约束不覆盖，
    /// 与隐藏用的 width=0 同时激活会冲突（见 mtmr-custombutton-width-conflict.md）
    private var widthConstraint: NSLayoutConstraint!
    /// items.json 的 itemWidth：每个子组件的固定宽度。nil → 子组件按内容自适应
    private var itemWidth: CGFloat?
    /// items.json 的 width：容器总宽上限，不是强制值
    private var configuredWidth: CGFloat?

    init(identifier: NSTouchBarItem.Identifier, source: SourceProtocol?, interval: TimeInterval, compactCount: Int) {
        self.scriptSource = source?.string
        self.interval = interval
        self.compactCount = max(1, compactCount)
        super.init(identifier: identifier)
        view = makeView()
        // 起始即无会话 → 宽度 0，不占位
        widthConstraint = view.widthAnchor.constraint(equalToConstant: 0)
        widthConstraint.isActive = true

        guard scriptSource != nil else { return }
        DispatchQueue.shellScriptQueue.async { [weak self] in
            self?.poll()
        }
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        scrollWidthConstraint?.isActive = false
    }

    // MARK: - 轮询

    /// 运行在 shellScriptQueue（串行）上；下一轮同样挂回该队列，
    /// 用 [weak self] 让 items.json 热重载替换实例后自然终止
    private func poll() {
        guard let scriptSource = scriptSource else { return }

        let (output, succeeded) = ShellScriptRunner.execute(scriptSource, timeout: interval)
        // 脚本失败或输出不合约时保留上一次的子项，不清空
        if succeeded, let sessions = AgentStatusListBarItem.decodeAll(output) {
            DispatchQueue.main.async { [weak self] in
                self?.reconcile(sessions)
            }
        }

        DispatchQueue.shellScriptQueue.asyncAfter(deadline: .now() + interval) { [weak self] in
            self?.poll()
        }
    }

    private static func decodeAll(_ output: String) -> [Session]? {
        guard !output.isEmpty, let data = output.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([Session].self, from: data)
    }

    /// 主线程。按 id 新建 / 更新 / 回收子项；`order` 只追加，保持启动顺序稳定。
    private func reconcile(_ sessions: [Session]) {
        var alive = Set<String>()
        var structureChanged = false

        for session in sessions {
            alive.insert(session.id)

            let child: AgentStatusBarItem
            if let existing = children[session.id] {
                child = existing
            } else {
                let id = NSTouchBarItem.Identifier(AgentStatusBarItem.identifier.appending(session.id))
                child = AgentStatusBarItem(identifier: id)
                child.isBordered = isBordered
                // 配了 itemWidth 就给子项定宽；未定宽时保持内容自适应
                if let itemWidth = itemWidth {
                    child.applyConfiguredWidth(itemWidth)
                }
                children[session.id] = child
                order.append(session.id)
                structureChanged = true
            }

            // 显式声明「有数据」—— 子项自身不轮询，不声明的话会被压成 0 宽
            // 而与它内部的内容最小宽度约束冲突，Auto Layout 只能任意断一条
            child.provideContainerData()

            // 复用 AgentStatusBarItem 的同一份符号/颜色映射，两条路径不会漂移
            let display = AgentStatusBarItem.presentation(
                status: session.status,
                detail: session.detail,
                kind: session.kind
            )
            child.update(project: session.project, status: display.text, age: session.age, statusColor: display.color)
        }

        // 已结束的会话：不在墓碑里留位，TouchBar 宽度有限，空占位是浪费
        let ended = order.filter { !alive.contains($0) }
        for id in ended {
            children[id]?.view.removeFromSuperview()
            children[id] = nil
            order.removeAll { $0 == id }
            structureChanged = true
        }

        // 只有结构（会话集合/顺序）变了才重建布局。纯数据刷新由子项就地改文本，
        // 不必动 stack —— 每轮都 rebuild 会把展开态的 NSScrollView 重建一次，
        // 用户滑到的位置就被弹回最前面。
        if structureChanged {
            rebuild()
        } else {
            applyVisibility()
        }
    }

    // MARK: - 布局

    private func makeView() -> NSView {
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.distribution = .fill
        stack.spacing = AgentStatusListBarItem.spacing
        stack.translatesAutoresizingMaskIntoConstraints = false

        badge.font = AgentStatusListBarItem.badgeFont
        badge.alignment = .center
        badge.textColor = .white
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.isHidden = true
        badge.widthAnchor.constraint(greaterThanOrEqualToConstant: AgentStatusListBarItem.minimumBadgeWidth).isActive = true

        let host = NSView()
        host.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            stack.topAnchor.constraint(equalTo: host.topAnchor),
            stack.bottomAnchor.constraint(equalTo: host.bottomAnchor),
        ])

        host.addGestureRecognizer(
            NSClickGestureRecognizer(target: clickTarget(), action: #selector(ClickProxy.handleTap))
        )
        return host
    }

    /// 折叠 / 展开只改 arrangedSubviews —— 不碰 TouchBar 生命周期，
    /// 避免 GroupBarItem 那种 dismiss + presentSystemModal 的消失再出现闪烁。
    /// 子 view 在两种模式间**复用同一批实例**（一个 view 只能有一个 superview，
    /// 所以先全部摘掉再重新挂）。
    private func rebuild() {
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        // 上面那轮只摘了容器这一层；展开态的子 view 还挂在滚动容器的 stack 上。
        // 不显式摘掉的话，折叠态把它们加进本容器时会同时存在于两棵视图树里
        expandedScrollItem?.replaceItems([])
        scrollWidthConstraint?.isActive = false

        guard !order.isEmpty else {
            applyVisibility()
            return
        }

        if isExpanded {
            rebuildExpanded()
        } else {
            rebuildCollapsed()
        }
        applyVisibility()
    }

    private func rebuildCollapsed() {
        let layout = collapsedLayout()

        for id in layout.ids {
            guard let view = children[id]?.view else { continue }
            stack.addArrangedSubview(view)
        }

        badge.isHidden = layout.overflow <= 0
        if !badge.isHidden {
            badge.stringValue = "+\(layout.overflow)"
            stack.addArrangedSubview(badge)
        }
    }

    /// 折叠态显示哪些子项：恒为前 `compactCount` 个，其余进 `+N` 徽标。
    /// **不因宽度不足少显示** —— 早先按 `width` 上限砍子项时，子项未定宽、宽度随内容
    /// 浮动，正好卡在上限附近就会在「显示 2 个」和「只显示 1 个」之间反复跳。
    private func collapsedLayout() -> (ids: [String], overflow: Int) {
        let ids = Array(order.prefix(compactCount))
        return (ids, order.count - ids.count)
    }

    /// 折叠态所需总宽 = 各子项宽度之和 + 徽标宽 + 间距
    private func collapsedWidth(ids: [String], overflow: Int) -> CGFloat {
        let badgeWidth = overflow > 0 ? measuredBadgeWidth(overflow: overflow) : 0
        let pieces = ids.count + (badgeWidth > 0 ? 1 : 0)
        guard pieces > 0 else { return 0 }
        return ids.reduce(CGFloat(0)) { $0 + childWidth($1) }
            + badgeWidth
            + CGFloat(pieces - 1) * AgentStatusListBarItem.spacing
    }

    /// 单个子项的宽度：定宽就是 itemWidth，未定宽取实测值。
    /// 实测是必须的 —— 未定宽时子项内容自适应，算不出总宽就没法跟 `width` 上限比。
    private func childWidth(_ id: String) -> CGFloat {
        if let itemWidth = itemWidth { return itemWidth }
        return children[id]?.view.fittingSize.width ?? 0
    }

    /// 徽标宽度取实测值（+N 的位数会变），但不低于徽标自身的最小宽约束
    private func measuredBadgeWidth(overflow: Int) -> CGFloat {
        badge.stringValue = "+\(overflow)"
        return max(AgentStatusListBarItem.minimumBadgeWidth, ceil(badge.fittingSize.width))
    }

    private func rebuildExpanded() {
        let back = makeBackItem()
        backItem = back
        stack.addArrangedSubview(back.view)

        let items = order.compactMap { children[$0] }

        if let existing = expandedScrollItem {
            // 就地换内容并把滚动位置放回去，不重建容器
            let clip = (existing.view as? NSScrollView)?.contentView
            let origin = clip?.bounds.origin ?? .zero
            existing.replaceItems(items)
            clip?.scroll(to: origin)
            // rebuild() 已把本容器 stack 清空过了，复用旧滚动容器时必须重新挂回去 ——
            // 漏了这行会导致第二次及以后的每次展开都只剩回退按钮
            stack.addArrangedSubview(existing.view)
        } else {
            let scroller = ScrollViewItem(
                identifier: NSTouchBarItem.Identifier(AgentStatusListBarItem.identifier.appending("scroll.")),
                items: items
            )
            expandedScrollItem = scroller
            stack.addArrangedSubview(scroller.view)

            // NSScrollView 无固有尺寸，给一个确定宽度，否则会塌成 0
            let constraint = scroller.view.widthAnchor.constraint(equalToConstant: AgentStatusListBarItem.minimumScrollWidth)
            constraint.isActive = true
            scrollWidthConstraint = constraint
        }
        // 会话增减后所需宽度会变，两条分支都得重算。rebuild() 开头停用过这条约束，
        // 复用旧容器时必须重新激活，否则再次展开后滚动区会塌成 0
        scrollWidthConstraint?.isActive = true
        scrollWidthConstraint?.constant = expandedScrollWidth()
    }

    /// 展开态滚动区宽度：全部子项宽度求和，再按「配置的 `width` 与 TouchBar 实测宽度
    /// 取更小者」封顶。展开态要占一条 TouchBar，不封顶会把旁边的元素整个挤掉。
    private func expandedScrollWidth() -> CGFloat {
        let chrome = AgentStatusListBarItem.backWidth + AgentStatusListBarItem.spacing
        let needed = order.reduce(CGFloat(0)) { $0 + childWidth($1) }
            + CGFloat(max(0, order.count - 1)) * AgentStatusListBarItem.innerSpacing
        let limit = min(configuredWidth ?? AgentStatusListBarItem.fallbackBarWidth, barWidth) - chrome
        return max(AgentStatusListBarItem.minimumScrollWidth, min(needed, limit))
    }

    /// 展开态铺满整条 TouchBar，宽度取承载 window 的实测值
    private var barWidth: CGFloat {
        let windowWidth = view.window?.frame.width ?? 0
        return windowWidth > 0 ? windowWidth : AgentStatusListBarItem.fallbackBarWidth
    }

    private func makeBackItem() -> NSCustomTouchBarItem {
        let label = NSTextField(labelWithString: "‹")
        label.font = AgentStatusListBarItem.backFont
        label.textColor = .white
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        let host = NSView()
        host.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(label)
        NSLayoutConstraint.activate([
            host.widthAnchor.constraint(equalToConstant: AgentStatusListBarItem.backWidth),
            label.centerXAnchor.constraint(equalTo: host.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: host.centerYAnchor),
        ])

        let item = NSCustomTouchBarItem(identifier: NSTouchBarItem.Identifier(AgentStatusListBarItem.identifier.appending("back.")))
        item.view = host
        host.addGestureRecognizer(
            NSClickGestureRecognizer(target: clickTarget(), action: #selector(ClickProxy.handleCollapse))
        )
        return item
    }

    // MARK: - 交互

    private func clickTarget() -> ClickProxy {
        if let proxy = clickProxy { return proxy }
        let proxy = ClickProxy(owner: self)
        clickProxy = proxy
        return proxy
    }

    func toggleExpanded() {
        // 会话数不超过折叠上限时没什么可展开的，点击无意义
        guard order.count > compactCount else { return }
        isExpanded = true
        rebuild()
    }

    func collapse() {
        isExpanded = false
        backItem?.view.removeFromSuperview()
        rebuild()
    }

    // MARK: - 宽度

    /// 由 TouchBarController 走 CanSetBordered 调用；容器自身无外框，下发给全部子项
    func setBordered(_ value: Bool) {
        isBordered = value
        children.values.forEach { $0.isBordered = value }
    }

    /// 由 TouchBarController 优先于 CanSetWidth 调用，避免叠加第二条宽度约束。
    /// 刻意不叫 setWidth —— 该名字已被 NSCustomTouchBarItem 的 CanSetWidth 扩展占用。
    ///
    /// 这里只是**上限**：容器宽度由可见子组件求和决定，放不下时少显示几个子组件，
    /// 而不是把已经显示的子组件压窄 —— 子组件宽度由 itemWidth 定死，不受容器影响。
    func applyConfiguredWidth(_ value: CGFloat) {
        configuredWidth = value
        if isExpanded {
            rebuild()
        } else {
            applyVisibility()
        }
    }

    /// 每个子组件的固定宽度。必须在 reconcile 建出子项之前调用，否则先建出来的
    /// 子项会停在内容自适应上；这里也会把已存在的子项一并改过来。
    func applyItemWidth(_ value: CGFloat) {
        guard value != itemWidth else { return }
        itemWidth = value
        children.values.forEach { $0.applyConfiguredWidth(value) }
        rebuild()
    }

    /// 容器宽度：无会话归零；否则恒等于可见子组件的宽度求和（含徽标）——
    /// 因此只剩一个会话时，宽度就等于那一个子组件的宽度。
    /// `width` 只在放不下时起作用：少显示几个子项，而不是把子项压窄。
    private func applyVisibility() {
        guard !order.isEmpty else {
            setContainerWidth(0)
            return
        }
        if isExpanded {
            setContainerWidth(AgentStatusListBarItem.backWidth + AgentStatusListBarItem.spacing
                + (scrollWidthConstraint?.constant ?? AgentStatusListBarItem.minimumScrollWidth))
            return
        }
        let layout = collapsedLayout()
        setContainerWidth(collapsedWidth(ids: layout.ids, overflow: layout.overflow))
    }

    private func setContainerWidth(_ width: CGFloat) {
        widthConstraint.constant = width
        widthConstraint.isActive = true
    }
}