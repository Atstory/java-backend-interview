# Spring·AOP·IoC（9 题详答）

规范 ID 范围见各题标题；原始编号已标注。

<a id="Q097"></a>

### Q097（原始编号: 4）

**【题干】**
请求过来，对于 JavaScript 对象表示法（JavaScript Object Notation，JSON）或者一些对象的数据，怎么正确接收和转换，比如请求体绑定注解（@RequestBody）等等，接收到后，它是怎么映射处理的，接下来怎么处理？

**【核心结论】**
Spring MVC 用 HttpMessageConverter（如 MappingJackson2HttpMessageConverter）将请求体反序列化为 @RequestBody 参数；之后进入 Controller → Service 业务处理并校验。

**【详细说明】**
流程：
1. DispatcherServlet 找到 Handler。
2. RequestResponseBodyMethodProcessor 读取 Body。
3. Jackson（默认）按字段/注解映射到 Java 对象。
4. 可选 @Valid 校验。
5. 业务处理；返回时再序列化为 JSON（@ResponseBody）。
注意 Content-Type、字段名策略、未知字段、日期格式。

**【示例/写法】**
@PostMapping("/orders")
public Result create(@Valid @RequestBody CreateOrderReq req) { ... }

**【易错点】**
- 大 Body 不限流导致内存问题。
- 用 @RequestParam 收 JSON Body。

**【权威依据】**
- Spring MVC Framework Reference：Message Converters
- Jackson 文档

<a id="Q098"></a>

### Q098（原始编号: 17）

**【题干】**
通知，比如环绕通知、前置通知、后置通知，有哪些具体的应用场景？

**【核心结论】**
AOP 通知用于横切：日志、鉴权、事务、限流、耗时统计、幂等、异常统一处理等。环绕最灵活，可控制是否调用目标。

**【详细说明】**
- @Before：参数校验、鉴权前置。
- @AfterReturning：成功审计。
- @AfterThrowing：异常度量。
- @After：清理。
- @Around：计时、重试、事务（底层）、缓存。

**【示例/写法】**
@Around("@annotation(opsLog)") Object around(ProceedingJoinPoint pjp){ long t=...; Object r=pjp.proceed(); ...}

**【易错点】**
- 在通知里堆业务导致难测。

**【权威依据】**
- Spring AOP Advice 类型文档

<a id="Q099"></a>

### Q099（原始编号: 47, 179）

**【题干】**
Spring Boot 常用注解。

**【核心结论】**
列举并解释：@SpringBootApplication、@RestController、@Service、@Autowired/@Resource、@Configuration/@Bean、@Value/@ConfigurationProperties、@Transactional、@Async、@Cacheable、@Scheduled 等。

**【详细说明】**
按「启动/Web/配置/注入/数据/AOP」分类答 8–12 个即可，各一句用途。

**【示例/写法】**
@SpringBootApplication // 见 Q105

**【易错点】**
- 只背名字无约束（如 @Transactional 代理）。

**【权威依据】**
- Spring Boot Reference Documentation

<a id="Q100"></a>

### Q100（原始编号: 66）

**【题干】**
面向切面编程（Aspect-Oriented Programming，AOP）的机制是什么？哪些地方用到？

**【核心结论】**
机制：在连接点织入切面逻辑；Spring 默认用运行时代理（JDK 接口代理或 CGLIB 子类）。用于横切关注点。

**【详细说明】**
概念：Aspect、Pointcut、Join Point、Advice、Weaving。使用处：事务、日志、鉴权、监控。

**【示例/写法】**
@Aspect @Component class LogAspect { ... }

**【易错点】**
- 自调用不经代理。

**【权威依据】**
- Spring AOP 文档；AspectJ 概念

<a id="Q101"></a>

### Q101（原始编号: 89, 195）

**【题干】**
面向切面编程（Aspect-Oriented Programming，AOP）通过什么实现？

**【核心结论】**
Spring AOP：动态代理（JDK Proxy / CGLIB）。亦可引入 AspectJ 编译期/加载期织入做更强切点。

**【详细说明】**
接口代理调 InvocationHandler；类代理生成子类。`@EnableAspectJAutoProxy`。

**【示例/写法】**
说明为何 final/private 方法难被 Spring AOP 增强。

**【易错点】**
- 说 Spring AOP 等于完整 AspectJ。

**【权威依据】**
- Spring AOP Proxying mechanisms

<a id="Q102"></a>

### Q102（原始编号: 93, 102）

**【题干】**
实际项目当中，你用面向切面编程（Aspect-Oriented Programming，AOP）做过哪些事情？

**【核心结论】**
用 STAR 举例：操作日志、接口鉴权、幂等注解、慢方法告警、多租户上下文等。

**【详细说明】**
每个例子点明切点表达式与通知类型、收益。

**【示例/写法】**
@Idempotent 注解 + Around 查 Redis 幂等键。

**【易错点】**
- 虚构未做过的。

**【权威依据】**
- Spring AOP 文档

<a id="Q103"></a>

### Q103（原始编号: 97, 106, 193）

**【题干】**
面向切面编程（Aspect-Oriented Programming，AOP）中的通知，你是怎么使用的？有哪些业务场景？

**【核心结论】**
同 Q098/Q102，强调通知选型与场景匹配。

**【详细说明】**
环绕做计时；前置做鉴权；异常通知做告警。

**【示例/写法】**
结合 @annotation 自定义注解切点。

**【易错点】**
- 所有逻辑都 Around 难维护。

**【权威依据】**
- Spring Advice API

<a id="Q104"></a>

### Q104（原始编号: 142）

**【题干】**
控制反转（Inversion of Control，IoC）和面向切面编程（Aspect-Oriented Programming，AOP）的原理讲一下。

**【核心结论】**
IoC：对象创建与依赖交给容器（DI）。AOP：横切逻辑与业务分离，经代理织入。二者共同支撑 Spring 生态。

**【详细说明】**
IoC：BeanFactory/ApplicationContext、依赖注入、生命周期回调。AOP：代理与拦截器链。事务是 AOP 典型应用。

**【示例/写法】**
画「容器创建 Bean → 注入 → 包装代理」流程。

**【易错点】**
- 把 IoC 说成仅 @Autowired。

**【权威依据】**
- Spring Core IoC / AOP Reference

<a id="Q105"></a>

### Q105（原始编号: 164）

**【题干】**
@SpringBootApplication 注解由哪些注解组成？

**【核心结论】**
元注解组合：@SpringBootConfiguration（= @Configuration）、@EnableAutoConfiguration、@ComponentScan（默认扫描主类所在包）。

**【详细说明】**
此外还有 @Custom 相关属性；排除自动配置可用 exclude。

**【示例/写法】**
@SpringBootApplication(exclude = {DataSourceAutoConfiguration.class})

**【易错点】**
- 漏掉其中一个。

**【权威依据】**
- Spring Boot @SpringBootApplication Javadoc

