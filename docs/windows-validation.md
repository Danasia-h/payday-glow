# Windows 1.2.0 验证范围

实现：WPF 原生半透明卡片 + Windows Forms 系统托盘，.NET 10 自带运行环境、单文件 win-x64 发布。用户无需安装 SDK 或 .NET。保留 macOS 源码和原有本机数据标识。

## 自动检查

- `Windows/PaydayGlow.Tests`：固定 21.5 天、午休和班次边界、跨夜、休息日、收入封顶、亮/灭屏状态、提醒去重、实时增长、设置持久化和损坏文件恢复。
- GitHub Actions 使用 Windows 构建机，执行 `Windows/build-windows.ps1`。
- 启动最终发布的 `PaydayGlow.exe --smoke-test <隔离目录>`，检查首次设置、保存/重读、真实 Dispatcher 定时器更新、齿轮设置、隐藏/显示、右下角定位、透明属性、超时显示和原生祝贺弹窗。
- 使用 Windows 自身渲染卡片、设置页、下班后状态和弹窗截图，保存 JSON 检查报告。
- 屏幕电源事件通过向本应用 HWND 注入 Windows 格式消息验证；不对构建机真的熄屏，不把这一项声明为硬件实测。

## 边界

- 目标为 Windows 10/11 x64，原生启动验证以 CI 实际报告的 Windows 版本为准。未逐一验证所有 Windows 10/11 版本、DPI、多显示器、远程桌面和安全软件配置。
- 未进行实体显示器休眠/唤醒或真实下班时刻的长时间实测。
- 不提供 Windows 7/8、32 位或原生 ARM64 构建。
- 单文件会自动将原生运行库展开到当前用户的临时目录；不需要管理员权限。
- 本版无商业代码签名，接收者可能收到系统/安全软件对新应用的提示。不会修改系统防护策略。
- Windows 设置只存本机的 `%LOCALAPPDATA%\PaydayGlow`；不从开发 Mac 导入工资或作息。不上传个人数据。
- .NET 单文件、自带运行环境的发布机制参考 [Microsoft 文档](https://learn.microsoft.com/en-us/dotnet/core/deploying/single-file/overview)。
- 会话屏幕状态参考 [Microsoft Power Setting GUIDs](https://learn.microsoft.com/en-us/windows/win32/power/power-setting-guids)，使用交互式应用推荐的 `GUID_SESSION_DISPLAY_STATUS`，亮起和变暗都视为亮屏。
