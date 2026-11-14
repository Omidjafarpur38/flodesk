// FloDesk: Persian network / VPN / low-bandwidth settings page.
// Copied to flutter/lib/flodesk_network.dart by flodesk/rebrand.sh; shared by
// desktop and Android home screens.
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';

const String kFloVersion = '__FLO_VERSION__';
const String kFloForceRelayKey = 'flodesk-force-relay-v1';
const String kFloSpeedModeKey = 'flodesk-speed-mode-v1';

const Color _accent = Color(0xFF7C6CFF);

bool floForceRelay() => bind.mainGetLocalOption(key: kFloForceRelayKey) == 'Y';

/// Session defaults for each mode. Empty string = option off (RustDesk's "N").
const Map<String, Map<String, String>> _speedPresets = {
  // Weak internet: lowest quality, 10 fps, efficient codec, no audio, no
  // clipboard / file copy-paste.
  'low': {
    kOptionImageQuality: 'low',
    'custom-fps': '10',
    kOptionCodecPreference: 'vp9',
    kOptionDisableAudio: 'Y',
    kOptionDisableClipboard: 'Y',
    kOptionEnableFileCopyPaste: 'N',
  },
  'balanced': {
    kOptionImageQuality: 'balanced',
    'custom-fps': '30',
    kOptionCodecPreference: 'auto',
    kOptionDisableAudio: '',
    kOptionDisableClipboard: '',
    kOptionEnableFileCopyPaste: 'Y',
  },
  'best': {
    kOptionImageQuality: 'best',
    'custom-fps': '30',
    kOptionCodecPreference: 'auto',
    kOptionDisableAudio: '',
    kOptionDisableClipboard: '',
    kOptionEnableFileCopyPaste: 'Y',
  },
};

String floSpeedMode() {
  final m = bind.mainGetLocalOption(key: kFloSpeedModeKey);
  return _speedPresets.containsKey(m) ? m : 'balanced';
}

Future<void> floApplySpeedMode(String mode) async {
  final p = _speedPresets[mode];
  if (p == null) return;
  for (final e in p.entries) {
    await bind.mainSetUserDefaultOption(key: e.key, value: e.value);
  }
  await bind.mainSetLocalOption(key: kFloSpeedModeKey, value: mode);
}

void openFloDeskNetwork(BuildContext context) {
  Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FloDeskNetworkPage()));
}

class FloDeskNetworkPage extends StatefulWidget {
  const FloDeskNetworkPage({Key? key}) : super(key: key);
  @override
  State<FloDeskNetworkPage> createState() => _FloDeskNetworkPageState();
}

class _FloDeskNetworkPageState extends State<FloDeskNetworkPage> {
  final _id = TextEditingController();
  final _relay = TextEditingController();
  final _key = TextEditingController();
  final _proxy = TextEditingController();
  final _puser = TextEditingController();
  final _ppass = TextEditingController();
  bool _forceRelay = false;
  String _speed = 'balanced';
  String _msg = '';
  bool _ok = true;
  bool _busy = false;

  Color get _bg => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF0B0C10)
      : const Color(0xFFF6F7FB);
  Color get _card => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF14161C)
      : Colors.white;
  Color get _fg => Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : const Color(0xFF0F172A);
  Color get _muted => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF9AA1AF)
      : const Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _id.text = bind.mainGetOptionSync(key: 'custom-rendezvous-server');
    _relay.text = bind.mainGetOptionSync(key: 'relay-server');
    _key.text = bind.mainGetOptionSync(key: 'key');
    _forceRelay = floForceRelay();
    _speed = floSpeedMode();
    _loadProxy();
  }

  Future<void> _loadProxy() async {
    try {
      final s = await bind.mainGetSocks();
      if (s.length == 3 && mounted) {
        setState(() {
          _proxy.text = s[0];
          _puser.text = s[1];
          _ppass.text = s[2];
        });
      }
    } catch (_) {}
  }

  void _say(String m, bool ok) {
    if (mounted) setState(() {
      _msg = m;
      _ok = ok;
    });
  }

  Future<void> _saveServer() async {
    setState(() => _busy = true);
    try {
      final errs = <RxString>[RxString(''), RxString(''), RxString(''), RxString('')];
      final okSave = await setServerConfig(
          null,
          errs,
          ServerConfig(
              idServer: _id.text,
              relayServer: _relay.text,
              apiServer: '',
              key: _key.text));
      _say(okSave ? 'تنظیمات سرور ذخیره شد.' : 'سرور معتبر نیست یا پاسخ نمی‌دهد: ${errs[0].value}${errs[1].value}', okSave);
    } catch (e) {
      _say('خطا در ذخیره: $e', false);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _testServer() async {
    setState(() => _busy = true);
    final host = _id.text.trim();
    if (host.isEmpty) {
      _say('آدرس سرور خالی است (پیش‌فرض نرم‌افزار استفاده می‌شود).', true);
    } else {
      final r = await bind.mainTestIfValidServer(server: host, testWithProxy: true);
      _say(r.isEmpty ? 'سرور در دسترس است.' : 'سرور در دسترس نیست: $r', r.isEmpty);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _saveProxy() async {
    setState(() => _busy = true);
    try {
      await bind.mainSetSocks(
          proxy: _proxy.text.trim(),
          username: _puser.text.trim(),
          password: _ppass.text.trim());
      _say(_proxy.text.trim().isEmpty ? 'پروکسی خاموش شد.' : 'پروکسی ذخیره شد.', true);
    } catch (e) {
      _say('خطا در ذخیره پروکسی: $e', false);
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _section(String title, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _fg.withOpacity(0.08))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  color: _fg, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...children,
        ]),
      );

  Widget _field(String label, TextEditingController c, {bool pass = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          obscureText: pass,
          textDirection: TextDirection.ltr,
          style: TextStyle(color: _fg),
          decoration: InputDecoration(labelText: label, isDense: true),
        ),
      );

  Widget _btn(String t, VoidCallback f, {bool primary = true}) => primary
      ? FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: _accent, foregroundColor: Colors.white),
          onPressed: _busy ? null : f,
          child: Text(t))
      : OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: _fg),
          onPressed: _busy ? null : f,
          child: Text(t));

  Widget _help(String t) => Text(t,
      style: TextStyle(color: _muted, fontSize: 12.5, height: 1.9));

  Widget _modeTile(String key, String title, String sub) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await floApplySpeedMode(key);
          if (mounted) setState(() => _speed = key);
          _say('حالت «$title» اعمال شد؛ از اتصال بعدی فعال است.', true);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _speed == key ? _accent : _fg.withOpacity(0.12),
                  width: _speed == key ? 2 : 1)),
          child: Row(children: [
            Icon(_speed == key ? Icons.radio_button_checked : Icons.radio_button_off,
                color: _speed == key ? _accent : _muted),
            const SizedBox(width: 10),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: _fg, fontWeight: FontWeight.w600)),
              Text(sub, style: TextStyle(color: _muted, fontSize: 12, height: 1.7)),
            ])),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          foregroundColor: _fg,
          elevation: 0,
          title: const Text('شبکه و اتصال'),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              if (_msg.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: (_ok ? const Color(0xFF22C55E) : const Color(0xFFF87171))
                          .withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(_msg, style: TextStyle(color: _fg)),
                ),
              _section('حالت سرعت', [
                _modeTile('low', 'کم‌سرعت (اینترنت ضعیف)',
                    'کمترین کیفیت تصویر، ۱۰ فریم، کدک کم‌حجم VP9، بدون صدا، بدون کلیپ‌بورد و کپی فایل'),
                _modeTile('balanced', 'متعادل', 'کیفیت و سرعت متعادل، صدا و کلیپ‌بورد فعال'),
                _modeTile('best', 'بهترین کیفیت', 'بیشترین کیفیت تصویر؛ نیاز به اینترنت پرسرعت'),
                _help('این حالت به‌عنوان پیش‌فرض همه‌ی اتصال‌های خروجی بعدی ذخیره می‌شود. '
                    'برای اتصال در حال اجرا، از نوار ابزار نشست هم می‌توانید کیفیت را عوض کنید.'),
              ]),
              _section('سرور', [
                _field('سرور شناسه (ID / Rendezvous)', _id),
                _field('سرور رله (Relay) — اختیاری', _relay),
                _field('کلید عمومی (Key)', _key),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _btn('ذخیره‌ی سرور', _saveServer),
                  _btn('آزمایش اتصال', _testServer, primary: false),
                ]),
                const SizedBox(height: 8),
                _help('اگر خالی بگذارید نرم‌افزار از سرور داخل خودش استفاده می‌کند. '
                    'پورت‌های لازم روی سرور: TCP 21115 تا 21117 و UDP 21116 (و TCP 21118/21119 برای وب).'),
              ]),
              _section('اتصال از خارج کشور به سرور ایران / VPN', [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: _accent,
                  title: Text('فقط رله (Force relay)', style: TextStyle(color: _fg)),
                  subtitle: _help('وقتی اتصال مستقیم (P2P) بین دو کشور برقرار نمی‌شود، همه‌ی اتصال‌های خروجی از '
                      'طریق سرور رله می‌روند (معادل افزودن /r به شناسه). کندتر ولی پایدارتر است.'),
                  value: _forceRelay,
                  onChanged: (v) async {
                    await bind.mainSetLocalOption(
                        key: kFloForceRelayKey, value: v ? 'Y' : '');
                    setState(() => _forceRelay = v);
                  },
                ),
                const SizedBox(height: 6),
                _field('پروکسی (مثلاً socks5://127.0.0.1:1080 یا host:port)', _proxy),
                _field('نام کاربری پروکسی (اختیاری)', _puser),
                _field('رمز پروکسی (اختیاری)', _ppass, pass: true),
                _btn('ذخیره‌ی پروکسی', _saveProxy),
                const SizedBox(height: 10),
                _help('راهنما: اگر VPN شما کل سیستم را می‌گیرد (حالت TUN)، معمولاً نیازی به پروکسی نیست. '
                    'اگر VPN فقط پروکسی محلی می‌دهد، آدرس آن را اینجا بنویسید. '
                    'اگر شناسه‌ی دستگاه ثبت نمی‌شود یا اتصال بین دو کشور قطع و وصل می‌شود، «فقط رله» را روشن کنید و '
                    'مطمئن شوید پورت‌های سرور رله باز است.'),
              ]),
              Center(child: _help('FloDesk نسخه $kFloVersion')),
            ]),
          ),
        ),
      ),
    );
  }
}
