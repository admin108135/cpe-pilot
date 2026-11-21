import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

import '../api/hilink.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AppState _app = AppState.instance;

  final TextEditingController _host = TextEditingController();
  final TextEditingController _user = TextEditingController();
  final TextEditingController _pwd = TextEditingController();

  XmlDocument? _device;
  NetModeInfo? _netMode;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _host.text = _app.host;
    _user.text = _app.userName;
    _pwd.text = _app.password;
    _app.addListener(_onAppChanged);
    if (_app.loggedIn) _loadInfo();
  }

  @override
  void dispose() {
    _app.removeListener(_onAppChanged);
    _host.dispose();
    _user.dispose();
    _pwd.dispose();
    super.dispose();
  }

  void _onAppChanged() {
    if (!mounted) return;
    setState(() {});
    if (_app.loggedIn && _device == null) _loadInfo();
  }

  Future<void> _loadInfo() async {
    if (_busy || !_app.loggedIn) return;
    _busy = true;
    final d = await _app.client.fetchDeviceInfo();
    final nm = await _app.client.fetchNetMode();
    if (!mounted) return;
    setState(() {
      _device = d;
      _netMode = nm;
      _busy = false;
    });
  }

  String _tag(XmlDocument? d, String name) {
    if (d == null) return '';
    final els = d.rootElement.findElements(name);
    return els.isEmpty ? '' : els.first.innerText.trim();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(2, 0, 0, 12),
            child: Text('设置',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ),
          _connectCard(),
          if (_app.loggedIn) ...[
            const SizedBox(height: 18),
            SectionTitle('网络模式', trailing: TextButton(
              onPressed: _loadInfo,
              child: const Text('刷新', style: TextStyle(fontSize: 12)),
            )),
            _netModeCard(),
            const SizedBox(height: 18),
            SectionTitle('设备信息'),
            _deviceCard(),
            const SizedBox(height: 18),
            _dangerZone(),
          ],
          const SizedBox(height: 22),
          _aboutCard(),
        ],
      ),
    );
  }

  Widget _connectCard() {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.lan_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('设备连接',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const Spacer(),
            Pill(
              text: _app.loggedIn ? '已登录' : '未登录',
              color: _app.loggedIn ? AppColors.success : AppColors.textMuted,
            ),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _host,
            keyboardType: TextInputType.url,
            enabled: !_app.loggedIn,
            decoration: const InputDecoration(labelText: '设备地址'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _user,
            enabled: !_app.loggedIn,
            decoration: const InputDecoration(labelText: '用户名'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _pwd,
            obscureText: true,
            enabled: !_app.loggedIn,
            decoration: const InputDecoration(labelText: '管理密码'),
          ),
          const SizedBox(height: 6),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _app.useHttps,
            onChanged: _app.loggedIn
                ? null
                : (v) => setState(() => _app.useHttps = v),
            title: const Text('使用 HTTPS',
                style: TextStyle(fontSize: 13.5, color: AppColors.textBody)),
            activeColor: AppColors.primary,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: _app.loggedIn
                ? OutlinedButton.icon(
                    onPressed: _app.loggingIn ? null : _app.logout,
                    icon: const Icon(Icons.logout_rounded, size: 17),
                    label: const Text('断开连接'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      foregroundColor: AppColors.textBody,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  )
                : FilledButton(
                    onPressed: _app.loggingIn
                        ? null
                        : () async {
                            FocusScope.of(context).unfocus();
                            _app.host = _host.text.trim();
                            _app.userName = _user.text.trim().isEmpty
                                ? 'admin'
                                : _user.text.trim();
                            _app.password = _pwd.text;
                            await _app.savePrefs();
                            await _app.login();
                          },
                    child: Text(_app.loggingIn ? '正在登录…' : '登录'),
                  ),
          ),
          if (_app.message.isNotEmpty && !_app.loggedIn) ...[
            const SizedBox(height: 10),
            Text(_app.message,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.danger)),
          ],
        ],
      ),
    );
  }

  Widget _netModeCard() {
    final nm = _netMode;
    final nrOn = nm != null && nm.nrMode != '00' && nm.nrMode.isNotEmpty;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      child: Column(children: [
        InfoRow(label: '当前模式', value: nm?.label ?? '--'),
        const Divider(),
        InfoRow(label: 'NetworkMode', value: nm?.networkMode ?? '--', mono: true),
        const Divider(),
        InfoRow(label: 'LTE', value: nm?.lteMode ?? '--', mono: true),
        const Divider(),
        InfoRow(label: 'NR', value: nm?.nrMode ?? '--', mono: true),
        const Divider(),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: nrOn,
          onChanged: nm == null
              ? null
              : (v) async {
                  final ok = await _app.client.setNrEnabled(v);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ok
                        ? '已提交${v ? '开启' : '关闭'} 5G，设备会短暂断网重注册'
                        : '设备拒绝：${_app.client.lastError}'),
                  ));
                  await Future.delayed(const Duration(seconds: 3));
                  _loadInfo();
                },
          title: const Text('启用 5G (NR)',
              style: TextStyle(fontSize: 14, color: AppColors.textBody)),
          subtitle: const Text('关闭后驻留 4G，可用来接收短信',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
          activeColor: AppColors.primary,
        ),
      ]),
    );
  }

  Widget _deviceCard() {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
      child: Column(children: [
        InfoRow(label: '设备名称', value: _tag(_device, 'DeviceName')),
        const Divider(),
        InfoRow(label: '软件版本', value: _tag(_device, 'SoftwareVersion'), mono: true),
        const Divider(),
        InfoRow(label: '硬件版本', value: _tag(_device, 'HardwareVersion'), mono: true),
        const Divider(),
        InfoRow(label: 'WAN IP', value: _tag(_device, 'WanIPAddress'), mono: true),
        const Divider(),
        InfoRow(label: 'MAC', value: _tag(_device, 'MacAddress1'), mono: true),
        const Divider(),
        InfoRow(label: '运行时长', value: _uptime(_tag(_device, 'Uptime'))),
      ]),
    );
  }

  String _uptime(String raw) {
    final sec = int.tryParse(raw);
    if (sec == null) return '--';
    final d = sec ~/ 86400;
    final h = (sec % 86400) ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    if (d > 0) return '$d 天 $h 小时';
    if (h > 0) return '$h 小时 $m 分';
    return '$m 分';
  }

  Widget _dangerZone() {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 6, 12, 6),
      child: Row(children: [
        const Icon(Icons.restart_alt_rounded,
            size: 19, color: AppColors.warning),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('重启设备',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              SizedBox(height: 2),
              Text('重启期间会断网 1~2 分钟',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
            ],
          ),
        ),
        TextButton(
          onPressed: _confirmReboot,
          child: const Text('重启', style: TextStyle(color: AppColors.danger)),
        ),
      ]),
    );
  }

  void _confirmReboot() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('重启设备？', style: TextStyle(fontSize: 16)),
        content: const Text('设备会断开重连，期间所有终端断网。',
            style: TextStyle(fontSize: 13.5, color: AppColors.textBody)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              await _app.client.postXml('/api/device/control',
                  '<?xml version="1.0" encoding="UTF-8"?><request><Control>1</Control></request>');
              if (!mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('已下发重启指令')));
            },
            child: const Text('重启'),
          ),
        ],
      ),
    );
  }

  Widget _aboutCard() {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: AppColors.gradient,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.router_rounded,
                  size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CPE 管家',
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                SizedBox(height: 2),
                Text('v1.0.0 · 华为 HiLink 协议',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
              ],
            ),
          ]),
          const SizedBox(height: 12),
          const Text(
            '支持华为 HiLink 系 5G CPE（含 H155 / H168 / 鼎桥 INS2 等）。'
            '短信在 5G SA 驻网下受固件限制无法收发，可关闭 5G 切到 4G 后使用。',
            style: TextStyle(
                fontSize: 12, height: 1.6, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
