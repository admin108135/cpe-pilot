# CPE 管家（cpe_pilot）

华为 HiLink 系 5G CPE 的安卓管理工具。视觉风格参考 CPE Ultra（`com.billy.cpeultra`）的配色体系：
浅色底 + 蓝紫渐变 + 圆角卡片 + 柔和投影。

## 功能

| 模块 | 说明 |
| --- | --- |
| 连接 | 华为 SCRAM 两步登录，自动识别 100003 会话失效；cookie/token 持久化，重启免重登 |
| 概览 | 信号环形仪表（RSRP）、SINR/RSRQ/PCI、小区信息（频段带宽、NR-ARFCN、Cell ID、TAC、PLMN）、上下行速率与累计流量 |
| 短信 | 收件箱列表、未读角标、发送、删除、标记已读、**验证码自动识别与一键复制** |
| 设置 | 网关/账号/密码、HTTPS、网络模式读写（可关闭 5G 切 4G）、设备信息、重启设备 |

## 已知限制

- **5G SA 驻网下华为 CPE 不支持收发短信**（固件层面限制，非 App 问题）。设置页提供「关闭 5G」，切 4G 后可正常收发。
- 网络模式写入使用设备当前掩码回填，仅在 NR 位上做切换；若固件拒绝会返回具体 code。
- 首次使用需手机先连上 CPE 的 Wi-Fi。

## 构建

推送后由 GitHub Actions 自动编译：

- Flutter 3.19.0 stable / Java 17 / `flutter build apk --release`
- 产物：artifact `CPE-Pilot-APK`

本地不构建，仅提交 `lib/`、`pubspec.yaml`、`AndroidManifest.xml`、`MainActivity.kt`，
CI 中由 `flutter create` 补齐平台模板后再编译。

## 目录

```
lib/
├── main.dart              入口 + 底部导航
├── theme.dart             色板与 Material3 主题
├── app_state.dart         全局连接状态
├── api/hilink.dart        HiLink 协议（SCRAM / 信号 / 短信 / 网络模式）
├── pages/                 概览、短信、设置
└── widgets/common.dart    卡片、指标块、信号环等组件
assets/icon.png            应用图标源图（1024）
tools/make_icons.py        图标切图脚本（CI 调用）
```
