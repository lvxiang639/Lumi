# 家长辅导工具 设计文档

## 概述
拍照/文字/语音输入题目 → AI 分步讲解 → 自动记录错题 → 弱点分析 → 智能推送练习题

## 数据模型

### study_records
- id, user_id, child_name, subject(语文/数学/英语)
- tags (AI自动打标), question, answer, image_url
- status (未掌握/已掌握), created_at

### practice_pushes  
- id, user_id, record_id, question, answer, solved, created_at

## 交互流程
1. 输入（拍照/文字/语音） → OCR → AI 讲解
2. 自动归档到错题本
3. 错题本按学科/时间浏览
4. 弱点分析（标签统计） → 推送练习题

## API 端点
- POST /api/study/solve — 解题入口
- GET /api/study/records — 错题列表
- PUT /api/study/records/{id} — 标记已掌握
- GET /api/study/analysis — 弱点分析
- POST /api/study/practice — 生成练习题

## 实施范围
P0: 模型+API+拍照解题+错题本+弱点分析
P1: 语音输入+练习题推送
