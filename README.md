# PasteGo

macOS 剪贴板 AI 助手 — 自动记录剪贴板历史，一键调用 AI 处理文本。

![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.10-orange) ![License](https://img.shields.io/badge/License-MIT-green)

## 功能特性

- **剪贴板历史** — 自动监听并记录文本、代码、URL、图片，支持搜索和分类筛选
- **置顶收藏** — 重要内容一键置顶，不会被新记录冲掉
- **AI 模板** — 自定义提示词模板（翻译、总结、改写等），点击即刻生成
- **全局快捷键** — 为模板绑定快捷键，在任意 App 中按下即可调用 AI 处理当前剪贴板内容
- **自定义对话** — Chat 风格的自由输入模式，把剪贴板内容作为素材发送任意指令
- **多 AI 后端** — 支持 OpenAI、Claude、Ollama、Kimi、MiniMax 等，自由配置
- **流式输出** — 实时逐字显示生成结果，支持 Markdown 渲染和思维链折叠
- **隐私优先** — 数据全部存储在本地 SQLite，不上传任何内容

## 构建与运行

**前置要求：** macOS 14.0+、Xcode 16+

```bash
# 克隆仓库
git clone https://github.com/mrzch03/PasteGoNative.git
cd PasteGoNative/PasteGoNative

# 使用 Xcode 打开项目
open PasteGo.xcodeproj
```

在 Xcode 中选择 `PasteGo` scheme，点击 **Run (⌘R)** 即可运行。

首次运行时，macOS 会提示授予**辅助功能权限**（用于全局快捷键和粘贴功能），请在系统设置中允许。

## 使用指南

### 基本操作

| 操作 | 说明 |
|------|------|
| `Cmd+Shift+V` | 显示/隐藏主窗口 |
| 点击菜单栏图标 | 显示/隐藏主窗口 |
| `Esc` | 返回上一页 |

### 1. 剪贴板历史

启动后自动监听剪贴板，所有复制的内容都会出现在历史列表中。支持：
- 搜索关键词过滤
- 按类型筛选（文本 / 代码 / URL / 图片）
- 点击置顶按钮收藏重要内容

### 2. AI 生成

1. 在历史列表中勾选一条或多条素材
2. 点击「AI 生成」进入生成页面
3. 选择模板卡片（如「翻译」）即刻生成，或切换到「自定义」模式自由输入指令
4. 生成完成后点击「复制结果」

### 3. 全局快捷键

为模板绑定快捷键后，可在**任意应用**中使用：

1. 在其他 App 中复制一段文本
2. 按下模板快捷键（如默认的 `Cmd+Shift+T` 翻译）
3. PasteGo 自动弹出并生成结果

### 4. 配置 AI 服务

进入**设置**页面，添加 AI 服务商：

| 服务商 | Endpoint 示例 | 说明 |
|--------|---------------|------|
| OpenAI | `https://api.openai.com/v1` | 需要 API Key |
| Claude | `https://api.anthropic.com` | 需要 API Key |
| Ollama | `http://localhost:11434` | 本地部署，无需 Key |
| Kimi | `https://api.moonshot.cn/v1` | 需要 API Key |
| MiniMax | `https://api.minimax.chat/v1` | 需要 API Key |

### 5. 自定义模板

在设置页面创建模板：

- **名称**：显示在生成页的卡片上
- **提示词**：使用 `{{materials}}` 作为素材占位符
- **快捷键**：按下组合键录入，如 `Cmd+Shift+T`

示例提示词：
```
请将以下内容翻译为中文（如已是中文则翻译为英文）：

{{materials}}
```

## 技术栈

- **语言：** Swift 5.10
- **UI 框架：** SwiftUI (macOS 14+)
- **数据库：** SQLite ([GRDB](https://github.com/groue/GRDB.swift))
- **快捷键：** [HotKey](https://github.com/soffes/HotKey) + [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)
- **Markdown：** [swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui)

## License

[MIT](LICENSE)
