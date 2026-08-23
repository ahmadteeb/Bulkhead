class ContainerPortMapping {
  final int? privatePort;
  final int? publicPort;
  final String? type;
  final String? ip;

  ContainerPortMapping({
    this.privatePort,
    this.publicPort,
    this.type,
    this.ip,
  });

  factory ContainerPortMapping.fromJson(Map<String, dynamic> json) {
    return ContainerPortMapping(
      privatePort: json['PrivatePort'] as int?,
      publicPort: json['PublicPort'] as int?,
      type: json['Type'] as String?,
      ip: json['IP'] as String?,
    );
  }

  @override
  String toString() {
    if (publicPort != null && ip != null) {
      return '$ip:$publicPort->$privatePort/$type';
    } else if (publicPort != null) {
      return '$publicPort->$privatePort/$type';
    }
    return '$privatePort/$type';
  }
}

class ContainerMountPoint {
  final String? type;
  final String? name;
  final String? source;
  final String? destination;
  final String? mode;
  final bool? rw;

  ContainerMountPoint({
    this.type,
    this.name,
    this.source,
    this.destination,
    this.mode,
    this.rw,
  });

  factory ContainerMountPoint.fromJson(Map<String, dynamic> json) {
    return ContainerMountPoint(
      type: json['Type'] as String?,
      name: json['Name'] as String?,
      source: json['Source'] as String?,
      destination: json['Destination'] as String?,
      mode: json['Mode'] as String?,
      rw: json['RW'] as bool?,
    );
  }
}

class ContainerModel {
  final String id;
  final String name;
  final String image;
  final String imageId;
  final String state;
  final String status;
  final DateTime created;
  final List<ContainerPortMapping> ports;
  final List<ContainerMountPoint> mounts;
  final Map<String, String> labels;
  final double cpuPercent;
  final int memoryUsage;
  final int memoryLimit;

  ContainerModel({
    required this.id,
    required this.name,
    required this.image,
    required this.imageId,
    required this.state,
    required this.status,
    required this.created,
    required this.ports,
    required this.mounts,
    required this.labels,
    this.cpuPercent = 0.0,
    this.memoryUsage = 0,
    this.memoryLimit = 0,
  });

  String get shortId => id.length >= 12 ? id.substring(0, 12) : id;

  factory ContainerModel.fromJson(Map<String, dynamic> json) {
    final rawNames = (json['Names'] as List<dynamic>?)?.cast<String>() ?? [];
    String parsedName = rawNames.isNotEmpty ? rawNames.first : (json['Id'] ?? 'unnamed');
    if (parsedName.startsWith('/')) {
      parsedName = parsedName.substring(1);
    }

    final rawCreated = json['Created'];
    DateTime parsedCreated = DateTime.now();
    if (rawCreated is int) {
      parsedCreated = DateTime.fromMillisecondsSinceEpoch(rawCreated * 1000);
    } else if (rawCreated is String) {
      parsedCreated = DateTime.tryParse(rawCreated) ?? DateTime.now();
    }

    final portsList = (json['Ports'] as List<dynamic>?)
            ?.map((p) => ContainerPortMapping.fromJson(p as Map<String, dynamic>))
            .toList() ??
        [];

    final mountsList = (json['Mounts'] as List<dynamic>?)
            ?.map((m) => ContainerMountPoint.fromJson(m as Map<String, dynamic>))
            .toList() ??
        [];

    final labelsMap = (json['Labels'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v.toString()),
        ) ??
        {};

    return ContainerModel(
      id: json['Id'] as String? ?? '',
      name: parsedName,
      image: json['Image'] as String? ?? '',
      imageId: json['ImageID'] as String? ?? '',
      state: (json['State'] as String? ?? 'unknown').toLowerCase(),
      status: json['Status'] as String? ?? '',
      created: parsedCreated,
      ports: portsList,
      mounts: mountsList,
      labels: labelsMap,
    );
  }

  ContainerModel copyWithStats({
    double? cpuPercent,
    int? memoryUsage,
    int? memoryLimit,
  }) {
    return ContainerModel(
      id: id,
      name: name,
      image: image,
      imageId: imageId,
      state: state,
      status: status,
      created: created,
      ports: ports,
      mounts: mounts,
      labels: labels,
      cpuPercent: cpuPercent ?? this.cpuPercent,
      memoryUsage: memoryUsage ?? this.memoryUsage,
      memoryLimit: memoryLimit ?? this.memoryLimit,
    );
  }
}
