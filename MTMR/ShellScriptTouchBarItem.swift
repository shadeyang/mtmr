//
//  ShellScriptTouchBarItem.swift
//  MTMR
//
//  Created by bobr on 08/08/2019.
//  Copyright © 2019 Anton Palgunov. All rights reserved.
//
import Foundation

class ShellScriptTouchBarItem: CustomButtonTouchBarItem {
    private let interval: TimeInterval
    private let source: String
    private var forceHideConstraint: NSLayoutConstraint!
    
    struct ScriptResult: Decodable {
        var title: String?
        var image: Source?
    }

    init?(identifier: NSTouchBarItem.Identifier, source: SourceProtocol, interval: TimeInterval) {
        self.interval = interval
        self.source = source.string ?? "echo No \"source\""
        super.init(identifier: identifier, title: "")
        
        forceHideConstraint = view.widthAnchor.constraint(equalToConstant: 0)
        forceHideConstraint.isActive = true
        
        DispatchQueue.shellScriptQueue.async {
            self.refreshAndSchedule()
        }
    }
    
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func refreshAndSchedule() {
        // Execute script and get result
        let (scriptResult, succeeded) = execute(source)
        var rawTitle: String, image: NSImage?
        var json: Bool

        do {
            let decoder = JSONDecoder()
            let result = try decoder.decode(ScriptResult.self, from: scriptResult.data(using: .utf8)!)
            json = true
            rawTitle = result.title ?? ""
            image = result.image?.image
        } catch {
            json = false
            rawTitle = scriptResult
        }

        // Apply returned text attributes (if they were returned) to our result string
        let helper = AMR_ANSIEscapeHelper.init()
        helper.defaultStringColor = NSColor.white
        helper.font = "1".defaultTouchbarAttributedString.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        let title = NSMutableAttributedString.init(attributedString: helper.attributedString(withANSIEscapedString: rawTitle) ?? NSAttributedString(string: ""))
        title.addAttributes([.baselineOffset: 1], range: NSRange(location: 0, length: title.length))
        let newBackgoundColor: NSColor? = title.length != 0 ? title.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? NSColor : nil
        
        // Update UI
        DispatchQueue.main.async { [weak self, newBackgoundColor] in
            // 失败时不更新 UI，保留上一次成功结果；首次失败继续隐藏
            guard succeeded else { return }

            guard let self = self else { return }

            if newBackgoundColor != self.backgroundColor {
                self.backgroundColor = newBackgoundColor
            }

            if !self.attributedTitle.isEqual(to: title) {
                self.attributedTitle = title
            }

            if json && self.image != image {
                self.image = image
            }

            let shouldHide = rawTitle.isEmpty && image == nil
            if self.forceHideConstraint.isActive != shouldHide {
                self.forceHideConstraint.isActive = shouldHide
            }
        }
        
        // Schedule next update
        DispatchQueue.shellScriptQueue.asyncAfter(deadline: .now() + interval) { [weak self] in
            self?.refreshAndSchedule()
        }
    }
    
    func execute(_ command: String) -> (String, Bool) {
        let task = Process()
        if let shell = getenv("SHELL") {
            task.launchPath = String.init(cString: shell)
        } else {
            task.launchPath = "/bin/bash"
        }
        task.arguments = ["-c", command]

        let pipe = Pipe()
        task.standardOutput = pipe

        // 超过刷新间隔时终止任务；非零退出码视为失败
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak task] in
            task?.terminate()
        }

        task.launch()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = NSString(
            data: data,
            encoding: String.Encoding.utf8.rawValue
        ) as String? ?? ""

        task.waitUntilExit()

        let result = output.replacingOccurrences(
            of: "\\n+$",
            with: "",
            options: .regularExpression
        )

        if task.terminationStatus != 0 || result == "error" {
            return ("", false)
        }

        return (result, true)
    }
}

extension DispatchQueue {
    static let shellScriptQueue = DispatchQueue(label: "mtmr.shellscript")
}
