import 'package:flutter/material.dart';

/// Outgoing tab widgets remain mounted briefly during their animation.
class PageNoticeScope extends InheritedWidget {
  const PageNoticeScope({
    super.key,
    required this.isActive,
    required super.child,
  });
  final bool Function() isActive;

  @override
  bool updateShouldNotify(PageNoticeScope oldWidget) =>
      isActive != oldWidget.isActive;
}

bool isNoticePageCurrent(BuildContext context) {
  if (!context.mounted || ModalRoute.of(context)?.isCurrent == false) {
    return false;
  }
  return context.getInheritedWidgetOfExactType<PageNoticeScope>()?.isActive() ??
      true;
}

void clearPageNotices(BuildContext context) {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.clearSnackBars();
  messenger?.removeCurrentSnackBar();
}

void showPageSnackBar(BuildContext context, SnackBar notice) {
  if (!isNoticePageCurrent(context)) return;
  clearPageNotices(context);
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(notice);
}
