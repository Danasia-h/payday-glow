# PaydayGlow

**薪动 / 上班鼓励器** — a native macOS floating wage clock that makes every working second visible.

PaydayGlow 是一个位于屏幕右下角的半透明工资时钟：显示今日已赚、计薪进度和下班倒计时；到点弹窗祝贺，过点仍亮屏则显示「被白嫖中」。

![PaydayGlow preview — example data](docs/images/preview.png)

> 截图为示例数据。工资与作息设置仅保存在本机，不包含在此仓库中。

## Features

- 深色半透明、可拖动的悬浮卡片，支持菜单栏显示、隐藏与归位。
- 薄荷绿计薪进度环，今日收入显示四位小数，每秒更新。
- 月均工作日固定 **21.5 天**；支持自定义上下班、工作日、不计薪午休及跨夜班次。
- 下班弹窗、每日提醒去重、亮屏后的超时状态。
- 纯 SwiftUI / AppKit，无外部依赖、网络请求或账号系统。

## Build and run

需要 Apple Silicon Mac 与 Xcode / Apple Command Line Tools。构建目标为 macOS 13 及以上；未逐一验证所有 macOS 版本。

```sh
git clone https://github.com/Danasia-h/payday-glow.git
cd payday-glow
zsh test.sh
zsh build.sh
open build/薪动.app
```

本仓库为私有仓库，克隆需要你的 GitHub 账户授权。构建产物使用本机临时签名，未进行 Apple 开发者公证。

点击卡片齿轮设置月薪和作息。应用默认使用真实时间；设置会自动保存。开发用 `--preview` 模式也连续计时，保存设置后切换到真实时间。

## Calculation

```text
每日预计收入 = 月薪 ÷ 21.5
每秒收入 = 每日预计收入 ÷ 每日计薪秒数
今日已赚 = 当天已过去的计薪秒数 × 每秒收入
```

不计薪午休期间收入与进度暂停，倒计时继续；下班后收入封顶。工作日选择决定何时计薪和提醒，不改变 21.5 这个分母。当前版本不处理法定节假日、调休、请假、税费、奖金及加班费。

## Repository layout

```text
Sources/          SwiftUI 卡片、AppKit 应用入口与工资计算逻辑
Tests/            计算、计时、提醒边界检查
Assets/           应用图标
Icon.swift        图标生成源码
build.sh          编译及本机签名
test.sh           编译并运行检查
docs/             使用说明、验证边界与示例截图
```

[完整使用说明](docs/usage.zh-CN.md) · [验证记录](docs/validation.md)

原始工作文件、中间截图、历史安装包及编译缓存已迁入项目本地的 `work/`、`outputs/`，由 `.gitignore` 排除。源代码以项目根目录的 `Sources/`、`Tests/` 和 `Assets/` 为准。

保留原应用标识 `local.xindong.salaryclock`，以继续读取已有本机工资与作息设置。英文项目名为 PaydayGlow，卡片显示名仍为「上班鼓励器」。
