# Prompt Playbook for your OpenClaw (derived from Awesome-Prompts)

This document turns the ideas in <https://github.com/dongshuyan/Awesome-Prompts> into **safe, repeatable prompts** for your OpenClaw setup.

> Focus: accuracy, tool-use discipline, memory-first workflow. **We intentionally ignore “越狱破限/NSFW” content**.

---

## 0) Default operating rule (always-on)

When the user asks for anything related to prior context (projects/servers/decisions/preferences):

1) Pull latest cloud memory (best-effort)
2) `memory_search` → `memory_get`
3) Only ask questions if memory is missing/uncertain
4) After finishing: write memory → push

---

## 1) 搜索验证（中档版，日常推荐）

**Use when**: user asks factual questions, troubleshooting, comparisons.

**Prompt:**

> 你先不要直接回答。先复述我的问题（1-2 句），列出你需要确认的关键点（最多 5 条）。
> 然后：
> - 先用可用工具做信息检索/验证（给出来源链接或可复现步骤）
> - 最后再给结论（要点式），并标注不确定点
> 约束：不编造，不确定就说不确定。

---

## 2) 项目优化与施工（3 步）

### Step 1: 需求澄清 + 方案设计

> 你是资深交付负责人。先输出：目标、范围、不做什么、风险、验收标准、回滚方案。
> 如果需要信息，优先从记忆库检索；只有缺失再问我。

### Step 2: 施工计划（分阶段）

> 把方案拆成阶段，每阶段包含：改动清单、命令/文件、预期输出、验证方法、回滚点。

### Step 3: 施工执行（严格日志）

> 施工时每一步都要：做什么 → 为什么 → 结果 → 下一步。
> 完成后生成交接记录，并把关键结论写入记忆库。

---

## 3) 记忆写入（最小信息集）

**项目（project）最小必填：**
- What it is（一句话）
- Repo（如果有）
- Deployment（是否部署/在哪/怎么跑）

**服务器（infra）最小必填：**
- IP/区域/OS
- 登录方式（不放密码）
- 跑哪些项目/端口

---

## 4) 每日复盘（客观犀利版）

> 回放今天的 memory 文件：列出 3 条“纠正点”和 3 条“低效点”，每条都写成可执行规则。
> 然后给出 1 个最该改的流程/配置建议（只改 AGENTS/TOOLS/脚本，不动 SOUL）。

---

## 5) Multi-OpenClaw 同步（强约定）

**开工前**：Pull → memory_search → 执行 → 写记忆 → Push

**每小时**：cron 做 Pull+Push（best-effort），错误写入当日日志。
