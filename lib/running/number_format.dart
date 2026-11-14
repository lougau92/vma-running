/// Numeric display formatting shared by running features.
library;

/// Formats a running value to two decimals, using scientific notation for
/// values too small or large to display clearly as a decimal.
String formatRunningNumber(double value) => value < 0.01 || value >= 1e9
    ? value.toStringAsExponential(2)
    : value.toStringAsFixed(2);
