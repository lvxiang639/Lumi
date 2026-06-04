# 笔记系统 (Notes)

## 数据模型
```
notes: id, user_id, title, content, note_type("note"|"journal"), created_at, updated_at
```

## 入口方式

### 方式 1：工具面板
```
🔧 工具 → 笔记 tab
    │
    ├── [+ 新建] → 弹出标题+内容对话框 → POST /api/notes
    ├── 笔记列表 → 标题 + 内容预览(2行)
    └── 🗑 删除 → DELETE /api/notes/{id}
```

### 方式 2：对话触发（未来）
```
用户说 "记个笔记" → intent "note" → 语音转文字 → 存为笔记
```

## API 端点
```
GET    /api/notes?note_type=note     → 笔记列表
POST   /api/notes                     → 创建笔记
PUT    /api/notes/{id}                → 编辑笔记
DELETE /api/notes/{id}                → 删除笔记
```

## 关键逻辑
- **note_type 区分**：`note`=普通笔记，`journal`=日记（预留）
- **未来联动**：日记内容 → LLM 自动总结 → 存入长期记忆
