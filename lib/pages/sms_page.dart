import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/hilink.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SmsPage extends StatefulWidget {
  const SmsPage({super.key});

  @override
  State<SmsPage> createState() => _SmsPageState();
}

class _SmsPageState extends State<SmsPage> {
  final AppState _app = AppState.instance;
  List<SmsItem> _items = [];
  bool _loading = false;
  bool _loadedOnce = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _app.addListener(_onAppChanged);
    if (_app.loggedIn) _load();
  }

  @override
  void dispose() {
    _app.removeListener(_onAppChanged);
    super.dispose();
  }

  void _onAppChanged() {
    if (!mounted) return;
    setState(() {});
    if (_app.loggedIn && !_loadedOnce) _load();
  }

  Future<void> _load() async {
    if (!_app.loggedIn || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final list = await _app.client.fetchSmsList(count: 30);
    final count = await _app.client.fetchSmsCount();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _loadedOnce = true;
      if (list == null) {
        _error = '短信接口无响应·去「抓包」页点「探测短信」看原始返回';
      } else {
        _items = list;
        _error = null;
      }
      if (count != null) _app.unread = count['localUnread'] ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 16, 8),
            child: Row(
              children: [
                const Text('短信',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(width: 8),
                if (_app.unread > 0)
                  Pill(
                    text: '${_app.unread} 条未读',
                    color: AppColors.danger,
                  ),
                const Spacer(),
                if (_app.loggedIn)
                  IconButton(
                    onPressed: _openCompose,
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: '发送短信',
                    color: AppColors.primary,
                  ),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (!_app.loggedIn) {
      return const _Hint(
        icon: Icons.link_off_rounded,
        title: '尚未连接设备',
        desc: '先到「设置」填写设备地址与管理密码并登录',
      );
    }
    if (_loading && !_loadedOnce) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return _Hint(
        icon: Icons.sms_failed_rounded,
        title: '读不到短信',
        desc: '$_error\n\n如果网页后台有短信菜单但一直空白，通常是 5G SA 驻网导致：\n华为 CPE 在 SA 下不支持收发短信，切到 4G 再试。',
        action: TextButton(onPressed: _load, child: const Text('重试')),
      );
    }
    if (_items.isEmpty) {
      return _Hint(
        icon: Icons.mark_chat_unread_outlined,
        title: '收件箱是空的',
        desc: '下拉可刷新。若手机能收到、这里始终为空，说明固件没有实现短信接收。',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final m = _items[i];
          return SoftCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            onTap: () => _openDetail(m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (!m.read)
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(right: 7),
                        decoration: BoxDecoration(
                          gradient: AppColors.gradient,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    Text(
                      m.phone.isEmpty ? '未知号码' : m.phone,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            m.read ? FontWeight.w500 : FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(_shortDate(m.date),
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  m.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13.2, height: 1.5, color: AppColors.textBody),
                ),
                if (m.code != null) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    Pill(
                      text: '验证码 ${m.code}',
                      color: AppColors.primary,
                      icon: Icons.key_rounded,
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => _copy(m.code!),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('复制', style: TextStyle(fontSize: 12)),
                    ),
                  ]),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  String _shortDate(String d) {
    if (d.length >= 16) return d.substring(5, 16);
    return d;
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已复制 $text'), duration: const Duration(seconds: 2)),
    );
  }

  void _openDetail(SmsItem m) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.card,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
          ),
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: Text(m.phone.isEmpty ? '未知号码' : m.phone,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                ),
                Text(m.date,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textMuted)),
              ]),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.42),
                child: SingleChildScrollView(
                  child: Text(m.content,
                      style: const TextStyle(
                          fontSize: 14.5,
                          height: 1.6,
                          color: AppColors.textBody)),
                ),
              ),
              const SizedBox(height: 18),
              Row(children: [
                if (m.code != null)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _copy(m.code!);
                      },
                      icon: const Icon(Icons.copy_rounded, size: 17),
                      label: Text('复制验证码 ${m.code}'),
                    ),
                  )
                else
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _copy(m.content);
                      },
                      icon: const Icon(Icons.copy_rounded, size: 17),
                      label: const Text('复制内容'),
                    ),
                  ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _app.client.deleteSms(m.index);
                    await _load();
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: AppColors.danger,
                  tooltip: '删除',
                ),
              ]),
            ],
          ),
        );
      },
    );

    if (!m.read) {
      _app.client.markRead(m.index).then((_) => _load());
    }
  }

  void _openCompose() {
    final phone = TextEditingController();
    final content = TextEditingController();
    bool sending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppRadius.sheet)),
              ),
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('发送短信',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: '收件号码', hintText: '例如 10010'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: content,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        labelText: '内容', hintText: '短信正文'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: sending
                          ? null
                          : () async {
                              setLocal(() => sending = true);
                              final err = await _app.client.sendSms(
                                  phone.text.trim(), content.text);
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(err == null
                                      ? '已提交发送'
                                      : '$err（SA 驻网下通常发不出去，可切 4G 再试）'),
                                ),
                              );
                              _load();
                            },
                      child: Text(sending ? '发送中…' : '发送'),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({
    required this.icon,
    required this.title,
    required this.desc,
    this.action,
  });

  final IconData icon;
  final String title;
  final String desc;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
                boxShadow: softShadow(),
              ),
              child: Icon(icon, size: 30, color: AppColors.textMuted),
            ),
            const SizedBox(height: 18),
            Text(title,
                style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(desc,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12.5, height: 1.6, color: AppColors.textMuted)),
            if (action != null) ...[const SizedBox(height: 10), action!],
          ],
        ),
      ),
    );
  }
}
