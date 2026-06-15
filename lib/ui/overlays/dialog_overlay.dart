import 'package:flutter/material.dart';

class DialogOverlay extends StatelessWidget {
  final String npcName;
  final String npcType;
  final String dialogueText;
  final VoidCallback onClose;
  final void Function(String action)? onAction;

  const DialogOverlay({
    super.key,
    required this.npcName,
    required this.npcType,
    required this.dialogueText,
    required this.onClose,
    this.onAction,
  });

  List<String> _availableActions(String type) {
    switch (type) {
      case 'merchant':
      case 'blacksmith':
        return ['shop', 'talk'];
      case 'innkeeper':
        return ['inn', 'talk'];
      case 'ama_banker':
        return ['bank', 'talk'];
      case 'quest_giver':
        return ['quest', 'talk'];
      case 'black_market':
        return ['shop', 'talk'];
      case 'lore_keeper':
      case 'custodian_envoy':
      case 'faction_relations':
      case 'medic':
        return ['talk'];
      default:
        return ['talk'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = _availableActions(npcType);
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            border: Border.all(color: const Color(0xFFE0C070)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                npcName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE0C070),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                dialogueText,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final action in actions)
                    _ActionButton(
                      label: _actionLabel(action),
                      onPressed: () {
                        if (action == 'talk') {
                          onClose();
                        } else {
                          onAction?.call(action);
                        }
                      },
                    ),
                  _ActionButton(label: 'Leave', onPressed: onClose),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'shop':
        return 'Shop';
      case 'quest':
        return 'Quest';
      case 'bank':
        return 'Exchange';
      case 'inn':
        return 'Rest';
      case 'talk':
        return 'Talk';
      default:
        return action;
    }
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3A2A1A),
          foregroundColor: const Color(0xFFE0C070),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: Color(0xFFE0C070)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
