class JsPlugin {
  final String id;
  final String name;
  final String version;
  final String description;
  final String? icon;
  final String code;
  final bool enabled;
  final String? sourceUrl;

  JsPlugin({
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    this.icon,
    required this.code,
    this.enabled = true,
    this.sourceUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        'description': description,
        'icon': icon,
        'code': code,
        'enabled': enabled,
        'sourceUrl': sourceUrl,
      };

  factory JsPlugin.fromJson(Map<String, dynamic> json) => JsPlugin(
        id: json['id'] as String? ?? 'unknown',
        name: json['name'] as String? ?? 'Unnamed Plugin',
        version: json['version'] as String? ?? '1.0.0',
        description: json['description'] as String? ?? '',
        icon: json['icon'] as String?,
        code: json['code'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? true,
        sourceUrl: json['sourceUrl'] as String?,
      );

  JsPlugin copyWith({
    bool? enabled,
    String? code,
    String? name,
    String? version,
    String? description,
    String? icon,
  }) =>
      JsPlugin(
        id: id,
        name: name ?? this.name,
        version: version ?? this.version,
        description: description ?? this.description,
        icon: icon ?? this.icon,
        code: code ?? this.code,
        enabled: enabled ?? this.enabled,
        sourceUrl: sourceUrl,
      );
}
