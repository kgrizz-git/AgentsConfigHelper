import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/schemas/policy_card.dart';
import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as p;

/// Reviewed, plain-language help for one Codex permission group.
class CodexPermissionFieldHelp extends Equatable {
  /// Creates help for one displayed Codex permission group.
  const CodexPermissionFieldHelp({
    required this.label,
    required this.description,
  });

  /// The display label for this help entry.
  final String label;

  /// A description of the stored setting, not a prediction of enforcement.
  final String description;

  @override
  List<Object?> get props => [label, description];
}

/// Reviewed help metadata for the currently supported Codex permission groups.
class CodexPermissionsHelp {
  /// Explains the card's intentionally read-only scope.
  static const policy = CodexPermissionFieldHelp(
    label: 'Codex permissions',
    description:
        'This card shows the permission entries stored in this config.toml '
        'file. Codex resolves them at runtime across config layers, profile '
        'inheritance, and sandbox settings; this card does not compute that '
        'effective policy. Permission profiles are a beta Codex feature and '
        'may change.',
  );

  /// Explains the legacy sandbox and approval keys.
  static const legacy = CodexPermissionFieldHelp(
    label: 'Sandbox and approvals',
    description:
        'The legacy sandbox_mode and approval_policy values stored in this '
        'file. When sandbox_mode appears in any loaded config layer, Codex '
        'uses these older sandbox settings instead of permission profiles. A '
        'stored retired "untrusted" approval policy is shown as-is; see the '
        'Codex migration guide for the current policies.',
  );

  /// Explains the selected default profile.
  static const selection = CodexPermissionFieldHelp(
    label: 'Default profile',
    description:
        'The permission profile Codex applies by default, as stored here. '
        'The named profile may be a built-in, defined in this file below, or '
        'defined in another config layer; an unknown name is shown as stored.',
  );

  /// Builds per-profile help whose label is the profile name.
  static CodexPermissionFieldHelp profile(String profileName) {
    return CodexPermissionFieldHelp(
      label: profileName,
      description:
          'The filesystem and network rules stored for this profile in this '
          'file. A stored extends value names its parent profile but is never '
          'resolved here; Codex applies inheritance at runtime.',
    );
  }

  /// Explains the filesystem rules of a profile.
  static const filesystem = CodexPermissionFieldHelp(
    label: 'Filesystem rules',
    description:
        'Stored path-to-access entries (read, write, deny). More specific '
        'entries win over broader ones, and deny wins ties at equal '
        'specificity. Codex enforces them at runtime.',
  );

  /// Explains the network rules of a profile.
  static const network = CodexPermissionFieldHelp(
    label: 'Network rules',
    description:
        'Stored network access and domain policy for this profile. Domain '
        'rules are enforced only when the network proxy is active (see '
        'features.network_proxy); this card does not check enforcement.',
  );

  /// Notes the legacy table that the card does not parse.
  static const legacyTable = CodexPermissionFieldHelp(
    label: 'Legacy sandbox table',
    description:
        'A [sandbox_workspace_write] table is present in this file but not '
        'shown on this card. Review it in the raw editor.',
  );
}

/// One stored filesystem rule: a direct access value, a scoped subpath map,
/// or both (the parser never produces both at once).
class CodexFilesystemEntry extends Equatable {
  /// Creates a filesystem entry from its stored access and subpaths.
  CodexFilesystemEntry({
    required this.path,
    this.access,
    Map<String, String>? subpaths,
  }) : subpaths = subpaths == null ? null : Map.unmodifiable(subpaths);

  /// The stored path or special root (`:minimal`, `:workspace_roots`, …).
  final String path;

  /// The direct access value (`read`/`write`/`deny`), when a plain string.
  final String? access;

  /// Scoped `subpath → access` rules, when the stored value is a table.
  final Map<String, String>? subpaths;

  @override
  List<Object?> get props => [path, access, subpaths];
}

/// The stored, policy-relevant network subset of one profile.
class CodexNetworkPolicy extends Equatable {
  /// Creates a network policy from its stored entries.
  CodexNetworkPolicy({
    this.enabled,
    Map<String, String>? domains,
    Map<String, String>? unixSockets,
    this.allowLocalBinding,
  }) : domains = domains == null ? null : Map.unmodifiable(domains),
       unixSockets = unixSockets == null ? null : Map.unmodifiable(unixSockets);

  /// Whether commands in the profile may access the network, when stored.
  final bool? enabled;

  /// Stored `host pattern → allow/deny` domain rules.
  final Map<String, String>? domains;

  /// Stored Unix socket `path → allow/deny` overrides.
  final Map<String, String>? unixSockets;

  /// Whether allowlisted hostnames may resolve to local addresses, if stored.
  final bool? allowLocalBinding;

  @override
  List<Object?> get props => [enabled, domains, unixSockets, allowLocalBinding];
}

/// One stored `[permissions.<name>]` profile, exactly as written in the file.
class CodexPermissionProfile extends Equatable {
  /// Creates a profile from its stored entries.
  CodexPermissionProfile({
    required this.name,
    this.description,
    this.extendsProfile,
    Map<String, bool>? workspaceRoots,
    this.globScanMaxDepth,
    List<CodexFilesystemEntry>? filesystem,
    this.network,
  }) : workspaceRoots = workspaceRoots == null
           ? null
           : Map.unmodifiable(workspaceRoots),
       filesystem = filesystem == null ? null : List.unmodifiable(filesystem);

  /// The profile name as stored under `[permissions.<name>]`.
  final String name;

  /// The stored human-readable description, when present.
  final String? description;

  /// The stored parent profile from `extends`, never resolved here.
  final String? extendsProfile;

  /// Stored `path → enabled` workspace roots, when a table is present.
  final Map<String, bool>? workspaceRoots;

  /// The stored deny-read glob pre-expansion bound, when present.
  final int? globScanMaxDepth;

  /// The stored filesystem rules, in file order, when a table is present.
  final List<CodexFilesystemEntry>? filesystem;

  /// The stored network policy, when a table is present.
  final CodexNetworkPolicy? network;

  @override
  List<Object?> get props => [
    name,
    description,
    extendsProfile,
    workspaceRoots,
    globScanMaxDepth,
    filesystem,
    network,
  ];
}

/// A read-only, validated view of a Codex `config.toml` permission block.
class CodexPermissionsPresentation extends PolicyCardPresentation {
  /// Creates a presentation from the recognized stored entries.
  CodexPermissionsPresentation({
    required this.hasSandboxWorkspaceWriteTable,
    required this.hasConfiguredPermissions,
    this.sandboxMode,
    this.approvalPolicy,
    this.defaultPermissions,
    List<CodexPermissionProfile>? profiles,
  }) : profiles = profiles == null ? const [] : List.unmodifiable(profiles);

  /// The stored legacy `sandbox_mode`, when present (shown as-is).
  final String? sandboxMode;

  /// The stored legacy `approval_policy`, when present (shown as-is).
  final String? approvalPolicy;

  /// The stored `default_permissions` selection, when present.
  final String? defaultPermissions;

  /// The stored profiles, in file order.
  final List<CodexPermissionProfile> profiles;

  /// Whether a `[sandbox_workspace_write]` table is present (not parsed).
  final bool hasSandboxWorkspaceWriteTable;

  /// Whether any permission entry is stored in the file.
  final bool hasConfiguredPermissions;

  @override
  List<Object?> get props => [
    sandboxMode,
    approvalPolicy,
    defaultPermissions,
    profiles,
    hasSandboxWorkspaceWriteTable,
    hasConfiguredPermissions,
  ];
}

/// Interprets the known Codex TOML permission configuration without mutating
/// it. Display-only: unknown keys never suppress the card, and wrong-typed
/// recognized values decline to the raw editor.
class CodexPermissionsAdapter implements PolicyCardAdapter {
  /// Stable key used by the widget registry. Named `adapterId` (not `id`)
  /// because Dart forbids a static member and an instance member sharing one
  /// name; the instance getter below forwards to it for the interface.
  static const adapterId = 'codex.permissions';

  /// Forwards [adapterId] for the [PolicyCardAdapter] interface.
  @override
  String get id => adapterId;

  /// The primary documentation for the displayed Codex permission profiles.
  static final Uri documentationUri = Uri.parse(
    'https://developers.openai.com/codex/permissions',
  );

  /// The built-in profile names a `default_permissions` value may select
  /// without a same-file `[permissions.<name>]` table.
  static const builtinProfileNames = {
    ':read-only',
    ':workspace',
    ':danger-full-access',
  };

  static const _filesystemAccess = {'read', 'write', 'deny'};
  static const _domainAccess = {'allow', 'deny'};

  /// Returns a read-only presentation only for known Codex targets.
  @override
  PolicyCardSelection interpret({
    required ToolConfig config,
    required DiscoveredConfig? discoveredConfig,
  }) {
    if (!_isCodexTarget(config, discoveredConfig)) {
      return const PolicyCardSelection(
        adapterId: adapterId,
        status: PolicyCardStatus.notApplicable,
      );
    }

    final raw = config.rawSettings;
    final sandboxMode = _storedString(raw, 'sandbox_mode');
    if (sandboxMode == _invalid) return _unsupportedField('sandbox_mode');
    final approvalPolicy = _storedString(raw, 'approval_policy');
    if (approvalPolicy == _invalid) {
      return _unsupportedField('approval_policy');
    }
    final defaultPermissions = _storedString(raw, 'default_permissions');
    if (defaultPermissions == _invalid) {
      return _unsupportedField('default_permissions');
    }

    final profiles = <CodexPermissionProfile>[];
    if (raw.containsKey('permissions')) {
      final permissions = raw['permissions'];
      if (permissions is! Map) return _unsupportedField('permissions');
      for (final entry in permissions.entries) {
        final profile = _readProfile(entry.key, entry.value);
        if (profile == null) {
          return _unsupportedField('permissions.${entry.key}');
        }
        profiles.add(profile);
      }
    }

    return PolicyCardSelection(
      adapterId: adapterId,
      status: PolicyCardStatus.available,
      presentation: CodexPermissionsPresentation(
        sandboxMode: sandboxMode as String?,
        approvalPolicy: approvalPolicy as String?,
        defaultPermissions: defaultPermissions as String?,
        profiles: profiles,
        hasSandboxWorkspaceWriteTable: raw.containsKey(
          'sandbox_workspace_write',
        ),
        hasConfiguredPermissions:
            sandboxMode != null ||
            approvalPolicy != null ||
            defaultPermissions != null ||
            profiles.isNotEmpty,
      ),
    );
  }

  bool _isCodexTarget(
    ToolConfig config,
    DiscoveredConfig? discoveredConfig,
  ) {
    if (discoveredConfig == null ||
        !discoveredConfig.fromCatalog ||
        discoveredConfig.descriptor?.id != ToolId.codex ||
        discoveredConfig.kind != ConfigSourceKind.structuredConfig ||
        discoveredConfig.format != ConfigFormat.toml ||
        config.format != ConfigFormat.toml ||
        (discoveredConfig.scope != ConfigLocationScope.user &&
            discoveredConfig.scope != ConfigLocationScope.project)) {
      return false;
    }

    final filePath = discoveredConfig.filePath;
    return p.basename(filePath) == 'config.toml' &&
        p.basename(p.dirname(filePath)) == '.codex';
  }

  /// Marker for a present-but-wrong-typed value.
  static const _invalid = Object();

  /// Returns the stored string, null when omitted, or [_invalid] when the
  /// present value is not a string. Unknown strings are shown as-is.
  Object? _storedString(Map<String, Object?> raw, String key) {
    if (!raw.containsKey(key)) return null;
    final value = raw[key];
    if (value is! String) return _invalid;
    return value;
  }

  /// Reads one `[permissions.<name>]` table; null when malformed.
  CodexPermissionProfile? _readProfile(Object? name, Object? table) {
    if (name is! String || table is! Map) return null;
    final description = _tableString(table, 'description');
    if (description == _invalid) return null;
    final extendsProfile = _tableString(table, 'extends');
    if (extendsProfile == _invalid) return null;

    final workspaceRoots = _tableBoolMap(table, 'workspace_roots');
    if (workspaceRoots == _invalid) return null;

    List<CodexFilesystemEntry>? filesystem;
    int? globScanMaxDepth;
    if (table.containsKey('filesystem')) {
      final rawFilesystem = table['filesystem'];
      if (rawFilesystem is! Map) return null;
      if (rawFilesystem.containsKey('glob_scan_max_depth')) {
        final depth = rawFilesystem['glob_scan_max_depth'];
        if (depth is! int) return null;
        globScanMaxDepth = depth;
      }
      filesystem = <CodexFilesystemEntry>[];
      for (final entry in rawFilesystem.entries) {
        if (entry.key == 'glob_scan_max_depth') continue;
        final rule = _readFilesystemEntry(entry.key, entry.value);
        if (rule == null) return null;
        filesystem.add(rule);
      }
    }

    CodexNetworkPolicy? network;
    if (table.containsKey('network')) {
      network = _readNetwork(table['network']);
      if (network == null) return null;
    }

    return CodexPermissionProfile(
      name: name,
      description: description as String?,
      extendsProfile: extendsProfile as String?,
      workspaceRoots: workspaceRoots as Map<String, bool>?,
      globScanMaxDepth: globScanMaxDepth,
      filesystem: filesystem,
      network: network,
    );
  }

  /// Returns the stored string for [key], null when omitted, [_invalid] when
  /// the present value is not a string.
  Object? _tableString(Map<dynamic, dynamic> table, String key) {
    if (!table.containsKey(key)) return null;
    final value = table[key];
    if (value is! String) return _invalid;
    return value;
  }

  /// Returns the stored string-bool map for [key], null when omitted,
  /// [_invalid] when malformed.
  Object? _tableBoolMap(Map<dynamic, dynamic> table, String key) {
    if (!table.containsKey(key)) return null;
    final value = table[key];
    if (value is! Map) return _invalid;
    final result = <String, bool>{};
    for (final entry in value.entries) {
      if (entry.key is! String || entry.value is! bool) return _invalid;
      result[entry.key as String] = entry.value as bool;
    }
    return result;
  }

  /// Reads one filesystem entry; null when the access value is malformed.
  /// Unknown access strings decline: only `read`/`write`/`deny` render.
  CodexFilesystemEntry? _readFilesystemEntry(Object? path, Object? value) {
    if (path is! String) return null;
    if (value is String) {
      if (!_filesystemAccess.contains(value)) return null;
      return CodexFilesystemEntry(path: path, access: value);
    }
    if (value is Map) {
      final subpaths = <String, String>{};
      for (final entry in value.entries) {
        if (entry.key is! String ||
            entry.value is! String ||
            !_filesystemAccess.contains(entry.value)) {
          return null;
        }
        subpaths[entry.key as String] = entry.value as String;
      }
      return CodexFilesystemEntry(path: path, subpaths: subpaths);
    }
    return null;
  }

  /// Reads one network table; null when malformed. Proxy listener/transport
  /// and `dangerously_*` keys are ignored (left to the raw editor).
  CodexNetworkPolicy? _readNetwork(Object? table) {
    if (table is! Map) return null;
    bool? enabled;
    if (table.containsKey('enabled')) {
      if (table['enabled'] is! bool) return null;
      enabled = table['enabled'] as bool;
    }
    Map<String, String>? domains;
    if (table.containsKey('domains')) {
      domains = _readAccessMap(table['domains'], _domainAccess);
      if (domains == null) return null;
    }
    Map<String, String>? unixSockets;
    if (table.containsKey('unix_sockets')) {
      unixSockets = _readAccessMap(table['unix_sockets'], _domainAccess);
      if (unixSockets == null) return null;
    }
    bool? allowLocalBinding;
    if (table.containsKey('allow_local_binding')) {
      if (table['allow_local_binding'] is! bool) return null;
      allowLocalBinding = table['allow_local_binding'] as bool;
    }
    return CodexNetworkPolicy(
      enabled: enabled,
      domains: domains,
      unixSockets: unixSockets,
      allowLocalBinding: allowLocalBinding,
    );
  }

  /// Reads a `pattern → access` map restricted to [allowed]; null when any
  /// key or value is malformed.
  Map<String, String>? _readAccessMap(Object? value, Set<String> allowed) {
    if (value is! Map) return null;
    final result = <String, String>{};
    for (final entry in value.entries) {
      if (entry.key is! String ||
          entry.value is! String ||
          !allowed.contains(entry.value)) {
        return null;
      }
      result[entry.key as String] = entry.value as String;
    }
    return result;
  }

  PolicyCardSelection _unsupportedField(String field) {
    return PolicyCardSelection(
      adapterId: adapterId,
      status: PolicyCardStatus.unsupported,
      unsupportedReason:
          'Codex permission "$field" is not a supported value. '
          'Use the raw editor to review it.',
    );
  }
}
