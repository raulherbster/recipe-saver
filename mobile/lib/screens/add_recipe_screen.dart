import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import 'recipe_detail_screen.dart';

class AddRecipeScreen extends ConsumerStatefulWidget {
  final String? initialUrl;

  const AddRecipeScreen({super.key, this.initialUrl});

  @override
  ConsumerState<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends ConsumerState<AddRecipeScreen> {
  final _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null) {
      _urlController.text = widget.initialUrl!;
      _startExtraction();
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _urlController.text = data!.text!;
    }
  }

  void _startExtraction() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    ref.read(extractionProvider.notifier).extractRecipe(url: url);
  }

  void _reset() {
    ref.read(extractionProvider.notifier).reset();
    _urlController.clear();
  }

  void _viewRecipe(String recipeId) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(recipeId: recipeId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final extractionState = ref.watch(extractionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Recipe'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildUrlInput(),
            const SizedBox(height: 16),

            if (!extractionState.isExtracting && extractionState.result == null)
              FilledButton.icon(
                onPressed: _startExtraction,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Extract Recipe'),
              ),

            if (extractionState.isExtracting) _buildLoading(),

            if (extractionState.result != null)
              _buildResult(extractionState),

            if (extractionState.error != null && extractionState.result == null)
              _buildError(extractionState.error!),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Paste a recipe URL',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _urlController,
          decoration: InputDecoration(
            hintText: 'https://...',
            prefixIcon: const Icon(Icons.link),
            suffixIcon: IconButton(
              icon: const Icon(Icons.content_paste),
              onPressed: _pasteFromClipboard,
              tooltip: 'Paste from clipboard',
            ),
          ),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _startExtraction(),
        ),
        const SizedBox(height: 8),
        Text(
          'Supports YouTube, Instagram, and direct recipe website links.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Extracting recipe...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Looking for recipe links and parsing content',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(ExtractionState state) {
    final result = state.result!;

    if (!result.success) {
      return _buildError(result.error ?? 'No recipe found');
    }

    final recipe = result.recipe!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recipe extracted via ${result.method}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            Text(
              recipe.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (recipe.description != null) ...[
              const SizedBox(height: 8),
              Text(
                recipe.description!,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),

            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (recipe.ingredients.isNotEmpty)
                  _buildStat(Icons.list,
                      '${recipe.ingredients.length} ingredients'),
                if (recipe.formattedTime != null)
                  _buildStat(Icons.schedule, recipe.formattedTime!),
                if (recipe.difficulty != null)
                  _buildStat(Icons.signal_cellular_alt, recipe.difficulty!),
                if (recipe.recipeSiteName != null)
                  _buildStat(Icons.link, recipe.recipeSiteName!),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Add Another'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.check),
                    label: const Text('Done'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => _viewRecipe(recipe.id),
                icon: const Icon(Icons.visibility),
                label: const Text('View Full Recipe'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildError(String error) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'Extraction Failed',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
