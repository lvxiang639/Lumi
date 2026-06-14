# 商店 (Shop)

## 功能
虚拟商店，可购买角色服装和声音包。

## 流程
```
打开商店 → 加载商品列表
    │
    ▼
GET /api/shop/outfits + GET /api/shop/voices
    │
    ▼
显示: 服装列表 + 声音包列表
    │
    ▼
点击"购买" → POST /api/shop/purchase
    │
    ▼
刷新列表，已拥有显示"已拥有"标签
```

## API 端点
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | /api/shop/outfits | 获取服装列表 |
| GET | /api/shop/voices | 获取声音包列表 |
| POST | /api/shop/purchase | 购买商品 |

## 商品类型
| 类型 | 说明 | 示例 |
|------|------|------|
| outfit | 角色服装 | 校服、水手服 |
| voice_pack | 声音包 | 温柔姐姐、毒舌损友 |

## 数据模型
| 表 | 说明 |
|------|------|
| characters | 角色配置 |
| outfits | 服装定义 |
| voice_packs | 声音包定义 |
| user_inventory | 用户拥有的物品 |

## 前端
- 工具中心无直接入口，通过"我"→角色管理进入
- 列表显示: 图标 + 名称 + 价格/类型 + 购买按钮/已拥有标签
- 支持深色模式
