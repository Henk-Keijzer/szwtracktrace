import 'dart:convert';
import 'package:http/http.dart' as http;

class LocalizationService {
  LocalizationService({required this.server});

  /// The server URL to fetch localization JSON files from.
  final String server;

  Map<String, dynamic> _translations = {};

  // Fetches the localization JSON from the server and loads it into memory.
  Future<void> load(String languageCode) async {
    final response = await http.get(Uri.parse('${server}config/lang_$languageCode.json'));
    if (response.statusCode == 200) {
      _translations = jsonDecode(response.body);
    }
  }

  // 4 routines to get translated texts: 1 string, 2 string with parameters, 3 pluralized string, 4 string based on a selection
  //
  // --- Get a simple string ---
  /// Gets a simple translated string for a given key.
  /// Example: getString('appTitle') -> "SZW Track & Trace"
  String str(String key) {
    return _translations[key] as String? ?? key; // Return the key itself if not found
  }

  // --- Get a string with parameters ---
  /// Gets a translated string and replaces placeholders with provided values.
  /// Example: getStringWithParams('helloUser', {'userName': 'John'}) -> "Hello, John"
  /// (Assuming JSON is: "helloUser": "Hello, {userName}")
  String param(String key, Map<String, String> params) {
    String template = _translations[key] as String? ?? key;
    params.forEach((paramKey, paramValue) {
      template = template.replaceAll('{$paramKey}', paramValue);
    });
    return template;
  }

  // --- Get a pluralized string (Corrected for Localizely format) ---
  /// Gets a pluralized string based on a count, using the Localizely key format.
  /// Example: getPlural('baseMaps', 0) -> "Basiskaarten"
  /// Example: getPlural('baseMaps', 1) -> "Basiskaart"
  /// Example: getPlural('baseMaps', 5) -> "Basiskaarten"
  String plural(String key, int count) {
    String pluralKey;
    if (count == 0) {
      // First, try to find a specific 'zero' key.
      pluralKey = '$key[plural_zero]';
      if (_translations.containsKey(pluralKey)) {
        return _translations[pluralKey] as String;
      }
      // If 'zero' is not found, fall back to 'other' as requested.
      pluralKey = '$key[plural_other]';
    } else if (count == 1) {
      // Use the 'one' key for a count of 1.
      pluralKey = '$key[plural_one]';
    } else {
      // Use the 'other' key for all other counts (2, 3, 4, ...).
      pluralKey = '$key[plural_other]';
    }

    // Return the translated string for the constructed key, or the base key if not found.
    return _translations[pluralKey] as String? ?? key;
  }

  // --- Get a string based on a selection (Corrected for Localizely format) ---
  /// Gets a translated string based on a selection keyword.
  /// Example: select('configShips', 'schepen') -> "ships"
  String select(String key, String selection) {
    final String template = _translations[key] as String? ?? key;
    // A more robust regex that allows for spaces or no spaces after the comma.
    final RegExp selectRegex = RegExp(r'\{\w+,\s*select,\s*(.*)\}$');
    final Match? match = selectRegex.firstMatch(template);
    if (match == null) {
      return template; // Not a select format string, return as is.
    }
    // This captures the content: "schepen{ships} boten{boats} other{ships}"
    final String content = match.group(1)!;
    // Use a simpler regex to find all keyword-value pairs like "schepen{ships}".
    // It looks for a word (keyword), followed by an opening brace '{',
    // captures the content inside the braces (value), and ends with a closing brace '}'.
    final RegExp caseRegex = RegExp(r'(\w+)\s*\{(.*?)\}');
    final Iterable<Match> caseMatches = caseRegex.allMatches(content);
    String? otherValue;
    String? exactMatchValue;
    for (final caseMatch in caseMatches) {
      final String keyword = caseMatch.group(1)!; // e.g., "schepen", "boten", "other"
      final String value = caseMatch.group(2)!; // e.g., "ships", "boats", "ships"
      if (keyword == 'other') {
        otherValue = value;
      } else if (keyword == selection) {
        exactMatchValue = value;
        break; // Found the exact selection, no need to look further.
      }
    }
    // Return the exact match if found, otherwise the 'other' value,
    // or the original key as a final fallback if something went wrong.
    return exactMatchValue ?? otherValue ?? key;
  }
}
