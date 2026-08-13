/// Removes JSONC syntax while keeping character offsets stable for AST patches.
class JsoncCleaner {
  /// Replaces comments and trailing commas without changing string length.
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
