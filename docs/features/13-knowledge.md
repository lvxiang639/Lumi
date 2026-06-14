# 知识库 (Knowledge Base)

## 功能
上传文档(PDF/Word/TXT)，基于文档内容进行 AI 问答(RAG)。

## 流程
```
用户上传文档
    │
    ▼
POST /api/knowledge/upload → 文档分块 → BGE-M3 向量化 → FAISS 索引
    │
    ▼
POST /api/knowledge/{id}/chat → 用户提问 → 向量检索相关块 → LLM 回答
    │
    ▼
返回答案 + 引用来源
```

## API 端点
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /api/knowledge/upload | 上传文档并创建知识库 |
| GET | /api/knowledge | 列出所有知识库 |
| DELETE | /api/knowledge/{id} | 删除知识库 |
| POST | /api/knowledge/{id}/chat | 基于知识库问答 |

## 技术栈
- **Embedding**: BGE-M3 (1024维)，通过 sentence-transformers
- **向量搜索**: FAISS (Facebook AI Similarity Search)
- **分块策略**: 按段落分块，保留上下文重叠
- **存储**: 原始文档 MinIO，文本块 PostgreSQL

## 数据模型
| 表 | 关键字段 |
|------|---------|
| knowledge_bases | id, user_id, title, file_url |
| knowledge_chunks | id, kb_id, chunk_index, content, embedding(ARRAY) |

## 前端
- 工具中心入口: "知识库"
- 上传按钮: 选择 PDF/Word/TXT
- 列表: 文档名 + 文本块数量
- 删除: 按钮删除
- 空状态: 引导上传
