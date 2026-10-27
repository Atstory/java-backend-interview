# 权威依据与参考文献（references）

说明：下列条目均可核验；面试作答时优先引用官方文档与标准教材。**禁止编造论文名**。部分经典论文给出通行题名与可查出处。

## Java / JVM

1. *The Java Virtual Machine Specification*（Java SE），Runtime Data Areas、类加载与链接。  
   https://docs.oracle.com/javase/specs/jvms/se17/html/index.html
2. Oracle/HotSpot *Garbage Collection Tuning Guide*（G1 默认变更、各收集器）。  
   https://docs.oracle.com/en/java/javase/17/gctuning/
3. JDK 8 GC Ergonomics / 命令行与默认收集器说明（核对 Parallel 等默认行为）。  
   https://docs.oracle.com/javase/8/docs/technotes/guides/vm/gctuning/
4. `java.util.concurrent` 包 API（`ThreadPoolExecutor`、`AQS`、`ConcurrentHashMap`、`CountDownLatch` 等）。  
   https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/util/concurrent/package-summary.html
5. Joshua Bloch, *Effective Java*（3rd Edition）——条目：Builder、equals/hashCode、Executor、单例等。
6. Brian Goetz et al., *Java Concurrency in Practice*（JCIP）——可见性、CAS、线程池、AQS 思想。
7. JLS（*Java Language Specification*）——`volatile` / `synchronized` 语义。  
   https://docs.oracle.com/javase/specs/jls/se17/html/index.html

## Spring / Spring Boot / Spring Cloud

8. Spring Framework Reference：Core (IoC)、AOP、Transaction Management（传播行为、代理与自调用）。  
   https://docs.spring.io/spring-framework/reference/
9. Spring Boot Reference：`@SpringBootApplication`、自动配置。  
   https://docs.spring.io/spring-boot/docs/current/reference/html/
10. Spring Cloud OpenFeign / LoadBalancer。  
    https://docs.spring.io/spring-cloud-openfeign/docs/current/reference/html/  
    https://docs.spring.io/spring-cloud-commons/docs/current/reference/html/#spring-cloud-loadbalancer

## 数据库：MySQL / Oracle / PostgreSQL / openGauss / 达梦

11. MySQL 8.0 Reference Manual：InnoDB 事务隔离、锁、MVCC、EXPLAIN、慢查询。  
    https://dev.mysql.com/doc/refman/8.0/en/
12. Oracle Database Concepts / SQL Language Reference（数据类型、伪列、PL/SQL 概念）。  
    https://docs.oracle.com/en/database/oracle/oracle-database/
13. PostgreSQL 官方文档：Transaction Isolation、`WITH RECURSIVE`、`INSERT ON CONFLICT`、NULL 语义。  
    https://www.postgresql.org/docs/current/
14. openGauss 官方文档：兼容性、数据类型、SQL 参考、迁移与调优。  
    https://docs.opengauss.org/
15. 达梦数据库产品手册：Oracle 兼容与迁移说明（以厂商当前文档为准）。  
    https://eco.dameng.com/document/

## Redis / 缓存

16. Redis 官方文档：Persistence（RDB/AOF/混合）、Replication、`SET` NX EX、分布式锁讨论。  
    https://redis.io/docs/  
    https://redis.io/docs/management/persistence/  
    Redis Blog: *Correct implementation of distributed locks*（Antirez）—— https://redis.io/docs/manual/patterns/distributed-locks/ （或以 redis.io 当前 distributed locks 页面为准）
17. Microsoft Azure Architecture Center：Cache-Aside pattern。  
    https://learn.microsoft.com/en-us/azure/architecture/patterns/cache-aside

## 消息队列

18. Apache Kafka 文档：投递语义、幂等生产者。  
    https://kafka.apache.org/documentation/
19. Apache RocketMQ 文档：事务消息。  
    https://rocketmq.apache.org/docs/
20. Gregor Hohpe & Bobby Woolf, *Enterprise Integration Patterns*（消息、可靠投递思想）。

## 安全（XSS / SQLi / 加密 / S3）

21. OWASP *XSS Prevention Cheat Sheet*。  
    https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html
22. OWASP *SQL Injection Prevention Cheat Sheet*。  
    https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html
23. OWASP *Cryptographic Storage Cheat Sheet* / *Password Storage Cheat Sheet*。  
    https://cheatsheetseries.owasp.org/
24. MDN：Content-Security-Policy。  
    https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP
25. NIST FIPS 197：*Advanced Encryption Standard (AES)*。  
    https://csrc.nist.gov/publications/detail/fips/197/final
26. RFC 2104：HMAC。  
    https://www.rfc-editor.org/rfc/rfc2104
27. AWS S3：Protecting data with encryption（SSE-S3 / SSE-KMS / SSE-C）。  
    https://docs.aws.amazon.com/AmazonS3/latest/userguide/serv-side-encryption.html
28. AWS KMS Developer Guide。  
    https://docs.aws.amazon.com/kms/latest/developerguide/
29. JDBC `PreparedStatement`（参数化防注入）。  
    https://docs.oracle.com/javase/tutorial/jdbc/basics/prepared.html

## Elasticsearch / 对象存储

30. Elasticsearch Guide：Field data types（`keyword`）、Term query。  
    https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html
31. 华为云 OBS 产品文档（或项目所用云厂商对象存储文档）。  
    https://support.huaweicloud.com/obs/

## 微服务治理 / 网关

32. Nacos 官方文档：服务发现、配置管理、Open API。  
    https://nacos.io/docs/latest/
33. Sentinel / Resilience4j 文档（熔断、隔离）。  
    https://sentinelguard.io/  
    https://resilience4j.readme.io/
34. Nginx 文档：`ngx_http_proxy_module`。  
    https://nginx.org/en/docs/http/ngx_http_proxy_module.html

## 分布式一致性（CAP / BASE）等经典出处

35. Eric Brewer，PODC 2000 Keynote：*Towards Robust Distributed Systems*（CAP 论述源头之一）。
36. Seth Gilbert & Nancy Lynch, “Brewer’s Conjecture and the Feasibility of Consistent, Available, Partition-Tolerant Web Services,” *ACM SIGACT News*, 2002.（CAP 形式化讨论，常见引用）
37. Dan Pritchett, “BASE: An Acid Alternative,” *ACM Queue*, 2008.（BASE 经典文章）
38. Leslie Lamport, “Paxos Made Simple,” 2001.（共识算法经典短文，按需引用）

## 设计模式 / 重构 / 工作流

39. Gamma et al.（GoF）, *Design Patterns: Elements of Reusable Object-Oriented Software*——Strategy、Factory Method。
40. Martin Fowler, *Refactoring*；Strangler Fig Application 模式说明。  
    https://martinfowler.com/bliki/StranglerFigApplication.html
41. Activiti User Guide / BPMN 2.0。  
    https://www.activiti.org/ （以当前版本文档为准）

## 其它工程库

42. MyBatis / MyBatis-Plus 官方文档。  
    https://mybatis.org/mybatis-3/  
    https://baomidou.com/
43. Apache POI。  
    https://poi.apache.org/
44. Alibaba EasyExcel。  
    https://easyexcel.opensource.alibaba.com/
45. Spring Security Reference（RBAC/方法安全）。  
    https://docs.spring.io/spring-security/reference/

## 使用约定

- 答「默认隔离级别 / 默认 GC」必须带**产品与大版本**，并以当前官方文档或 `SHOW`/`PrintFlags` 实测为准。  
- 引用论文时写清作者、题名、年份/期刊；不确定则改引官方文档，勿臆造。  
