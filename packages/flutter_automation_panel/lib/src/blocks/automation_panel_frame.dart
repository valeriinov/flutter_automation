import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_count.dart';
import 'package:flutter_automation_panel/src/blocks/automation_panel_status.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_theme.dart';
import 'package:flutter_automation_panel/src/theme/automation_panel_strings.dart';

/// {@category Widgets}
///
/// The frame of a panel page: a header, an optional status row, optional tabs,
/// the body and an optional footer.
///
/// A page with an [onBack] callback is a nested page. Its header shows a back
/// button, a smaller title and a [subtitle]. Any other page shows the QA logo
/// and the title.
///
/// The frame fills the screen: the header stands below the status bar, and the
/// footer or the body ends above the bottom system area. The status bar shows
/// dark icons over the light header.
class AutomationPanelFrame extends StatelessWidget {
  /// Title of the page.
  final String title;

  /// Line under the title of a nested page.
  final String? subtitle;

  /// Called when the tester taps the back button of a nested page.
  final VoidCallback? onBack;

  /// Called when the tester taps the cross.
  final VoidCallback onClose;

  /// The status row, missing when the page shows none.
  final AutomationPanelStatus? status;

  /// Labels of the tabs, none for a page without tabs.
  final List<String> tabs;

  /// Index of the chosen tab.
  final int selectedTab;

  /// Called with the index of the tab the tester taps.
  final ValueChanged<int>? onTabSelected;

  /// Content of the page.
  final Widget child;

  /// Content pinned under the body, such as the result and the buttons.
  final Widget? footer;

  const AutomationPanelFrame({
    required this.title,
    required this.onClose,
    required this.child,
    this.subtitle,
    this.onBack,
    this.status,
    this.tabs = const [],
    this.selectedTab = 0,
    this.onTabSelected,
    this.footer,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);
    final status = this.status;
    final footer = this.footer;
    final systemPadding = MediaQuery.paddingOf(context);

    return AnnotatedRegion(
      value: SystemUiOverlayStyle.dark,
      child: ColoredBox(
        color: theme.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              title: title,
              subtitle: subtitle,
              onBack: onBack,
              onClose: onClose,
              systemTop: systemPadding.top,
            ),
            if (status != null) _StatusRow(status: status),
            if (tabs.isNotEmpty)
              _Tabs(
                tabs: tabs,
                selectedTab: selectedTab,
                onTabSelected: onTabSelected,
              ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                removeBottom: true,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: footer == null ? systemPadding.bottom : 0,
                  ),
                  child: child,
                ),
              ),
            ),
            if (footer != null)
              _Footer(systemBottom: systemPadding.bottom, child: footer),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final VoidCallback onClose;
  final double systemTop;

  const _Header({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onClose,
    required this.systemTop,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);
    final subtitle = this.subtitle;
    final isNested = onBack != null;

    return Container(
      constraints: BoxConstraints(minHeight: 56 + systemTop),
      padding: EdgeInsets.fromLTRB(isNested ? 6 : 16, 6 + systemTop, 6, 0),
      decoration: BoxDecoration(
        color: theme.surface,
        border: isNested ? Border(bottom: BorderSide(color: theme.line)) : null,
      ),
      child: Row(
        spacing: isNested ? 6 : 10,
        children: [
          if (isNested)
            IconButton(
              onPressed: onBack,
              tooltip: AutomationPanelStrings.back,
              icon: const Icon(Icons.chevron_left, size: 28),
            )
          else
            const _Logo(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textStyle(
                    size: isNested ? 17 : 20,
                    weight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: theme.textStyle(
                      size: 12,
                      color: theme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            tooltip: AutomationPanelStrings.closePanel,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: theme.accent),
      child: Text(
        AutomationPanelStrings.qaBadge,
        style: theme.textStyle(
          size: 12,
          weight: FontWeight.w700,
          color: theme.surface,
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  final List<String> tabs;
  final int selectedTab;
  final ValueChanged<int>? onTabSelected;

  const _Tabs({
    required this.tabs,
    required this.selectedTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(bottom: BorderSide(color: theme.line)),
      ),
      child: Row(
        children: [
          for (int index = 0; index < tabs.length; index += 1)
            Expanded(
              child: _Tab(
                label: tabs[index],
                isSelected: index == selectedTab,
                onPressed: () => onTabSelected?.call(index),
              ),
            ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final double systemBottom;
  final Widget child;

  const _Footer({required this.systemBottom, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        max(24, systemBottom + AutomationPanelTheme.gapSmall),
      ),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(top: BorderSide(color: theme.line)),
      ),
      child: child,
    );
  }
}

class _StatusRow extends StatelessWidget {
  final AutomationPanelStatus status;

  const _StatusRow({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return Container(
      color: theme.surface,
      constraints: const BoxConstraints(
        minHeight: AutomationPanelTheme.touchTarget,
      ),
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        children: [
          Expanded(child: _StatusState(status: status)),
          for (final action in status.actions)
            TextButton(
              onPressed: action.onPressed,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, AutomationPanelTheme.touchTarget),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: theme.textStyle(size: 13, weight: FontWeight.w600),
              ),
              child: Text(action.label),
            ),
        ],
      ),
    );
  }
}

class _StatusState extends StatelessWidget {
  final AutomationPanelStatus status;

  const _StatusState({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);
    final onPressed = status.onPressed;

    return InkWell(
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AutomationPanelTheme.touchTarget,
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 4),
          child: Row(
            spacing: AutomationPanelTheme.gapSmall,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: status.isChanged ? theme.accent : theme.textMuted,
                ),
                child: const SizedBox.square(dimension: 8),
              ),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    text: status.text,
                    children: [
                      if (status.changeCount > 0)
                        TextSpan(
                          text: ' · ',
                          children: [
                            TextSpan(
                              text: describeCount(
                                status.changeCount,
                                AutomationPanelStrings.changeNoun,
                              ),
                              style: TextStyle(
                                color: theme.danger,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  style: theme.textStyle(size: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onPressed != null)
                Icon(Icons.chevron_right, size: 18, color: theme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  const _Tab({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AutomationPanelTheme.of(context);

    return InkWell(
      onTap: onPressed,
      child: Container(
        height: AutomationPanelTheme.touchTarget,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? theme.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: theme.textStyle(
            size: 14,
            weight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? theme.accent : theme.textSecondary,
          ),
        ),
      ),
    );
  }
}
