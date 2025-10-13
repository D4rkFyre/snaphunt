// lib/services/retry_tokens.dart
import 'dart:math' as math;

/// Total tokens per player = round(#clues * 0.6), capped at 12.
int computeTokenTotal(int clueCount) {
  return math.min(12, (clueCount * 0.6).round());
}

/// Tokens used = sum over clues of max(0, attempts - 1), but at most 2 per clue.
/// (First attempt is free; each re-take costs 1; 2-token per-clue cap.)
int computeTokensUsed(Map<String, int> attemptsByClue) {
  var used = 0;
  attemptsByClue.forEach((_, attempts) {
    final perClue = attempts <= 1 ? 0 : (attempts - 1);
    used += perClue.clamp(0, 2);
  });
  return used;
}
