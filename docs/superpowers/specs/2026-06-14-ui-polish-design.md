# UI Polish — Agent List & Profile Screens

**Date:** 2026-06-14  
**Scope:** Bug fix + detail polish for `agent_list_page.dart` and `profile_screen.dart`

## agent_list_page.dart

### Bug Fix: GestureDetector nesting (line 106-108)
- `Container` does not have `onTap` — the current code puts `onTap` on `Container` and nests `GestureDetector` as a child incorrectly
- Fix: wrap `Container` with `GestureDetector`, move `onTap` to `GestureDetector`, keep `decoration`/`padding` on `Container`

### Close button in history detail bottom sheet
- Add an `IconButton(Icons.close)` to the right side of the title row in `_showHistoryDetail`

### Empty state for history tab
- Replace plain `Center(child: Text(...))` with styled empty state matching `discover_screen.dart` pattern:
  - Centered icon in rounded container with accent background
  - Primary text: "暂无使用记录"
  - Secondary text: "使用 Agent 后，记录会显示在这里"

### Pull-to-refresh
- Wrap both `_agentList` and `_historyList` ListViews with `RefreshIndicator`
- `onRefresh` calls `_load()`

### Card tap feedback
- Wrap agent card `Container` with `Material(color: Colors.transparent)` + `InkWell` for ripple effect
- History cards already use `GestureDetector` (fixed above)

## profile_screen.dart

### AI Persona: read actual user data
- In `_showPersonaSheet`, replace `String selected = '默认'` with reading from `AuthProvider.user.persona`
- Default to `'默认'` if null/empty

### Icon colors for settings items
- Use the already-added `iconColor` parameter on `_settingItem`:
  - 角色管理 (Icons.auto_awesome) → `AppColors.accent`
  - AI 人格 (Icons.psychology_outlined) → `Color(0xFF8B5CF6)` (purple)
  - 邮箱设置 (Icons.email_outlined) → `AppColors.accentBlue`
  - 对话摘要列表 (Icons.summarize_outlined) → `Color(0xFFF59E0B)` (amber)
  - 关于/隐私 → default (textSecondary)

### Theme chip polish
- Add subtle border to the theme mode chip for better visibility
- Border color: `AppColors.border(b)`
