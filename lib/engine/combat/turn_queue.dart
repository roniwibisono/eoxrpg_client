import '../core/seeded_rng.dart';

class TurnQueue {
  final SeededRng _rng;
  final int _dice;

  List<String> _order = [];
  int _round = 0;

  TurnQueue(this._rng, {this._dice = 10});

  int get round => _round;
  List<String> get order => List.unmodifiable(_order);

  void buildQueue(Map<String, int> unitSpeeds) {
    final entries = <_InitiativeEntry>[];
    for (final entry in unitSpeeds.entries) {
      final roll = _rng.range(1.0, _dice.toDouble()).round();
      entries.add(_InitiativeEntry(entry.key, entry.value + roll));
    }
    entries.sort((a, b) => b.score.compareTo(a.score));
    _order = entries.map((e) => e.unitId).toList();
    _round++;
  }

  String? current() => _order.isNotEmpty ? _order.first : null;

  String? advance() {
    if (_order.isEmpty) return null;
    _order.removeAt(0);
    return current();
  }

  bool get isEmpty => _order.isEmpty;
}

class _InitiativeEntry {
  final String unitId;
  final int score;
  const _InitiativeEntry(this.unitId, this.score);
}
