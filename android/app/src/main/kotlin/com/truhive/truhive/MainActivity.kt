package com.truhive.truhive

import com.ryanheise.audioservice.AudioServiceActivity

// AudioServiceActivity keeps the Flutter engine shared with the background
// playback service, so music continues when the app is closed.
class MainActivity : AudioServiceActivity()
