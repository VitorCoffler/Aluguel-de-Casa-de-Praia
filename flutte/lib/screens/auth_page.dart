import 'package:flutter/material.dart';
import '../services/api.dart';
import '../widgets/common.dart';

Future<bool> exigirLogin(BuildContext context, {bool anfitriao = false}) async {
  if (api.usuario != null) return true;
  return await Navigator.push<bool>(context, MaterialPageRoute(
    builder: (_) => AuthPage(anfitriao: anfitriao),
  )) ?? false;
}

class AuthPage extends StatefulWidget {
  final bool anfitriao;
  const AuthPage({super.key, this.anfitriao = false});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _codigo = TextEditingController();
  String _modo = 'login';
  bool _busy = false;
  bool _ocultar = true;
  String? _erro;
  @override
  void dispose() { for (final c in [_nome, _email, _senha, _codigo]) { c.dispose(); } super.dispose(); }

  Future<void> _enviar() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _erro = null; });
    try {
      if (_modo == 'login' || _modo == 'register') {
        await api.autenticar('/auth/$_modo', {
          'email': _email.text.trim(), 'password': _senha.text,
          if (_modo == 'register') 'name': _nome.text.trim(),
        });
        if (mounted) Navigator.pop(context, true);
      } else if (_modo == 'forgot') {
        final result = await api.request('POST', '/auth/forgot', {'email': _email.text.trim()});
        if (!mounted) return;
        avisar(context, result['message']!);
        setState(() => _modo = 'reset');
      } else {
        final result = await api.request('POST', '/auth/reset', {'token': _codigo.text.trim(), 'password': _senha.text});
        if (!mounted) return;
        avisar(context, result['message']!);
        _senha.clear();
        setState(() => _modo = 'login');
      }
    } catch (e) { if (mounted) setState(() => _erro = '$e'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final cadastro = _modo == 'register', recuperar = _modo == 'forgot', reset = _modo == 'reset';
    final title = cadastro ? 'Crie sua conta' : recuperar || reset ? 'Recuperar acesso' : widget.anfitriao ? 'Sua casa, novas histórias.' : 'Sua próxima pausa começa aqui.';
    return Scaffold(
      appBar: AppBar(title: const Text('Casa da Praia')),
      body: SingleChildScrollView(child: Conteudo(width: 520, child: Card(child: Padding(
        padding: const EdgeInsets.all(28), child: Form(key: _form, child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(Icons.waves_rounded, size: 48, color: oceano),
            const SizedBox(height: 24), Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12), const Text('Uma conta para viajar e anunciar. Você escolhe como usar.'),
            const SizedBox(height: 28),
            if (cadastro) ...[
              TextFormField(controller: _nome, decoration: const InputDecoration(labelText: 'Nome completo'),
                validator: (v) => (v?.trim().length ?? 0) < 2 ? 'Informe seu nome.' : null),
              const SizedBox(height: 16),
            ],
            if (!reset) ...[
              TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, autocorrect: false,
                decoration: const InputDecoration(labelText: 'E-mail'),
                validator: (v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v?.trim() ?? '') ? null : 'Informe um e-mail válido.'),
              const SizedBox(height: 16),
            ],
            if (reset) ...[
              TextFormField(controller: _codigo, decoration: const InputDecoration(labelText: 'Código de recuperação'),
                validator: (v) => v?.trim().length == 64 ? null : 'Cole o código completo.'),
              const SizedBox(height: 16),
            ],
            if (!recuperar) TextFormField(controller: _senha, obscureText: _ocultar,
              decoration: InputDecoration(labelText: reset ? 'Nova senha' : 'Senha', helperText: cadastro || reset ? 'No mínimo 10 caracteres' : null,
                suffixIcon: IconButton(tooltip: 'Mostrar ou ocultar senha', onPressed: () => setState(() => _ocultar = !_ocultar), icon: Icon(_ocultar ? Icons.visibility_outlined : Icons.visibility_off_outlined))),
              validator: (v) => (v?.length ?? 0) < (cadastro || reset ? 10 : 1) ? 'Confira sua senha.' : null,
              onFieldSubmitted: (_) { if (!_busy) _enviar(); }),
            if (_erro != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_erro!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            const SizedBox(height: 24),
            FilledButton(onPressed: _busy ? null : _enviar, child: Text(_busy ? 'Aguarde…' : cadastro ? 'Criar conta' : recuperar ? 'Solicitar código' : reset ? 'Salvar nova senha' : 'Entrar')),
            if (_modo == 'login') TextButton(onPressed: _busy ? null : () => setState(() { _modo = 'forgot'; _erro = null; }), child: const Text('Esqueci minha senha')),
            TextButton(onPressed: _busy ? null : () => setState(() { _modo = _modo == 'login' ? 'register' : 'login'; _erro = null; }), child: Text(_modo == 'login' ? 'Ainda não tenho conta' : 'Voltar para o login')),
            if (recuperar) TextButton(onPressed: _busy ? null : () => setState(() => _modo = 'reset'), child: const Text('Já tenho um código')),
          ],
        )),
      )))),
    );
  }
}
