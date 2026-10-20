import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/reserva.dart';
import '../services/api.dart';
import '../widgets/common.dart';

class EditHousePage extends StatefulWidget {
  final Casa? casa;
  const EditHousePage({super.key, this.casa});
  @override
  State<EditHousePage> createState() => _EditHousePageState();
}
class _EditHousePageState extends State<EditHousePage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late final TextEditingController _cidade;
  late final TextEditingController _descricao;
  late final TextEditingController _preco;
  final List<String> _fotos = [];
  final Set<String> _comodidades = {};
  final _opcoes = ['Wi-Fi', 'Piscina', 'Churrasqueira', 'Garagem', 'Ar-condicionado', 'Cozinha', 'Aceita pets', 'Vista para o mar', 'Máquina de lavar', 'Acessibilidade'];
  int _hospedes = 2;
  int _quartos = 1;
  bool _ativa = true;
  bool _busy = false;
  bool _upload = false;
  @override
  void initState() {
    super.initState(); final c = widget.casa;
    _nome = TextEditingController(text: c?.nome);
    _cidade = TextEditingController(text: c?.cidade);
    _descricao = TextEditingController(text: c?.descricao);
    _preco = TextEditingController(text: c == null ? '' : (c.diariaCentavos / 100).toStringAsFixed(2).replaceAll('.', ','));
    if (c != null) { _fotos.addAll(c.fotos); _comodidades.addAll(c.comodidades); _hospedes = c.hospedes; _quartos = c.quartos; _ativa = c.ativa; }
  }
  @override
  void dispose() { for (final c in [_nome, _cidade, _descricao, _preco]) { c.dispose(); } super.dispose(); }
  int? get _valor {
    final value = double.tryParse(_preco.text.trim().replaceAll(',', '.'));
    return value == null || !value.isFinite ? null : (value * 100).round();
  }
  Future<void> _adicionarFotos() async {
    setState(() => _upload = true);
    try {
      final files = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'], allowMultiple: true, withData: true);
      if (files == null || !mounted) return;
      if (_fotos.length + files.files.length > 10) throw const ApiException('Selecione no máximo 10 fotos no total.');
      for (final file in files.files) {
        if (file.size > 3 * 1024 * 1024 || file.bytes == null) throw const ApiException('Cada foto deve ter até 3 MB.');
      }
      for (final file in files.files) {
        final result = await api.request('POST', '/uploads', {'base64': base64Encode(file.bytes!)});
        if (!mounted) return;
        setState(() => _fotos.add(result['url'] as String));
      }
    } catch (e) { if (mounted) avisar(context, e); }
    finally { if (mounted) setState(() => _upload = false); }
  }
  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    if (_fotos.isEmpty) { avisar(context, 'Adicione pelo menos uma foto.'); return; }
    setState(() => _busy = true);
    try {
      final c = widget.casa;
      await api.request(c == null ? 'POST' : 'PUT', c == null ? '/host/houses' : '/host/houses/${c.id}', {
        'name': _nome.text.trim(), 'city': _cidade.text.trim(), 'description': _descricao.text.trim(),
        'price_cents': _valor, 'guests': _hospedes, 'bedrooms': _quartos,
        'photos': _fotos, 'amenities': _comodidades.toList(), 'active': _ativa,
      });
      if (!mounted) return;
      avisar(context, 'Anúncio salvo.'); Navigator.pop(context);
    } catch (e) { if (mounted) avisar(context, e); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.casa == null ? 'Novo anúncio' : 'Editar anúncio')),
    body: SingleChildScrollView(child: Conteudo(width: 850, child: Form(key: _form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Apresente seu lugar ao mundo', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8), const Text('Fotos claras e uma boa descrição ajudam seus hóspedes a escolher.'), const SizedBox(height: 28),
      TextFormField(controller: _nome, maxLength: 100, decoration: const InputDecoration(labelText: 'Nome da casa'), validator: (v) => (v?.trim().length ?? 0) < 3 ? 'Use pelo menos 3 caracteres.' : null),
      const SizedBox(height: 16), TextFormField(controller: _cidade, maxLength: 100, decoration: const InputDecoration(labelText: 'Cidade e estado', hintText: 'Guarapari - ES'), validator: (v) => (v?.trim().length ?? 0) < 3 ? 'Informe a cidade e o estado.' : null),
      const SizedBox(height: 16), TextFormField(controller: _descricao, minLines: 4, maxLines: 8, maxLength: 4000, decoration: const InputDecoration(labelText: 'Descrição'), validator: (v) => (v?.trim().length ?? 0) < 20 ? 'Descreva a casa com pelo menos 20 caracteres.' : null),
      const SizedBox(height: 16), TextFormField(controller: _preco, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor da diária', prefixText: 'R\$ '), validator: (_) => _valor == null || _valor! < 100 || _valor! > 10000000 ? 'Informe de R\$ 1 a R\$ 100.000.' : null),
      const SizedBox(height: 16), Wrap(spacing: 24, children: [
        Contador(label: 'Hóspedes', value: _hospedes, onChanged: (v) => setState(() => _hospedes = v)),
        Contador(label: 'Quartos', value: _quartos, max: 20, onChanged: (v) => setState(() => _quartos = v)),
      ]), const SizedBox(height: 24),
      Text('Comodidades', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: _opcoes.map((opcao) => FilterChip(label: Text(opcao), selected: _comodidades.contains(opcao), onSelected: (value) => setState(() { value ? _comodidades.add(opcao) : _comodidades.remove(opcao); }))).toList()),
      const SizedBox(height: 28), Text('Galeria de fotos', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8), const Text('De 1 a 10 imagens, até 3 MB cada. A primeira será a capa.'), const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 12, children: List.generate(_fotos.length, (i) => SizedBox(width: 160, child: Column(children: [
        ClipRRect(borderRadius: BorderRadius.circular(12), child: FotoCasa(url: _fotos[i], height: 110)),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(tooltip: 'Usar como capa', onPressed: _busy || _upload || i == 0 ? null : () => setState(() { final photo = _fotos.removeAt(i); _fotos.insert(0, photo); }), icon: Icon(i == 0 ? Icons.star : Icons.star_border)),
          IconButton(tooltip: 'Remover foto', onPressed: _busy || _upload ? null : () => setState(() => _fotos.removeAt(i)), icon: const Icon(Icons.delete_outline)),
        ]),
      ])))),
      OutlinedButton.icon(onPressed: _busy || _upload || _fotos.length >= 10 ? null : _adicionarFotos, icon: const Icon(Icons.add_photo_alternate_outlined), label: Text(_upload ? 'Enviando fotos…' : 'Adicionar fotos')),
      const SizedBox(height: 24),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Anúncio publicado'), subtitle: const Text('Ao pausar, as reservas existentes continuam registradas.'), value: _ativa, onChanged: (v) => setState(() => _ativa = v)),
      const SizedBox(height: 24), FilledButton(onPressed: _busy || _upload ? null : _salvar, child: Text(_busy ? 'Salvando…' : 'Salvar anúncio')),
    ])))),
  );
}
