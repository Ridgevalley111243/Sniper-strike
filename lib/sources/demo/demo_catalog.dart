import '../../audio/synth.dart';

/// One original demo recording. All titles, artists and lyrics are fictional
/// and were written for TRUHive; the audio is synthesized on the device.
class DemoRecording {
  const DemoRecording(this.id, this.title, this.artist, this.album, this.genre, this.year, this.seconds, this.style,
      [this.lyrics]);
  final String id;
  final String title;
  final String artist;
  final String album;
  final String genre;
  final int year;
  final int seconds;
  final SongStyle style;
  final List<String>? lyrics;
}

const _onGod = [
  'Morning light across the river',
  'I keep the quiet in my hands',
  'Every road that I was given',
  'Leads me back to where I stand',
  'Hold it close and never scatter',
  'All the names I used to carry',
  'On God, I am home again',
  'On God, I am home again',
  'Drums are calling from the rooftops',
  'Lanterns swaying in the heat',
  'Mama singing in the doorway',
  'Every heartbeat finds the beat',
  'On God, I am home again',
  'On God, I am home again',
];

const _northernGlass = [
  'Frost is writing on the window',
  'Little rivers made of light',
  'You were humming something golden',
  'In the middle of the night',
  'Northern glass and silver weather',
  'Keep the kettle on for me',
  'I will find you in the morning',
  'Where the cold meets the sea',
];

const _lanternHymn = [
  'Carry the lantern up the hill',
  'Sing while the evening is still',
  'Grace in the hush, grace in the rain',
  'Lift every voice, lift it again',
  'Carry the lantern, carry it high',
  'Over the valley, under the sky',
];

const _brightside = [
  'Wake up, the city is calling',
  'Laces tight and the light is falling',
  'Every mile is a promise kept',
  'Run like you never slept',
  'Brightside, brightside',
  'Keep it moving, keep it alive',
];

const demoRecordings = [
  DemoRecording('r01', 'On God', 'Kaelo Mensah', 'On God — Single', 'Afrobeats', 2024, 222, SongStyle.afrobeats, _onGod),
  DemoRecording('r02', 'On God (Acoustic)', 'Kaelo Mensah', 'Quiet Sessions', 'Afrobeats', 2024, 245, SongStyle.chill),
  DemoRecording('r03', 'God Over Everything', 'Ama Serwaa', 'Morning Psalms', 'Gospel', 2023, 198, SongStyle.gospel),
  DemoRecording('r04', 'Lantern Hymn', 'The Lantern Choir', 'Lantern Hymns', 'Gospel', 2022, 240, SongStyle.gospel, _lanternHymn),
  DemoRecording('r05', 'Northern Glass', 'Lumen Tide', 'Northern Glass', 'Chill', 2024, 235, SongStyle.chill, _northernGlass),
  DemoRecording('r06', 'Undertow', 'Sade Okoro', 'Undertow', 'Chill', 2023, 217, SongStyle.chill),
  DemoRecording('r07', 'Late Bloom', 'Ivory Lane', 'Late Bloom', 'Chill', 2022, 252, SongStyle.ambient),
  DemoRecording('r08', 'Brightside Run', 'Volt Parade', 'Mileage', 'Workout', 2024, 196, SongStyle.workout, _brightside),
  DemoRecording('r09', 'Eighth Mile', 'Volt Parade', 'Mileage', 'Workout', 2024, 208, SongStyle.workout),
  DemoRecording('r10', 'Palm Wine Evenings', 'Kwesi Arthur-Bello', 'Coastline Highlife', 'Highlife', 2021, 230, SongStyle.highlife),
  DemoRecording('r11', 'Accra After Dark', 'Kwesi Arthur-Bello', 'Coastline Highlife', 'Highlife', 2021, 214, SongStyle.highlife),
  DemoRecording('r12', 'Unsayable', 'Hollow Pines', 'Charcoal Tide', 'Ambient', 2020, 172, SongStyle.ambient),
  DemoRecording('r13', 'Salt Photographs', 'Hollow Pines', 'Charcoal Tide', 'Ambient', 2020, 254, SongStyle.ambient),
  DemoRecording('r14', 'To Speak Of Solitude', 'Hollow Pines', 'Charcoal Tide', 'Ambient', 2020, 201, SongStyle.ambient),
  DemoRecording('r15', 'Golden Billows', 'Hollow Pines', 'Charcoal Tide', 'Ambient', 2020, 178, SongStyle.ambient),
  DemoRecording('r16', 'Sunday Gold', 'Ama Serwaa', 'Morning Psalms', 'Gospel', 2023, 226, SongStyle.gospel),
  DemoRecording('r17', 'Lagos Lights', 'Temi Adeyemi', 'Lagos Lights', 'Afrobeats', 2024, 189, SongStyle.afrobeats),
  DemoRecording('r18', 'Bodies In Motion', 'Temi Adeyemi', 'Lagos Lights', 'Afrobeats', 2024, 203, SongStyle.afrobeats),
  DemoRecording('r19', 'Slow Tide Radio', 'Lumen Tide', 'Northern Glass', 'Chill', 2024, 241, SongStyle.chill),
  DemoRecording('r20', 'Higher Ground Interval', 'Volt Parade', 'Mileage', 'Workout', 2024, 187, SongStyle.workout),
];

/// Which recordings each demo source carries (and so which duplicates the
/// search engine has to group).
const demoSourceCatalogs = {
  'openwave': ['r01', 'r02', 'r03', 'r04', 'r05', 'r06', 'r08', 'r10', 'r12', 'r13', 'r14', 'r15', 'r17', 'r19'],
  'commons': ['r01', 'r03', 'r05', 'r07', 'r09', 'r11', 'r12', 'r16', 'r18', 'r20'],
  'arcadia': ['r01', 'r02', 'r04', 'r06', 'r08', 'r13', 'r16', 'r17'],
  'indievault': ['r01', 'r07', 'r10', 'r18'],
};
