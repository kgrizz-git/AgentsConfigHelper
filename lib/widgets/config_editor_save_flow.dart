part of 'config_editor.dart';

extension _ConfigEditorSaveFlow on _ConfigEditorState {
  Future<SavePreview?> _pendingSavePreview({bool overwrite = false}) async {
    final callback = widget.previewSaveContent;
    if (callback == null) return null;
    _previewError = null;
    try {
      return await callback(
        _currentConfig.copyWith(rules: _rules, permissions: _permissions),
        rawContent: _rawContent != _currentConfig.originalContent
            ? _rawContent
            : null,
        overwriteConfirmed: overwrite,
      );
    } on Object catch (error) {
      _previewError = error;
      debugPrint('Save preview unavailable: $error');
      return null;
    }
  }

  Future<void> _saveChanges() async {
    final overwrite = _overwriteApproved;
    _overwriteApproved = false;
    final shown = _shownPreview;
    if (widget.previewSaveContent != null && shown == null) {
      _showPreviewUnavailable(_previewError);
      return;
    }
    final startRevision = _editRevision;
    // Block editing before the fresh-preview await; otherwise edits made while
    // it runs would be dropped by the saved-preview reset.
    _updateUi(() => _saving = true);
    if (shown != null && widget.previewSaveContent != null) {
      final fresh = await _pendingSavePreview(overwrite: overwrite);
      if (!mounted) return;
      if (_editRevision != startRevision ||
          fresh == null ||
          fresh.content != shown.content ||
          fresh.sourceContent != shown.sourceContent ||
          fresh.sourceExists != shown.sourceExists) {
        _updateUi(() => _saving = false);
        await _showDiffModal(overwrite: overwrite);
        return;
      }
    }
    final previewToCommit = shown;
    final commitPreview = widget.commitPreview;
    return await StructuredSaveFlow.run(
      context: context,
      isMounted: () => mounted,
      rawContent: () =>
          _rawContent != _currentConfig.originalContent ? _rawContent : null,
      buildUpdatedConfig: () => _currentConfig.copyWith(
        rules: _rules,
        permissions: _permissions,
      ),
      onSave: (config, {rawContent, allowRewrite, overwriteConfirmed}) {
        // Commit the displayed preview verbatim. A fallback preview still
        // needs the separate rewrite consent before it may be committed.
        if (previewToCommit != null && commitPreview != null) {
          if ((allowRewrite ?? false) || !previewToCommit.usedFallback) {
            return commitPreview(previewToCommit);
          }
        }
        return widget.onSave(
          config,
          rawContent: rawContent,
          allowRewrite: allowRewrite,
          overwriteConfirmed: overwriteConfirmed,
        );
      },
      overwriteConfirmed: overwrite,
      onSuccess: (savedConfig) {
        _updateUi(() {
          _currentConfig = savedConfig;
          _shownPreview = null;
          _initLocalState(_currentConfig);
        });
        _notifyDirtyChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully.')),
        );
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $error'),
            backgroundColor: AppColors.error,
          ),
        );
      },
      setSavingFalse: () {
        if (mounted) {
          _updateUi(() {
            _saving = false;
          });
        }
      },
      onRepreview: () => unawaited(_showDiffModal(overwrite: true)),
    );
  }

  void _showPreviewUnavailable([Object? error]) {
    if (!mounted) return;
    final detail = error == null ? 'Reload the file and try again.' : '$error';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Could not compute a preview of this save, so nothing was written. '
          '$detail',
        ),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _showDiffModal({bool overwrite = false}) async {
    _overwriteApproved = overwrite;
    _shownPreview = await _pendingSavePreview(overwrite: overwrite);
    if (!mounted) return;
    if (widget.previewSaveContent != null && _shownPreview == null) {
      final error = _previewError;
      if (!overwrite && error is SaveConflictException) {
        final confirmed = await StructuredSaveFlow.showConflictDialog(
          context,
          error,
        );
        if (confirmed != true || !mounted) return;
        _overwriteApproved = true;
        _shownPreview = await _pendingSavePreview(overwrite: true);
        if (!mounted) return;
        if (_shownPreview == null) {
          _showPreviewUnavailable(_previewError);
          return;
        }
      } else {
        _showPreviewUnavailable(error);
        return;
      }
    }
    final editRevision = _editRevision;
    final confirmed = await StructuredSaveFlow.showDiffModal(
      context: context,
      isMounted: () => mounted,
      isCurrentRevision: () => _editRevision == editRevision,
      pendingFidelityAssessment: _pendingFidelityAssessment,
      pendingSavePreview: () async => _shownPreview?.content,
      supportsStructuredFields: _supportsStructuredFields,
      rawOnly: widget.rawOnly,
      currentRules: _currentConfig.rules,
      currentPermissions: _currentConfig.permissions,
      rules: _rules,
      permissions: _permissions,
      originalContent: _currentConfig.originalContent,
      rawContent: _rawContent,
      buildDiffSection: StructuredSaveFlow.buildDiffSection,
      buildRawDiffSection: StructuredSaveFlow.buildRawDiffSection,
      saving: _saving,
      onSaveChanges: _saveChanges,
    );
    if (!confirmed && mounted) _overwriteApproved = false;
  }
}
