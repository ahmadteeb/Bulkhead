class DockerEventModel {
  final String type;
  final String action;
  final String actorId;
  final String actorName;
  final DateTime time;

  DockerEventModel({
    required this.type,
    required this.action,
    required this.actorId,
    required this.actorName,
    required this.time,
  });

  factory DockerEventModel.fromJson(Map<String, dynamic> json) {
    final actor = json['Actor'] as Map<String, dynamic>? ?? {};
    final attributes = actor['Attributes'] as Map<String, dynamic>? ?? {};
    final name = attributes['name'] as String? ?? attributes['image'] as String? ?? actor['ID'] as String? ?? 'unknown';

    final timeNano = json['timeNano'] as int?;
    final timeSec = json['time'] as int?;

    DateTime parsedTime = DateTime.now();
    if (timeNano != null) {
      parsedTime = DateTime.fromMillisecondsSinceEpoch(timeNano ~/ 1000000);
    } else if (timeSec != null) {
      parsedTime = DateTime.fromMillisecondsSinceEpoch(timeSec * 1000);
    }

    return DockerEventModel(
      type: json['Type'] as String? ?? 'general',
      action: json['Action'] as String? ?? 'event',
      actorId: actor['ID'] as String? ?? '',
      actorName: name,
      time: parsedTime,
    );
  }
}
