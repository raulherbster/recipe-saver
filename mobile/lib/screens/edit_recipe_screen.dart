import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
import '../providers/providers.dart';

class EditRecipeScreen extends ConsumerStatefulWidget {
  final Recipe recipe;

  const EditRecipeScreen({super.key, required this.recipe});

  @override
  ConsumerState<EditRecipeScreen> createState() => _EditRecipeScreenState();
}

class _EditRecipeScreenState extends ConsumerState<EditRecipeScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _servingsController;
  late final TextEditingController _difficultyController;
  late final TextEditingController _prepTimeMinsController;
  late final TextEditingController _cookTimeMinsController;
  late final TextEditingController _totalTimeMinsController;

  late List<TextEditingController> _ingredientControllers;
  late List<TextEditingController> _instructionControllers;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.recipe;
    _titleController = TextEditingController(text: r.title);
    _descriptionController = TextEditingController(text: r.description ?? '');
    _servingsController = TextEditingController(text: r.servings ?? '');
    _difficultyController = TextEditingController(text: r.difficulty ?? '');
    _prepTimeMinsController =
        TextEditingController(text: r.prepTimeMins?.toString() ?? '');
    _cookTimeMinsController =
        TextEditingController(text: r.cookTimeMins?.toString() ?? '');
    _totalTimeMinsController =
        TextEditingController(text: r.totalTimeMins?.toString() ?? '');

    _ingredientControllers = r.ingredients.isNotEmpty
        ? r.ingredients
            .map((ing) => TextEditingController(text: ing.displayText))
            .toList()
        : [TextEditingController()];

    _instructionControllers = (r.instructions != null && r.instructions!.isNotEmpty)
        ? r.instructions!
            .map((step) => TextEditingController(text: step))
            .toList()
        : [TextEditingController()];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _servingsController.dispose();
    _difficultyController.dispose();
    _prepTimeMinsController.dispose();
    _cookTimeMinsController.dispose();
    _totalTimeMinsController.dispose();
    for (final c in _ingredientControllers) {
      c.dispose();
    }
    for (final c in _instructionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addIngredient() {
    setState(() {
      _ingredientControllers.add(TextEditingController());
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredientControllers[index].dispose();
      _ingredientControllers.removeAt(index);
    });
  }

  void _addInstruction() {
    setState(() {
      _instructionControllers.add(TextEditingController());
    });
  }

  void _removeInstruction(int index) {
    setState(() {
      _instructionControllers[index].dispose();
      _instructionControllers.removeAt(index);
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    final payload = <String, dynamic>{};

    final title = _titleController.text.trim();
    if (title.isNotEmpty) payload['title'] = title;

    final description = _descriptionController.text.trim();
    if (description.isNotEmpty) payload['description'] = description;

    final servings = _servingsController.text.trim();
    if (servings.isNotEmpty) payload['servings'] = servings;

    final difficulty = _difficultyController.text.trim();
    if (difficulty.isNotEmpty) payload['difficulty'] = difficulty;

    final prepTime = int.tryParse(_prepTimeMinsController.text.trim());
    if (prepTime != null) payload['prep_time_mins'] = prepTime;

    final cookTime = int.tryParse(_cookTimeMinsController.text.trim());
    if (cookTime != null) payload['cook_time_mins'] = cookTime;

    final totalTime = int.tryParse(_totalTimeMinsController.text.trim());
    if (totalTime != null) payload['total_time_mins'] = totalTime;

    final ingredients = _ingredientControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => {'name': s, 'raw_text': s})
        .toList();
    if (ingredients.isNotEmpty) payload['ingredients'] = ingredients;

    final instructions = _instructionControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (instructions.isNotEmpty) payload['instructions'] = instructions;

    try {
      await ref
          .read(apiServiceProvider)
          .updateRecipe(widget.recipe.id, payload);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Recipe'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Text(
              'Title',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.title),
                hintText: 'Recipe title',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              'Description',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.notes),
                hintText: 'Short description',
              ),
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            // Servings
            Text(
              'Servings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _servingsController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.people),
                hintText: 'e.g. 4 servings',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            // Difficulty
            Text(
              'Difficulty',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _difficultyController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.signal_cellular_alt),
                hintText: 'e.g. Easy, Medium, Hard',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            // Prep Time
            Text(
              'Prep Time (minutes)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _prepTimeMinsController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.timer_outlined),
                hintText: 'e.g. 15',
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            // Cook Time
            Text(
              'Cook Time (minutes)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _cookTimeMinsController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.local_fire_department),
                hintText: 'e.g. 30',
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            // Total Time
            Text(
              'Total Time (minutes)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _totalTimeMinsController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.schedule),
                hintText: 'e.g. 45',
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 24),

            // Ingredients
            Row(
              children: [
                Icon(Icons.list,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Ingredients',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._ingredientControllers.asMap().entries.map((entry) {
              final index = entry.key;
              final controller = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.check_circle_outline),
                          hintText: 'Ingredient ${index + 1}',
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeIngredient(index),
                      tooltip: 'Remove ingredient',
                    ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: _addIngredient,
              icon: const Icon(Icons.add),
              label: const Text('Add ingredient'),
            ),
            const SizedBox(height: 24),

            // Instructions
            Row(
              children: [
                Icon(Icons.format_list_numbered,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Instructions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._instructionControllers.asMap().entries.map((entry) {
              final index = entry.key;
              final controller = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          prefixIcon: CircleAvatar(
                            radius: 14,
                            backgroundColor:
                                Theme.of(context).colorScheme.primaryContainer,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          hintText: 'Step ${index + 1}',
                        ),
                        maxLines: 3,
                        minLines: 1,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeInstruction(index),
                      tooltip: 'Remove step',
                    ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: _addInstruction,
              icon: const Icon(Icons.add),
              label: const Text('Add step'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
