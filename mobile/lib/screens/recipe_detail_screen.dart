import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/providers.dart';
import '../models/recipe.dart';

class RecipeDetailScreen extends ConsumerWidget {
  final String recipeId;

  const RecipeDetailScreen({super.key, required this.recipeId});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _deleteRecipe(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recipe'),
        content: const Text('Are you sure you want to delete this recipe?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(apiServiceProvider).deleteRecipe(recipeId);
        ref.read(recipesProvider.notifier).removeRecipe(recipeId);
        if (context.mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipeAsync = ref.watch(recipeDetailProvider(recipeId));

    return Scaffold(
      body: recipeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64),
              const SizedBox(height: 16),
              Text('Failed to load recipe'),
              const SizedBox(height: 8),
              Text(error.toString()),
            ],
          ),
        ),
        data: (recipe) => _buildContent(context, ref, recipe),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, Recipe recipe) {
    return CustomScrollView(
      slivers: [
        // App bar with image
        SliverAppBar(
          expandedHeight: 250,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              recipe.title,
              style: const TextStyle(
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
            background: recipe.thumbnailUrl != null
                ? CachedNetworkImage(
                    imageUrl: recipe.thumbnailUrl!,
                    fit: BoxFit.cover,
                    color: Colors.black26,
                    colorBlendMode: BlendMode.darken,
                  )
                : Container(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.restaurant,
                      size: 80,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
          ),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteRecipe(context, ref);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),

        // Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick info
                _buildQuickInfo(context, recipe),
                const SizedBox(height: 16),

                // Source links
                if (recipe.videoUrl != null || recipe.recipePageUrl != null)
                  _buildSourceLinks(context, recipe),

                // Description
                if (recipe.description != null) ...[
                  const SizedBox(height: 16),
                  Text(recipe.description!,
                       style: Theme.of(context).textTheme.bodyLarge),
                ],

                // Categories
                if (recipe.categories.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildCategories(context, recipe),
                ],

                // Ingredients
                const SizedBox(height: 24),
                _buildIngredients(context, recipe),

                // Instructions
                if (recipe.instructions != null && recipe.instructions!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildInstructions(context, recipe),
                ],

                // Tags
                if (recipe.tags.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildTags(context, recipe),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickInfo(BuildContext context, Recipe recipe) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            if (recipe.prepTimeMins != null)
              _buildInfoItem(context, Icons.timer_outlined, 'Prep',
                  '${recipe.prepTimeMins} min'),
            if (recipe.cookTimeMins != null)
              _buildInfoItem(context, Icons.local_fire_department, 'Cook',
                  '${recipe.cookTimeMins} min'),
            if (recipe.totalTimeMins != null)
              _buildInfoItem(
                  context, Icons.schedule, 'Total', recipe.formattedTime!),
            if (recipe.servings != null)
              _buildInfoItem(
                  context, Icons.people, 'Serves', recipe.servings!),
            if (recipe.difficulty != null)
              _buildInfoItem(context, Icons.signal_cellular_alt, 'Level',
                  recipe.difficulty!),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(
      BuildContext context, IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSourceLinks(BuildContext context, Recipe recipe) {
    return Card(
      child: Column(
        children: [
          if (recipe.videoUrl != null)
            ListTile(
              leading: Icon(
                recipe.videoPlatform == 'youtube'
                    ? Icons.play_circle_filled
                    : Icons.camera_alt,
                color: recipe.videoPlatform == 'youtube'
                    ? Colors.red
                    : Colors.purple,
              ),
              title: Text(recipe.videoPlatform == 'youtube'
                  ? 'Watch on YouTube'
                  : 'View on Instagram'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _openUrl(recipe.videoUrl!),
            ),
          if (recipe.recipePageUrl != null) ...[
            if (recipe.videoUrl != null) const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.article, color: Colors.blue),
              title: Text(recipe.recipeSiteName != null
                  ? 'Recipe on ${recipe.recipeSiteName}'
                  : 'View Full Recipe'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _openUrl(recipe.recipePageUrl!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategories(BuildContext context, Recipe recipe) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: recipe.categories.map((cat) {
        return Chip(
          label: Text(cat.name),
          avatar: Icon(_categoryIcon(cat.type), size: 18),
        );
      }).toList(),
    );
  }

  IconData _categoryIcon(String type) {
    switch (type) {
      case 'dietary':
        return Icons.eco;
      case 'protein':
        return Icons.egg;
      case 'course':
        return Icons.restaurant_menu;
      case 'cuisine':
        return Icons.public;
      case 'method':
        return Icons.microwave;
      case 'season':
        return Icons.wb_sunny;
      case 'difficulty':
        return Icons.signal_cellular_alt;
      case 'time':
        return Icons.schedule;
      default:
        return Icons.label;
    }
  }

  Widget _buildIngredients(BuildContext context, Recipe recipe) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.list, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text('Ingredients',
                style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recipe.ingredients.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final ing = recipe.ingredients[index];
              return ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(ing.displayText),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInstructions(BuildContext context, Recipe recipe) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.format_list_numbered,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text('Instructions',
                style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 12),
        ...recipe.instructions!.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(step)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTags(BuildContext context, Recipe recipe) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tags', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: recipe.tags.map((tag) {
            return Chip(
              label: Text(tag.tag),
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
            );
          }).toList(),
        ),
      ],
    );
  }
}
