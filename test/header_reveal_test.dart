import 'package:flutter_test/flutter_test.dart';
import 'package:nofeed/header_reveal.dart';

void main() {
  late HeaderReveal reveal;
  setUp(() => reveal = HeaderReveal());

  HeaderFrame scroll(double from, double to, {double step = 2}) {
    var frame = reveal.frame;
    final dir = to > from ? 1 : -1;
    for (var y = from; dir > 0 ? y <= to : y >= to; y += dir * step) {
      frame = reveal.update(y);
    }
    return frame;
  }

  test('starts at the top: header shown, no backdrop', () {
    expect(reveal.frame, const HeaderFrame(1, 0, floating: false));
    expect(reveal.frame.state, HeaderState.top);
  });

  test('near the top the header fades with the offset, backdrop stays full', () {
    final frame = scroll(0, 36); // half of the 72 pt fade zone
    expect(frame.text, closeTo(0.5, 0.05));
    expect(frame.backdrop, 1);
    expect(frame.state, HeaderState.shown);
  });

  test('past the fade zone the header is gone and the backdrop shrinks', () {
    final frame = scroll(0, 92);
    expect(frame.text, 0);
    expect(frame.state, HeaderState.hidden);
    expect(frame.backdrop, closeTo(0.5, 0.05));
    expect(scroll(92, 400).backdrop, 0);
  });

  test('further down it comes back gradually, following the finger', () {
    scroll(0, 600);
    final quarter = scroll(600, 584);
    expect(quarter.text, closeTo(0.25, 0.05));
    expect(quarter.backdrop, closeTo(0.25, 0.05));
    expect(scroll(584, 536).text, 1);
  });

  test('settles fully shown or hidden when scrolling stops', () {
    scroll(0, 600);
    scroll(600, 560); // ~0.6 shown
    expect(reveal.settle(), const HeaderFrame(1, 1, floating: true));
    scroll(560, 600); // ~0.4 shown
    expect(reveal.settle().state, HeaderState.hidden);
  });

  test('a revealed header stays visible when scrolling back to the top', () {
    scroll(0, 600);
    scroll(600, 500);
    expect(scroll(500, 10).text, 1);
  });

  test('back at the top (also rubber-band above it)', () {
    scroll(0, 600);
    expect(reveal.update(-20), const HeaderFrame(1, 0, floating: false));
  });

  test('reset goes back to the top state', () {
    scroll(0, 600);
    reveal.reset();
    expect(reveal.frame.state, HeaderState.top);
  });
}
