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
    servingSizeGrams: Value(100),
    caloriesPerServing: 165,
    proteinPerServing: 31,
    carbsPerServing: 0,
    fatPerServing: 3.6,
    createdAt: now,
  ));
  db.into(db.foods).insert(FoodsCompanion.insert(
    name: 'Olive Oil',
    servingLabel: '1 tbsp',
    servingSizeGrams: Value(14),
    caloriesPerServing: 119,
    proteinPerServing: 0,
    carbsPerServing: 0,
    fatPerServing: 13.5,
    createdAt: now,
  ));
  db.into(db.foods).insert(FoodsCompanion.insert(
    name: 'Brown Rice',
    servingLabel: '100g',
    servingSizeGrams: Value(100),
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
  });
}
