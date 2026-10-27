# 安全与加密（6 题详答）

规范 ID 范围见各题标题；原始编号已标注。

<a id="Q121"></a>

### Q121（原始编号: 3）

**【题干】**
Web 层请求进来了，怎么防止跨站脚本攻击（Cross-Site Scripting，XSS）或者结构化查询语言注入攻击，写在哪里，怎么防止这些攻击？

**【核心结论】**
分层防御：XSS 在输出编码/CSP/模板自动转义；SQLi 在参数化查询/ORM 绑定，禁止拼接 SQL。写在「输出层」与「数据访问层」，而不是只靠前端校验。

**【详细说明】**
**XSS**
- 存储型/反射型/DOM 型。
- 防御：按上下文做 HTML/JS/URL 编码（输出编码）；现代模板（Thymeleaf 等）默认转义；Content-Security-Policy；HttpOnly Cookie；输入校验为辅。
- 写在哪：视图渲染/前端 sink 点；响应头中间件设 CSP；富文本用白名单消毒（OWASP Java HTML Sanitizer）。

**SQLi**
- 防御：PreparedStatement / MyBatis `#{}` 参数绑定；禁止 `${}` 拼条件（除非严格白名单）；最小权限账号。
- 写在哪：DAO/Repository 层；WAF 为纵深。

二者不可只靠「拦截器里替换关键字」。

**【示例/写法】**
// SQLi 正确
PreparedStatement ps = conn.prepareStatement("SELECT * FROM u WHERE id=?");
ps.setLong(1, id);

// MyBatis
select * from u where id = #{id}  -- 不要用 ${id}

// XSS：模板转义输出用户昵称；CSP: default-src 'self'

**【易错点】**
- 黑名单过滤 SQL 关键字。
- 只转义输入不转义输出。
- 混淆 XSS 与 CSRF（还需 Token）。

**【权威依据】**
- OWASP XSS Prevention Cheat Sheet
- OWASP SQL Injection Prevention Cheat Sheet
- CSP 规范（MDN / W3C）
- JDBC PreparedStatement

<a id="Q122"></a>

### Q122（原始编号: 5）

**【题干】**
亚马逊简单存储服务（Amazon Simple Storage Service，Amazon S3）容器。你对一些文件加密上传的时候，用哪些算法，比如RES，加密后的密钥你存在哪里，存在 S3 存储桶里，还是其他地方？

**【核心结论】**
原文「RES」按语境应纠正为 **AES**（常见为 AES-256），而非某种叫 RES 的标准算法。S3 支持 SSE-S3、SSE-KMS、SSE-C 与客户端加密；数据密钥通常由 KMS/密钥服务保管，而不是把主密钥明文塞进同一桶对象里当唯一防护。

**【详细说明】**
**纠正**：用户说的「RES」→ 应为 **AES**（Advanced Encryption Standard）。若指 RSA，那是非对称，常用于信封加密中的密钥封装，而不是大文件主加密算法。

**S3 加密方式（官方）**
1. SSE-S3：S3 管密钥，AES-256。
2. SSE-KMS：CMK 在 AWS KMS，可审计权限。
3. SSE-C：客户提供密钥，S3 不持久保存你的密钥。
4. 客户端加密：应用先加密再 PutObject。

**密钥存哪**
- 推荐：KMS/HSM/企业密钥系统；应用只持有角色权限。
- 对象元数据可存「密钥 ID / 加密上下文」，不是存主密钥明文。
- 不要把解密主密钥与密文对象一并「仅靠隐藏路径」放在同一桶。

**【示例/写法】**
PutObject 时 ServerSideEncryption = aws:kms，指定 KMS KeyId；
应用侧信封加密：随机 AES 数据密钥加密文件，数据密钥用 KMS/RSA 封装后存元数据。

**【易错点】**
- 把 RES 当成算法名继续展开。
- 主密钥明文存同桶。
- 忽略 IAM 与桶策略。

**【权威依据】**
- AWS S3 用户指南：Protecting data with encryption
- AWS KMS 文档
- NIST FIPS 197（AES）

<a id="Q123"></a>

### Q123（原始编号: 7）

**【题干】**
在涉及外部接口时，你要注意哪些算法？有哪些算法可以保证对接安全，不会被攻击？

**【核心结论】**
对接安全是「协议+密钥管理+防重放」组合：TLS、签名（HMAC-SHA256/非对称）、时间戳与 nonce、可选加密载荷；算法只是一环，不能单独「保证不会被攻击」。

**【详细说明】**
常见：
- 传输：TLS 1.2+。
- 完整性与认证：HMAC-SHA256、RSA/ECDSA 签名。
- 机密性：AES-GCM。
- 国密场景：SM2/SM3/SM4。
配套：IP 白名单、限流、证书固定、密钥轮换。

**【示例/写法】**
sign = HMAC_SHA256(secret, method+path+timestamp+nonce+bodyHash)

**【易错点】**
- 只用 MD5 当签名。
- 无时间窗可重放。

**【权威依据】**
- RFC 2104 HMAC；TLS 1.2/1.3；OWASP API Security

<a id="Q124"></a>

### Q124（原始编号: 45, 225）

**【题干】**
项目中你是如何处理加密数据的？对于加密的数据，你是怎么查询的？比如手机号后四位，你怎么查询、做搜索？

**【核心结论】**
密文不可直接模糊查。正确做法：另建**盲索引**（如对后四位做 HMAC/keyed hash 存检索列），或同步到 ES 的 keyword 检索字段；禁止解密全表扫描比对。

**【详细说明】**
方案：
1. 存储：手机号 AES-GCM 等加密存密文列。
2. 检索：`last4_hmac = HMAC(pepper, last4)` 存独立列并建索引；查询时对输入后四位同样 HMAC 后等值查。
3. 或：后四位明文若合规允许可单独列（仍有隐私风险，需评估）。
4. ES：密文不进分析器；盲索引值进 keyword；或合规允许的脱敏字段。
5. Pepper/密钥放 KMS，定期评估。

**【示例/写法】**
SELECT * FROM user WHERE mobile_last4_index = ?;
-- ? = HMAC(pepper, requestLast4)
-- 不要：SELECT * 后解密每行比对

**【易错点】**
- 建议解密全表。
- 无密钥的 plain MD5 后四位（易彩虹表）。
- 用可逆加密当索引且密钥硬编码。

**【权威依据】**
- 盲索引/可搜索加密工程实践（应用 HMAC 索引）
- AES-GCM 用法；OWASP Cryptographic Storage
- Elasticsearch keyword 字段映射文档

<a id="Q125"></a>

### Q125（原始编号: 98, 194）

**【题干】**
业务当中，不同用户的权限你是怎么处理的？代码当中有写过吗？怎么写的？

**【核心结论】**
常用 RBAC/ABAC：认证后拿到主体，鉴权用角色/权限注解或拦截器；数据权限加组织维度过滤。

**【详细说明】**
实现：Spring Security / Sa-Token；`@PreAuthorize`；网关鉴权 + 服务二次校验；数据范围 SQL 拼 `dept_id IN (...)`（注意注入）。

**【示例/写法】**
@PreAuthorize("hasAuthority('order:read')")

**【易错点】**
- 只藏按钮不鉴权接口。

**【权威依据】**
- Spring Security Reference；RBAC 模型

<a id="Q126"></a>

### Q126（原始编号: 224）

**【题干】**
代码中使用了哪些加密算法？

**【核心结论】**
按用途答：传输 TLS；存储 AES-GCM；密码哈希 bcrypt/scrypt/Argon2；签名 HMAC-SHA256 或 RSA/ECDSA；国密 SM 系列（若信创）。

**【详细说明】**
说明密钥管理与轮换；密码绝不可逆加密存储。

**【示例/写法】**
PasswordEncoder = new BCryptPasswordEncoder();

**【易错点】**
- 用 Base64 当加密。
- 可逆加密存密码。

**【权威依据】**
- OWASP Password Storage；NIST 密码学建议；AES/GCM

