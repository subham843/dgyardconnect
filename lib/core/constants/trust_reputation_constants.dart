/// Trust score (0–100) and reputation level constants. New users start at 70.
abstract final class TrustReputationConstants {
  static const int defaultTrustScore = 70;
  static const int minScore = 0;
  static const int maxScore = 100;

  /// Reputation level labels for display.
  static const Map<String, String> reputationLabels = {
    'elite': 'Elite',
    'trusted': 'Trusted',
    'standard': 'Standard',
    'risky': 'Risky',
    'restricted': 'Restricted',
  };

  static String labelForReputationLevel(String? level) =>
      level != null ? (reputationLabels[level] ?? level) : 'Standard';

  /// Dispute severity options for admin (trust score deduction: low -2, medium -5, high -10).
  static const Map<String, String> disputeSeverityLabels = {
    'low': 'Low (-2)',
    'medium': 'Medium (-5)',
    'high': 'High (-10)',
  };

  /// Technician level labels (trust-score based: Bronze 0–49, Silver 50–69, Gold 70–84, Elite 85–100).
  static const Map<String, String> technicianLevelLabels = {
    'bronze': 'Bronze',
    'silver': 'Silver',
    'gold': 'Gold',
    'elite': 'Elite',
  };

  static String labelForTechnicianLevel(String? level) =>
      level != null ? (technicianLevelLabels[level] ?? level) : '—';
}
