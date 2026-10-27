# JVM与内存（13 题详答）

规范 ID 范围见各题标题；原始编号已标注。

<a id="Q062"></a>

### Q062（原始编号: 10）

**【题干】**
Java 虚拟机（Java Virtual Machine，JVM）你是怎么优化的？

**【核心结论】**
优化基于指标：GC 停顿、吞吐、内存、CPU。手段含选型与调参 GC、堆大小、对象分配分析、代码减分配、线程与直内存。

**【详细说明】**
步骤：基线监控 → 抓 GC 日志/heap dump → 定位泄漏或疯分配 → 改代码或调参 → 回归。
参数方向：`-Xms/-Xmx` 同值、GC 选择（G1/ZGC）、`-XX:+HeapDumpOnOutOfMemoryError` 等。

**【示例/写法】**
-Xms2g -Xmx2g -XX:+UseG1GC -Xlog:gc*:file=gc.log

**【易错点】**
- 无数据乱调参。

**【权威依据】**
- HotSpot GC Tuning Guide（Oracle）
- JVM Spec 运行时数据区

<a id="Q063"></a>

### Q063（原始编号: 18）

**【题干】**
生产环境上出现一些问题，比如内存溢出了或者其他问题，除了正常查看日志，你还有哪些分析工具或方式，能定位到具体是代码问题还是结构化查询语言问题？

**【核心结论】**
分层排查：应用指标/APM、JVM（jstack/jmap/MAT）、SQL（慢日志/EXPLAIN）、系统（top/vmstat/iostat）、网络。用证据区分代码泄漏 vs 慢 SQL 占连接/CPU。

**【详细说明】**
工具：
- 线程：jstack、async-profiler。
- 内存：jmap、MAT、JFR。
- SQL：慢日志、Druid/p6spy、DB 控制台。
- 链路：SkyWalking/Zipkin 看耗时占比。
判别：接口慢且 DB 耗时高→SQL；Old 涨且 GC 频繁→对象泄漏/缓存；CPU 高且栈在业务循环→代码。

**【示例/写法】**
一次慢请求：APM 火焰图 + 对应 SQL EXPLAIN。

**【易错点】**
- 只看应用日志不看 DB。

**【权威依据】**
- JDK 工具文档；MySQL 慢日志

<a id="Q064"></a>

### Q064（原始编号: 25）

**【题干】**
中央处理器（Central Processing Unit，CPU）这一块容易占用率过高，你是怎么优化的？

**【核心结论】**
先定位热点线程与方法（top -H、jstack、profiler），再分：业务死循环、正则/序列化过重、GC 压力、JIT 未优化路径、不合理线程数导致上下文切换。

**【详细说明】**
优化：减计算、缓存结果、算法复杂度、控制并行度、换高效库、解决 Full GC 风暴。

**【示例/写法】**
perf/async-profiler 找热点方法后重构。

**【易错点】**
- 盲目加核。

**【权威依据】**
- Java 性能分析通识；OS 性能工具

<a id="Q065"></a>

### Q065（原始编号: 34, 186）

**【题干】**
Java 虚拟机（Java Virtual Machine，JVM）优化，你做过哪些？

**【核心结论】**
同 Q062，用 STAR 举 1–2 个真实案例（如 G1 调停顿、修泄漏）。

**【详细说明】**
案例结构：现象→证据→改动→指标变化。

**【示例/写法】**
「Full GC 频繁 → MAT 定位缓存无界 → 加上限与 TTL → GC 次数下降」。

**【易错点】**
- 只列参数无结果。

**【权威依据】**
- GC Tuning Guide

<a id="Q066"></a>

### Q066（原始编号: 57, 167）

**【题干】**
代码运行在 Java 虚拟机（Java Virtual Machine，JVM）的什么地方？

**【核心结论】**
字节码在 JVM 中由类加载器加载到方法区/元空间等，执行引擎解释/JIT 编译后在 CPU 上跑；线程栈帧在 Java 虚拟机栈；对象在堆。

**【详细说明】**
运行时数据区：堆、虚拟机栈、本地方法栈、程序计数器、方法区（元空间）。「代码」指令流经解释器/JIT；热点本地代码在 Code Cache。

**【示例/写法】**
对象 new → 堆；局部变量 → 栈帧局部变量表。

**【易错点】**
- 说「代码都在堆里跑」。

**【权威依据】**
- JVM Specification §2 Runtime Data Areas

<a id="Q067"></a>

### Q067（原始编号: 63, 216）

**【题干】**
Java 虚拟机（Java Virtual Machine，JVM）优化你做过吗？怎么去分析和优化？

**【核心结论】**
同 Q062/Q065：监控→日志/dump→分析→改代码/参数→验证。

**【详细说明】**
分析链：GC 日志解读、heap histogram、泄漏引用链、分配火焰图。

**【示例/写法】**
开启 JFR 持续画像。

**【易错点】**
- 生产随意 jmap live 大停顿不评估。

**【权威依据】**
- Java Flight Recorder 文档；GC Tuning

<a id="Q068"></a>

### Q068（原始编号: 86, 198）

**【题干】**
什么是内存溢出？怎么解决？

**【核心结论】**
OOM 指申请内存失败：常见 `Java heap space`、`Metaspace`、`Direct buffer memory`、`GC overhead limit`、栈 `StackOverflowError`（严格说是栈溢出）。解决：看异常类型→dump→修泄漏或调大并设上限。

**【详细说明】**
步骤：保留 dump；MAT 看 Dominator；查无界缓存、类加载泄漏、NIO 直内存；设置 `-XX:+HeapDumpOnOutOfMemoryError`。

**【示例/写法】**
-XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/path

**【易错点】**
- 一律加 -Xmx 当永久方案。

**【权威依据】**
- Java 异常文档；MAT 用户指南

<a id="Q069"></a>

### Q069（原始编号: 87, 148, 197）

**【题干】**
Java 类加载器有哪些？

**【核心结论】**
启动类加载器 Bootstrap、扩展/平台 Platform（JDK9+）、应用 Application；还可自定义 ClassLoader。双亲委派：优先委派父加载。

**【详细说明】**
JDK8：Bootstrap、Extension、App；JDK9+：Platform 替代 Extension。Tomcat 等有 WebApp ClassLoader。

**【示例/写法】**
说明 SPI 等打破双亲委派的场景。

**【易错点】**
- 仍把 JDK17 说成 Extension。

**【权威依据】**
- JVM Spec 类加载；JEP 261 模块系统相关说明

<a id="Q070"></a>

### Q070（原始编号: 88, 146, 196）

**【题干】**
Java 类加载过程。

**【核心结论】**
加载 → 链接（验证、准备、解析）→ 初始化；使用与卸载。初始化执行 `<clinit>`。

**【详细说明】**
- 加载：字节流→Class 结构。
- 验证：字节码安全。
- 准备：静态字段默认值。
- 解析：符号引用→直接引用（可延迟）。
- 初始化：主动使用时执行静态初始化。

**【示例/写法】**
new、访问静态、反射、主类等触发初始化。

**【易错点】**
- 把准备阶段当成赋源代码中的正确初值（final 编译期常量例外）。

**【权威依据】**
- JVM Spec §5 Linking/Initialization

<a id="Q071"></a>

### Q071（原始编号: 90, 99）

**【题干】**
Java 开发工具包 17（Java Development Kit 17，JDK 17）使用的是哪个垃圾回收器？

**【核心结论】**
JDK 9 起默认 GC 为 G1；JDK 17 仍默认 G1GC（除非指定其他）。另可选 Parallel、Serial、ZGC、Shenandoah（发行版支持情况视厂商）。

**【详细说明】**
核实：`java -XX:+PrintFlagsFinal -version | grep Use*GC`。ZGC 在后续版本持续增强，但不等于 17 默认。

**【示例/写法】**
java -XX:+UseZGC ...  # 显式启用

**【易错点】**
- 说 JDK17 默认 ZGC。

**【权威依据】**
- Oracle JDK 17 GC 文档 / HotSpot Virtual Machine Garbage Collection Tuning Guide

<a id="Q072"></a>

### Q072（原始编号: 91, 100）

**【题干】**
Java 开发工具包 8（Java Development Kit 8，JDK 8）使用的是哪个垃圾回收器？

**【核心结论】**
JDK 8 服务器类机器默认通常是 Parallel GC（Throughput）；非 G1。G1 在 JDK9 才成为默认。

**【详细说明】**
可用 `-XX:+UseG1GC` 显式启用。客户端类历史默认 Serial。以实际 flags 为准。

**【示例/写法】**
java -XX:+PrintCommandLineFlags -version

**【易错点】**
- 把 JDK8 默认说成 G1 或 CMS。

**【权威依据】**
- Oracle JDK 8 GC Ergonomics 说明

<a id="Q073"></a>

### Q073（原始编号: 144）

**【题干】**
如何解决内存溢出？

**【核心结论】**
同 Q068，强调分类处理与代码修复优先于盲目扩容。

**【详细说明】**
heap/metaspace/direct/native 分别对策。

**【示例/写法】**
无界 Map → 限大小+TTL；ClassLoader 泄漏修热部署。

**【易错点】**
- 忽略 DirectMemory。

**【权威依据】**
- 同 Q068

<a id="Q074"></a>

### Q074（原始编号: 161）

**【题干】**
Java 虚拟机（Java Virtual Machine，JVM）的运行时数据区。

**【核心结论】**
按 JVM Spec：PC、Java 虚拟机栈、本地方法栈、堆、方法区；JDK8+ 方法区常由元空间实现。线程私有 vs 共享要分清。

**【详细说明】**
- 线程私有：PC、栈、本地方法栈。
- 共享：堆、方法区（元空间）、直接内存（JVM Spec 外常见运行时区域）。
- 栈帧：局部变量表、操作数栈、动态链接、返回地址。

**【示例/写法】**
画分区图作答。

**【易错点】**
- 把「常量池」只放堆或只放方法区说死（注意运行时常量池在方法区）。

**【权威依据】**
- JVM Specification §2.5

