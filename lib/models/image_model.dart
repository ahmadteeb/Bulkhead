class ImageModel {
  final String id;
  final List<String> repoTags;
  final int size;
  final DateTime created;
  final int containers;
  final Map<String, String> labels;

  ImageModel({
    required this.id,
    required this.repoTags,
    required this.size,
    required this.created,
    required this.containers,
    required this.labels,
  });

  String get shortId {
    final cleanId = id.startsWith('sha256:') ? id.substring(7) : id;
    return cleanId.length >= 12 ? cleanId.substring(0, 12) : cleanId;
  }

  String get primaryTag {
    if (repoTags.isNotEmpty && repoTags.first != '<none>:<none>') {
      return repoTags.first;
    }
    return '<none> ($shortId)';
  }

  factory ImageModel.fromJson(Map<String, dynamic> json) {
    final tags = (json['RepoTags'] as List<dynamic>?)?.cast<String>() ?? [];
    
    final rawCreated = json['Created'];
    DateTime parsedCreated = DateTime.now();
    if (rawCreated is int) {
      parsedCreated = DateTime.fromMillisecondsSinceEpoch(rawCreated * 1000);
    } else if (rawCreated is String) {
      parsedCreated = DateTime.tryParse(rawCreated) ?? DateTime.now();
    }

    final labelsMap = (json['Labels'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v.toString()),
        ) ??
        {};

    return ImageModel(
      id: json['Id'] as String? ?? '',
      repoTags: tags,
      size: json['Size'] as int? ?? 0,
      created: parsedCreated,
      containers: json['Containers'] as int? ?? 0,
      labels: labelsMap,
    );
  }
}
