import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/icon_mapper.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_strings.dart';
import '../domain/category_model.dart';
import 'categories_controller.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openCategorySheet({
    CategoryModel? existing,
    CategoryType? initialType,
  }) async {
    await showModalBottomSheet<CategoryModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext ctx) {
        return CategoryFormSheet(
          existing: existing,
          initialType:
              initialType ??
              (_tabController.index == 0
                  ? CategoryType.expense
                  : CategoryType.income),
        );
      },
    );
  }

  Future<void> _handleDelete(CategoryModel category) async {
    final AppStrings strings = AppStrings.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(strings.delete),
          content: Text(
            strings.tr(
              'ต้องการลบหมวดหมู่ "${category.name}" ใช่หรือไม่?',
              'Delete category "${category.name}"?',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
              child: Text(strings.delete),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await ref
          .read(categoriesControllerProvider.notifier)
          .deleteCategory(category.id);
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      if (e.isCategoryInUse) {
        final bool? archiveInstead = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) {
            return AlertDialog(
              title: Text(strings.archive),
              content: Text(e.localizedMessage(strings)),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(strings.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(strings.archive),
                ),
              ],
            );
          },
        );
        if (archiveInstead == true && mounted) {
          await ref
              .read(categoriesControllerProvider.notifier)
              .updateCategory(category.id, isArchived: true);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.localizedMessage(strings))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final CategoriesState state = ref.watch(categoriesControllerProvider);
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.categoriesTitle),
        actions: <Widget>[
          FilterChip(
            label: Text(strings.showArchived),
            selected: state.includeArchived,
            onSelected: (bool val) {
              ref
                  .read(categoriesControllerProvider.notifier)
                  .loadCategories(includeArchived: val);
            },
          ),
          const SizedBox(width: 12),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: <Widget>[
            Tab(text: strings.expense),
            Tab(text: strings.income),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCategorySheet(),
        icon: const Icon(Icons.add_rounded),
        label: Text(strings.addCategory),
      ),
      body: ResponsiveCenter(
        child: state.isLoading && state.items.isEmpty
            ? ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, __) => const SkeletonBox(height: 68),
              )
            : TabBarView(
                controller: _tabController,
                children: <Widget>[
                  _buildCategoryList(
                    state.byType(CategoryType.expense),
                    CategoryType.expense,
                    strings,
                    theme,
                  ),
                  _buildCategoryList(
                    state.byType(CategoryType.income),
                    CategoryType.income,
                    strings,
                    theme,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCategoryList(
    List<CategoryModel> list,
    CategoryType type,
    AppStrings strings,
    ThemeData theme,
  ) {
    if (list.isEmpty) {
      return EmptyStateView(
        icon: Icons.category_outlined,
        title: strings.noData,
        actionLabel: strings.addCategory,
        onAction: () => _openCategorySheet(initialType: type),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(categoriesControllerProvider.notifier).loadCategories(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (BuildContext context, int index) {
          final CategoryModel item = list[index];
          final Color color = AppColors.fromHex(item.color);
          return PremiumCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            onTap: () => _openCategorySheet(existing: item),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withAlpha(32),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    IconMapper.resolve(item.icon),
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration: item.isArchived
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (item.isArchived)
                        Text(
                          strings.archive,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (String value) async {
                    if (value == 'edit') {
                      await _openCategorySheet(existing: item);
                    } else if (value == 'archive') {
                      await ref
                          .read(categoriesControllerProvider.notifier)
                          .updateCategory(
                            item.id,
                            isArchived: !item.isArchived,
                          );
                    } else if (value == 'delete') {
                      await _handleDelete(item);
                    }
                  },
                  itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Text(strings.edit),
                    ),
                    PopupMenuItem<String>(
                      value: 'archive',
                      child: Text(
                        item.isArchived ? strings.unarchive : strings.archive,
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text(
                        strings.delete,
                        style: const TextStyle(color: AppColors.expense),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class CategoryFormSheet extends ConsumerStatefulWidget {
  const CategoryFormSheet({
    super.key,
    this.existing,
    this.initialType = CategoryType.expense,
  });

  final CategoryModel? existing;
  final CategoryType initialType;

  @override
  ConsumerState<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<CategoryFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late CategoryType _selectedType;
  late String _selectedIcon;
  late String _selectedColor;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _selectedType = widget.existing?.type ?? widget.initialType;
    _selectedIcon = widget.existing?.icon ?? 'restaurant';
    _selectedColor =
        widget.existing?.color ?? AppColors.presetHexColors.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    HapticFeedback.lightImpact();
    final AppStrings strings = AppStrings.of(context);

    try {
      CategoryModel result;
      if (widget.existing == null) {
        result = await ref
            .read(categoriesControllerProvider.notifier)
            .createCategory(
              name: _nameController.text.trim(),
              type: _selectedType,
              icon: _selectedIcon,
              color: _selectedColor,
            );
      } else {
        result = await ref
            .read(categoriesControllerProvider.notifier)
            .updateCategory(
              widget.existing!.id,
              name: _nameController.text.trim(),
              icon: _selectedIcon,
              color: _selectedColor,
            );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(result);
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.localizedMessage(strings))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
    final bool isEditing = widget.existing != null;
    final Color activeColor = AppColors.fromHex(_selectedColor);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    isEditing ? strings.editCategory : strings.addCategory,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!isEditing) ...<Widget>[
                SegmentedButton<CategoryType>(
                  segments: <ButtonSegment<CategoryType>>[
                    ButtonSegment<CategoryType>(
                      value: CategoryType.expense,
                      label: Text(strings.expense),
                      icon: const Icon(Icons.south_west_rounded, size: 18),
                    ),
                    ButtonSegment<CategoryType>(
                      value: CategoryType.income,
                      label: Text(strings.income),
                      icon: const Icon(Icons.north_east_rounded, size: 18),
                    ),
                  ],
                  selected: <CategoryType>{_selectedType},
                  onSelectionChanged: (Set<CategoryType> next) {
                    setState(() => _selectedType = next.first);
                  },
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: strings.categoryName,
                  prefixIcon: Icon(
                    IconMapper.resolve(_selectedIcon),
                    color: activeColor,
                  ),
                ),
                validator: (String? v) {
                  if (v == null || v.trim().isEmpty) {
                    return strings.tr(
                      'กรุณากรอกชื่อหมวดหมู่',
                      'Please enter category name',
                    );
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Text(
                strings.selectColor,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: AppColors.presetHexColors.map((String hex) {
                  final Color c = AppColors.fromHex(hex);
                  final bool selected =
                      hex.toUpperCase() == _selectedColor.toUpperCase();
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = hex),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(
                                color: theme.colorScheme.onSurface,
                                width: 3,
                              )
                            : null,
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Text(
                strings.selectIcon,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 180,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: IconMapper.allKeys.length,
                  itemBuilder: (BuildContext context, int index) {
                    final String key = IconMapper.allKeys[index];
                    final bool selected = key == _selectedIcon;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _selectedIcon = key),
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected
                              ? activeColor.withAlpha(36)
                              : theme.colorScheme.surfaceContainerHighest
                                    .withAlpha(60),
                          borderRadius: BorderRadius.circular(12),
                          border: selected
                              ? Border.all(color: activeColor, width: 2)
                              : null,
                        ),
                        child: Icon(
                          IconMapper.resolve(key),
                          color: selected
                              ? activeColor
                              : theme.colorScheme.onSurfaceVariant,
                          size: 22,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(strings.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
