import 'package:flutter/material.dart';
import '../services/api.dart';

const oceano = Color(0xFF12675D);
const areia = Color(0xFFF7F5EF);
const tinta = Color(0xFF183E3A);

void avisar(BuildContext context, Object message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$message')));
}

Future<bool> confirmar(BuildContext context, String title, String message) async =>
  await showDialog<bool>(context: context, builder: (context) => AlertDialog(
    title: Text(title), content: Text(message), actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Voltar')),
      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmar')),
    ],
  )) ?? false;

class Conteudo extends StatelessWidget {
  final Widget child;
  final double width;
  const Conteudo({super.key, required this.child, this.width = 1200});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(constraints: BoxConstraints(maxWidth: width), child: Padding(
      padding: const EdgeInsets.all(20), child: child,
    )),
  );
}

class FotoCasa extends StatelessWidget {
  final String? url;
  final double? height;
  const FotoCasa({super.key, this.url, this.height});
  @override
  Widget build(BuildContext context) {
    final fallback = Container(height: height, color: const Color(0xFFDCEAE3),
      child: const Center(child: Icon(Icons.beach_access_outlined, size: 56, color: oceano)));
    if (url == null) return fallback;
    return Image.network(api.foto(url!), height: height, width: double.infinity, fit: BoxFit.cover,
      errorBuilder: (_, error, stackTrace) => fallback,
      loadingBuilder: (_, child, progress) => progress == null ? child : fallback,
    );
  }
}

class Vazio extends StatelessWidget {
  final String title;
  final String message;
  final Widget? action;
  final IconData icon;
  const Vazio({super.key, required this.title, required this.message, this.action, this.icon = Icons.beach_access_outlined});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 52, color: oceano), const SizedBox(height: 18),
      Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8), Text(message, textAlign: TextAlign.center),
      if (action != null) ...[const SizedBox(height: 20), action!],
    ]),
  ));
}

class Falha extends StatelessWidget {
  final Object error;
  final VoidCallback retry;
  const Falha({super.key, required this.error, required this.retry});
  @override
  Widget build(BuildContext context) => Vazio(
    title: 'Não foi possível carregar', message: '$error', icon: Icons.wifi_off_rounded,
    action: OutlinedButton(onPressed: retry, child: const Text('Tentar novamente')),
  );
}

class Contador extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  const Contador({super.key, required this.label, required this.value, required this.onChanged, this.min = 1, this.max = 30});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Text(label), const SizedBox(width: 8),
    IconButton(tooltip: 'Diminuir $label', onPressed: value > min ? () => onChanged(value - 1) : null, icon: const Icon(Icons.remove_circle_outline)),
    Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
    IconButton(tooltip: 'Aumentar $label', onPressed: value < max ? () => onChanged(value + 1) : null, icon: const Icon(Icons.add_circle_outline)),
  ]);
}
