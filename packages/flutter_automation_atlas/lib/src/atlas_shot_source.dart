/// {@category Utils}
///
/// Where the page of a bundle reads its screenshots from.
enum AtlasShotSource {
  /// One file per screenshot, `shots/<hash>.png` beside the page.
  files,

  /// WebP sheets inside the page.
  inline,

  /// The links an `AtlasShotPublisher` returns, one per screenshot hash.
  urls;

  /// The source named [name], or `null` when no source has that name.
  static AtlasShotSource? tryRead(String name) {
    return values.asNameMap()[name];
  }
}
