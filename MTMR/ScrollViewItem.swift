import Foundation

class ScrollViewItem: NSCustomTouchBarItem/*, NSGestureRecognizerDelegate*/ {

    init(identifier: NSTouchBarItem.Identifier, items: [NSTouchBarItem]) {
        super.init(identifier: identifier)
        let views = items.compactMap { $0.view }
        let stackView = NSStackView(views: views)
        stackView.spacing = 1
        stackView.orientation = .horizontal
        let scrollView = NSScrollView(frame: CGRect(origin: .zero, size: stackView.fittingSize))
        scrollView.documentView = stackView
        view = scrollView
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 就地替换内容，保留滚动位置。
    ///
    /// 重建整个 ScrollViewItem 会连同滚动位置一起丢掉 —— 调用方若在每次数据刷新时
    /// 重建，用户刚滑到的位置就会被弹回最前面。GroupBarItem 不调用本方法，行为不变。
    func replaceItems(_ items: [NSTouchBarItem]) {
        guard
            let scrollView = view as? NSScrollView,
            let stack = scrollView.documentView as? NSStackView
        else { return }

        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        for view in items.compactMap({ $0.view }) {
            stack.addArrangedSubview(view)
        }
    }
}
