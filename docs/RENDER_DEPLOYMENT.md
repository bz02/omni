# Omni 记忆服务：Render 部署方案

核对日期：2026-09-13。本文及 `deploy/render.yaml` 是可审核的部署配置；尚未创建 Render 服务、磁盘或付费资源。代码提交 `17e855dacdc14a0f2c382d1250d59a10cf720c2b` 已通过 [GitHub Linux 容器验证](https://github.com/bz02/omni/actions/runs/34796813217)：镜像构建、94 项后端测试、非 root 启动、未授权访问及容器重建后的数据保留均通过。Render 实际部署及 Apple/模型端到端验收仍待完成。

## 费用与适用范围

美国 Oregon 区域，单个 `0.5c-512mb` Web Service 为 **$7/月**，1 GB 持久磁盘为 **$0.25/月**，基础合计 **$7.25/月**。这是持续运行的预算估算，不包含模型调用、超过工作区额度的流量/构建、域名、税或选购的工作区费用。创建资源前需要拥有者接受收费；此文件没有创建资源。[Render 官方价格](https://render.com/pricing)

新计划 ID `0.5c-512mb` 对应原 Starter，规格为 0.5 CPU、512 MB，价格不变。该配置适合少量用户的受控测试，尚未证明可承载正式生产流量。[计划 ID 对照](https://render.com/docs/compute-plans)

SQLite 需要持久磁盘。Render 的磁盘只能挂到一个服务实例，部署会短暂停机；此方案固定 1 个实例和 1 个应用 worker，不启用自动扩容。只有 `/var/data` 下的数据可在重新部署后保留。不要换成 Free 实例或把数据库改到临时路径。[持久磁盘规则](https://render.com/docs/disks)

## 仓库与创建参数

使用包含本次后端代码的 GitHub 分支，Blueprint 路径选择 **`deploy/render.yaml`**。服务的 Dockerfile 为 `backend/deploy/render/Dockerfile`，构建上下文为 `backend`；不设置另一个 `rootDir`，避免路径被二次拼接。现有 `backend/.dockerignore` 排除私钥、本地配置和数据库，镜像只复制依赖清单、`omni_memory` 和部署入口。[Blueprint 字段说明](https://render.com/docs/blueprint-spec)

蓝图禁用自动部署和预览环境，以免一次提交自动重启 SQLite 服务或创建额外资源。首次创建仍然会部署并产生费用。蓝图使用其所属仓库，并将服务分支明确设为 `codex/omni-memory-deployment`；否则 Render 的服务可能使用仅有旧网页代码的默认分支。未来合并到默认分支时应相应更新这一配置。

Render 提供服务地址和 TLS，无需先购买域名。运行后用分配的 HTTPS 根地址设置 iOS 的 `OMNI_MEMORY_API_URL`。[Render Web Service](https://render.com/docs/web-services)

## 持久化与非 root 身份

Render 在构建结束后挂载磁盘，因此镜像构建时的 `chown` 不能保证新磁盘可写。专用入口先确认 `/var/data` 确实是挂载点，只初始化 `/var/data/omni`，随后切换为 **UID 10001、GID 1000** 并禁用重新提权，再加载应用。数据库固定为 `/var/data/omni/memory.sqlite3`。应用整个请求处理期间均为非 root；镜像入口的短暂权限初始化应在首次真实容器验收中确认。

GID 1000 用于读取 Render 的 `/etc/secrets` 文件，这是 Render 对 Docker 非 root 用户的官方兼容要求。入口不会打印环境变量、读取私人文件到日志、递归修改磁盘所有权或拷贝数据库到镜像。[Docker 密钥文件权限](https://render.com/docs/docker-secrets)

## 私密配置

蓝图只生成持久的随机 `OMNI_MEMORY_SESSION_SECRET`，以及公开 bundle ID 和 `Sandbox` 环境。初次启动没有 Apple 和模型配置，登录、订阅验证及在线聊天不可用，接口不会给访客授予权限。不要用测试身份适配器、`managed_accounts=False` 或测试购买替代真实服务器验证。

在 Render 服务的 Environment 页面添加以下变量。真实值直接填入服务商私密配置，不能发送到聊天或提交仓库：

| 配置 | 应填写的内容 |
| --- | --- |
| `OMNI_APPLE_TEAM_ID`、`OMNI_APPLE_SIGNIN_KEY_ID` | Apple 登录 Team ID、Key ID |
| `OMNI_APPLE_SIGNIN_KEY_PATH` | `/etc/secrets/apple-signin.p8` |
| `OMNI_APPLE_IAP_KEY_ID`、`OMNI_APPLE_ISSUER_ID` | App Store Connect 内购 Key ID、Issuer ID |
| `OMNI_APPLE_IAP_KEY_PATH` | `/etc/secrets/apple-iap.p8` |
| `OMNI_APPLE_PLUS_PRODUCT_IDS` | 已创建且正确绑定到应用的月/年 Plus 商品 ID，逗号分隔 |
| `OMNI_RENDER_ROOT_CERTIFICATE_PEM_FILES` | 例如 `/etc/secrets/AppleRootCA-G3.pem`；多个 Apple 根证书用冒号连接 |
| `OMNI_APPLE_APP_ID` | Production 时必填的数字 App ID |
| `OPENAI_API_KEY`、`OMNI_MEMORY_MODEL` | 模型账号密钥及实际可调用的模型名；先设账号消费上限 |

Apple 的两份 `.p8` 文件放在同一页面的 Secret Files。Render 的文件输入是文本，因此 Apple 公共根证书应先在可信本地环境转换成 PEM，再存为 `.pem` secret file；不要把二进制 DER 直接粘贴进去。部署入口以非 root 身份把这些公共 PEM 转成临时 DER，并设置服务所需的 `OMNI_APPLE_ROOT_CERTIFICATES`。根证书只从 [Apple PKI](https://www.apple.com/certificateauthority/) 获取并核对来源，不使用登录、付款 SDK 自带的未知根证书。[Render Secret Files](https://render.com/docs/configure-environment-variables)

不要在 Dockerfile 中用 `ARG` 读取密钥。配置文件路径后、实际文件尚未添加时，启动会失败；先准备好变量与文件，再发起手动部署。生成的主密钥必须保留，直接更换会破坏已有账号映射、会话和加密的 Apple 刷新令牌。

## 验收与开放边界

蓝图的 `/health` 只检查进程存活，Render 用它判断服务是否开始接收流量。它不证明 Apple 密钥、商品或模型可用；一个显示健康的未配置服务仍会在登录处返回 503。[Render 健康检查](https://render.com/docs/health-checks)

收费和登录获授权后，先部署到 Sandbox，按顺序验收：持久挂载及应用 UID → HTTPS 与未授权请求 401 → 真实 Apple 登录 → 真实商店沙盒订阅 → 在线回复 → 第二台设备同步 → 服务重启后数据仍在 → 登出和删除。未经配置时 `POST /v1/auth/challenge` 返回 503 是预期行为，不应绕过。

测试令牌和 StoreKit 本地配置不构成真实 Apple 验收。切换到 Production 前需配置真实 app ID，确认 App Store 商品、账号 token 和签名环境一致，完成隐私政策与 iOS 隐私申报。

以下运营事项仍是正式公开服务的前置工作：Apple 账号状态通知、删除请求中断的恢复操作、密钥轮换迁移、模型预算和错误告警、备份删除周期。Render 提供磁盘及自动快照的静态加密，但不能据此声称记忆正文有应用层加密或账号删除会立即擦除历史备份。数据库恢复可能恢复已撤销会话/旧内容，必须有恢复后的会话撤销和删除重放步骤。

启动命令关闭访问日志，并保留不信任转发头的默认行为。Render 代理后的登录限流可能把多个用户视为同一来源；扩大测试前需按真实网络拓扑设置可信代理/边缘限制。不要简单相信任意 `X-Forwarded-For`，也不要把用户对话、令牌或交易正文接入日志采集。

[账号配置详解](../backend/README_ACCOUNTS.md) · [通用部署说明](RENDER_DEPLOYMENT.md)
