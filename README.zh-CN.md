# 我的 TouchBar，我做主。 [![GitHub release](https://img.shields.io/github/release/toxblh/MTMR.svg)](https://github.com/Toxblh/MTMR/releases) [![license](https://img.shields.io/github/license/Toxblh/MTMR.svg)](https://github.com/Toxblh/MTMR/blob/master/LICENSE) ![minimal system requirements](https://img.shields.io/badge/required-macOS%2010.12.2-blue.svg) ![travis](https://travis-ci.org/Toxblh/MTMR.svg?branch=master)

**[English](README.md) | [简体中文](README.zh-CN.md)**

<img src="Resources/logo.png" align="right"
     title="MTMR by Toxblh" width="110" height="110">

_一款为 MacBook Pro 定制的 TouchBar 应用_

我的想法是做一个用来定制 TouchBar 的插件平台。我非常喜欢 BTT，也喜欢把 TouchBar 完全按自己的预设改掉，所以我想自己做一个。

**在这里分享你的预设 → [MTMR-presets](https://github.com/Toxblh/MTMR-presets)**

**MTMR 可视化编辑器** -> [MTMR Designer](https://josmanvis.github.io/mtmr-designer)</br>
感谢 [@josetwentyfour](https://github.com/josmanvis)

<p align="center">
  <img src="./Resources/aaaaa-acc6-17fee7572ed0.png" alt="带 TouchBar 的 MacBook" width="800">
</p>

<p align="center">
<a href="https://discord.gg/CmNcDuQ"><img height="20px" src="https://assets-global.website-files.com/6257adef93867e50d84d30e2/62fddf0fde45a8baedcc7ee5_847541504914fd33810e70a0ea73177e%20(2)-1.png"> Discord</a>
<a href="https://t.me/joinchat/AmVYGg8vW38c13_3MxdE_g"><img height="20px" src="https://telegram.org/img/t_logo.png" /> Telegram</a>
</p>

<p align="center"><a href="https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=WUAAG2HH58WE4" title="Donate via Paypal"><img height="36px" src="Resources/support_paypal.svg" alt="PayPal donate button" /></a>
<a href="https://www.buymeacoffee.com/toxblh" target="_blank"><img src="https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png" alt="Buy Me A Coffee" height="36px" ></a>
<a href="https://www.patreon.com/bePatron?u=9900748"><img height="36px"  src="https://c5.patreon.com/external/logo/become_a_patron_button.png" srcset="https://c5.patreon.com/external/logo/become_a_patron_button@2x.png 2x"></a>
<a href="https://www.producthunt.com/posts/my-touchbar-my-rules-mtmr">
    <img src="https://api.producthunt.com/widgets/embed-image/v1/featured.svg?post_id=my-touchbar-my-rules-mtmr&theme=light" alt="My TouchBar My Rules (MTMR)" height="36px" style="max-width:100%">
</a></p>

## 本 fork 的新增亮点

本仓库是 [Toxblh/MTMR](https://github.com/Toxblh/MTMR) 的 fork，新增了两个组件，专门服务于「同时开着好几个 AI 编程会话」的人：

| 组件 | 作用 |
|---|---|
| [`agentStatus`](#agentstatus) | 三段式状态条 —— 项目名、当前在跑什么、已经跑了多久 —— 数据来自你自己写的任意 shell 脚本。 |
| [`agentStatusList`](#agentstatuslist) | 一个容器，把**所有**在线会话折进同一个条目里：平时显示两个加一个 `+N` 徽标，点一下就把 TouchBar 展开成完整列表。 |

上游 MTMR 没有对应的东西。在那里你得为每个会话手写一条 `agentStatus`，而且每有会话开始或结束就要重新改一次 `items.json`。`agentStatusList` 只轮询脚本**一次**，按 id 匹配会话所以条目不会错位，数量变化时自己折叠。

### 上手试一下

往 `~/Library/Application Support/MTMR/items.json` 里加一条：

```json
{
  "type": "agentStatusList",
  "itemWidth": 220,
  "width": 480,
  "refreshInterval": 3,
  "compactCount": 2,
  "source": { "inline": "python3 ~/bin/touchbar_status.py --json-all" }
}
```

脚本要输出一个 JSON 数组 —— 每个会话一个对象，按启动顺序排列，每个对象都必须带 `id`。完整契约、所有配置键和宽度模型见下面的
[`agentStatus`](#agentstatus) 与 [`agentStatusList`](#agentstatuslist)。

本文档其余部分与上游完全一致。

## 安装

- 从 GitHub 下载最新的 [release](https://github.com/Toxblh/MTMR/releases)（.dmg）
- 或者用 Homebrew：`brew install --cask mtmr`
- [Dario Prski](https://medium.com/@urdigitalpulse) 在 medium 上写了一篇[很棒的文章](https://medium.com/@urdigitalpulse/customise-your-macbook-pro-touch-bar-966998e606b5)，更详细地讲了怎么装 MTMR

**首次安装**时，需要在「辅助功能」里给 MTMR 授权，否则 <kbd>Esc</kbd>、<kbd>音量</kbd>、<kbd>亮度</kbd> 这类系统按键不会生效。

<p align="center">
<img width="450" alt="screenshot 2019-02-24 at 23 19 20" src="https://user-images.githubusercontent.com/2198153/53307057-2b078200-388c-11e9-8212-8c2b1aff0aa6.png">
</p>

<p align="center">
🍏 → 系统偏好设置 → 安全性与隐私 → 隐私标签 → 辅助功能 → MTMR
</p>

## 示例

[MTMR presets](https://github.com/Toxblh/MTMR-presets)

<p align="center">
  <img src="./Resources/Artboard.png" alt="TouchBar 预设" width="800">
</p>

## 自定义

MTMR 的配置存放在 `~/Library/Application\ Support/MTMR/items.json`。

预装的配置内容大致如此，多半不是你想要的，建议改成：

## 内置按钮类型：

> 按钮

- escape
- exitTouchbar
- brightnessUp
- brightnessDown
- illuminationUp（键盘背光）
- illuminationDown（键盘背光）
- volumeDown
- volumeUp
- mute

> 原生插件

- timeButton
- battery
- cpu
- currency
- weather
- yandexWeather
- inputsource
- music（轻点暂停，长按下一首）
- dock（长按一半打开应用，长按到底退出应用）
- nightShift
- dnd（请勿打扰）
- darkMode
- pomodoro
- network
- upnext（日历事件）

> 媒体按键

- previous
- play
- next

> AppleScript 插件

- sleep
- displaySleep

> 自定义按钮

- staticButton
- appleScriptTitledButton
- shellScriptTitledButton

## 手势

默认可以从应用菜单里开启基础手势（状态栏 → MTMR 图标 → 音量/亮度手势）：
- 双指滑动：调节音量
- 三指滑动：调节亮度

### 自定义手势

你可以给两指/三指/四指滑动绑定自定义动作。要这么做，需要使用 `swipe` 类型：

```json
    "type": "swipe",
    "fingers": 2,            // 需要的手指数量（2、3 或 4）
    "direction": "right",    // 滑动方向（right/left）
    "minOffset": 10,          // 可选：触发事件所需的最小位移
    "sourceApple": {         // 可选：要执行的 apple script
        "inline": "beep"
    },
    "sourceBash": {          // 可选：要执行的 bash 脚本
        "inline": "touch /Users/lobster/test"
    }
```

预设里可以放任意多个 `swipe` 对象。

## 内置滑块类型：

- brightness
- volume

### 也可以用这些类型做自定义按钮

#### `staticButton`

```json
 "type": "staticButton",
 "title": "esc",
```

#### `appleScriptTitledButton`

```js
  {
    "type": "appleScriptTitledButton",
    "refreshInterval": 60, //可选
    "source": {
      "filePath": "~/Library/Application Support/MTMR/iTunes.nowPlaying.scpt",
      // 或者
      "inline": "tell application \"Finder\"\rif not (exists window 1) then\rmake new Finder window\rset target of front window to path to home folder as string\rend if\ractivate\rend tell",
      // 或者
      "base64": "StringInbase64"
    },
  }
```

> 注意：可以按以下步骤修改 appleScriptTitledButton 的图标：
> 1. 在 `alternativeImages` 字段里声明图标字典
> 2. 让脚本返回两个值的数组 —— `{"TITLE", "IMAGE_LABEL"}`
> 3. 确保 `IMAGE_LABEL` 已在 `alternativeImages` 字段里声明

示例：
```js
  {
    "type": "appleScriptTitledButton",
    "source": {
      "inline": "if (random number from 1 to 2) = 1 then\n\tset val to {\"title\", \"play\"}\nelse\n\tset val to {\"title\", \"pause\"}\nend if\nreturn val"
    },
    "refreshInterval": 1,
    "image": {
      "base64": "iVBORw0KGgoAAAANSUhEUgA..."
    },
    "alternativeImages": {
      "play": {
        "base64": "iVBORw0KGgoAAAANSUhEUgAAAAAA..."
      },
      "pause": {
        "base64": "iVBORw0KGgoAAAANSUhEUgAAAIAA..."
      }
    }
  },
```

#### `shellScriptTitledButton`
> 注意：脚本也可以用转义序列返回颜色（详见 https://misc.flogisoft.com/bash/tip_colors_and_formatting ）
> 目前只支持「16 色」模式。按钮会把返回的颜色设为自己的背景色。

这是一个会根据负载值变色的「CPU 负载」按钮示例（注：原生 `cpu` 插件表现更好）：
```js
{
  "type": "shellScriptTitledButton",
  "width": 80,
  "refreshInterval": 2,
  "source": {
    "inline": "top -l 2 -n 0 -F | egrep -o ' \\d*\\.\\d+% idle' | tail -1 | awk -F% '{p = 100 - $1; if (p > 30) c = \"\\033[33m\"; if (p > 70) c = \"\\033[30;43m\"; printf \"%s%4.1f%%\\n\", c, p}'"
  },
  "actions": [
    {
      "trigger": "singleTap",
      "action": "appleScript",
      "actionAppleScript": {
        "inline": "activate application \"Activity Monitor\"\rtell application \"System Events\"\r\ttell process \"Activity Monitor\"\r\t\ttell radio button \"CPU\" of radio group 1 of group 2 of toolbar 1 of window 1 to perform action \"AXPress\"\r\tend tell\rend tell"
      }
    }
  ],
  "align": "right",
  "image": {
    // 你也可以在这里指定 filePath。
    // 图片会被缩放到 24x24。
    // "filePath": "~/myproject/myimage.jpg" // 或者 "/fixed/path/to/the.png"
    "base64":
    "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAMAAACdt4HsAAAABGdBTUEAALGPC/xhBQAAACBjSFJNAAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3CculE8AAAA/1BMVEUAAADaACbYACfYACfjABzXACjYACfXACjYACfYACfYACfYACfdACLYACfXACjYACfVACv/AADXACjYACfYACfXACjYACfXACjaACXYACfYACfVACvYACfYACfZACbZACbYACfYACfZACb/AADYACfYACfVACrXACjVACu/AEDYACfYACfYACfXACjXACjYACfXACjYACfYACfYACfXACjYACfXACjYACfYACfZACbYACfYACfMADPYACfYACfYACfYACfYACfZACbXACjYACfYACfRAC7XACjYACfZACbWACnXACjXACjYACfTACzZACb/AADYACfYACfYACcAAAA+zneGAAAAU3RSTlMAItK+CVPjh3xUxPwPiGDQGAMtSKmN3Vk+wPQG/e26oIJBnwJCdiuAHgTmw+6BX+IgfaqLUvKOW8VKnagK+vBwYrhlc/urCznvhSyUbOEXPAFjGh/ektAAAAABYktHRACIBR1IAAAACXBIWXMAAA3XAAAN1wFCKJt4AAAAB3RJTUUH4ggWETQWgEDcSgAAAqVJREFUWMPtl4ly2jAQhsUNNlcw5r4SICEHLSQhCQRyX73T/u//LpUlLIyxbMAznWmn/0ywo5U+27tr7ZoQuwLBUJidRKIxPhKLRtgxHAoGiLfiQIKdKFCTxjGpQmEDCSC+BiAFpNlJBsgaxyyQYQNpIPUf8AcAOzktD+iaoQJQNI5FoMAGdCCv5XZclpfKFXiqUi5Jllf1mvdyQzW96gigd4h6o+mhRp1O0x3vvwa1VSWeqrZU1Jyeogy01ggSVQsoO/i/gjq9/u6u+2LDXq2jshqLHNCgdsCVwO0NILdi0oDmuoAmoImhQDzFRPNnb36L7U43NVfc2EH2D9h5t9OePyIF5IU9uIhvkyN7iiXmQUIOj8x/lB6f0bTaQ3ZA+9iaNCH2Lpg6btsBIRJOpJl0E9ABTvof5kqEGeCjMaN/AnRMgM5XJcI2J1J1gf6S48Tb2Ae6JkAjdgmAeJ1XAOJ1Xg8wGJ6elXwAzkeGjy62BgxG3MuXnoCIkmEq8EQyAUPgajyhPxJAga9SIiRqzwMOuAbGZDrDjQRgKkpiqiPgFphM74B7d4BKy2cyy1RcBvSodUb/HiSAIl+VlEfh8cm4wvPL9nnw+gbc+kkkUVioO95etwe8PBuP8vQoBzg7UQAe5t7syZwoCaMA3AN30wlzh3MYJYkkADeYTckYuJYlkiSVBeCKZtSY/gxlqezlxEt+pdFg6zBesPXn1ih8Aj5vkAels9PhYCkPsl++kg0AQu4dyuqmugIQm+qS5Nv6N+D7wm7d1skPc4xu666Fhd6BxU6r+jub8tNaWNxK29EhsdpR/sVn7FlLm0txPdgni+JrFNd3p+K67MQtyrsp3w2G7xbHd5Plv83z3Wj6b3V9N9ssFv7afaa//ZPn3wD4/vje8PP/N7TebS0hgZhEAAAAJXRFWHRkYXRlOmNyZWF0ZQAyMDE4LTA4LTIyVDE3OjUyOjIyKzAyOjAwc2qUYAAAACV0RVh0ZGF0ZTptb2RpZnkAMjAxOC0wOC0yMlQxNzo1MjoyMiswMjowMAI3LNwAAAAZdEVYdFNvZnR3YXJlAHd3dy5pbmtzY2FwZS5vcmeb7jwaAAAAAElFTkSuQmCC"
  },
  "bordered": false
}
```

## 分组

```js
{
  "type": "group",
  "align": "center",
  "bordered": true,
  "title": "stats",
  "items": [
    { "type": "play" },
    { "type": "mute" },
    ...
  ]
}
```

关闭一个分组，用这个按钮：

```
{
  "type": "close",
  "width": 64
},
```

## 原生插件

#### `cpu`

> 以百分比显示当前 CPU 负载，并根据负载值变色。
> 比基于 shell 的方案功耗更低、稳定性更高。

```js
{
  "type": "cpu",
  "refreshInterval": 3,
  "width": 80
}
```

#### `timeButton`

> 注意：部分时区缩写无法正常工作：https://en.wikipedia.org/wiki/List_of_time_zone_abbreviations

> formatTemplate 示例：https://www.datetimeformatter.com/how-to-format-date-time-in-swift/

> locale 示例：https://gist.github.com/jacobbubu/1836273

```js
{
  "type": "timeButton",
  "formatTemplate": "dd HH:mm",
  "locale": "en_GB",
  "timeZone": "UTC"
}
```

#### `weather`

> 服务商：https://openweathermap.org \
> 注意：到 https://openweathermap.org 注册获取你的 API key \
> 注意：注册后需等待约 20 分钟 API key 才会生效。\
> 注意：在「安全性与隐私」系统偏好设置的「定位服务」中启用 MTMR

```js
  "type": "weather",
  "refreshInterval": 600, // 单位：秒
  "units": "metric", // 或者 imperial
  "icon_type": "text", // 或者 images
  "api_key": "" // 在 openweather 上获取 key
```

#### `yandexWeather`（实验性）

> 服务商：https://yandex.ru/pogoda 。点击一次在浏览器里打开天气预报。 \
> 注意：在「安全性与隐私」系统偏好设置的「定位服务」中启用 MTMR

```js
  "type": "yandexWeather",
  "refreshInterval": 600 // 单位：秒
```

#### `currency`

> 服务商：https://coinbase.com

```js
  "type": "currency",
  "refreshInterval": 600, // 单位：秒
  "align": "right",
  "from": "BTC",
  "to": "USD",
  "full": true // £‣1.29$
```

#### `music`

```js
{
  "type": "music",
  "align": "center",
  "width": 80, // 可选
  "bordered": false, // 可选
  "refreshInterval": 2, // 单位：秒。可选。默认 5 秒
  "disableMarquee": true // 关闭跑马灯效果。可选。默认 false
},
```

#### `pomodoro`

> 番茄钟插件。轻点开始工作计时，长按开始休息计时。点击进行中的计时可重置。

```js
{
  "type": "pomodoro",
  "workTime": 1200, // 工作时长（秒）。默认 1500（25 分钟）
  "restTime": 600 // 休息时长（秒）。默认 300（5 分钟）
},
```

#### `network`

> 网络插件。显示网络用量。

```js
{
  "type": "network",
  "flip": true,
  "units": "dynamic" // 或者 B/s、KB/s、MB/s、GB/s
},
```

#### `dock`

> Dock 插件

```js
{
  "type": "dock",
  "filter": "(^Xcode$)|(Safari)|(.*player)",
  "autoResize": true
},
```

#### `agentStatus`

> 一个圆角背景里的三段式状态视图，用细竖线分隔：
> 左侧项目名，中间状态，右侧已运行时间。
> 项目名一律从第一个字符开始显示；名字过长时从右边缘裁切，而不是滚动。
> 设 `"bordered": false` 可得到透明背景，只保留分隔线。
>
> 数据来自一个每 `refreshInterval` 秒轮询一次的 shell 脚本。脚本必须在 stdout 打印
> **一行 JSON**：
>
> ```json
> {"project": "my-app", "status": "working", "detail": "Read", "kind": "tool", "age": "3m"}
> ```
>
> `project`、`status` 和 `age` 必须齐全；缺任何一个、退出码非零、或输出耗时超过轮询间隔，
> 都会被判为本次轮询失败并保留上一次成功读到的值。`detail` 和 `kind` 是可选的 ——
> 省略它们时中间段只显示纯状态符号。
>
> 在拿到数据之前该条目不显示：首次轮询成功之前，以及脚本报告 `project` 为空串时，
> 它的宽度会收缩为 0，在 TouchBar 上不占任何空间。所以完全省略 `source` 就意味着该条目永不出现。
>
> `status` 传的是状态标记而非符号。符号和颜色由 Swift 侧决定：
> `idle` → `○` 灰色，`working` → `●` 绿色，`waiting` → `◐` 橙色，`done` → `✓` 蓝色，
> `error` → `✗` 红色，缺失或未知 → `●` 白色。`age` 由脚本负责格式化
> （`3m`、`12s`、`2h`）；MTMR 不做任何时间计算。
>
> 只要 `detail` 非空，无论 `status` 是什么都会追加在状态符号之后。用它填一个简短的工具名
> （`Read`、`Grep`、`Shell`）或 agent 类型（`Explore`、`general`），没有具体任务时留空即可。
> 此时 `kind` 只决定图标与配色：`tool` → 绿色的 `●`，`agent` → 蓝色的 `◆`，
> 缺失或未知 → 状态符号本身配它自己的颜色。注意中间段变长会撑宽自己，
> 而项目名只能用剩下的空间。

```js
{
  "type": "agentStatus",
  "width": 226, // 可选。总宽度。状态段与时长段按各自文本定宽，项目名吸收剩余空间
  "bordered": false, // 可选。默认 true
  "refreshInterval": 5, // 可选。轮询间隔（秒）。默认 5
  "source": {
    "inline": "./status.sh --slot 0"
  },
},
```

#### `agentStatusList`

> 一个容器，把 N 个 [`agentStatus`](#agentstatus) 条目整合成单个条目，按会话启动顺序排列，
> 数量无上限。折叠态显示前 `compactCount` 个，再用一个 `+N` 徽标表示其余数量。
> 点击后会把 TouchBar 展开成完整列表，放不下时可左右拖动，最左侧是一个返回按钮。
> 会话按 id 匹配而不是按位置，所以一个会话结束、另一个新建时条目不会错位。
>
> 容器每个间隔只轮询脚本**一次**并分发结果 —— 每个子项自己绝不会跑脚本。
> 至少存在一个会话之前该条目不显示。
>
> 折叠态**始终**显示前 `compactCount` 个会话 —— 不会因为宽度不足就少显示 ——
> 并且宽度只与实际显示的子项等宽，所以只有一个会话时，容器宽度就正好等于那一个子项的宽度。
> 此外 `itemWidth` 会给每个子项一个相同的**固定**宽度；不写它的话每个子项按自身内容自适应。
>
> `width` 只作用于**展开态**，且是上限值：列表不能吃掉整条 TouchBar、把旁边的条目挤掉。
> 超出该宽度的会话靠左右拖动列表来查看。
>
> 脚本必须在 stdout 打印**一个 JSON 数组**，每个会话一个对象，按启动顺序排列。
> 每个对象都必须带 `id`，否则条目无法匹配、会乱跳。`project`、`status` 和 `age` 必填，
> `detail` 与 `kind` 可选 —— 各字段含义见 [`agentStatus`](#agentstatus)。

```js
{
  "type": "agentStatusList",
  "itemWidth": 220, // 可选。每个子项的固定宽度。省略则各子项按自身内容自适应
  "width": 480, // 可选。展开态的总宽上限，避免列表挤掉旁边的条目
  "refreshInterval": 5, // 可选。轮询间隔（秒）。默认 5
  "compactCount": 2, // 可选。折叠态直接显示几个，其余折进 +N 徽标。默认 2
  "bordered": true, // 可选。默认 true
  "source": {
    "inline": "./sessions.sh --json-all"
  },
},
```

```json
[
  {"id":"51fe958f944e","project":"my-app","status":"working","detail":"Read","kind":"tool","age":"3m"},
  {"id":"7a2c9d04be1f","project":"other","status":"idle","detail":"","kind":"","age":"12s"}
]
```

#### `upnext`

> 日历下一个事件插件
显示 macOS 日历中即将到来的事件。不显示当前正在进行的事件。

```js
{
  "type": "upnext",
  "from": 0, // 下一个事件的搜索范围下界（小时）。默认 0（当前时间）（可以为负以查看过去的事件）
  "to": 12, // 下一个事件的搜索范围上界（小时）。默认 12（未来 12 小时）
  "maxToShow": 3, // 最多显示的事件数量上限。默认 3（最近 3 个事件）
  "autoResize": false // 为 true 时组件会扩展以显示全部事件。默认 false（在 "width" 内滚动显示）
},
```



## 动作：

### 示例：

```js
"actions": [
  {
    "trigger": "singleTap",
    "action": "hidKey",
    "keycode": 53
  }
]
```

### 触发方式：

- `singleTap`
- `doubleTap`
- `tripleTap`
- `longTap`

### 类型

- `hidKey`
  > https://github.com/aosm/IOHIDFamily/blob/master/IOHIDSystem/IOKit/hidsystem/ev_keymap.h 只能用数字

```json
 "action": "hidKey",
 "keycode": 53,
```

- `keyPress`
  > https://eastmanreference.com/complete-list-of-applescript-key-codes

```json
 "action": "keyPress",
 "keycode": 1,
```

- `appleScript`

```js
 "action": "appleScript",
 "actionAppleScript": {
      "inline": "tell application \"Finder\"\rif not (exists window 1) then\rmake new Finder window\rset target of front window to path to home folder as string\rend if\ractivate\rend tell",
    // "filePath" 或 "base64" 同样可用
 },
```

- `shellScript`

```js
 "action": "shellScript",
 "executablePath": "/usr/bin/pmset",
 "shellArguments": ["sleepnow"], // 可选

```

- `openUrl`

```js
 "action": "openUrl",
 "url": "https://google.com",
```

## 附加参数：

- `width` 限制某个按钮占用的宽度

```json
  "width": 34
```

- `align` 可以把条目贴到某一侧，默认居中

```js
  "align": "left" // "left"、"right" 或 "center"
```

- `bordered` 可以做出无边框按钮

```js
  "bordered": "false" // "true" 或 "false"
```

- `background` 指定按钮背景色

```js
  "background": "#FF0000",
```
把 background 设成 "#000000" 并令 bordered == false，就能做出平时没有灰色背景、按下时才显示背景的按钮。

- `title` 指定按钮标题

```js
  "title": "hello"
```

- `image` 指定按钮图标

```js
  "image": {
    // 下面两种都可以
    "base64": "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAMAAACdt4HsAAAABGdB...."
    // 或者
    "filePath": "~/img.png"
  }
```

- `matchAppId` 仅在前台应用的 bundle id 匹配给定正则时显示该按钮

```json
  "matchAppId": "Safari"
```


## 疑难排查

#### 配置打不开：
- 另开一个不能编辑文本的程序
    1. 打开 Terminal.app
    2. 输入 `open -a TextEdit ~/Library/Application\ Support/MTMR/items.json` 并按 <kbd>回车</kbd>


#### 按钮或手势不工作：
- 「上次更新之后 mtmr 就坏了！」
- 「按钮有时候触发不了动作」
- 「ESC 不工作」
- 「手势不工作」

重新勾选或确认已勾选 🍏 → 系统偏好设置 → 安全性与隐私 → 隐私标签 → 辅助功能 → MTMR

## 致谢

由 [@Toxblh](https://patreon.com/toxblh) 与 [@ReDetection](http://patreon.com/ReDetection) 开发。

[![Analytics](https://ga-beacon.appspot.com/UA-96373624-2/mtmr?pixel)](https://github.com/igrigorik/ga-beacon)