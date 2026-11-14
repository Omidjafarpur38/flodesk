// FloDesk: Persian RTL Android home (apparel business). Copied to
// flutter/lib/mobile/pages/flodesk_mobile_home.dart by flodesk/rebrand.sh and
// wired into the mobile ConnectionPage.build() by a small patch.
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/peer_tab_page.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:get/get.dart';

const _kDevicesKey = 'flodesk-devices-v1';
const _kPwKey = 'flodesk-fixed-pw-v1';
const _kPwInitKey = 'flodesk-fixed-pw-init-v1';

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
  _Cat('sewing', 'سالن تولید', Icons.content_cut_rounded, Color(0xFFBA68C8)),
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

class FloDeskMobileHome extends StatefulWidget {
  const FloDeskMobileHome({Key? key}) : super(key: key);
  @override
  State<FloDeskMobileHome> createState() => _FloDeskMobileHomeState();
}

class _FloDeskMobileHomeState extends State<FloDeskMobileHome> {
  bool _dark = true;
  static const accent = Color(0xFF7C6CFF);
  Color get bg => _dark ? Color(0xFF0B0C10) : Color(0xFFF6F7FB);
  Color get card => _dark ? Color(0xFF14161C) : Colors.white;
  Color get line => _dark ? Color(0xFF262A34) : Color(0xFFE6E8EF);
  Color get muted => _dark ? Color(0xFF9AA1AF) : Color(0xFF6B7280);

  final _quickId = TextEditingController();
  List<_Device> _devices = [];
  String _filter = 'all';
  int _tab = 0; // 0 devices, 1 recent, 2 guide
  String _fixedPw = '';

  @override
  void initState() {
    super.initState();
    _initPassword();
    try {
      final raw = bind.mainGetLocalOption(key: _kDevicesKey);
      if (raw.isNotEmpty) {
        _devices = (jsonDecode(raw) as List)
            .map((e) => _Device('${e['id']}', '${e['name']}', '${e['cat']}'))
            .toList();
      }
    } catch (_) {
      _devices = [];
    }
  }

  @override
  void dispose() {
    _quickId.dispose();
    super.dispose();
  }

  String _randomPw() {
    const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
    final r = Random.secure();
    return List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
  }

  // Fixed (permanent) password: set once, changes only when the user asks.
  Future<void> _initPassword() async {
    try {
      var pw = bind.mainGetLocalOption(key: _kPwKey);
      if (bind.mainGetLocalOption(key: _kPwInitKey) != '1') {
        await bind.mainSetOption(
            key: kOptionVerificationMethod, value: kUsePermanentPassword);
        await bind.mainSetLocalOption(key: _kPwInitKey, value: '1');
      }
      if (pw.isEmpty) {
        final np = _randomPw();
        if (await bind.mainSetPermanentPasswordWithResult(password: np)) {
          pw = np;
          await bind.mainSetLocalOption(key: _kPwKey, value: pw);
        }
      }
      if (mounted) setState(() => _fixedPw = pw);
    } catch (_) {}
  }

  Future<void> _changePassword() async {
    final c = TextEditingController();
    String err = '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            backgroundColor: card,
            scrollable: true,
            title: Text('تغییر رمز ثابت'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                  'رمز فعلی تا وقتی خودتان تغییرش ندهید ثابت می‌ماند. رمز جدید حداقل ۶ نویسه باشد.',
                  style: TextStyle(fontSize: 12.5, height: 1.8, color: muted)),
              SizedBox(height: 12),
              TextField(
                controller: c,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                    labelText: 'رمز جدید',
                    errorText: err.isEmpty ? null : err),
              ),
              SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                    onPressed: () => setS(() => c.text = _randomPw()),
                    icon: Icon(Icons.casino_outlined, size: 18),
                    label: Text('رمز تصادفی')),
              ),
            ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('انصراف')),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: accent, foregroundColor: Colors.white),
                onPressed: () async {
                  final np = c.text.trim();
                  if (np.length < 6) {
                    setS(() => err = 'حداقل ۶ نویسه');
                    return;
                  }
                  final ok = await bind.mainSetPermanentPasswordWithResult(
                      password: np);
                  if (!ok) {
                    setS(() => err = 'ثبت رمز ناموفق بود');
                    return;
                  }
                  await bind.mainSetLocalOption(key: _kPwKey, value: np);
                  await bind.mainSetOption(
                      key: kOptionVerificationMethod,
                      value: kUsePermanentPassword);
                  if (mounted) setState(() => _fixedPw = np);
                  Navigator.pop(ctx);
                  showToast('رمز ثابت تغییر کرد');
                },
                child: Text('ذخیره'),
              ),
            ],
          ),
        ),
      ),
    );
  }


  String _digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  Future<void> _save() async {
    await bind.mainSetLocalOption(
        key: _kDevicesKey,
        value: jsonEncode(_devices.map((d) => d.toJson()).toList()));
    if (mounted) setState(() {});
  }

  void _connect(String id, {bool file = false}) {
    final d = _digits(id);
    if (d.isEmpty) {
      showToast('شناسه‌ی دستگاه را وارد کنید');
      return;
    }
    connect(context, d, isFileTransfer: file);
  }

  Future<void> _edit({_Device? dev, String? prefillId}) async {
    final name = TextEditingController(text: dev?.name ?? '');
    final id = TextEditingController(text: dev?.id ?? prefillId ?? '');
    String cat = dev?.cat ?? 'pos';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            backgroundColor: card,
            scrollable: true,
            title: Text(dev == null ? 'افزودن دستگاه' : 'ویرایش دستگاه'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: name,
                  decoration: InputDecoration(labelText: 'نام دلخواه')),
              SizedBox(height: 10),
              TextField(
                  controller: id,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'شناسه‌ی دستگاه')),
              SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in _cats)
                  ChoiceChip(
                    avatar: Icon(c.icon, size: 18, color: c.color),
                    label: Text(c.label),
                    selected: cat == c.key,
                    onSelected: (_) => setS(() => cat = c.key),
                  ),
              ]),
            ]),
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
    if (ok == true && nid.isNotEmpty) {
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

  Future<void> _delete(_Device d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: card,
          title: Text('حذف دستگاه'),
          content: Text('«${d.name}» از فهرست حذف شود؟'),
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

  Widget _box({required Widget child}) => Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: line)),
        child: child,
      );

  Widget _identity() {
    final m = gFFI.serverModel;
    return _box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('شناسه‌ی این گوشی (برای دریافت پشتیبانی)',
                style: TextStyle(color: muted, fontSize: 12)),
          ),
          Obx(() {
            final st = stateGlobal.svcStatus.value;
            final ok = st == SvcStatus.ready;
            final col = ok
                ? Color(0xFF34D399)
                : (st == SvcStatus.connecting
                    ? Color(0xFFFBBF24)
                    : Color(0xFFF87171));
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: col.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(
                  ok ? 'آنلاین' : (st == SvcStatus.connecting ? 'در حال اتصال' : 'آفلاین'),
                  style: TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w700, color: col)),
            );
          }),
        ]),
        SizedBox(height: 6),
        AnimatedBuilder(
          animation: m.serverId,
          builder: (_, __) => InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: m.serverId.text));
              showToast('شناسه کپی شد');
            },
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(children: [
                Text(m.serverId.text.isEmpty ? '···' : m.serverId.text,
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2)),
                SizedBox(width: 8),
                Icon(Icons.copy_rounded, size: 17, color: muted),
              ]),
            ),
          ),
        ),
        SizedBox(height: 10),
        Row(children: [
          Text('رمز ثابت: ', style: TextStyle(color: muted, fontSize: 12)),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _fixedPw));
              showToast('رمز کپی شد');
            },
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(_fixedPw.isEmpty ? '······' : _fixedPw,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5)),
            ),
          ),
          Spacer(),
          TextButton.icon(
              onPressed: _changePassword,
              icon: Icon(Icons.edit_rounded, size: 16),
              label: Text('تغییر رمز')),
        ]),
        SizedBox(height: 4),
        Text('برای اشتراک صفحه، به تب «اشتراک صفحه» بروید و سرویس را روشن کنید.',
            style: TextStyle(color: muted, fontSize: 11.5, height: 1.7)),
      ]),
    );
  }

  Widget _quick() {
    return _box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('اتصال سریع',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _quickId,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.number,
              onSubmitted: _connect,
              style: TextStyle(fontSize: 18, letterSpacing: 1.5),
              decoration: InputDecoration(
                hintText: 'شناسه‌ی مقصد',
                hintTextDirection: TextDirection.rtl,
                filled: true,
                fillColor: bg,
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: line)),
              ),
            ),
          ),
          IconButton(
              tooltip: 'ذخیره در دستگاه‌های من',
              onPressed: () => _edit(prefillId: _quickId.text),
              icon: Icon(Icons.bookmark_add_outlined)),
          FilledButton(
              onPressed: () => _connect(_quickId.text),
              child: Text('اتصال')),
        ]),
      ]),
    );
  }

  Widget _deviceTile(_Device d) {
    final c = _catOf(d.cat);
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: line)),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: c.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(c.icon, color: c.color),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold)),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(d.id,
                  style: TextStyle(color: muted, letterSpacing: 1.2)),
            ),
            Text(c.label, style: TextStyle(color: muted, fontSize: 11)),
          ]),
        ),
        FilledButton(
            onPressed: () => _connect(d.id), child: Text('اتصال')),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: muted),
          onSelected: (v) {
            if (v == 'file') _connect(d.id, file: true);
            if (v == 'edit') _edit(dev: d);
            if (v == 'del') _delete(d);
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'file', child: Text('انتقال فایل')),
            PopupMenuItem(value: 'edit', child: Text('ویرایش')),
            PopupMenuItem(value: 'del', child: Text('حذف')),
          ],
        ),
      ]),
    );
  }

  Widget _devicesView() {
    final list = _filter == 'all'
        ? _devices
        : _devices.where((d) => d.cat == _filter).toList();
    return ListView(
      padding: EdgeInsets.only(bottom: 24),
      children: [
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
                  avatar: Icon(c.icon, size: 16, color: c.color),
                  label: Text(c.label),
                  selected: _filter == c.key,
                  onSelected: (_) => setState(() => _filter = c.key),
                ),
              ),
          ]),
        ),
        SizedBox(height: 12),
        if (list.isEmpty)
          _box(
            child: Column(children: [
              SizedBox(height: 14),
              Icon(Icons.devices_other_rounded, size: 40, color: muted),
              SizedBox(height: 10),
              Text(
                  _devices.isEmpty
                      ? 'هنوز دستگاهی اضافه نکرده‌اید'
                      : 'دستگاهی در این دسته نیست',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text(
                  'صندوق‌ها، انبار، دفتر و سالن تولید را با نام دلخواه اضافه کنید.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 12, height: 1.8)),
              SizedBox(height: 10),
              FilledButton.tonalIcon(
                  onPressed: () => _edit(),
                  icon: Icon(Icons.add_rounded),
                  label: Text('افزودن دستگاه')),
              SizedBox(height: 10),
            ]),
          )
        else ...[
          for (final d in list) _deviceTile(d),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
                onPressed: () => _edit(),
                icon: Icon(Icons.add_rounded),
                label: Text('افزودن دستگاه')),
          ),
        ],
      ],
    );
  }

  Widget _guide() {
    Widget step(int n, String t, String s) => Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
                radius: 13,
                backgroundColor: line,
                child: Text('$n',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t, style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(s,
                        style: TextStyle(
                            color: muted, fontSize: 12, height: 1.8)),
                  ]),
            ),
          ]),
        );
    return ListView(padding: EdgeInsets.only(bottom: 24), children: [
      _box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('دریافت پشتیبانی روی این گوشی',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          step(1, 'شناسه را بدهید',
              'شناسه‌ی بالای صفحه‌ی اصلی را به پشتیبان بگویید (با لمس کپی می‌شود).'),
          step(2, 'سرویس را روشن کنید',
              'به تب «اشتراک صفحه» بروید و «شروع سرویس» را بزنید و مجوزها را بدهید.'),
          step(3, 'اتصال را بپذیرید',
              'وقتی درخواست اتصال آمد، «پذیرفتن» را بزنید.'),
          step(4, 'پایان',
              'برای قطع، در همان تب «توقف» را بزنید.'),
        ]),
      ),
      SizedBox(height: 12),
      _box(
        child: Text(
            '• رمز یا درخواست اتصال را فقط برای کسی بپذیرید که خودتان با او تماس گرفته‌اید.\n'
            '• هرگز رمز بانکی یا کد پیامکی را در FloDesk وارد نکنید.\n'
            '• FloDesk بر پایه‌ی RustDesk و تحت مجوز AGPL-3.0 است.',
            style: TextStyle(color: muted, height: 2, fontSize: 12.5)),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    _dark = Theme.of(context).brightness == Brightness.dark;
    final base = Theme.of(context);
    Widget seg(int i, String t) => Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _tab = i),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: _tab == i ? line : Colors.transparent,
                  borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: Text(t,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          _tab == i ? FontWeight.bold : FontWeight.normal)),
            ),
          ),
        );
    final Widget content = _tab == 0
        ? _devicesView()
        : (_tab == 1
            ? Directionality(
                textDirection: TextDirection.ltr, child: PeerTabPage())
            : _guide());
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
        padding: EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: Column(children: [
          _identity(),
          SizedBox(height: 10),
          _quick(),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(3),
            decoration: BoxDecoration(
                color: card, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              seg(0, 'دستگاه‌های من'),
              seg(1, 'اخیر'),
              seg(2, 'راهنما'),
            ]),
          ),
          SizedBox(height: 12),
          Expanded(child: content),
        ]),
      ),
      ),
    );
  }
}
