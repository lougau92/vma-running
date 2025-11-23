List<double> presetDistances() {
  final distances = <double>[];

  void addRange(double start, double end, double step) {
    for (double d = start; d <= end + 0.0001; d += step) {
      distances.add(d);
      if (distances.length > 2000) break;
    }
  }

  addRange(100, 500, 100); // 100m increments up to 500
  addRange(500, 3000, 500); // 500m increments to 3k
  addRange(3000, 15000, 1000); // 1k increments 3k-15k
  addRange(20000, 50000, 5000); // 5k increments 20k-50k

  // Half and full marathon.
  distances.addAll([21097.5, 42195]);

  addRange(50000, 200000, 10000); // 10k increments 50k+

  distances.sort();

  final unique = <double>[];
  for (final d in distances) {
    if (unique.isEmpty || (d - unique.last).abs() > 0.0001) {
      unique.add(d);
    }
  }
  return unique;
}

List<double> presetTimesSeconds() {
  // Common workout/target times in seconds.
  final minutes = [
    1,
    5,
    6,
    10,
    12,
    15,
    20,
    30,
    45,
    60,
    90,
    120,
    180,
    240,
    300,
    600,
    900,
    1200,
    1800,
    3600,
    5400,
    7200,
  ];
  return minutes.map((m) => (m * 60).toDouble()).toList();
}
