import 'dart:convert';
import 'package:http/http.dart' as http;

Future<List<dynamic>> fetchProductCategories() async {
  final response = await http.get(Uri.parse('https://ibots.in/wp-json/wp/v2/product_cat'));

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to load product categories');
  }
}

