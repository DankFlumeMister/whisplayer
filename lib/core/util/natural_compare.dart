/// Compares [a] and [b] so that embedded numbers order by value rather than
/// by character code: `"track 2"` sorts before `"track 10"`, and
/// `"02_xxx"` before `"10_xxx"`.
///
/// Runs of digits are compared as integers; everything else falls back to a
/// plain code-unit comparison. When two runs are numerically equal but
/// differently padded (`"07"` vs `"7"`) the padded form keeps a stable,
/// deterministic position instead of comparing equal.
int naturalCompare(String a, String b) {
  var i = 0;
  var j = 0;
  while (i < a.length && j < b.length) {
    final codeA = a.codeUnitAt(i);
    final codeB = b.codeUnitAt(j);
    final digitA = _isDigit(codeA);
    final digitB = _isDigit(codeB);
    if (digitA && digitB) {
      final startI = i;
      final startJ = j;
      while (i < a.length && _isDigit(a.codeUnitAt(i))) {
        i++;
      }
      while (j < b.length && _isDigit(b.codeUnitAt(j))) {
        j++;
      }
      final numberA = int.tryParse(a.substring(startI, i));
      final numberB = int.tryParse(b.substring(startJ, j));
      if (numberA != null && numberB != null && numberA != numberB) {
        return numberA.compareTo(numberB);
      }
      // Equal values with different padding (07 vs 7) — keep stable order.
      final fallback =
          a.substring(startI, i).compareTo(b.substring(startJ, j));
      if (fallback != 0) {
        return fallback;
      }
    } else {
      if (codeA != codeB) {
        return codeA.compareTo(codeB);
      }
      i++;
      j++;
    }
  }
  return (a.length - i).compareTo(b.length - j);
}

bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;
