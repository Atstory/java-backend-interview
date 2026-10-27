# Java/后端面试题详答（去重唯一题）

## 说明

本目录针对 `/workspace/interview-questions-dedup/` 去重结果，为 **151** 道唯一题撰写逐题详细答案，并附能力总结与权威引用。

- 输入题库：`01-deduped-by-category.md`、`02-number-to-canonical.md`、`_data.json`（groups=151）
- 原始题目 239 道 → 去重唯一 151 道

## 答题原则

1. **准确优先**：不确定处写清边界与版本依赖，不编造 API/语法/论文名。
2. **结构统一**：每题含【题干】【核心结论】【详细说明】【示例/写法】【易错点】【权威依据】。
3. **中文撰写**：技术专名保留英文缩写（JVM、CAS、AOF 等）。
4. **官方口径**：openGauss/Oracle 差异、S3 加密、XSS/SQLi、事务传播、JVM GC、缓存击穿等对齐官方文档。
5. **安全分层**：XSS→输出编码/CSP/模板转义；SQLi→PreparedStatement/`#{}` 参数化（DAO 层）。
6. **加密检索**：手机号后四位用盲索引/HMAC 或 ES keyword，禁止建议解密全表扫。
7. **纠错**：原文「RES」按 AES 语境纠正并注明；堆/栈 LIFO 按正确 CS 定义回答并轻点原文笔误。

## 文件清单（绝对路径）

- `/workspace/interview-questions-answers/00-index.md`
- `/workspace/interview-questions-answers/README.md`
- `/workspace/interview-questions-answers/SUMMARY-能力考察与培养.md`
- `/workspace/interview-questions-answers/answers-01-国产化与数据库迁移.md`
- `/workspace/interview-questions-answers/answers-02-数据库·SQL·索引·事务.md`
- `/workspace/interview-questions-answers/answers-03-Redis与缓存.md`
- `/workspace/interview-questions-answers/answers-04-消息队列.md`
- `/workspace/interview-questions-answers/answers-05-JVM与内存.md`
- `/workspace/interview-questions-answers/answers-06-并发·锁·线程池.md`
- `/workspace/interview-questions-answers/answers-07-Spring·AOP·IoC.md`
- `/workspace/interview-questions-answers/answers-08-微服务与治理.md`
- `/workspace/interview-questions-answers/answers-09-集合与Java基础.md`
- `/workspace/interview-questions-answers/answers-10-安全与加密.md`
- `/workspace/interview-questions-answers/answers-11-对象存储.md`
- `/workspace/interview-questions-answers/answers-12-搜索·Elasticsearch.md`
- `/workspace/interview-questions-answers/answers-13-支付·幂等·一致性业务.md`
- `/workspace/interview-questions-answers/answers-14-性能与排查.md`
- `/workspace/interview-questions-answers/answers-15-设计模式与工作流.md`
- `/workspace/interview-questions-answers/answers-16-工程与团队.md`
- `/workspace/interview-questions-answers/references.md`

## 分类答卷

| 文件 | 分类 | 题数 |
|---|---|---:|
| `answers-01-国产化与数据库迁移.md` | 国产化与数据库迁移 | 18 |
| `answers-02-数据库·SQL·索引·事务.md` | 数据库·SQL·索引·事务 | 25 |
| `answers-03-Redis与缓存.md` | Redis与缓存 | 13 |
| `answers-04-消息队列.md` | 消息队列 | 5 |
| `answers-05-JVM与内存.md` | JVM与内存 | 13 |
| `answers-06-并发·锁·线程池.md` | 并发·锁·线程池 | 22 |
| `answers-07-Spring·AOP·IoC.md` | Spring·AOP·IoC | 9 |
| `answers-08-微服务与治理.md` | 微服务与治理 | 7 |
| `answers-09-集合与Java基础.md` | 集合与Java基础 | 8 |
| `answers-10-安全与加密.md` | 安全与加密 | 6 |
| `answers-11-对象存储.md` | 对象存储 | 3 |
| `answers-12-搜索·Elasticsearch.md` | 搜索·Elasticsearch | 2 |
| `answers-13-支付·幂等·一致性业务.md` | 支付·幂等·一致性业务 | 3 |
| `answers-14-性能与排查.md` | 性能与排查 | 4 |
| `answers-15-设计模式与工作流.md` | 设计模式与工作流 | 2 |
| `answers-16-工程与团队.md` | 工程与团队 | 11 |

## 导航

- 总目录与锚点：[`00-index.md`](./00-index.md)
- 能力考察与培养：[`SUMMARY-能力考察与培养.md`](./SUMMARY-能力考察与培养.md)
- 权威引用：[`references.md`](./references.md)

## 覆盖统计

- 唯一题详答数：**151**
- 期望（_data.json）：**151**
- 状态：**OK 全覆盖**
