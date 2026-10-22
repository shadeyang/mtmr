//
//  AgentStatusBarItem.swift
//  MTMR
//
//  Copyright © 2018 Anton Palgunov. All rights reserved.
//

import AppKit

/// 三段式 agent 状态视图：左侧项目名（超长时跑马灯滚动）、中间状态、右侧活动时间。
/// 三段共处一个圆角背景内，段间以竖线分隔，体现「整体」与「元素分割」。
///
/// 宽度策略：状态段与时长段按各自文本实测宽度加内边距定宽，并禁止伸缩；
/// 项目段吸收全部余量。整体总宽由 items.json 的 `width` 固定，
/// 项目名超出可视宽度时改为跑马灯滚动而非截断。
///
/// 数据由接入层通过 `update(project:status:age:statusColor:)` 推送。
class AgentStatusBarItem: NSCustomTouchBarItem, Widget {
    static var name: String = "agentStatus"
    static var identifier: String = "com.toxblh.mtmr.agentStatus."

    private static let font = NSFont.systemFont(ofSize: 15, weight: .regular)
    // 与 CustomButtonTouchBarItem.defaultTouchbarAttributedString 取值一致，
    // 使本组件的文字基线与其它 MTMR 组件在同一条水平线上
    private static let baselineOffset: CGFloat = 1
    private static let preferredProjectWidth: CGFloat = 120
    private static let minimumProjectWidth: CGFloat = 40
    private static let dividerWidth: CGFloat = 1
    private static let dividerHeightRatio: CGFloat = 0.5
    private static let segmentHeight: CGFloat = 30
    private static let segmentPadding: CGFloat = 10
    private static let cornerRadius: CGFloat = 6
    private static let marqueeInterval: TimeInterval = 0.25

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

    private var statusWidthConstraint: NSLayoutConstraint!
    private var ageWidthConstraint: NSLayoutConstraint!

    private var project = ""
    private var status = "○"
    private var age = "--"
    private var statusColor = NSColor.white
    private var marqueeTimer: Timer?

    override init(identifier: NSTouchBarItem.Identifier) {
        super.init(identifier: identifier)
        view = makeView()
        update(project: "agent", status: "○", age: "--", statusColor: .white)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        marqueeTimer?.invalidate()
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

    /// 左段：吸收全部余量。项目名超出可视宽度时由 clipView 裁切，跑马灯负责轮转。
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

        // 未设 width 时的默认宽度；可被 items.json 的 "width" 拉伸或压窄而不冲突
        let preferredWidth = projectClipView.widthAnchor.constraint(equalToConstant: AgentStatusBarItem.preferredProjectWidth)
        preferredWidth.priority = .defaultHigh
        preferredWidth.isActive = true

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

        stopMarquee()
        // 跑马灯要等布局算完才知道项目名有没有超出可视宽度
        DispatchQueue.main.async { [weak self] in
            self?.refreshMarquee()
        }
    }

    private func render(projectText: String? = nil) {
        projectLabel.attributedStringValue = styled(projectText ?? project, alignment: .left, color: .white)
        statusLabel.attributedStringValue = styled(status, alignment: .center, color: statusColor)
        ageLabel.attributedStringValue = styled(age, alignment: .center, color: .white)

        // 两段宽度跟着内容走，变化后项目段拿到的余量随之改变
        statusWidthConstraint?.constant = measuredWidth(of: statusLabel) + 2 * AgentStatusBarItem.segmentPadding
        ageWidthConstraint?.constant = measuredWidth(of: ageLabel) + 2 * AgentStatusBarItem.segmentPadding
    }

    private func refreshMarquee() {
        let fits = projectLabel.intrinsicContentSize.width <= projectClipView.bounds.width
        if fits || project.count < 2 {
            stopMarquee()
            render(projectText: project)
            return
        }

        guard marqueeTimer == nil else { return }
        marqueeTimer = Timer.scheduledTimer(
            timeInterval: AgentStatusBarItem.marqueeInterval,
            target: self,
            selector: #selector(marquee),
            userInfo: nil,
            repeats: true
        )
    }

    private func stopMarquee() {
        marqueeTimer?.invalidate()
        marqueeTimer = nil
    }

    @objc private func marquee() {
        render(projectText: String(project.dropFirst()) + String(project.prefix(1)))
    }
}