# 心情日记 (Mood)

## 数据模型
```
mood_logs: id, user_id, emotion, intensity, note, created_at
```

## 入口方式

### 方式 1：工具面板
```
🔧 工具 → 心情 tab
    │
    ├── 6 种情绪按钮: 😊开心 😢难过 😠生气 😌平静 😲惊讶 😟担心
    │   点击 → POST /api/notes/moods → 记录当前心情
    │
    ├── 本周统计: 😊×3 😢×1 😌×5
    │   数据来自 GET /api/notes/moods/stats?period=week
    │
    └── 历史记录: 按时间倒序，显示 emoji + 情绪名 + 时间
```

### 方式 2：情绪系统联动
```
对话中检测到情绪变化 → EmotionState 更新
    ↓
主动关怀: "感觉你心情不太好，要聊聊吗？"
    ↓
用户也可以手动在心情 tab 记录
```

## 统计 API
```
GET /api/notes/moods/stats?period=week|month
    │
    ▼
按北京时间过滤 → 按 emotion 分组 COUNT → 返回 {by_emotion: {joy: 3, sad: 1, ...}}
```

## 关键逻辑
- **双系统并存**：MoodLog（手动记录）和 UserEmotionState（自动检测）互不干扰
- **情绪值映射**：joy/sad/angry/calm/surprised/worried 六种，与情绪系统一致
- **默认强度**：手动记录默认 intensity=1.0
