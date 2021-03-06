import 'dart:convert';
import 'dart:io';

import 'package:html/dom.dart';
import 'package:html/parser.dart' show parse;

import 'Http.dart';

class ParseHtml {
  //
  static Future<String> content(String url) async {
    var c = "";
    var html = await HttpUtil().http().get(url);

    Element content;
    if (url.contains("qvyue")) {
      content = parse(html.data).getElementById("BookText");
    } else if (url.contains("iqb5")) {
      content = parse(html.data, encoding: "gbk").getElementById("contents");
    } else {
      content = parse(html.data).getElementById("content");
    }
    content.nodes.forEach((element) {
      var text = element.text.trim();
      if (text.isNotEmpty) {
        c += "\t\t\t\t\t\t\t\t" + text + "\n";
      }
    });
    return c;
  }

  static Future getHTML(String url) async {
    var dataList;
    try {
      var client = new HttpClient();
      var request = await client.getUrl(Uri.parse(url));
      var response = await request.close();
      var responseBody = await response.transform(utf8.decoder).join();
      dataList = await parseJson(responseBody);
    } catch (e) {}
    return dataList;
  }
}
