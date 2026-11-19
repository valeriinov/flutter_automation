/// {@category Utils}
///
/// Where the page of a bundle reads its screenshots from.
enum AtlasShotSource {
  /// One file per screenshot, `shots/<hash>.png` beside the page.
  files,

  /// WebP sheets inside the page.
  inline,

  /// WebP sheets written as files `shots/<sheet hash>.webp` beside the page,
  /// named by the hash of the sheet bytes; the page crops each shot from its
  /// sheet on a canvas as with [inline], so the page and `shots/` stand on
  /// one http(s) origin.
  sheets,

  /// The links an `AtlasShotPublisher` returns, one per screenshot hash.
  urls;

  /// The source named [name], or `null` when no source has that name.
  static AtlasShotSource? tryRead(String name) {
    return values.asNameMap()[name];
  }
}
