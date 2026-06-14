# 倒数日 (Countdown)

## 功能
记录重要日期，自动计算剩余天数。支持滑动删除。

## 流程
```
用户点击 + → 输入事件名称 + 选择日期
    │
    ▼
POST /api/countdown → 保存到 countdowns 表
    │
    ▼
列表显示: 天数徽章 + 事件名 + 倒计时标签
    │
    ▼
左滑删除 → DELETE /api/countdown/{id}
```

## API 端点
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | /api/countdown | 获取所有倒数日 |
| POST | /api/countdown | 创建倒数日 |
| DELETE | /api/countdown/{id} | 删除倒数日 |

## 天数计算
```python
def _daysLeft(target_date):
    target = datetime.strptime(target_date, "%Y-%m-%d").date()
    now = date.today()
    return (target - now).days
```

- 正数: "还有 X 天"
- 0: "🎉 就是今天！"
- 负数: "已过去 X 天"
- ≤3 天且未过期: 红色警示

## 数据模型
| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| user_id | UUID | 用户ID |
| title | String | 事件名称 |
| target_date | DateTime | 目标日期 |
| created_at | DateTime | 创建时间 |

## 前端
- 工具中心入口: "倒数日"
- 列表卡片: 天数徽章(彩色) + 标题 + 日期
- 空状态: 图标容器引导创建
- 滑动删除: Dismissible 组件
