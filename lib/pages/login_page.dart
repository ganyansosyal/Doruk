import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _kayitModu = false;
  bool _busy = false;
  bool _goz1 = false, _goz2 = false, _goz3 = false;
  String _err = '';
  String _ok = '';

  final _gKul = TextEditingController();
  final _gSifre = TextEditingController();
  final _kKul = TextEditingController();
  final _kMail = TextEditingController();
  final _kSifre = TextEditingController();
  final _kSifre2 = TextEditingController();

  @override
  void initState() {
    super.initState();
    _err = AuthService.notice.value;
  }

  @override
  void dispose() {
    for (final c in [_gKul, _gSifre, _kKul, _kMail, _kSifre, _kSifre2]) {
      c.dispose();
    }
    super.dispose();
  }

  void _setTab(bool kayit) => setState(() {
        _kayitModu = kayit;
        _err = '';
        _ok = '';
      });

  Future<void> _giris() async {
    setState(() { _busy = true; _err = ''; _ok = ''; });
    final err = await AuthService.giris(_gKul.text, _gSifre.text);
    if (!mounted) return;
    setState(() { _busy = false; _err = err ?? ''; });
    // Başarılıysa router otomatik ana sayfaya yönlendirir
  }

  Future<void> _kayit() async {
    setState(() { _busy = true; _err = ''; _ok = ''; });
    final err = await AuthService.kayit(
      kullaniciRaw: _kKul.text,
      emailRaw: _kMail.text,
      sifre: _kSifre.text,
      sifre2: _kSifre2.text,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() { _busy = false; _err = err; });
      return;
    }
    setState(() { _ok = '✓ Kayıt başarılı! Giriş yapılıyor...'; });
    await Future.delayed(const Duration(milliseconds: 1200));
    final e2 = await AuthService.giris(_kKul.text, _kSifre.text);
    if (!mounted) return;
    setState(() { _busy = false; _ok = ''; _err = e2 ?? ''; });
  }

  Future<void> _unuttum() async {
    if (_gKul.text.trim().isEmpty) {
      setState(() { _err = 'Önce kullanıcı adını yaz'; _ok = ''; });
      return;
    }
    setState(() { _busy = true; _err = ''; _ok = ''; });
    final (ok, msg) = await AuthService.sifreSifirla(_gKul.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) { _ok = msg; } else { _err = msg; }
    });
  }

  InputDecoration _dec(String hint, {Widget? suffix}) => InputDecoration(
        hintText: hint,
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kAccent.withOpacity(0.2))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kAccent.withOpacity(0.2))),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: kTextDim)),
      );

  Widget _pass(TextEditingController c, bool show, VoidCallback toggle, String hint) => TextField(
        controller: c,
        obscureText: !show,
        autocorrect: false,
        decoration: _dec(hint, suffix: IconButton(icon: Icon(show ? Icons.visibility : Icons.visibility_off, size: 20), onPressed: toggle)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Center(child: Text('D', style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: kAccent))),
                    const Center(child: Text('DORUK', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 10, color: kAccent2))),
                    const Center(child: Text('PİYASA TAKİP', style: TextStyle(fontSize: 10, letterSpacing: 3, color: kTextDim))),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(child: _tab('GİRİŞ YAP', !_kayitModu, () => _setTab(false))),
                      const SizedBox(width: 8),
                      Expanded(child: _tab('KAYIT OL', _kayitModu, () => _setTab(true))),
                    ]),
                    if (!_kayitModu) ..._girisForm() else ..._kayitForm(),
                    if (_err.isNotEmpty)
                      Padding(padding: const EdgeInsets.only(top: 12), child: Text(_err, textAlign: TextAlign.center, style: const TextStyle(color: kDown, fontSize: 12))),
                    if (_ok.isNotEmpty)
                      Padding(padding: const EdgeInsets.only(top: 12), child: Text(_ok, textAlign: TextAlign.center, style: const TextStyle(color: kUp, fontSize: 12))),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(String t, bool active, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: active ? kAccent.withOpacity(0.16) : Colors.white.withOpacity(0.03),
            border: Border.all(color: active ? kAccent : Colors.transparent),
          ),
          child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1, color: active ? kAccent : kTextDim)),
        ),
      );

  List<Widget> _girisForm() => [
        _label('KULLANICI ADI'),
        TextField(controller: _gKul, autocorrect: false, textCapitalization: TextCapitalization.none, decoration: _dec('kullanici_adi')),
        _label('ŞİFRE'),
        _pass(_gSifre, _goz1, () => setState(() => _goz1 = !_goz1), '••••••••'),
        const SizedBox(height: 16),
        FilledButton(onPressed: _busy ? null : _giris, child: Text(_busy ? 'GİRİŞ YAPILIYOR...' : 'GİRİŞ YAP')),
        const SizedBox(height: 10),
        Center(child: TextButton(onPressed: _busy ? null : _unuttum, child: const Text('Şifremi Unuttum'))),
      ];

  List<Widget> _kayitForm() => [
        _label('KULLANICI ADI'),
        TextField(controller: _kKul, autocorrect: false, textCapitalization: TextCapitalization.none, decoration: _dec('kullanici_adi')),
        _label('E-POSTA'),
        TextField(controller: _kMail, autocorrect: false, keyboardType: TextInputType.emailAddress, decoration: _dec('ornek@gmail.com')),
        _label('ŞİFRE'),
        _pass(_kSifre, _goz2, () => setState(() => _goz2 = !_goz2), 'En az 6 karakter'),
        _label('ŞİFRE TEKRAR'),
        _pass(_kSifre2, _goz3, () => setState(() => _goz3 = !_goz3), '••••••••'),
        const SizedBox(height: 16),
        FilledButton(onPressed: _busy ? null : _kayit, child: Text(_busy ? 'KAYIT YAPILIYOR...' : 'KAYIT OL')),
      ];
}
