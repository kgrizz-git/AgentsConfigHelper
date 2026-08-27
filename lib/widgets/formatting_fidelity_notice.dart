import 'package:agents_config_helper/services/fidelity_assessor.dart';
import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Persistent, accessible disclosure for a potentially lossy structured save.
class FormattingFidelityNotice extends StatelessWidget {
  const FormattingFidelityNotice({
    required this.assessment,
    this.showOpeningStatement = true,
    super.key,
  });

  final FidelityAssessment assessment;
  final bool showOpeningStatement;

  @override
  Widget build(BuildContext context) {
    final isWarning = assessment.risk == FidelityRisk.warning;
    final color = isWarning ? AppColors.warning : AppColors.primaryAccent;
    final icon = isWarning ? Icons.warning_amber_outlined : Icons.info_outline;
    final openingStatement = showOpeningStatement
        ? 'Opening this file does not change it on disk.'
        : null;
    const guidance =
        'Use raw content when exact layout matters and review changes before '
        'saving.';
    final semanticsLabel = [
      assessment.title,
      assessment.saveRiskDescription,
      ?openingStatement,
      guidance,
    ].join(' ');

    return Semantics(
      container: true,
      label: semanticsLabel,
      liveRegion: false,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assessment.title,
                    style: AppTextStyles.uiSubheader.copyWith(color: color),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    assessment.saveRiskDescription,
                    style: AppTextStyles.uiSecondary.copyWith(
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  if (openingStatement != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      openingStatement,
                      style: AppTextStyles.uiSecondary.copyWith(
                        color: AppColors.textPrimaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Text(guidance, style: AppTextStyles.uiSecondary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
