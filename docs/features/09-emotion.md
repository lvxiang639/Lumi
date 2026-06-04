# 情绪系统 (Emotion)

## 数据模型
```
user_emotion_states: user_id(PK), current_emotion, intensity, last_updated, last_reason
```

## 流程
```
用户发消息
    │
    ▼
emotion_service.analyze(message)
    │
    ▼ LLM 分析
返回 {emotion: "joy", intensity: 0.8, reason: "升职了"}
    │
    ▼
emotion_service.apply(user_id, emotion_data)
    │
    ├── 加载当前情绪状态
    ├── 计算衰减 (elapsed → decay_rate)
    ├── 混合: 新情绪强度 > 衰减后 → 替换, 否则保留
    └── 存入 user_emotion_states
    │
    ▼
注入 LLM system prompt:
  "当前情绪: joy 😊 (强度 0.8)
   请根据当前情绪调整回复风格: 欢快活泼，多用感叹词"
    │
    ▼
WebSocket → emotion_update → 前端角色动画
```

## 6 种情绪
| emotion | 标签 | 回复风格 | 衰减(/30min) |
|---------|------|---------|-------------|
| joy | 😊 | 欢快活泼 | 0.15 |
| sad | 😢 | 温柔安慰 | 0.12 |
| angry | 😠 | 简短冷淡 | 0.18 |
| calm | 😌 | 正常语调 | 0.05 |
| surprised | 😲 | 带感叹词 | 0.20 |
| worried | 😟 | 关切询问 | 0.10 |

## 关键逻辑
- **衰减混合**: 新情绪强度 >= 衰减后 → 替换为主情绪
- **强度归零**: 自动重置为 calm
- **前端联动**: macOS(PNG) / iOS(SVG) 角色动画切换
