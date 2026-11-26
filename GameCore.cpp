// Shadow Architect - portable C++17 game core implementation
#include "GameCore.hpp"
#include <algorithm>

namespace sa {

static const int DX[4] = {1, 0, -1, 0};
static const int DY[4] = {0, 1, 0, -1};

GameCore::GameCore() : levels_(makeLevels()) {}

std::vector<Level> GameCore::makeLevels() {
    std::vector<Level> out;
    const std::vector<Text> plain = {
        u"############", u"#S........G#", u"#..........#", u"#..........#",
        u"#..........#", u"#..........#", u"#..........#", u"############"
    };

    {
        Level L;
        L.id = 1;
        L.nameAr = u"أول ظل"; L.nameEn = u"First Shade";
        L.hookAr = u"النور يصنع الفجوة: أدر المصباح ليصبح الظل طريقاً.";
        L.hookEn = u"Light carves the gap: rotate the lamp so shadow becomes a path.";
        L.ahaAr = u"حين تدير المصباح يميناً، ينسحب النور عن الممر فجأة ويصبح الظل أرضاً.";
        L.ahaEn = u"Turn the lamp right and light retreats — shadow becomes ground.";
        L.hintAr = u"المصباح يضيء إلى الأعلى. اضغطه مرة واحدة.";
        L.hintEn = u"The lamp shines upward. Tap it once.";
        L.speechAr = u"الظل هو طريقي... لا تترك النور يبتلعه!";
        L.speechEn = u"Shadow is my road... don't let light swallow it!";
        L.grid = plain;
        L.lamps.push_back({{5, 4}, 3});
        L.par = 1;
        out.push_back(L);
    }
    {
        Level L;
        L.id = 2;
        L.nameAr = u"مرآة الميل"; L.nameEn = u"The Leaning Mirror";
        L.hookAr = u"المرآة لا تعكس دُجى، بل تعكس النور الذي يخاف منه.";
        L.hookEn = u"The mirror doesn't reflect Duja — it reflects the light he fears.";
        L.ahaAr = u"تدير المرآة شعاعاً واحداً، فيسقط الحاجز كله عن الشارع.";
        L.ahaEn = u"One mirror flip drops the whole barrier off the street.";
        L.hintAr = u"المرآة ترسل الشعاع إلى أعلى. بدّل ميلها.";
        L.hintEn = u"The mirror sends the beam upward. Flip its angle.";
        L.speechAr = u"هذه المرآة تلعب بالنور... وأنا ألعب بالظل.";
        L.speechEn = u"This mirror plays with light... and I play with shadow.";
        L.grid = plain;
        L.lamps.push_back({{2, 5}, 0});
        L.mirrors.push_back({{6, 5}, true});
        L.par = 1;
        out.push_back(L);
    }
    {
        Level L;
        L.id = 3;
        L.nameAr = u"المنعطف"; L.nameEn = u"The Turn";
        L.hookAr = u"دُجى لا يختار الاتجاه... الظل هو الذي يختار له.";
        L.hookEn = u"Duja doesn't choose direction... the shadow chooses for him.";
        L.ahaAr = u"دُجى يمشي مستقيماً، ثم ينعطف وحده لأن الظل انحنى قبله.";
        L.ahaEn = u"Duja walks straight, then turns because the shadow bent first.";
        L.hintAr = u"المصباح يقطع الظل عند (1,5). أدره إلى أعلى.";
        L.hintEn = u"The lamp cuts the shadow at (1,5). Turn it upward.";
        L.speechAr = u"لا أخاف المنعطف... أخاف أن ينتهي الظل.";
        L.speechEn = u"I don't fear the turn... I fear the shadow ending.";
        L.grid = {
            u"############", u"#S.........#", u"##########.#", u"#..........#",
            u"#.##########", u"#..........#", u"#.........G#", u"############"
        };
        L.lamps.push_back({{5, 5}, 2});
        L.par = 1;
        out.push_back(L);
    }
    {
        Level L;
        L.id = 4;
        L.nameAr = u"الترس النابض"; L.nameEn = u"The Breathing Gear";
        L.hookAr = u"البوابة تتنفس مع الوقت... اضغط الترس في اللحظة المناسبة.";
        L.hookEn = u"The gate breathes with time... nudge the gear at the right moment.";
        L.ahaAr = u"لم تتحرك الجدران... تحرّك الزمن نفسه بمفتاح واحد.";
        L.ahaEn = u"No wall moved... you moved time itself with a single key.";
        L.hintAr = u"الترس مغلق عند وصول دُجى. غيّر نبضه بضغطة واحدة.";
        L.hintEn = u"The gear is closed when Duja arrives. Shift its beat by one tap.";
        L.speechAr = u"الترس يتنفس... سأعدّ معه.";
        L.speechEn = u"The gear is breathing... I'll count with it.";
        L.grid = plain;
        L.gears.push_back({{6, 1}, 4, 3});
        L.par = 1;
        out.push_back(L);
    }
    {
        Level L;
        L.id = 5;
        L.nameAr = u"نوران وميل"; L.nameEn = u"Two Lights, One Tilt";
        L.hookAr = u"مصباحان يغلقان الطريق، ومرآة واحدة تفتحه.";
        L.hookEn = u"Two lamps seal the road; a single mirror unseals it.";
        L.ahaAr = u"المصباح الثاني لا يضيء الطريق، بل يضيء المرآة التي تُضيء الطريق.";
        L.ahaEn = u"The second lamp lights the mirror that lights the road.";
        L.hintAr = u"أدر المصباح العلوي، ثم بدّل ميل المرآة.";
        L.hintEn = u"Rotate the upper lamp, then flip the mirror.";
        L.speechAr = u"نوران... وظل واحد فقط يكفي لي.";
        L.speechEn = u"Two lights... but only one shadow is enough for me.";
        L.grid = plain;
        L.lamps.push_back({{5, 4}, 3});
        L.lamps.push_back({{2, 5}, 0});
        L.mirrors.push_back({{8, 5}, true});
        L.par = 2;
        out.push_back(L);
    }
    {
        Level L;
        L.id = 6;
        L.nameAr = u"تواءة البندول"; L.nameEn = u"The Pendulum's Twist";
        L.hookAr = u"النور الذي يقتل الظل هو نفسه مفتاح بوابة القلب.";
        L.hookEn = u"The light that kills the shadow is the very key to the Heart Gate.";
        L.ahaAr = u"دورة واحدة تُطهّر الممر، والثانية ترسل النور عبر مرآتين لتفتح القلب.";
        L.ahaEn = u"One turn clears the corridor; the second sends light through two mirrors.";
        L.hintAr = u"البوابة مغلقة. أدر المصباح مرتين واتبع الشعاع.";
        L.hintEn = u"The gate is locked. Rotate the lamp twice and follow the beam.";
        L.speechAr = u"كنت أظن النور عدوي... حتى صار مفتاحي.";
        L.speechEn = u"I thought light was my enemy... until it became my key.";
        L.grid = plain;
        L.lamps.push_back({{5, 4}, 3});
        L.mirrors.push_back({{5, 6}, false});
        L.mirrors.push_back({{10, 6}, true});
        L.goalRequiresLight = true;
        L.par = 2;
        out.push_back(L);
    }
    return out;
}

bool GameCore::inB(int x, int y) const { return x >= 0 && y >= 0 && x < 12 && y < 8; }

char GameCore::cell(int x, int y) const {
    if (!inB(x, y)) return '#';
    return (char)grid[y][x];
}

Lamp* GameCore::lampAt(int x, int y) {
    for (auto& o : lamps) if (o.p.x == x && o.p.y == y) return &o;
    return nullptr;
}
Mirror* GameCore::mirrorAt(int x, int y) {
    for (auto& o : mirrors) if (o.p.x == x && o.p.y == y) return &o;
    return nullptr;
}
Gear* GameCore::gearAt(int x, int y) {
    for (auto& o : gears) if (o.p.x == x && o.p.y == y) return &o;
    return nullptr;
}
bool GameCore::gearClosed(const Gear& g) const {
    return ((tick + g.phase) % g.period) >= (g.period / 2);
}
int GameCore::reflectDir(int d, bool slash) {
    if (slash) { if (d == 0) return 3; if (d == 3) return 0; if (d == 1) return 2; return 1; }
    if (d == 0) return 1; if (d == 1) return 0; if (d == 2) return 3; return 2;
}

std::vector<std::vector<bool> > GameCore::light() {
    std::vector<std::vector<bool> > lit(8, std::vector<bool>(12, false));
    for (auto& l : lamps) {
        lit[l.p.y][l.p.x] = true;
        int d = l.dir, x = l.p.x + DX[d], y = l.p.y + DY[d], guard = 0;
        while (guard++ < 240 && inB(x, y)) {
            if (cell(x, y) == '#') break;
            Mirror* m = mirrorAt(x, y);
            if (m) {
                lit[y][x] = true;
                d = reflectDir(d, m->slash);
                x += DX[d]; y += DY[d];
                continue;
            }
            Gear* g = gearAt(x, y);
            if (g && gearClosed(*g)) break;
            lit[y][x] = true;
            x += DX[d]; y += DY[d];
        }
    }
    return lit;
}

bool GameCore::canEnter(int x, int y, const std::vector<std::vector<bool> >& lit) {
    if (!inB(x, y) || cell(x, y) == '#') return false;
    if (lampAt(x, y) || mirrorAt(x, y)) return false;
    Gear* g = gearAt(x, y);
    if (g && gearClosed(*g)) return false;
    if (cell(x, y) == 'G' && level().goalRequiresLight && !lit[y][x]) return false;
    return true;
}
bool GameCore::shadowTile(int x, int y, const std::vector<std::vector<bool> >& lit) {
    if (!canEnter(x, y, lit)) return false;
    if (cell(x, y) == ' ') return false;
    if (cell(x, y) == 'G') return true;
    return !lit[y][x];
}

void GameCore::say(const Text& text, unsigned long nowMs, unsigned long durationMs) {
    bubble = text;
    bubbleUntil = nowMs + durationMs;
}

void GameCore::initLevel(int index) {
    running = false;
    levelIndex = std::max(0, std::min((int)levels_.size() - 1, index));
    const Level& L = level();
    grid = L.grid; lamps = L.lamps; mirrors = L.mirrors; gears = L.gears;
    duja = {1, 1}; start = {1, 1};
    for (int y = 0; y < 8; ++y)
        for (int x = 0; x < 12; ++x)
            if (grid[y][x] == u'S') { duja = {x, y}; start = {x, y}; }
    dir = 0; tick = 0; moves = 0;
    dead = false; won = false; deadUntil = 0; earnedSparks = 0;
    bubble.clear(); bubbleUntil = 0;
    history.clear();
    screen = Screen::Playing;
}

void GameCore::snapshot() {
    Snapshot s;
    s.lamps = lamps; s.mirrors = mirrors; s.gears = gears; s.moves = moves;
    history.push_back(s);
    if (history.size() > 60) history.erase(history.begin());
}

bool GameCore::act(int x, int y) {
    if (dead || won) return false;
    Lamp* l = lampAt(x, y);
    Mirror* m = mirrorAt(x, y);
    Gear* g = gearAt(x, y);
    if (!l && !m && !g) return false;
    snapshot();
    if (l) l->dir = (l->dir + 1) % 4;
    if (m) m->slash = !m->slash;
    if (g) g->phase = (g->phase + 1) % g->period;
    moves++;
    return true;
}

void GameCore::undo() {
    if (history.empty() || dead || won) return;
    Snapshot s = history.back();
    history.pop_back();
    lamps = s.lamps; mirrors = s.mirrors; gears = s.gears; moves = s.moves;
}

void GameCore::togglePlay() {
    if (dead || won) return;
    running = !running;
}

void GameCore::winLevel() {
    won = true; running = false; screen = Screen::Win;
    int par = level().par;
    earnedSparks = (moves <= par) ? 3 : (moves <= par + 2 ? 2 : 1);
    if (earnedSparks > settings.sparks[levelIndex]) settings.sparks[levelIndex] = earnedSparks;
    if (levelIndex + 1 >= settings.unlocked && levelIndex + 1 < 6) settings.unlocked = levelIndex + 2;
}

void GameCore::die(unsigned long nowMs) {
    dead = true; running = false; deadUntil = nowMs + 1400;
    bubble = loc(u"آه! خرجت عن الظل...", u"Ouch! I stepped off the shadow...");
    bubbleUntil = deadUntil;
}

void GameCore::finishDeath() {
    if (!dead) return;
    duja = start; tick = 0; dead = false; bubble.clear(); bubbleUntil = 0;
}

void GameCore::step(unsigned long nowMs) {
    if (dead || won || !running) return;
    std::vector<std::vector<bool> > lit = light();
    int nx = duja.x + DX[dir], ny = duja.y + DY[dir];
    bool moved = false;
    if (shadowTile(nx, ny, lit)) {
        duja.x = nx; duja.y = ny; moved = true;
    } else {
        int ld = (dir + 3) % 4, rd = (dir + 1) % 4;
        bool lo = shadowTile(duja.x + DX[ld], duja.y + DY[ld], lit);
        bool ro = shadowTile(duja.x + DX[rd], duja.y + DY[rd], lit);
        if (lo && !ro) { dir = ld; duja.x += DX[ld]; duja.y += DY[ld]; moved = true; }
        else if (ro && !lo) { dir = rd; duja.x += DX[rd]; duja.y += DY[rd]; moved = true; }
        else {
            Gear* g = gearAt(nx, ny);
            bool blocked = !inB(nx, ny) || cell(nx, ny) == '#' ||
                           lampAt(nx, ny) || mirrorAt(nx, ny) || (g && gearClosed(*g));
            if (blocked) {
                dir = (dir + 2) % 4;
                bubble = loc(u"جدار! أرجع أدر.", u"A wall! Let me turn back.");
                bubbleUntil = nowMs + 1100;
            } else { die(nowMs); return; }
        }
    }
    tick++;
    if (moved && cell(duja.x, duja.y) == 'G') winLevel();
}

} // namespace sa
