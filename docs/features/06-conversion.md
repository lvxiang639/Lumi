# 文件转换 (Conversion)

## 两种入口

### 对话触发
```
聊天中点击 📎 → 选文件
    │
    ▼
自动判断: .docx→PDF  .pdf→DOCX
    │
    ▼
POST /api/tools/convert?target=pdf
    ↓
上传到 MinIO (bucket: lingxi)
    ↓
存入 converted_files 表
    ↓
返回 JSON: {target_name, download_url, file_size}
    ↓
聊天显示: "✅ 转换完成: xxx.pdf, 可到工具→文件处理下载"
```

### 工具面板
```
🔧 工具 → 文件 tab
    │
    ├── [选择文件] → [开始转换]
    ├── 转换状态
    └── 转换历史
         ├── PDF 红图标 / DOCX 蓝图标
         ├── 文件名 + 大小 + 时间
         └── 📥 下载 (presigned URL)
```

## 数据模型
```
converted_files: id, user_id, original_name, target_name, object_name, content_type, file_size
```

## 转换引擎
```
PDF→DOCX: pdf2docx.Converter (纯 Python)
DOCX→PDF: python-docx + fpdf2 (CJK 字体: macOS PingFang)
```

## MinIO 存储
```
上传: minio_service.upload_file() → conversions/{uuid}.pdf
下载: minio_service.get_download_url() → presigned URL (1h)
```
