/// The EEG rhythms the app reports (brain-rhythms spec). Delta and gamma
/// are zeroed in the estimator, as in BrainBit's EEGWaves app.
enum Rhythm {
  theta('Theta', '4–8 Hz'),
  alpha('Alpha', '8–13 Hz'),
  beta('Beta', '13–30 Hz');

  const Rhythm(this.label, this.band);
  final String label;
  final String band;
}

/// Shares of theta, alpha and beta in the signal, in percent, adding up to
/// 100.
class RhythmShares {
  const RhythmShares._(this.theta, this.alpha, this.beta);

  /// Scales [theta], [alpha] and [beta] so they add up to 100; null when
  /// they carry no power (or are not finite).
  static RhythmShares? normalized(double theta, double alpha, double beta) {
    final values = [theta, alpha, beta];
    if (values.any((v) => !v.isFinite || v < 0)) return null;
    final total = theta + alpha + beta;
    if (total <= 0) return null;
    return RhythmShares._(
      100 * theta / total,
      100 * alpha / total,
      100 * beta / total,
    );
  }

  final double theta;
  final double alpha;
  final double beta;

  double operator [](Rhythm r) => switch (r) {
    Rhythm.theta => theta,
    Rhythm.alpha => alpha,
    Rhythm.beta => beta,
  };

  /// `[θ, α, β]`, rounded to 0.1.
  List<double> toJson() => [
    for (final v in [theta, alpha, beta]) double.parse(v.toStringAsFixed(1)),
  ];

  static RhythmShares? fromJson(Object? json) {
    if (json is! List || json.length != 3) return null;
    final v = [for (final e in json) (e as num).toDouble()];
    return normalized(v[0], v[1], v[2]);
  }

  @override
  bool operator ==(Object other) =>
      other is RhythmShares &&
      other.theta == theta &&
      other.alpha == alpha &&
      other.beta == beta;

  @override
  int get hashCode => Object.hash(theta, alpha, beta);

  @override
  String toString() =>
      'RhythmShares(θ ${theta.toStringAsFixed(1)}, '
      'α ${alpha.toStringAsFixed(1)}, β ${beta.toStringAsFixed(1)})';
}
