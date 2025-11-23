import 'package:flutter/material.dart';
import 'vma_storage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VMA Training',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _vmaStorage = VmaStorage();
  double? _vma;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVma();
  }

  Future<void> _loadVma() async {
    final stored = await _vmaStorage.load();
    if (!mounted) return;

    setState(() {
      _vma = stored;
      _loading = false;
    });

    if (stored == null) {
      await _promptForVma();
    }
  }

  Future<void> _promptForVma() async {
    final selected = await _vmaStorage.promptForVma(
      context,
      initialValue: _vma,
    );

    if (selected != null && mounted) {
      setState(() => _vma = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _vma == null
                      ? 'No VMA saved yet'
                      : 'Your VMA: ${_vma!.toStringAsFixed(2)} km/h',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _promptForVma,
                  icon: const Icon(Icons.directions_run),
                  label:
                      Text(_vma == null ? 'Set VMA' : 'Update VMA'),
                ),
              ],
            ),
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('VMA Training'),
      ),
      body: body,
    );
  }
}
