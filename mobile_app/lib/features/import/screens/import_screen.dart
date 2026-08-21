import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/collections.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/services/share_intent_service.dart';
import '../../../data/models/actual_account.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../shared/widgets/privacy_banner.dart';
import '../../review/screens/review_screen_args.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _shareService = ShareIntentService();

  List<ActualAccount> _accounts = [];
  bool _loadingAccounts = true;
  String? _accountsError;
  ActualAccount? _selectedAccount;

  Uint8List? _bytes;
  String? _filename;
  int? _sizeBytes;

  bool _parsing = false;
  String? _parseError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAccounts());
    _shareService.takeInitial().then((pdf) {
      if (pdf != null) _handleSharedPdf(pdf);
    });
    _shareService.listen(_handleSharedPdf);
  }

  @override
  void dispose() {
    _shareService.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _loadingAccounts = true;
      _accountsError = null;
    });
    final budgetSyncId = ref.read(appConfigProvider).budgetSyncId;
    try {
      final accounts = await ref
          .read(importerApiProvider)
          .getAccounts(budgetSyncId: budgetSyncId);
      final openAccounts = accounts.where((a) => !a.closed).toList();
      final lastId = ref.read(settingsStoreProvider).lastAccountId;
      if (!mounted) return;
      setState(() {
        _accounts = openAccounts;
        _selectedAccount =
            firstWhereOrNull(openAccounts, (a) => a.id == lastId) ??
            (openAccounts.isNotEmpty ? openAccounts.first : null);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _accountsError = e.message);
      if (e.isUnauthorized) context.go('/settings');
    } finally {
      if (mounted) setState(() => _loadingAccounts = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    _setPicked(bytes: file.bytes, filename: file.name, size: file.size);
  }

  Future<void> _handleSharedPdf(SharedPdf shared) async {
    try {
      final bytes = await File(shared.path).readAsBytes();
      _setPicked(bytes: bytes, filename: shared.filename, size: bytes.length);
    } catch (_) {
      if (mounted) setState(() => _parseError = 'Could not read the shared file.');
    }
  }

  void _setPicked({Uint8List? bytes, required String filename, required int size}) {
    if (bytes == null) {
      setState(() => _parseError = 'Could not read that file.');
      return;
    }
    if (size > 20 * 1024 * 1024) {
      setState(() {
        _parseError = 'That file is larger than 20 MB — the backend rejects statements above that size.';
      });
      return;
    }
    setState(() {
      _bytes = bytes;
      _filename = filename;
      _sizeBytes = size;
      _parseError = null;
    });
  }

  Future<void> _parse({String? password}) async {
    if (_bytes == null || _filename == null || _selectedAccount == null) return;
    setState(() {
      _parsing = true;
      _parseError = null;
    });
    final config = ref.read(appConfigProvider);
    try {
      final result = await ref
          .read(importerApiProvider)
          .parseStatement(
            bytes: _bytes!,
            filename: _filename!,
            password: password,
            budgetSyncId: config.budgetSyncId,
          );
      await ref.read(settingsStoreProvider).setLastAccountId(_selectedAccount!.id);
      if (!mounted) return;
      context.push(
        '/review',
        extra: ReviewScreenArgs(
          parseResult: result,
          account: _selectedAccount!,
          budgetSyncId: config.budgetSyncId,
        ),
      );
    } on ApiException catch (e) {
      if (e.code == 'PDF_PASSWORD_REQUIRED' || e.code == 'PDF_PASSWORD_INCORRECT') {
        final retryPassword = await _promptPassword(wrongPassword: e.code == 'PDF_PASSWORD_INCORRECT');
        if (retryPassword != null && retryPassword.isNotEmpty) {
          await _parse(password: retryPassword);
          return;
        }
      } else if (e.isUnauthorized) {
        if (mounted) context.go('/settings');
      } else if (e.code == 'BANK_UNRECOGNIZED') {
        setState(() => _parseError = '${e.message} The statement layout may not be supported yet.');
      } else {
        setState(() => _parseError = e.message);
      }
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }

  Future<String?> _promptPassword({required bool wrongPassword}) {
    final controller = TextEditingController();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This statement is password-protected',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text('Many banks use your NIF or card number as the password.'),
            if (wrongPassword) ...[
              const SizedBox(height: 8),
              Text(
                'That password was incorrect.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
              onSubmitted: (value) => Navigator.pop(context, value),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, controller.text),
                  child: const Text('Unlock'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backendConfigAsync = ref.watch(backendConfigProvider);
    final canParse = _bytes != null && _selectedAccount != null && !_parsing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import statement'),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Category memory',
            onPressed: () => context.push('/categories'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          backendConfigAsync.when(
            data: (config) => config.usesAi
                ? PrivacyBanner(providerName: config.aiProvider ?? 'an AI provider')
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (error, stackTrace) => const SizedBox.shrink(),
          ),
          Text('Account', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_loadingAccounts)
            const Center(child: CircularProgressIndicator())
          else if (_accountsError != null)
            ErrorRetry(message: _accountsError!, onRetry: _loadAccounts)
          else if (_accounts.isEmpty)
            const Text('No open accounts found in this budget.')
          else
            DropdownButtonFormField<ActualAccount>(
              // If `flutter analyze` flags `value` as deprecated on your
              // installed Flutter version, switch this to `initialValue` —
              // the parameter was renamed at some point and which one
              // compiles depends on exactly which version you have.
              value: _selectedAccount,
              items: _accounts
                  .map(
                    (a) => DropdownMenuItem(
                      value: a,
                      child: Text(a.offbudget ? '${a.name} (off-budget)' : a.name),
                    ),
                  )
                  .toList(),
              onChanged: (a) => setState(() => _selectedAccount = a),
            ),
          const SizedBox(height: 24),
          Text('Statement', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(_filename ?? 'Choose PDF'),
          ),
          if (_sizeBytes != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${(_sizeBytes! / 1024).toStringAsFixed(0)} KB'),
            ),
          if (_parseError != null) ...[
            const SizedBox(height: 12),
            Text(_parseError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: canParse ? () => _parse() : null,
            child: _parsing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Parse statement'),
          ),
        ],
      ),
    );
  }
}
