# 灵犀教育版 — Web 端重构

## 定位
面对江苏小学家长，基于苏教版教材的 AI 辅导平台。家长桌面端管理，孩子平板端做题。

## 前端技术栈
- Web: React + TypeScript + Vite
- 移动端: 保留现有 Flutter 代码，核心学习功能双端共用后端

## 页面架构

### 导航（桌面端左侧栏，移动端底部 Tab）
| Tab | 功能 |
|-----|------|
| 🏠 学习中心 | 孩子汇总面板、每日任务、薄弱提醒、快捷入口 |
| 📚 课本 | 苏教版目录（预置）+ 用户上传 PDF → RAG 对话该课本 |
| 📝 练习 | AI 出题/做题/专题训练/奥数/古诗词 |
| ❌ 错题本 | 按知识点回顾错题、生成类似题强化 |
| 📈 成长 | 知识图谱 + 考试记录 + 学习报告 |

### 💬 聊天助手
- 全局右下角悬浮按钮
- 点击呼出聊天面板，自动带当前页面上下文
- 家长可随时对任何内容提问

## 核心模块

### 1. 课本管理
- 预置苏教版语数外知识点大纲（按年级/学期/单元/课次）
- 用户上传：PDF 拍照 → OCR → 拆分为课 → 向量索引 → RAG 对话
- 复用现有 `knowledge_bases` + `knowledge_chunks` 表

### 2. 练习中心
- AI 出题：选孩子 + 教材课次/知识点/难度 → LLM 生成题目
- 做题：逐题展示 → 输入答案 → AI 批改 → 讲解
- 错题自动入库，标记知识点
- 专题训练：奥数/古诗词/文言文/应用题 独立入口

### 3. 错题本
- 按知识点分组展示错题
- 每道错题：原题、错误答案、正确答案、AI 讲解
- "再做一题"按钮 → LLM 生成类似题
- 连续做对 2 次 → 标记已掌握 → 从错题本移除

### 4. 知识图谱
- `knowledge_points` 表：年级/学期/单元/知识点（树形，4 层）
- 苏教版数据预置
- 每个孩子独立掌握度（绿>70% / 黄 30-70% / 红<30% / 灰 未学）
- LLM 解题时自动匹配知识点（solve prompt 增加 `knowledge_points` 字段）

### 5. 成长记录
- 做题量趋势 + 掌握率变化（折线图）
- 考试分数录入：日期 + 科目 + 分数 + 备注
- 每周 AI 学习报告：总结薄弱点、进步点、建议

### 6. 专项训练
- 模板化 prompt：奥数/古诗词填空/文言文翻译/英语语法
- 用户自定义：输入"生成10道分数约分题" → LLM 出题

## 数据库新表

| 表 | 关键字段 |
|------|---------|
| knowledge_points | id, parent_id, name, grade, subject, semester, unit, keywords |
| exam_records | id, user_id, child_id, subject, score, total, exam_date, note |
| textbooks | id, title, grade, subject, publisher, semester, chapters(json) |
| study_records | +knowledge_point_id, +retry_count, +retry_correct |

## API 新增

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | /api/edu/knowledge-points | 知识点树 |
| GET | /api/edu/wrong-book | 错题本（按孩子/科目/知识点筛选） |
| POST | /api/edu/practice/generate | AI 出题 |
| POST | /api/edu/practice/grade | 批改答案 |
| GET | /api/edu/exam-records | 考试记录 CRUD |
| POST | /api/edu/exam-records | 录入考试分数 |
| GET | /api/edu/report/weekly | 周学习报告 |
| POST | /api/textbooks/upload | 上传课本 PDF |
| GET | /api/textbooks/{id} | 课本目录 |
| POST | /api/textbooks/{id}/chat | RAG 对话课本 |

## React 项目结构
```
web/
├── src/
│   ├── App.tsx
│   ├── layouts/MainLayout.tsx      (侧边栏 + 内容区)
│   ├── pages/
│   │   ├── Dashboard.tsx           (学习中心)
│   │   ├── Textbooks.tsx           (课本管理)
│   │   ├── Practice.tsx            (练习中心)
│   │   ├── WrongBook.tsx           (错题本)
│   │   └── Growth.tsx              (成长记录)
│   ├── components/
│   │   ├── ChatFAB.tsx             (悬浮聊天按钮)
│   │   ├── ChatPanel.tsx           (聊天面板)
│   │   ├── ChildSwitcher.tsx       (孩子切换器)
│   │   ├── KnowledgeTree.tsx       (知识图谱)
│   │   └── QuestionCard.tsx        (题目卡片)
│   ├── hooks/
│   └── services/
└── package.json
```

## 实施顺序
1. React 项目初始化 + 基础布局 + 路由
2. 学习中心 Dashboard
3. 课本管理（预置 + 上传）
4. 练习中心（AI 出题 + 批改）
5. 错题本
6. 知识图谱 + 成长记录
7. 聊天助手（悬浮 + 上下文带入）
