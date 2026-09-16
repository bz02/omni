# Omni 云端 iOS 发布验证

核实日期：2026-09-16。工作流：[ios-verify.yml](../.github/workflows/ios-verify.yml)。

**当前状态：原生分支已公开推送，第四轮云端验证全部通过：归档、57 项单元测试、6 项 UI 测试成功。尚未使用 Apple 分发签名、上传 TestFlight 或提交 App Store。**

此工作流使用 GitHub 的 macOS ARM64 runner，以 Xcode 26.3 / iOS 26.2 SDK 构建原生 iOS app、运行所有单元测试及三套核心用户流程。它不使用 Apple 分发签名，不上传 TestFlight，也不提交 App Store。实际结果以对应提交的 GitHub Actions 运行记录为准，不能把通过归档等同于已发布。

## 已完成的云端运行

| 运行 / 提交 | 实际结果 |
| --- | --- |
| [第一轮 35069032372](https://github.com/bz02/omni/actions/runs/35069032372) / `95863e2` | 归档通过。预置模拟器迁移失败未被旧脚本识别，随后小写 UDID 无法匹配 Xcode 目标；两类测试均未实际执行。 |
| [第二轮 35070781427](https://github.com/bz02/omni/actions/runs/35070781427) / `7ec9c88` | 归档通过。保留原始 UDID 并增加启动检查后，正确在预置模拟器迁移失败时停止；单元和 UI 测试均跳过。 |
| [第三轮 35071429207](https://github.com/bz02/omni/actions/runs/35071429207) / `4790a29` | 归档、新建 iPhone 17 / iOS 26.2 模拟器启动与响应检查、57 项单元测试（10 套，含 4 项真实本地 StoreKit 生命周期）通过。UI 共 6 项，Clarity 3 项及 Memory 2 项通过；Account 1 项失败。专属模拟器清理成功。 |
| [第四轮 35121560176](https://github.com/bz02/omni/actions/runs/35121560176) / `2618e44` | 全部通过：无签名归档、全新模拟器准备、57 项单元测试（含 4 项 StoreKit 生命周期）及 6 项 UI 测试。Account 1 项、Clarity 3 项、Memory 2 项均成功；清理成功。 |

第三轮 Account 流程在日记输入前未取得键盘焦点。修复仅补充键盘和焦点工具栏等待，以及完整输入值断言；没有删除业务检查。第四轮已实际完成账号错误恢复、日记保存与重启持久化、未登录时禁止未绑定购买的完整流程。总运行时间 13 分 56 秒。

## 启动范围

- 只有 `codex/omni-ios-release` 分支的原生路径变动会触发 push 验证：`Omni/`、项目文件/共享 scheme、`OmniTests/`、`OmniUITests/`、`Configuration/` 和这一个 workflow。
- 同时提供 `workflow_dispatch` 手动触发；job 仍只允许该发布分支。
- 网站和后端路径的独立变动不触发这条 iOS workflow。没有 PR 或定时触发器。
- 同分支的新运行会取消旧运行，避免同时重复构建。

首次可通过推送这个分支启动；手动运行入口需要工作流先存在于仓库默认分支。这不是要求为了首次验证先合并代码。[GitHub 手动触发说明](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)

## 实际验证

| 步骤 | 范围 |
| --- | --- |
| 工具链 | 验证 ARM64、明确 Xcode 26.3、iOS 26.2 SDK；核对三个 StoreKit fixture |
| 无分发签名归档 | Release、通用 iOS 设备、独立 DerivedData；禁用证书及 provisioning 操作 |
| 所有单元测试 | 完整 `OmniTests`，包括本地 Apple StoreKit 生命周期、账号、记忆、同步与网络边界测试 |
| 三套用户流程 | `ClarityJourneyTests`、`MemoryJourneyTests`、`AccountJourneyTests`；每个测试使用独立虚构资料 |
| 结果摘要 | GitHub 日志与 step summary 显示各步骤成功或失败 |

选择已安装、与 SDK 兼容的 iOS 26 运行时，并为每次运行新建专属 iPhone 17 模拟器，避免复用 runner 预置设备的迁移状态。保留原始 UDID，检查启动迁移、Booted 状态、实际命令响应及 Xcode 中完全匹配的 ARM64 目标；结束后只关闭并删除本次创建的设备，失败启动也会清理。不写死设备 UUID；缺少所需工具链或运行时时直接失败，不降级到旧 SDK。所有 StoreKit 测试串行运行，使用本地 fixture，不产生真实购买。

本次配置**不打包或上传 artifact，不上传缓存**。归档、`.xcresult` 和截图附件只临时存在于 runner，随该运行环境清理；不提供持久化下载文件。GitHub 保留正常运行日志和 step summary。任务设置 60 分钟上限，归档和两类测试各自还有步骤上限。

这避免新增 artifact/cache 存储，不等同于承诺 GitHub 的计算永远免费。仓库账户自身的 Actions 额度和计费规则仍适用。

## 已核对的官方环境

GitHub 官方标签表将 `macos-26` 映射到 ARM64；2026-09-16 查看镜像版本 `20260907.0351.1`，其中仍有 `/Applications/Xcode_26.3.app`、对应 iOS / iPhone Simulator 26.2 SDK，以及 iOS 26.2 iPhone 运行时。无需改成浮动的默认 Xcode。[官方标签表](https://github.com/actions/runner-images/blob/main/README.md)、[macOS 26 ARM64 软件清单](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md)

唯一外部 Action 是 `actions/checkout` v7.0.1，固定完整提交 `3d3c42e5aac5ba805825da76410c181273ba90b1`。权限只有 `contents: read`，不在 checkout 中保留 Git 凭据。[官方 release](https://github.com/actions/checkout/releases/tag/v7.0.1)

镜像会更新。若指定版本被删除，需要重新核对官方清单后明确改版，不能用旧 SDK 通过结果代替当前发布验证。

## 发布边界

工作流生成的是未使用 Apple 分发签名的归档，不能直接安装或提交。代码检查和模拟器通过之后，还需要完成真实隐私/支持网址、线上服务配置、App Store Connect 商品及 Apple 签名，才能生成和上传正式构建。

App Store 已注册 `omni.ai.Omni`、团队 `MGFX73F82F` 和应用记录 `6812658396`；月度商品已创建但未开售，年度商品仍需完成。测试配置中的月/年价格不代表已开售价格。当前原生工程的隐私、支持及服务地址默认留空；只复制源代码不会自动启用真实付费或聊天服务。发布前应通过对应的 build settings 注入已核实地址，不能将服务私钥或 Apple 私钥写入源码。
