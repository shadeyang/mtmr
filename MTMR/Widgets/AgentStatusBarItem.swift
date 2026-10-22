//
//  AgentStatusBarItem.swift
//  MTMR
//
//  Copyright © 2018 Anton Palgunov. All rights reserved.
//

import AppKit

/// 三段式 agent 状态视图：左侧项目名、中间状态（当前在跑的 tool/agent）、右侧活动时间。
/// 三段共处一个圆角背景内，段间以竖线分隔，体现「整体」与「元素分割」。
///
/// 宽度策略：状态段与时长段按各自文本实测宽度加内边距定宽，并禁止伸缩；
/// 项目段吸收全部余量。整体总宽由 items.json 的 `width` 固定。
/// 项目名一律从名称开头显示，超出可视宽度直接裁切，不做滚动。
///
/// 数据由接入层通过 `update(project:status:age:statusColor:)` 推送。
class AgentStatusBarItem: NSCustomTouchBarItem, Widget {
    static var name: String = "agentStatus"
    static var identifier: String = "com.toxblh.mtmr.agentStatus."

    private static let font = NSFont.systemFont(ofSize: 15, weight: .regular)
    // 本组件三段的 label 都由 centerYAnchor 在各自段内几何居中，不需要基线微调。
    // 原本照抄 CustomButtonTouchBarItem.defaultTouchbarAttributedString 取 1，
    // 那是为跨组件对齐基线用的；在这里只会把整组字形抬离圆角背景的中心（表现为「偏高」）。
    private static let baselineOffset: CGFloat = 0
    private static let preferredProjectWidth: CGFloat = 120
    private static let minimumProjectWidth: CGFloat = 40
    private static let dividerWidth: CGFloat = 1
    private static let dividerHeightRatio: CGFloat = 0.5
    private static let segmentHeight: CGFloat = 30
    private static let segmentPadding: CGFloat = 10
    private static let cornerRadius: CGFloat = 6

    /// 置为 false 时去掉圆角背景，变成无背景透明样式
    var isBordered: Bool = true {
        didSet { applyStyle() }
    }

    private let background = NSBox()
    private let stack = NSStackView()
    private let projectClipView = NSView()
    private let projectLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let ageLabel = NSTextField(labelWithString: "")

    /// 项目段两条互斥的宽度策略：
    /// - 配了 items.json 的 width → 撑满整段（否则 120pt 的自然宽会把长名字永久封顶）
    /// - 没配 width → 用 120pt 自然宽，靠 defaultHigh 让系统可压可拉
    private var preferredClipWidthConstraint: NSLayoutConstraint!
    private var fillClipWidthConstraint: NSLayoutConstraint!

    private var statusWidthConstraint: NSLayoutConstraint!
    private var ageWidthConstraint: NSLayoutConstraint!

    private var project = ""
    private var status = "○"
    private var age = "--"
    private var statusColor = NSColor.white

    private let scriptSource: String?
    private let interval: TimeInterval
    private var lastPayload: Payload?

    /// 自有宽度约束。刻意不走 CanSetWidth —— 那条路径是「新增」一条约束而非覆盖，
    /// 与隐藏用的 width=0 会同时激活而冲突（见 mtmr-custombutton-width-conflict.md）。
    /// 单一约束按状态改常量/是否激活，因此永不冲突。
    private var widthConstraint: NSLayoutConstraint!
    private var configuredWidth: CGFloat?

    /// 脚本 stdout 的单行 JSON。project/status/age 必填，缺一即视为解析失败；
    /// detail/kind 可选 —— 只有旧的三字段脚本不产出这两个键
    private struct Payload: Decodable, Equatable {
        let project: String
        let status: String
        let detail: String?
        let kind: String?
        let age: String
    }

    init(identifier: NSTouchBarItem.Identifier, source: SourceProtocol?, interval: TimeInterval) {
        self.scriptSource = source?.string
        self.interval = interval
        super.init(identifier: identifier)
        view = makeView()
        // 起始即无数据 → 宽度 0，不占位
        widthConstraint = view.widthAnchor.constraint(equalToConstant: 0)
        widthConstraint.isActive = true
        startPolling()
    }

    /// 由 TouchBarController 优先于 CanSetWidth 调用，避免叠加第二条宽度约束。
    /// 刻意不叫 setWidth —— 该名字已被 NSCustomTouchBarItem 的 CanSetWidth 扩展占用，
    /// 同名同签名会被判为覆写扩展方法而编译失败。
    func applyConfiguredWidth(_ value: CGFloat) {
        configuredWidth = value
        applyWidthMode()
        applyVisibility()
    }

    /// 配了 width 就让项目段撑满整段，否则退回 120pt 自然宽。两条互斥，
    /// 否则 preferredWidth 的等值约束会把长项目名永久封顶在 120pt。
    private func applyWidthMode() {
        let fills = configuredWidth != nil
        preferredClipWidthConstraint?.isActive = !fills
        fillClipWidthConstraint?.isActive = fills
    }

    /// 无数据时宽度归零：有数据且配了 width 用之，配了用自然尺寸，未读到数据一律不显示
    private func applyVisibility() {
        guard let payload = lastPayload, !payload.project.isEmpty else {
            widthConstraint.constant = 0
            widthConstraint.isActive = true
            return
        }
        guard let width = configuredWidth else {
            widthConstraint.isActive = false
            return
        }
        widthConstraint.constant = width
        widthConstraint.isActive = true
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 未配置 source 时不启动轮询，组件因始终无数据而保持隐藏
    private func startPolling() {
        guard scriptSource != nil else { return }
        DispatchQueue.shellScriptQueue.async { [weak self] in
            self?.poll()
        }
    }

    /// 运行在 shellScriptQueue（串行）上；下一轮同样挂回该队列，
    /// 用 [weak self] 让 items.json 热重载替换实例后自然终止
    private func poll() {
        guard let scriptSource = scriptSource else { return }

        let (output, succeeded) = ShellScriptRunner.execute(scriptSource, timeout: interval)
        // 脚本失败或输出不合约时保留上一次成功结果
        if succeeded, let payload = AgentStatusBarItem.decode(output) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.lastPayload != payload else { return }
                self.lastPayload = payload
                let display = AgentStatusBarItem.presentation(for: payload)
                self.update(project: payload.project, status: display.text, age: payload.age, statusColor: display.color)
            }
        }

        DispatchQueue.shellScriptQueue.asyncAfter(deadline: .now() + interval) { [weak self] in
            self?.poll()
        }
    }

    private static func decode(_ output: String) -> Payload? {
        guard !output.isEmpty, let data = output.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: data)
    }

    /// 中段显示什么：状态符号 + （有则追加）运行项名称。
    /// detail 有内容就追加在符号之后，不要求 kind 存在 —— 否则 kind 缺失时
    /// detail 会被整个丢掉。kind 只用于区分 tool / agent 的图标与颜色。
    private static func presentation(for payload: Payload) -> (text: String, color: NSColor) {
        let detail = payload.detail ?? ""
        guard !detail.isEmpty else { return style(for: payload.status) }

        switch payload.kind {
        case "tool": return ("● " + detail, .systemGreen)
        case "agent": return ("◆ " + detail, .systemBlue)
        default:
            let (symbol, color) = style(for: payload.status)
            return ("\(symbol) \(detail)", color)
        }
    }

    /// status token → 符号与颜色。脚本只报告事实，显示规则都在本侧。
    private static func style(for status: String) -> (text: String, color: NSColor) {
        switch status {
        case "idle": return ("○", .systemGray)
        case "working": return ("●", .systemGreen)
        case "waiting": return ("◐", .systemOrange)
        case "done": return ("✓", .systemBlue)
        case "error": return ("✗", .systemRed)
        default: return ("●", .white)
        }
    }

    private func styled(_ text: String, alignment: NSTextAlignment, color: NSColor) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        return NSAttributedString(string: text, attributes: [
            .foregroundColor: color,
            .font: AgentStatusBarItem.font,
            .baselineOffset: AgentStatusBarItem.baselineOffset,
            .paragraphStyle: paragraph,
        ])
    }

    private func measuredWidth(of label: NSTextField) -> CGFloat {
        let string = label.attributedStringValue
        guard string.length > 0 else { return 0 }
        return ceil(string.size().width)
    }

    /// 不给标签加高度约束：NSTextField 在固有行高下才能把文字正确垂直居中，
    /// 强行拉到 segmentHeight 会让整组文字在背景里偏移。三段字号相同 → 固有高度相同
    /// → 彼此基线自然一致；纵向居中交给段容器的 centerY。
    private func makeLabel(_ label: NSTextField, alignment: NSTextAlignment) {
        label.lineBreakMode = .byClipping
        label.usesSingleLineMode = true
        label.maximumNumberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        label.attributedStringValue = styled("", alignment: alignment, color: .white)
    }

    /// 左段：吸收全部余量。项目名固定从名称开头显示，超出可视宽度由 clipView 直接裁切。
    private func makeProjectSegment() -> NSView {
        let segment = NSView()
        segment.translatesAutoresizingMaskIntoConstraints = false
        // 低 hugging → 有余量时优先增长；低抗压缩 → 空间不足时最先被压窄
        segment.setContentHuggingPriority(.defaultLow, for: .horizontal)
        segment.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        projectClipView.translatesAutoresizingMaskIntoConstraints = false
        projectClipView.clipsToBounds = true
        segment.addSubview(projectClipView)
        projectClipView.addSubview(projectLabel)

        // 未设 width 时的自然宽；defaultHigh 让系统可压可拉
        preferredClipWidthConstraint = projectClipView.widthAnchor.constraint(equalToConstant: AgentStatusBarItem.preferredProjectWidth)
        preferredClipWidthConstraint.priority = .defaultHigh
        preferredClipWidthConstraint.isActive = true

        // 设了 width 时改为撑满整段（见 applyWidthMode 切换）——
        // 否则 items.json 的 width 调到 300 也没用，项目名永远被关在 120pt 窗口里。
        fillClipWidthConstraint = projectClipView.trailingAnchor.constraint(equalTo: segment.trailingAnchor, constant: -AgentStatusBarItem.segmentPadding)
        fillClipWidthConstraint.isActive = false

        NSLayoutConstraint.activate([
            projectClipView.widthAnchor.constraint(greaterThanOrEqualToConstant: AgentStatusBarItem.minimumProjectWidth),
            segment.heightAnchor.constraint(equalToConstant: AgentStatusBarItem.segmentHeight),
            projectClipView.leadingAnchor.constraint(equalTo: segment.leadingAnchor, constant: AgentStatusBarItem.segmentPadding),
            projectClipView.trailingAnchor.constraint(lessThanOrEqualTo: segment.trailingAnchor, constant: -AgentStatusBarItem.segmentPadding),
            projectClipView.heightAnchor.constraint(equalToConstant: AgentStatusBarItem.segmentHeight),
            projectLabel.centerYAnchor.constraint(equalTo: projectClipView.centerYAnchor),
            projectLabel.leadingAnchor.constraint(equalTo: projectClipView.leadingAnchor),
            projectLabel.widthAnchor.constraint(greaterThanOrEqualTo: projectClipView.widthAnchor),
        ])
        return segment
    }

    /// 中段与右段：宽度按文本实测值加内边距定死，并禁止伸缩。
    /// 返回的 width 约束需要在文本变化时更新 constant。
    private func makeContentSizedSegment(_ label: NSTextField) -> (view: NSView, width: NSLayoutConstraint) {
        let segment = NSView()
        segment.translatesAutoresizingMaskIntoConstraints = false
        segment.setContentHuggingPriority(.required, for: .horizontal)
        segment.setContentCompressionResistancePriority(.required, for: .horizontal)
        segment.addSubview(label)

        let width = segment.widthAnchor.constraint(
            equalToConstant: measuredWidth(of: label) + 2 * AgentStatusBarItem.segmentPadding
        )
        width.isActive = true

        NSLayoutConstraint.activate([
            segment.heightAnchor.constraint(equalToConstant: AgentStatusBarItem.segmentHeight),
            label.leadingAnchor.constraint(equalTo: segment.leadingAnchor, constant: AgentStatusBarItem.segmentPadding),
            label.trailingAnchor.constraint(equalTo: segment.trailingAnchor, constant: -AgentStatusBarItem.segmentPadding),
            label.centerYAnchor.constraint(equalTo: segment.centerYAnchor),
        ])
        return (segment, width)
    }

    private func makeDivider() -> NSView {
        let divider = NSView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.22).cgColor

        NSLayoutConstraint.activate([
            divider.widthAnchor.constraint(equalToConstant: AgentStatusBarItem.dividerWidth),
            divider.heightAnchor.constraint(equalToConstant: AgentStatusBarItem.segmentHeight * AgentStatusBarItem.dividerHeightRatio),
        ])
        return divider
    }

    private func makeView() -> NSView {
        makeLabel(projectLabel, alignment: .left)
        makeLabel(statusLabel, alignment: .center)
        makeLabel(ageLabel, alignment: .center)

        let statusSegment = makeContentSizedSegment(statusLabel)
        statusWidthConstraint = statusSegment.width
        let ageSegment = makeContentSizedSegment(ageLabel)
        ageWidthConstraint = ageSegment.width

        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.distribution = .fill
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(makeProjectSegment())
        stack.addArrangedSubview(makeDivider())
        stack.addArrangedSubview(statusSegment.view)
        stack.addArrangedSubview(makeDivider())
        stack.addArrangedSubview(ageSegment.view)

        background.boxType = .custom
        background.titlePosition = .noTitle
        background.borderWidth = 0
        background.cornerRadius = AgentStatusBarItem.cornerRadius
        background.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            stack.topAnchor.constraint(equalTo: background.topAnchor),
            stack.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])

        applyStyle()
        return background
    }

    private func applyStyle() {
        background.fillColor = isBordered ? NSColor.white.withAlphaComponent(0.16) : .clear
    }

    func update(project: String, status: String, age: String, statusColor: NSColor) {
        self.project = project
        self.status = status
        self.age = age
        self.statusColor = statusColor
        render()
        applyVisibility()
    }

    private func render() {
        projectLabel.attributedStringValue = styled(project, alignment: .left, color: .white)
        statusLabel.attributedStringValue = styled(status, alignment: .center, color: statusColor)
        ageLabel.attributedStringValue = styled(age, alignment: .center, color: .white)

        // 两段宽度跟着内容走，变化后项目段拿到的余量随之改变
        statusWidthConstraint?.constant = measuredWidth(of: statusLabel) + 2 * AgentStatusBarItem.segmentPadding
        ageWidthConstraint?.constant = measuredWidth(of: ageLabel) + 2 * AgentStatusBarItem.segmentPadding
    }
}