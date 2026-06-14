# 图片 OCR (文字识别 + 版面分析)

## 功能
拍照或选择图片，AI 自动识别图中文字和版面结构。支持两种模式：
- **文字识别**：提取图片中的纯文字内容（PaddleOCR）
- **版面分析**：识别文档结构，包括文字、表格、公式、图表区域（PP-StructureV3）

结果自动保存，可查看历史记录（含原图）。

## 流程
```
用户拍照/选图
    │
    ├── 文字识别模式
    │       │
    │       ▼
    │   POST /api/tools/ocr (multipart file)
    │       │
    │       ▼
    │   PaddleOCR 文字识别 → 提取文本行
    │       │
    │       ▼
    │   保存 OcrRecord → 返回结果
    │
    └── 版面分析模式
            │
            ▼
        POST /api/tools/ocr/structure (multipart file)
            │
            ▼
        PP-StructureV3 版面分析
            │
            ├── 文字区域 → 文本
            ├── 表格区域 → HTML
            ├── 公式区域 → LaTeX
            └── 图表区域 → 结构化数据
            │
            ▼
        返回 Markdown + 元素列表
```

## API 端点
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /api/tools/ocr | 上传图片识别文字（自动保存记录） |
| POST | /api/tools/ocr/structure | 上传图片分析版面结构（PP-StructureV3） |
| GET | /api/tools/ocr/records | OCR 文字识别记录列表 |
| GET | /api/tools/ocr/records/{id} | 单条记录详情（含原图） |

## 技术实现
- **文字识别**: PaddleOCR (`lang=ch`, 离线免费)
- **版面分析**: PP-StructureV3 (版面检测 + 表格 + 公式 + 图表)
- **兜底方案**: Qwen-VL (`qwen-vl-plus`) — 当 PaddleOCR 无法提取文字时自动启用
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
- 模式切换: 文字识别 / 版面分析（SegmentedButton）
- 文字识别: 图片缩略图 + 识别文字（可选中复制）
- 版面分析: 图片缩略图 + Markdown 视图 + 元素列表（类型标签 + 内容）
- 历史列表（文字识别模式）: 文字摘要 + 时间，点击查看原图和完整文字
