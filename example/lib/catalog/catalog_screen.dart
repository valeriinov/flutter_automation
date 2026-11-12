import 'package:flutter/material.dart';
import 'package:flutter_automation/flutter_automation.dart';

import 'package:example/automation/example_target.dart';
import 'package:example/catalog/catalog_api.dart';
import 'package:example/catalog/catalog_item.dart';

/// Second screen: the items the catalog answers with.
class CatalogScreen extends StatefulWidget {
  static const routeName = 'catalog';

  final CatalogApi catalogApi;

  const CatalogScreen({super.key, required this.catalogApi});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late final Future<List<CatalogItem>> _items = widget.catalogApi.getItems();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catalog')),
      body: FutureBuilder<List<CatalogItem>>(
        future: _items,
        builder: (context, snapshot) {
          final items = snapshot.data;

          if (snapshot.hasError) {
            return const Center(child: Text('Could not load the catalog'));
          }

          if (items == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (items.isEmpty) {
            return Center(
              child: const Text(
                'The catalog is empty',
              ).automationTarget(ExampleTarget.catalogEmpty),
            );
          }

          return ListView(
            children: [
              for (final item in items)
                ListTile(
                  title: Text(item.title),
                ).automationTarget(ExampleTarget.catalogItem.withKey(item.id)),
            ],
          ).automationTarget(ExampleTarget.catalogList);
        },
      ),
    ).automationTarget(ExampleTarget.catalogScreen);
  }
}
