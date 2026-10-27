# 并发·锁·线程池（22 题详答）

规范 ID 范围见各题标题；原始编号已标注。

<a id="Q075"></a>

### Q075（原始编号: 16, 237）

**【题干】**
怎么记录线程运行完了，并且都正确提交了，可以继续走接下来的流程？

**【核心结论】**
用协作原语等待完成：`CountDownLatch`、`CyclicBarrier`、`CompletableFuture.allOf`、线程池 `invokeAll`/`Future.get`，并检查异常与结果。

**【详细说明】**
「正确提交」要定义：任务 Future 无异常、业务状态成功。失败策略：快速失败或收集错误。

**【示例/写法】**
CountDownLatch latch=new CountDownLatch(n);
// 各线程 finally latch.countDown();
latch.await();
CompletableFuture.allOf(f1,f2,...).join();

**【易错点】**
- 只 sleep 等待。
- 忽略任务异常当成功。

**【权威依据】**
- java.util.concurrent 包文档；JCIP 相关章节

<a id="Q076"></a>

### Q076（原始编号: 26, 188）

**【题干】**
volatile 关键字用在了哪些地方？synchronized 关键字用在了哪些地方？

**【核心结论】**
volatile：可见性与禁止重排序（有限），典型状态标志、DCL 中的单例引用。synchronized：互斥临界区，保证原子+可见+有序。

**【详细说明】**
volatile 不保证 i++ 原子性。synchronized 可修饰方法/块，可重入。

**【示例/写法】**
private volatile boolean shutdown;
synchronized(lock){ ... }

**【易错点】**
- 用 volatile 代替锁做复合操作。

**【权威依据】**
- JLS；JCIP；Java Language Spec volatile/synchronized

<a id="Q077"></a>

### Q077（原始编号: 28）

**【题干】**
比较并交换（Compare-And-Swap，CAS）是什么？原理是什么？英文全称是什么？

**【核心结论】**
CAS = Compare-And-Swap：原子地「期望值匹配则更新为新值」。硬件/CPU 原子指令支撑；Java 中 Unsafe/VarHandle、Atomic* 使用。有 ABA 问题可用版本戳。

**【详细说明】**
原理：读当前、比较 expected、成功则写 update，否则失败重试。无锁乐观并发基础。

**【示例/写法】**
atomic.compareAndSet(expect, update);

**【易错点】**
- 忽略 ABA。
- 英文写成 Compare-And-Set 当全称（Atomic 方法名是 CAS 思想）。

**【权威依据】**
- java.util.concurrent.atomic 文档；Goetz JCIP 关于 CAS

<a id="Q078"></a>

### Q078（原始编号: 29, 191）

**【题干】**
synchronized 关键字和 volatile 关键字的区别。

**【核心结论】**
synchronized 互斥+可见+有序（临界区）；volatile 仅可见与有序（单变量读写语义），不互斥。

**【详细说明】**
对比表：原子性复合操作、阻塞、使用成本。

**【示例/写法】**
计数用 AtomicInteger/synchronized，不用单独 volatile int++。

**【易错点】**
- 认为 volatile 能保复合操作原子。

**【权威依据】**
- JLS；语言规范

<a id="Q079"></a>

### Q079（原始编号: 42, 227）

**【题干】**
synchronized 关键字和可重入锁的区别。

**【核心结论】**
二者都可重入。`ReentrantLock`（显式 Lock）提供可中断、超时、公平、多条件队列等；synchronized 是 JVM 内置监视器，语法简洁，锁释放自动。

**【详细说明】**
区别：API 灵活度、条件变量数量（synchronized 单 wait set vs 多 Condition）、必须手动 unlock（finally）。性能在现代 HotSpot 上通常接近。

**【示例/写法】**
lock.lock(); try { ... } finally { lock.unlock(); }

**【易错点】**
- 忘记 unlock。
- 说 synchronized 不可重入（错）。

**【权威依据】**
- ReentrantLock Javadoc；JLS synchronized

<a id="Q080"></a>

### Q080（原始编号: 43, 226）

**【题干】**
锁讲一下，用过哪几种？

**【核心结论】**
分类：内置锁 synchronized、显式 Lock、读写锁、自旋/乐观（CAS）、分布式锁（Redis/ZK）、数据库乐观锁版本号。按场景选型。

**【详细说明】**
举例：单机临界区 synchronized/ReentrantLock；读多写少 ReadWriteLock/StampedLock；跨进程 Redis 锁；库存 version 字段。

**【示例/写法】**
列用过的并说场景。

**【易错点】**
- 分布式锁滥用。

**【权威依据】**
- JCIP；ReentrantReadWriteLock；Redis 锁文档

<a id="Q081"></a>

### Q081（原始编号: 44, 158, 177）

**【题干】**
线程池的运行机制讲一下。

**【核心结论】**
ThreadPoolExecutor：任务来先用核心线程 → 队列 → 创建至最大线程 → 拒绝策略。关键参数：core、max、keepAlive、queue、handler、工厂。

**【详细说明】**
流程与工作线程生命周期；注意无界队列时 max 可能达不到；`execute` vs `submit` 异常处理差异。

**【示例/写法】**
new ThreadPoolExecutor(core, max, keepAlive, unit, queue, factory, handler);

**【易错点】**
- Executors.newFixed 用无界队列隐患。
- 同池跑互依赖任务死锁。

**【权威依据】**
- ThreadPoolExecutor Javadoc；《Java 并发编程实战》线程池章节

<a id="Q082"></a>

### Q082（原始编号: 48）

**【题干】**
创建线程的几种方式。

**【核心结论】**
继承 Thread、实现 Runnable、实现 Callable+FutureTask、线程池提交、CompletableFuture 异步等；本质仍是 Thread 执行任务。

**【详细说明】**
推荐任务与执行解耦：Runnable/Callable + 池，少继承 Thread。

**【示例/写法】**
executor.submit(() -> ...);

**【易错点】**
- 大量 new Thread 无池。

**【权威依据】**
- Java Tutorial Concurrency；Executor 框架

<a id="Q083"></a>

### Q083（原始编号: 51, 176, 221）

**【题干】**
多线程运行结束后，我怎么知道这几个线程都正确运行结束了？有什么方式？10 个线程执行完了，需要走其他逻辑，我怎么知道这 10 个线程执行完了？怎么知道这 10 个线程执行完了？

**【核心结论】**
同 Q075：Latch/Barrier/allOf/invokeAll；并检查每个任务状态。

**【详细说明】**
强调「正确」：收集异常，不要只等结束。

**【示例/写法】**
List<Future<T>> fs = pool.invokeAll(tasks);
for (Future<T> f: fs) f.get();

**【易错点】**
- await 后不检查结果。

**【权威依据】**
- CountDownLatch Javadoc

<a id="Q084"></a>

### Q084（原始编号: 61, 213）

**【题干】**
用过哪些线程池？有什么区别？怎么分析线程池的一些指标？

**【核心结论】**
常用自建 ThreadPoolExecutor；区别在队列与拒绝策略、IO/CPU 型参数。指标：活跃线程、队列长度、完成任务数、拒绝次数、任务耗时。

**【详细说明】**
禁止无脑 `Executors.newCached`（无界线程）。监控：Micrometer、`ThreadPoolExecutor` API、日志。

**【示例/写法】**
pool.getActiveCount(); getQueue().size();

**【易错点】**
- Fixed/Cached/Single 分不清队列行为。

**【权威依据】**
- ThreadPoolExecutor；Java EE/微服务监控实践

<a id="Q085"></a>

### Q085（原始编号: 80, 147）

**【题干】**
讲一下 ThreadLocal。

**【核心结论】**
线程隔离的变量副本，典型存用户上下文、事务同步、SimpleDateFormat（历史）。注意内存泄漏：线程池复用线程需 `remove`。

**【详细说明】**
实现：Thread 内 ThreadLocalMap，弱引用 key。InheritableThreadLocal 可传子线程（慎用）。

**【示例/写法】**
try { ctx.set(x); ... } finally { ctx.remove(); }

**【易错点】**
- 线程池场景忘记 remove。

**【权威依据】**
- ThreadLocal Javadoc；JCIP 相关讨论

<a id="Q086"></a>

### Q086（原始编号: 82, 202）

**【题干】**
volatile 关键字讲一下，怎么用？

**【核心结论】**
保证可见性与禁止特定重排序；用于状态标志、发布安全的不可变对象引用等；不替代锁。

**【详细说明】**
示例：shutdown 标志；DCL 单例的实例字段。

**【示例/写法】**
private static volatile Singleton inst;

**【易错点】**
- 当锁用。

**【权威依据】**
- JLS；Effective Java 条目（单例）

<a id="Q087"></a>

### Q087（原始编号: 83, 201）

**【题干】**
ConcurrentHashMap 为什么是线程安全的？

**【核心结论】**
JDK8+ 用 CAS + synchronized 锁桶头（Node）等分段思想演进，读写并发；复合操作仍需注意（如 check-then-act 要用原子方法）。

**【详细说明】**
扩容协助转移；`size` 近似；禁止 null。相对 Hashtable 全表锁更细粒度。

**【示例/写法】**
map.putIfAbsent(k,v); compute 系列原子更新。

**【易错点】**
- 认为复合业务「先 get 再 put」自动安全。

**【权威依据】**
- ConcurrentHashMap Javadoc；源码设计说明

<a id="Q088"></a>

### Q088（原始编号: 84, 200）

**【题干】**
线程安全的集合有哪些？

**【核心结论】**
ConcurrentHashMap、CopyOnWriteArrayList、ConcurrentLinkedQueue、BlockingQueue 实现、`Collections.synchronized*` 包装、Hashtable/Vector（遗留）等。

**【详细说明】**
选型：读多偶写 COW；高并发 Map 用 CHM；生产者消费者用 BlockingQueue。

**【示例/写法】**
new ConcurrentHashMap<>();

**【易错点】**
- ArrayList 当线程安全。

**【权威依据】**
- java.util.concurrent 包总述

<a id="Q089"></a>

### Q089（原始编号: 85, 199）

**【题干】**
synchronized 关键字和 Lock 接口的区别。

**【核心结论】**
同 Q079 核心对比；Lock 可 tryLock、中断、公平、多条件。

**【详细说明】**
选择：简单场景 synchronized；需要高级特性用 Lock。

**【示例/写法】**
if (lock.tryLock(1, TimeUnit.SECONDS)) try {...} finally {lock.unlock();}

**【易错点】**
- Lock 不在 finally 解锁。

**【权威依据】**
- Lock Javadoc；语言规范

<a id="Q090"></a>

### Q090（原始编号: 118）

**【题干】**
你用过哪些锁？

**【核心结论】**
同 Q080，列项目中真实使用的锁类型与场景。

**【详细说明】**
举例清单 + 一次踩坑（死锁/忘记释放）。

**【示例/写法】**
synchronized / ReentrantLock / Redis 锁 / DB 乐观锁。

**【易错点】**
- 堆名词无场景。

**【权威依据】**
- JCIP；Redis 锁

<a id="Q091"></a>

### Q091（原始编号: 126, 133, 178, 239）

**【题干】**
创建线程池的几种方式。

**【核心结论】**
推荐：构造 `ThreadPoolExecutor`/`ScheduledThreadPoolExecutor`；`Executors` 工厂方法仅作演示需知队列风险；Spring/`@Async` 自定义池。

**【详细说明】**
七大参数意义；CPU 密集 vs IO 密集公式仅经验起点。

**【示例/写法】**
Executors.newFixedThreadPool(n) // 无界 LinkedBlockingQueue 风险

**【易错点】**
- 生产直接 Executors 无界。

**【权威依据】**
- Effective Java（Executor）；阿里巴巴 Java 手册相关建议；ThreadPoolExecutor

<a id="Q092"></a>

### Q092（原始编号: 130）

**【题干】**
数字人民币解冻付款，怎么处理高并发？

**【核心结论】**
高并发资金操作：限流、异步化、账户分片/分段锁、幂等单号、状态机、与央行/渠道接口的超时重试与对账；本地先落单再异步推进。

**【详细说明】**
设计：
1. 入口网关限流与幂等。
2. 解冻/支付状态机（防重复解冻付款）。
3. 热点账户：排队、分片、或渠道侧能力。
4. 超时不明：查询单而非直接重试扣款。
5. 最终对账。
不编造具体央行 API。

**【示例/写法】**
createOrder(idemKey) → freeze → pay → confirm；各步可查询。

**【易错点】**
- 无幂等直接重试付款。

**【权威依据】**
- 支付状态机与幂等通识；渠道文档（若有）

<a id="Q093"></a>

### Q093（原始编号: 151）

**【题干】**
抽象队列同步器（AbstractQueuedSynchronizer，AQS）。

**【核心结论】**
AQS 是 java.util.concurrent 锁与同步器的基础框架：state + CLH 变体等待队列，支撑 ReentrantLock、Semaphore、CountDownLatch 等。

**【详细说明】**
独占/共享模式；`acquire`/`release`；条件队列。自定义同步器重写 tryAcquire 等。

**【示例/写法】**
ReentrantLock 内部 Sync extends AQS。

**【易错点】**
- 只背名字不谈 state 与队列。

**【权威依据】**
- AQS Javadoc；JCIP

<a id="Q094"></a>

### Q094（原始编号: 157）

**【题干】**
线程池的核心参数。

**【核心结论】**
corePoolSize、maximumPoolSize、keepAliveTime、unit、workQueue、threadFactory、handler（拒绝策略）。

**【详细说明】**
逐一解释；拒绝策略 Abort/CallerRuns/Discard/DiscardOldest。

**【示例/写法】**
表格默写参数含义。

**【易错点】**
- 忽略 handler。

**【权威依据】**
- ThreadPoolExecutor 构造器 Javadoc

<a id="Q095"></a>

### Q095（原始编号: 159）

**【题干】**
高并发接口，每秒查询次数（Queries Per Second，QPS）过万，接口怎么设计？

**【核心结论】**
读多：多级缓存、CDN、防击穿；写多：削峰、分库分表、异步；整体：无状态水平扩展、限流降级、连接池与超时、压测验证。

**【详细说明】**
分层：接入限流 → 本地/Redis 缓存 → 服务无状态 → DB 优化/读写分离。幂等与熔断。

**【示例/写法】**
热点 GET：Cache-Aside + 单飞锁重建。

**【易错点】**
- 无压测声称过万。

**【权威依据】**
- 高并发架构通识；Redis/缓存文档

<a id="Q096"></a>

### Q096（原始编号: 222）

**【题干】**
10 个线程执行完了，需要走其他逻辑，我怎么知道这 10 个线程执行完了？

**【核心结论】**
同 Q075/Q083：CountDownLatch(10) 或 CompletableFuture.allOf。

**【详细说明】**
简洁答一种首选写法并提异常处理。

**【示例/写法】**
latch.await(); nextStep();

**【易错点】**
- while(!allAlive) 空转。

**【权威依据】**
- CountDownLatch Javadoc

