# 搜索·Elasticsearch（2 题详答）

规范 ID 范围见各题标题；原始编号已标注。

<a id="Q130"></a>

### Q130（原始编号: 46, 223）

**【题干】**
提到的 Elasticsearch（分布式搜索与分析引擎，ES），你怎么通过手机号后四位检索到加密数据？

**【核心结论】**
ES 中存盲索引字段（HMAC(后四位)）并映射为 keyword 做 term 查询；密文存另一字段不参与分词。应用查前计算同样 HMAC。不要对 AES 密文做 wildcard。

**【详细说明】**
索引设计：
- mobile_cipher：存储密文（不索引或仅存）。
- mobile_last4_idx：keyword，存 HMAC。
查询：term 查 mobile_last4_idx。合规允许时可用脱敏展示字段。

**【示例/写法】**
PUT user/_mapping { "properties": { "mobile_last4_idx": { "type": "keyword" } } }
GET user/_search { "query": { "term": { "mobile_last4_idx": "<hmac>" } } }

**【易错点】**
- 密文上 wildcard。
- 后四位明文无保护进 ES。

**【权威依据】**
- Elasticsearch mapping keyword
- 同 Q124 盲索引思路

<a id="Q131"></a>

### Q131（原始编号: 58）

**【题干】**
国产 Elasticsearch 检索技术。

**【核心结论】**
指国产化检索产品或 ES 兼容发行（如部分厂商搜索引擎/ES 发行版）。回答：协议兼容性、集群运维、与信创 OS/JDK 适配及你用过的产品名。

**【详细说明】**
说明替换原 ES 时的插件、鉴权、性能验证。避免编造不存在的产品细节。

**【示例/写法】**
POC：同样索引与查询的召回与延迟对比。

**【易错点】**
- 虚构产品能力。

**【权威依据】**
- 对应国产检索产品官方文档；Elastic 官方文档作对照

