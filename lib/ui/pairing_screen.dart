import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../space/space_repository.dart';

/// Pierwsze uruchomienie po zalogowaniu: albo zakładasz kalendarz i zapraszasz partnera,
/// albo wpisujesz kod, który dostałeś od niego.
class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  final _code = TextEditingController();
  bool _enterCode = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on JoinException catch (e) {
      _error = switch (e.failure) {
        JoinFailure.invalidCode => 'Taki kod nie istnieje albo został już użyty.',
        JoinFailure.spaceFull => 'Ten kalendarz ma już dwie osoby.',
        JoinFailure.alreadyInSpace => 'Jesteś już w kalendarzu.',
      };
    } catch (e) {
      _error = 'Coś poszło nie tak. Sprawdź internet i spróbuj ponownie.\n($e)';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Połącz się z partnerem',
                  style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'Jedna osoba zakłada wspólny kalendarz i dostaje kod. Druga wpisuje ten kod u siebie. Kod działa jeden raz.',
                style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              if (!_enterCode) ...[
                FilledButton(
                  onPressed: _busy || user == null
                      ? null
                      : () => _run(() async {
                            await ref.read(spaceRepositoryProvider).createSpace(user);
                          }),
                  child: const Text('Załóż wspólny kalendarz'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _busy ? null : () => setState(() => _enterCode = true),
                  child: const Text('Mam kod od partnera'),
                ),
              ] else ...[
                TextField(
                  controller: _code,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Kod od partnera',
                    hintText: 'KAL-XXXX-XXXX',
                  ),
                  style: const TextStyle(fontSize: 20, letterSpacing: 2),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy || user == null
                      ? null
                      : () => _run(() => ref
                          .read(spaceRepositoryProvider)
                          .joinWithCode(user, _code.text)),
                  child: const Text('Połącz'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _busy ? null : () => setState(() => _enterCode = false),
                  child: const Text('Wróć'),
                ),
              ],
              if (_busy) ...[
                const SizedBox(height: 20),
                const Center(child: CircularProgressIndicator()),
              ],
              if (_error != null) ...[
                const SizedBox(height: 20),
                Text(_error!, style: TextStyle(color: scheme.error)),
              ],
              const SizedBox(height: 40),
              Center(
                child: TextButton(
                  onPressed: _busy ? null : () => ref.read(authRepositoryProvider).signOut(),
                  child: Text('Wyloguj${user?.email != null ? ' (${user!.email})' : ''}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
