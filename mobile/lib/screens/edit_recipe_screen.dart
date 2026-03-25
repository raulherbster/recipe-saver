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
  bool _isDirty = false;

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

    _instructionControllers =
        (r.instructions != null && r.instructions!.isNotEmpty)
            ? r.instructions!
                .map((step) => TextEditingController(text: step))
                .toList()
            : [TextEditingController()];

    for (final c in _fixedControllers) {
      c.addListener(_markDirty);
    }
    for (final c in _ingredientControllers) {
      c.addListener(_markDirty);
    }
    for (final c in _instructionControllers) {
      c.addListener(_markDirty);
    }
  }

  List<TextEditingController> get _fixedControllers => [
        _titleController,
        _descriptionController,
        _servingsController,
        _difficultyController,
        _prepTimeMinsController,
        _cookTimeMinsController,
        _totalTimeMinsController,
      ];

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  @override
  void dispose() {
    for (final c in _fixedControllers) {
      c.removeListener(_markDirty);
      c.dispose();
    }
    for (final c in _ingredientControllers) {
      c.removeListener(_markDirty);
      c.dispose();
    }
    for (final c in _instructionControllers) {
      c.removeListener(_markDirty);
      c.dispose();
    }
    super.dispose();
  }

  void _addIngredient() {
    final c = TextEditingController()..addListener(_markDirty);
    setState(() {
      _ingredientControllers.add(c);
      _isDirty = true;
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredientControllers[index].removeListener(_markDirty);
      _ingredientControllers[index].dispose();
      _ingredientControllers.removeAt(index);
      _isDirty = true;
    });
  }

  void _reorderIngredient(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final c = _ingredientControllers.removeAt(oldIndex);
      _ingredientControllers.insert(newIndex, c);
      _isDirty = true;
    });
  }

  void _addInstruction() {
    final c = TextEditingController()..addListener(_markDirty);
    setState(() {
      _instructionControllers.add(c);
      _isDirty = true;
    });
  }

  void _removeInstruction(int index) {
    setState(() {
      _instructionControllers[index].removeListener(_markDirty);
      _instructionControllers[index].dispose();
      _instructionControllers.removeAt(index);
      _isDirty = true;
    });
  }

  void _reorderInstruction(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final c = _instructionControllers.removeAt(oldIndex);
      _instructionControllers.insert(newIndex, c);
      _isDirty = true;
    });
  }

  Future<bool> _confirmDiscard() async {
    final shouldDiscard = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes that will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return shouldDiscard ?? false;
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final servings = _servingsController.text.trim();
    final difficulty = _difficultyController.text.trim();
    final prepTime = int.tryParse(_prepTimeMinsController.text.trim());
    final cookTime = int.tryParse(_cookTimeMinsController.text.trim());
    final totalTime = int.tryParse(_totalTimeMinsController.text.trim());

    final ingredients = _ingredientControllers
        .asMap()
        .entries
        .where((e) => e.value.text.trim().isNotEmpty)
        .map((e) => Ingredient(
              id: e.key < widget.recipe.ingredients.length
                  ? widget.recipe.ingredients[e.key].id
                  : 'ing-${widget.recipe.id}-${e.key}',
              name: e.value.text.trim(),
              sortOrder: e.key,
            ))
        .toList();

    final instructions = _instructionControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    try {
      final updated = Recipe(
        id: widget.recipe.id,
        title: title.isNotEmpty ? title : widget.recipe.title,
        description:
            description.isNotEmpty ? description : widget.recipe.description,
        servings: servings.isNotEmpty ? servings : widget.recipe.servings,
        difficulty:
            difficulty.isNotEmpty ? difficulty : widget.recipe.difficulty,
        prepTimeMins: prepTime ?? widget.recipe.prepTimeMins,
        cookTimeMins: cookTime ?? widget.recipe.cookTimeMins,
        totalTimeMins: totalTime ?? widget.recipe.totalTimeMins,
        ingredients:
            ingredients.isNotEmpty ? ingredients : widget.recipe.ingredients,
        instructions:
            instructions.isNotEmpty ? instructions : widget.recipe.instructions,
        categories: widget.recipe.categories,
        tags: widget.recipe.tags,
        videoUrl: widget.recipe.videoUrl,
        videoPlatform: widget.recipe.videoPlatform,
        recipePageUrl: widget.recipe.recipePageUrl,
        recipeSiteName: widget.recipe.recipeSiteName,
        thumbnailUrl: widget.recipe.thumbnailUrl,
        authorName: widget.recipe.authorName,
        extractionMethod: widget.recipe.extractionMethod,
        extractionConfidence: widget.recipe.extractionConfidence,
        createdAt: widget.recipe.createdAt,
        updatedAt: DateTime.now(),
      );
      await ref.read(localDbServiceProvider).updateRecipe(updated);
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
    return PopScope(
      canPop: !_isDirty,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final discard = await _confirmDiscard();
        if (discard && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
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
              Text('Title', style: Theme.of(context).textTheme.titleMedium),
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
              Text('Description',
                  style: Theme.of(context).textTheme.titleMedium),
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
              Text('Servings', style: Theme.of(context).textTheme.titleMedium),
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
              Text('Difficulty',
                  style: Theme.of(context).textTheme.titleMedium),
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
              Text('Prep Time (minutes)',
                  style: Theme.of(context).textTheme.titleMedium),
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
              Text('Cook Time (minutes)',
                  style: Theme.of(context).textTheme.titleMedium),
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
              Text('Total Time (minutes)',
                  style: Theme.of(context).textTheme.titleMedium),
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
                  Text('Ingredients',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 8),
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorder: _reorderIngredient,
                children: [
                  for (int i = 0; i < _ingredientControllers.length; i++)
                    _buildIngredientRow(i, _ingredientControllers[i]),
                ],
              ),
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
                  Text('Instructions',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 8),
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorder: _reorderInstruction,
                children: [
                  for (int i = 0; i < _instructionControllers.length; i++)
                    _buildInstructionRow(i, _instructionControllers[i]),
                ],
              ),
              TextButton.icon(
                onPressed: _addInstruction,
                icon: const Icon(Icons.add),
                label: const Text('Add step'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIngredientRow(int index, TextEditingController controller) {
    return Padding(
      key: ObjectKey(controller),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.drag_handle, color: Colors.grey),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
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
  }

  Widget _buildInstructionRow(int index, TextEditingController controller) {
    return Padding(
      key: ObjectKey(controller),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              child: Icon(Icons.drag_handle, color: Colors.grey),
            ),
          ),
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
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
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
  }
}
