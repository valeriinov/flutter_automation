import 'dart:convert';

import 'package:flutter_automation_atlas/src/atlas_shot_encoder.dart';

final class HashShotEncoder implements AtlasShotEncoder {
  const HashShotEncoder();

  @override
  AtlasShotSheet encodeSheet(List<String> shots) {
    return AtlasShotSheet(
      bytes: utf8.encode(shots.join(',')),
      cells: {
        for (final (index, shot) in shots.indexed)
          shot: AtlasShotCell(left: index, top: 0, width: 1, height: 1),
      },
    );
  }
}
