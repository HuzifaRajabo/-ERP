// lib/views/shared/payment_widgets.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../views/shared/shared_components.dart';
import '../../core/utils/money_utils.dart';

class ErrorBox extends StatelessWidget {
  final String message;

  const ErrorBox({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Theme.of(context).colorScheme.error,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentSummaryCard extends StatelessWidget {
  final int totalAmount;
  final int paidAmount;
  final int remaining;

  const PaymentSummaryCard({
    super.key,
    required this.totalAmount,
    required this.paidAmount,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SummaryItem(
                label: 'الإجمالي',
                value: MoneyUtils.formatMoney(totalAmount),
                color: Theme.of(context).colorScheme.onSurface,
              ),
              _SummaryItem(
                label: 'المدفوع',
                value: MoneyUtils.formatMoney(paidAmount),
                color: AppColors.success,
              ),
              _SummaryItem(
                label: 'المتبقي',
                value: MoneyUtils.formatMoney(remaining),
                color: remaining > 0
                    ? Theme.of(context).colorScheme.error
                    : AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
            value: totalAmount > 0
                ? (paidAmount / totalAmount).clamp(0.0, 1.0)
                : 0,
            minHeight: 6,
            color: AppColors.success,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.grey[500],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );
  }
}