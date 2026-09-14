# Omni 账号、Apple 订阅与记忆服务

状态：真实 Apple 协议适配器和账户生命周期已实现，测试使用生成的 RSA/EC 密钥、合成证书和本地 HTTP 响应。尚未配置开发者密钥、部署域名、App Store Connect 产品或真实 Apple 沙盒账号，因此不能把测试通过描述为已上线。

## 账号合同

所有请求只能发往自有 HTTPS 服务，所有时间戳均为 Unix 秒。响应和错误带 `Cache-Control: no-store`；错误只包含通用 `detail`，不会回显凭据。

| 请求 | 输入 | 输出 |
| --- | --- | --- |
| `POST /v1/auth/challenge` | 无 | `challenge_id`, `nonce`, `expires_at` |
| `POST /v1/auth/apple` | `challenge_id`, `identity_token`, `authorization_code` | `account_id`, `access_token`, `refresh_token`, `expires_at` |
| `POST /v1/auth/refresh` | `refresh_token` | 同登录 |
| `POST /v1/auth/logout` | Bearer + `refresh_token` | `logged_out` |
| `GET /v1/account/session` | Bearer | `account_id`, `premium_active`, `premium_until`（秒或 null） |
| `POST /v1/account/subscription` | Bearer + `signed_transaction` | 同账号状态 |
| `DELETE /v1/account` | Bearer | `deleted`, `apple_access_revoked` |

挑战有效期 5 分钟。客户端把返回的原始 `nonce` 做 SHA-256，使用小写十六进制串设置 Apple 登录请求的 `nonce`。登录后发送 Apple 返回的 `identityToken` 和 `authorizationCode`。挑战在访问 Apple 网络前就被一次性消费，失败需重新发起。

服务只信任 Apple JWKS 中的 RSA 密钥，校验 RS256 签名、固定 issuer、准确的 bundle audience、nonce、有效期和近期签发时间。未知密钥的重新抓取最多每分钟一次；正常密钥缓存一小时。固定 Apple URL，拒绝跳转，不读取代理环境变量；网络超时 10 秒，身份响应上限 64 KiB。

`account_id` 是服务生成的 UUID。Apple subject 只以带独立用途前缀的 HMAC 映射保存，不返回客户端，不需要用户的电子邮箱或姓名。客户端不得提交自己的 owner 或 premium 值。

访问令牌有效 15 分钟且包含独立随机 ID。服务保存访问及刷新令牌的 HMAC，逐请求检查会话是否有效；不是仅验证 JWT 签名。刷新令牌为随机 48 字节，30 天绝对有效期，每次刷新必须轮换。旧刷新令牌再次使用会撤销整个设备会话，包括刚签发的新令牌；其他设备不受影响。客户端必须串行刷新，无法确认刷新结果时重新登录，不得自动重复发送旧刷新令牌。最多保留 10 个活动设备会话家族，家族最多 4,096 次刷新，过度刷新需重新登录。

## Apple 配置

以下值由部署环境提供；密钥文件、数据库和 Apple 证书均不得提交仓库：

| 环境变量 | 用途 |
| --- | --- |
| `OMNI_MEMORY_SESSION_SECRET` | 随机高熵服务密钥，至少 32 字节；身份映射、会话与 Apple 刷新令牌加密使用有用途区分的派生值 |
| `OMNI_MEMORY_DB` | 持久私有数据库路径 |
| `OMNI_APPLE_BUNDLE_ID` | 实际应用 bundle ID，须匹配 Sign in with Apple 和商店应用 |
| `OMNI_APPLE_TEAM_ID` | Apple 开发者 Team ID |
| `OMNI_APPLE_SIGNIN_KEY_ID` | 启用 Sign in with Apple 的密钥 ID |
| `OMNI_APPLE_SIGNIN_KEY_PATH` | 对应 `.p8` 私钥文件路径 |
| `OMNI_APPLE_IAP_KEY_ID` | App Store Connect 内购密钥 ID |
| `OMNI_APPLE_IAP_KEY_PATH` | 对应内购 `.p8` 私钥路径 |
| `OMNI_APPLE_ISSUER_ID` | App Store Connect API issuer ID |
| `OMNI_APPLE_ROOT_CERTIFICATES` | 从 Apple PKI 下载的根证书 DER 文件路径，按平台路径分隔符连接（Linux/macOS 是冒号） |
| `OMNI_APPLE_PLUS_PRODUCT_IDS` | 当前真实 Plus 产品 ID，逗号分隔 |
| `OMNI_APPLE_STORE_ENVIRONMENT` | 必须明确 `Sandbox` 或 `Production`；禁止 Xcode/LocalTesting 跳过验签模式 |
| `OMNI_APPLE_APP_ID` | 生产环境必填，App Store 数字 app ID |

身份验证配置不完整时，登录接口返回 503；订阅配置不完整时，订阅验证返回 503，不授予 Plus。Apple OAuth 私钥由 ES256 签发短期 client secret，用授权码换取 Apple 刷新令牌，后者通过 AES-GCM 加密保存。更换主服务密钥会使现有会话、身份映射与密文失效；上线后轮换需要明确迁移方案，不能直接替换环境变量。

## 订阅资格

StoreKit 购买必须设置 `.appAccountToken(accountID)`，提交客户端已验证交易的 `jwsRepresentation`。服务使用 Apple 官方 `app-store-server-library` 校验证书链、签名、环境与 bundle，并启用在线证书吊销检查。随后调用 Apple 当前订阅状态接口，重新验证返回的交易；仅持有历史签名交易不足以获得资格。

交易必须属于当前账号 UUID、认可的 Plus 产品和所查询的原始交易。有效活动订阅以及有匹配、未过期签名续费信息的 Billing Grace Period 可获得资格；已撤销、过期、被升级替代、单纯 billing retry 均不授予。服务返回真实截止时间，但内部付费许可最多缓存 300 秒。后续受保护请求会刷新过期的缓存，因此退款状态最多有五分钟延迟；这不是已部署的 Apple 通知 webhook。

Apple 不可用时，付费许可归零，已登录用户仍能读取、修改、删除和导出自己的数据。恢复网络后的请求可再次验证。订阅在旧应用中购买、没有正确 account token 的恢复交易会被拒绝；不能猜测归属或自动绑定到当前账号。正式开放给旧用户前需明确迁移方式。

## 删除与保存边界

登出撤销该设备会话；删除账号撤销所有会话。删除先标记账号正在删除，阻止并发登录和受保护访问，再调用 Apple revoke 接口。Apple 失败时恢复可访问状态并返回错误，不声称已删除。Apple 成功后，同一数据库事务删除身份、订阅、设备会话、对话、记忆、同步快照和账号行。应用删除账号不会替用户取消 Apple 商店订阅，界面需提供 Apple 管理订阅入口。

数据库创建权限为 0600，父目录新建为 0700，开启 SQLite secure_delete。Apple 刷新令牌有应用层加密；记忆正文依然是普通 SQLite 文本，服务器磁盘及备份加密、访问权限、备份删除周期和日志策略属于部署工作。禁止记录请求体、Authorization、签名交易、刷新令牌或身份提供方返回正文。

进程在 Apple 已撤销而本地删除事务尚未完成时崩溃，会留下 `deleting=1` 的受保护记录，普通客户端无法继续访问；上线运维需要检查和完成这类删除。当前没有后台删除恢复任务，也没有 Apple 账号状态通知接收器。主密钥或数据库损坏不能通过重置标志跳过 Apple 撤销步骤。

生产默认使用受管理账号，拒绝仅由本地 operator 签出的历史测试 JWT。`managed_accounts=False` 仅供隔离的旧测试显式使用，不是环境开关。外围反向代理还需请求速率和容量限制；应用内登录限流使用直连地址，不信任任意客户端伪造的转发头。

## 验证与资料

`tests/test_accounts.py` 覆盖真正合成 RSA 签名、Apple 官方库检查的三层 EC 证书链、篡改与错误 claims、nonce 重放、会话轮换、越权购买、到期与退款、签名宽限期、上游失败、授权码交换和撤销删除。`tests/test_account_routes.py` 通过真实 FastAPI HTTP 路由验证登录、订阅、同步、导出、删除、轮换与隔离。全部使用合成输入，没有真实付费交易、用户资料或模型调用。

协议实现参考 [Apple 登录验证](https://developer.apple.com/documentation/signinwithapple/authenticating-users-with-sign-in-with-apple)、[Apple 公钥](https://developer.apple.com/documentation/signinwithapplerestapi/fetch-apple%27s-public-key-for-verifying-token-signature)、[Apple 官方 Python 库](https://github.com/apple/app-store-server-library-python)、[当前订阅状态](https://developer.apple.com/documentation/appstoreserverapi/get-all-subscription-statuses) 和 [Billing Grace Period 截止时间](https://developer.apple.com/documentation/appstoreserverapi/graceperiodexpiresdate)。
