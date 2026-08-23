class ComposeServiceInfo {
  final String name;
  final String containerId;
  final String state;
  final String status;
  final String ports;

  ComposeServiceInfo({
    required this.name,
    required this.containerId,
    required this.state,
    required this.status,
    required this.ports,
  });

  factory ComposeServiceInfo.fromJson(Map<String, dynamic> json) {
    return ComposeServiceInfo(
      name: json['Service'] as String? ?? json['Name'] as String? ?? 'service',
      containerId: json['ID'] as String? ?? json['Id'] as String? ?? '',
      state: (json['State'] as String? ?? json['Status'] as String? ?? 'unknown').toLowerCase(),
      status: json['Status'] as String? ?? json['State'] as String? ?? '',
      ports: json['Ports'] as String? ?? json['Publishers']?.toString() ?? '',
    );
  }
}

class ComposeStackModel {
  final String name;
  final String status;
  final String configFiles;

  ComposeStackModel({
    required this.name,
    required this.status,
    required this.configFiles,
  });

  factory ComposeStackModel.fromJson(Map<String, dynamic> json) {
    return ComposeStackModel(
      name: json['Name'] as String? ?? json['Project'] as String? ?? 'unnamed',
      status: json['Status'] as String? ?? 'running',
      configFiles: json['ConfigFiles'] as String? ?? json['Config'] as String? ?? '',
    );
  }
}
