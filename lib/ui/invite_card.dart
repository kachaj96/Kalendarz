import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../space/invite_code.dart';

/// Kod zaproszenia z przyciskami kopiowania i wygenerowania nowego.
class InviteCard extends StatelessWidget {
  const InviteCard({super.key, required this.code, this.onRenew});

  final String? code;
  final VoidCallback? onRenew;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Czekasz na partnera. Przekaż mu ten kod:',
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Center(
            child: SelectableText(
              code == null ? 'brak kodu' : formatInviteCode(code!),
              style: text.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  onPressed: code == null
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: formatInviteCode(code!)),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Skopiowano kod')),
                            );
                          }
                        },
                  child: const Text('Kopiuj'),
                ),
              ),
              if (onRenew != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    onPressed: onRenew,
                    child: const Text('Nowy kod'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
