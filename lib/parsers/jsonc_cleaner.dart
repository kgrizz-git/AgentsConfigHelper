class JsoncCleaner {
  /// Neutralizes comments and trailing commas in a JSONC string by replacing them
  /// with spaces. This preserves exact string offsets so AST nodes map 1:1 back
  /// to the original string.
  static String clean(String input) {
    final out = input.split('');
    var inString = false;
    var escape = false;

    for (var i = 0; i < input.length; i++) {
      if (inString) {
        if (escape) {
          escape = false;
          continue;
        }
        if (input[i] == r'\') {
          escape = true;
          continue;
        }
        if (input[i] == '"') {
          inString = false;
          continue;
        }
      } else {
        if (input[i] == '"') {
          inString = true;
          continue;
        }
        // line comment
        if (i + 1 < input.length && input[i] == '/' && input[i + 1] == '/') {
          while (i < input.length && input[i] != '\n') {
            out[i++] = ' ';
          }
          if (i < input.length) out[i] = '\n';
          continue;
        }
        // block comment
        if (i + 1 < input.length && input[i] == '/' && input[i + 1] == '*') {
          out[i++] = ' ';
          out[i++] = ' ';
          while (i + 1 < input.length &&
              !(input[i] == '*' && input[i + 1] == '/')) {
            if (input[i] != '\n') out[i] = ' ';
            i++;
          }
          if (i + 1 < input.length) {
            out[i++] = ' ';
            out[i] = ' ';
          }
          continue;
        }
      }
    }

    // Remove trailing commas outside strings
    inString = false;
    escape = false;
    for (var i = 0; i < out.length; i++) {
      if (inString) {
        if (escape) {
          escape = false;
          continue;
        }
        if (out[i] == r'\') {
          escape = true;
          continue;
        }
        if (out[i] == '"') {
          inString = false;
          continue;
        }
      } else {
        if (out[i] == '"') {
          inString = true;
          continue;
        }
        if (out[i] == '}' || out[i] == ']') {
          // Look backwards for a comma before this closing bracket
          var j = i - 1;
          while (j >= 0 &&
              (out[j] == ' ' ||
                  out[j] == '\n' ||
                  out[j] == '\r' ||
                  out[j] == '\t')) {
            j--;
          }
          if (j >= 0 && out[j] == ',') {
            out[j] = ' '; // neutralize the trailing comma
          }
        }
      }
    }

    return out.join();
  }
}
