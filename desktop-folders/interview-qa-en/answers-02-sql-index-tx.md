# 数据库·SQL·索引·事务（25 题详答）

规范 ID 范围见各题标题；原始编号已标注。

<a id="Q019"></a>

### Q019（原始编号: 1）

**【题干】**
大批量数据入库，你怎么处理，语句怎么写，如果用动态结构化查询语言的遍历循环解决了，但是入库的时候发现有重复数据或者修改的时候，在插入语句中怎么去重，或者发现重复数据了，怎么正确地修改，不会冲突或者避免重复。

**【核心结论】**
批量入库用批处理/COPY/LOAD，避免逐行提交；去重与「插入或更新」用唯一约束 + `INSERT ... ON CONFLICT`/`MERGE`/`INSERT IGNORE`/`REPLACE` 等方言特性，或先 staging 再合并；不要靠应用循环碰运气。

**【详细说明】**
1. **批量写入**
   - JDBC batch / MyBatis foreach 控批次（如 500–2000）。
   - PostgreSQL/openGauss：`COPY`；MySQL：`LOAD DATA`；Oracle：SQL*Loader/FORALL。
   - 适当临时禁用非必要二级索引，装完再建。

2. **去重与 upsert**
   - 表上建好唯一索引（业务键）。
   - PG/openGauss：`INSERT ... ON CONFLICT (uk) DO UPDATE SET ...`
   - MySQL：`ON DUPLICATE KEY UPDATE` 或 `INSERT IGNORE`
   - Oracle：`MERGE INTO ...`
   - 或：入 staging 表 → `DISTINCT`/窗口函数去重 → 合并入正式表。

3. **并发冲突**
   - 唯一约束防重；捕获重复键错误重试或转更新。
   - 大事务拆小，避免长锁。

**【示例/写法】**
-- PostgreSQL/openGauss
INSERT INTO t(id, name, ver) VALUES (?, ?, ?)
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, ver = EXCLUDED.ver
WHERE t.ver < EXCLUDED.ver;

-- MySQL
INSERT INTO t(id,name) VALUES (?,?)
ON DUPLICATE KEY UPDATE name=VALUES(name);

**【易错点】**
- 循环单条 commit。
- 无唯一约束只靠 SELECT 再 INSERT（竞态）。
- 超大 foreach 导致 SQL 包过大。

**【权威依据】**
- PostgreSQL INSERT ON CONFLICT
- MySQL INSERT ... ON DUPLICATE KEY UPDATE
- Oracle MERGE 语句文档

<a id="Q020"></a>

### Q020（原始编号: 9, 124, 235）

**【题干】**
索引失效、事务失效的方式。

**【核心结论】**
索引「失效」多指优化器未选用索引；事务「失效」多指 @Transactional 未生效或传播/异常导致未回滚。两者原因列表要分开记。

**【详细说明】**
**索引未走（常见）**
- 对索引列使用函数/运算、隐式类型转换。
- 模糊查询前导 `%`；`OR` 条件不善；`!=`/`NOT IN` 等。
- 联合索引不满足最左前缀。
- 选择性差、统计信息过期，优化器选全表。
- `LIKE` 范围过大；索引列 IS NULL 视情况。

**事务注解失效（Spring）**
- 非 public 方法；同类自调用绕过代理。
- 异常被吞或非 RuntimeException 且未指定 rollbackFor。
- 传播级别 `NOT_SUPPORTED`/`NEVER` 等。
- 未纳入 Spring 管理；数据源/事务管理器未配置。
- 多线程中子线程无事务上下文。

**【示例/写法】**
见 Q022、Q025 示例。

**【易错点】**
- 把「没建索引」和「索引失效」混为一谈。
- 以为 checked exception 默认回滚。

**【权威依据】**
- MySQL Optimizer / InnoDB 文档
- Spring Framework Transaction Management

<a id="Q021"></a>

### Q021（原始编号: 11）

**【题干】**
事务之间的相互调用。

**【核心结论】**
本质是 Spring 事务传播行为（Propagation）：谁加入谁、谁挂起谁、是否新建事务。同类自调用不走代理则传播不生效。

**【详细说明】**
常用传播：
- REQUIRED（默认）：有则加入，无则新建。
- REQUIRES_NEW：始终新事务，外层挂起。
- NESTED：嵌套（保存点，视管理器支持）。
- SUPPORTS / MANDATORY / NOT_SUPPORTED / NEVER。
相互调用场景：服务 A 调 B，要明确失败是否回滚外层。

**【示例/写法】**
@Transactional(propagation = Propagation.REQUIRES_NEW)
public void auditLog() { ... }

**【易错点】**
- 自调用导致传播「看起来配了却没用」。

**【权威依据】**
- Spring Transaction Propagation 文档
- Java EE 事务传播概念

<a id="Q022"></a>

### Q022（原始编号: 31, 189）

**【题干】**
索引失效的方式。

**【核心结论】**
更准确说是「索引未被使用」。罗列条件与联合索引最左前缀，并用 EXPLAIN 验证。

**【详细说明】**
详见 Q020 索引部分。补充：
- 范围条件后的列可能无法有效用到联合索引后续列（MySQL 对范围后列利用有限）。
- 覆盖索引可避免回表但前提是列在索引中。
- 强制索引仅作诊断，生产慎用。

**【示例/写法】**
EXPLAIN SELECT ... WHERE phone = '...'
看 type/key/rows/Extra。

**【易错点】**
- 只背口诀不看执行计划。

**【权威依据】**
- MySQL EXPLAIN Output Format
- 《高性能 MySQL》索引章节

<a id="Q023"></a>

### Q023（原始编号: 38, 233）

**【题干】**
事务隔离级别的作用。

**【核心结论】**
隔离级别定义并发事务之间可见性与异常现象（脏读、不可重复读、幻读）的允许程度，在一致性与性能间权衡。

**【详细说明】**
四级（SQL 标准）：
1. READ UNCOMMITTED：可读未提交（脏读）。
2. READ COMMITTED：仅读已提交；不可重复读可能发生。
3. REPEATABLE READ：同一事务重复读一致；幻读处理因实现而异（InnoDB 用 MVCC+间隙锁抑制）。
4. SERIALIZABLE：串行化，最强隔离。
作用：防止指定异常；级别越高通常并发度越低或开销越大。

**【示例/写法】**
-- MySQL
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

**【易错点】**
- 以为 RR 在所有数据库都完全无幻读。

**【权威依据】**
- SQL 标准隔离级别
- MySQL innodb-transaction-isolation
- PostgreSQL Transaction Isolation

<a id="Q024"></a>

### Q024（原始编号: 67）

**【题干】**
自动注入（@Autowired）、事务注解（@Transactional）和面向切面编程之间有什么关系？

**【核心结论】**
@Autowired 是 IoC 依赖注入；@Transactional 通过 AOP 代理织入事务边界；二者都建立在 Spring 容器与代理机制上，但职责不同。

**【详细说明】**
- IoC：容器创建 Bean 并注入依赖（@Autowired/@Inject）。
- AOP：为 Bean 创建代理，在调用前后增强。
- @Transactional：TransactionInterceptor 等切面，在方法前 getTransaction、后 commit/rollback。
因此：没有 Spring 代理（自调用、final、非容器对象）时事务切面不生效；注入的是代理对象才能带事务。

**【示例/写法】**
注入接口类型，确保拿到代理：
@Autowired private OrderService orderService;

**【易错点】**
- 认为 @Autowired 本身开启事务。

**【权威依据】**
- Spring AOP / Transaction Management Reference

<a id="Q025"></a>

### Q025（原始编号: 68, 166, 210）

**【题干】**
一个类有两个方法，A 方法有事务，B 方法没有事务，相互调用会有什么情况？

**【核心结论】**
关键看是否经过 Spring 代理：this.B()/this.A() 自调用时，事务注解对「被调用方」不生效；通过注入的代理调用则按传播规则生效。

**【详细说明】**
情形：
1. A（有事务）自调用 B（无注解）：B 在 A 的事务里执行（同一线程连接），异常按 A 的事务回滚。
2. B（无注解）自调用 A（有注解）：A 的事务不开启（自调用）。
3. 其它 Bean 调 A：事务正常。
4. A 调「代理.A/B」：可用 AopContext 或拆 Bean 解决。
B 无注解不是「没事务」，而是不创建事务边界；落在调用方事务中则随调用方。

**【示例/写法】**
// 拆到两个 Bean，或
((OrderService) AopContext.currentProxy()).a();

**【易错点】**
- 以为同类调用注解一定生效。

**【权威依据】**
- Spring 文档：Self-invocation / proxy mode

<a id="Q026"></a>

### Q026（原始编号: 69, 209）

**【题干】**
事务的原理和作用、事务传播机制。

**【核心结论】**
作用：原子性、一致性、隔离性、持久性（ACID）。Spring 原理：AOP 代理 + PlatformTransactionManager 绑定连接/会话。传播机制决定多方法嵌套时的事务边界。

**【详细说明】**
原理要点：
- ThreadLocal 绑定事务状态与连接。
- 统一提交/回滚；异常策略可配。
传播：REQUIRED、REQUIRES_NEW、NESTED 等（见 Q021）。
数据库侧：undo/redo 或 WAL、锁与 MVCC 支撑隔离。

**【示例/写法】**
@Transactional(rollbackFor = Exception.class, propagation = Propagation.REQUIRED)

**【易错点】**
- 只背 ACID 不谈传播与代理。

**【权威依据】**
- Spring Transaction Management
- 数据库事务章节（MySQL/Oracle）

<a id="Q027"></a>

### Q027（原始编号: 74, 165, 204）

**【题干】**
事务的原理及传播机制。

**【核心结论】**
与 Q026 同质，可更偏实现：TransactionInterceptor、同步器、传播枚举行为表。

**【详细说明】**
展开传播行为表：每种传播在「存在/不存在事务」时的动作；REQUIRES_NEW 与独立数据源连接；NESTED 依赖 JDBC 保存点。

**【示例/写法】**
列行为表作答。

**【易错点】**
- 混淆 REQUIRES_NEW 与 NESTED。

**【权威依据】**
- Spring Propagation 枚举 Javadoc 与参考文档

<a id="Q028"></a>

### Q028（原始编号: 76）

**【题干】**
B+ 树、聚簇索引、联合索引。

**【核心结论】**
InnoDB 用 B+ 树组织索引；聚簇索引叶子存整行（通常主键）；联合索引是多列组成的 B+ 树键，遵循最左前缀。

**【详细说明】**
- B+ 树：多路平衡树，叶子链表有序，适合范围查询；非叶子存键与指针。
- 聚簇：数据与主键索引一体；二级索引叶子存主键。
- 联合索引 (a,b,c)：可用 a、(a,b)、(a,b,c) 等最左前缀条件。
- 覆盖索引：查询列均在索引中可避免回表。

**【示例/写法】**
KEY idx_abc (a,b,c)
WHERE a=? AND b=?  -- 可用

**【易错点】**
- 混淆哈希索引与 B+。
- 忽略回表成本。

**【权威依据】**
- MySQL InnoDB 索引文档
- 《高性能 MySQL》

<a id="Q029"></a>

### Q029（原始编号: 81, 203）

**【题干】**
事务隔离级别及其可能出现的问题，怎么解决幻读？

**【核心结论】**
四级隔离对应脏读/不可重复读/幻读；InnoDB RR 下通过 MVCC + Next-Key Lock（记录锁+间隙锁）抑制幻读；应用也可升至 SERIALIZABLE 或业务幂等设计。

**【详细说明】**
异常现象定义后，说明 InnoDB：
- 快照读（普通 SELECT）靠 ReadView。
- 当前读（SELECT FOR UPDATE / UPDATE）加 Next-Key Lock，锁住间隙防插入幻行。
PG 默认 RC，幻读处理不同。解决要声明引擎。

**【示例/写法】**
SELECT * FROM t WHERE id BETWEEN 1 AND 10 FOR UPDATE;

**【易错点】**
- 绝对说「RR 一定无幻读」跨引擎。

**【权威依据】**
- MySQL InnoDB Locking / Consistent Read
- SQL 标准

<a id="Q030"></a>

### Q030（原始编号: 94, 103）

**【题干】**
实际项目当中，Redis 持久化使用的是数据库快照（Redis Database，RDB）还是仅追加文件（Append Only File，AOF）？

**【核心结论】**
可按项目如实答；常见生产是 AOF（或 AOF+RDB 混合）优先耐久，RDB 利于备份与重启加速。Redis 4+ 支持 RDB-AOF 混合持久化。

**【详细说明】**
- RDB：定时快照，体积小、恢复快，窗口内数据可能丢。
- AOF：写命令追加，`everysec` 折中；重写控制体积。
- 混合：AOF 文件中带 RDB 前缀。
默认配置历史上偏 RDB 快照策略；是否开启 AOF 看 redis.conf `appendonly`。面试应说明自己环境选择理由。

**【示例/写法】**
appendonly yes
appendfsync everysec
aof-use-rdb-preamble yes

**【易错点】**
- 把「默认」说成唯一生产选择。
- 题目写在「数据库」类但内容是 Redis，按 Redis 官方答。

**【权威依据】**
- Redis Persistence 官方文档

<a id="Q031"></a>

### Q031（原始编号: 115）

**【题干】**
慢结构化查询语言（慢 SQL）怎么优化？

**【核心结论】**
先 EXPLAIN/慢日志定位，再从索引、SQL 改写、表结构、缓存、架构分层治理。

**【详细说明】**
步骤：
1. 打开慢查询日志，取 Top。
2. EXPLAIN 看类型、索引、行数、Extra。
3. 加/改索引；避免 select *；拆大 SQL；分页优化。
4. 冗余/冷热分离；读写分离；ES 等。
5. 应用：N+1、缺批量、缺缓存。

**【示例/写法】**
慢日志阈值：long_query_time；结合 pt-query-digest。

**【易错点】**
- 不看计划盲目加索引。

**【权威依据】**
- MySQL Slow Query Log / EXPLAIN

<a id="Q032"></a>

### Q032（原始编号: 122）

**【题干】**
大批量数据怎么导入、导出？采用分批处理、同步处理还是异步处理？

**【核心结论】**
导入导出优先专用装载工具 + 分批；在线业务用异步任务队列，避免同步接口长时间占连接。

**【详细说明】**
- 导入：COPY/LOAD DATA/SQL*Loader；应用侧分批 batch。
- 导出：游标/流式写文件，避免一次加载内存。
- 同步：小数据量、管理后台可控场景。
- 异步：大数据量、可追踪任务进度、失败重试。
- 一致性：导入用 staging + 校验后切换。

**【示例/写法】**
接口提交任务 → MQ/Worker → 写对象存储 → 通知下载。

**【易错点】**
- 同步接口导千万行。

**【权威依据】**
- 各数据库 bulk load 文档

<a id="Q033"></a>

### Q033（原始编号: 123）

**【题干】**
数据库怎么发现慢结构化查询语言（慢 SQL），以及怎么优化？

**【核心结论】**
发现：慢查询日志、performance_schema、监控 APM、`SHOW PROCESSLIST`。优化同 Q031。

**【详细说明】**
发现渠道与阈值配置；优化闭环与回归。

**【示例/写法】**
开启 slow_query_log；对接 Prometheus/导出器。

**【易错点】**
- 只优化一次不建监控。

**【权威依据】**
- MySQL sys schema / slow log 文档

<a id="Q034"></a>

### Q034（原始编号: 127）

**【题干】**
MyBatis-Plus。

**【核心结论】**
MyBatis-Plus 是 MyBatis 增强工具，简化 CRUD、条件构造、分页插件等；不替代理解 SQL 与索引。

**【详细说明】**
能力：BaseMapper、Wrapper 条件、自动填充、乐观锁插件、逻辑删除、代码生成。注意：复杂报表仍手写 SQL/XML；避免 Wrapper 拼接导致难维护。

**【示例/写法】**
LambdaQueryWrapper<User> q = new LambdaQueryWrapper<>();
q.eq(User::getStatus, 1).page(...);

**【易错点】**
- 全部用 MP 忽略执行计划。

**【权威依据】**
- MyBatis-Plus 官方文档

<a id="Q035"></a>

### Q035（原始编号: 128）

**【题干】**
你用过哪些数据库？

**【核心结论】**
按真实经历列举：如 MySQL、Oracle、openGauss/PostgreSQL、Redis（若算）、达梦等；各补一句场景与特点。

**【详细说明】**
结构化回答：名称 → 版本量级 → 场景（OLTP/报表）→ 你做的调优/迁移。

**【示例/写法】**
「MySQL 8 主从；Oracle 11g/19c 核心交易；openGauss 信创迁移」。

**【易错点】**
- 罗列从未用过的产品。

**【权威依据】**
- 各库官方文档（佐证特性描述）

<a id="Q036"></a>

### Q036（原始编号: 136）

**【题干】**
默认的事务隔离级别。

**【核心结论】**
视数据库：MySQL InnoDB 默认 REPEATABLE READ；PostgreSQL/openGauss 默认 READ COMMITTED；Oracle 默认 READ COMMITTED。Spring 未指定时跟随连接池/数据库默认。

**【详细说明】**
强调「默认」必须带产品名；可用 `SELECT @@transaction_isolation`（MySQL 8）或 `SHOW transaction_isolation` 验证。

**【示例/写法】**
MySQL: SELECT @@transaction_isolation;
PG: SHOW transaction_isolation;

**【易错点】**
- 背成所有库都是 RR。

**【权威依据】**
- MySQL / PostgreSQL / Oracle 隔离级别官方说明

<a id="Q037"></a>

### Q037（原始编号: 137）

**【题干】**
大批量数据处理的方式。

**【核心结论】**
分批、并行可控、异步化、专用装载、限流与可恢复；避免长事务与巨大 SQL。

**【详细说明】**
模式：分页/主键游标扫描；bulk insert；MapReduce/Spark 离线；MQ 削峰；分段任务幂等。

**【示例/写法】**
按 id 范围：WHERE id > ? ORDER BY id LIMIT 1000

**【易错点】**
- 一次加载全部到内存。

**【权威依据】**
- 数据库 bulk 与批处理最佳实践

<a id="Q038"></a>

### Q038（原始编号: 141）

**【题干】**
Oracle 数据库讲一下。

**【核心结论】**
从架构（实例+数据库、SGA/PGA）、进程、表空间、UNDO/REDO、优化器、高可用（Data Guard）与 SQL 特点概述，结合使用经验。

**【详细说明】**
要点：逻辑结构表空间/段/区/块；MVCC 靠 undo；执行计划与统计信息；序列、同义词、包。面试抓 3–5 个深点即可。

**【示例/写法】**
说明自己用过的版本与场景。

**【易错点】**
- 只背名词无关联。

**【权威依据】**
- Oracle Database Concepts

<a id="Q039"></a>

### Q039（原始编号: 145）

**【题干】**
事务各个隔离级别及其可能出现的问题。

**【核心结论】**
同 Q023/Q029：四级与脏读、不可重复读、幻读对应表。

**【详细说明】**
画表：级别 → 脏读 → 不可重复读 → 幻读。并注明引擎实现差异。

**【示例/写法】**
口表作答 + InnoDB 补充。

**【易错点】**
- 混淆不可重复读与幻读（后者是行集合变多/变少）。

**【权威依据】**
- SQL 标准；MySQL InnoDB 文档

<a id="Q040"></a>

### Q040（原始编号: 149）

**【题干】**
结构化查询语言（Structured Query Language，SQL）优化方式，主要优化什么？

**【核心结论】**
主要优化：降低扫描与回表成本、稳定执行计划、减少锁与临时对象、合理索引与统计信息；目标是延迟与吞吐，而非「SQL 更短」。

**【详细说明】**
维度：索引、写法、结构、架构、参数。度量：扫描行数、缓冲命中、锁等待、P99。

**【示例/写法】**
优化前后 EXPLAIN 与耗时对比。

**【易错点】**
- 过度索引损害写性能。

**【权威依据】**
- 高性能 MySQL；优化器文档

<a id="Q041"></a>

### Q041（原始编号: 160）

**【题干】**
Redis 扣减成功，但是没有写入数据库，怎么处理？

**【核心结论】**
典型缓存与 DB 不一致：用事务消息/出箱、补偿对账、或先 DB 后删缓存等策略；扣减库存类应用「DB 为准 + 异步重建缓存」或 Lua+消息可靠投递。

**【详细说明】**
方案：
1. 以 DB 为权威：先扣 DB 成功再改 Redis；失败不改缓存。
2. 若必须先 Redis：写入 Outbox/MQ，消费者落库；失败重试；定时对账修复。
3. 幂等：扣减单号防重。
4. 告警与人工/自动补偿。

**【示例/写法】**
伪流程：Lua 扣减 → 发「库存变更」消息 → 消费者 UPDATE DB（幂等键）

**【易错点】**
- 只靠定时全量刷库无幂等。

**【权威依据】**
- Redis 事务/Lua；可靠消息最终一致性论述

<a id="Q042"></a>

### Q042（原始编号: 162）

**【题干】**
多版本并发控制（Multi-Version Concurrency Control，MVCC）解决什么问题？死锁。

**【核心结论】**
MVCC 主要解决读写并发冲突，让读不阻塞写、写不阻塞读（在快照隔离语义下），降低锁争用；它不消除死锁——写写仍可能锁等待/死锁。

**【详细说明】**
- InnoDB：隐藏列 + undo 版本链 + ReadView。
- 死锁：并发事务互相持锁等待；用 capturer 回滚、索引降锁范围、固定加锁顺序、缩短事务。
题目把「死锁」并列，应澄清 MVCC 不是死锁解决方案，而是减少锁的手段之一。

**【示例/写法】**
SHOW ENGINE INNODB STATUS\G 查看死锁日志。

**【易错点】**
- 声称 MVCC「解决死锁」。

**【权威依据】**
- MySQL InnoDB Multi-Versioning
- 死锁检测文档

<a id="Q043"></a>

### Q043（原始编号: 163）

**【题干】**
SELECT … FOR UPDATE 使用了哪些锁？

**【核心结论】**
在 InnoDB 中为当前读：对扫描到的索引记录加排他锁（X）；在 RR 下对范围条件常加 Next-Key Lock（记录锁+间隙锁），防止幻读；具体锁种类依赖隔离级别与索引是否命中。

**【详细说明】**
- 唯一索引等值：记录锁（+必要间隙视情况）。
- 范围/非唯一：Next-Key / 间隙锁。
- 无索引：可能升级为更大范围锁（应避免）。
- 锁在事务提交/回滚释放。

**【示例/写法】**
BEGIN;
SELECT * FROM t WHERE id=1 FOR UPDATE;
-- 其它事务更新 id=1 阻塞

**【易错点】**
- 以为 FOR UPDATE 在所有隔离级别锁法相同。

**【权威依据】**
- MySQL InnoDB Locking Reads

