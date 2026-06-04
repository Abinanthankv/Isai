class EclipseAddon {
  final String id;
  final String name;
  final String version;
  final String description;
  final String? icon;
  final String baseUrl;
  final bool enabled;

  EclipseAddon({
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    this.icon,
    required this.baseUrl,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        'description': description,
        'icon': icon,
        'baseUrl': baseUrl,
        'enabled': enabled,
      };

  factory EclipseAddon.fromJson(Map<String, dynamic> json) => EclipseAddon(
        id: json['id'] as String? ?? 'unknown',
        name: json['name'] as String? ?? 'Unnamed Addon',
        version: json['version'] as String? ?? '1.0.0',
        description: json['description'] as String? ?? '',
        icon: json['icon'] as String?,
        baseUrl: json['baseUrl'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? true,
      );

  EclipseAddon copyWith({
    bool? enabled,
    String? name,
    String? version,
    String? description,
    String? icon,
    String? baseUrl,
  }) =>
      EclipseAddon(
        id: id,
        name: name ?? this.name,
        version: version ?? this.version,
        description: description ?? this.description,
        icon: icon ?? this.icon,
        baseUrl: baseUrl ?? this.baseUrl,
        enabled: enabled ?? this.enabled,
      );
}
