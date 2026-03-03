# OpenClaw 云端记忆库（七牛云 S3）方案说明

> 目标：让多个 OpenClaw 实例共享同一份“云端记忆库”（项目/服务器/决策/偏好），**每次执行任务前先本地检索**，同时支持从七牛云 **拉取记忆** 来丰富本地知识库，避免上下文压缩导致丢信息。

## 1. 总体设计（Local-first + Cloud Sync）

- **本地为准（source of truth）**：OpenClaw 每次工作时首先使用本地文件进行 `memory_search` / `memory_get`。
- **七牛云做持久化与跨实例同步**：把本地 `MEMORY.md` 与 `memory/` 目录同步到七牛云（对象存储）。
- **必须支持 Pull**：在新机器/新实例启动或开始工作前，先从七牛云拉取最新记忆到本地，再进行记忆检索。

这保证：
- 单机/单会话稳定快速
- 多实例共享一致知识
- 重启/迁移后可恢复

## 2. 目录结构（强约定）

OpenClaw workspace 根目录下：

- `MEMORY.md`：长期、结构化索引（项目清单、服务器清单、关键决策）
- `memory/YYYY-MM-DD.md`：每日流水与复盘
- `memory/projects/*.md`：项目档案（一个项目一个文件）
- `memory/infra/*.md`：服务器/基础设施档案（一个主机一个文件）

## 3. 七牛云对象存储布局

- bucket：`yoominic-openclaw`
- prefix：`clawX/`

最终对象路径示例：
- `clawX/MEMORY.md`
- `clawX/memory/2026-03-03.md`
- `clawX/memory/projects/yoominic-memory.md`

## 4. 鉴权与安全（非常重要）

⚠️ **不要在聊天中发送 AK/SK**。建议：

- 在每台机器上通过环境变量/系统环境变量配置：
  - `QINIU_AK`
  - `QINIU_SK`
- 使用**最小权限**（仅允许该 bucket + 仅允许 `clawX/` 前缀更佳）
- 如果 AK/SK 泄露：立即在七牛后台重置。

## 5. 同步工具选择：S3-compatible + AWS CLI（方案 B）

本实现使用七牛 S3 兼容 endpoint：

- endpoint: `https://yoominic-openclaw.s3.cn-south-1.qiniucs.com`

并通过 AWS CLI 完成上传/下载。

### 5.1 安装 AWS CLI v2

Windows 安装包：<https://awscli.amazonaws.com/AWSCLIV2.msi>

验证：

```powershell
& 'C:\Program Files\Amazon\AWSCLIV2\aws.exe' --version
```

### 5.2 配置密钥（在机器本地）

推荐用 setx 写入用户环境变量（重启 OpenClaw/ClawX 后生效）：

```powershell
setx QINIU_AK "<YOUR_AK>"
setx QINIU_SK "<YOUR_SK>"
```

> 说明：`setx` 不会影响已经运行的进程，需重启 OpenClaw/ClawX 或重新登录。

## 6. 同步脚本（Push / Pull）

脚本位置：
- `skills/cloud-memory/scripts/cloud-memory-s3-push.ps1`
- `skills/cloud-memory/scripts/cloud-memory-s3-pull.ps1`

配置文件：
- `skills/cloud-memory/scripts/cloud-memory-s3.config.json`

### 6.1 Pull（云端 → 本地）【关键】

每个 OpenClaw 实例在“开始干活前”建议先执行：

```powershell
powershell -ExecutionPolicy Bypass -File skills\cloud-memory\scripts\cloud-memory-s3-pull.ps1
```

用途：
- 新实例第一次启动时拉取云端记忆
- 多实例协作时，先拉最新，避免用旧知识做决策

### 6.2 Push（本地 → 云端）

每次写入/更新记忆后执行：

```powershell
powershell -ExecutionPolicy Bypass -File skills\cloud-memory\scripts\cloud-memory-s3-push.ps1
```

## 7. 多 OpenClaw 实例同步策略（推荐流程）

### 7.1 每次工作前（Pull → Search → Act）

1) Pull 最新记忆
2) 再执行 `memory_search` / `memory_get`
3) 开始部署/排障/操作

### 7.2 每次写入记忆后（Push）

- 更新 `MEMORY.md` / `memory/*`
- 立即 Push

### 7.3 冲突处理（现实一定会发生）

对象存储是“最后写入覆盖”，因此建议：
- 尽量让 `MEMORY.md` 保持“索引/结论”，减少频繁改同一段
- 每个实例多写入各自的 `memory/YYYY-MM-DD.md`，避免互相覆盖
- 真要多人并发编辑同一个文件：建议迁移到 Git 作为主同步层（或引入锁/合并策略）

## 8. 每日复盘（可选但强烈推荐）

脚本：`skills/cloud-memory/scripts/daily-review.ps1`

它会：
- 先 best-effort 同步到七牛（失败也继续复盘）
- 检测模板未补全、索引缺失、坏链、重复引用
- 输出三段式简报：同步 / 复盘 / 建议

运行：

```powershell
powershell -ExecutionPolicy Bypass -File skills\cloud-memory\scripts\daily-review.ps1
```

## 9. 如何把这份方案用于你的 GitHub

建议把以下内容提交到你的仓库：
- `skills/cloud-memory/**`
- `docs/cloud-memory-qiniu.md`

然后每台机器拉取仓库后即可使用同一套脚本与规范。

---

## 附：你当前这套配置的关键参数

- bucket: `yoominic-openclaw`
- prefix: `clawX`
- endpoint: `https://yoominic-openclaw.s3.cn-south-1.qiniucs.com`
