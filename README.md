# 跟单神控 App

```powershell
cd app
flutter create . --project-name gendan_shenkong --platforms=android
# 若提示覆盖，保留已有 lib/ 与 pubspec.yaml
flutter pub get
flutter run
```

首次 `flutter create` 会生成 `android/`；请在 `AndroidManifest.xml` 增加：

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

并用 `wx2.ico` 配置应用图标。
