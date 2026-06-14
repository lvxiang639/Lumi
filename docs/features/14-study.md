# 学习辅导 (Study Tutor)

## 功能
AI 辅导学生学习，支持文字提问和拍照识题，自动分步讲解。

## 三个 Tab

### 解题 (Tab 0)
```
输入题目(文字或拍照)
    │
    ▼
POST /api/study/solve → OCR(可选) → DeepSeek 分步讲解 → 保存记录
    │
    ▼
显示: 科目标签 + 解题步骤 + 关键点 + 答案
```

### 记录 (Tab 1)
- 按科目筛选(全部/数学/语文/英语)
- 每项显示: 科目徽章 + 题目摘要 + 答案预览 + 时间
- 点击查看完整解题过程(底部弹窗)
- 标记"已掌握"

### 分析 (Tab 2)
- 本周统计: 各科做题数量
- 薄弱点: 按标签汇总(错≥2次)
- 建议 + 一键生成练习题

## API 端点
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /api/study/solve | 解题(文字+可选图片) |
| GET | /api/study/records | 答题记录列表 |
| PUT | /api/study/records/{id} | 更新状态 |
| GET | /api/study/analysis | 薄弱点分析 |
| POST | /api/study/practice | 生成练习题 |

## 同音字闯关 (Tab 3)
独立的同音字填空练习，详见 [15-homophone.md](15-homophone.md)

## OCR 方案
1. **PaddleOCR**（优先）: 免费离线，中文识别最佳。首次加载 ~3s
2. **Qwen 多模态**（备选）: PaddleOCR 失败时自动启用
3. 图片通过 multipart form 上传

## 数据模型
| 表 | 关键字段 |
|------|---------|
| study_records | question, answer(JSON), subject, tags, status |
| practice_pushes | question, answer, solved |

## 前端
- 工具中心入口: "辅导"
- 辅导页: 解题/记录/分析/同音字 四个 Tab
