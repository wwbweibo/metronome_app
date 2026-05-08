class TimeSignature {
  final int numerator;
  final int denominator;
  final String label;
  final List<int> accentBeats;

  const TimeSignature({
    required this.numerator,
    required this.denominator,
    required this.label,
    required this.accentBeats,
  });

  int get beats => numerator;

  static const fourFour = TimeSignature(
    numerator: 4, denominator: 4, label: '4/4', accentBeats: [0],
  );
  static const threeFour = TimeSignature(
    numerator: 3, denominator: 4, label: '3/4', accentBeats: [0],
  );
  static const sixEight = TimeSignature(
    numerator: 6, denominator: 8, label: '6/8', accentBeats: [0, 3],
  );

  static const all = [fourFour, threeFour, sixEight];

  bool isAccent(int beatIndex) => accentBeats.contains(beatIndex);

  @override
  bool operator ==(Object other) =>
      other is TimeSignature && label == other.label;

  @override
  int get hashCode => label.hashCode;
}
