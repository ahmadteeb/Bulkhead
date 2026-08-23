class VolumeModel {
  final String name;
  final String driver;
  final String mountpoint;
  final String scope;
  final DateTime created;
  final Map<String, String> labels;
  final int usageSize;
  final int refContainers;

  VolumeModel({
    required this.name,
    required this.driver,
    required this.mountpoint,
    required this.scope,
    required this.created,
    required this.labels,
    this.usageSize = -1,
    this.refContainers = 0,
  });

  factory VolumeModel.fromJson(Map<String, dynamic> json) {
    final rawCreated = json['CreatedAt'];
    DateTime parsedCreated = DateTime.now();
    if (rawCreated is String) {
      parsedCreated = DateTime.tryParse(rawCreated) ?? DateTime.now();
    }

    final labelsMap = (json['Labels'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v.toString()),
        ) ??
        {};

    final usageData = json['UsageData'] as Map<String, dynamic>?;
    final size = usageData?['Size'] as int? ?? -1;
    final refCount = usageData?['RefCount'] as int? ?? 0;

    return VolumeModel(
      name: json['Name'] as String? ?? 'unnamed',
      driver: json['Driver'] as String? ?? 'local',
      mountpoint: json['Mountpoint'] as String? ?? '',
      scope: json['Scope'] as String? ?? 'local',
      created: parsedCreated,
      labels: labelsMap,
      usageSize: size,
      refContainers: refCount,
    );
  }

  VolumeModel copyWith({
    int? usageSize,
    int? refContainers,
  }) {
    return VolumeModel(
      name: name,
      driver: driver,
      mountpoint: mountpoint,
      scope: scope,
      created: created,
      labels: labels,
      usageSize: usageSize ?? this.usageSize,
      refContainers: refContainers ?? this.refContainers,
    );
  }
}
