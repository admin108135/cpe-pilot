import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final AppState _app = AppState.instance;

  Timer? _timer;
  bool _busy = false;
  Map<String, String>? _signal;
  XmlDocument? _status;
  XmlDocument? _traffic;

  final TextEditingController _host = TextEditingController();
  final TextEditingController _pwd = TextEditingController();

  @override
  void initState() {
    super.initState();
    _host.text = _app.host;
    _pwd.text = _app.password;
    _app.addListener(_onAppChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_app.loggedIn) _startPolling();
    });
  }

  @override
  void dispose() {
    _app.removeListener(_onAppChanged);
    _timer?.cancel();
    _host.dispose();
    _pwd.dispose();
    super.dispose();
  }

  void _onAppChanged() {
    if (!mounted) return;
    if (_app.loggedIn && _timer == null) {
      _startPolling();
    } else if (!_app.loggedIn && _timer != null) {
      _timer?.cancel();
      _timer = null;
      _signal = null;
      _status = null;
      _traffic = null;
    }
    setState(() {});
  }

  void _startPolling() {
    _timer?.cancel();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_busy || !_app.loggedIn) return;
    _busy = true;
    try {
      final s = await _app.client.fetchSignal();
      final st = await _app.client.fetchStatus();
      final tf = await _app.client.fetchTraffic();
      if (!mounted) return;
      setState(() {
        if (s != null) _signal = s;
        if (st != null) _status = st;
        if (tf != null) _traffic = tf;
      });
    } finally {
      _busy = false;
    }
  }

  // ---- 取值辅助 -----------------------------------------------------------

  String _v(List<String> keys, {Map<String, String>? from}) {
    final m = from ?? _signal;
    if (m == null) return '';
    for (final k in keys) {
      final val = m[k];
      if (val != null && val.trim().isNotEmpty) return val.trim();
    }
    return '';
  }

  String _tag(XmlDocument? d, String name) {
    if (d == null) return '';
    final els = d.rootElement.findElements(name);
    return els.isEmpty ? '' : els.first.innerText.trim();
  }

  double? _num(String s) {
    final m = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(s);
    return m == null ? null : double.tryParse(m.group(0)!);
  }

  bool get _is5g {
    final s = _signal;
    if (s == null) return false;
    return s.containsKey('nrrsrp') || s.containsKey('nrearfcn');
  }

  String get _nrLabel {
    if (_signal == null) return '--';
    return _is5g ? '5G NR' : 'LTE';
  }

  int get _bars {
    final rsrp = _num(_v(['nrrsrp', 'rsrp']));
    if (rsrp == null) return 0;
    if (rsrp >= -85) return 5;
    if (rsrp >= -95) return 4;
    if (rsrp >= -105) return 3;
    if (rsrp >= -115) return 2;
    return 1;
  }

  double get _ringProgress {
    final rsrp = _num(_v(['nrrsrp', 'rsrp']));
    if (rsrp == null) return 0;
    return ((rsrp + 120) / 55).clamp(0.05, 1.0);
  }

  Color get _qualityColor {
    final b = _bars;
    if (b >= 4) return AppColors.success;
    if (b >= 3) return AppColors.warning;
    if (b >= 1) return AppColors.danger;
    return AppColors.textMuted;
  }

  String get _qualityText {
    final b = _bars;
    if (b >= 4) return '信号良好';
    if (b == 3) return '信号一般';
    if (b >= 1) return '信号偏弱';
    return '暂无数据';
  }

  /// "DL:636660 UL:636660" -> "636660"
  String get _arfcn {
    final raw = _v(['nrearfcn', 'earfcn']);
    final m = RegExp(r'(\d{4,6})').firstMatch(raw);
    return m?.group(1) ?? raw;
  }

  String get _cellId => _v(['cell_id']);

  /// pci 可能是十六进制（3B1），同时给出十进制
  String get _pci {
    final raw = _v(['pci']);
    if (raw.isEmpty) return '';
    final hex = int.tryParse(raw, radix: 16);
    if (hex != null && RegExp(r'^[0-9A-Fa-f]{2,4}$').hasMatch(raw)) {
      return raw.toUpperCase();
    }
    return raw;
  }

  String get _bandwidth => _v(['nrdlbandwidth', 'dlbandwidth']);

  @override
  Widget build(BuildContext context) {
    final logged = _app.loggedIn;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          children: [
            _header(),
            const SizedBox(height: 16),
            if (!logged) _loginCard() else ...[
              _signalCard(),
              const SizedBox(height: 14),
              _metricGrid(),
              const SizedBox(height: 18),
              SectionTitle('小区信息', trailing: _liveDot()),
              SoftCard(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                child: Column(children: [
                  InfoRow(label: '制式', value: _nrLabel),
                  const Divider(),
                  InfoRow(label: '频段带宽', value: _bandwidth),
                  const Divider(),
                  InfoRow(label: 'NR-ARFCN', value: _arfcn, mono: true),
                  const Divider(),
                  InfoRow(label: 'PCI', value: _pci, mono: true),
                  const Divider(),
                  InfoRow(label: 'Cell ID', value: _cellId, mono: true),
                  const Divider(),
                  InfoRow(label: 'TAC', value: _v(['tac']), mono: true),
                  const Divider(),
                  InfoRow(label: 'PLMN', value: _v(['plmn']), mono: true),
                ]),
              ),
              const SizedBox(height: 18),
              SectionTitle('流量'),
              _trafficCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: AppColors.gradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.router_rounded, color: Colors.white, size: 21),
        ),
        const SizedBox(width: 11),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('CPE 管家',
                style: TextStyle(
                    fontSize: 18.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.2)),
            const SizedBox(height: 2),
            Text(
              _app.loggedIn ? _app.host : '未连接设备',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ],
        ),
        const Spacer(),
        if (_app.loggedIn)
          Pill(
            text: _qualityText,
            color: _qualityColor,
            icon: Icons.circle,
          ),
      ],
    );
  }

  Widget _liveDot() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: _busy ? AppColors.warning : AppColors.success,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(_busy ? '同步中' : '实时',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }

  // ---- 未登录 -------------------------------------------------------------

  Widget _loginCard() {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.wifi_lock_rounded,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('连接设备',
                style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _host,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: '设备地址',
              hintText: '192.168.8.1',
              prefixIcon: Icon(Icons.lan_rounded, size: 19),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _pwd,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '管理密码',
              hintText: '路由器背面标签上的密码',
              prefixIcon: Icon(Icons.key_rounded, size: 19),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _app.loggingIn
                  ? null
                  : () async {
                      await HapticFeedback.lightImpact();
                      _app.host = _host.text.trim();
                      _app.password = _pwd.text.trim();
                      await _app.savePrefs();
                      await _app.login();
                    },
              child: Text(_app.loggingIn ? '正在登录…' : '连接'),
            ),
          ),
          if (_app.message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.09),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_app.message,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.danger)),
            ),
          ],
          const SizedBox(height: 12),
          const Text('提示：手机需先连上该 CPE 的 Wi-Fi',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  // ---- 已登录 -------------------------------------------------------------

  Widget _signalCard() {
    final rsrp = _v(['nrrsrp', 'rsrp']);
    final sinr = _v(['nrsinr', 'sinr']);
    final rsrq = _v(['nrrsrq', 'rsrq']);

    return GradientCard(
      child: Column(
        children: [
          Row(
            children: [
              Pill(
                text: _nrLabel,
                color: Colors.white,
                bg: Colors.white.withOpacity(0.20),
                icon: _is5g ? Icons.bolt_rounded : Icons.signal_cellular_alt,
              ),
              const SizedBox(width: 8),
              if (_bandwidth.isNotEmpty)
                Pill(
                  text: _bandwidth,
                  color: Colors.white,
                  bg: Colors.white.withOpacity(0.20),
                ),
              const Spacer(),
              SignalBars(level: _bars, color: Colors.white),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SignalRing(
                progress: _ringProgress,
                center: rsrp.isEmpty ? '--' : _num(rsrp)?.toStringAsFixed(0) ?? rsrp,
                subLabel: 'RSRP dBm',
                colors: const [Color(0xFF3EDC86), Color(0xFF5B9CFF)],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _darkMetric('SINR', sinr, AppColors.successBright),
                    const SizedBox(height: 12),
                    _darkMetric('RSRQ', rsrq, AppColors.warningBright),
                    const SizedBox(height: 12),
                    _darkMetricRaw('PCI', _pci, Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _darkMetric(String label, String raw, Color color) {
    final n = _num(raw);
    final value = n == null ? (raw.isEmpty ? '--' : raw) : n.toStringAsFixed(1);
    return _darkMetricRaw(label, value, color);
  }

  Widget _darkMetricRaw(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10.5,
                letterSpacing: 0.4,
                color: Colors.white.withOpacity(0.7))),
        const SizedBox(height: 2),
        Text(value.isEmpty ? '--' : value,
            style: TextStyle(
                fontSize: 20,
                height: 1.05,
                fontWeight: FontWeight.w600,
                color: color)),
      ],
    );
  }

  Widget _metricGrid() {
    final dl = _tag(_traffic, 'CurrentDownloadRate');
    final ul = _tag(_traffic, 'CurrentUploadRate');

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: MetricTile(
                label: '下行速率',
                value: _rate(dl),
                color: AppColors.primary,
              )),
              Container(width: 1, height: 34, color: AppColors.divider),
              const SizedBox(width: 14),
              Expanded(
                  child: MetricTile(
                label: '上行速率',
                value: _rate(ul),
                color: AppColors.secondary,
              )),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: MetricTile(
                label: '累计下行',
                value: _bytes(_tag(_traffic, 'TotalDownload')),
                unit: '',
                color: AppColors.textPrimary,
              )),
              const SizedBox(width: 14),
              Expanded(
                  child: MetricTile(
                label: '累计上行',
                value: _bytes(_tag(_traffic, 'TotalUpload')),
                unit: '',
                color: AppColors.textPrimary,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _trafficCard() {
    final total = _bytes(_tag(_traffic, 'TotalDownload'));
    final conn = _tag(_status, 'ConnectionStatus');
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      child: Column(children: [
        InfoRow(label: '累计下行', value: total),
        const Divider(),
        InfoRow(label: '连接状态', value: conn == '901' ? '已连接' : (conn.isEmpty ? '已连接' : '状态 $conn')),
        const Divider(),
        InfoRow(label: 'WAN IP', value: _tag(_status, 'WanIPAddress')),
        const Divider(),
        InfoRow(label: 'Wi-Fi 名称', value: _tag(_status, 'WifiUserName')),
      ]),
    );
  }

  String _rate(String raw) {
    final n = _num(raw);
    if (n == null) return '--';
    final kbps = n / 1024;
    if (kbps >= 1024) return '${(kbps / 1024).toStringAsFixed(2)} MB/s';
    if (kbps < 1) return '0 KB/s';
    return '${kbps.toStringAsFixed(kbps < 10 ? 1 : 0)} KB/s';
  }

  String _bytes(String raw) {
    final n = _num(raw);
    if (n == null) return '--';
    if (n >= 1 << 30) return '${(n / (1 << 30)).toStringAsFixed(2)} GB';
    if (n >= 1 << 20) return '${(n / (1 << 20)).toStringAsFixed(1)} MB';
    return '${(n / 1024).toStringAsFixed(0)} KB';
  }
}
