# EasyTier 2.6.4.2

## 主要修复与改动

- 修复 STUN CLI 输出：正确报告 UDP STUN 结果，不再要求同时存在 TCP STUN 结果。
- 合并上游 EasyTier main 的功能更新，包括 Web 会话路由隔离、WASM 配置生成器、ACL TOML 配置、凭据与策略同步、WireGuard 门户多客户端支持及热更新。
- 改进 smoltcp/listener、连接存活检测、非对称连接恢复、STUN/TCP STUN 和 CLI 代理网段输出。
- 修复 Android VPN 状态同步、Windows 启动超时，以及 macOS/OHOS 相关兼容性问题。
- 改进 Android 构建脚本和 NDK/API 配置，修复 Windows Action 参数转义问题。

## 构建产物

- Linux、Windows 和 Android 四种 ABI 由 `releases/2.6.4.2` 构建。
- 本次 fork release 不构建 macOS 产物。
