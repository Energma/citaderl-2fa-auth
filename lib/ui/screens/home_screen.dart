import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/profile.dart';
import '../../core/providers.dart';
import '../widgets/token_card.dart';
import 'add_token_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  DateTime? _pausedAt;
  TabController? _tabController;
  List<Profile> _profiles = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed && _pausedAt != null) {
      final lockDuration = ref.read(autoLockDurationProvider);
      if (DateTime.now().difference(_pausedAt!) > lockDuration) {
        ref.read(vaultProvider.notifier).lock();
      }
      _pausedAt = null;
    }
  }

  void _rebuildTabs(List<Profile> profiles) {
    if (_listEquals(profiles, _profiles)) return;
    _profiles = profiles;
    final oldIndex = _tabController?.index ?? 0;
    _tabController?.dispose();
    _tabController = TabController(
      length: profiles.length + 1, // +1 for "All"
      vsync: this,
      initialIndex: oldIndex.clamp(0, profiles.length),
    );
    _tabController!.addListener(_onTabChanged);
  }

  bool _listEquals(List<Profile> a, List<Profile> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].name != b[i].name) return false;
    }
    return true;
  }

  void _onTabChanged() {
    if (!_tabController!.indexIsChanging) {
      final index = _tabController!.index;
      if (index == 0) {
        ref.read(activeProfileIdProvider.notifier).state = null;
      } else {
        ref.read(activeProfileIdProvider.notifier).state =
            _profiles[index - 1].id;
      }
    }
  }

  void _deleteToken(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Token'),
        content: const Text(
          'This will permanently remove this token. You may lose access to the associated account if you don\'t have a backup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(tokenRepositoryProvider).delete(id);
      ref.invalidate(tokenListProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = _isSearching
        ? ref.watch(searchResultsProvider)
        : ref.watch(tokenListProvider);
    final profiles = ref.watch(profileListProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return profiles.when(
      data: (profileList) {
        _rebuildTabs(profileList);
        return Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              _buildAppBar(theme, isDark, innerBoxIsScrolled),
            ],
            body: tokens.when(
              data: (tokenList) {
                if (tokenList.isEmpty) return _buildEmptyState(theme);
                return _buildTokenList(tokenList);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
          floatingActionButton: _buildFab(theme),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const Scaffold(
        body: Center(child: Text('Failed to load profiles')),
      ),
    );
  }

  Widget _buildAppBar(ThemeData theme, bool isDark, bool innerBoxIsScrolled) {
    return SliverAppBar(
      floating: true,
      snap: true,
      pinned: true,
      expandedHeight: _isSearching ? null : null,
      title: _isSearching
          ? _buildSearchField(theme)
          : Text(
              'Citadel',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: theme.colorScheme.onSurface,
              ),
            ),
      actions: [
        IconButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
              key: ValueKey(_isSearching),
            ),
          ),
          onPressed: () {
            setState(() => _isSearching = !_isSearching);
            if (!_isSearching) {
              _searchController.clear();
              ref.read(searchQueryProvider.notifier).state = '';
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings_rounded),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
        const SizedBox(width: 4),
      ],
      bottom: _isSearching ? null : _buildTabBar(theme, isDark),
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return TextField(
      controller: _searchController,
      autofocus: true,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: 'Search tokens...',
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withAlpha(100),
        ),
        border: InputBorder.none,
        filled: false,
      ),
      onChanged: (q) => ref.read(searchQueryProvider.notifier).state = q,
    );
  }

  PreferredSizeWidget _buildTabBar(ThemeData theme, bool isDark) {
    if (_tabController == null) {
      return const PreferredSize(
        preferredSize: Size.fromHeight(0),
        child: SizedBox.shrink(),
      );
    }

    return PreferredSize(
      preferredSize: const Size.fromHeight(52),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                indicatorSize: TabBarIndicatorSize.label,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: theme.colorScheme.primary.withAlpha(isDark ? 40 : 25),
                ),
                dividerColor: Colors.transparent,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor:
                    theme.colorScheme.onSurface.withAlpha(140),
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                splashBorderRadius: BorderRadius.circular(12),
                tabs: [
                  _buildTab('All', null),
                  ..._profiles.map((p) => _buildTab(p.name, p.color)),
                ],
              ),
            ),
            _buildManageButton(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, Color? dotColor) {
    return Tab(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _buildManageButton(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: IconButton(
        icon: Icon(
          Icons.tune_rounded,
          size: 20,
          color: theme.colorScheme.onSurface.withAlpha(120),
        ),
        tooltip: 'Manage profiles',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        ).then((_) => ref.invalidate(profileListProvider)),
        style: IconButton.styleFrom(
          padding: const EdgeInsets.all(8),
          minimumSize: const Size(36, 36),
        ),
      ),
    );
  }

  Widget _buildTokenList(List<dynamic> tokenList) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(tokenListProvider),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 12, bottom: 96, left: 4, right: 4),
        itemCount: tokenList.length,
        itemBuilder: (context, index) {
          final token = tokenList[index];
          return TokenCard(
            token: token,
            onDelete: () => _deleteToken(token.id),
            onEdit: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddTokenScreen(editToken: token),
                ),
              );
              ref.invalidate(tokenListProvider);
            },
          );
        },
      ),
    );
  }

  Widget _buildFab(ThemeData theme) {
    return FloatingActionButton(
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddTokenScreen()),
        );
        ref.invalidate(tokenListProvider);
      },
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Icon(Icons.add_rounded, size: 28),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final activeId = ref.watch(activeProfileIdProvider);
    final profileName = activeId != null
        ? _profiles
            .where((p) => p.id == activeId)
            .map((p) => p.name)
            .firstOrNull
        : null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.shield_outlined,
                size: 40,
                color: theme.colorScheme.primary.withAlpha(160),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              profileName != null
                  ? 'No $profileName tokens'
                  : 'No tokens yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withAlpha(180),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add your first 2FA token',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(100),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
