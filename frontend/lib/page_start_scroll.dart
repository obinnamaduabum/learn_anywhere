import 'package:flutter/widgets.dart';

import 'page_notices.dart';

/// Starts the visible page at its beginning on forward and back navigation.
class PageStartScrollObserver extends NavigatorObserver {
  void reset(Route<dynamic>? route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route is! ModalRoute || !route.isCurrent) return;
      final context = route.subtreeContext;
      if (context is! Element || !context.mounted) return;
      void visit(Element element) {
        if (element is StatefulElement && element.state is ScrollableState) {
          final state = element.state as ScrollableState;
          if (state.position.hasContentDimensions &&
              axisDirectionToAxis(state.position.axisDirection) ==
                  Axis.vertical) {
            state.position.jumpTo(state.position.minScrollExtent);
          }
        }
        element.visitChildElements(visit);
      }

      visit(context);
    });
  }

  void clear(Route<dynamic>? route) {
    if (route is ModalRoute && route.subtreeContext != null) {
      clearPageNotices(route.subtreeContext!);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    clear(previousRoute);
    reset(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    clear(route);
    reset(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    clear(oldRoute);
    reset(newRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      clear(route);
}
