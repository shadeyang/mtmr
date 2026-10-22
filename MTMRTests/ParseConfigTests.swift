import XCTest

class ParseConfig: XCTestCase {
    func testButtonNoAction() {
        let buttonNoActionFixture = """
            [  { "type": "staticButton",  "title": "Pew" } ]
        """.data(using: .utf8)!
        let result = try? JSONDecoder().decode([BarItemDefinition].self, from: buttonNoActionFixture)
        guard case .staticButton("Pew")? = result?.first?.type else {
            XCTFail()
            return
        }
        guard result?.first?.actions.count == 0 else {
            XCTFail()
            return
        }
    }

    func testButtonKeyCodeAction() {
        let buttonKeycodeFixture = """
            [  { "type": "staticButton",  "title": "Pew", "actions": [ { "trigger": "singleTap", "action": "hidKey", "keycode": 123 } ] } ]
        """.data(using: .utf8)!
        let result = try? JSONDecoder().decode([BarItemDefinition].self, from: buttonKeycodeFixture)
        guard case .staticButton("Pew")? = result?.first?.type else {
            XCTFail()
            return
        }
        guard case .hidKey(keycode: 123)? = result?.first?.actions.filter({ $0.trigger == .singleTap }).first?.value else {
            XCTFail()
            return
        }
    }
    
    func testButtonKeyCodeLegacyAction() {
        let buttonKeycodeFixture = """
            [  { "type": "staticButton",  "title": "Pew", "action": "hidKey", "keycode": 123 } ]
        """.data(using: .utf8)!
        let result = try? JSONDecoder().decode([BarItemDefinition].self, from: buttonKeycodeFixture)
        guard case .staticButton("Pew")? = result?.first?.type else {
            XCTFail()
            return
        }
        guard case .hidKey(keycode: 123)? = result?.first?.legacyAction else {
            XCTFail()
            return
        }
    }

    func testPredefinedItem() {
        let buttonKeycodeFixture = """
            [  { "type": "escape" } ]
        """.data(using: .utf8)!
        let result = try? JSONDecoder().decode([BarItemDefinition].self, from: buttonKeycodeFixture)
        guard case .staticButton("esc")? = result?.first?.type else {
            XCTFail()
            return
        }
        guard case .keyPress(keycode: 53)? = result?.first?.actions.filter({ $0.trigger == .singleTap }).first?.value else {
            XCTFail()
            return
        }
    }

    func testExtendedWidthForPredefinedItem() {
        let buttonKeycodeFixture = """
            [  { "type": "escape", "width": 110}, ]
        """.data(using: .utf8)!
        let result = try? JSONDecoder().decode([BarItemDefinition].self, from: buttonKeycodeFixture)
        guard case .staticButton("esc")? = result?.first?.type else {
            XCTFail()
            return
        }
        guard case .keyPress(keycode: 53)? = result?.first?.actions.filter({ $0.trigger == .singleTap }).first?.value else {
            XCTFail()
            return
        }
        guard case .width(110)? = result?.first?.additionalParameters[.width] else {
            XCTFail()
            return
        }
    }

    func testAgentStatus() {
        let agentStatusFixture = """
            [  { "type": "agentStatus", "width": 190 } ]
        """.data(using: .utf8)!
        let result = try? JSONDecoder().decode([BarItemDefinition].self, from: agentStatusFixture)
        guard case .agentStatus? = result?.first?.type else {
            XCTFail()
            return
        }
        guard case .width(190)? = result?.first?.additionalParameters[.width] else {
            XCTFail()
            return
        }
    }

    /// source 必须可缺省 —— barItemDefinitions() 用的是 try!，必填会让只写了
    /// { "type": "agentStatusList" } 的配置解码抛错并直接崩溃
    func testAgentStatusListWithoutSource() {
        let fixture = """
            [  { "type": "agentStatusList", "width": 420 } ]
        """.data(using: .utf8)!
        let result = try? JSONDecoder().decode([BarItemDefinition].self, from: fixture)
        guard case .agentStatusList(source: .none, refreshInterval: 5.0, compactCount: 2)? = result?.first?.type else {
            XCTFail()
            return
        }
        guard case .width(420)? = result?.first?.additionalParameters[.width] else {
            XCTFail()
            return
        }
    }

    func testAgentStatusListWithSourceAndCompactCount() {
        let fixture = """
            [  { "type": "agentStatusList", "source": { "inline": "x.sh --json-all" }, "refreshInterval": 4, "compactCount": 3 } ]
        """.data(using: .utf8)!
        let result = try? JSONDecoder().decode([BarItemDefinition].self, from: fixture)
        guard case .agentStatusList(source: .some, refreshInterval: 4.0, compactCount: 3)? = result?.first?.type else {
            XCTFail()
            return
        }
    }

    /// itemWidth 是每个子组件的固定宽度，width 是容器总宽上限 —— 两个键互不干扰，
    /// 同时出现时必须各自解出各自的值
    func testAgentStatusListItemWidth() {
        let fixture = """
            [  { "type": "agentStatusList", "itemWidth": 220, "width": 480 } ]
        """.data(using: .utf8)!
        let result = try? JSONDecoder().decode([BarItemDefinition].self, from: fixture)
        guard case .itemWidth(220)? = result?.first?.additionalParameters[.itemWidth] else {
            XCTFail()
            return
        }
        guard case .width(480)? = result?.first?.additionalParameters[.width] else {
            XCTFail()
            return
        }
    }

    /// itemWidth 必须可缺省：不写时解码不抛错，且该参数不存在（子组件走内容自适应）
    func testAgentStatusListWithoutItemWidth() {
        let fixture = """
            [  { "type": "agentStatusList", "source": { "inline": "x.sh --json-all" } } ]
        """.data(using: .utf8)!
        let result = try? JSONDecoder().decode([BarItemDefinition].self, from: fixture)
        guard case .agentStatusList? = result?.first?.type else {
            XCTFail()
            return
        }
        if case .itemWidth? = result?.first?.additionalParameters[.itemWidth] {
            XCTFail()
        }
    }
}
