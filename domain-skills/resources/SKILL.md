---
name: resources
description: 公司级共享资源目录。当需要查找水库数据、GIS底图、行政边界、水资源年报、行业规范时触发。
---

# 共享资源 (~/Dev/Work/shared/resources/)

水利公司级共享数据，多个项目复用。读取时用绝对路径 `~/Dev/Work/shared/resources/...`。

## 数据库 (data/)

| 路径 | 内容 |
|------|------|
| `data/db_water_stats.db` | 全省水资源统计（~92 县 × 6 年 × 3 类型 = 1650 条） |
| `data/db_reservoirs.db` | 水库数据（4278 条，含生态流量） |
| `data/原始xlsx/` | 原始 Excel 数据（导入源） |
| `data/工程资料/` | 工程详表等 |

## GIS (gis/)

| 路径 | 内容 |
|------|------|
| `gis/水利要素/水库/` | 水库点位 shp |
| `gis/水利要素/` | 河流、水闸等水利要素 |
| `gis/行政边界乡镇/` | 乡镇级行政区划 shp（CGCS2000）|
| `gis/专题数据/洪水风险/` | 洪水风险专题 |
| `gis/专题数据/岸线规划/` | 岸线规划专题 |
| `gis/专题数据/生态流量/` | 生态流量专题 |
| `gis/专题数据/供水管网/` | 供水管网专题 |
| `gis/小水电/` | 小水电 geojson |
| `gis/其他.gdb/` | ArcGIS GDB（杂项空间数据）|

## 参考资料 (references/)

| 路径 | 内容 |
|------|------|
| `references/standards/` | 行业规范、政策文件 |
| `references/planning/` | 规划报告 |
| `references/internal/` | 公司内部模板、字体、软著 |
| `references/data/` | 数据资源索引 |
| `references/environmental/` | 环境相关资料 |

## 命令行工具 (bin/)

| 工具 | 用途 |
|------|------|
| `bin/water_stats.py` | 全省水资源统计数据导入 + 查询 |
| `bin/reservoir_query.py` | 水库数据查询 + 生态流量导入 |
| `bin/import_reservoir.py` | 从工程详表导入水库 |

对应 CC commands 在 `~/Dev/Work/shared/resources/.claude/commands/`：
`/import-stats` `/extract-stats` `/query-stats` `/import-reservoirs` `/extract-reservoirs` `/query-reservoirs`

## 约束

- GIS 坐标系统一为 CGCS2000，输出可转 WGS84
- 大文件（shp/gdb/xlsx）不要 git track，只在本地使用
- 修改共享数据前确认不影响其他项目
- 所有数据走 SQLite DB，xlsx 只是导入源
