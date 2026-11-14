// FloDesk: Persian RTL home dashboard for apparel businesses.
// Copied to flutter/lib/desktop/pages/flodesk_home.dart by flodesk/rebrand.sh
// and wired into DesktopHomePage.build() by a one-line patch (see rebrand.sh).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/connection_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_tab_page.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
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
  static const accent = Color(0xFF7C6CFF);
  Color get bg => _dark ? Color(0xFF0B0C10) : Color(0xFFF6F7FB);
  Color get card => _dark ? Color(0xFF14161C) : Colors.white;
  Color get card2 => _dark ? Color(0xFF1B1E26) : Color(0xFFF0F1F6);
  Color get line => _dark ? Color(0xFF262A34) : Color(0xFFE6E8EF);
  Color get muted => _dark ? Color(0xFF9AA1AF) : Color(0xFF6B7280);
  Color get fg => _dark ? Colors.white : Color(0xFF0F172A);

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

  Widget _surface({required Widget child, EdgeInsets? pad, Color? color}) =>
      Container(
        padding: pad ?? EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color ?? card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: line),
        ),
        child: child,
      );

  Widget _iconBtn(IconData ic, String tip, VoidCallback onTap) => Tooltip(
        message: tip,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: line)),
            child: Icon(ic, size: 20, color: fg),
          ),
        ),
      );

  Widget _statusPill() {
    return Obx(() {
      final st = stateGlobal.svcStatus.value;
      final ok = st == SvcStatus.ready;
      final txt = ok
          ? 'آنلاین'
          : (st == SvcStatus.connecting ? 'در حال اتصال…' : 'آفلاین');
      final col = ok
          ? Color(0xFF34D399)
          : (st == SvcStatus.connecting ? Color(0xFFFBBF24) : Color(0xFFF87171));
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: col.withOpacity(0.14),
            borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
          SizedBox(width: 8),
          Text(txt,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: col)),
        ]),
      );
    });
  }

  Widget _offlineHint() {
    return Obx(() {
      if (stateGlobal.svcStatus.value == SvcStatus.ready) {
        return SizedBox.shrink();
      }
      return Container(
        margin: EdgeInsets.only(top: 14),
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Color(0xFFF87171).withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Color(0xFFF87171).withOpacity(0.35))),
        child: Row(children: [
          Icon(Icons.wifi_off_rounded, color: Color(0xFFF87171)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
                'اتصال به سرور برقرار نیست. اینترنت و فایروال را بررسی کنید، یا آدرس و کلید سرور را در تنظیمات ← شبکه بررسی کنید.',
                style: TextStyle(fontSize: 12.5, height: 1.8, color: fg)),
          ),
          SizedBox(width: 8),
          TextButton(
              onPressed: () => DesktopTabPage.onAddSetting(
                  initialPage: SettingsTabKey.network),
              child: Text('تنظیمات شبکه')),
        ]),
      );
    });
  }

  Widget _hero() {
    final model = gFFI.serverModel;
    final showOneTime = model.approveMode != 'click' &&
        model.verificationMethod != kUsePermanentPassword;
    Widget label(String t) =>
        Text(t, style: TextStyle(color: muted, fontSize: 12.5));
    return Container(
      padding: EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: line),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: _dark
              ? [Color(0xFF1B1840), Color(0xFF14161C)]
              : [Color(0xFFECE9FF), Colors.white],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('هویت این دستگاه',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: fg)),
          SizedBox(width: 12),
          _statusPill(),
        ]),
        SizedBox(height: 4),
        Text('برای دریافت پشتیبانی، شناسه و رمز را به پشتیبان بگویید.',
            style: TextStyle(color: muted, fontSize: 12.5)),
        SizedBox(height: 18),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            flex: 6,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  label('شناسه'),
                  SizedBox(height: 2),
                  AnimatedBuilder(
                    animation: model.serverId,
                    builder: (_, __) => InkWell(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: model.serverId.text));
                        showToast('شناسه کپی شد');
                      },
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(
                              model.serverId.text.isEmpty
                                  ? '··· ··· ···'
                                  : model.serverId.text,
                              style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                  color: fg)),
                          SizedBox(width: 10),
                          Icon(Icons.copy_rounded, size: 18, color: muted),
                        ]),
                      ),
                    ),
                  ),
                ]),
          ),
          Expanded(
            flex: 4,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  label(showOneTime ? 'رمز یک‌بارمصرف' : 'رمز دسترسی'),
                  SizedBox(height: 6),
                  AnimatedBuilder(
                    animation: model.serverPasswd,
                    builder: (_, __) => Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        InkWell(
                          onTap: () {
                            Clipboard.setData(
                                ClipboardData(text: model.serverPasswd.text));
                            showToast('رمز کپی شد');
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                                color: card2,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: line)),
                            child: Text(
                                model.approveMode == 'click'
                                    ? 'تأیید دستی'
                                    : (model.serverPasswd.text.isEmpty
                                        ? '······'
                                        : model.serverPasswd.text),
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5,
                                    color: fg)),
                          ),
                        ),
                        if (showOneTime) SizedBox(width: 6),
                        if (showOneTime)
                          IconButton(
                              tooltip: 'رمز جدید',
                              onPressed: () =>
                                  bind.mainUpdateTemporaryPassword(),
                              icon: Icon(Icons.refresh_rounded, color: fg)),
                      ]),
                    ),
                  ),
                ]),
          ),
        ]),
        _offlineHint(),
      ]),
    );
  }

  Widget _quickConnect() {
    return _surface(
      pad: EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Row(children: [
        Icon(Icons.bolt_rounded, color: accent, size: 24),
        SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _quickId,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.number,
            onSubmitted: _connect,
            style: TextStyle(fontSize: 22, letterSpacing: 2, color: fg),
            decoration: InputDecoration(
              hintText: 'اتصال سریع: شناسه‌ی دستگاه مقصد',
              hintTextDirection: TextDirection.rtl,
              hintStyle:
                  TextStyle(fontSize: 14, letterSpacing: 0, color: muted),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
          ),
        ),
        Tooltip(
          message: 'ذخیره در دستگاه‌های من',
          child: IconButton(
              onPressed: () => _editDevice(prefillId: _quickId.text),
              icon: Icon(Icons.bookmark_add_outlined, color: fg)),
        ),
        SizedBox(width: 4),
        FilledButton.icon(
          onPressed: () => _connect(_quickId.text),
          style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              minimumSize: Size(120, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14))),
          icon: Icon(Icons.cast_connected_rounded, size: 20),
          label: Text('اتصال',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ),
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
        color: accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.4)),
      ),
      child: Row(children: [
        Icon(Icons.shield_outlined, color: accent),
        SizedBox(width: 10),
        Expanded(
          child: Text(
              'برای کار پایدار در حالت پشتیبانی (و دسترسی به پنجره‌های مدیر ویندوز)، FloDesk را نصب کنید.',
              style: TextStyle(fontSize: 12.5, height: 1.7, color: fg)),
        ),
        TextButton(
            onPressed: () => setState(() => _hideInstall = true),
            child: Text('بعداً')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: accent, foregroundColor: Colors.white),
          onPressed: () async {
            await rustDeskWinManager.closeAllSubWindows();
            bind.mainGotoInstall();
          },
          child: Text('نصب'),
        ),
      ]),
    );
  }

  Widget _chip(String t, bool sel, VoidCallback onTap, {IconData? ic, Color? c}) {
    return Padding(
      padding: EdgeInsetsDirectional.only(end: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? accent : card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sel ? accent : line),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (ic != null) Icon(ic, size: 16, color: sel ? Colors.white : c),
            if (ic != null) SizedBox(width: 6),
            Text(t,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : fg)),
          ]),
        ),
      ),
    );
  }

  Widget _devicesView() {
    final list = _filter == 'all'
        ? _devices
        : _devices.where((d) => d.cat == _filter).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('دستگاه‌های من',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: fg)),
        Spacer(),
        OutlinedButton.icon(
          onPressed: () => _editDevice(),
          style: OutlinedButton.styleFrom(
              foregroundColor: fg,
              side: BorderSide(color: line),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14))),
          icon: Icon(Icons.add_rounded, size: 20),
          label: Text('افزودن دستگاه'),
        ),
      ]),
      SizedBox(height: 14),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _chip('همه (${_devices.length})', _filter == 'all',
              () => setState(() => _filter = 'all')),
          for (final c in _cats)
            _chip(c.label, _filter == c.key,
                () => setState(() => _filter = c.key),
                ic: c.icon, c: c.color),
        ]),
      ),
      SizedBox(height: 16),
      if (list.isEmpty)
        _surface(
          pad: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Center(
            child: Column(children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    color: accent.withOpacity(0.14), shape: BoxShape.circle),
                child: Icon(Icons.devices_other_rounded,
                    size: 32, color: accent),
              ),
              SizedBox(height: 14),
              Text(
                  _devices.isEmpty
                      ? 'هنوز دستگاهی اضافه نکرده‌اید'
                      : 'دستگاهی در این دسته نیست',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: fg)),
              SizedBox(height: 6),
              Text(
                  'صندوق‌ها، انبار، دفتر و سالن تولید را با نام دلخواه اضافه کنید تا با یک کلیک وصل شوید.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, height: 1.8, fontSize: 12.5)),
              SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _editDevice(),
                style: FilledButton.styleFrom(
                    backgroundColor: accent, foregroundColor: Colors.white),
                icon: Icon(Icons.add_rounded),
                label: Text('افزودن اولین دستگاه'),
              ),
            ]),
          ),
        )
      else
        Wrap(spacing: 14, runSpacing: 14, children: [
          for (final d in list) _deviceCard(d),
        ]),
    ]);
  }

  Widget _deviceCard(_Device d) {
    final c = _catOf(d.cat);
    return Container(
      width: 262,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: c.color.withOpacity(0.16),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(c.icon, color: c.color, size: 24),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14, color: fg)),
                  Text(c.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, fontSize: 11.5)),
                ]),
          ),
          PopupMenuButton<String>(
            tooltip: 'گزینه‌ها',
            icon: Icon(Icons.more_horiz_rounded, color: muted),
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
        SizedBox(height: 14),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(d.id,
              style: TextStyle(
                  fontSize: 19,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                  color: fg)),
        ),
        SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _connect(d.id),
              style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  minimumSize: Size(0, 44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              icon: Icon(Icons.cast_connected_rounded, size: 18),
              label: Text('اتصال',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          SizedBox(width: 8),
          Tooltip(
            message: 'انتقال فایل',
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _connect(d.id, file: true),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: card2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: line)),
                child: Icon(Icons.folder_open_rounded, color: fg, size: 20),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _guide() {
    Widget step(int n, String t, String s) => Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration:
                  BoxDecoration(color: accent, shape: BoxShape.circle),
              child: Text('$n',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t,
                        style:
                            TextStyle(fontWeight: FontWeight.w800, color: fg)),
                    SizedBox(height: 3),
                    Text(s,
                        style: TextStyle(
                            color: muted, fontSize: 12.5, height: 1.8)),
                  ]),
            ),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('راهنمای دریافت پشتیبانی (برای صندوق‌دار و مشتری)',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: fg)),
          SizedBox(height: 16),
          step(1, 'FloDesk را باز کنید',
              'در صفحه‌ی اصلی، شناسه (عدد بزرگ) و رمز یک‌بارمصرف را می‌بینید.'),
          step(2, 'شناسه و رمز را به پشتیبان بدهید',
              'با کلیک روی هر کدام کپی می‌شود؛ از طریق تلفن یا پیام‌رسان بفرستید.'),
          step(3, 'اتصال را تأیید کنید',
              'اگر پنجره‌ی درخواست اتصال آمد، «پذیرفتن» را بزنید.'),
          step(4, 'پایان جلسه',
              'هر زمان خواستید پنجره‌ی جلسه را ببندید؛ رمز بعد از هر جلسه عوض می‌شود.'),
        ]),
      ),
      SizedBox(height: 14),
      _surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('نکته‌های امنیتی',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: fg)),
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

  Widget _header() {
    Widget tab(int i, IconData ic, String t) {
      final sel = _tab == i;
      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _tab = i),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
              color: sel ? accent : Colors.transparent,
              borderRadius: BorderRadius.circular(14)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(ic, size: 18, color: sel ? Colors.white : muted),
            SizedBox(width: 8),
            Text(t,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : fg)),
          ]),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Row(children: [
        Image.asset('assets/flodesk_logo.png',
            width: 36,
            height: 36,
            errorBuilder: (_, __, ___) => SizedBox(width: 36)),
        SizedBox(width: 10),
        Text('FloDesk',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900, color: fg)),
        SizedBox(width: 24),
        Container(
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: line)),
          child: Row(children: [
            tab(0, Icons.devices_rounded, 'دستگاه‌ها'),
            tab(1, Icons.history_rounded, 'اخیر'),
            tab(2, Icons.menu_book_rounded, 'راهنما'),
          ]),
        ),
        Spacer(),
        _iconBtn(_dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            _dark ? 'تم روشن' : 'تم تیره', () async {
          await MyTheme.changeDarkMode(_dark ? ThemeMode.light : ThemeMode.dark);
        }),
        SizedBox(width: 8),
        _iconBtn(Icons.language_rounded, 'زبان / Language', () async {
          final cur = bind.mainGetLocalOption(key: 'lang');
          final next = (cur == 'en') ? 'fa' : 'en';
          await bind.mainSetLocalOption(key: 'lang', value: next);
          await reloadAllWindows();
          bind.mainChangeLanguage(lang: next);
        }),
        SizedBox(width: 8),
        _iconBtn(Icons.info_outline_rounded, 'درباره', _about),
        SizedBox(width: 8),
        _iconBtn(Icons.settings_rounded, 'تنظیمات',
            () => DesktopTabPage.onAddSetting()),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    _dark = Theme.of(context).brightness == Brightness.dark;
    final base = Theme.of(context);
    final Widget body = _tab == 1
        ? Directionality(
            textDirection: TextDirection.ltr, child: ConnectionPage())
        : SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: _tab == 2
                ? _guide()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _installBar(),
                      _hero(),
                      SizedBox(height: 14),
                      _quickConnect(),
                      SizedBox(height: 26),
                      _devicesView(),
                    ],
                  ),
          );
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: base.copyWith(
          colorScheme: base.colorScheme.copyWith(
            primary: accent,
            onPrimary: Colors.white,
          ),
        ),
        child: Container(
          color: bg,
          child: Column(children: [
            _header(),
            Expanded(child: body),
          ]),
        ),
      ),
    );
  }
}
