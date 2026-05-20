import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/colors.dart';
import '../../../../core/theme/tokens/spacing.dart';

const List<String> availableDietaryTags = [
  'vegan',
  'vegetarian',
  'gluten_free',
  'dairy_free',
  'peanut_free',
  'caffeine_free',
];

const Map<String, Map<String, String>> dietaryTagLabels = {
  'vegan': {'en': 'Vegan', 'ms': 'Vegan'},
  'vegetarian': {'en': 'Vegetarian', 'ms': 'Vegetarian'},
  'gluten_free': {'en': 'Gluten-Free', 'ms': 'Bebas Gluten'},
  'dairy_free': {'en': 'Dairy-Free', 'ms': 'Bebas Tenusu'},
  'peanut_free': {'en': 'Peanut-Free', 'ms': 'Bebas Kacang'},
  'caffeine_free': {'en': 'Caffeine-Free', 'ms': 'Bebas Kafein'},
};

/// Beautiful horizontal scrollable row of custom interactive filter chips
class DietaryFilterChips extends StatelessWidget {
  const DietaryFilterChips({
    super.key,
    required this.selectedTags,
    required this.primaryColor,
    required this.onTagToggled,
    required this.onClearAll,
    required this.languageCode,
  });

  final Set<String> selectedTags;
  final Color primaryColor;
  final ValueChanged<String> onTagToggled;
  final VoidCallback onClearAll;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: availableDietaryTags.length + (selectedTags.isNotEmpty ? 1 : 0),
        itemBuilder: (context, index) {
          if (selectedTags.isNotEmpty && index == 0) {
            // Clear Filters Chip with a premium reset design
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: ActionChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, size: 14, color: primaryColor),
                    const SizedBox(width: 4),
                    Text(
                      languageCode == 'ms' ? 'Batal Semua' : 'Reset',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                onPressed: onClearAll,
                backgroundColor: primaryColor.withValues(alpha: 0.1),
                side: BorderSide(color: primaryColor.withValues(alpha: 0.25), width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            );
          }

          final tagIndex = selectedTags.isNotEmpty ? index - 1 : index;
          final tag = availableDietaryTags[tagIndex];
          final isSelected = selectedTags.contains(tag);
          final labelMap = dietaryTagLabels[tag] ?? {'en': tag, 'ms': tag};
          final label = labelMap[languageCode] ?? labelMap['en']!;

          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: FilterChip(
              label: Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.white : AppColors.grey700,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              selected: isSelected,
              onSelected: (_) => onTagToggled(tag),
              selectedColor: primaryColor,
              backgroundColor: AppColors.white,
              checkmarkColor: AppColors.white,
              showCheckmark: false,
              side: BorderSide(
                color: isSelected ? primaryColor : AppColors.grey300,
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          );
        },
      ),
    );
  }
}
