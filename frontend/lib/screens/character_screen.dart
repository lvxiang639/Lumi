import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/character_provider.dart';

class CharacterScreen extends StatefulWidget {
  const CharacterScreen({super.key});

  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CharacterProvider>().loadConfig();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, _) {
        final config = provider.config;
        return Scaffold(
          appBar: AppBar(title: const Text('角色设置')),
          body: provider.loading
              ? const Center(child: CircularProgressIndicator())
              : config == null
                  ? const Center(child: Text('请先初始化角色'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Center(child: Icon(Icons.person, size: 100, color: Colors.indigo)),
                        const SizedBox(height: 16),
                        Center(child: Text(config.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
                        const SizedBox(height: 24),
                        Text('当前服装: ${config.outfitName ?? "默认"}', style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('当前声音: ${config.voicePackName ?? "默认"}', style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 24),
                        const Text('已拥有的服装', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ...provider.outfits.map((o) => ListTile(
                          title: Text(o['name'] as String? ?? ''),
                          trailing: o['equipped'] == true
                              ? const Chip(label: Text('使用中'))
                              : TextButton(
                                  onPressed: () => provider.equip('outfit', o['id'] as String),
                                  child: const Text('穿上'),
                                ),
                        )),
                        const Divider(),
                        const Text('已拥有的声音', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ...provider.voices.map((v) => ListTile(
                          title: Text(v['name'] as String? ?? ''),
                          subtitle: Text(v['type'] as String? ?? ''),
                          trailing: v['equipped'] == true
                              ? const Chip(label: Text('使用中'))
                              : TextButton(
                                  onPressed: () => provider.equip('voice_pack', v['id'] as String),
                                  child: const Text('使用'),
                                ),
                        )),
                      ],
                    ),
        );
      },
    );
  }
}
