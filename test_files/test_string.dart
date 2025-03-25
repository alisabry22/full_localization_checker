// Test file with various string literals

void main() {
  // Simple string literals
  var simple1 = 'This is a simple string';
  var simple2 = "This is another simple string";
  
  // String interpolation
  var name = 'World';
  var interpolated1 = 'Hello $name';
  var interpolated2 = "The value is ${2 + 2}";
  
  // Adjacent strings
  var adjacent = 'This ' 'is ' 'an ' 'adjacent ' 'string';
  
  // Multi-line strings
  var multiLine = '''
  This is a
  multi-line string
  ''';
  
  // UI-related strings that should be localized
  showDialog(
    title: 'Alert Title',
    content: "This is a message that should be localized",
  );
  
  // Function that returns Text widget
   Text('This should be detected as UI text');
}

// Mock function to simulate UI components
void showDialog({required String title, required String content}) {
  print('Dialog: $title - $content');
}

class Text {
  final String data;
  Text(this.data);
}