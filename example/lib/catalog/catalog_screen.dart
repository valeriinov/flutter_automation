import 'package:flutter/material.dart';
import 'package:flutter_automation/flutter_automation.dart';

import 'package:example/automation/example_target.dart';
import 'package:example/catalog/catalog_api.dart';

/// Second screen: the items the catalog answers with.
class CatalogScreen extends StatefulWidget {
  static const routeName = 'catalog';

  final CatalogApi catalogApi;

  const CatalogScreen({super.key, required this.catalogApi});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late final Future<List<String>> _titles = widget.catalogApi.getItemTitles();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catalog')),
      body: FutureBuilder<List<String>>(
        future: _titles,
        builder: (context, snapshot) {
          final titles = snapshot.data;

          if (snapshot.hasError) {
            return const Center(child: Text('Could not load the catalog'));
          }

          if (titles == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (titles.isEmpty) {
            return Center(
              child: const Text(
                'The catalog is empty',
              ).automationTarget(ExampleTarget.catalogEmpty),
            );
          }

          return ListView(
            children: [
              for (final title in titles) ListTile(title: Text(title)),
            ],
          ).automationTarget(ExampleTarget.catalogList);
        },
      ),
    ).automationTarget(ExampleTarget.catalogScreen);
  }
}
