import '../config.dart';

/// Enhanced widget pattern detector that supports complex Flutter patterns
class EnhancedWidgetPatternDetector {
  final LocalizationCheckerConfig config;
  final bool verbose;

  EnhancedWidgetPatternDetector({required this.config, this.verbose = false});

  /// Advanced UI patterns including state management and navigation
  static const List<String> advancedUiPatterns = [
    // Standard Flutter widgets
    'Text(', 'RichText(', 'TextFormField(', 'TextField(',
    'AppBar(', 'BottomNavigationBar(', 'Drawer(', 'TabBar(',
    'SnackBar(', 'AlertDialog(', 'Dialog(', 'SimpleDialog(',
    'ElevatedButton(', 'TextButton(', 'OutlinedButton(', 'IconButton(',
    'FloatingActionButton(', 'Tooltip(', 'Chip(', 'Card(',
    'ListTile(', 'ExpansionTile(', 'DataTable(', 'DataColumn(',
    'Banner(', 'MaterialBanner(', 'PopupMenuButton(',

    // Form and input widgets
    'DropdownMenuItem(', 'CheckboxListTile(', 'RadioListTile(',
    'SwitchListTile(', 'Slider(', 'RangeSlider(', 'Stepper(',
    'Step(', 'FormField(', 'DropdownButtonFormField(',

    // Navigation and routing
    'Route(', 'PageRoute(', 'MaterialPageRoute(', 'CupertinoPageRoute(',
    'Navigator.', 'GoRouter(', 'AutoRoute(', 'Beamer(',
    'VRouter(', 'FluroRouter(', 'GetX.', 'Get.', 'context.go(',
    'context.push(', 'context.replace(', 'pushNamed(', 'pushReplacementNamed(',

    // State management patterns
    'BlocBuilder(', 'BlocConsumer(', 'BlocListener(', 'BlocProvider(',
    'MultiBlocProvider(', 'Consumer(', 'ConsumerWidget(', 'ProviderScope(',
    'StateNotifierProvider(',
    'ChangeNotifierProvider(',
    'ValueNotifierProvider(',
    'RiverpodConsumer(', 'HookConsumer(', 'GetBuilder(', 'GetX(',
    'Obx(', 'ValueListenableBuilder(', 'StreamBuilder(', 'FutureBuilder(',

    // Error handling and feedback
    'ScaffoldMessenger.', 'showDialog(', 'showModalBottomSheet(',
    'showSnackBar(', 'showAboutDialog(', 'showDatePicker(', 'showTimePicker(',
    'showSearch(', 'showMenu(', 'showGeneralDialog(',

    // Custom and third-party widgets
    'CustomScrollView(', 'SliverAppBar(', 'SliverList(', 'SliverGrid(',
    'RefreshIndicator(', 'DraggableScrollableSheet(', 'BottomSheet(',
    'PersistentBottomSheetController(', 'Hero(', 'AnimatedSwitcher(',
    'PageView(', 'TabBarView(', 'IndexedStack(', 'Stepper(',

    // Property patterns for localization
    'title:', 'subtitle:', 'label:', 'labelText:', 'hintText:',
    'helperText:', 'errorText:', 'prefixText:', 'suffixText:',
    'placeholder:', 'message:', 'content:', 'text:', 'data:',
    'tooltip:', 'semanticLabel:', 'description:', 'name:',
    'validator:', 'autovalidateMode:', 'errorMessage:',

    // Accessibility patterns
    'Semantics(', 'ExcludeSemantics(', 'MergeSemantics(',
    'semanticsLabel:', 'onTap:', 'onPressed:', 'onChanged:',

    // Animation and transition patterns
    'AnimatedContainer(', 'AnimatedOpacity(', 'AnimatedAlign(',
    'Hero(', 'PageTransition(', 'SlideTransition(',

    // Platform-specific patterns
    'CupertinoAlertDialog(', 'CupertinoActionSheet(', 'CupertinoButton(',
    'CupertinoNavigationBar(', 'CupertinoTabBar(', 'CupertinoTextField(',
    'CupertinoDatePicker(', 'CupertinoTimerPicker(', 'CupertinoPicker(',

    // Package-specific patterns (common packages)
    'FlutterToast.', 'EasyLoading.', 'Flushbar(', 'GetSnackBar(',
    'AutoSizeText(', 'SelectableText(', 'ExpandableText(',
    'FormBuilderTextField(', 'FormBuilderDropdown(', 'FormBuilderCheckbox(',

    // Method invocations that often contain UI strings
    'showDialog(', 'showModalBottomSheet(', 'showSnackBar(', 'showAboutDialog(',
    'showDatePicker(', 'showTimePicker(', 'showSearch(', 'showMenu(',
    'pushNamed(', 'pushReplacementNamed(', 'push(', 'replace(',
    'go(', 'goNamed(', 'pop(', 'canPop(', 'maybePop(',
    'emit(', 'add(', 'call(', 'update(', 'refresh(', 'invalidate(',

    // Route context patterns
    'routes:', 'route:', 'routeName:', 'routeSettings:', 'arguments:',

    // Validation context patterns
    'validator:', 'validation:', 'errorMessage:', 'FormField(',
    'autovalidate:', 'autovalidateMode:',

    // Error handling patterns
    'onError:', 'error:', 'failure:', 'exception:', 'catch(',
    'try {', 'Error(', 'Exception(', 'Failure(',

    // State management method patterns
    'setState(', 'notifyListeners(', 'rebuild(', 'invalidate(',
    '.when(', '.map(', '.maybeWhen(', '.maybeMap(',
  ];

  /// Detects if a string literal is in a UI-related context based on surrounding code
  bool isInUiContext(String content, List<String> contextLines) {
    // Check each context line for UI patterns
    for (final line in contextLines) {
      // Check against advanced UI patterns
      if (advancedUiPatterns.any((pattern) => line.contains(pattern))) {
        if (verbose) {
          final foundPattern = advancedUiPatterns.firstWhere(
            (pattern) => line.contains(pattern),
          );
          print('✅ UI context found: $foundPattern in line: ${line.trim()}');
        }
        return true;
      }

      // Check custom UI patterns from config
      if (config.customUiPatterns.any((pattern) => line.contains(pattern))) {
        if (verbose) {
          final foundPattern = config.customUiPatterns.firstWhere(
            (pattern) => line.contains(pattern),
          );
          print(
            '✅ Custom UI context found: $foundPattern in line: ${line.trim()}',
          );
        }
        return true;
      }

      // Additional context-based checks
      if (_isInRouteContext(line) ||
          _isInValidationContext(line) ||
          _isInErrorHandlingContext(line) ||
          _isInStateManagementContext(line) ||
          _isInAccessibilityContext(line) ||
          _isInAnimationContext(line) ||
          _isInPlatformSpecificContext(line)) {
        return true;
      }
    }

    return false;
  }

  bool _isInRouteContext(String line) {
    final routePatterns = [
      'Route',
      'Navigator',
      'router',
      'go(',
      'push(',
      'pop(',
      'routes:',
      'routeName:',
      'routeSettings:',
      'arguments:',
      'MaterialPageRoute',
      'CupertinoPageRoute',
      'PageRouteBuilder',
      'GoRouter',
      'AutoRoute',
      'Beamer',
      'VRouter',
      'FluroRouter',
    ];

    return routePatterns.any((pattern) => line.contains(pattern));
  }

  bool _isInValidationContext(String line) {
    final validationPatterns = [
      'validator',
      'validation',
      'errorMessage',
      'FormField',
      'autovalidate',
      'autovalidateMode',
      'inputFormatters',
      'TextFormField',
      'DropdownButtonFormField',
      'FormBuilder',
    ];

    return validationPatterns.any((pattern) => line.contains(pattern));
  }

  bool _isInErrorHandlingContext(String line) {
    final errorPatterns = [
      'Error',
      'Exception',
      'catch',
      'onError',
      'failure',
      'try {',
      'throw',
      'rethrow',
      'StackTrace',
      'ErrorWidget',
    ];

    return errorPatterns.any((pattern) => line.contains(pattern));
  }

  bool _isInStateManagementContext(String line) {
    final statePatterns = [
      'Bloc',
      'Provider',
      'Consumer',
      'Riverpod',
      'GetX',
      'Get.',
      'setState',
      'notifyListeners',
      'emit',
      'add',
      'watch',
      'read',
      'ChangeNotifier',
      'ValueNotifier',
      'StreamController',
      'BehaviorSubject',
      'when(',
      'map(',
      'maybeWhen(',
      'maybeMap(',
      'rebuild(',
      'invalidate(',
    ];

    return statePatterns.any((pattern) => line.contains(pattern));
  }

  bool _isInAccessibilityContext(String line) {
    final accessibilityPatterns = [
      'Semantics',
      'semanticsLabel',
      'ExcludeSemantics',
      'MergeSemantics',
      'tooltip',
      'Tooltip',
      'semanticLabel',
      'onTap',
      'onPressed',
      'excludeFromSemantics',
      'semanticsValue',
      'semanticsHint',
    ];

    return accessibilityPatterns.any((pattern) => line.contains(pattern));
  }

  bool _isInAnimationContext(String line) {
    final animationPatterns = [
      'AnimatedContainer',
      'AnimatedOpacity',
      'AnimatedAlign',
      'AnimatedSize',
      'Hero',
      'PageTransition',
      'SlideTransition',
      'FadeTransition',
      'AnimationController',
      'Tween',
      'CurvedAnimation',
      'AnimatedBuilder',
    ];

    return animationPatterns.any((pattern) => line.contains(pattern));
  }

  bool _isInPlatformSpecificContext(String line) {
    final platformPatterns = [
      'Cupertino',
      'Material',
      'Platform.',
      'defaultTargetPlatform',
      'Theme.of',
      'CupertinoTheme',
      'MaterialApp',
      'CupertinoApp',
      'showCupertinoDialog',
      'showCupertinoModalPopup',
    ];

    return platformPatterns.any((pattern) => line.contains(pattern));
  }

  /// Enhanced method to check if a string should be localized
  bool shouldLocalizeString(
    String content,
    List<String> contextLines,
    String filePath,
    int lineNumber,
  ) {
    // Skip obviously non-localizable content
    if (_shouldSkipString(content)) {
      if (verbose) {
        print('❌ Skipped non-localizable: "$content" at $filePath:$lineNumber');
      }
      return false;
    }

    // Check if it's in a UI context
    if (!isInUiContext(content, contextLines)) {
      if (verbose) {
        print('❌ Skipped non-UI context: "$content" at $filePath:$lineNumber');
      }
      return false;
    }

    if (verbose) {
      print('✅ Should localize: "$content" at $filePath:$lineNumber');
    }

    return true;
  }

  bool _shouldSkipString(String content) {
    // Enhanced skip patterns
    final skipPatterns = [
      // Technical identifiers
      RegExp(r'^[a-zA-Z0-9_]+$'), // Simple identifiers
      RegExp(r'^https?://'), // URLs
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'), // Email
      RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ), // UUIDs
      RegExp(r'^[/#]'), // Paths starting with / or #
      RegExp(r'^(true|false|null)$'), // Boolean and null literals
      // File extensions and technical strings
      RegExp(
        r'\.(png|jpg|jpeg|gif|svg|pdf|mp4|avi|mov|json|xml|yaml|yml)$',
        caseSensitive: false,
      ),

      // API and database related
      RegExp(r'^(GET|POST|PUT|DELETE|PATCH|HEAD|OPTIONS)$'),
      RegExp(r'^application/.*'),
      RegExp(r'^text/.*'),

      // Color codes and CSS-like values
      RegExp(r'^#[0-9a-fA-F]{3,8}$'),
      RegExp(r'^\d+px$'),
      RegExp(r'^\d+%$'),

      // Single characters that are not typically localized
      RegExp(r'^.$'), // Single character
      // Common non-localizable words
      RegExp(
        r'^(ok|yes|no|on|off|up|down|left|right|top|bottom|start|end|home|back|next|prev|previous)$',
        caseSensitive: false,
      ),
    ];

    return skipPatterns.any((pattern) => pattern.hasMatch(content)) ||
        content.trim().isEmpty ||
        content.length < 2;
  }
}
