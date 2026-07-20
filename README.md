# 跟单神控 App

手机**只输入绑定码**，不显示服务器地址。

## 地址从哪来？

| 位置 | 作用 |
|------|------|
| 电脑 `gendan_remote.env` → `GENDAN_PUBLIC_URL` | **只有 exe 读取**；启动时复制到剪贴板 |
| 手机本地存储 | App 真正用来连 Relay；界面不展示 |
| 出厂默认 | `https://gendan.hyqibot.com`（可被剪贴板更新覆盖） |

换公网/局域网：**改 env → 重启 exe → 手机「从剪贴板更新服务器」→ 再绑定**。不必重编 App。

```powershell
cd app
flutter pub get
dart run flutter_launcher_icons
flutter run
```
