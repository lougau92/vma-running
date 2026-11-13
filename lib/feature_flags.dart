/// Release switches configured at build time, never through user settings.
class FeatureFlags {
  const FeatureFlags({
    this.clubCommunications = const bool.fromEnvironment(
      'ENABLE_CLUB_COMMUNICATIONS',
      defaultValue: false,
    ),
    this.clubRankings = const bool.fromEnvironment(
      'ENABLE_CLUB_RANKINGS',
      defaultValue: false,
    ),
  });

  final bool clubCommunications;
  final bool clubRankings;
}
