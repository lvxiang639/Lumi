# 图片 OCR (文字识别)

## 功能
拍照或选择图片，AI 自动识别图中文字。结果自动保存，可查看历史记录（含原图）。

## 流程
```
用户拍照/选图
    │
    ▼
POST /api/tools/ocr (multipart file)
    │
    ▼
图片 → base64 → Qwen 多模态 API
    │
    ▼
Prompt: "请识别图片中的所有文字内容"
    │
    ▼
保存 OcrRecord (图片base64 + 识别文字) → 返回结果
    │
    ▼
前端显示: 原图 + 识别文字
    │
    ▼
历史记录可点击查看原图和文字
```

## API 端点
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /api/tools/ocr | 上传图片识别(自动保存记录) |
| GET | /api/tools/ocr/records | OCR 记录列表 |
| GET | /api/tools/ocr/records/{id} | 记录详情(含原图) |

## 技术实现
- **模型**: Qwen 多模态 (`qwen-plus`)
- **图片存储**: base64 编码存入 ocr_records 表
- **超时**: 30秒
- **支持格式**: JPEG, PNG

## 数据模型
| 字段 | 类型 | 说明 |
|------|------|------|
| image_base64 | Text | data:image/xxx;base64,... |
| text | Text | 识别出的文字 |
| created_at | DateTime | 识别时间 |

## 前端
- 工具中心入口: "OCR"
- 点击相机按钮 → 拍照/选图
- 结果区: 图片缩略图 + 识别文字(可选中复制)
- 历史列表: 文字摘要 + 时间，点击查看原图和完整文字
