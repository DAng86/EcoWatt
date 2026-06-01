class Reading {
  final String channel;
  final DateTime ts;
  final double currentA;
  final double powerW;
  final String alertType;

  Reading({
    required this.channel,
    required this.ts,
    required this.currentA,
    required this.powerW,
    required this.alertType,
  });

  Map<String, dynamic> toMap() => {
        'channel': channel,
        'ts': ts.toIso8601String(),
        'currentA': currentA,
        'powerW': powerW,
        'alertType': alertType,
      };

  factory Reading.fromMap(Map<String, dynamic> map) => Reading(
        channel: map['channel'] as String,
        ts: DateTime.parse(map['ts'] as String),
        currentA: (map['currentA'] as num).toDouble(),
        powerW: (map['powerW'] as num).toDouble(),
        alertType: map['alertType'] as String,
      );
}
