# 图片 OCR

## 流程
```
用户拍照/选图
    │
    ▼
POST /api/tools/ocr (multipart file)
    │
    ▼
图片 → base64 → Qwen-VL 多模态 API
    │
    ▼
Prompt: "识别文字 + 判断类型(receipt/card/text)"
    │
    ▼
返回 {"type": "receipt", "text": "识别出的所有文字"}
    │
    ▼
前端显示: 🧾发票 / 👤名片 / 📄文字 + 识别结果
```

## API 端点
```
POST /api/tools/ocr → multipart file → Qwen-VL → JSON
```

## 类型判断
| 类型 | 标签 | 前端显示 |
|------|------|---------|
| receipt | 发票/收据 | 🧾 发票 |
| card | 名片 | 👤 名片 |
| text | 普通文字 | 📄 文字 |

## 关键逻辑
- **模型**: Qwen-VL (`force_model="qwen"`)，已有 API key
- **JSON 解析**: 优先 `json.loads()`，失败用正则提取 `{...}`
- **未来联动**: 识别到发票 → 一键创建记账记录
