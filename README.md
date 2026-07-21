# 跟单神控 App

Flutter 客户端，仓库：[hyqibot/copytrader](https://github.com/hyqibot/copytrader)。

## 地址与绑定

| 项 | 说明 |
|---|---|
| 电脑 `gendan_remote.env` → `GENDAN_PUBLIC_URL` | 仅 exe/Agent 读取；须与 App 编译 `--dart-define=GENDAN_PUBLIC_URL` 一致 |
| 手机设置 | **只填绑定码**，不显示域名/IP |
| 出厂默认 | `https://gendan.hyqibot.com` |

换公网域名：改电脑 env + CI Variables / dart-define → **重编并安装 APK**。旧版「从剪贴板更新服务器」已移除。

## 本地构建

```bash
flutter build apk --release --dart-define=GENDAN_PUBLIC_URL=https://gendan.hyqibot.com
```
