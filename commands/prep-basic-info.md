---
description: 基础信息数据准备（DB优先+网搜补充→01-06.md+参考资料溯源）
---

为目标县市生成6个基础信息MD文件，用于 `/gen-report` 报告生成。

用户提供了参数: $ARGUMENTS

## 流程

### 1. 解析参数

从 `$ARGUMENTS` 解析目标县市名（如 "天台"）。

确定目录：
- 数据目录：`~/Dev/Work/projects/eco-flow/{city拼音}-{county}/data/`
- 参考资料：`~/Dev/Work/projects/eco-flow/{city拼音}-{county}/data/参考资料/`
- 格式模板：`~/Dev/Work/projects/eco-flow/lishui-景宁/data/01_基本信息.md` ~ `06_水资源概况.md`

### 2. 先查DB（优先级最高）

**DB有的数据直接用，不要网搜。** 这是铁律。

从 `~/Dev/Work/projects/eco-flow/data/db_water_stats.db` 查询所有可用 stat_type：

```sql
-- 查看该县有哪些数据类型
SELECT stat_type, year, substr(data,1,100) FROM water_stats
WHERE county='{县名}县' ORDER BY stat_type, year
```

**已入库的 stat_type 及对应文件：**

| stat_type | 对应文件 | year | 说明 |
|-----------|---------|------|------|
| `geography` | 01_基本信息 | 0 | 经纬度、面积、地势、相邻县市 |
| `admin_division` | 02_行政区划 | 具体年份 | 乡镇街道、人口、城镇化率 |
| `economic` | 03_经济社会 | 2019-2024 | GDP、人口 |
| `hydrology` | 04_河流水系 | 0 | 水系、主要河流、水库统计 |
| `climate` | 05_水文气象 | 0 | 气温、降水、日照、无霜期 |
| `supply` | 06_水资源概况 | 2019-2024 | 供水量5年表 |
| `usage` | 06_水资源概况 | 2019-2024 | 用水量5年表 |
| `water_resource` | 06_水资源概况 | 0 | 多年平均水资源总量 |

从 `~/Dev/Work/projects/eco-flow/data/db_reservoirs.db` 补充水库详情：
```sql
SELECT scale, COUNT(*) FROM reservoirs WHERE county='{县名}县' GROUP BY scale
SELECT name, scale, total_capacity, drainage_area, eco_flow_target
FROM reservoirs WHERE county='{县名}县' ORDER BY total_capacity DESC
```

### 3. 网搜补充（仅DB缺失字段）

先检查 Step 2 查到的数据，**只对DB里没有或为空的字段才网搜**。

如果某个 stat_type 对该县不存在，才搜：
- geography 缺失 → 搜 `"{县名} 地理位置 面积 经纬度"`
- admin_division 缺失 → 搜 `"{县名} 行政区划 乡镇街道"` + `"{县名} 统计公报"`
- climate 缺失 → 搜 `"{县名} 气候 年均气温 降水量"`
- hydrology 缺失 → 搜 `"{县名} 河流水系"` / `"{县名} 水文概况"`
- water_resource 缺失 → 搜 `"{县名} 水资源公报"` / `"{市名} 水资源公报"`

**搜到的数据必须做两件事：**
1. 存到 `参考资料/网搜汇总.md`（含URL、摘录内容、搜索日期）
2. **导入DB**：运行 `import_county_info.py` 或直接 SQL INSERT，确保下次不再网搜

原始文件（PDF/网页）下载到 `~/Dev/Work/shared/resources/data/原始xlsx/原始网搜/{县名}/`

### 4. 生成6个MD

严格按景宁模板的**标题结构和字段**，全部从DB取数填充。找不到的标 `[待补充]`，每个文件末尾加 `<!-- 来源: xxx -->` 注释。

| 文件 | 核心字段 | 数据源 |
|------|---------|--------|
| 01_基本信息.md | 地理位置、经纬度、面积、东西南北长宽、行政中心 | DB:geography |
| 02_行政区划.md | 街道/镇/乡数量及名称、常住人口、城镇化率 | DB:admin_division |
| 03_经济社会.md | GDP(总量+人均+三产结构)、常住人口 | DB:economic |
| 04_河流水系.md | 水系归属、主要河流(名称/长度/流域面积)、水库总数 | DB:hydrology + reservoirs |
| 05_水文气象.md | 气候类型、年均气温、年降水量、日照、无霜期 | DB:climate |
| 06_水资源概况.md | 水资源总量、供水量表(5年)、用水量表(5年)、趋势分析 | DB:water_resource + supply + usage |

### 5. 保存参考资料

确保 `参考资料/网搜汇总.md` 包含：
- 所有引用URL列表
- 每条数据的来源标注
- 搜索日期

### 6. 完成报告

汇总输出：
- 6个文件生成状态
- `[待补充]` 字段列表
- 建议用户核实的关键数据点

## 导入工具

新县市的基础信息需要入库时，参考/扩展脚本：
`code/脚本/core/db/import_county_info.py --county {县名}县 --city {市名}市`
