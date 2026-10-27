# 微服务与治理（7 题详答）

规范 ID 范围见各题标题；原始编号已标注。

<a id="Q106"></a>

### Q106（原始编号: 49, 174）

**【题干】**
OpenFeign 远程调用时，A 服务连接 B 服务，B 服务有 1、2、3 三个节点，会连接到哪个节点？

**【核心结论】**
由负载均衡客户端决定（Spring Cloud LoadBalancer 或历史 Ribbon）：默认常见轮询等策略，不是固定某一节点；需结合注册中心拿到实例列表。

**【详细说明】**
流程：Feign → LoadBalancer 从 Discovery 取 B 的实例 → 按策略选一个 → HTTP 调用。可配随机、权重、重试。会话粘滞需显式。

**【示例/写法】**
说明：无 LB 时直连单 URL 则无选择。

**【易错点】**
- 说「一定连 1 号」。

**【权威依据】**
- Spring Cloud OpenFeign / LoadBalancer 文档

<a id="Q107"></a>

### Q107（原始编号: 50, 175, 220）

**【题干】**
微服务中的配置使用什么？配置只能发布后才能生效吗？不能实时生效吗？

**【核心结论】**
常用 Nacos/Apollo/Spring Cloud Config 等配置中心。可实时生效：通过监听刷新（Nacos 配置监听、`@RefreshScope`、Spring Cloud Bus 等），不必每次发版；敏感变更仍要谨慎与灰度。

**【详细说明】**
说明：并非所有配置都能热更新（如部分连接池创建后参数）；数据源等可能需特殊处理。发布配置 ≠ 发应用版本。

**【示例/写法】**
@RefreshScope on @ConfigurationProperties beans; Nacos listener。

**【易错点】**
- 认为所有项改完立即对长连接生效。

**【权威依据】**
- Nacos 配置管理文档；Spring Cloud Context Refresh

<a id="Q108"></a>

### Q108（原始编号: 62, 110, 215）

**【题干】**
用过哪些中间件？用在什么地方？起什么作用？

**【核心结论】**
按类别列举：Redis 缓存/锁、MQ 异步、Nacos 注册配置、Nginx 反代、ES 搜索、网关等；各一句作用。

**【详细说明】**
对齐项目架构图回答。

**【示例/写法】**
「Redis：热点与锁；Kafka：订单事件；Nacos：注册+配置」。

**【易错点】**
- 堆名单无作用。

**【权威依据】**
- 各中间件官方概述

<a id="Q109"></a>

### Q109（原始编号: 64, 211）

**【题干】**
介绍一下微服务的几个组件。

**【核心结论】**
注册发现、配置中心、网关、负载均衡、熔断限流、链路追踪、集中日志等。举例 Spring Cloud Alibaba 组件。

**【详细说明】**
组件协作：服务注册 → 网关路由 → Feign 调用 → 熔断 → 追踪。

**【示例/写法】**
Nacos + Gateway + OpenFeign + Sentinel + SkyWalking。

**【易错点】**
- 把业务服务本身当「组件」罗列无治理能力。

**【权威依据】**
- Spring Cloud 文档；微服务模式（Fowler 等）

<a id="Q110"></a>

### Q110（原始编号: 65）

**【题干】**
有没有遇到熔断问题？A 服务调用 B 服务，B 服务卡住了，OpenFeign 远程调用有熔断机制，直接触发熔断并抛出异常，避免服务资源持续占用，导致 A 服务也崩溃。

**【核心结论】**
题干已描述熔断价值：失败快速、保护调用方线程池。补充：超时、隔离（舱壁）、半开恢复、降级返回；Feign 需整合 Resilience4j/Sentinel 等。

**【详细说明】**
现象：B 慢导致 A 线程耗尽。对策：超时 shorter than 调用方忍耐；熔断打开后短时间快速失败；舱壁线程池隔离；降级缓存/默认值。

**【示例/写法】**
Sentinel/Resilience4j 注解或规则；Feign fallback。

**【易错点】**
- 无超时只靠熔断。
- 熔断后无限重试打爆。

**【权威依据】**
- Resilience4j / Sentinel 文档；Release It! 熔断思想

<a id="Q111"></a>

### Q111（原始编号: 78）

**【题干】**
注册中心和配置中心，你用的都是 Nacos 吗？

**【核心结论】**
可如实答：常用 Nacos 同时承担注册与配置；也可用 Eureka/Consul + Config/Apollo 等拆分。说明选择原因。

**【详细说明】**
Nacos：临时/持久实例、配置命名空间与分组、监听推送。

**【示例/写法】**
对比一句话：Eureka 偏注册；Apollo 偏配置。

**【易错点】**
- 不懂命名空间导致环境串配置。

**【权威依据】**
- Nacos 官方文档

<a id="Q112"></a>

### Q112（原始编号: 92, 101）

**【题干】**
Nacos 使用的是应用程序编程接口（Application Programming Interface，API），还是什么？

**【核心结论】**
Nacos 提供 HTTP Open API、Java SDK/客户端，以及 Spring Cloud 抽象集成；控制台是管理界面。服务发现与配置通过客户端与服务端通信（含长轮询/gRPC 等版本相关机制）。

**【详细说明】**
回答层次：对应用是依赖 starter/SDK；对运维可用 HTTP API；底层有服务端协议。

**【示例/写法】**
NamingService.registerInstance(...); ConfigService.getConfig(...);

**【易错点】**
- 以为只能点控制台。

**【权威依据】**
- Nacos Open API / SDK 文档

