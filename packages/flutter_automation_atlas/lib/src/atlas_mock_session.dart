/// {@category Utils}
///
/// Builds the [AtlasMockSession] of one replay run from its [context].
///
/// The replay calls it inside a `FakeAsync` zone, so the session starts each
/// timer on fake time. It cannot wait for real I/O. The caller builds the
/// mock that a session needs before the replay starts.
///
/// After the factory returns, the replay runs the pending microtasks. A setup
/// that sets state before its first `await` takes effect before the first
/// [AtlasMockSession.ask].
typedef AtlasMockSessionFactory =
    AtlasMockSession Function(AtlasMockSessionContext context);

/// {@category Utils}
///
/// What a replay run holds about the snapshot it replays and the time it runs
/// on.
final class AtlasMockSessionContext {
  /// The scenario of the variant, as JSON.
  final Map<String, Object?> scenario;

  /// The locale of the capture that made the snapshot.
  final String locale;

  /// The answer records of the snapshot, oldest first.
  final List<Map<String, Object?>> recordedAnswers;

  /// The anchor the mock seeds its dates on.
  final DateTime anchor;

  /// The moment the app launched at, `null` when the snapshot holds none.
  final DateTime? launchedAt;

  /// Whether a timer that the mock started fires only after the requests
  /// behind it have waited. If `false`, it fires right after the request that
  /// started it.
  final bool isLazy;

  const AtlasMockSessionContext({
    required this.scenario,
    required this.locale,
    required this.recordedAnswers,
    required this.anchor,
    required this.launchedAt,
    required this.isLazy,
  });
}

/// {@category Utils}
///
/// The mock of a project, as a replay asks it again. It takes one recorded
/// answer at a time. It hands back the records that the mock wrote while it
/// answered.
///
/// The replay asks the answers in the order the snapshot recorded them. After
/// each [ask] it lets the mock run, calls [takeJournal], and compares the
/// record [findReplayed] picks with the recorded one.
abstract class AtlasMockSession {
  /// Asks the mock the question the answer [record] recorded.
  ///
  /// An error that [ask] throws, synchronously or in the returned future,
  /// counts as a failed answer.
  Future<Object?> ask(Map<String, Object?> record);

  /// The records the mock wrote since the last call, oldest first. The mock
  /// starts its journal anew.
  List<Map<String, Object?>> takeJournal();

  /// Picks the record of [journal] that answers [record].
  ///
  /// [journal] is what [takeJournal] returned after [ask] of [record]. The
  /// method returns `null` when the mock answered nothing.
  Map<String, Object?>? findReplayed(
    Map<String, Object?> record,
    List<Map<String, Object?>> journal,
  );

  /// What [record] asks, for the `stale` line.
  String describe(Map<String, Object?> record);

  /// Stops the mock and removes what the session made.
  ///
  /// The replay lets the microtasks of the returned future run, but not its
  /// timers.
  Future<void> close();

  /// The answers the mock gives without a record of them in the snapshot,
  /// replayed before every recorded answer, in the first stage.
  ///
  /// The package cleans these records as it cleans the journal.
  List<Map<String, Object?>> impliedAnswers() => const [];

  /// Whether [record] is a value the mock pushed to the app, which reaches it
  /// whenever the mock emits, rather than the answer to [ask].
  ///
  /// On a lazy timing, the replay lets each pending timer fire before it
  /// asks such a record.
  bool isPushedValue(Map<String, Object?> record) => false;
}
