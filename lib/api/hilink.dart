import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

// ---------------------------------------------------------------------------
// 工具函数
// ---------------------------------------------------------------------------

List<int> hexDecode(String hex) {
  final clean = hex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  final even = clean.length.isEven ? clean : '0$clean';
  return List.generate(
      even.length ~/ 2, (i) => int.parse(even.substring(i * 2, i * 2 + 2), radix: 16));
}

String hexEncode(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

String randomNonce([int len = 64]) {
  final r = math.Random.secure();
  const chars = '0123456789abcdef';
  return List.generate(len, (_) => chars[r.nextInt(16)]).join();
}

/// PBKDF2-HMAC-SHA256（手写，避免高层 API 版本差异）
List<int> pbkdf2HmacSha256(
    List<int> password, List<int> salt, int iterations, int dkLen) {
  const hashLen = 32;
  final blocks = (dkLen / hashLen).ceil();
  final out = <int>[];
  for (var block = 1; block <= blocks; block++) {
    final msg = <int>[
      ...salt,
      (block >> 24) & 255,
      (block >> 16) & 255,
      (block >> 8) & 255,
      block & 255,
    ];
    var u = Hmac(sha256, password).convert(msg).bytes;
    var t = List<int>.from(u);
    for (var i = 1; i < iterations; i++) {
      u = Hmac(sha256, password).convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    out.addAll(t);
  }
  return out.sublist(0, dkLen);
}

/// 华为 SCRAM-SHA256 变体：注意 HMAC 的 key/data 顺序与 RFC 相反
String computeClientProof(String password, String saltHex, int iterations,
    String firstNonce, String serverNonce,
    {bool variant = false}) {
  final salted = pbkdf2HmacSha256(
      utf8.encode(password), hexDecode(saltHex), iterations, 32);
  final authMessage = '$firstNonce,$serverNonce,$serverNonce';

  List<int> clientKey;
  List<int> signature;
  if (variant) {
    // 旧写法（key/msg 顺序相反），仅用于兼容其它固件
    clientKey = Hmac(sha256, utf8.encode('Client Key')).convert(salted).bytes;
    final storedKey = sha256.convert(clientKey).bytes;
    signature = Hmac(sha256, utf8.encode(authMessage)).convert(storedKey).bytes;
  } else {
    // 标准 SCRAM-SHA256（与 cpeultra 一致）
    clientKey = Hmac(sha256, salted).convert(utf8.encode('Client Key')).bytes;
    final storedKey = sha256.convert(clientKey).bytes;
    signature = Hmac(sha256, storedKey).convert(utf8.encode(authMessage)).bytes;
  }
  final proof =
      List<int>.generate(clientKey.length, (i) => clientKey[i] ^ signature[i]);
  return hexEncode(proof);
}

/// 服务器签名，用于校验对端身份（参考实现同款）
String computeServerSignature(String password, String saltHex, int iterations,
    String firstNonce, String serverNonce) {
  final salted = pbkdf2HmacSha256(
      utf8.encode(password), hexDecode(saltHex), iterations, 32);
  final authMessage = '$firstNonce,$serverNonce,$serverNonce';
  final serverKey =
      Hmac(sha256, salted).convert(utf8.encode('Server Key')).bytes;
  return hexEncode(
      Hmac(sha256, serverKey).convert(utf8.encode(authMessage)).bytes);
}

String escXml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

String? tagOf(XmlDocument? doc, String name) {
  if (doc == null) return null;
  final els = doc.rootElement.findElements(name);
  if (els.isEmpty) return null;
  return els.first.innerText.trim();
}

XmlDocument? tryParseXml(String s) {
  try {
    return XmlDocument.parse(s);
  } catch (_) {
    return null;
  }
}

// ---------------------------------------------------------------------------
// 数据模型
// ---------------------------------------------------------------------------

class SmsItem {
  final String index;
  final String phone;
  final String content;
  final String date;
  final bool read;

  SmsItem({
    required this.index,
    required this.phone,
    required this.content,
    required this.date,
    required this.read,
  });

  /// 从正文里抓 4~8 位验证码（最常见的两类：纯数字码、带连字符的码）
  String? get code {
    final m = RegExp(r'(?:验证码|校验码|动态码|确认码|code)[^0-9]{0,12}(\d{4,8})',
            caseSensitive: false)
        .firstMatch(content);
    if (m != null) return m.group(1);
    final m2 = RegExp(r'(?<!\d)(\d{6})(?!\d)').firstMatch(content);
    return m2?.group(1);
  }
}

class NetModeInfo {
  final String networkMode;
  final String networkBand;
  final String lteMode;
  final String nrMode;

  NetModeInfo({
    required this.networkMode,
    required this.networkBand,
    required this.lteMode,
    required this.nrMode,
  });

  String get label {
    final parts = <String>[];
    if (nrMode != '00' && nrMode.isNotEmpty) parts.add('5G');
    if (lteMode != '00' && lteMode.isNotEmpty) parts.add('4G');
    if (parts.isEmpty) return '自动';
    return parts.join(' + ');
  }
}

// ---------------------------------------------------------------------------
// HiLink 客户端
// ---------------------------------------------------------------------------

/// 一条完整抓包记录（请求 + 响应）
class HttpCapture {
  HttpCapture({
    required this.method,
    required this.path,
    required this.reqBody,
    required this.status,
    required this.respBody,
    required this.ms,
    required this.error,
    required this.at,
  });

  final String method;
  final String path;
  final String reqBody;
  final int status;
  final String respBody;
  final int ms;
  final String error;
  final DateTime at;

  bool get ok => status >= 200 && status < 400;
  String get statusLabel => status == 0 ? 'ERR' : '$status';
  String get time =>
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}:${at.second.toString().padLeft(2, '0')}';

  String dump() {
    final b = StringBuffer();
    b.writeln('### $time ${method} $path → $statusLabel ${ms}ms');
    if (error.isNotEmpty) b.writeln('ERR: $error');
    if (reqBody.isNotEmpty) b.writeln('REQ: $reqBody');
    if (respBody.isNotEmpty) b.writeln('RESP: $respBody');
    return b.toString();
  }
}

class CpeClient {
  CpeClient({required this.host, this.useHttps = false});

  String host;
  bool useHttps;

  String cookie = '';
  String token = '';
  bool loggedIn = false;
  String lastError = '';
  String user = 'admin';

  /// 诊断轨迹：记录每一步请求的状态码与响应片段，便于排查协议差异
  final List<String> trace = [];

  void _log(String msg) {
    if (trace.length >= 90) trace.removeAt(0);
    trace.add(msg);
  }

  static String _head(String s, [int n = 260]) {
    final flat = s.replaceAll(RegExp(r'\s+'), ' ');
    return flat.length <= n ? flat : '${flat.substring(0, n)}…';
  }

  String get traceText => trace.join('\n');

  // ---- 抓包 ---------------------------------------------------------------
  bool captureOn = true;
  final List<HttpCapture> captures = [];

  static String _clip(String s, [int n = 3000]) =>
      s.length <= n ? s : '${s.substring(0, n)}\n…(已截断，共 ${s.length} 字符)';

  void _cap(String method, String path, String req, int status, String resp,
      int ms, String error) {
    if (!captureOn) return;
    if (req.length > 1200) req = _clip(req, 1200);
    captures.add(HttpCapture(
      method: method,
      path: path,
      reqBody: req,
      status: status,
      respBody: _clip(resp),
      ms: ms,
      error: error,
      at: DateTime.now(),
    ));
    if (captures.length > 120) captures.removeRange(0, captures.length - 120);
  }

  void clearCaptures() => captures.clear();

  String get captureText {
    final b = StringBuffer();
    b.writeln('设备: $host  用户: $user  时间: ${DateTime.now()}');
    b.writeln('共 ${captures.length} 条\n');
    for (final c in captures) {
      b.write(c.dump());
      b.writeln();
    }
    return b.toString();
  }

  static const _ua =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  String get baseUrl => '${useHttps ? 'https' : 'http'}://$host';

  Map<String, String> get _headers {
    final h = <String, String>{
      'Referer': '$baseUrl/html/index.html',
      'Origin': baseUrl,
      'Accept': '*/*',
      'User-Agent': _ua,
    };
    if (cookie.isNotEmpty) h['Cookie'] = cookie;
    return h;
  }

  static String trimToken(String t) {
    if (t.isEmpty) return t;
    if (t.contains('#')) {
      for (final seg in t.split('#')) {
        if (seg.isNotEmpty) return seg;
      }
      return t;
    }
    // 老固件返回纯十六进制长串，取后 32 位；新版固件返回 base64 完整 token，原样使用
    final isHex = RegExp(r'^[0-9a-fA-F]+$').hasMatch(t);
    if (isHex && t.length > 32) return t.substring(32);
    return t;
  }


  void _absorbCookie(http.Response r) {
    final raw = r.headers['set-cookie'];
    if (raw != null && raw.isNotEmpty) {
      final pair = raw.split(';').first.trim();
      // 只接受会话 cookie，避免被无关 Set-Cookie 覆盖
      if (pair.startsWith('SessionID=')) cookie = pair;
    }
    // 新版 WebUI 会把 CSRF token 放在响应头里，优先级高于 body
    final tok = r.headers['__requestverificationtoken'];
    if (tok != null && tok.trim().isNotEmpty) {
      token = trimToken(tok.trim());
    }
  }

  Future<http.Response?> _rawGet(String path,
      {Duration timeout = const Duration(seconds: 5)}) async {
    final sw = Stopwatch()..start();
    try {
      final r = await http
          .get(Uri.parse('$baseUrl$path'), headers: _headers)
          .timeout(timeout);
      _absorbCookie(r);
      sw.stop();
      _log('GET $path → ${r.statusCode} | ${_head(r.body)}');
      _cap('GET', path, '', r.statusCode, r.body, sw.elapsedMilliseconds, '');
      return r;
    } catch (e) {
      sw.stop();
      _log('GET $path → 异常: $e');
      lastError = '$e';
      _cap('GET', path, '', 0, '', sw.elapsedMilliseconds, '$e');
      return null;
    }
  }

  Future<http.Response?> _rawPost(String path, String body,
      {Duration timeout = const Duration(seconds: 8)}) async {
    final sw = Stopwatch()..start();
    try {
      final h = Map<String, String>.from(_headers);
      h['Content-Type'] = 'application/x-www-form-urlencoded; charset=UTF-8';
      h['X-Requested-With'] = 'XMLHttpRequest';
      if (token.isNotEmpty) h['__RequestVerificationToken'] = token;
      final r = await http
          .post(Uri.parse('$baseUrl$path'), headers: h, body: body)
          .timeout(timeout);
      _absorbCookie(r);
      sw.stop();
      _log('POST $path → ${r.statusCode} | 请求 ${_head(body, 160)} | 响应 ${_head(r.body)}');
      _cap('POST', path, body, r.statusCode, r.body, sw.elapsedMilliseconds, '');
      return r;
    } catch (e) {
      sw.stop();
      _log('POST $path → 异常: $e');
      lastError = '$e';
      _cap('POST', path, body, 0, '', sw.elapsedMilliseconds, '$e');
      return null;
    }
  }

  Future<void> initSession() async {
    await _rawGet('/', timeout: const Duration(seconds: 4));
    await _rawGet('/html/index.html', timeout: const Duration(seconds: 4));
    final ok = await refreshSesTok();
    if (!ok) {
      _log('SesTokInfo 未取到，回退 webserver/token');
      await refreshToken();
    }
  }

  /// 与 cpeultra 一致：SesTokInfo 同时给出会话 Cookie 与 CSRF token
  Future<bool> refreshSesTok() async {
    final r = await _rawGet('/api/webserver/SesTokInfo');
    if (r == null || r.statusCode != 200) return false;
    final d = tryParseXml(r.body);
    final ses = tagOf(d, 'SesInfo') ?? '';
    final tok = tagOf(d, 'TokInfo') ?? '';
    if (ses.isNotEmpty) {
      cookie = ses.startsWith('SessionID=')
          ? ses.split(';').first.trim()
          : 'SessionID=$ses';
      _log('会话 cookie 长度 ${cookie.length}');
    }
    if (tok.isNotEmpty) token = trimToken(tok);
    return tok.isNotEmpty;
  }

  Future<void> refreshToken() async {
    final r1 = await _rawGet('/api/webserver/token');
    if (r1 != null && r1.statusCode == 200) {
      final t = tagOf(tryParseXml(r1.body), 'token');
      if (t != null && t.isNotEmpty) token = trimToken(t);
    }
    if (token.isEmpty) {
      final r2 = await _rawGet('/api/webserver/SesTokInfo');
      if (r2 != null && r2.statusCode == 200) {
        final d = tryParseXml(r2.body);
        final ses = tagOf(d, 'SesInfo');
        final tok = tagOf(d, 'TokInfo');
        if (ses != null && ses.isNotEmpty && cookie.isEmpty) cookie = ses;
        if (tok != null && tok.isNotEmpty) token = tok;
      }
    }
  }

  Future<bool> login(String userName, String password) async {
    user = userName.isEmpty ? 'admin' : userName;
    lastError = '';
    trace.clear();
    _log('== 登录开始 host=$host user=$userName https=$useHttps ==');
    if (password.isEmpty) {
      lastError = '请填写管理密码';
      return false;
    }
    await initSession();
    _log('token 长度 ${token.length}');

    final attempts = <String>[];

    // 1. cpeultra 同款：标准 SCRAM + 精简请求体（logintype=1）
    final r1 = await _scramAttempt(password,
        modernBody: true, loginflag: false, variant: false);
    attempts.add('照抄新版=${r1 ?? '成功'}');
    if (r1 == null) return _loginDone(attempts);

    // 2. 新版请求体 + 带 loginflag 的挑战
    final r2 = await _scramAttempt(password,
        modernBody: true, loginflag: true, variant: false);
    attempts.add('新版+loginflag=${r2 ?? '成功'}');
    if (r2 == null) return _loginDone(attempts);

    // 3. 标准 proof + 旧请求体
    final r3 = await _scramAttempt(password,
        modernBody: false, loginflag: true, variant: false);
    attempts.add('旧请求体=${r3 ?? '成功'}');
    if (r3 == null) return _loginDone(attempts);

    // 4. 旧写法 proof + 旧请求体（兼容 INS2）
    final r3b = await _scramAttempt(password,
        modernBody: false, loginflag: true, variant: true);
    attempts.add('旧proof=${r3b ?? '成功'}');
    if (r3b == null) return _loginDone(attempts);

    // 4. 老式 /api/user/login
    final r4 = await _legacyLogin(password);
    attempts.add('老式登录=${r4 ?? '成功'}');
    if (r4 == null) return _loginDone(attempts);

    loggedIn = false;
    lastError = '五种方式均被拒（${attempts.join('、')}）'
        '·如浏览器也登不上，就是管理密码不对';
    _log(lastError);
    return false;
  }

  bool _loginDone(List<String> attempts) {
    loggedIn = true;
    lastError = '';
    _log('登录成功，方式: ${attempts.join('、')}');
    return true;
  }

  /// 返回 null 表示成功，否则返回失败原因（错误码/状态）
  Future<String?> _scramAttempt(String password,
      {required bool modernBody,
      required bool loginflag,
      required bool variant}) async {
    final firstNonce = randomNonce();
    final challengeBody = '<?xml version="1.0" encoding="UTF-8"?><request>'
        '<username>${escXml(user)}</username>'
        '<firstnonce>$firstNonce</firstnonce>'
        '<mode>1</mode>'
        '${loginflag ? '<loginflag>2</loginflag>' : ''}'
        '</request>';
    final challenge =
        await _rawPost('/api/user/challenge_login', challengeBody);
    if (challenge == null) return '无响应';
    if (challenge.statusCode != 200) return 'HTTP ${challenge.statusCode}';

    final d = tryParseXml(challenge.body);
    final preCode = tagOf(d, 'code');
    if (preCode != null && preCode.isNotEmpty) return '挑战$preCode';

    final salt = tagOf(d, 'salt') ?? '';
    final serverNonce = tagOf(d, 'servernonce') ?? '';
    final iterations = int.tryParse(tagOf(d, 'iterations') ?? '') ?? 1000;
    if (salt.isEmpty || serverNonce.isEmpty) return '无salt';

    final proof = computeClientProof(
        password, salt, iterations, firstNonce, serverNonce,
        variant: variant);

    final authBody = modernBody
        ? '<?xml version="1.0" encoding="UTF-8"?><request>'
            '<clientproof>$proof</clientproof>'
            '<finalnonce>$serverNonce</finalnonce>'
            '<logintype>1</logintype></request>'
        : '<?xml version="1.0" encoding="UTF-8"?><request>'
            '<username>${escXml(user)}</username>'
            '<clientproof>$proof</clientproof>'
            '<finalnonce>$serverNonce</finalnonce>'
            '<password_type>4</password_type></request>';

    final auth =
        await _rawPost('/api/user/authentication_login', authBody);
    if (auth == null) return '无响应';

    final body = auth.body;
    if (auth.statusCode == 200 && !body.contains('<code>')) {
      final sig = computeServerSignature(
          password, salt, iterations, firstNonce, serverNonce);
      final got = tagOf(tryParseXml(body), 'serversignature') ?? '';
      _log('服务器签名 ${got.isEmpty ? '缺失' : (got.toLowerCase() == sig ? '校验通过' : '不一致')}');
      return null;
    }
    final code = tagOf(tryParseXml(body), 'code');
    return code ?? 'HTTP ${auth.statusCode}';
  }

  Future<String?> _legacyLogin(String password) async {
    final pwd64 = base64Encode(utf8.encode(password));
    final body = '<?xml version="1.0" encoding="UTF-8"?><request>'
        '<Username>${escXml(user)}</Username>'
        '<Password>$pwd64</Password>'
        '<password_type>3</password_type></request>';
    final r = await _rawPost('/api/user/login', body);
    if (r == null) return '无响应';
    if (r.statusCode == 200 && !r.body.contains('<code>')) {
      await refreshToken();
      return null;
    }
    final code = tagOf(tryParseXml(r.body), 'code');
    return code ?? 'HTTP ${r.statusCode}';
  }

  /// 短信专项探测：GET/POST 两种取法都打一遍，判断固件是否开放短信
  Future<void> probeSms() async {
    _log('== 短信接口探测 ==');
    await _rawGet('/api/sms/sms-count', timeout: const Duration(seconds: 4));
    await _rawGet('/api/sms/sms-list', timeout: const Duration(seconds: 4));
    await _rawPost(
        '/api/sms/sms-list',
        '<request><PageIndex>1</PageIndex><ReadCount>20</ReadCount>'
            '<BoxType>1</BoxType><SortType>0</SortType></request>',
        timeout: const Duration(seconds: 6));
  }

  Future<void> probeEndpoints() async {
    _log('== 只读探测 ==');
    const paths = [
      '/api/device/information',
      '/api/device/signal',
      '/api/monitoring/status',
      '/api/net/net-mode',
      '/api/sms/sms-count',
      '/api/sms/sms-list',
    ];
    for (final p in paths) {
      await _rawGet(p, timeout: const Duration(seconds: 3));
    }
  }

  // ---- 通用读取 ------------------------------------------------------------

  /// 返回 null 表示请求失败；返回字符串表示原始 body
  Future<String?> fetchText(String path) async {
    final r = await _rawGet(path);
    if (r == null) return null;
    return r.body;
  }

  Future<String?> postXml(String path, String body) async {
    final r = await _rawPost(path, body);
    if (r == null) return null;
    return r.body;
  }

  // ---- 设备 / 信号 ---------------------------------------------------------

  Future<XmlDocument?> fetchDeviceInfo() async {
    final r = await _rawGet('/api/device/information');
    if (r == null || r.statusCode != 200) return null;
    return tryParseXml(r.body);
  }

  Future<Map<String, String>?> fetchSignal() async {
    final r = await _rawGet('/api/device/signal');
    if (r == null || r.statusCode != 200) return null;
    final d = tryParseXml(r.body);
    if (d == null) return null;
    if (d.rootElement.findElements('code').isNotEmpty) {
      lastError = '会话鉴权未通过';
      return null;
    }
    final map = <String, String>{};
    for (final el in d.rootElement.childElements) {
      map[el.name.local] = el.innerText.trim();
    }
    return map;
  }

  Future<XmlDocument?> fetchStatus() async {
    final r = await _rawGet('/api/monitoring/status');
    if (r == null || r.statusCode != 200) return null;
    return tryParseXml(r.body);
  }

  Future<XmlDocument?> fetchTraffic() async {
    final r = await _rawGet('/api/monitoring/traffic-statistics');
    if (r == null || r.statusCode != 200) return null;
    return tryParseXml(r.body);
  }

  // ---- 短信 ---------------------------------------------------------------

  Future<Map<String, int>?> fetchSmsCount() async {
    final r = await _rawGet('/api/sms/sms-count');
    if (r == null || r.statusCode != 200) return null;
    final d = tryParseXml(r.body);
    if (d == null) return null;
    int read(String k) => int.tryParse(tagOf(d, k) ?? '') ?? 0;
    return {
      'localUnread': read('LocalUnread'),
      'localRead': read('LocalRead'),
      'localDeleted': read('LocalDeleted'),
      'simUnread': read('SimUnread'),
      'simRead': read('SimRead'),
      'simDeleted': read('SimDeleted'),
    };
  }

  Future<List<SmsItem>?> fetchSmsList({int page = 1, int count = 20}) async {
    final body = '<?xml version="1.0" encoding="UTF-8"?><request>'
        '<PageIndex>$page</PageIndex>'
        '<ReadCount>$count</ReadCount>'
        '<BoxType>1</BoxType>'
        '<SortType>0</SortType></request>';
    final r = await _rawPost('/api/sms/sms-list', body);
    if (r == null || r.statusCode != 200) {
      lastError = '短信接口无响应';
      return null;
    }
    final d = tryParseXml(r.body);
    if (d == null) return null;
    final list = <SmsItem>[];
    for (final m in d.rootElement.findAllElements('Message')) {
      String v(String k) {
        final els = m.findElements(k);
        return els.isEmpty ? '' : els.first.innerText.trim();
      }

      list.add(SmsItem(
        index: v('Index'),
        phone: v('Phone'),
        content: v('Content'),
        date: v('Date'),
        read: v('Smstat') == '1',
      ));
    }
    return list;
  }

  Future<String?> sendSms(String phone, String content) async {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final date =
        '${now.year}-${two(now.month)}-${two(now.day)} ${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
    final body = '<?xml version="1.0" encoding="UTF-8"?><request>'
        '<Index>-1</Index>'
        '<Phones><Phone>${escXml(phone)}</Phone></Phones>'
        '<Sca></Sca>'
        '<Content>${escXml(content)}</Content>'
        '<Length>${content.length}</Length>'
        '<Reserved>1</Reserved>'
        '<Date>$date</Date></request>';
    final r = await _rawPost('/api/sms/send-sms', body);
    if (r == null) return '发送请求失败';
    if (r.statusCode != 200) return 'HTTP ${r.statusCode}';
    final code = tagOf(tryParseXml(r.body), 'code');
    if (code == null) return null;
    return '发送失败（code $code）';
  }

  Future<void> markRead(String index) async {
    await _rawPost('/api/sms/set-read',
        '<?xml version="1.0" encoding="UTF-8"?><request><Index>$index</Index></request>');
  }

  Future<void> deleteSms(String index) async {
    await _rawPost('/api/sms/delete-sms',
        '<?xml version="1.0" encoding="UTF-8"?><request><Index>$index</Index></request>');
  }

  // ---- 组网模式 ------------------------------------------------------------

  Future<NetModeInfo?> fetchNetMode() async {
    final r = await _rawGet('/api/net/net-mode');
    if (r == null || r.statusCode != 200) return null;
    final d = tryParseXml(r.body);
    if (d == null) return null;
    return NetModeInfo(
      networkMode: tagOf(d, 'NetworkMode') ?? '',
      networkBand: tagOf(d, 'NetworkBand') ?? '',
      lteMode: tagOf(d, 'NetworkModeLTE') ?? '',
      nrMode: tagOf(d, 'NetworkModeNR') ?? '',
    );
  }

  /// 仅切换 NR 开关（不再盲写整段掩码，失败时提示回网页后台）
  Future<bool> setNrEnabled(bool enable) async {
    final cur = await fetchNetMode();
    if (cur == null) {
      lastError = '读不到当前网络模式';
      return false;
    }
    final body = '<?xml version="1.0" encoding="UTF-8"?><request>'
        '<NetworkMode>${cur.networkMode}</NetworkMode>'
        '<NetworkBand>${cur.networkBand}</NetworkBand>'
        '<NetworkModeLTE>${cur.lteMode}</NetworkModeLTE>'
        '<NetworkModeNR>${enable ? "01" : "00"}</NetworkModeNR></request>';
    final r = await _rawPost('/api/net/net-mode', body);
    if (r == null) return false;
    final code = tagOf(tryParseXml(r.body), 'code');
    if (code != null) {
      lastError = '设备拒绝（code $code）';
      return false;
    }
    return true;
  }
}
