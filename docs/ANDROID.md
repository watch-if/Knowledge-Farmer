# farmer Android

Android 是原生 Godot 横屏应用。正式 APK 以 `org.watchif.farmer` 和 ARM64 发布。Python 与 Lean 使用随 APK 安装的解释器与标准库，课程沿用桌面版的输入、验收与存档流程。Python 目录课程使用手机本机的回环 HTTP 服务。

## 构建

使用 Godot 4.6.3、该版本的 `android_release.apk` 模板、JDK、Android SDK 的 `build-tools;36.0.0` 和 `patchelf`。ARM64 是手机包，x86_64 是模拟器包。工具的下载缓存位于 `build/android-downloads`。

```bash
export ANDROID_SDK_ROOT=/path/to/android/sdk
export FARMER_ANDROID_TEMPLATE=/path/to/android_release.apk
tools/build-android.sh arm64-v8a build/farmer-Android-arm64.apk
```

为可安装预发行签名，需要提供 `FARMER_ANDROID_KEYSTORE` 和 `FARMER_ANDROID_PASSWORD`。模拟器验证的 `FARMER_ANDROID_SMOKE=1` 使用同一打包流程，把启动场景切换为应用内运行时冒烟验证。

## GitHub 签名

自动发布要求一个长期保存的 PKCS12 文件。用可信设备生成，密钥别名为 `farmer`，口令由拥有者安全保管。后续版本使用同一个密钥才能覆盖安装并保留手机进度。

```bash
keytool -genkeypair -storetype PKCS12 -keystore farmer-signing.p12 \
  -alias farmer -keyalg RSA -keysize 3072 -validity 10000 -dname "CN=farmer"
base64 -w0 farmer-signing.p12 | gh secret set FARMER_ANDROID_KEYSTORE_B64 -R watch-if/my-farmer
gh secret set FARMER_ANDROID_PASSWORD -R watch-if/my-farmer
```

GitHub Actions 使用仓库的两个 Actions Secrets。发布步骤检查 Windows ZIP 和 Android APK 都上传完成才公开预发行。
