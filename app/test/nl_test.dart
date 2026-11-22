import 'package:flutter_test/flutter_test.dart';
import 'package:little_later/data/nl.dart';

final now = DateTime(2026, 11, 21, 18, 20); // Saturday evening

String fmt(NL r) {
  final d = r.date;
  if (d == null) return r.title;
  return '${cleanTitle(r.title)} @${d.month}/${d.day} ${d.hour}:${d.minute.toString().padLeft(2, '0')}${r.repeat.isEmpty ? '' : ' ${r.repeatText}'}';
}

void main() {
  final cases = {
    'call mom 9pm tomorrow': 'Call mom @11/22 21:00',
    'gym 7am every day': 'Gym @11/22 7:00 Every day',
    'pay bill on monday': 'Pay bill @11/23 9:00',
    'meeting in 30 min': 'Meeting @11/21 18:50',
    'water plants weekdays 8am': 'Water plants @11/22 8:00 Mon–Fri',
    'dinner tonight': 'Dinner @11/21 21:00',
    'standup at 10': 'Standup @11/22 10:00',
    'kal 12 baje mujhe doodh lana hai': 'Doodh lana @11/22 12:00',
    'kal dopahar 12 baje mujhe doodh lana hai': 'Doodh lana @11/22 12:00',
    'raat ko 7 baje dawai leni hai': 'Dawai leni @11/21 19:00',
    'shaam ko 4 baje mummy ko call karna hai': 'Mummy ko call karna @11/22 16:00',
    'subah 11 baje meeting': 'Meeting @11/22 11:00',
    'saade 4 baje shaam chai': 'Chai @11/22 16:30',
    'कल 12 बजे मुझे दूध लाना है': 'दूध लाना @11/22 12:00',
    'har roz subah 6 baje yoga': 'Yoga @11/22 6:00 Every day',
    'parso sham 5 baje bank jana hai': 'Bank jana @11/23 17:00',
    'har somvar 10 baje team call': 'Team call @11/23 10:00 Mon',
    'remind me to call mom 9pm tomorrow': 'Call mom @11/22 21:00',
    'कल 12:00 दूध लाना है': 'दूध लाना @11/22 12:00',
    'meeting 7:30 tomorrow': 'Meeting @11/22 19:30',
  };
  cases.forEach((input, want) {
    test(input, () => expect(fmt(parseNL(input, now: now)), want));
  });

  test('two timed things split into reminders', () {
    final s = splitTasks('tomorrow I want to go to the dairy at 7 am and school at 10 pm', now: now)!;
    expect(s.def, 'reminders');
    expect(s.parts.map((p) => p.title).toList(), ['Go to the dairy', 'School']);
    expect(s.parts[1].nl.date!.hour, 22);
    expect(s.listTitle, 'Plan for tomorrow');
  });
  test('hinglish split with aur', () {
    final s = splitTasks('kal subah 7 baje dairy jana hai aur raat ko 9 baje school ka homework', now: now)!;
    expect(s.parts.map((p) => p.title).toList(), ['Dairy jana', 'School ka homework']);
  });
  test('shopping list', () {
    final s = splitTasks('buy milk, eggs and bread', now: now)!;
    expect(s.def, 'list');
    expect(s.listTitle, 'Shopping list');
    expect(s.parts.map((p) => p.title).toList(), ['Milk', 'Eggs', 'Bread']);
  });
  test('messy hindi speech splits into real reminders', () {
    final s = splitTasks('कल 1:00 बजे मुझे यहां जाना है और 3:00 मुझे घर जाना है और शाम के 5:00 बजे', now: now)!;
    expect(s.parts.map((p) => p.title).toList(), ['यहां जाना', 'घर जाना']);
  });
  test('speech heard in pieces is joined without repeats', () {
    expect(mergeSpeech('kal 3 baje', '3 baje doodh lana'), 'kal 3 baje doodh lana');
    expect(mergeSpeech('3:00 बजे', '3:00 बजे दोपहर के'), '3:00 बजे दोपहर के');
    expect(mergeSpeech('call mom', 'call mom'), 'call mom');
    expect(mergeSpeech('gym 7am', 'and dinner 9pm'), 'gym 7am and dinner 9pm');
  });
  test('things that belong together stay together', () {
    expect(splitTasks('salt and pepper', now: now), isNull);
    expect(splitTasks('call mom and dad tonight', now: now), isNull);
  });
}
