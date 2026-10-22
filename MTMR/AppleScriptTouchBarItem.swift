import Foundation

class AppleScriptTouchBarItem: CustomButtonTouchBarItem {
    private var script: NSAppleScript!
    private let interval: TimeInterval
    private var forceHideConstraint: NSLayoutConstraint!
    private let alternativeImages: [String: SourceProtocol]

    init?(identifier: NSTouchBarItem.Identifier, source: SourceProtocol, interval: TimeInterval, alternativeImages: [String: SourceProtocol]) {
        self.interval = interval
        self.alternativeImages = alternativeImages
        super.init(identifier: identifier, title: "")
        forceHideConstraint = view.widthAnchor.constraint(equalToConstant: 0)
        forceHideConstraint.isActive = true
        DispatchQueue.appleScriptQueue.async {
            guard let script = source.appleScript else {
                return
            }
            self.script = script
            DispatchQueue.main.async {
                self.isBordered = false
            }
            
            var error: NSDictionary?
            guard script.compileAndReturnError(&error) else {
                #if DEBUG
                    print(error?.description ?? "unknown error")
                #endif
                return
            }
            self.refreshAndSchedule()
        }
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func refreshAndSchedule() {
        #if DEBUG
            print("refresh happened (interval \(interval)), self \(identifier.rawValue))")
        #endif
        let (scriptResult, succeeded) = execute()
        DispatchQueue.main.async {
            // 执行失败时保留上一次成功结果；首次失败则继续隐藏
            guard succeeded else { return }
            self.title = scriptResult
            self.forceHideConstraint.isActive = scriptResult == ""
            #if DEBUG
                print("did set new script result title \(scriptResult)")
            #endif
        }
        DispatchQueue.appleScriptQueue.asyncAfter(deadline: .now() + interval) { [weak self] in
            self?.refreshAndSchedule()
        }
    }

    func updateIcon(iconLabel: String) {
        if alternativeImages[iconLabel] != nil {
            DispatchQueue.main.async {
                self.image = self.alternativeImages[iconLabel]!.image
            }
        } else {
            print("Cannot find icon with label \"\(iconLabel)\"")
        }
    }

    func execute() -> (String, Bool) {
        var error: NSDictionary?
        let output = script.executeAndReturnError(&error)

        if let error = error {
            print(error)
            return ("", false)
        }

        if output.descriptorType == typeAEList {
            guard output.numberOfItems > 0 else {
                return ("", true)
            }

            let arr = (1...output.numberOfItems).compactMap {
                output.atIndex($0)?.stringValue ?? ""
            }

            if arr.isEmpty {
                return ("", true)
            } else if arr.count == 1 {
                return (arr[0], true)
            } else {
                updateIcon(iconLabel: arr[1])
                return (arr[0], true)
            }
        }

        return (output.stringValue ?? "", true)
    }
}

extension DispatchQueue {
    static let appleScriptQueue = DispatchQueue(label: "mtmr.applescript")
}
