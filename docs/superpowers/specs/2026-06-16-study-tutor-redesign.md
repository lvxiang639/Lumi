# 学习辅导重构 — 多孩子支持 + 分析优化

## 核心改动

1. **孩子名字管理** — 独立表 `study_children`，下拉选择 + 输入新增
2. **记录按孩子筛选** — records API 增加 child_id 参数
3. **分析按孩子分组** — 每个孩子独立统计：做题数、掌握率、趋势、薄弱点、AI 建议

## 数据模型

### 新建 `study_children` 表
| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID PK | |
| user_id | UUID FK → users | |
| name | String(50) | 孩子名字 |
| grade | String(20) | 年级（可选，如"三年级"） |
| created_at | DateTime | |

### `study_records` 表变更
- `child_name` → `child_id` (UUID FK → study_children, nullable)
- 保留 `child_name` 字段兼容旧数据（改名 `child_name_deprecated`）

## API

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | /api/study/children | 用户所有孩子列表 |
| POST | /api/study/children | 新增孩子 |
| DELETE | /api/study/children/{id} | 删除 |
| POST | /api/study/solve | child_name → child_id（自动创建孩子） |
| GET | /api/study/records | +child_id 筛选 |
| GET | /api/study/analysis | **重构** — 按孩子分组统计 |
| GET | /api/study/analysis/{child_id} | 单孩子趋势详情 |

## 分析数据结构

```json
{
  "children": [{
    "child_id": "...", "child_name": "小明", "grade": "三年级",
    "total": 28, "mastered": 18, "mastery_rate": 0.64,
    "by_subject": {"数学": 15, "语文": 10, "英语": 3},
    "weak_points": [{"tag": "分数加减", "count": 8}, ...],
    "weekly_trend": [{"week": "W1", "total": 5, "mastered": 2}, ...],
    "ai_suggestion": "本周重点练习分数加减..."
  }],
  "overall": {"total": 40, "mastered": 26, "mastery_rate": 0.65}
}
```

## 前端

- 名字输入框 → Combobox（下拉 + 搜索 + 新增）
- 记录页 → 孩子 + 科目双筛选
- 分析页 → 孩子卡片 × N，每卡片含：统计、趋势、薄弱点、AI 建议
- 解题页 → 选孩子后记录关联

## 实施顺序

1. 后端：新建 study_children 表 + model + migration
2. 后端：children CRUD API
3. 后端：改造 solve/records API（支持 child_id）
4. 后端：重构 analysis API（按孩子分组）
5. 前端：Combobox 名字选择器
6. 前端：记录页双筛选
7. 前端：分析页重构
