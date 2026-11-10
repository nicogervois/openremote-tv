import 'package:flutter/material.dart';
import '../core/models.dart';
import '../network/discovery.dart';

class AddTvSheet extends StatefulWidget {
  const AddTvSheet({super.key});
  @override
  State<AddTvSheet> createState() => _AddTvSheetState();
}

class _AddTvSheetState extends State<AddTvSheet> {
  final form = GlobalKey<FormState>();
  final host = TextEditingController();
  final name = TextEditingController(text: 'Living room');
  final mac = TextEditingController();
  final psk = TextEditingController();
  TvBrand brand = TvBrand.samsung;
  @override
  void dispose() {
    host.dispose();
    name.dispose();
    mac.dispose();
    psk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      24,
      24,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Meet your TV.',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<TvBrand>(
              initialValue: brand,
              decoration: const InputDecoration(labelText: 'TV platform'),
              items: TvBrand.values
                  .map(
                    (b) => DropdownMenuItem(
                      value: b,
                      child: Text('${b.label} · ${b.platform}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => brand = value!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Room / nickname'),
              maxLength: 40,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Give your TV a name.'
                  : null,
            ),
            TextFormField(
              controller: host,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'TV IP address',
                hintText: '192.168.1.42',
              ),
              validator: (value) => isLocalIpv4(value?.trim() ?? '')
                  ? null
                  : 'Enter a private IPv4 address from your TV settings.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: mac,
              decoration: const InputDecoration(
                labelText: 'MAC address (optional)',
                helperText: 'For Wake-on-LAN; requires network standby.',
                hintText: 'AA:BB:CC:DD:EE:FF',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                try {
                  magicPacket(value.trim());
                  return null;
                } catch (_) {
                  return 'Use six pairs of hexadecimal digits.';
                }
              },
            ),
            if (brand == TvBrand.sony) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: psk,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Sony pre-shared key',
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Enter the key configured on the TV.'
                    : null,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Sony IP control uses unencrypted local HTTP. Connect only on trusted home Wi-Fi.',
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(context, (
                    device: TvDevice(
                      host: host.text.trim(),
                      name: name.text.trim(),
                      brand: brand,
                      mac: mac.text.trim(),
                    ),
                    psk: brand == TvBrand.sony ? psk.text : null,
                  ));
                }
              },
              child: const Text('Connect TV'),
            ),
          ],
        ),
      ),
    ),
  );
}

class KeyboardDialog extends StatefulWidget {
  const KeyboardDialog({super.key});
  @override
  State<KeyboardDialog> createState() => _KeyboardDialogState();
}

class _KeyboardDialogState extends State<KeyboardDialog> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Less clicking. More watching.'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Open a text field on the TV first. Some TV apps do not accept remote text.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Text to send'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (controller.text.isNotEmpty) {
            Navigator.pop(context, controller.text);
          }
        },
        child: const Text('Send to TV'),
      ),
    ],
  );
}
