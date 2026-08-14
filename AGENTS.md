# AGENTS.md

## Project Overview

“诗文社的学生”是一款使用 Godot 4.x + Dialogic 开发的中文 Galgame。

## General Guidance

- Preserve the existing project structure and conventions when making changes.
- Keep changes focused and avoid unrelated modifications.
- Prefer clear, maintainable code and concise documentation.
- Run relevant checks or tests before submitting a pull request when practical.
- Keep commits focused and describe the actual change in the commit message.

## Tech Stack

- Godot 4.7
- Dialogic 2.0 Alpha-20
- GDScript
- Forward+ renderer

## Project Structure

- `scenes/` — Godot 场景
- `scripts/` — 游戏逻辑、UI 和全局状态
- `timelines/` — Dialogic 剧情时间线
- `characters/` — Dialogic 角色定义
- `styles/` — Dialogic UI 样式
- `assets/` — 图片、音乐、音效等资源
- `fonts/` — 游戏字体
- `addons/dialogic/` — Dialogic 插件及其本地代码

## Development Guidelines

### Godot

- 优先使用现有场景和节点结构，不要为了简单功能无谓地动态创建节点。
- 修改 `.tscn` 前先理解对应脚本和节点之间的关系。
- 保持现有 GDScript 风格和中文注释。

### Dialogic

- 剧情内容主要修改 `timelines/*.dtl`。
- 角色信息修改 `characters/*.dch`。
- 不要直接修改 `addons/dialogic/` 中的第三方插件代码，除非确实需要修复或扩展插件。

### Game State

`GameState` 是全局 Autoload，负责：

- 章节解锁
- 章节完成状态
- 当前章节
- 游戏层存档
- Dialogic 存档衔接

修改存档逻辑时必须同时考虑 Godot 存档与 Dialogic 存档之间的状态同步。

### Story

这是以剧情和人物关系为核心的作品。

修改剧情时不要只追求代码层面的正确性，还要保持：

- 人物性格一致
- 对话自然
- 前后剧情连续
- 诗词引用准确
- 演出节奏合理

### Assets

新增资源时使用现有目录结构，不要把图片、音乐、音效直接堆在项目根目录。

## Before Committing

- 确认资源路径正确。
- 确认 GDScript 没有明显语法错误。
- 确认 Dialogic timeline 中的角色、背景和音频路径存在。
- 不要提交 `.godot/` 等生成文件。
- Commit message 简洁描述实际修改。
