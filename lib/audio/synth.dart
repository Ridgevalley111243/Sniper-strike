import 'dart:math' as math;
import 'dart:typed_data';

/// Musical character of a generated demo track.
enum SongStyle { afrobeats, gospel, chill, workout, ambient, highlife }

/// Everything needed to deterministically render one original demo song.
class SongSpec {
  const SongSpec({
    required this.seed,
    required this.style,
    required this.duration,
    required this.bpm,
    required this.rootMidi,
    required this.minor,
    required this.progression,
  });

  final int seed;
  final SongStyle style;
  final Duration duration;
  final double bpm;
  final int rootMidi;
  final bool minor;
  final List<int> progression; // scale degrees (0-based) per bar

  factory SongSpec.fromSeed(int seed, SongStyle style, Duration duration) {
    final r = math.Random(seed);
    final bpm = switch (style) {
      SongStyle.afrobeats => 102 + r.nextInt(10).toDouble(),
      SongStyle.gospel => 72 + r.nextInt(12).toDouble(),
      SongStyle.chill => 80 + r.nextInt(10).toDouble(),
      SongStyle.workout => 122 + r.nextInt(6).toDouble(),
      SongStyle.ambient => 64 + r.nextInt(10).toDouble(),
      SongStyle.highlife => 112 + r.nextInt(10).toDouble(),
    };
    const progressions = [
      [0, 4, 5, 3],
      [0, 5, 3, 4],
      [5, 3, 0, 4],
      [0, 3, 4, 3],
      [0, 2, 5, 4],
    ];
    return SongSpec(
      seed: seed,
      style: style,
      duration: duration,
      bpm: bpm,
      rootMidi: 45 + r.nextInt(8),
      minor: style == SongStyle.chill || style == SongStyle.ambient ? r.nextBool() : r.nextInt(4) == 0,
      progression: progressions[r.nextInt(progressions.length)],
    );
  }
}

/// Renders [SongSpec]s as 16-bit mono PCM. Every sample is a pure function of
/// absolute time, so any segment can be rendered independently (used for
/// 30-second previews and for resuming an interrupted download).
class Synth {
  Synth(this.spec, {this.sampleRate = 22050}) {
    final scale = spec.minor ? const [0, 2, 3, 5, 7, 8, 10] : const [0, 2, 4, 5, 7, 9, 11];
    _chords = [
      for (final degree in spec.progression)
        [for (var k = 0; k < 3; k++) _midiToHz(spec.rootMidi + 12 + _scaleNote(scale, degree + k * 2))]
    ];
    _bass = [for (final degree in spec.progression) _midiToHz(spec.rootMidi + _scaleNote(scale, degree))];
    _beatSec = 60 / spec.bpm;
    _totalSec = spec.duration.inMilliseconds / 1000;
  }

  final SongSpec spec;
  final int sampleRate;
  late final List<List<double>> _chords;
  late final List<double> _bass;
  late final double _beatSec;
  late final double _totalSec;

  int get totalSamples => sampleCountFor(spec.duration, sampleRate);

  static int _scaleNote(List<int> scale, int degree) => scale[degree % 7] + 12 * (degree ~/ 7);
  static double _midiToHz(int m) => 440 * math.pow(2, (m - 69) / 12).toDouble();

  static const _tau = 2 * math.pi;

  // Deterministic white noise in [-1, 1].
  static double _noise(int n) {
    var x = (n * 374761393 + 668265263) & 0x7fffffff;
    x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff;
    return (x / 0x3fffffff) - 1;
  }

  double _sample(int n) {
    final t = n / sampleRate;
    final beat = t / _beatSec;
    final bar = (beat / 4).floor();
    final chord = _chords[bar % _chords.length];
    final bassHz = _bass[bar % _bass.length];
    final inBar = (beat % 4) * _beatSec; // seconds since bar start
    final introBars = spec.style == SongStyle.ambient ? 1 << 20 : 4;
    final drums = bar >= introBars && t < _totalSec - 6;
    final section = (bar ~/ 8) % 2; // alternate textures every 8 bars

    var s = 0.0;

    // Pad: three detuned voices per chord tone with a soft attack at each bar.
    final padEnv = math.min(1.0, inBar / 0.35) * (0.85 + 0.15 * math.sin(_tau * 0.1 * t));
    final organ = spec.style == SongStyle.gospel;
    for (final f in chord) {
      s += 0.05 * padEnv * (math.sin(_tau * f * t) + 0.6 * math.sin(_tau * f * 1.004 * t + 1.3));
      if (organ) s += 0.025 * padEnv * (math.sin(_tau * f * 2 * t) + 0.5 * math.sin(_tau * f * 3 * t));
    }

    // Bass on eighth notes, pluck envelope.
    final ambient = spec.style == SongStyle.ambient;
    final tb = ambient ? inBar : t % (_beatSec / 2);
    final bassEnv = math.exp(-tb * (ambient ? 0.6 : 7));
    s += 0.18 * bassEnv * (math.sin(_tau * bassHz * t) + 0.25 * math.sin(_tau * bassHz * 2 * t));

    if (drums) {
      final tBeat = t % _beatSec;
      final beatIdx = beat.floor() % 4;
      // Kick
      var kickT = -1.0;
      switch (spec.style) {
        case SongStyle.workout:
          kickT = tBeat;
        case SongStyle.afrobeats:
        case SongStyle.highlife:
          // 1, the "and" of 2, and 3 — a light syncopated pattern.
          final pos = beat % 4;
          if (pos < 1) {
            kickT = pos * _beatSec;
          } else if (pos >= 1.5 && pos < 2.5) {
            kickT = (pos - 1.5) * _beatSec;
          } else if (pos >= 2.5 && pos < 3) {
            kickT = (pos - 2.5) * _beatSec;
          } else if (pos >= 3) {
            kickT = -1;
          }
        case SongStyle.chill:
        case SongStyle.gospel:
          if (beatIdx == 0 || beatIdx == 2) kickT = tBeat;
        case SongStyle.ambient:
          break;
      }
      if (kickT >= 0 && kickT < 0.4) {
        final phase = _tau * (45 * kickT + 75 / 30 * (1 - math.exp(-30 * kickT)));
        s += 0.42 * math.exp(-kickT * 9) * math.sin(phase);
      }
      // Snare / clap on 2 and 4
      if ((beatIdx == 1 || beatIdx == 3) && tBeat < 0.25 && spec.style != SongStyle.ambient) {
        s += 0.11 * math.exp(-tBeat * 22) * (_noise(n) * 0.8 + 0.4 * math.sin(_tau * 190 * tBeat));
      }
      // Hats / shakers
      final sixteenth = _beatSec / 4;
      final ts = t % sixteenth;
      final step = (beat * 4).floor() % 16;
      final hatOn = switch (spec.style) {
        SongStyle.afrobeats || SongStyle.highlife => true,
        SongStyle.workout => step.isOdd,
        SongStyle.chill => step % 2 == 0,
        _ => false,
      };
      if (hatOn) {
        final hp = _noise(n) - _noise(n - 1);
        s += (step % 4 == 2 ? 0.05 : 0.028) * math.exp(-ts * 70) * hp;
      }
      // Arpeggio pluck in alternate sections
      if (section == 1 || spec.style == SongStyle.highlife) {
        final idx = (beat * 4).floor() % 6;
        final f = chord[idx % 3] * (idx >= 3 ? 4 : 2);
        s += 0.045 * math.exp(-ts * 14) * math.sin(_tau * f * t);
      }
    }

    // Song-level fades.
    final fadeIn = math.min(1.0, t / 1.5);
    final fadeOut = math.min(1.0, math.max(0.0, (_totalSec - t) / 4));
    s *= fadeIn * fadeOut;
    // Gentle saturation keeps peaks under control.
    return s / (1 + s.abs() * 0.6);
  }

  /// Renders samples [from, from+count) into 16-bit little-endian PCM.
  Uint8List renderPcm(int from, int count) {
    final out = ByteData(count * 2);
    for (var i = 0; i < count; i++) {
      final v = (_sample(from + i) * 32767 * 0.92).round().clamp(-32768, 32767);
      out.setInt16(i * 2, v, Endian.little);
    }
    return out.buffer.asUint8List();
  }
}

/// Standard 44-byte RIFF/WAVE header for 16-bit mono PCM.
Uint8List wavHeader(int sampleCount, int sampleRate) {
  final dataBytes = sampleCount * 2;
  final b = ByteData(44);
  void ascii(int off, String s) {
    for (var i = 0; i < s.length; i++) {
      b.setUint8(off + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  b.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little); // PCM
  b.setUint16(22, 1, Endian.little); // mono
  b.setUint32(24, sampleRate, Endian.little);
  b.setUint32(28, sampleRate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  b.setUint32(40, dataBytes, Endian.little);
  return b.buffer.asUint8List();
}

int sampleCountFor(Duration d, int sampleRate) => (d.inMilliseconds * sampleRate / 1000).round();

int wavSize(Duration d, int sampleRate) => 44 + sampleCountFor(d, sampleRate) * 2;
