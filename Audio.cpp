#include "Audio.hpp"
#include <cmath>
#include <cstdint>
#include <algorithm>

namespace sa {

static void write16(std::vector<unsigned char>& v, uint16_t x) {
    v.push_back((unsigned char)(x & 255));
    v.push_back((unsigned char)(x >> 8));
}
static void write32(std::vector<unsigned char>& v, uint32_t x) {
    for (int i = 0; i < 4; ++i) v.push_back((unsigned char)((x >> (i * 8)) & 255));
}
static std::vector<unsigned char> header(int sampleRate, int samples) {
    std::vector<unsigned char> v;
    uint32_t dataBytes = (uint32_t)samples * 2;
    write32(v, 0x46464952);            // RIFF
    write32(v, 36 + dataBytes);
    write32(v, 0x45564157);            // WAVE
    write32(v, 0x20746d66);            // fmt
    write32(v, 16);
    write16(v, 1);                     // PCM
    write16(v, 1);                     // mono
    write32(v, (uint32_t)sampleRate);
    write32(v, (uint32_t)(sampleRate * 2));
    write16(v, 2);
    write16(v, 16);
    write32(v, 0x61746164);            // data
    write32(v, dataBytes);
    return v;
}

std::vector<unsigned char> makeAmbientWav() {
    const int rate = 22050, secs = 8, samples = rate * secs;
    std::vector<unsigned char> v = header(rate, samples);
    const double f[4] = {130.81, 164.81, 196.00, 246.94};
    for (int i = 0; i < samples; ++i) {
        double t = (double)i / rate;
        double env = std::min(1.0, std::min(t / 1.6, (secs - t) / 1.6));
        double s = 0;
        for (int j = 0; j < 4; ++j)
            s += std::sin(6.283185307179586 * f[j] * t) * (0.11 - j * 0.018);
        s *= env;
        int x = (int)(s * 32767.0);
        if (x > 32767) x = 32767;
        if (x < -32768) x = -32768;
        write16(v, (uint16_t)(x & 0xFFFF));
    }
    return v;
}

std::vector<unsigned char> makeToneWav(int freqHz, int durationMs) {
    const int rate = 22050;
    int samples = (int)((long long)rate * durationMs / 1000);
    std::vector<unsigned char> v = header(rate, samples);
    for (int i = 0; i < samples; ++i) {
        double t = (double)i / rate;
        double env = std::min(1.0, (durationMs / 1000.0 - t) / 0.12);
        if (env < 0) env = 0;
        double s = std::sin(6.283185307179586 * freqHz * t) * 0.22 * env;
        int x = (int)(s * 32767.0);
        write16(v, (uint16_t)(x & 0xFFFF));
    }
    return v;
}

} // namespace sa
