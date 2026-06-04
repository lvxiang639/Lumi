# 记账系统 (Expense)

## 数据模型
```
expense_records: id, user_id, amount(正数支出/负数收入), category, remark, recorded_at
```

## 入口方式

### 方式 1：对话触发
```
用户说 "午餐花了50元"
    │
    ▼
LLM intent classify → "expense"
    │
    ▼
ExpenseSkill.execute()
    │
    ▼
LLM 提取: {amount: 50, category: "餐饮", remark: "午餐"}
    │
    ▼
存入 expense_records → 回复 "已记录：支出 餐饮 50.00元"
```

### 方式 2：工具面板
```
🔧 工具 → 记账 tab
    │
    ├── 周/月切换 → 显示统计
    ├── 分类饼图 → 各类金额
    ├── 记录列表 → 金额/分类/备注
    ├── ✏️ 编辑 → 修改金额/分类/备注
    └── 🗑 删除 → 长按或点删除按钮
```

## 统计 API
```
GET /api/expenses/stats?period=week|month
    │
    ▼
按北京时间过滤 → 按分类 SUM → 返回 {total_expense, by_category}
```

## 关键逻辑
- **正数 = 支出，负数 = 收入**：`amount > 0` 显示红色 `-`，`amount < 0` 显示绿色 `+`
- **分类**：餐饮/交通/购物/娱乐/住房/医疗/教育/其他
- **时区**：北京时间 (UTC+8)，与用户最近交互时间一致
- **备注截断**：LLM 提取时限制 20 字，存储时 `[:500]` 兜底
