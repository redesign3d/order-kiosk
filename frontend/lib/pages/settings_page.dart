import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models.dart';
import '../state/session.dart';
import '../state/settings.dart';
import '../theme.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _storeUrl = TextEditingController();
  final _consumerKey = TextEditingController();
  final _consumerSecret = TextEditingController();
  final _webhookSecret = TextEditingController();
  int _pollingSeconds = 15;
  bool _includeDrafts = false;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(settingsProvider.notifier).load());
  }

  @override
  void dispose() {
    _storeUrl.dispose();
    _consumerKey.dispose();
    _consumerSecret.dispose();
    _webhookSecret.dispose();
    super.dispose();
  }

  void _populate(Settings settings) {
    if (_seeded) return;
    _storeUrl.text = settings.storeUrl;
    _pollingSeconds = settings.pollingIntervalSeconds;
    _includeDrafts = settings.includeDrafts;
    _seeded = true;
  }

  Future<void> _save() async {
    final settings = Settings(
      storeUrl: _storeUrl.text.trim(),
      includeDrafts: _includeDrafts,
      pollingIntervalSeconds: _pollingSeconds,
      hasCredentials: true,
      hasWebhookSecret: true,
    );
    await ref.read(settingsProvider.notifier).update(
          settings,
          consumerKey: _consumerKey.text.isEmpty ? null : _consumerKey.text,
          consumerSecret:
              _consumerSecret.text.isEmpty ? null : _consumerSecret.text,
          webhookSecret:
              _webhookSecret.text.isEmpty ? null : _webhookSecret.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsProvider);
    final session = ref.watch(sessionProvider);
    if (state.settings != null) {
      _populate(state.settings!);
    }

    final uri = Uri.base;
    final baseOrigin = (uri.scheme == 'http' || uri.scheme == 'https')
        ? uri.origin
        : 'http://localhost:8080';
    final webhookBase = '$baseOrigin/webhooks/woocommerce';
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Settings'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => ref.read(sessionProvider.notifier).logout(),
          child: const Icon(CupertinoIcons.square_arrow_right, size: 22),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('WooCommerce connection',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _field(
                label: 'Store URL',
                controller: _storeUrl,
                placeholder: 'https://store.example.com'),
            _field(
                label: 'Consumer Key',
                controller: _consumerKey,
                placeholder: 'ck_xxx'),
            _field(
                label: 'Consumer Secret',
                controller: _consumerSecret,
                placeholder: 'cs_xxx'),
            _field(
                label: 'Webhook secret',
                controller: _webhookSecret,
                placeholder: 'secret used to verify'),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Include checkout drafts'),
                CupertinoSwitch(
                  value: _includeDrafts,
                  onChanged: (val) => setState(() => _includeDrafts = val),
                )
              ],
            ),
            const SizedBox(height: 10),
            Text('Polling interval: $_pollingSeconds s',
                style: const TextStyle(color: CupertinoColors.systemGrey)),
            CupertinoSlider(
              value: _pollingSeconds.toDouble(),
              min: 5,
              max: 60,
              divisions: 11,
              onChanged: (val) => setState(() => _pollingSeconds = val.toInt()),
            ),
            const SizedBox(height: 16),
            if (state.error != null)
              Text(state.error!,
                  style: const TextStyle(color: CupertinoColors.systemRed)),
            if (state.message != null)
              Text(state.message!,
                  style: const TextStyle(color: CupertinoColors.activeGreen)),
            CupertinoButton.filled(
              onPressed: state.loading ? null : _save,
              child: state.loading
                  ? const CupertinoActivityIndicator()
                  : const Text('Save settings'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  color: AppColors.accent,
                  onPressed: state.loading
                      ? null
                      : () {
                          ref.read(settingsProvider.notifier).testConnection();
                        },
                  child: const Text('Test connection'),
                ),
                CupertinoButton(
                  color: CupertinoColors.systemGrey3,
                  onPressed: session.user?.role == 'ADMIN' && !state.loading
                      ? () => ref.read(settingsProvider.notifier).runBackfill()
                      : null,
                  child: const Text('Run backfill'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Webhook endpoints',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _WebhookRow(
                label: 'Order created', url: '$webhookBase/order-created'),
            _WebhookRow(
                label: 'Order updated', url: '$webhookBase/order-updated'),
            _WebhookRow(
                label: 'Order deleted', url: '$webhookBase/order-deleted'),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? placeholder,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: CupertinoColors.systemGrey)),
          const SizedBox(height: 6),
          CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
          ),
        ],
      ),
    );
  }
}

class _WebhookRow extends StatelessWidget {
  const _WebhookRow({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: url));
          },
          child: const Icon(CupertinoIcons.doc_on_doc, size: 18),
        ),
        Expanded(
          flex: 2,
          child: Text(
            url,
            style: const TextStyle(
                color: CupertinoColors.systemGrey, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
