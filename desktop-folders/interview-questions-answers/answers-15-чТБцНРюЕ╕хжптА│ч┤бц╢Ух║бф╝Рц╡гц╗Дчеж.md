# 设计模式与工作流（2 题详答）

规范 ID 范围见各题标题；原始编号已标注。

<a id="Q139"></a>

### Q139（原始编号: 71, 207）

**【题干】**
Activiti 工作流。

**【核心结论】**
Activiti 是 BPMN 工作流引擎：流程定义、部署、实例、任务、监听器。用于审批流等。注意版本（Activiti 7/迁移 Flowable）。

**【详细说明】**
核心表 ACT_*；Service：Repository/Runtime/Task/History。嵌入 Spring 或独立。

**【示例/写法】**
deploy bpmn → startProcessInstanceByKey → complete task。

**【易错点】**
- 把业务状态只放引擎不落业务表。

**【权威依据】**
- Activiti 用户指南；BPMN 2.0

<a id="Q140"></a>

### Q140（原始编号: 95, 104, 205）

**【题干】**
策略模式的概念，以及它和工厂模式的区别。

**【核心结论】**
策略：封装可互换算法，上下文持有策略接口，运行时切换行为。工厂：封装对象创建。策略侧重行为变化，工厂侧重创建解耦；常组合使用。

**【详细说明】**
策略消除大量 if-else 分支；工厂按类型 new 实现。

**【示例/写法】**
PayStrategy alipay/wechat; PayFactory.get(type).pay();

**【易错点】**
- 把二者说成同一种模式。

**【权威依据】**
- GoF《设计模式》Strategy / Factory Method

