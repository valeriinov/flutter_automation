/// {@category Utils}
///
/// Kind of control an automation target addresses.
///
/// The value is the middle segment of an automation id. From the id alone, an
/// agent can tell what an element accepts: a tap, typed text or a state change.
/// It does not need to read the widget tree.
enum AutomationTargetType {
  /// Element that reacts to a tap and runs one action.
  button,

  /// Element that accepts typed text.
  field,

  /// Element that switches between two states: checkbox, switch, radio.
  toggle,

  /// Element that switches the visible section of a screen.
  tab,

  /// Element that narrows what a list shows and leaves the section unchanged.
  chip,

  /// Row or card that opens a detail screen, or acts on the entity it shows.
  tile,

  /// Root of a screen, present in the native tree while that screen shows.
  ///
  /// A mark on one turns "which screen am I on" into a line of the id dump. An
  /// agent that walks a flow then confirms where it landed without a
  /// screenshot.
  screen,

  /// Root of a surface that covers the screen below: a bottom sheet or a
  /// dialog.
  ///
  /// Its presence in the dump explains a failed tap. A tap on the screen below
  /// finds its widget but has no effect. The modal barrier takes the tap.
  sheet,

  /// Bounded area of a screen. It is present in the native tree in each state
  /// the screen has.
  ///
  /// Its bounds answer a layout question: where the area sits and how tall it
  /// is. They serve an agent that measures the space around the area, not one
  /// that taps it.
  panel,

  /// Line of copy an agent reads or measures rather than acts on.
  ///
  /// A mark on one keeps a flow off the exact text. Copy that carries an
  /// amount, a date or a translation is a finder that breaks the day either
  /// changes. The id stays the address of the line, whatever it says.
  label,
}
