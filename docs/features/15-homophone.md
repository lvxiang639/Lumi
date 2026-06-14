# 同音字组词闯关 (Homophone Exercise)

## 功能
AI 自动生成同音字填空题，学生填写后 AI 批改。

## 流程
```
点击"开始闯关"
    │
    ▼
POST /api/study/homophone/generate → DeepSeek 生成5组同音字题
    │  每组合2-3个词，挖空同音字: __学 → 同、__话 → 童
    ▼
学生填写缺失的字
    │
    ▼
POST /api/study/homophone/{id}/submit → DeepSeek 批改每道题
    │
    ▼
显示结果: ✅正确 / ❌错误 + 详细反馈
```

## 题目格式
```json
{
  "questions": [
    {
      "pinyin": "tóng",
      "words": [
        {"blank": "__学", "answer": "同", "hint": "和'学'组成词语"},
        {"blank": "__话", "answer": "童", "hint": "和'话'组成词语"},
        {"blank": "__牌", "answer": "铜", "hint": "和'牌'组成词语"}
      ]
    }
  ]
}
```

## 批改标准
1. 填字与目标拼音同音（声韵调相同）
2. 组成的词语合理、常见
3. 反馈具体说明对错原因

## API 端点
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /api/study/homophone/generate | 生成5组题 |
| POST | /api/study/homophone/{id}/submit | 提交答案批改 |
| GET | /api/study/homophone/history | 练习历史 |
| GET | /api/study/homophone/{id} | 练习详情 |

## 数据模型
| 字段 | 类型 | 说明 |
|------|------|------|
| questions | Text(JSON) | LLM生成的题目 |
| answers | Text(JSON) | 学生提交的答案 |
| grading | Text(JSON) | LLM批改结果 |
| score | String | 得分如 "12/15" |
| status | String | pending / completed |

## 前端
- 三种模式: idle(开始) / practicing(答题) / reviewing(结果)
- 练习中: 拼音标签 + 挖空词 + 单字输入框
- 批改中: ✅❌标记 + feedback + 成绩
- 历史记录: 列表 + 点击查看题目和答案
