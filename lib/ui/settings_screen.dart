import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'invite_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmLeave(BuildContext context, WidgetRef ref, String uid, String spaceId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rozłączyć kalendarz?'),
        content: const Text(
          'Przestaniesz widzieć wspólne wpisy. Partner zachowa wszystko, co zostało we wspólnym kalendarzu. '
          'Żeby wrócić, potrzebny będzie nowy kod od partnera.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Rozłącz')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(spaceRepositoryProvider).leave(uid, spaceId);
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final space = ref.watch(spaceProvider).value;
    final scheme = Theme.of(context).colorScheme;
    final partner = user == null ? null : space?.partnerOf(user.uid);

    Widget section(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              ...children,
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Partner i ustawienia')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          section('Konto', [
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(user?.displayName ?? 'Zalogowano'),
                subtitle: Text(user?.email ?? ''),
              ),
            ),
          ]),
          section('Partner', [
            if (space != null && user != null && partner != null)
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.people_outline),
                  title: Text(partner.name),
                  subtitle: Text(partner.email),
                ),
              )
            else if (space != null && user != null)
              InviteCard(
                code: space.inviteCode,
                onRenew: () => ref.read(spaceRepositoryProvider).renewInvite(space, user.uid),
              ),
            const SizedBox(height: 12),
            if (space != null && user != null)
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.error,
                  side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
                ),
                onPressed: () => _confirmLeave(context, ref, user.uid, space.id),
                child: const Text('Rozłącz'),
              ),
          ]),
          section('Konto Google', [
            OutlinedButton(
              onPressed: () async {
                Navigator.of(context).popUntil((r) => r.isFirst);
                await ref.read(authRepositoryProvider).signOut();
              },
              child: const Text('Wyloguj'),
            ),
          ]),
          section('O aplikacji', [
            const Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                title: Text('Kalendarz 0.1'),
                subtitle: Text('Dane wspólne wymagają internetu. Wpisy lokalne będą działać zawsze.'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
