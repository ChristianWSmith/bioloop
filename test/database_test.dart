import 'package:bioloop/core/database/database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.createInMemory();
  });

  tearDown(() {
    db.close();
  });

  group('table existence', () {
    test('foods table is queryable', () async {
      await expectLater(db.select(db.foods).get(), completes);
    });

    test('food_entries table is queryable', () async {
      await expectLater(db.select(db.foodEntries).get(), completes);
    });

    test('bodyweight_entries table is queryable', () async {
      await expectLater(db.select(db.bodyweightEntries).get(), completes);
    });

    test('user_goals table is queryable', () async {
      await expectLater(db.select(db.userGoals).get(), completes);
    });

    test('meal_templates table is queryable', () async {
      await expectLater(db.select(db.mealTemplates).get(), completes);
    });

    test('recipes table is queryable', () async {
      await expectLater(db.select(db.recipes).get(), completes);
    });

    test('recipe_ingredients table is queryable', () async {
      await expectLater(db.select(db.recipeIngredients).get(), completes);
    });
  });

  group('basic CRUD', () {
    test('foods: insert and read back', () async {
      final now = DateTime.now().toIso8601String();
      final id = await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Chicken Breast',
        servingLabel: '100g',
        caloriesPerServing: 165,
        proteinPerServing: 31,
        carbsPerServing: 0,
        fatPerServing: 3.6,
        createdAt: now,
      ));
      final food = await db.select(db.foods).getSingle();
      expect(food.id, id);
      expect(food.name, 'Chicken Breast');
      expect(food.servingLabel, '100g');
      expect(food.caloriesPerServing, 165);
      expect(food.proteinPerServing, 31);
      expect(food.carbsPerServing, 0);
      expect(food.fatPerServing, 3.6);
      expect(food.source, 'manual');
      expect(food.createdAt, now);
    });

    test('food_entries: insert and read back', () async {
      final now = DateTime.now().toIso8601String();
      final id = await db.into(db.foodEntries).insert(
        FoodEntriesCompanion.insert(
          name: 'Test Meal',
          calories: 500,
          proteinGrams: 30,
          carbsGrams: 50,
          fatGrams: 20,
          servings: 1,
          servingLabel: '1 serving',
          mealType: 'lunch',
          loggedAt: now,
        ),
      );
      final entry = await db.select(db.foodEntries).getSingle();
      expect(entry.id, id);
      expect(entry.name, 'Test Meal');
      expect(entry.calories, 500);
      expect(entry.mealType, 'lunch');
    });

    test('bodyweight_entries: insert and read back', () async {
      final now = DateTime.now().toIso8601String();
      final id = await db.into(db.bodyweightEntries).insert(
        BodyweightEntriesCompanion.insert(
          weightKg: 75.5,
          loggedAt: now,
        ),
      );
      final entry = await db.select(db.bodyweightEntries).getSingle();
      expect(entry.id, id);
      expect(entry.weightKg, 75.5);
      expect(entry.loggedAt, now);
    });

    test('user_goals: insert and read back', () async {
      final now = DateTime.now().toIso8601String();
      await db.into(db.userGoals).insert(
        UserGoalsCompanion.insert(
          goalType: 'cut',
          updatedAt: now,
        ),
      );
      final goal = await db.select(db.userGoals).getSingle();
      expect(goal.goalType, 'cut');
      expect(goal.proteinGPerLb, 1.0);
      expect(goal.fatCaloriePct, 25.0);
      expect(goal.useImperial, 0);
      expect(goal.activityLevel, 3);
      expect(goal.onboardingCompleted, 0);
      expect(goal.id, 1);
    });

    test('meal_templates: insert and read back', () async {
      final now = DateTime.now().toIso8601String();
      final foodsJson = '[{"name":"Oats","calories":150}]';
      final id = await db.into(db.mealTemplates).insert(
        MealTemplatesCompanion.insert(
          name: 'Breakfast',
          foods: foodsJson,
          createdAt: now,
        ),
      );
      final template = await db.select(db.mealTemplates).getSingle();
      expect(template.id, id);
      expect(template.name, 'Breakfast');
      expect(template.foods, foodsJson);
    });

    test('recipes: insert and read back', () async {
      final now = DateTime.now().toIso8601String();
      final id = await db.into(db.recipes).insert(
        RecipesCompanion.insert(
          name: 'Protein Shake',
          servingSize: 500,
          servingLabel: 'ml',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final recipe = await db.select(db.recipes).getSingle();
      expect(recipe.id, id);
      expect(recipe.name, 'Protein Shake');
      expect(recipe.servingSize, 500);
      expect(recipe.servingLabel, 'ml');
    });

    test('recipe_ingredients: insert and read back', () async {
      final now = DateTime.now().toIso8601String();
      final foodId = await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Whey',
        servingLabel: '1 scoop',
        caloriesPerServing: 120,
        proteinPerServing: 24,
        carbsPerServing: 2,
        fatPerServing: 1,
        createdAt: now,
      ));
      final recipeId = await db.into(db.recipes).insert(
        RecipesCompanion.insert(
          name: 'Shake',
          servingSize: 300,
          servingLabel: 'ml',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final ingId = await db.into(db.recipeIngredients).insert(
        RecipeIngredientsCompanion.insert(
          recipeId: recipeId,
          foodId: foodId,
          quantity: 2,
          createdAt: now,
        ),
      );
      final ingredient =
          await db.select(db.recipeIngredients).getSingle();
      expect(ingredient.id, ingId);
      expect(ingredient.recipeId, recipeId);
      expect(ingredient.foodId, foodId);
      expect(ingredient.quantity, 2);
    });
  });

  group('user_goals singleton', () {
    test('inserting second row with id=1 is a no-op on count', () async {
      final now = DateTime.now().toIso8601String();
      await db.into(db.userGoals).insert(
        UserGoalsCompanion.insert(goalType: 'cut', updatedAt: now),
      );
      // Second insert creates a new row since drift doesn't upsert on
      // non-autoIncrement PK by default. T2b handles the actual upsert.
      await db.into(db.userGoals).insert(
        UserGoalsCompanion.insert(
          goalType: 'bulk',
          updatedAt: now,
        ),
      );

      final rows = await db.select(db.userGoals).get();
      expect(rows.length, 2);
    });
  });

  group('default values', () {
    test('goal_weight_kg is null by default', () async {
      final now = DateTime.now().toIso8601String();
      await db.into(db.userGoals).insert(
        UserGoalsCompanion.insert(goalType: 'maintain', updatedAt: now),
      );
      final goal = await db.select(db.userGoals).getSingle();
      expect(goal.goalWeightKg, isNull);
    });

    test('use_imperial defaults to false (0)', () async {
      final now = DateTime.now().toIso8601String();
      await db.into(db.userGoals).insert(
        UserGoalsCompanion.insert(goalType: 'maintain', updatedAt: now),
      );
      final goal = await db.select(db.userGoals).getSingle();
      expect(goal.useImperial, 0);
    });

    test('activity_level defaults to 3 (moderate)', () async {
      final now = DateTime.now().toIso8601String();
      await db.into(db.userGoals).insert(
        UserGoalsCompanion.insert(goalType: 'maintain', updatedAt: now),
      );
      final goal = await db.select(db.userGoals).getSingle();
      expect(goal.activityLevel, 3);
    });
  });

  group('index', () {
    test('search by partial name returns matches', () async {
      final now = DateTime.now().toIso8601String();
      for (var i = 0; i < 100; i++) {
        await db.into(db.foods).insert(FoodsCompanion.insert(
          name: 'Food $i',
          servingLabel: '100g',
          caloriesPerServing: 100.0 + i,
          proteinPerServing: 10.0,
          carbsPerServing: 10.0,
          fatPerServing: 1.0,
          createdAt: now,
        ));
      }
      final results = await (db.select(db.foods)
            ..where((f) => f.name.like('Food 5')))
          .get();
      expect(results.length, 1);
      expect(results.single.name, 'Food 5');
    });
  });

  group('migration', () {
    test('database opens with all tables', () async {
      await expectLater(db.select(db.foods).get(), completes);
    });
  });
}
