import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/hilink.dart';
import '../app_state.dart';
import '../theme.dart';

/// 报文抓包页：记录 App 发出的每条请求与设备的原始返回，可复制导出
class CapturePage extends StatefulWidget {
  const CapturePage({super.key});

  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage> {
  final AppState _app = AppState.instance;
  Timer? _ticker;
  int _count = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _count = _app.client.captures.length;
    _ticker = Timer.periodic(const Duration(milliseconds: 700), (_) {
      final n = _app.client.captures.length;
      if (mounted && n != _count) setState(() => _count = n);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() job) async {
    setState(() => _busy = true);
    await job();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _count = _app.client.captures.length;
    });
  }

  void _copyAll() {
    Clipboard.setData(ClipboardData(text: _app.client.captureText));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('全部报文已复制')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final caps = _app.client.captures.reversed.toList();
    final empty = caps.isEmpty;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('报文抓包',
                          style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.2)),
                      const SizedBox(height: 2),
                      Text(
                        '共 $_count 条 · 记录每条请求与原始返回',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                _Toggle(
                  value: _app.client.captureOn,
                  onChanged: (v) => setState(() => _app.client.captureOn = v),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Row(
              children: [
                _ActionChip(
                  icon: Icons.radar_rounded,
                  label: '探测接口',
                  onTap: _busy ? null : () => _run(_app.client.probeEndpoints),
                ),
                _ActionChip(
                  icon: Icons.sms_outlined,
                  label: '探测短信',
                  onTap: _busy ? null : () => _run(_app.client.probeSms),
                ),
                _ActionChip(
                  icon: Icons.copy_all_rounded,
                  label: '复制',
                  onTap: empty ? null : _copyAll,
                ),
                _ActionChip(
                  icon: Icons.delete_outline_rounded,
                  label: '清空',
                  onTap: empty
                      ? null
                      : () => setState(() {
                            _app.client.clearCaptures();
                            _count = 0;
                          }),
                ),
              ],
            ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 2),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          Expanded(
            child: empty
                ? _emptyView()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                    itemCount: caps.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _CaptureTile(cap: caps[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.bgAlt,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  size: 30, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            const Text('还没有捕获到报文',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            const Text(
              '去概览页连一次设备，或点上面的「探测接口」\n请求会实时出现在这里',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, height: 1.6, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value ? '记录中' : '已暂停',
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: value ? AppColors.primary : AppColors.textMuted)),
        const SizedBox(width: 4),
        Transform.scale(
          scale: 0.78,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: enabled ? AppColors.card : AppColors.bgAlt,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Column(
                children: [
                  Icon(icon,
                      size: 17,
                      color: enabled ? AppColors.primary : AppColors.textMuted),
                  const SizedBox(height: 3),
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: enabled
                              ? AppColors.textSecondary
                              : AppColors.textMuted)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CaptureTile extends StatefulWidget {
  const _CaptureTile({required this.cap});

  final HttpCapture cap;

  @override
  State<_CaptureTile> createState() => _CaptureTileState();
}

class _CaptureTileState extends State<_CaptureTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.cap;
    final isPost = c.method == 'POST';
    final accent = isPost ? AppColors.secondary : AppColors.primary;
    final statusColor = c.ok ? AppColors.success : AppColors.danger;

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.11),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(c.method,
                        style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: accent)),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      c.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(c.statusLabel,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: statusColor)),
                  const SizedBox(width: 6),
                  Text('${c.ms}ms',
                      style: const TextStyle(
                          fontSize: 10.5, color: AppColors.textMuted)),
                  Icon(_open ? Icons.expand_less : Icons.expand_more,
                      size: 16, color: AppColors.textMuted),
                ],
              ),
              if (c.error.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(c.error,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.danger)),
              ],
              if (_open) ...[
                if (c.reqBody.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _block('请求', c.reqBody, AppColors.textMuted),
                ],
                if (c.respBody.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _block('响应', c.respBody, AppColors.textBody),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: c.dump()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('这条已复制')),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 13),
                    label: const Text('复制这条',
                        style: TextStyle(fontSize: 11.5)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _block(String title, String text, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted)),
        const SizedBox(height: 3),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 220),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(9),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              text,
              style: TextStyle(
                fontSize: 11,
                height: 1.45,
                color: color,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
