// Shadow Architect - portable C++17 game core (no platform APIs)
#pragma once
#include <string>
#include <vector>

namespace sa {

using Text = std::u16string;

inline Text U(const char* s) {
    Text out;
    while (*s) {
        unsigned char c = (unsigned char)*s;
        unsigned int cp = 0; int n = 1;
        if (c < 0x80) { cp = c; }
        else if ((c & 0xE0) == 0xC0) { cp = c & 0x1F; n = 2; }
        else if ((c & 0xF0) == 0xE0) { cp = c & 0x0F; n = 3; }
        else if ((c & 0xF8) == 0xF0) { cp = c & 0x07; n = 4; }
        else { cp = 0xFFFD; }
        for (int i = 1; i < n; ++i) {
            unsigned char d = (unsigned char)*(s + i);
            if (!d || (d & 0xC0) != 0x80) { cp = 0xFFFD; break; }
            cp = (cp << 6) | (d & 0x3F);
        }
        s += n;
        if (cp > 0xFFFF) {
            cp -= 0x10000;
            out.push_back((char16_t)(0xD800 + (cp >> 10)));
            out.push_back((char16_t)(0xDC00 + (cp & 0x3FF)));
        } else {
            out.push_back((char16_t)cp);
        }
    }
    return out;
}

struct Vec2 { int x = 0, y = 0; };
struct Lamp { Vec2 p; int dir = 0; };
struct Mirror { Vec2 p; bool slash = true; };
struct Gear { Vec2 p; int period = 4, phase = 0; };

struct Level {
    int id = 0;
    Text nameAr, nameEn, hookAr, hookEn, ahaAr, ahaEn, hintAr, hintEn, speechAr, speechEn;
    std::vector<Text> grid;
    std::vector<Lamp> lamps;
    std::vector<Mirror> mirrors;
    std::vector<Gear> gears;
    bool goalRequiresLight = false;
    int par = 1;
};

enum class Screen { Menu, LevelSelect, Settings, HowTo, Credits, Playing, Paused, Win };

struct Settings {
    int music = 2;
    int sfx = 2;
    int lang = 0;                 // 0 = Arabic, 1 = English
    int unlocked = 1;
    int sparks[6] = {0, 0, 0, 0, 0, 0};
};

struct Snapshot {
    std::vector<Lamp> lamps;
    std::vector<Mirror> mirrors;
    std::vector<Gear> gears;
    int moves = 0;
};

class GameCore {
public:
    GameCore();

    static std::vector<Level> makeLevels();
    const std::vector<Level>& levels() const { return levels_; }
    const Level& level() const { return levels_[levelIndex]; }

    bool arabic() const { return settings.lang == 0; }
    Text loc(const Text& a, const Text& e) const { return arabic() ? a : e; }

    void initLevel(int index);
    void step(unsigned long nowMs);
    bool act(int x, int y);
    void undo();
    void togglePlay();
    void finishDeath();
    void say(const Text& text, unsigned long nowMs, unsigned long durationMs);

    std::vector<std::vector<bool> > light();

    Settings settings;
    Screen screen = Screen::Menu;
    Screen returnScreen = Screen::Menu;
    int levelIndex = 0;

    std::vector<Text> grid;
    std::vector<Lamp> lamps;
    std::vector<Mirror> mirrors;
    std::vector<Gear> gears;
    Vec2 duja{1, 1}, start{1, 1};
    int dir = 0, tick = 0, moves = 0;
    bool running = false, dead = false, won = false;
    unsigned long deadUntil = 0;
    unsigned long bubbleUntil = 0;
    Text bubble;
    int earnedSparks = 0;
    std::vector<Snapshot> history;

private:
    std::vector<Level> levels_;
    bool inB(int x, int y) const;
    char cell(int x, int y) const;
    Lamp* lampAt(int x, int y);
    Mirror* mirrorAt(int x, int y);
    Gear* gearAt(int x, int y);
    bool gearClosed(const Gear& g) const;
    bool canEnter(int x, int y, const std::vector<std::vector<bool> >& lit);
    bool shadowTile(int x, int y, const std::vector<std::vector<bool> >& lit);
    static int reflectDir(int d, bool slash);
    void snapshot();
    void winLevel();
    void die(unsigned long nowMs);
};

} // namespace sa
