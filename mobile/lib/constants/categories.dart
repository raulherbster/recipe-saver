import '../models/recipe.dart';

/// Hardcoded category taxonomy — matches the backend's CATEGORY_TAXONOMY.
/// Used by categoriesProvider instead of an API call.
const _dietary = ['vegetarian', 'vegan', 'pescatarian', 'gluten-free', 'dairy-free', 'keto', 'paleo'];
const _protein = ['chicken', 'beef', 'pork', 'fish', 'seafood', 'tofu', 'legumes', 'eggs'];
const _course = ['breakfast', 'lunch', 'dinner', 'snack', 'dessert', 'appetizer', 'side-dish', 'drink'];
const _cuisine = ['italian', 'mexican', 'indian', 'thai', 'japanese', 'chinese', 'korean', 'mediterranean', 'middle-eastern', 'french', 'american', 'greek', 'vietnamese'];
const _method = ['baking', 'grilling', 'frying', 'slow-cooker', 'one-pot', 'air-fryer', 'instant-pot', 'no-cook', 'stir-fry'];
const _season = ['spring', 'summer', 'fall', 'winter'];
const _difficulty = ['easy', 'medium', 'hard'];
const _time = ['under-15m', '15-30m', '30-60m', 'over-60m'];

List<Category> _cats(String type, List<String> names) => names
    .map((n) => Category(id: '${type}_$n', name: n, type: type))
    .toList();

final CategoryGroups hardcodedCategories = CategoryGroups(
  dietary: _cats('dietary', _dietary),
  protein: _cats('protein', _protein),
  course: _cats('course', _course),
  cuisine: _cats('cuisine', _cuisine),
  method: _cats('method', _method),
  season: _cats('season', _season),
  difficulty: _cats('difficulty', _difficulty),
  time: _cats('time', _time),
);
