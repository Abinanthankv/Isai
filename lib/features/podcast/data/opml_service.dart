import 'package:xml/xml.dart';
import '../../../core/database/database.dart';

class OpmlFeedItem {
  final String title;
  final String xmlUrl;
  final String? htmlUrl;

  OpmlFeedItem({
    required this.title,
    required this.xmlUrl,
    this.htmlUrl,
  });
}

class OpmlService {
  /// Parse OPML XML content and extract all podcast RSS feed URLs.
  static List<OpmlFeedItem> parseOpml(String xmlString) {
    final items = <OpmlFeedItem>[];
    try {
      final document = XmlDocument.parse(xmlString);
      final outlines = document.findAllElements('outline');

      for (final node in outlines) {
        final xmlUrl = node.getAttribute('xmlUrl') ?? node.getAttribute('url');
        if (xmlUrl != null && xmlUrl.isNotEmpty) {
          final title = node.getAttribute('text') ??
              node.getAttribute('title') ??
              'Untitled Podcast';
          final htmlUrl = node.getAttribute('htmlUrl');

          items.add(OpmlFeedItem(
            title: title.trim(),
            xmlUrl: xmlUrl.trim(),
            htmlUrl: htmlUrl?.trim(),
          ));
        }
      }
    } catch (e) {
      print('[OpmlService] Parse error: $e');
    }
    return items;
  }

  /// Export a list of podcast subscriptions to OPML XML format.
  static String exportOpml(List<DbPodcastSubscription> subscriptions) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('opml', attributes: {'version': '2.0'}, nest: () {
      builder.element('head', nest: () {
        builder.element('title', nest: 'Isai Podcast Subscriptions');
        builder.element('dateCreated', nest: DateTime.now().toUtc().toIso8601String());
      });
      builder.element('body', nest: () {
        builder.element('outline', attributes: {'text': 'Podcasts', 'title': 'Podcasts'}, nest: () {
          for (final sub in subscriptions) {
            builder.element('outline', attributes: {
              'type': 'rss',
              'text': sub.title,
              'title': sub.title,
              'xmlUrl': sub.feedUrl,
            });
          }
        });
      });
    });

    final document = builder.buildDocument();
    return document.toXmlString(pretty: true, indent: '  ');
  }
}
