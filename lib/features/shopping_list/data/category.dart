import 'package:cenko/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class Category {
  const Category({required this.id, required this.slug, this.icon});

  final int id;
  final String slug;
  final String? icon;

  IconData get iconData => _iconMap[icon] ?? Icons.category_rounded;

  static const _iconMap = <String, IconData>{
    'eco_rounded': Icons.eco_rounded,
    'lunch_dining_rounded': Icons.lunch_dining_rounded,
    'phishing_rounded': Icons.phishing_rounded,
    'local_drink_rounded': Icons.local_drink_rounded,
    'egg_alt_rounded': Icons.egg_alt_rounded,
    'bakery_dining_rounded': Icons.bakery_dining_rounded,
    'rice_bowl_rounded': Icons.rice_bowl_rounded,
    'inventory_2_rounded': Icons.inventory_2_rounded,
    'soup_kitchen_rounded': Icons.soup_kitchen_rounded,
    'ac_unit_rounded': Icons.ac_unit_rounded,
    'cookie_rounded': Icons.cookie_rounded,
    'water_drop_rounded': Icons.water_drop_rounded,
    'coffee_rounded': Icons.coffee_rounded,
    'child_friendly_rounded': Icons.child_friendly_rounded,
    'pets_rounded': Icons.pets_rounded,
    'spa_rounded': Icons.spa_rounded,
    'home_rounded': Icons.home_rounded,
    'clean_hands_rounded': Icons.clean_hands_rounded,
    'yard_rounded': Icons.yard_rounded,
    'category_rounded': Icons.category_rounded,
  };

  factory Category.fromMap(Map<String, dynamic> m) => Category(
    id: m['id'] as int,
    slug: m['slug'] as String,
    icon: m['icon'] as String?,
  );
}

/// Resolves a category slug to a localized display name.
String categoryLocalizedName(AppLocalizations l10n, String slug) => switch (slug) {
  'fruits_and_vegetables' => l10n.categoryFruitsAndVegetables,
  'meat' => l10n.categoryMeat,
  'fish_and_seafood' => l10n.categoryFishAndSeafood,
  'dairy_products' => l10n.categoryDairyProducts,
  'eggs' => l10n.categoryEggs,
  'bakery' => l10n.categoryBakery,
  'pantry_staples' => l10n.categoryPantryStaples,
  'cans_and_jars' => l10n.categoryCansAndJars,
  'seasonings_sauces_and_condiments' => l10n.categorySeasoningsSaucesAndCondiments,
  'frozen_foods' => l10n.categoryFrozenFoods,
  'snacks_and_sweets' => l10n.categorySnacksAndSweets,
  'drinks' => l10n.categoryDrinks,
  'coffee_and_tea' => l10n.categoryCoffeeAndTea,
  'baby_products' => l10n.categoryBabyProducts,
  'pet_supplies' => l10n.categoryPetSupplies,
  'personal_care' => l10n.categoryPersonalCare,
  'household_supplies' => l10n.categoryHouseholdSupplies,
  'cleaning_supplies' => l10n.categoryCleaningSupplies,
  'home_and_garden' => l10n.categoryHomeAndGarden,
  'other' => l10n.categoryOther,
  _ => slug,
};
