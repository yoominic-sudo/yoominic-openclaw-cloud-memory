# 记忆系统优化（参考 linux.do 1621623「OpenClaw 终极记忆系统」）

本文把帖子里的关键思想，落地到我们当前的 **cloud-memory + 七牛 S3** 方案中。

> 我们保留：幂等、信号过滤、长期记忆硬上限、复盘/整理流水线。
> 我们不照搬：qmd（你当前没用它）。我们用纯文件 + OpenClaw 工具链实现。

---

## 1) 我们当前方案现状

- 记忆载体：`MEMORY.md` + `memory/**`（projects/infra/daily）
- 云端同步：七牛 S3（Pull/Pull），并有每小时 cron 维持同步
- 复盘：`daily-review.ps1`（可跑，能检查缺项/坏链/重复）

缺口：
- 目前缺少“从会话自动抽取记忆点”的 **memory-sync**（帖子里的 Job1）
- 目前缺少“周度压缩 + 长期蒸馏”的 **memory-tidy**（帖子里的 Job2）
- MEMORY.md 没有硬限制机制（只是建议）

---

## 2) 关键优化点（从帖子学到的）

### A. 幂等性（Idempotency）
- 用 `sessionId` 的前 8 位作为去重键，写入 daily 里
- 再次运行时，如果已经存在同一 `session:XXXXXXXX` 就跳过

### B. 信号过滤（减少噪音）
- 跳过 < 2 条用户消息的会话（或总消息太少）
- 跳过 isolated 会话

### C. 长期记忆硬上限
- `MEMORY.md` 推荐硬上限：**80 行 / 5KB**
- 超出就先压缩/合并再添加（否则长期记忆会失效）

### D. 两个 cron job 的流水线
1) **memory-sync**：把“最近几小时的会话”压缩进当天 `memory/YYYY-MM-DD.md`
2) **memory-tidy**：把旧 daily 压成 weekly，再蒸馏进 MEMORY.md，再归档

---

## 3) 我们的落地实现（不依赖 qmd）

### 3.1 新增目录
- `memory/weekly/`
- `memory/archive/`

### 3.2 Cron Job：memory-sync（建议 4 次/天）

目标：自动从最近 4 小时会话里抽取“可复用结论”，写入今日 daily 文件。

关键规则：
- sessions_list 取最近 4 小时
- 跳过 isolated
- 跳过用户消息 < 2
- 幂等：如果 daily 文件里已出现 `session:XXXXXXXX` 就跳过

> 注：这一步不会改 MEMORY.md，只写 daily（更安全）。

### 3.3 Cron Job：memory-tidy（每天凌晨）

目标：
- 把 >7 天的 daily 汇总到 weekly
- 从最近 7 天 daily + MEMORY.md 提炼“长期有效”的条目
- 强制 4 条准入条件：
  1) 不写会导致未来犯具体错误
  2) 对未来多次对话有用
  3) 自包含、可理解
  4) 不重复
- 写前备份：`memory/archive/MEMORY.md.bak-YYYY-MM-DD`
- 超 80 行必须先压缩

---

## 4) 多 OpenClaw 同步（你最关注的点）

强约定：
- **开工前**：Pull → memory_search → 执行 → 写记忆 → Push
- **后台维护**：cron 每小时 Pull/Push，保证多实例一致
- **会话沉淀**：memory-sync 把“对话里出现但没写入文件”的关键信息补落盘
- **长期维护**：memory-tidy 控制 MEMORY.md 膨胀，保持可用

---

## 5) 下一步（我建议你批准我执行的变更）

1) 在 OpenClaw cron 里新增：
   - `memory-sync`（每 4 小时）
   - `memory-tidy`（每天 03:00）
2) 先以“仅写 daily + 仅生成周报 + 仅在满足条件时更新 MEMORY.md”的严格模式运行 1 周

