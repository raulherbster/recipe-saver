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
  final _captionController = TextEditingController();
  bool _showCaptionField = false;

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
    _captionController.dispose();
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

    // Check if Instagram - show caption field
    if (url.contains('instagram.com') && !_showCaptionField) {
      setState(() => _showCaptionField = true);
      return;
    }

    ref.read(extractionProvider.notifier).extractRecipe(
          url: url,
          manualCaption: _showCaptionField ? _captionController.text : null,
        );
  }

  void _reset() {
    ref.read(extractionProvider.notifier).reset();
    _urlController.clear();
    _captionController.clear();
    setState(() => _showCaptionField = false);
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
            // URL Input
            _buildUrlInput(),
            const SizedBox(height: 16),

            // Instagram caption field
            if (_showCaptionField) ...[
              _buildCaptionInput(),
              const SizedBox(height: 16),
            ],

            // Extract button
            if (!extractionState.isExtracting && extractionState.response == null)
              FilledButton.icon(
                onPressed: _startExtraction,
                icon: const Icon(Icons.auto_awesome),
                label: Text(_showCaptionField ? 'Extract Recipe' : 'Extract Recipe'),
              ),

            // Loading state
            if (extractionState.isExtracting) _buildLoading(),

            // Result
            if (extractionState.response != null) _buildResult(extractionState),

            // Error
            if (extractionState.error != null && extractionState.response == null)
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
          'Paste a YouTube or Instagram URL',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _urlController,
          decoration: InputDecoration(
            hintText: 'https://youtube.com/watch?v=...',
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
          'We\'ll look for recipe links in the video description and extract the recipe automatically.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      ],
    );
  }

  Widget _buildCaptionInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.info_outline,
                 size: 20,
                 color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Instagram requires manual help',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Please paste the caption from the Instagram post. Check the bio for a recipe link too!',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _captionController,
          decoration: const InputDecoration(
            hintText: 'Paste caption here...',
            prefixIcon: Icon(Icons.notes),
          ),
          maxLines: 5,
          minLines: 3,
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
    final response = state.response!;

    if (!response.success) {
      return _buildError(response.error ?? response.message);
    }

    final recipe = response.recipe!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Success header
            Row(
              children: [
                Icon(Icons.check_circle,
                     color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    response.message,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Recipe preview
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

            // Quick stats
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (recipe.ingredients.isNotEmpty)
                  _buildStat(Icons.list, '${recipe.ingredients.length} ingredients'),
                if (recipe.formattedTime != null)
                  _buildStat(Icons.schedule, recipe.formattedTime!),
                if (recipe.difficulty != null)
                  _buildStat(Icons.signal_cellular_alt, recipe.difficulty!),
                if (recipe.recipeSiteName != null)
                  _buildStat(Icons.link, recipe.recipeSiteName!),
              ],
            ),
            const SizedBox(height: 16),

            // Confidence indicator
            if (response.confidence < 1.0) ...[
              LinearProgressIndicator(
                value: response.confidence,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 4),
              Text(
                'Extraction confidence: ${(response.confidence * 100).toInt()}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
            ],

            // Actions
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
                    onPressed: () {
                      Navigator.pop(context, true); // Return success
                    },
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
