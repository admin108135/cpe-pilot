import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/hilink.dart';

/// 全局状态：设备连接、登录态、消息提示
class AppState extends ChangeNotifier {
  static final AppState instance = AppState._();
  AppState._();

  final CpeClient client = CpeClient(host: '192.168.8.1');

  String host = '192.168.8.1';
  String userName = 'admin';
  String password = '';
  bool useHttps = false;

  bool prefsLoaded = false;
  bool loggingIn = false;
  String message = '';
  int unread = 0;

  bool get loggedIn => client.loggedIn;

  Future<void> loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    host = prefs.getString('cpe_host') ?? '192.168.8.1';
    userName = prefs.getString('cpe_user') ?? 'admin';
    password = prefs.getString('cpe_password') ?? '';
    useHttps = prefs.getBool('cpe_https') ?? false;
    client.host = host;
    client.useHttps = useHttps;
    client.cookie = prefs.getString('cpe_cookie') ?? '';
    client.token = prefs.getString('cpe_token') ?? '';
    prefsLoaded = true;
    notifyListeners();

    if (password.isNotEmpty) {
      // 静默尝试恢复登录，失败不打扰用户
      final ok = await _doLogin(silent: true);
      if (ok) notifyListeners();
    }
  }

  Future<void> savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cpe_host', host);
    await prefs.setString('cpe_user', userName);
    await prefs.setString('cpe_password', password);
    await prefs.setBool('cpe_https', useHttps);
  }

  Future<void> persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cpe_cookie', client.cookie);
    await prefs.setString('cpe_token', client.token);
  }

  Future<bool> _doLogin({bool silent = false}) async {
    client.host = host.trim();
    client.useHttps = useHttps;
    loggingIn = true;
    if (!silent) notifyListeners();

    final ok = await client.login(userName.trim(), password);
    loggingIn = false;
    if (ok) {
      message = '';
      await persistSession();
    } else {
      message = client.lastError.isEmpty ? '登录失败' : client.lastError;
    }
    notifyListeners();
    return ok;
  }

  Future<bool> login() => _doLogin();

  Future<void> logout() async {
    client.loggedIn = false;
    client.cookie = '';
    client.token = '';
    unread = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cpe_cookie');
    await prefs.remove('cpe_token');
    notifyListeners();
  }

  Future<void> refreshUnread() async {
    if (!loggedIn) return;
    final c = await client.fetchSmsCount();
    if (c != null) {
      unread = c['localUnread'] ?? 0;
      notifyListeners();
    }
  }

  void setMessage(String s) {
    message = s;
    notifyListeners();
  }

  void clearMessage() {
    if (message.isEmpty) return;
    message = '';
    notifyListeners();
  }
}
