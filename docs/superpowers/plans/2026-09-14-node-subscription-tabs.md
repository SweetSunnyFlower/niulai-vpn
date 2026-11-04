# 节点订阅 Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 节点浏览器增加“全部 / 各订阅”等宽、可横向滚动的 Tab，并在 Tab 中显示可用节点统计。

**Architecture:** 直接在 `NodesScreen` 中计算订阅 Tab 和过滤节点，使用横向 `SingleChildScrollView + Row` 实现等宽 Tab。

**Tech Stack:** Flutter、Provider、flutter_test。

---

## File Structure

- Modify: `lib/screens/nodes_screen.dart`

---

### Task 1: Add tab state and filtering

**Files:**
- Modify: `lib/screens/nodes_screen.dart`

- [ ] **Step 1: Add state**

```dart
String? _selectedSubscriptionId;
```

- [ ] **Step 2: Compute visible nodes**

Replace current `final nodes = allNodes.where((node) => node.isConnectable).toList();` with:

```dart
final connectable = allNodes.where((node) => node.isConnectable).toList();
final nodes = _selectedSubscriptionId == null
    ? connectable
    : controller.subscriptions
          .where((subscription) => subscription.id == _selectedSubscriptionId)
          .expand((subscription) => subscription.nodes)
          .where((node) => node.isConnectable)
          .toList();
```

- [ ] **Step 3: Add tab data builder**

```dart
List<_SubscriptionTabData> _buildTabs(AppController controller) {
  final allNodes = controller.allNodes;
  final totalAll = allNodes.length;
  final availableAll = allNodes.where((node) => node.isConnectable).length;
  final tabs = [
    _SubscriptionTabData(
      id: null,
      label: '全部',
      total: totalAll,
      available: availableAll,
    ),
  ];
  for (final subscription in controller.subscriptions) {
    final nodes = subscription.nodes;
    tabs.add(
      _SubscriptionTabData(
        id: subscription.id,
        label: subscription.displayName,
        total: nodes.length,
        available: nodes.where((node) => node.isConnectable).length,
      ),
    );
  }
  return tabs;
}
```

- [ ] **Step 4: Analyze**

Run: `flutter analyze --no-pub`
Expected: no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/nodes_screen.dart
git commit -m "feat: compute node subscription tabs"
```

---

### Task 2: Render tabs

**Files:**
- Modify: `lib/screens/nodes_screen.dart`

- [ ] **Step 1: Add tab widget**

After header and before list, replace count row with:

```dart
_NodeSubscriptionTabs(
  tabs: _buildTabs(controller),
  selectedId: _selectedSubscriptionId,
  onSelected: (id) {
    setState(() => _selectedSubscriptionId = id);
  },
),
```

- [ ] **Step 2: Implement widgets**

```dart
class _SubscriptionTabData {
  const _SubscriptionTabData({
    required this.id,
    required this.label,
    required this.total,
    required this.available,
  });
  final String? id;
  final String label;
  final int total;
  final int available;
}

class _NodeSubscriptionTabs extends StatelessWidget {
  const _NodeSubscriptionTabs({
    required this.tabs,
    required this.selectedId,
    required this.onSelected,
  });
  final List<_SubscriptionTabData> tabs;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final tab = tabs[index];
          final selected = tab.id == selectedId;
          return GestureDetector(
            onTap: () => onSelected(tab.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.cyan.withValues(alpha: .16)
                    : AppColors.surface.withValues(alpha: .72),
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              child: Text(
                '${tab.label} ${tab.available}/${tab.total}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? AppColors.cyan
                      : AppColors.textSecondary,
                  fontWeight: selected
                      ? FontWeight.w700
                      : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 3: Analyze/test**

Run: `flutter analyze --no-pub && flutter test --no-pub`
Expected: pass.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/nodes_screen.dart
git commit -m "feat: render node subscription tabs"
```

---

### Task 3: Final verification

- [ ] **Step 1: Run checks**

```bash
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug
```

- [ ] **Step 2: Manual smoke**

1. 打开节点浏览器。
2. 检查“全部”Tab 和订阅 Tab。
3. 点击订阅 Tab。
4. 确认列表只显示该订阅节点。
5. 检查 Tab 数量统计。

- [ ] **Step 3: Commit any fixes**

```bash
git add -A
git commit -m "test: finalize node subscription tabs"
```

---

## Self-Review

- Spec coverage: all requirements map to Tasks 1-2.
- Placeholder scan: no TODO/TBD placeholders.
- Type consistency: `_SubscriptionTabData`, `_NodeSubscriptionTabs`, `_selectedSubscriptionId` names are consistent.
