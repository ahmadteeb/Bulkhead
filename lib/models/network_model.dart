class NetworkModel {
  final String id;
  final String name;
  final String driver;
  final String scope;
  final bool internal;
  final String? subnet;
  final String? gateway;
  final Map<String, String> containers;
  final Map<String, String> labels;

  NetworkModel({
    required this.id,
    required this.name,
    required this.driver,
    required this.scope,
    required this.internal,
    this.subnet,
    this.gateway,
    required this.containers,
    required this.labels,
  });

  String get shortId => id.length >= 12 ? id.substring(0, 12) : id;

  factory NetworkModel.fromJson(Map<String, dynamic> json) {
    final ipam = json['IPAM'] as Map<String, dynamic>?;
    final configList = ipam?['Config'] as List<dynamic>?;

    String? parsedSubnet;
    String? parsedGateway;
    if (configList != null && configList.isNotEmpty) {
      final cfg = configList.first as Map<String, dynamic>;
      parsedSubnet = cfg['Subnet'] as String?;
      parsedGateway = cfg['Gateway'] as String?;
    }

    final rawContainers = json['Containers'] as Map<String, dynamic>? ?? {};
    final containerMap = <String, String>{};
    rawContainers.forEach((cid, cdata) {
      if (cdata is Map<String, dynamic>) {
        final cName = cdata['Name'] as String? ?? cid;
        containerMap[cid] = cName;
      }
    });

    final labelsMap = (json['Labels'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v.toString()),
        ) ??
        {};

    return NetworkModel(
      id: json['Id'] as String? ?? '',
      name: json['Name'] as String? ?? 'unnamed',
      driver: json['Driver'] as String? ?? 'bridge',
      scope: json['Scope'] as String? ?? 'local',
      internal: json['Internal'] as bool? ?? false,
      subnet: parsedSubnet,
      gateway: parsedGateway,
      containers: containerMap,
      labels: labelsMap,
    );
  }
}
