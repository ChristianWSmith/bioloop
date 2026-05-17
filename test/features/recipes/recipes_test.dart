import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bioloop/core/database/database.dart';
import 'package:bioloop/features/recipes/recipe_form_screen.dart';
import 'package:bioloop/features/recipes/recipe_list_screen.dart';
import 'package:bioloop/providers/database_provider.dart';
import 'package:bioloop/providers/recipe_provider.dart';

AppDatabase createSeedDb() {
  final db = AppDatabase.createInMemory();
  final now = DateTime.now().toIso8601String();
  db.into(db.foods).insert(FoodsCompanion.insert(
    name: 'Chicken Breast',
    servingLabel: '100g',
    caloriesPerServing: 165,
    proteinPerServing: 31,
    carbsPerServing: 0,
    fatPerServing: 3.6,
    createdAt: now,
  ));
  db.into(db.foods).insert(FoodsCompanion.insert(
    name: 'Olive Oil',
    servingLabel: '1 tbsp',
    caloriesPerServing: 119,
    proteinPerServing: 0,
    carbsPerServing: 0,
    fatPerServing: 13.5,
    createdAt: now,
  ));
  db.into(db.foods).insert(FoodsCompanion.insert(
    name: 'Brown Rice',
    servingLabel: '100g',
    caloriesPerServing: 111,
    proteinPerServing: 2.6,
    carbsPerServing: 23,
    fatPerServing: 0.9,
    createdAt: now,
  ));
  return db;
}

void main() {
  group('Recipe DAO', () {
    test('insert and read recipe', () async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      final now = DateTime.now().toIso8601String();

      final id = await db.insertRecipe(RecipesCompanion.insert(
        name: 'Chicken Salad',
        servingSize: 400,
        servingLabel: 'g',
        createdAt: now,
        updatedAt: now,
      ));

      final recipe = await db.getRecipe(id);
      expect(recipe?.name, 'Chicken Salad');
      expect(recipe?.servingSize, 400);
      expect(recipe?.servingLabel, 'g');
    });

    test('insert ingredients and read back with food data', () async {
      final db = createSeedDb();
      addTearDown(() => db.close());
      final now = DateTime.now().toIso8601String();

      final recipeId = await db.insertRecipe(RecipesCompanion.insert(
        name: 'Chicken Salad',
        servingSize: 400,
        servingLabel: 'g',
        createdAt: now,
        updatedAt: now,
      ));

      final chicken =
          await (db.select(db.foods)..where((f) => f.name.equals('Chicken Breast')))
              .getSingle();
      final oil = await (db.select(db.foods)..where((f) => f.name.equals('Olive Oil')))
          .getSingle();

      await db.insertIngredient(RecipeIngredientsCompanion.insert(
        recipeId: recipeId,
        foodId: chicken.id,
        quantity: 2,
        createdAt: now,
      ));
      await db.insertIngredient(RecipeIngredientsCompanion.insert(
        recipeId: recipeId,
        foodId: oil.id,
        quantity: 1,
        createdAt: now,
      ));

      final ingredients = await db.getIngredientsWithFood(recipeId);
      expect(ingredients.length, 2);
      expect(ingredients[0].food.name, 'Chicken Breast');
      expect(ingredients[1].food.name, 'Olive Oil');
    });

    test('delete recipe removes recipe row and ingredients can be bulk-deleted', () async {
      final db = createSeedDb();
      addTearDown(() => db.close());
      final now = DateTime.now().toIso8601String();

      final recipeId = await db.insertRecipe(RecipesCompanion.insert(
        name: 'Test',
        servingSize: 100,
        servingLabel: 'g',
        createdAt: now,
        updatedAt: now,
      ));

      final chicken = await (db.select(db.foods)
            ..where((f) => f.name.equals('Chicken Breast')))
          .getSingle();

      await db.insertIngredient(RecipeIngredientsCompanion.insert(
        recipeId: recipeId,
        foodId: chicken.id,
        quantity: 1,
        createdAt: now,
      ));

      expect(await db.getRecipe(recipeId), isNotNull);
      expect((await db.getIngredientsWithFood(recipeId)).length, 1);

      await db.deleteRecipe(recipeId);
      expect(await db.getRecipe(recipeId), isNull);

      // Ingredients remain (no FK cascade without PRAGMA foreign_keys=ON)
      // Use deleteIngredientsForRecipe to clean up
      await db.deleteIngredientsForRecipe(recipeId);
      expect((await db.getIngredientsWithFood(recipeId)).length, 0);
    });

    test('compute macros single ingredient', () async {
      final db = createSeedDb();
      addTearDown(() => db.close());
      final now = DateTime.now().toIso8601String();

      final recipeId = await db.insertRecipe(RecipesCompanion.insert(
        name: 'Chicken',
        servingSize: 200,
        servingLabel: 'g',
        createdAt: now,
        updatedAt: now,
      ));

      final chicken = await (db.select(db.foods)
            ..where((f) => f.name.equals('Chicken Breast')))
          .getSingle();

      await db.insertIngredient(RecipeIngredientsCompanion.insert(
        recipeId: recipeId,
        foodId: chicken.id,
        quantity: 2,
        createdAt: now,
      ));

      final macros = await db.computeRecipeMacros(recipeId);
      expect(macros.calories, closeTo(330, 0.01));
      expect(macros.proteinGrams, closeTo(62, 0.01));
      expect(macros.perUnitCalories, closeTo(1.65, 0.01));
    });

    test('compute macros multiple ingredients', () async {
      final db = createSeedDb();
      addTearDown(() => db.close());
      final now = DateTime.now().toIso8601String();

      final recipeId = await db.insertRecipe(RecipesCompanion.insert(
        name: 'Chicken & Rice',
        servingSize: 500,
        servingLabel: 'g',
        createdAt: now,
        updatedAt: now,
      ));

      final chicken = await (db.select(db.foods)
            ..where((f) => f.name.equals('Chicken Breast')))
          .getSingle();
      final rice = await (db.select(db.foods)
            ..where((f) => f.name.equals('Brown Rice')))
          .getSingle();

      await db.insertIngredient(RecipeIngredientsCompanion.insert(
        recipeId: recipeId,
        foodId: chicken.id,
        quantity: 2,
        createdAt: now,
      ));
      await db.insertIngredient(RecipeIngredientsCompanion.insert(
        recipeId: recipeId,
        foodId: rice.id,
        quantity: 1,
        createdAt: now,
      ));

      final macros = await db.computeRecipeMacros(recipeId);
      expect(macros.calories, closeTo(441, 0.01));
      expect(macros.proteinGrams, closeTo(64.6, 0.01));
      expect(macros.carbsGrams, closeTo(23, 0.01));
      expect(macros.fatGrams, closeTo(8.1, 0.01));
    });

    test('compute macros empty recipe', () async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      final now = DateTime.now().toIso8601String();

      final recipeId = await db.insertRecipe(RecipesCompanion.insert(
        name: 'Empty',
        servingSize: 100,
        servingLabel: 'g',
        createdAt: now,
        updatedAt: now,
      ));

      final macros = await db.computeRecipeMacros(recipeId);
      expect(macros.calories, 0);
      expect(macros.proteinGrams, 0);
      expect(macros.carbsGrams, 0);
      expect(macros.fatGrams, 0);
    });

    test('update ingredient and recompute macros', () async {
      final db = createSeedDb();
      addTearDown(() => db.close());
      final now = DateTime.now().toIso8601String();

      final recipeId = await db.insertRecipe(RecipesCompanion.insert(
        name: 'Test',
        servingSize: 100,
        servingLabel: 'g',
        createdAt: now,
        updatedAt: now,
      ));

      final chicken = await (db.select(db.foods)
            ..where((f) => f.name.equals('Chicken Breast')))
          .getSingle();

      final ingId = await db.insertIngredient(RecipeIngredientsCompanion.insert(
        recipeId: recipeId,
        foodId: chicken.id,
        quantity: 1,
        createdAt: now,
      ));

      final macros1 = await db.computeRecipeMacros(recipeId);
      expect(macros1.calories, closeTo(165, 0.01));

      await db.updateIngredient(
        RecipeIngredientsCompanion(quantity: const Value(3)),
        ingId,
      );

      final macros2 = await db.computeRecipeMacros(recipeId);
      expect(macros2.calories, closeTo(495, 0.01));
    });
  });

    test('compute macros with per-100g ingredient (servingQuantity=100)', () async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      final now = DateTime.now().toIso8601String();

      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Oats (per 100g)',
        servingLabel: '100g',
        servingQuantity: const Value(100),
        servingUnit: const Value('g'),
        caloriesPerServing: 389,
        proteinPerServing: 16.9,
        carbsPerServing: 66,
        fatPerServing: 6.9,
        createdAt: now,
      ));

      final recipeId = await db.insertRecipe(RecipesCompanion.insert(
        name: 'Oatmeal',
        servingSize: 300,
        servingLabel: 'g',
        createdAt: now,
        updatedAt: now,
      ));

      final oats = await (db.select(db.foods)
            ..where((f) => f.name.equals('Oats (per 100g)')))
          .getSingle();

      // Log 200g of oats
      await db.insertIngredient(RecipeIngredientsCompanion.insert(
        recipeId: recipeId,
        foodId: oats.id,
        quantity: 200,
        createdAt: now,
      ));

      final macros = await db.computeRecipeMacros(recipeId);
      // 389 * (200 / 100) = 389 * 2 = 778
      expect(macros.calories, closeTo(778, 0.01));
      expect(macros.proteinGrams, closeTo(33.8, 0.01));
      expect(macros.carbsGrams, closeTo(132, 0.01));
      expect(macros.fatGrams, closeTo(13.8, 0.01));
      // perUnit = 300g → 778 / 300 = 2.593
      expect(macros.perUnitCalories, closeTo(2.593, 0.01));
    });

    test('compute macros backward-compatible with servingQuantity=1', () async {
      final db = createSeedDb();
      addTearDown(() => db.close());
      final now = DateTime.now().toIso8601String();

      final recipeId = await db.insertRecipe(RecipesCompanion.insert(
        name: 'Chicken',
        servingSize: 200,
        servingLabel: 'g',
        createdAt: now,
        updatedAt: now,
      ));

      final chicken = await (db.select(db.foods)
            ..where((f) => f.name.equals('Chicken Breast')))
          .getSingle();

      await db.insertIngredient(RecipeIngredientsCompanion.insert(
        recipeId: recipeId,
        foodId: chicken.id,
        quantity: 2,
        createdAt: now,
      ));

      final macros = await db.computeRecipeMacros(recipeId);
      // 165 * (2 / 1) = 330 (same as old formula)
      expect(macros.calories, closeTo(330, 0.01));
      expect(macros.proteinGrams, closeTo(62, 0.01));
    });

    test('compute macros per-100g vs per-serving produce same total for same mass', () async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      final now = DateTime.now().toIso8601String();

      // Per-serving food: 165 kcal per 1 serving (= 100g)
      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Per Serving',
        servingLabel: '100g',
        caloriesPerServing: 165,
        proteinPerServing: 31,
        carbsPerServing: 0,
        fatPerServing: 3.6,
        createdAt: now,
      ));

      // Per-100g food: 165 kcal per 100g
      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Per 100g',
        servingLabel: '100g',
        servingQuantity: const Value(100),
        servingUnit: const Value('g'),
        caloriesPerServing: 165,
        proteinPerServing: 31,
        carbsPerServing: 0,
        fatPerServing: 3.6,
        createdAt: now,
      ));

      final recipeId = await db.insertRecipe(RecipesCompanion.insert(
        name: 'Test',
        servingSize: 100,
        servingLabel: 'g',
        createdAt: now,
        updatedAt: now,
      ));

      final perServingFood = await (db.select(db.foods)
            ..where((f) => f.name.equals('Per Serving')))
          .getSingle();
      final per100gFood = await (db.select(db.foods)
            ..where((f) => f.name.equals('Per 100g')))
          .getSingle();

      // Both represent 200g of the same food
      await db.insertIngredient(RecipeIngredientsCompanion.insert(
        recipeId: recipeId,
        foodId: perServingFood.id,
        quantity: 2,  // 2 servings × 100g = 200g
        createdAt: now,
      ));
      await db.insertIngredient(RecipeIngredientsCompanion.insert(
        recipeId: recipeId,
        foodId: per100gFood.id,
        quantity: 200,  // 200g
        createdAt: now,
      ));

      final macros = await db.computeRecipeMacros(recipeId);
      // Both should be 330 kcal total (2 × 165)
      expect(macros.calories, closeTo(660, 0.01));
      expect(macros.proteinGrams, closeTo(124, 0.01));
    });

  group('Recipe service', () {
    test('getAllRecipes returns sorted by name', () async {
      final db = createSeedDb();
      addTearDown(() => db.close());
      final now = DateTime.now().toIso8601String();

      await db.insertRecipe(RecipesCompanion.insert(
        name: 'B',
        servingSize: 100,
        servingLabel: 'g',
        createdAt: now,
        updatedAt: now,
      ));
      await db.insertRecipe(RecipesCompanion.insert(
        name: 'A',
        servingSize: 200,
        servingLabel: 'ml',
        createdAt: now,
        updatedAt: now,
      ));
      await db.insertRecipe(RecipesCompanion.insert(
        name: 'C',
        servingSize: 50,
        servingLabel: 'g',
        createdAt: now,
        updatedAt: now,
      ));

      final recipes = await db.getAllRecipes();
      expect(recipes.length, 3);
      expect(recipes[0].name, 'A');
      expect(recipes[1].name, 'B');
      expect(recipes[2].name, 'C');
    });

    test('logRecipe creates food_entry with scaled macros', () async {
      final db = createSeedDb();
      addTearDown(() => db.close());
      final now = DateTime.now().toIso8601String();

      final recipeId = await db.insertRecipe(RecipesCompanion.insert(
        name: 'Test Meal',
        servingSize: 400,
        servingLabel: 'g',
        createdAt: now,
        updatedAt: now,
      ));

      final chicken = await (db.select(db.foods)
            ..where((f) => f.name.equals('Chicken Breast')))
          .getSingle();
      final oil = await (db.select(db.foods)
            ..where((f) => f.name.equals('Olive Oil')))
          .getSingle();

      await db.insertIngredient(RecipeIngredientsCompanion.insert(
        recipeId: recipeId,
        foodId: chicken.id,
        quantity: 2,
        createdAt: now,
      ));
      await db.insertIngredient(RecipeIngredientsCompanion.insert(
        recipeId: recipeId,
        foodId: oil.id,
        quantity: 1,
        createdAt: now,
      ));

      final service = RecipeService(db: db);
      final entryId = await service.logRecipe(
        recipeId: recipeId,
        portion: 200,
        mealType: 'lunch',
      );

      final entries = await db.getEntriesForDate(DateTime.now());
      final entry = entries.firstWhere((e) => e.id == entryId);

      expect(entry.name, 'Test Meal');
      expect(entry.recipeId, recipeId);
      expect(entry.mealType, 'lunch');
      expect(entry.servings, closeTo(0.5, 0.001));
      expect(entry.servingLabel, 'g');

      // Chicken (2×165=330) + Oil (1×119=119) = 449 total
      // scale = 200/400 = 0.5 → 224.5 cal, 31g protein, 0g carbs, 10.35g fat
      expect(entry.calories, closeTo(224.5, 0.01));
      expect(entry.proteinGrams, closeTo(31, 0.01));
      expect(entry.carbsGrams, closeTo(0, 0.01));
      expect(entry.fatGrams, closeTo(10.35, 0.01));
    });
  });

  group('Recipe list screen', () {
    Widget buildTestApp(AppDatabase db) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(
          home: RecipeListScreen(),
        ),
      );
    }

    testWidgets('empty state shows no recipes message', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      await tester.pumpWidget(buildTestApp(db));
      await tester.pumpAndSettle();

      expect(find.textContaining('No recipes yet'), findsOneWidget);
      expect(find.textContaining('Tap + to create one'), findsOneWidget);
    });

    testWidgets('shows saved recipe in list', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      final now = DateTime.now().toIso8601String();

      await db.insertRecipe(RecipesCompanion.insert(
        name: 'Chicken Salad',
        servingSize: 400,
        servingLabel: 'g',
        createdAt: now,
        updatedAt: now,
      ));

      await tester.pumpWidget(buildTestApp(db));
      await tester.pumpAndSettle();

      expect(find.text('Chicken Salad'), findsOneWidget);
      expect(find.text('400 g'), findsOneWidget);
    });

    testWidgets('FAB is visible', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      await tester.pumpWidget(buildTestApp(db));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add), findsAtLeast(1));
    });

    testWidgets('tapping FAB navigates to RecipeFormScreen', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      await tester.pumpWidget(buildTestApp(db));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.byType(RecipeFormScreen), findsOneWidget);
    });

    testWidgets('delete recipe removes from list', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      final now = DateTime.now().toIso8601String();

      await db.insertRecipe(RecipesCompanion.insert(
        name: 'To Delete',
        servingSize: 100,
        servingLabel: 'g',
        createdAt: now,
        updatedAt: now,
      ));

      await tester.pumpWidget(buildTestApp(db));
      await tester.pumpAndSettle();

      expect(find.text('To Delete'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Delete recipe?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('To Delete'), findsNothing);
      expect(find.textContaining('No recipes yet'), findsOneWidget);
    });

    testWidgets('tooltip shows unified message', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      final now = DateTime.now().toIso8601String();

      await db.insertRecipe(RecipesCompanion.insert(
        name: 'Test',
        servingSize: 100,
        servingLabel: 'g',
        createdAt: now,
        updatedAt: now,
      ));

      await tester.pumpWidget(buildTestApp(db));
      await tester.pumpAndSettle();

      final tooltipFinder = find.byType(Tooltip);
      expect(tooltipFinder, findsWidgets);

      final tooltips = tester.widgetList<Tooltip>(tooltipFinder).toList();
      expect(tooltips.any((t) => t.message == 'Tap to log, long-press to delete'), isTrue);
    });
  });

  group('Recipe form screen', () {
    Widget buildTestApp(AppDatabase db, {int? recipeId}) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: RecipeFormScreen(recipeId: recipeId),
        ),
      );
    }

    testWidgets('save button disabled with empty name', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      await tester.pumpWidget(buildTestApp(db));
      await tester.pumpAndSettle();

      final saveButton = find.widgetWithText(FilledButton, 'Save');
      expect(saveButton, findsOneWidget);
      expect(
        tester.widget<FilledButton>(saveButton).onPressed,
        isNull,
      );
    });

    testWidgets('save button disabled with no ingredients', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      await tester.pumpWidget(buildTestApp(db));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Test Recipe');
      await tester.pump();

      final saveButton = find.widgetWithText(FilledButton, 'Save');
      expect(
        tester.widget<FilledButton>(saveButton).onPressed,
        isNull,
      );
    });

    testWidgets('edit mode shows recipe data', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      final now = DateTime.now().toIso8601String();

      final recipeId = await db.insertRecipe(RecipesCompanion.insert(
        name: 'Edit Me',
        servingSize: 300,
        servingLabel: 'g',
        createdAt: now,
        updatedAt: now,
      ));

      await tester.pumpWidget(buildTestApp(db, recipeId: recipeId));
      await tester.pumpAndSettle();

      // The text appears in both the TextField and the AppBar title
      expect(find.textContaining('Edit Me'), findsAtLeast(1));
      expect(find.byIcon(Icons.playlist_add_check), findsOneWidget);
    });

    testWidgets('ingredient search shows recent foods', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      final now = DateTime.now().toIso8601String();

      // Seed a food and log it so it appears in recent foods
      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Chicken Breast',
        servingLabel: '100g',
        caloriesPerServing: 165,
        proteinPerServing: 31,
        carbsPerServing: 0,
        fatPerServing: 3.6,
        createdAt: now,
      ));
      final chicken = await (db.select(db.foods)
            ..where((f) => f.name.equals('Chicken Breast')))
          .getSingle();
      await db.into(db.foodEntries).insert(FoodEntriesCompanion.insert(
        name: 'Chicken Breast',
        calories: 330,
        proteinGrams: 62,
        carbsGrams: 0,
        fatGrams: 7.2,
        servings: 2,
        servingLabel: '2 100g',
        foodId: Value(chicken.id),
        mealType: 'lunch',
        loggedAt: now,
      ));

      // Start from RecipeListScreen (as in real app flow)
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: RecipeListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to RecipeFormScreen via FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Tap "Add ingredient" → showSearch opens
      await tester.tap(find.text('Add ingredient'));
      await tester.pumpAndSettle();

      // "My Foods" mode shows all local foods by default
      expect(find.text('Chicken Breast'), findsOneWidget);
      expect(find.text('Create custom food'), findsOneWidget);
    });

    test('edit recipe → save → ingredients persist', () async {
      final db = createSeedDb();
      addTearDown(() => db.close());
      final now = DateTime.now().toIso8601String();

      final recipeId = await db.insertRecipe(RecipesCompanion.insert(
        name: 'Original',
        servingSize: 400,
        servingLabel: 'g',
        createdAt: now,
        updatedAt: now,
      ));
      final chicken = await (db.select(db.foods)..where((f) => f.name.equals('Chicken Breast'))).getSingle();
      final rice = await (db.select(db.foods)..where((f) => f.name.equals('Brown Rice'))).getSingle();
      
      await db.insertIngredient(RecipeIngredientsCompanion.insert(
        recipeId: recipeId, foodId: chicken.id, quantity: 2, createdAt: now,
      ));
      await db.insertIngredient(RecipeIngredientsCompanion.insert(
        recipeId: recipeId, foodId: rice.id, quantity: 1, createdAt: now,
      ));

      // Verify initial state
      var ingredients = await db.getIngredientsWithFood(recipeId);
      expect(ingredients.length, 2);
      expect(ingredients[0].food.name, 'Chicken Breast');
      expect(ingredients[1].food.name, 'Brown Rice');

      // Simulate edit: delete and re-insert (mimicking the save flow)
      await db.deleteIngredientsForRecipe(recipeId);
      await db.insertIngredient(RecipeIngredientsCompanion.insert(
        recipeId: recipeId, foodId: chicken.id, quantity: 2, createdAt: now,
      ));
      await db.insertIngredient(RecipeIngredientsCompanion.insert(
        recipeId: recipeId, foodId: rice.id, quantity: 1, createdAt: now,
      ));

      // Verify ingredients persist
      ingredients = await db.getIngredientsWithFood(recipeId);
      expect(ingredients.length, 2);
      expect(ingredients[0].food.name, 'Chicken Breast');
      expect(ingredients[1].food.name, 'Brown Rice');
    });

    test('edit recipe → save → macros recalculate correctly', () async {
      final db = createSeedDb();
      addTearDown(() => db.close());
      final now = DateTime.now().toIso8601String();

      final recipeId = await db.insertRecipe(RecipesCompanion.insert(
        name: 'Test',
        servingSize: 400,
        servingLabel: 'g',
        createdAt: now,
        updatedAt: now,
      ));
      final chicken = await (db.select(db.foods)..where((f) => f.name.equals('Chicken Breast'))).getSingle();
      
      await db.insertIngredient(RecipeIngredientsCompanion.insert(
        recipeId: recipeId, foodId: chicken.id, quantity: 2, createdAt: now,
      ));

      // Verify initial macros
      final macros1 = await db.computeRecipeMacros(recipeId);
      expect(macros1.calories, closeTo(330, 0.01));

      // Simulate edit: change quantity from 2 to 3
      await db.deleteIngredientsForRecipe(recipeId);
      await db.insertIngredient(RecipeIngredientsCompanion.insert(
        recipeId: recipeId, foodId: chicken.id, quantity: 3, createdAt: now,
      ));

      // Verify updated macros
      final macros2 = await db.computeRecipeMacros(recipeId);
      expect(macros2.calories, closeTo(495, 0.01));  // 165 * 3 = 495
      expect(macros2.proteinGrams, closeTo(93, 0.01));  // 31 * 3 = 93
    });
  });
}
