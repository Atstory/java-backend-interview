# 国产化与数据库迁移（18 题详答）

规范 ID 范围见各题标题；原始编号已标注。

<a id="Q001"></a>

### Q001（原始编号: 2）

**【题干】**
Oracle 数据库迁移到 openGauss 数据库的时候，具体语法或者数据类型遇到问题，具体是什么问题？

**【核心结论】**
迁移中高频差异集中在：数据类型映射、PL/SQL 与 PL/pgSQL 语法、序列/伪列、空串与 NULL、分页与层次查询、专有函数与包。需按官方兼容性清单逐项改造，而非“换驱动即通”。

**【详细说明】**
常见具体问题（结合 openGauss/Oracle 官方迁移与兼容说明）：

1. **数据类型**
   - `NUMBER`：Oracle 无精度 NUMBER 与 openGauss `numeric`/`decimal` 映射需明确精度；整数场景常改 `bigint`/`integer`。
   - `VARCHAR2`/`NVARCHAR2` → `varchar`/`nvarchar2`（兼容模式）或 `character varying`；注意字节/字符语义（`CHAR` 语义差异）。
   - `DATE`：Oracle `DATE` 含时分秒；PostgreSQL/openGauss `date` 仅日期，需改用 `timestamp`/`timestamp without time zone`。
   - `CLOB`/`BLOB` → `text`/`clob`、`bytea`/`blob`（视兼容模式）；大对象 API 不同。
   - `RAW`/`LONG RAW` → `bytea`；`LONG` 已不推荐，需拆列或改 `text`。
   - `INTERVAL YEAR TO MONTH` 等间隔类型写法与 Oracle 不完全一致。

2. **语法与 SQL**
   - 伪列：`ROWNUM`、`ROWID` 在 openGauss 中需用窗口函数/`LIMIT`/`ctid` 等替代（A 兼容模式有部分支持，仍建议改写）。
   - 层次查询：`CONNECT BY`/`START WITH` 需改为递归 CTE（`WITH RECURSIVE`）。
   - 外连接旧写法 `(+)` 必须改为 `LEFT/RIGHT JOIN`。
   - `DUAL` 表：openGauss 可提供兼容，但标准写法可不依赖 `DUAL`。
   - 分页：`ROWNUM` 嵌套 → `LIMIT/OFFSET` 或 `FETCH FIRST n ROWS ONLY`。
   - `MERGE`、部分分析函数/提示（hint）语法差异。

3. **过程语言**
   - Oracle PL/SQL 包、`%TYPE`/`%ROWTYPE`、异常体系与 openGauss PL/pgSQL（及兼容 PL）不完全等价；自治事务、管道函数、高级包要重写。
   - `SYSDATE`/`SYSTIMESTAMP` → `current_timestamp`/`now()`（兼容模式下可有同义词）。
   - 字符串拼接：`||` 通用；`CONCAT` 参数个数差异需核对。

4. **空值语义**
   - Oracle 中空字符串常被当作 NULL；openGauss/PostgreSQL 空串与 NULL 分离，`'' IS NULL` 为假，迁移后比较与约束行为会变。

5. **序列与自增**
   - `SEQUENCE` + `nextval` 可用；`IDENTITY`/`SERIAL` 与 Oracle `IDENTITY` 列语法不同。
   - `currval` 会话语义需注意。

6. **权限、同义词、DBLink**
   - 同义词、数据库链接、角色权限模型需重建；部分企业特性无 1:1 对应。

**【示例/写法】**
-- 层次查询改递归 CTE 示例
WITH RECURSIVE org AS (
  SELECT id, parent_id, name FROM dept WHERE parent_id IS NULL
  UNION ALL
  SELECT d.id, d.parent_id, d.name FROM dept d JOIN org o ON d.parent_id = o.id
)
SELECT * FROM org;

-- DATE 含时间：Oracle DATE → timestamp
-- ALTER / 建表时用 timestamp，而非 date

**【易错点】**
- 以为 openGauss「兼容 Oracle」即可零改动上线；兼容模式仍有边界。
- 把 Oracle `DATE` 直接建成 openGauss `date`，丢时分秒。
- 忽略空串与 NULL 差异导致唯一约束/业务判断异常。
- 用 `ROWNUM` 在非兼容或版本差异下直接拷贝。

**【权威依据】**
- openGauss 官方文档：兼容性说明、数据类型、SQL 参考（docs.opengauss.org）
- Oracle Database SQL Language Reference：数据类型与伪列
- PostgreSQL 文档（openGauss 同源参考）：WITH RECURSIVE、NULL 与空串

<a id="Q002"></a>

### Q002（原始编号: 12）

**【题干】**
Oracle 数据库迁移到 openGauss 数据库，性能上有什么差异？

**【核心结论】**
不能简单说谁更快：优化器、执行计划、缓冲池/共享池模型、并行与分区实现、存储引擎路径都不同。迁移后常见是个别 SQL 变慢或变快，需用执行计划与压测定位，而不是整体对比宣传口径。

**【详细说明】**
1. **架构差异带来的表现差异**
   - Oracle：成熟的 CBO、丰富 Hint、RAC、多种分区与并行策略；SGA/PGA 调优体系独立。
   - openGauss：基于 PostgreSQL 演进，增加线程化、向量化执行、列存/行列混存等能力（版本相关）；缓冲与 vacuum/autovacuum、统计信息收集方式与 Oracle 不同。

2. **典型性能落差场景**
   - 复杂连接、子查询、分析函数：计划可能不同，缺统计信息时更易选错。
   - 大批量 DML：undo/redo（或 WAL）模型不同，批量提交策略需重调。
   - 高并发短事务：锁粒度、MVCC 实现细节不同（PostgreSQL 系行版本 vs Oracle undo）。
   - 存储过程密集逻辑：PL 执行效率可能低于原 Oracle 包。

3. **迁移后性能工作**
   - 导出慢 SQL，对比两边 `EXPLAIN (ANALYZE)`。
   - 补齐索引（注意 openGauss/PG 索引类型：BTree/GIN/GiST 等）。
   - 更新统计信息；调整 work_mem、shared_buffers、max_connections 等。
   - 热点表分区、物化视图、SQL 改写（去相关子查询等）。

**【示例/写法】**
-- openGauss/PG 系查看计划
EXPLAIN (ANALYZE, BUFFERS) SELECT ...;

-- 更新统计
ANALYZE schema.table;

**【易错点】**
- 用单一 TPC 数字断言「Oracle 一定更快/更慢」。
- 未做执行计划对比就加机器。
- 照搬 Oracle Hint 或初始化参数名。

**【权威依据】**
- openGauss 性能调优指南（官方文档）
- Oracle Database Performance Tuning Guide
- PostgreSQL EXPLAIN 文档

<a id="Q003"></a>

### Q003（原始编号: 23）

**【题干】**
openGauss 数据库的性能相比 Oracle 数据库还是有些不同，你是怎么迁移和改造的？性能问题你是怎么解决的？

**【核心结论】**
迁移改造按「评估→结构/语法改造→数据迁移校验→SQL/对象性能回归→参数与架构调优」推进；性能问题用慢 SQL + 执行计划 + 索引/改写/统计信息/硬件与并行手段闭环。

**【详细说明】**
**迁移改造步骤**
1. 兼容性评估：对象清单（表、索引、视图、包、作业、同义词）、SQL 扫描、第三方依赖。
2. 结构改造：类型映射、约束、分区策略对齐；PL/SQL → PL/pgSQL/兼容 PL。
3. 数据迁移：全量（导出导入/CDC 工具）+ 增量；校验行数、抽样 checksum、关键业务对账。
4. 双跑/灰度：读流量切换、写切换窗口；回滚预案。

**性能问题解决**
- Top SQL：从业务耗时、锁等待、IO 入手。
- 计划劣化：补统计、改写、加合适索引、避免函数包列导致无法用索引。
- 批量：分批提交、COPY/装载工具、降低索引维护（先装后建索引）。
- 连接池与应用侧：减少闲置事务、控制并发、避免大事务。
- 必要时：读写分离、缓存热点、异步化非核心路径。

**【示例/写法】**
迁移校验伪代码思路：
1) COUNT(*) 分表对比
2) 关键业务键 HASH 聚合对比
3) 抽检金额/状态机一致性

**【易错点】**
- 只迁数据不迁「作业/定时任务/同义词」导致功能缺失被误判为性能问题。
- 大事务一次性切换无校验。

**【权威依据】**
- openGauss 迁移与兼容性文档
- Oracle Data Pump / GoldenGate 等迁移方法论（对照理解）

<a id="Q004"></a>

### Q004（原始编号: 36, 184）

**【题干】**
国产化项目迁移过程中，你遇到了哪些问题？

**【核心结论】**
典型问题覆盖：数据库语法与类型、中间件替换（应用服务器/消息/缓存）、加密与国密算法、驱动与连接池、操作系统与字体/打印、第三方商业组件无国产替代、性能回归与人员技能。

**【详细说明】**
可按层次回答（面试宜结合亲历）：
1. **数据库**：见 Q001/Q018；驱动 JAR、分页插件、MyBatis 方言。
2. **中间件**：WebLogic/WebSphere → 东方通 TongWeb、宝兰德等；MQ、注册中心国产化替换。
3. **安全**：TLS 套件、SM2/SM3/SM4 与原 RSA/AES 体系并存；证书链。
4. **应用**：JNI/本地库、依赖 Oracle 专有包、报表工具。
5. **工程**：环境不一致、自动化脚本、监控指标更换。
6. **组织**：并行双轨、验收标准、回退演练。

**【示例/写法】**
问题清单模板：问题 | 影响 | 方案 | 验证方式 | 负责人

**【易错点】**
- 只谈「换库」不谈中间件与国密。
- 无量化验收（功能+性能+安全）。

**【权威依据】**
- 信创相关产品官方迁移指南（openGauss、达梦、TongWeb 等）
- 各产品发行说明中的兼容性列表

<a id="Q005"></a>

### Q005（原始编号: 37, 52, 173）

**【题干】**
openGauss 数据库、Oracle 数据库、MySQL 数据库，哪个性能更高？

**【核心结论】**
没有绝对「谁更高」。取决于负载类型（OLTP/OLAP）、硬件、参数、SQL 与数据模型。Oracle 企业特性成熟；MySQL InnoDB 在互联网高并发短事务常见；openGauss 在国产场景与部分分析/向量化能力上有优势。应回答「场景化对比 + 压测方法」。

**【详细说明】**
对比维度：
- **引擎**：MySQL InnoDB vs Oracle vs openGauss（PG 系 + 增强）。
- **隔离与锁**：默认隔离级别不同（见事务题）。
- **复制与高可用**：半同步/组复制、Data Guard、主备流复制等。
- **优化器与统计信息**。
结论表述：同硬件同模型压测（sysbench/TPC-C 类）才有意义；生产以业务 SQL 为准。

**【示例/写法】**
压测：固定并发与数据集，对比 TPS、P99、CPU、IO、锁等待。

**【易错点】**
- 背诵「Oracle 最强」而无场景。
- 用不同硬件结果互比。

**【权威依据】**
- 各厂商性能白皮书（注意营销口径）
- MySQL InnoDB、Oracle、openGauss 官方架构文档

<a id="Q006"></a>

### Q006（原始编号: 41, 75, 109, 192, 234）

**【题干】**
数据从一个数据库（比如 Oracle 数据库）迁移到另一个数据库（比如 openGauss 数据库），如何保证数据一致性？

**【核心结论】**
一致性靠「全量校验 + 增量同步窗口控制 + 切换前对账 + 切换后回读校验」；工具层保证传输完整，业务层保证语义一致（类型、时区、字符集、空值）。

**【详细说明】**
1. **迁移前**：字符集/时区统一；主键与唯一约束完备；禁止无序大表无校验迁移。
2. **全量**：断点续传；迁完行数、聚合校验（SUM/COUNT/校验和）。
3. **增量**：CDC（日志挖掘/触发器/时间戳）追平；切换时短停写或只读窗口。
4. **切换**：双写或冻结写入 → 最终增量追平 → 应用切连接 → 抽样与关键账户对账。
5. **切换后**：影子流量对比；保留回滚库。
6. **语义一致**：NUMBER 精度、DATE→timestamp、空串/NULL、排序规则（collation）。

**【示例/写法】**
校验 SQL 示例：
SELECT COUNT(*), SUM(amount), MAX(updated_at) FROM orders;
两边结果对比；关键表按主键区间抽样 MD5。

**【易错点】**
- 只比行数不比金额/状态。
- 增量未追平时就切写。
- 忽略序列当前值导致主键冲突。

**【权威依据】**
- openGauss 数据迁移工具文档
- 数据库迁移一致性校验最佳实践（行业通用方法）

<a id="Q007"></a>

### Q007（原始编号: 55）

**【题干】**
openGauss 数据库和 MySQL 数据库的区别。

**【核心结论】**
二者定位与实现路径不同：MySQL 以 InnoDB 插件式存储引擎闻名，开源生态大；openGauss 源自 PostgreSQL，强调企业特性、安全与国产化，SQL/体系结构更接近 PG 而非 MySQL。

**【详细说明】**
主要区别：
1. **血统**：MySQL（Oracle 公司）vs openGauss（PG 系国产发行）。
2. **SQL 方言**：分页 `LIMIT` 都有，但类型系统、窗口函数历史、`UPSERT` 语法（`ON DUPLICATE KEY` vs `ON CONFLICT`）不同。
3. **存储**：InnoDB 聚簇主键；PG/openGauss 堆表 + 索引组织不同，更新产生新元组版本（MVCC/VACUUM）。
4. **复制**：MySQL binlog；openGauss/PG WAL 流复制。
5. **存储过程语言**：MySQL 过程语法 vs PL/pgSQL。
6. **管理**：参数名、权限模型、备份工具均不同。

**【示例/写法】**
MySQL: INSERT ... ON DUPLICATE KEY UPDATE ...
openGauss/PG: INSERT ... ON CONFLICT (pk) DO UPDATE SET ...

**【易错点】**
- 把 openGauss 当「国产 MySQL」。
- 假设隔离级别默认相同（MySQL 默认 RR，PG 默认 RC）。

**【权威依据】**
- MySQL 8.0 Reference Manual
- openGauss / PostgreSQL 官方文档

<a id="Q008"></a>

### Q008（原始编号: 56）

**【题干】**
国产中间件、国产 PostgreSQL 数据库，有哪些相关技术？

**【核心结论】**
国产 PostgreSQL 系常见：openGauss、人大金仓 KingbaseES、GaussDB 等；中间件含应用服务器、消息、缓存、注册配置、API 网关等信创名录产品。

**【详细说明】**
**数据库（PG 系及相关）**
- openGauss、GaussDB、KingbaseES、瀚高、神舟通用等（具体选型看信创目录与版本）。

**中间件类别与代表方向**
- 应用服务器：东方通 TongWeb、宝兰德、中创等。
- 消息队列：国产 MQ/Kafka 发行或兼容产品。
- 缓存：国产 Redis 兼容发行。
- 注册/配置：Nacos 等（视国产化要求）。
- 负载与 Web：国产 Nginx 发行、硬件负载。
回答时应说明「用过的具体产品 + 替换的原栈 + 兼容性验证」。

**【示例/写法】**
选型表：原组件 | 国产替代 | 协议兼容性 | 验证用例

**【易错点】**
- 只报产品名无替换经验。
- 混淆「基于 PG」与「兼容 Oracle」产品。

**【权威依据】**
- 各产品官方站点与信创名录说明
- openGauss 社区文档

<a id="Q009"></a>

### Q009（原始编号: 108）

**【题干】**
国产 openGauss 数据库和 Oracle 数据库的区别。

**【核心结论】**
openGauss 基于 PostgreSQL 演进并增强；Oracle 是独立商业内核。差异体现在许可与生态、SQL/PL、优化器与高可用、工具链与运维体系。

**【详细说明】**
1. 许可与支持模式不同。
2. SQL：Oracle 伪列、CONNECT BY、大量内置包；openGauss 走 SQL 标准 + PG 方言 + 兼容层。
3. 高可用：Data Guard/RAC vs 主备、一主多备、分布式能力（版本相关）。
4. 管理工具与监控生态不同。
5. 数据类型与空串语义差异见 Q001。

**【示例/写法】**
回答结构：架构血统 → SQL/PL → HA → 迁移成本。

**【易错点】**
- 把兼容模式当成 100% 等价。

**【权威依据】**
- openGauss 架构与兼容性文档
- Oracle Concepts Guide

<a id="Q010"></a>

### Q010（原始编号: 111）

**【题干】**
国产技术迁移过程中遇到哪些问题？或者说，项目开发中遇到过哪些技术难点和问题？

**【核心结论】**
与 Q004 同类：可从数据库、中间件、国密、驱动、性能、第三方组件、人员技能展开，并给出「问题—方案—结果」案例。

**【详细说明】**
建议 STAR 叙述：
- 难点：某 Oracle 包无法直接迁、慢 SQL、国密改造影响性能、连接池适配。
- 方案：改写、索引、硬件/参数、算法选型（SM4 vs AES 场景）。
- 结果：指标对比。
同时可提协作难点：厂商响应、环境不一致。

**【示例/写法】**
案例卡片：背景/目标/动作/量化结果

**【易错点】**
- 空泛说「兼容性问题」无细节。

**【权威依据】**
- 对应产品官方迁移 FAQ

<a id="Q011"></a>

### Q011（原始编号: 117）

**【题干】**
用过哪些国产数据库、国产技术栈？迁移过程中遇到哪些问题？

**【核心结论】**
如实列举用过的库与中间件；问题落到类型/SQL/驱动/性能/国密；强调验证方法。

**【详细说明】**
技术栈举例口径：
- DB：openGauss / 达梦 / Kingbase 等（按真实经历）。
- 中间件：TongWeb、国产 MQ/Redis。
- 前端/OS：统信、麒麟等（若相关）。
迁移问题复用 Q001/Q004，避免清单堆砌。

**【示例/写法】**
简历对齐：项目名 → 原栈 → 目标栈 → 你的职责。

**【易错点】**
- 夸大「全都用过」。

**【权威依据】**
- 产品官方文档与项目验收材料

<a id="Q012"></a>

### Q012（原始编号: 129, 134）

**【题干】**
Oracle 数据库和 MySQL 数据库，哪个与达梦数据库更接近？

**【核心结论】**
达梦（DM）在语法与使用习惯上对 Oracle 兼容投入更多，整体更接近 Oracle，而非 MySQL。仍需以达梦官方兼容说明为准做评估。

**【详细说明】**
- 达梦提供 Oracle 兼容模式、常见数据类型与 PL/SQL 风格迁移路径。
- 与 MySQL：方言、引擎概念、复制体系差异更大。
- 实践：用官方兼容性评估工具/手册扫描对象与 SQL。

**【示例/写法】**
评估：对象类型覆盖率、SQL 解析失败率、存储过程改写量。

**【易错点】**
- 断言 100% 兼容 Oracle。

**【权威依据】**
- 达梦数据库产品手册：SQL 兼容性、迁移指南

<a id="Q013"></a>

### Q013（原始编号: 154）

**【题干】**
信创迁移，你做了哪些工作？

**【核心结论】**
工作通常包括：摸底盘点、替代选型、兼容改造、数据迁移与校验、安全（国密）改造、性能回归、双轨切换与文档培训。

**【详细说明】**
可按阶段答：
1. 资产盘点（软硬件、依赖许可证）。
2. 替代方案与 POC。
3. 应用改造（SQL、驱动、中间件 API）。
4. 数据迁移与一致性。
5. 等保/密评相关改造。
6. 上线切换与运维移交。

**【示例/写法】**
交付物：兼容性报告、迁移方案、回滚预案、压测报告。

**【易错点】**
- 只谈换服务器不谈应用改造。

**【权威依据】**
- 信创迁移项目方法论（厂商+行业实践）

<a id="Q014"></a>

### Q014（原始编号: 168）

**【题干】**
国产中间件、国产 PostgreSQL 数据库，以及有哪些国产化技术？

**【核心结论】**
同 Q008，可补充 OS、CPU、浏览器、办公套件等完整信创栈，但面试重点仍是你负责的中间件与数据库。

**【详细说明】**
分类：基础硬件/OS → 数据库 → 中间件 → 应用框架。突出可验证使用经验。

**【示例/写法】**
栈图：浏览器→网关→应用服务器→服务→DB/缓存/MQ

**【易错点】**
- 报过大而全清单却答不出用法。

**【权威依据】**
- 各产品官方介绍与适配名单

<a id="Q015"></a>

### Q015（原始编号: 169, 219）

**【题干】**
openGauss 数据库和 MySQL 数据库、Oracle 数据库的区别。

**【核心结论】**
三者两两对比：血统与引擎、SQL 方言、MVCC/锁、生态与许可、国产化与兼容策略。合成 Q007+Q009。

**【详细说明】**
简表：
| 维度 | MySQL | Oracle | openGauss |
| 血统 | MySQL | 自研商业 | PG 系国产 |
| 默认隔离 | RR(InnoDB) | RE | RC(PG系常见) |
| 分页 | LIMIT | ROWNUM/FETCH | LIMIT/FETCH |
| 过程语言 | 自有 | PL/SQL | PL/pgSQL+兼容 |
细节按面试官追问展开。

**【示例/写法】**
用一张对比表作答最清晰。

**【易错点】**
- 默认隔离级别记错。

**【权威依据】**
- MySQL/Oracle/openGauss 官方 Concepts 与 SQL Reference

<a id="Q016"></a>

### Q016（原始编号: 172）

**【题干】**
达梦数据库、Oracle 数据库、MySQL 数据库，哪个性能更好？

**【核心结论】**
同 Q005：无绝对排序；达梦多对标 Oracle 兼容场景；以业务压测为准。

**【详细说明】**
说明达梦在 Oracle 迁移场景下的优化点与差异；MySQL 适合另一类互联网负载。给出压测方法。

**【示例/写法】**
同硬件 TPC-C/业务混合压测对比 TPS 与 P99。

**【易错点】**
- 背厂商排名。

**【权威依据】**
- 达梦/Oracle/MySQL 性能与架构文档

<a id="Q017"></a>

### Q017（原始编号: 217）

**【题干】**
国产中间件。

**【核心结论】**
指在操作系统之上、应用之下的国产基础软件：应用服务器、消息、缓存、ESB/API 网关、TP 中间件等。回答应点名类别+代表产品+使用场景。

**【详细说明】**
常见类别：
- JavaEE 应用服务器（TongWeb 等）
- 消息中间件
- 分布式事务/工作流
- 数据访问与缓存
结合项目说明替换了哪家商业产品。

**【示例/写法】**
「用过 X 替代 WebLogic，做了 Y 验证」。

**【易错点】**
- 把数据库也笼统叫中间件而不区分。

**【权威依据】**
- 工信部/信创相关产品名录与厂商文档

<a id="Q018"></a>

### Q018（原始编号: 218）

**【题干】**
openGauss 数据库和 Oracle 数据库的函数有哪些差异？数据类型有哪些差异？具体哪些数据类型有差异？

**【核心结论】**
函数：日期、字符串、数值、空值处理、分析函数与专有包函数大量差异；类型：NUMBER/DATE/VARCHAR2/CLOB/RAW 等映射最关键。必须对照官方函数与类型对照表。

**【详细说明】**
**类型（具体）**
- NUMBER → numeric/decimal 或整型；精度要显式。
- VARCHAR2 → varchar；CHAR 定长空格填充行为核对。
- DATE（含时间）→ timestamp；纯日期才用 date。
- TIMESTAMP WITH TIME ZONE 等时区类型注意会话时区。
- CLOB/BLOB → text/clob、bytea/blob。
- BOOLEAN：Oracle 无真正布尔类型（SQL 层），openGauss/PG 有。

**函数**
- SYSDATE/SYSTIMESTAMP → CURRENT_TIMESTAMP/now()（兼容名可能有）。
- NVL → COALESCE/IFNULL 类；NVL2 需改写。
- DECODE → CASE。
- INSTR/SUBSTR 参数与返回对空串差异需测。
- TO_DATE/TO_CHAR 格式模型大体类似但细节不同。
- LISTAGG vs string_agg。
- 序列 nextval 写法：Oracle `seq.NEXTVAL` vs `nextval('seq')`（兼容模式或有点号写法）。

**【示例/写法】**
SELECT COALESCE(col, 0) ...  -- 替代 NVL
SELECT CASE WHEN ... END     -- 替代 DECODE

**【易错点】**
- 假设 TO_DATE 格式串 100% 相同。
- 忽略布尔与空串。

**【权威依据】**
- openGauss《Oracle 兼容性》函数/数据类型章节
- Oracle SQL Language Reference：Data Types / Functions

