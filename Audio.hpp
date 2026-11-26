// Portable in-memory WAV generation - no audio files, no third-party libs.
#pragma once
#include <vector>

namespace sa {
std::vector<unsigned char> makeAmbientWav();   // 8 seconds, loopable, calm pad
std::vector<unsigned char> makeToneWav(int freqHz, int durationMs);
}
