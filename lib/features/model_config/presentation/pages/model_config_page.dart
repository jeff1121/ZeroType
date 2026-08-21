import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_type/core/constants/app_constants.dart';
import '../controllers/model_config_controller.dart';
import '../../domain/entities/ai_provider.dart';
import '../../domain/entities/speech_connection.dart';

@RoutePage()
class ModelConfigPage extends ConsumerWidget {
  const ModelConfigPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providersAsync = ref.watch(providersConfigProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: providersAsync.when(
        data: (config) => SingleChildScrollView(
          padding: const EdgeInsets.only(
            left: 24,
            right: 24,
            bottom: 24,
            top: 30,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '模型',
                style: tt.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '先選 Provider 與通道，再選模型與使用中憑證',
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurface.withAlpha(150),
                ),
              ),
              const SizedBox(height: 32),
              _ConfigSection(
                title: '語音辨識',
                isRequired: true,
                child: _SpeechConfigSection(
                  providers: config.speechRecognition,
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('載入失敗: $err')),
      ),
    );
  }
}

class _ConfigSection extends StatefulWidget {
  const _ConfigSection({
    required this.title,
    required this.isRequired,
    required this.child,
  });

  final String title;
  final bool isRequired;
  final Widget child;

  @override
  State<_ConfigSection> createState() => _ConfigSectionState();
}

class _ConfigSectionState extends State<_ConfigSection> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(100),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.onSurface.withAlpha(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    widget.title,
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.isRequired) ...[
                    const SizedBox(width: 4),
                    const Text(
                      '*',
                      style: TextStyle(color: Colors.redAccent, fontSize: 18),
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: cs.onSurface.withAlpha(150),
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(padding: const EdgeInsets.all(20), child: widget.child),
          ],
        ],
      ),
    );
  }
}

class _SpeechConfigSection extends ConsumerWidget {
  const _SpeechConfigSection({required this.providers});
  final List<AiProvider> providers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(speechProviderControllerProvider);
    final cs = Theme.of(context).colorScheme;

    return stateAsync.when(
      data: (state) {
        final selectedProvider = providers.firstWhere(
          (p) => p.id == state.providerId,
          orElse: () => providers.first,
        );
        final isGeminiOfficial =
            state.providerId == 'gemini' &&
            state.channel == SpeechChannel.official;
        final isAzure = state.isAzure;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '選擇 Provider',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _ChoiceRow(
              values: providers.map((p) => (id: p.id, label: p.name)).toList(),
              selectedId: state.providerId,
              onSelected: (id) => ref
                  .read(speechProviderControllerProvider.notifier)
                  .selectProvider(id),
            ),
            const SizedBox(height: 24),
            const Text('選擇通道', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _ChoiceRow(
              values: state.allowedChannels
                  .map((c) => (id: c.id, label: c.displayName))
                  .toList(),
              selectedId: state.channel.id,
              onSelected: (id) => ref
                  .read(speechProviderControllerProvider.notifier)
                  .selectChannel(SpeechChannelX.fromId(id)),
            ),
            if (!isAzure && state.channel == SpeechChannel.proxy) ...[
              const SizedBox(height: 24),
              _TextSaveField(
                label: 'Proxy 根位址',
                hintText: 'http://127.0.0.1:8317',
                initialValue: state.proxyRoot ?? '',
                resetKey: '${state.providerId}-proxy-root',
                onSave: (val) => ref
                    .read(speechProviderControllerProvider.notifier)
                    .saveProxyRoot(val),
                savedMessage: 'Proxy 根位址已儲存',
              ),
            ],
            if (isAzure) ...[
              const SizedBox(height: 24),
              const Text(
                '使用中憑證',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _AzureCredentials(state: state),
              const SizedBox(height: 24),
              _ModelPicker(
                state: state,
                bundledModels: selectedProvider.models,
              ),
            ] else ...[
              const SizedBox(height: 24),
              _ModelPicker(
                state: state,
                bundledModels: selectedProvider.models,
              ),
              const SizedBox(height: 24),
              const Text(
                '使用中憑證',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              if (isGeminiOfficial)
                _GeminiOfficialCredentials(state: state)
              else
                _ApiKeyInput(
                  resetKey: '${state.providerId}-${state.channel.id}-key',
                  initialValue: state.activeApiKey ?? '',
                  onSave: (val) => ref
                      .read(speechProviderControllerProvider.notifier)
                      .saveApiKey(val),
                ),
            ],
          ],
        );
      },
      loading: () => const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Text('錯誤: $err', style: TextStyle(color: cs.error)),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.values,
    required this.selectedId,
    required this.onSelected,
  });

  final List<({String id, String label})> values;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      children: values.map((item) {
        final isSelected = item.id == selectedId;
        return ChoiceChip(
          label: Text(item.label),
          selected: isSelected,
          onSelected: (val) {
            if (val) onSelected(item.id);
          },
          backgroundColor: cs.surface,
          selectedColor: cs.primary.withAlpha(50),
          labelStyle: TextStyle(
            color: isSelected ? cs.primary : cs.onSurface.withAlpha(150),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          side: BorderSide(
            color: isSelected ? cs.primary : cs.onSurface.withAlpha(30),
          ),
        );
      }).toList(),
    );
  }
}

class _ModelPicker extends ConsumerWidget {
  const _ModelPicker({required this.state, required this.bundledModels});

  final SpeechConnectionState state;
  final List<AiModel> bundledModels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final officialAsync = state.channel == SpeechChannel.official
        ? ref.watch(officialModelsProvider)
        : const AsyncData<List<AiModel>?>(null);
    final proxyAsync = state.channel == SpeechChannel.proxy
        ? ref.watch(proxyModelsProvider)
        : const AsyncData<List<AiModel>>([]);
    final liveOfficial = officialAsync.hasError
        ? null
        : officialAsync.asData?.value;
    final catalog = state.channel == SpeechChannel.official
        ? (liveOfficial ?? bundledModels)
        : (proxyAsync.asData?.value ?? const <AiModel>[]);
    final selectedId = state.modelId;
    final models = [
      ...catalog,
      if (selectedId != null &&
          selectedId.isNotEmpty &&
          !catalog.any((m) => m.id == selectedId))
        AiModel(id: selectedId, name: selectedId),
    ];
    final isLoading = officialAsync.isLoading || proxyAsync.isLoading;
    final attemptedOfficial = state.isAzure
        ? (state.activeApiKey != null &&
              state.activeApiKey!.isNotEmpty &&
              state.azureEndpoint != null &&
              state.azureEndpoint!.isNotEmpty)
        : switch (state.activeCredentialMethod) {
            CredentialMethod.apiKey =>
              (state.activeApiKey != null && state.activeApiKey!.isNotEmpty),
            CredentialMethod.antigravityOauth => state.antigravityAvailable,
            null => false,
          };
    final showOfficialFallback =
        state.channel == SpeechChannel.official &&
        !officialAsync.isLoading &&
        liveOfficial == null &&
        attemptedOfficial;
    final azureNeedsManualInput =
        state.isAzure &&
        !officialAsync.isLoading &&
        (liveOfficial == null || liveOfficial.isEmpty);
    final showCatalogError = state.channel == SpeechChannel.official
        ? (officialAsync.hasError || showOfficialFallback)
        : proxyAsync.hasError;
    final catalogHint = state.isAzure
        ? '部署清單暫時查不到，請手動輸入部署名稱'
        : '模型目錄暫時查不到，仍可使用上次選擇的模型';
    final pickerLabel = state.isAzure ? '選擇部署' : '選擇模型';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              pickerLabel,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            const Text(
              '*',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(必填)',
              style: TextStyle(
                color: Colors.redAccent.withAlpha(150),
                fontSize: 12,
              ),
            ),
            if (isLoading) ...[
              const SizedBox(width: 12),
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
            if (state.channel == SpeechChannel.official) ...[
              const Spacer(),
              IconButton(
                tooltip: '更新模型目錄',
                onPressed: officialAsync.isLoading
                    ? null
                    : () => ref.invalidate(officialModelsProvider),
                icon: const Icon(Icons.refresh, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (azureNeedsManualInput)
          _TextSaveField(
            label: '部署名稱',
            hintText: '手動輸入 Whisper 部署名稱',
            initialValue: selectedId ?? '',
            resetKey: '${state.providerId}-azure-deployment',
            requiredField: true,
            onSave: (val) => ref
                .read(speechProviderControllerProvider.notifier)
                .selectModel(val.trim()),
            savedMessage: '部署名稱已儲存',
          )
        else
          _ModelDropdown(
            models: models,
            selectedModelId: selectedId,
            onChanged: (val) {
              if (val != null) {
                ref
                    .read(speechProviderControllerProvider.notifier)
                    .selectModel(val);
              }
            },
          ),
        if (showCatalogError)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              catalogHint,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(140),
              ),
            ),
          ),
      ],
    );
  }
}

class _AzureCredentials extends ConsumerWidget {
  const _AzureCredentials({required this.state});

  final SpeechConnectionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(speechProviderControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TextSaveField(
          label: 'Service Endpoint',
          hintText: 'https://<resource>.openai.azure.com',
          initialValue: state.azureEndpoint ?? '',
          resetKey: '${state.providerId}-azure-endpoint',
          requiredField: true,
          onSave: notifier.saveAzureEndpoint,
          savedMessage: 'Service Endpoint 已儲存',
        ),
        const SizedBox(height: 24),
        _ApiKeyInput(
          resetKey: '${state.providerId}-azure-key',
          initialValue: state.activeApiKey ?? '',
          onSave: notifier.saveApiKey,
          label: 'API Key（Access Token）',
        ),
        const SizedBox(height: 24),
        _TextSaveField(
          label: 'API Version',
          hintText: AppConstants.defaultAzureApiVersion,
          initialValue:
              state.azureApiVersion ?? AppConstants.defaultAzureApiVersion,
          resetKey: '${state.providerId}-azure-api-version',
          requiredField: true,
          onSave: notifier.saveAzureApiVersion,
          savedMessage: 'API Version 已儲存',
        ),
      ],
    );
  }
}

class _GeminiOfficialCredentials extends ConsumerWidget {
  const _GeminiOfficialCredentials({required this.state});
  final SpeechConnectionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = state.officialCredentialMethod;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChoiceRow(
          values: [
            (id: CredentialMethod.apiKey.id, label: 'API Key'),
            (
              id: CredentialMethod.antigravityOauth.id,
              label: 'Antigravity OAuth',
            ),
          ],
          selectedId: selected?.id,
          onSelected: (id) {
            final method = CredentialMethodX.fromId(id);
            if (method != null) {
              ref
                  .read(speechProviderControllerProvider.notifier)
                  .selectCredentialMethod(method);
            }
          },
        ),
        const SizedBox(height: 16),
        if (selected == CredentialMethod.apiKey)
          _ApiKeyInput(
            resetKey: '${state.providerId}-official-key',
            initialValue: state.officialApiKey ?? '',
            onSave: (val) => ref
                .read(speechProviderControllerProvider.notifier)
                .saveApiKey(val),
          )
        else if (selected == CredentialMethod.antigravityOauth)
          _AntigravityOauthActions(available: state.antigravityAvailable)
        else
          Text(
            '請選擇一份使用中憑證',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(140),
            ),
          ),
      ],
    );
  }
}

class _AntigravityOauthActions extends ConsumerStatefulWidget {
  const _AntigravityOauthActions({required this.available});
  final bool available;

  @override
  ConsumerState<_AntigravityOauthActions> createState() =>
      _AntigravityOauthActionsState();
}

class _AntigravityOauthActionsState
    extends ConsumerState<_AntigravityOauthActions> {
  bool _busy = false;

  Future<void> _login() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(speechProviderControllerProvider.notifier)
          .loginAntigravityOauth();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Antigravity 憑證已取得並落地'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), duration: const Duration(seconds: 4)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.available
              ? '已找到本機 Antigravity 憑證，轉寫時會直接引用。'
              : '尚未取得 Antigravity 憑證，請用 Google 帳號登入以取得並落地憑證。',
          style: TextStyle(color: cs.onSurface.withAlpha(160), height: 1.5),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            ElevatedButton(
              onPressed: _busy ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
              ),
              child: Text(
                widget.available ? '重新登入' : '用 Google 登入 Antigravity',
              ),
            ),
            if (_busy) ...[
              const SizedBox(width: 12),
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _ApiKeyInput extends StatelessWidget {
  const _ApiKeyInput({
    required this.resetKey,
    required this.initialValue,
    required this.onSave,
    this.label = 'API Key',
  });

  final String resetKey;
  final String initialValue;
  final Function(String) onSave;
  final String label;

  @override
  Widget build(BuildContext context) {
    return _TextSaveField(
      label: label,
      hintText: '輸入 API Key',
      initialValue: initialValue,
      resetKey: resetKey,
      obscureText: true,
      requiredField: true,
      onSave: onSave,
      savedMessage: 'API Key 已儲存',
    );
  }
}

class _TextSaveField extends StatefulWidget {
  const _TextSaveField({
    required this.label,
    required this.hintText,
    required this.initialValue,
    required this.resetKey,
    required this.onSave,
    required this.savedMessage,
    this.obscureText = false,
    this.requiredField = false,
  });

  final String label;
  final String hintText;
  final String initialValue;
  final String resetKey;
  final Function(String) onSave;
  final String savedMessage;
  final bool obscureText;
  final bool requiredField;

  @override
  State<_TextSaveField> createState() => _TextSaveFieldState();
}

class _TextSaveFieldState extends State<_TextSaveField> {
  late final TextEditingController _controller;
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _obscureText = widget.obscureText;
  }

  @override
  void didUpdateWidget(_TextSaveField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetKey != oldWidget.resetKey ||
        widget.initialValue != oldWidget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (widget.requiredField) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(color: cs.onSurface.withAlpha(80)),
                  filled: true,
                  fillColor: cs.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.onSurface.withAlpha(30)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.onSurface.withAlpha(30)),
                  ),
                  suffixIcon: widget.obscureText
                      ? IconButton(
                          icon: Icon(
                            _obscureText
                                ? Icons.visibility
                                : Icons.visibility_off,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscureText = !_obscureText),
                        )
                      : null,
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                widget.onSave(_controller.text);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(widget.savedMessage),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              child: const Text('儲存'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ModelDropdown extends StatelessWidget {
  const _ModelDropdown({
    required this.models,
    required this.selectedModelId,
    required this.onChanged,
  });

  final List<AiModel> models;
  final String? selectedModelId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.onSurface.withAlpha(30)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: models.any((m) => m.id == selectedModelId)
              ? selectedModelId
              : null,
          isExpanded: true,
          hint: const Text('選擇一個模型'),
          items: models.map((m) {
            return DropdownMenuItem(value: m.id, child: Text(m.name));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
