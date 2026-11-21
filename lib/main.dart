import 'dart:io' as io;

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'pages/dashboard_page.dart';
import 'pages/settings_page.dart';
import 'pages/sms_page.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  io.HttpOverrides.global = _AnyCertOverrides();
  runApp(const CpePilotApp());
}

class _AnyCertOverrides extends io.HttpOverrides {
  @override
  io.HttpClient createHttpClient(io.SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (io.X509Certificate cert, String host, int port) => true;
  }
}

class CpePilotApp extends StatelessWidget {
  const CpePilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CPE 管家',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const RootShell(),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  final AppState _app = AppState.instance;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _app.loadPrefs();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _app,
      builder: (context, _) {
        return Scaffold(
          body: IndexedStack(
            index: _index,
            children: const [
              DashboardPage(),
              SmsPage(),
              SettingsPage(),
            ],
          ),
          bottomNavigationBar: _BottomBar(
            index: _index,
            unread: _app.unread,
            onTap: (i) => setState(() => _index = i),
          ),
        );
      },
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.index,
    required this.onTap,
    this.unread = 0,
  });

  final int index;
  final ValueChanged<int> onTap;
  final int unread;

  static const _items = [
    (Icons.dashboard_outlined, Icons.dashboard_rounded, '概览'),
    (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, '短信'),
    (Icons.tune_rounded, Icons.tune_rounded, '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D5399).withOpacity(0.08),
            blurRadius: 22,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: List.generate(_items.length, (i) {
              final active = i == index;
              final item = _items[i];
              final color =
                  active ? AppColors.primary : AppColors.textMuted;
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onTap(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(active ? item.$2 : item.$1,
                                size: 24, color: color),
                            if (i == 1 && unread > 0)
                              Positioned(
                                right: -8,
                                top: -5,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.gradient,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    unread > 99 ? '99+' : '$unread',
                                    style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.$3,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight:
                                active ? FontWeight.w600 : FontWeight.w500,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
