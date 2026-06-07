# 灵犀 2.0 设计文档

## 概述

将灵犀 App 从基础 Material Design 暗色科幻风全面升级为现代、干净的双模式设计语言。参考微信/WhatsApp 的克制清晰 + 陪伴感，打造差异化的 AI 伴侣界面。

**设计方向**: Soft Clarity — 微信的克制 × 陪伴的温度 × 现代细腻层次

---

## 一、全局设计系统

### 1.1 色彩体系

**浅色模式（默认跟随系统）**
| Token | 色值 | 用途 |
|-------|------|------|
| `bg-primary` | `#F5F5F5` | 聊天背景、列表背景 |
| `bg-card` | `#FFFFFF` | 卡片、气泡（AI侧） |
| `accent-primary` | `#10B981` | 主强调色、用户气泡、选中态 |
| `accent-secondary` | `#3B82F6` | 链接、次要按钮 |
| `text-primary` | `#1A1A1A` | 主文字 |
| `text-secondary` | `#8E8E93` | 辅助文字、时间戳 |
| `border-light` | `#E5E5EA` | 分割线、气泡边框 |

**深色模式**
| Token | 色值 | 用途 |
|-------|------|------|
| `bg-primary` | `#0D1117` | 主背景 |
| `bg-card` | `#161B22` | 卡片、气泡 |
| `accent-primary` | `#10B981` | 主强调色 |
| `accent-secondary` | `#3B82F6` | 次要强调 |
| `text-primary` | `#E6E6E6` | 主文字 |
| `text-secondary` | `#8B949E` | 辅助文字 |
| `border-light` | `#21262D` | 分割线 |

### 1.2 字体

- **中英文**: PingFang SC（iOS/macOS 系统原生，微信同款）
- **字号层级**: 17（标题）/ 15（正文）/ 13（辅助）/ 11（时间戳）
- **行高**: 1.5（正文）、1.3（标题）

### 1.3 间距 & 圆角

- **圆角**: 卡片 8px、气泡 16px、按钮 24px、头像 全圆
- **间距**: 4px 基础单位，常用 8/12/16/20/24
- **页面内边距**: 左右 16px
- **气泡间距**: 垂直 4px

### 1.4 阴影（仅浅色模式）

- 卡片: `0 1px 3px rgba(0,0,0,0.04)`
- 悬浮按钮: `0 2px 8px rgba(0,0,0,0.08)`
- 深色模式不设阴影，用边框区分层次

---

## 二、信息架构

```
┌─────────────────────────────────────────┐
│              Bottom Nav (3 Tab)          │
│       💬 聊天     🧰 工具     👤 我      │
├─────────────────────────────────────────┤
│                                          │
│  Tab 1: 聊天列表页                       │
│    ├── 搜索栏                            │
│    ├── 对话列表（左滑删除/置顶）          │
│    └── 新建对话 FAB                      │
│                                          │
│  Tab 2: 工具中心                         │
│    ├── 宫格：日历/记账/笔记/心情/邮件/转换│
│    ├── 宫格：搜索/摘要/OCR/文件          │
│    └── 使用统计卡片（可选）               │
│                                          │
│  Tab 3: 个人中心                         │
│    ├── 角色卡片（宠物猫预览）             │
│    ├── 设置列表                          │
│    └── 退出登录                          │
│                                          │
└─────────────────────────────────────────┘
```

---

## 三、页面详细设计

### 3.1 聊天列表页

**布局**:
- 顶部导航栏：标题"灵犀"居中，右侧 `+` 新建按钮
- 搜索栏：粘在导航栏下方，圆角输入框，点击跳转搜索页
- 对话列表：卡片式条目，每项含头像(40px圆形+emoji)、标题、最后消息预览、时间
- 空状态：居中插图 + "开始第一段对话吧" + 新建按钮
- FAB：右下角浮动笔形按钮，新建对话

**手势**:
- 右滑 item → 置顶（蓝色标记）
- 左滑 item → 删除（红色，带确认）
- 下拉刷新

**状态**: loading（骨架屏）、empty（插画引导）、error（重试按钮）、正常列表

### 3.2 聊天页（核心）

**导航栏**:
- 左：← 返回按钮
- 中：AI 头像（32px 圆形，宠物猫 emoji/SVG）+ 名字 + 在线小绿点
- 右：⋮ 更多菜单（邮件摘要、保存笔记、提炼摘要、清空对话）

**消息列表**:
- 背景：WhatsApp 风 — 浅灰底 `#F5F5F5` + CSS 点状纹理图案
- 用户气泡：右对齐，浅绿底 `#DCF8C6`（微信经典色），16px 圆角
- AI 气泡：左对齐，白底灰边 `#FFFFFF` + `#E5E5EA` 边框，16px 圆角
- 时间戳：居中显示，不在气泡内，隔 5 条以上消息出现一次
- 流式回复：AI 气泡带 3 点跳动指示器
- 图片/文件消息：气泡内含缩略图 + 文件名

**输入栏**:
- 表情按钮 😊 | 附件按钮 📎 | 文字输入框（圆角 24px）| 语音按钮 🎤
- 输入框聚焦时自动上推，背景不缩放（键盘避让）
- 语音模式：按住说话，松开发送（微信式）

**长按菜单**（BottomSheet）:
- 复制文字
- 保存为笔记
- 更多操作（转发/删除/引用）

### 3.3 工具中心

**布局**:
- 顶部：页面标题"工具中心"
- 主体：3×N 宫格，每格 图标 + 文字
- 图标用系统 Material Icons，每个工具独立颜色

**工具列表**（9项）:
| 工具 | 图标 | 颜色 | 目标页面 |
|------|------|------|---------|
| 日历 | calendar_month | `#F59E0B` | CalendarPage |
| 记账 | account_balance_wallet | `#10B981` | ExpensePage |
| 笔记 | note_alt | `#3B82F6` | NotesPage |
| 心情 | mood | `#EC4899` | MoodPage |
| 邮件 | email | `#8B5CF6` | EmailPage |
| 转换 | swap_horiz | `#14B8A6` | FilePage |
| 搜索 | search | `#6366F1` | SearchPage |
| 摘要 | summarize | `#F97316` | SummaryPage |
| OCR | document_scanner | `#06B6D4` | OcrPage |

### 3.4 个人中心

**布局**:
- 顶部：角色卡片 — 宠物猫头像(56px) + 名字 + 服装/声音信息 + 换装入口
- 中间：设置列表（卡片式，箭头指示可点击）
  - 邮箱设置
  - 主题切换（浅色/深色/随系统）
  - 对话摘要列表
  - 关于灵犀
- 底部：退出登录（红色文字，居中）

**角色管理**:
- 点击角色卡片 → 底部弹出角色管理 Sheet
- Sheet 内容：服装列表（横向滑动选择）、声音列表（纵向列表选择）、保存

---

## 四、动画 & 微交互

### 4.1 过渡动画
- **页面跳转**: 微信式右滑进入 / 左滑返回（`SlideTransition` + 半透明遮罩）
- **Tab 切换**: 淡入淡出（`FadeTransition`，200ms）
- **BottomSheet**: 从底部弹出，带弹性回弹（`spring` 曲线）

### 4.2 微交互
- **气泡出现**: 从底部淡入 + 上移 8px（`SlideTransition` + `FadeTransition`）
- **流式打字**: 3 个点跳动指示器（依次缩放，间隔 150ms）
- **发送按钮**: 输入框有内容时，附件按钮变发送按钮（微信式旋转动画）
- **Tab 图标**: 选中态微缩放（1.0 → 1.1 → 1.0，150ms）
- **长按反馈**: 轻微震动（`HapticFeedback.lightImpact`）
- **下拉刷新**: 顶部出现主题色圆环动画

### 4.3 主题切换
- 通过 `ValueNotifier<ThemeMode>` 全局控制
- 切换时使用 `AnimatedContainer` / `AnimatedDefaultTextStyle` 平滑过渡
- 主题偏好持久化到 `SharedPreferences`

---

## 五、技术实现要点

### 5.1 主题系统
```dart
// app.dart 改造
class LingxiApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [...],
      child: Consumer<ThemeProvider>(
        builder: (ctx, themeProvider, _) => MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeProvider.themeMode,
          ...
        ),
      ),
    );
  }
}
```

### 5.2 目录结构调整
```
lib/
├── app.dart
├── main.dart
├── config.dart
├── theme/
│   ├── app_theme.dart        # 浅色/深色主题定义
│   ├── app_colors.dart       # 色彩常量
│   └── app_text_styles.dart  # 文字样式
├── models/                    # 不变
├── providers/                 # + theme_provider.dart
├── screens/
│   ├── chat/
│   │   ├── chat_screen.dart
│   │   └── widgets/
│   │       ├── chat_bubble.dart
│   │       ├── input_bar.dart
│   │       └── message_menu.dart
│   ├── conversation/
│   │   └── conversation_list_screen.dart
│   ├── tools/
│   │   └── tools_center_screen.dart
│   ├── profile/
│   │   └── profile_screen.dart
│   ├── auth/
│   │   └── login_screen.dart
│   └── main_screen.dart
├── widgets/                   # 共享组件
│   ├── character_avatar.dart
│   └── ...
└── services/                  # 不变
```

### 5.3 关键依赖
- 现有依赖不变（provider、http 等）
- 不新增第三方 UI 库
- 聊天背景纹理：用 `CustomPainter` 绘制点状图案

### 5.4 向后兼容
- 所有 API 接口不变
- WebSocket 消息协议不变
- Provider 接口保留现有公共方法
- Config (app_base_url 等) 不变

---

## 六、实现范围 & 优先级

### P0（核心，必须实现）
1. 全局主题系统（浅/深双模式 + 主题切换持久化）
2. 聊天列表页重构
3. 聊天页重构（气泡、输入栏、时间戳）
4. 底部导航重构（3 Tab 图标式）
5. 个人中心重构

### P1（重要，尽快实现）
6. 工具中心独立页
7. 登录页视觉升级
8. 聊天气泡时间显示
9. 页面过渡动画
10. 聊天背景纹理

### P2（可后续迭代）
11. 左滑手势（删除/置顶）
12. 流式打字指示器动画
13. 长按消息菜单
14. 骨架屏加载态
15. 各工具子页面视觉统一

---

## 七、不改变的部分
- 后端 API / WebSocket 协议
- 认证流程（手机号登录）
- 角色系统（宠物猫 SVG/WebView）
- 各工具页面功能逻辑
- TTS/ASR 服务
- Provider 核心业务逻辑
