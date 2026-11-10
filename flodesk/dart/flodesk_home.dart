// FloDesk: Persian RTL home dashboard for apparel businesses.
// Copied to flutter/lib/desktop/pages/flodesk_home.dart by flodesk/rebrand.sh
// and wired into DesktopHomePage.build() by a one-line patch (see rebrand.sh).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/connection_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_tab_page.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:get/get.dart';
import 'package:flutter_hbb/utils/multi_window_manager.dart';

const _kDevicesKey = 'flodesk-devices-v1';

class _Cat {
  final String key, label;
  final IconData icon;
  final Color color;
  const _Cat(this.key, this.label, this.icon, this.color);
}

const List<_Cat> _cats = [
  _Cat('pos', 'صندوق فروشگاه', Icons.point_of_sale_rounded, Color(0xFF4FC3F7)),
  _Cat('warehouse', 'انبار', Icons.warehouse_rounded, Color(0xFFFFB74D)),
  _Cat('office', 'دفتر / حسابداری', Icons.calculate_rounded, Color(0xFF81C784)),
  _Cat('sewing', 'سالن تولید (برش و دوخت)', Icons.content_cut_rounded,
      Color(0xFFBA68C8)),
  _Cat('wash', 'سنگ‌شویی', Icons.local_laundry_service_rounded,
      Color(0xFF4DB6AC)),
  _Cat('support', 'پشتیبانی', Icons.support_agent_rounded, Color(0xFFE57373)),
];

_Cat _catOf(String k) =>
    _cats.firstWhere((c) => c.key == k, orElse: () => _cats.last);

class _Device {
  String id, name, cat;
  _Device(this.id, this.name, this.cat);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'cat': cat};
}

class FloDeskHome extends StatefulWidget {
  const FloDeskHome({Key? key}) : super(key: key);
  @override
  State<FloDeskHome> createState() => _FloDeskHomeState();
}

class _FloDeskHomeState extends State<FloDeskHome> {
  bool _dark = true;
  Color get bg => _dark ? const Color(0xFF0F1115) : const Color(0xFFF5F6F8);
  Color get card => _dark ? const Color(0xFF1A1D24) : Colors.white;
  Color get line => _dark ? const Color(0xFF2A2F3A) : const Color(0xFFE2E5EA);
  Color get muted => _dark ? const Color(0xFF9AA1AF) : const Color(0xFF6B7280);

  final _quickId = TextEditingController();
  List<_Device> _devices = [];
  String _filter = 'all';
  int _tab = 0;
  bool _hideInstall = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _quickId.dispose();
    super.dispose();
  }

  void _load() {
    try {
      final raw = bind.mainGetLocalOption(key: _kDevicesKey);
      if (raw.isNotEmpty) {
        final l = jsonDecode(raw) as List;
        _devices = l
            .map((e) => _Device('${e['id']}', '${e['name']}', '${e['cat']}'))
            .toList();
      }
    } catch (_) {
      _devices = [];
    }
  }

  Future<void> _save() async {
    await bind.mainSetLocalOption(
        key: _kDevicesKey,
        value: jsonEncode(_devices.map((d) => d.toJson()).toList()));
    if (mounted) setState(() {});
  }

  String _digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  void _connect(String id, {bool file = false}) {
    final d = _digits(id);
    if (d.isEmpty) {
      showToast('شناسه‌ی دستگاه را وارد کنید');
      return;
    }
    connect(context, d, isFileTransfer: file);
  }

  Future<void> _editDevice({_Device? dev, String? prefillId}) async {
    final name = TextEditingController(text: dev?.name ?? '');
    final id = TextEditingController(text: dev?.id ?? prefillId ?? '');
    String cat = dev?.cat ?? 'pos';
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            backgroundColor: card,
            title: Text(dev == null ? 'افزودن دستگاه' : 'ویرایش دستگاه',
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 380,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: name,
                  decoration: InputDecoration(
                      labelText: 'نام دلخواه (مثلاً صندوق شعبه ولیعصر)'),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: id,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.number,
                  decoration:
                      InputDecoration(labelText: 'شناسه‌ی FloDesk دستگاه'),
                ),
                SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final c in _cats)
                      ChoiceChip(
                        avatar: Icon(c.icon, size: 18, color: c.color),
                        label: Text(c.label),
                        selected: cat == c.key,
                        onSelected: (_) => setS(() => cat = c.key),
                      ),
                  ]),
                ),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('انصراف')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('ذخیره')),
            ],
          ),
        ),
      ),
    );
    final nid = _digits(id.text);
    if (res == true && nid.isNotEmpty) {
      final nm = name.text.trim().isEmpty ? _catOf(cat).label : name.text.trim();
      if (dev == null) {
        _devices.add(_Device(nid, nm, cat));
      } else {
        dev.id = nid;
        dev.name = nm;
        dev.cat = cat;
      }
      await _save();
    }
  }

  Future<void> _confirmDelete(_Device d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: card,
          title: Text('حذف دستگاه'),
          content: Text('«${d.name}» از فهرست دستگاه‌های من حذف شود؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('انصراف')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('حذف')),
          ],
        ),
      ),
    );
    if (ok == true) {
      _devices.remove(d);
      await _save();
    }
  }

  void _about() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: card,
          title: Text('درباره‌ی FloDesk'),
          content: SizedBox(
            width: 420,
            child: Text(
              'FloDesk ابزار دسترسی از راه دور مخصوص کسب‌وکارهای پوشاک است '
              '(پشتیبانی صندوق، انبار، دفتر، تولید و سنگ‌شویی).\n\n'
              'این نرم‌افزار بر پایه‌ی RustDesk ساخته شده و مانند آن تحت مجوز '
              'GNU AGPL-3.0 منتشر می‌شود. کد منبع نسخه‌ی شما: '
              'github.com/Omidjafarpur38/flodesk',
              style: TextStyle(height: 1.9),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: Text('بستن'))
          ],
        ),
      ),
    );
  }

  // ---------- widgets ----------

  Widget _panel({required Widget child, EdgeInsets? pad}) => Container(
        padding: pad ?? EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
        ),
        child: child,
      );

  Widget _identity() {
    final model = gFFI.serverModel;
    final showOneTime = model.approveMode != 'click' &&
        model.verificationMethod != kUsePermanentPassword;
    return _panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.badge_outlined, size: 20, color: muted),
          SizedBox(width: 8),
          Text('هویت این دستگاه',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          Spacer(),
          IconButton(
            tooltip: 'تنظیمات',
            onPressed: DesktopTabPage.onAddSetting,
            icon: Icon(Icons.settings_outlined, color: muted),
          ),
        ]),
        SizedBox(height: 4),
        Text(
            'برای دریافت پشتیبانی، شناسه و رمز زیر را به پشتیبان بگویید.',
            style: TextStyle(color: muted, fontSize: 12.5, height: 1.7)),
        SizedBox(height: 14),
        Text('شناسه', style: TextStyle(color: muted, fontSize: 12)),
        AnimatedBuilder(
          animation: model.serverId,
          builder: (_, __) => InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: model.serverId.text));
              showToast('شناسه کپی شد');
            },
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(children: [
                Text(
                  model.serverId.text.isEmpty ? '···' : model.serverId.text,
                  style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2),
                ),
                SizedBox(width: 10),
                Icon(Icons.copy_rounded, size: 18, color: muted),
              ]),
            ),
          ),
        ),
        SizedBox(height: 10),
        Divider(color: line, height: 1),
        SizedBox(height: 10),
        Text(showOneTime ? 'رمز یک‌بارمصرف' : 'رمز دسترسی',
            style: TextStyle(color: muted, fontSize: 12)),
        AnimatedBuilder(
          animation: model.serverPasswd,
          builder: (_, __) => Directionality(
            textDirection: TextDirection.ltr,
            child: Row(children: [
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: model.serverPasswd.text));
                  showToast('رمز کپی شد');
                },
                child: Text(
                  model.approveMode == 'click'
                      ? 'تأیید دستی'
                      : (model.serverPasswd.text.isEmpty
                          ? '···'
                          : model.serverPasswd.text),
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5),
                ),
              ),
              Spacer(),
              if (showOneTime)
                IconButton(
                  tooltip: 'رمز جدید',
                  onPressed: () => bind.mainUpdateTemporaryPassword(),
                  icon: Icon(Icons.refresh_rounded, color: muted),
                ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _quickConnect() {
    return _panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.bolt_rounded, size: 20, color: muted),
          SizedBox(width: 8),
          Text('اتصال سریع',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _quickId,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.number,
              onSubmitted: _connect,
              style: TextStyle(fontSize: 20, letterSpacing: 1.5),
              decoration: InputDecoration(
                hintText: 'شناسه‌ی دستگاه مقصد',
                hintTextDirection: TextDirection.rtl,
                filled: true,
                fillColor: bg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: line)),
              ),
            ),
          ),
          SizedBox(width: 8),
          Tooltip(
            message: 'ذخیره در دستگاه‌های من',
            child: IconButton.outlined(
              onPressed: () => _editDevice(prefillId: _quickId.text),
              icon: Icon(Icons.bookmark_add_outlined),
            ),
          ),
          SizedBox(width: 6),
          FilledButton.icon(
            onPressed: () => _connect(_quickId.text),
            style: FilledButton.styleFrom(
                minimumSize: const Size(110, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            icon: Icon(Icons.cast_connected_rounded),
            label: Text('اتصال'),
          ),
        ]),
      ]),
    );
  }

  Widget _installBar() {
    if (!isWindows ||
        _hideInstall ||
        bind.isDisableInstallation() ||
        bind.mainIsInstalled()) {
      return SizedBox.shrink();
    }
    return Container(
      margin: EdgeInsets.only(bottom: 14),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF23262E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: line),
      ),
      child: Row(children: [
        Icon(Icons.shield_outlined, color: muted),
        SizedBox(width: 10),
        Expanded(
          child: Text(
              'برای کار پایدار در حالت پشتیبانی (و دسترسی به پنجره‌های مدیر ویندوز)، FloDesk را نصب کنید.',
              style: TextStyle(fontSize: 12.5, height: 1.7)),
        ),
        TextButton(
            onPressed: () => setState(() => _hideInstall = true),
            child: Text('بعداً')),
        FilledButton(
          onPressed: () async {
            await rustDeskWinManager.closeAllSubWindows();
            bind.mainGotoInstall();
          },
          child: Text('نصب'),
        ),
      ]),
    );
  }

  Widget _devicesView() {
    final list = _filter == 'all'
        ? _devices
        : _devices.where((d) => d.cat == _filter).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('دستگاه‌های من',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        Spacer(),
        FilledButton.tonalIcon(
          onPressed: () => _editDevice(),
          icon: Icon(Icons.add_rounded),
          label: Text('افزودن دستگاه'),
        ),
      ]),
      SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          Padding(
            padding: EdgeInsetsDirectional.only(end: 8),
            child: ChoiceChip(
              label: Text('همه (${_devices.length})'),
              selected: _filter == 'all',
              onSelected: (_) => setState(() => _filter = 'all'),
            ),
          ),
          for (final c in _cats)
            Padding(
              padding: EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                avatar: Icon(c.icon, size: 18, color: c.color),
                label: Text(c.label),
                selected: _filter == c.key,
                onSelected: (_) => setState(() => _filter = c.key),
              ),
            ),
        ]),
      ),
      SizedBox(height: 14),
      if (list.isEmpty)
        _panel(
          pad: EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          child: Center(
            child: Column(children: [
              Icon(Icons.devices_other_rounded, size: 44, color: muted),
              SizedBox(height: 12),
              Text(
                  _devices.isEmpty
                      ? 'هنوز دستگاهی اضافه نکرده‌اید'
                      : 'دستگاهی در این دسته نیست',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text(
                  'صندوق‌ها، انبار، دفتر و سالن تولید را با نام دلخواه اضافه کنید تا با یک کلیک وصل شوید.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, height: 1.8, fontSize: 12.5)),
            ]),
          ),
        )
      else
        Wrap(spacing: 12, runSpacing: 12, children: [
          for (final d in list) _deviceCard(d),
        ]),
    ]);
  }

  Widget _deviceCard(_Device d) {
    final c = _catOf(d.cat);
    return Container(
      width: 250,
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: c.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(c.icon, color: c.color, size: 22),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(c.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, fontSize: 11.5)),
                ]),
          ),
          PopupMenuButton<String>(
            tooltip: 'گزینه‌ها',
            icon: Icon(Icons.more_vert_rounded, color: muted, size: 20),
            onSelected: (v) {
              if (v == 'edit') _editDevice(dev: d);
              if (v == 'del') _confirmDelete(d);
              if (v == 'file') _connect(d.id, file: true);
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'file', child: Text('انتقال فایل')),
              PopupMenuItem(value: 'edit', child: Text('ویرایش نام و دسته')),
              PopupMenuItem(value: 'del', child: Text('حذف')),
            ],
          ),
        ]),
        SizedBox(height: 12),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(d.id,
              style: TextStyle(
                  fontSize: 18, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
        ),
        SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _connect(d.id),
            icon: Icon(Icons.cast_connected_rounded, size: 18),
            label: Text('اتصال'),
          ),
        ),
      ]),
    );
  }

  Widget _guide() {
    Widget step(int n, String t, String s) => Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
                radius: 14,
                backgroundColor: line,
                child: Text('$n',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            SizedBox(width: 12),
            Expanded(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 3),
                Text(s,
                    style: TextStyle(
                        color: muted, fontSize: 12.5, height: 1.8)),
              ]),
            ),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('راهنمای دریافت پشتیبانی (برای صندوق‌دار و مشتری)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 14),
          step(1, 'FloDesk را باز کنید',
              'در همین صفحه، شناسه (عدد بزرگ) و رمز یک‌بارمصرف را می‌بینید.'),
          step(2, 'شناسه و رمز را به پشتیبان بدهید',
              'با کلیک روی هر کدام کپی می‌شود؛ از طریق تلفن یا پیام‌رسان بفرستید.'),
          step(3, 'اتصال را تأیید کنید',
              'اگر پنجره‌ی درخواست اتصال آمد، «پذیرفتن» را بزنید.'),
          step(4, 'پایان جلسه',
              'هر زمان خواستید پنجره‌ی جلسه را ببندید؛ رمز بعد از هر جلسه عوض می‌شود.'),
        ]),
      ),
      SizedBox(height: 12),
      _panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('نکته‌های امنیتی',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(
              '• رمز را فقط به کسی بدهید که خودتان با او تماس گرفته‌اید.\n'
              '• اگر مطمئن نیستید، «رمز جدید» را بزنید یا برنامه را ببندید.\n'
              '• هرگز رمز بانکی یا کد پیامکی را در FloDesk وارد نکنید.',
              style: TextStyle(color: muted, height: 2, fontSize: 12.5)),
        ]),
      ),
    ]);
  }

  Widget _nav() {
    Widget item(int i, IconData ic, String t) => Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Material(
            color: _tab == i ? line : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _tab = i),
              child: Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                child: Row(children: [
                  Icon(ic, size: 20, color: _tab == i ? Colors.white : muted),
                  SizedBox(width: 10),
                  Text(t,
                      style: TextStyle(
                          fontWeight:
                              _tab == i ? FontWeight.bold : FontWeight.normal)),
                ]),
              ),
            ),
          ),
        );
    return Container(
      width: 200,
      color: card,
      padding: EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Image.asset('assets/flodesk_logo.png', width: 34, height: 34,
              errorBuilder: (_, __, ___) => SizedBox(width: 34)),
          SizedBox(width: 10),
          Text('FloDesk',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        ]),
        Padding(
          padding: EdgeInsets.only(top: 4, bottom: 18, right: 2),
          child: Text('دسترسی از راه دور پوشاک',
              style: TextStyle(color: muted, fontSize: 11.5)),
        ),
        item(0, Icons.devices_rounded, 'دستگاه‌های من'),
        item(1, Icons.history_rounded, 'اخیر و علاقه‌مندی‌ها'),
        item(2, Icons.menu_book_rounded, 'راهنما'),
        Spacer(),
        item(4, _dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            _dark ? 'تم روشن' : 'تم تیره'),
        item(5, Icons.language_rounded, 'زبان / Language'),
        item(3, Icons.info_outline_rounded, 'درباره'),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    _dark = Theme.of(context).brightness == Brightness.dark;
    final body = _tab == 1
        ? Directionality(
            textDirection: TextDirection.ltr, child: ConnectionPage())
        : SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: _tab == 2
                ? _guide()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _installBar(),
                      LayoutBuilder(builder: (ctx, cs) {
                        final wide = cs.maxWidth > 760;
                        final a = _identity();
                        final b = _quickConnect();
                        return wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 5, child: a),
                                  SizedBox(width: 14),
                                  Expanded(flex: 6, child: b),
                                ],
                              )
                            : Column(children: [
                                a,
                                SizedBox(height: 14),
                                b,
                              ]);
                      }),
                      SizedBox(height: 22),
                      _devicesView(),
                    ],
                  ),
          );
    if (_tab == 4 || _tab == 5) {
      final t = _tab;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        setState(() => _tab = 0);
        if (t == 4) {
          await MyTheme.changeDarkMode(
              _dark ? ThemeMode.light : ThemeMode.dark);
        } else {
          final cur = bind.mainGetLocalOption(key: 'lang');
          final next = (cur == 'en') ? 'fa' : 'en';
          await bind.mainSetLocalOption(key: 'lang', value: next);
          await reloadAllWindows();
          bind.mainChangeLanguage(lang: next);
        }
      });
    }
    if (_tab == 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _tab = 0);
          _about();
        }
      });
    }
    final base = Theme.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: base.copyWith(
          colorScheme: base.colorScheme.copyWith(
            primary: _dark ? Colors.white : const Color(0xFF111827),
            onPrimary: _dark ? const Color(0xFF111827) : Colors.white,
          ),
        ),
        child: Container(
          color: bg,
          child: Column(children: [
            Expanded(
              child: Row(children: [
                _nav(),
                VerticalDivider(width: 1, color: line),
                Expanded(child: body),
              ]),
            ),
            _statusBar(),
          ]),
        ),
      ),
    );
  }

  Widget _statusBar() {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
          color: card, border: Border(top: BorderSide(color: line))),
      child: Obx(() {
        final st = stateGlobal.svcStatus.value;
        final ok = st == SvcStatus.ready;
        final txt = ok
            ? 'متصل به سرور FloDesk'
            : (st == SvcStatus.connecting
                ? 'در حال اتصال به سرور…'
                : 'عدم اتصال به سرور');
        final col = ok
            ? const Color(0xFF34D399)
            : (st == SvcStatus.connecting
                ? const Color(0xFFFBBF24)
                : const Color(0xFFF87171));
        return Row(children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(txt, style: TextStyle(fontSize: 12, color: muted)),
          const Spacer(),
          Text('FloDesk', style: TextStyle(fontSize: 12, color: muted)),
        ]);
      }),
    );
  }
}
