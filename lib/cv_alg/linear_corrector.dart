class LinearCorrector {
  List<double> measuredDistances = [];
  List<double> actualDistances = [];
  double? a;
  double? b;

  void clear() {
    a = null;
    b = null;
    measuredDistances.clear();
    actualDistances.clear();
  }

  void addCalibrate(double measure, double actual) {
    measuredDistances.add(measure);
    actualDistances.add(actual);
  }

  bool doCalibrate() {
    if (measuredDistances.length >= 2) {
      final n = measuredDistances.length;
      final sumX = measuredDistances.reduce(
        (value, element) => value + element,
      );
      final sumY = actualDistances.reduce((value, element) => value + element);
      final sumXY = List.generate(
        n,
        (i) => measuredDistances[i] * actualDistances[i],
      ).reduce((value, element) => value + element);
      final sumX2 = measuredDistances
          .map((x) => x * x)
          .reduce((value, element) => value + element);

      final denominator = n * sumX2 - sumX * sumX;
      if (denominator == 0) return false;

      a = (n * sumXY - sumX * sumY) / denominator;
      b = (sumY * sumX2 - sumX * sumXY) / denominator;
      return true;
    } else {
      return false;
    }
  }

  double correct(double distMeasureMm) {
    if (a == null || b == null) {
      return distMeasureMm;
    }
    return a! * distMeasureMm + b!;
  }

  Map<String, double?> dumpResult() {
    return {'a': a, 'b': b};
  }

  void loadResult(Map<String, dynamic> dataMap) {
    a = dataMap['a'] as double?;
    b = dataMap['b'] as double?;
  }
}
