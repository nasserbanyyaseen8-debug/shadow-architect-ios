#import "GameView.h"
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#include "GameCore.hpp"
#include "Audio.hpp"
#include <algorithm>
#include <cmath>
#include <vector>

namespace {
struct TapButton {
    CGRect r;
    int tag;
    __unsafe_unretained NSString* label;
    bool primary;
    bool disabled;
};

static NSString* NSFromText(const sa::Text& t) {
    return [[NSString alloc] initWithBytes:t.data()
                                    length:t.size() * sizeof(char16_t)
                                  encoding:NSUTF16LittleEndianStringEncoding];
}

static UIColor* Gold() { return [UIColor colorWithRed:0.96 green:0.78 blue:0.47 alpha:1.0]; }
static UIColor* Cream() { return [UIColor colorWithRed:1.0 green:0.89 blue:0.65 alpha:1.0]; }
static UIColor* Ink() { return [UIColor colorWithRed:0.91 green:0.93 blue:0.98 alpha:1.0]; }
static UIColor* Muted() { return [UIColor colorWithRed:0.60 green:0.65 blue:0.77 alpha:1.0]; }
static UIColor* Panel() { return [UIColor colorWithRed:0.07 green:0.10 blue:0.18 alpha:0.94]; }

static void DrawText(NSString* s, CGRect r, CGFloat size, BOOL bold,
                     UIColor* color, NSTextAlignment align, BOOL rtl = NO) {
    NSMutableParagraphStyle* p = [[NSMutableParagraphStyle alloc] init];
    p.alignment = align;
    p.lineBreakMode = NSLineBreakByWordWrapping;
    p.baseWritingDirection = rtl ? NSWritingDirectionRightToLeft : NSWritingDirectionLeftToRight;
    UIFont* f = bold ? [UIFont boldSystemFontOfSize:size] : [UIFont systemFontOfSize:size];
    NSDictionary* a = @{NSFontAttributeName: f,
                        NSForegroundColorAttributeName: color,
                        NSParagraphStyleAttributeName: p};
    [s drawInRect:r withAttributes:a];
}

static void Rounded(CGRect r, UIColor* fill, UIColor* border, CGFloat radius) {
    UIBezierPath* path = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:radius];
    [fill setFill];
    [path fill];
    if (border) { [border setStroke]; path.lineWidth = 1.5; [path stroke]; }
}

static void Line(CGPoint a, CGPoint b, UIColor* c, CGFloat w) {
    UIBezierPath* p = [UIBezierPath bezierPath];
    [p moveToPoint:a]; [p addLineToPoint:b];
    [c setStroke]; p.lineWidth = w; p.lineCapStyle = kCGLineCapRound;
    [p stroke];
}

static void AddBtn(std::vector<TapButton>& v, CGRect r, int tag,
                   NSString* label, bool primary = false, bool disabled = false) {
    TapButton b; b.r = r; b.tag = tag; b.label = label; b.primary = primary; b.disabled = disabled;
    v.push_back(b);
}
}

@implementation GameView {
    sa::GameCore* _core;
    std::vector<TapButton> _buttons;
    CADisplayLink* _link;
    double _lastStep;
    double _tile, _bx, _by;
    AVAudioPlayer* _musicPlayer;
    AVAudioPlayer* _sfxPlayer;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _core = new sa::GameCore();
        _lastStep = 0; _tile = 40; _bx = 20; _by = 20;
        self.multipleTouchEnabled = NO;
        [self loadSettings];

        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:nil];
        [[AVAudioSession sharedInstance] setActive:YES error:nil];

        std::vector<unsigned char> wav = sa::makeAmbientWav();
        NSData* data = [NSData dataWithBytes:wav.data() length:wav.size()];
        NSError* err = nil;
        _musicPlayer = [[AVAudioPlayer alloc] initWithData:data error:&err];
        _musicPlayer.numberOfLoops = -1;
        _musicPlayer.volume = 0.16f;
        if (!err) [_musicPlayer play];

        _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick)];
        [_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    return self;
}

- (void)dealloc {
    [_link invalidate];
    delete _core;
}

- (double)nowMs { return (double)CACurrentMediaTime() * 1000.0; }

- (void)loadSettings {
    NSUserDefaults* d = [NSUserDefaults standardUserDefaults];
    _core->settings.music = [d objectForKey:@"sa_music"] ? (int)[d integerForKey:@"sa_music"] : 2;
    _core->settings.sfx = [d objectForKey:@"sa_sfx"] ? (int)[d integerForKey:@"sa_sfx"] : 2;
    _core->settings.lang = [d objectForKey:@"sa_lang"] ? (int)[d integerForKey:@"sa_lang"] : 0;
    _core->settings.unlocked = [d objectForKey:@"sa_unlocked"] ? (int)[d integerForKey:@"sa_unlocked"] : 1;
    for (int i = 0; i < 6; ++i)
        _core->settings.sparks[i] = (int)[d integerForKey:[NSString stringWithFormat:@"sa_spark%d", i]];
    _core->settings.music = std::max(0, std::min(3, _core->settings.music));
    _core->settings.sfx = std::max(0, std::min(3, _core->settings.sfx));
    _core->settings.unlocked = std::max(1, std::min(6, _core->settings.unlocked));
}

- (void)saveSettings {
    NSUserDefaults* d = [NSUserDefaults standardUserDefaults];
    [d setInteger:_core->settings.music forKey:@"sa_music"];
    [d setInteger:_core->settings.sfx forKey:@"sa_sfx"];
    [d setInteger:_core->settings.lang forKey:@"sa_lang"];
    [d setInteger:_core->settings.unlocked forKey:@"sa_unlocked"];
    for (int i = 0; i < 6; ++i)
        [d setInteger:_core->settings.sparks[i] forKey:[NSString stringWithFormat:@"sa_spark%d", i]];
    [d synchronize];
}

- (void)playSfx:(int)kind {
    if (_core->settings.sfx == 0) return;
    int freq = 660; int dur = 60;
    if (kind == 1) { freq = 780; dur = 70; }
    if (kind == 2) { freq = 190; dur = 90; }
    if (kind == 3) { freq = 130; dur = 170; }
    if (kind == 4) { freq = 920; dur = 90; }
    std::vector<unsigned char> wav = sa::makeToneWav(freq, dur);
    NSData* data = [NSData dataWithBytes:wav.data() length:wav.size()];
    _sfxPlayer = [[AVAudioPlayer alloc] initWithData:data error:nil];
    _sfxPlayer.volume = 0.16f * (1 + _core->settings.sfx * 0.2f);
    [_sfxPlayer play];
}

- (void)tick {
    double now = [self nowMs];
    if (_core->dead && now >= _core->deadUntil) _core->finishDeath();
    if (_core->running && now - _lastStep >= 480.0) {
        [self _selfCoreStep:now];
    }
    if (!_core->bubble.empty() && now > _core->bubbleUntil) {
        _core->bubble.clear(); _core->bubbleUntil = 0;
    }
    [self setNeedsDisplay];
}

- (void)_selfCoreStep:(double)now {
    bool wasWon = _core->won;
    _core->step(now);
    _lastStep = now;
    if (!wasWon && _core->won) { [self playSfx:4]; [self saveSettings]; }
}

- (void)speak:(const sa::Text&)text seconds:(double)sec {
    _core->say(text, (unsigned long)[self nowMs], (unsigned long)(sec * 1000.0));
}

// ---------------- drawing ----------------
- (void)drawRect:(CGRect)rect {
    CGFloat W = self.bounds.size.width, H = self.bounds.size.height;
    CGContextRef c = UIGraphicsGetCurrentContext();

    CGGradientRef g = CGGradientCreateWithColors(CGColorSpaceCreateDeviceRGB(),
        (__bridge CFArrayRef)@[(__bridge id)[UIColor colorWithRed:0.03 green:0.04 blue:0.09 alpha:1].CGColor,
                                (__bridge id)[UIColor colorWithRed:0.09 green:0.13 blue:0.24 alpha:1].CGColor],
        NULL);
    CGContextDrawLinearGradient(c, g, CGPointMake(0, 0), CGPointMake(0, H), 0);
    CGGradientRelease(g);

    _buttons.clear();
    switch (_core->screen) {
        case sa::Screen::Menu: [self drawMenu:W h:H]; break;
        case sa::Screen::LevelSelect: [self drawLevelSelect:W h:H]; break;
        case sa::Screen::Settings: [self drawSettings:W h:H]; break;
        case sa::Screen::HowTo: [self drawHowTo:W h:H]; break;
        case sa::Screen::Credits: [self drawCredits:W h:H]; break;
        default:
            [self drawBoard:W h:H];
            if (_core->screen == sa::Screen::Paused) [self drawPaused:W h:H];
            if (_core->screen == sa::Screen::Win) [self drawWin:W h:H];
            break;
    }
    [self drawButtons];
}

- (void)drawButtons {
    for (auto& b : _buttons) {
        UIColor* fill = b.disabled ? [UIColor colorWithRed:0.12 green:0.14 blue:0.20 alpha:1]
                        : (b.primary ? Gold()
                        : [UIColor colorWithRed:0.10 green:0.14 blue:0.25 alpha:1]);
        UIColor* fg = b.disabled ? Muted()
                    : (b.primary ? [UIColor colorWithRed:0.10 green:0.07 blue:0.02 alpha:1] : Cream());
        Rounded(b.r, fill, Gold(), 12);
        DrawText(b.label, CGRectInset(b.r, 6, 4), 15, YES, fg, NSTextAlignmentCenter, _core->arabic());
    }
}

- (void)drawMenu:(CGFloat)W h:(CGFloat)H {
    DrawText(@"◐", CGRectMake(0, 14, W, 52), 40, YES, Gold(), NSTextAlignmentCenter);
    DrawText(_core->arabic() ? @"مهندس الظلال" : @"SHADOW ARCHITECT",
             CGRectMake(0, 60, W, 52), 34, YES, Cream(), NSTextAlignmentCenter, _core->arabic());
    DrawText(_core->arabic() ? @"الفصل الأول — غرفة البندول" : @"Chapter I — The Pendulum Room",
             CGRectMake(0, 112, W, 26), 14, NO, Muted(), NSTextAlignmentCenter, _core->arabic());
    Rounded(CGRectMake(W/2-210, 146, 420, 38), Panel(), Gold(), 12);
    DrawText(@"بسم الله الرحمن الرحيم  •  سبحان الله وبحمده",
             CGRectMake(W/2-200, 148, 400, 34), 13, NO, Gold(), NSTextAlignmentCenter, YES);
    DrawText(@"Designed & developed by Nasser", CGRectMake(0, 186, W, 22), 12, NO, Muted(), NSTextAlignmentCenter);

    CGFloat bw = std::min((CGFloat)230.0f, (W - 50) / 2), bh = 36, gap = 8;
    CGFloat lx = W/2 - bw - gap/2, rx = W/2 + gap/2;
    CGFloat y = 214;
    AddBtn(_buttons, CGRectMake(lx, y, bw, bh), 100,
           _core->arabic() ? @"العب" : @"PLAY", YES);
    AddBtn(_buttons, CGRectMake(rx, y, bw, bh), 103,
           _core->arabic() ? @"الإعدادات" : @"SETTINGS"); y += bh+gap;
    AddBtn(_buttons, CGRectMake(lx, y, bw, bh), 101,
           _core->arabic() ? @"اختيار المرحلة" : @"LEVEL SELECT");
    AddBtn(_buttons, CGRectMake(rx, y, bw, bh), 104,
           _core->arabic() ? @"الاعتمادات" : @"CREDITS"); y += bh+gap;
    AddBtn(_buttons, CGRectMake(lx, y, bw, bh), 102,
           _core->arabic() ? @"كيفية اللعب" : @"HOW TO PLAY");
    AddBtn(_buttons, CGRectMake(rx, y, bw, bh), 305,
           _core->arabic() ? @"English / الإنجليزية" : @"العربية / Arabic");
}

- (void)drawLevelSelect:(CGFloat)W h:(CGFloat)H {
    DrawText(_core->arabic() ? @"اختيار المرحلة" : @"LEVEL SELECT",
             CGRectMake(0, 24, W, 44), 26, YES, Cream(), NSTextAlignmentCenter, _core->arabic());
    CGFloat cw = (W - 80) / 3, ch = (H - 150) / 2;
    for (int i = 0; i < 6; ++i) {
        int col = i % 3, row = i / 3;
        CGRect r = CGRectMake(20 + col*cw + 6, 80 + row*ch + 6, cw - 12, ch - 12);
        bool locked = (i + 1) > _core->settings.unlocked;
        NSString* name = NSFromText(_core->arabic() ? _core->levels()[i].nameAr : _core->levels()[i].nameEn);
        NSMutableString* stars = [NSMutableString string];
        for (int k = 0; k < _core->settings.sparks[i]; ++k) [stars appendString:@"★"];
        NSString* label = [NSString stringWithFormat:@"%d. %@  %@", i+1, name,
                           locked ? (_core->arabic() ? @"(مغلق)" : @"(locked)") : stars];
        AddBtn(_buttons, r, 200+i, label, NO, locked);
    }
    AddBtn(_buttons, CGRectMake(W/2-90, H-52, 180, 38), 106,
           _core->arabic() ? @"رجوع" : @"BACK");
}

- (void)drawSettings:(CGFloat)W h:(CGFloat)H {
    DrawText(_core->arabic() ? @"الإعدادات" : @"SETTINGS",
             CGRectMake(0, 24, W, 44), 26, YES, Cream(), NSTextAlignmentCenter, _core->arabic());
    CGFloat x = W/2 - 170, w = 340, y = 82;
    AddBtn(_buttons, CGRectMake(x, y, 60, 38), 300, @"−");
    AddBtn(_buttons, CGRectMake(x+w-60, y, 60, 38), 301, @"+");
    DrawText([NSString stringWithFormat:@"%@ %d", _core->arabic() ? @"الموسيقى" : @"Music", _core->settings.music],
             CGRectMake(x+66, y, w-132, 38), 15, YES, Ink(), NSTextAlignmentCenter, _core->arabic());
    y += 52;
    AddBtn(_buttons, CGRectMake(x, y, 60, 38), 302, @"−");
    AddBtn(_buttons, CGRectMake(x+w-60, y, 60, 38), 303, @"+");
    DrawText([NSString stringWithFormat:@"%@ %d", _core->arabic() ? @"المؤثرات" : @"SFX", _core->settings.sfx],
             CGRectMake(x+66, y, w-132, 38), 15, YES, Ink(), NSTextAlignmentCenter, _core->arabic());
    y += 52;
    AddBtn(_buttons, CGRectMake(x, y, w, 38), 304,
           _core->arabic() ? @"اللغة: العربية  (اضغط للإنجليزية)" : @"Language: English  (tap for العربية)");
    y += 52;
    AddBtn(_buttons, CGRectMake(x, y, w, 38), 306,
           _core->arabic() ? @"مسح التقدّم" : @"RESET PROGRESS");
    y += 52;
    AddBtn(_buttons, CGRectMake(W/2-90, y+10, 180, 38), 106,
           _core->arabic() ? @"رجوع" : @"BACK");
}

- (void)drawHowTo:(CGFloat)W h:(CGFloat)H {
    DrawText(_core->arabic() ? @"كيفية اللعب" : @"HOW TO PLAY",
             CGRectMake(0, 24, W, 44), 26, YES, Cream(), NSTextAlignmentCenter, _core->arabic());
    NSArray* lines = _core->arabic() ? @[
        @"• دُجى يمشي فوق الظل فقط.",
        @"• النور يحوّل البلاط إلى فجوة.",
        @"• اضغط المصباح لتدويره والمرآة لقلبها.",
        @"• اضغط الترس لتغيير نبض الزمن.",
        @"• أوصله للقلب بأقل حركات لنيل ٣ شرارات.",
        @"• RUN تشغيل | Undo تراجع | Reset إعادة | Hint تلميح"
    ] : @[
        @"- Duja walks only over shadow.",
        @"- Light turns tiles into gaps.",
        @"- Tap a lamp to rotate, a mirror to flip.",
        @"- Tap a gear to shift its timing.",
        @"- Reach the Heart in Par moves for 3 sparks.",
        @"- RUN starts time | Undo steps back | Reset restarts | Hint helps"
    ];
    CGFloat y = 82;
    for (NSString* s in lines) {
        DrawText(s, CGRectMake(30, y, W-60, 34), 14, NO, Ink(),
                 NSTextAlignmentLeft, _core->arabic());
        y += 40;
    }
    AddBtn(_buttons, CGRectMake(W/2-90, H-52, 180, 38), 106,
           _core->arabic() ? @"رجوع" : @"BACK");
}

- (void)drawCredits:(CGFloat)W h:(CGFloat)H {
    DrawText(_core->arabic() ? @"الاعتمادات" : @"CREDITS",
             CGRectMake(0, 50, W, 44), 26, YES, Cream(), NSTextAlignmentCenter, _core->arabic());
    DrawText(@"Shadow Architect — مهندس الظلال", CGRectMake(0, 120, W, 40), 20, YES, Gold(), NSTextAlignmentCenter);
    DrawText(@"Designed, coded and drawn by Nasser", CGRectMake(0, 165, W, 30), 14, NO, Ink(), NSTextAlignmentCenter);
    DrawText(@"C++17 / UIKit / CoreGraphics — no ads, no external assets",
             CGRectMake(0, 200, W, 30), 12, NO, Muted(), NSTextAlignmentCenter);
    DrawText(@"بسم الله الرحمن الرحيم", CGRectMake(0, 240, W, 30), 14, NO, Gold(), NSTextAlignmentCenter, YES);
    AddBtn(_buttons, CGRectMake(W/2-90, H-60, 180, 38), 106,
           _core->arabic() ? @"رجوع" : @"BACK");
}

- (void)drawBoard:(CGFloat)W h:(CGFloat)H {
    _tile = std::min((W * 0.60f) / 12.0f, (H * 0.82f) / 8.0f);
    _bx = 18;
    _by = (H - _tile * 8) / 2;
    std::vector<std::vector<bool> > lit = _core->light();
    double now = [self nowMs];

    for (int y = 0; y < 8; ++y) for (int x = 0; x < 12; ++x) {
        CGRect r = CGRectMake(_bx + x*_tile + 1, _by + y*_tile + 1, _tile-2, _tile-2);
        char ch = (char)_core->grid[y][x];
        if (ch == '#') {
            Rounded(r, [UIColor colorWithRed:0.15 green:0.19 blue:0.30 alpha:1], nil, 5);
        } else if (ch == ' ') {
            [[UIColor colorWithRed:0.01 green:0.02 blue:0.04 alpha:1] setFill];
            UIRectFill(r);
        } else {
            UIColor* f = lit[y][x] ? [UIColor colorWithRed:0.29 green:0.25 blue:0.17 alpha:1]
                                   : [UIColor colorWithRed:0.06 green:0.10 blue:0.19 alpha:1];
            Rounded(r, f, [UIColor colorWithRed:0.20 green:0.26 blue:0.40 alpha:1], 5);
        }
    }

    for (auto& g : _core->gears) {
        CGPoint c = CGPointMake(_bx + g.p.x*_tile + _tile/2, _by + g.p.y*_tile + _tile/2);
        bool closed = ((_core->tick + g.phase) % g.period) >= (g.period/2);
        UIColor* col = closed ? [UIColor colorWithRed:1 green:0.62 blue:0.48 alpha:1]
                              : [UIColor colorWithRed:0.36 green:0.43 blue:0.58 alpha:1];
        for (int i = 0; i < 8; ++i) {
            double a = now/700.0 + i*0.785398;
            CGRect tooth = CGRectMake(c.x + cos(a)*_tile*0.34 - 3, c.y + sin(a)*_tile*0.34 - 4, 6, 8);
            Rounded(tooth, col, nil, 2);
        }
        Rounded(CGRectMake(c.x-11, c.y-11, 22, 22), col, nil, 11);
        Rounded(CGRectMake(c.x-4, c.y-4, 8, 8), [UIColor colorWithRed:0.04 green:0.07 blue:0.13 alpha:1], nil, 4);
    }

    for (auto& m : _core->mirrors) {
        CGPoint c = CGPointMake(_bx + m.p.x*_tile + _tile/2, _by + m.p.y*_tile + _tile/2);
        if (m.slash) Line(CGPointMake(c.x-12, c.y+12), CGPointMake(c.x+12, c.y-12), [UIColor colorWithRed:0.79 green:0.93 blue:1 alpha:1], 5);
        else Line(CGPointMake(c.x-12, c.y-12), CGPointMake(c.x+12, c.y+12), [UIColor colorWithRed:0.79 green:0.93 blue:1 alpha:1], 5);
    }

    const int DX[4] = {1,0,-1,0}, DY[4] = {0,1,0,-1};
    for (auto& l : _core->lamps) {
        CGPoint c = CGPointMake(_bx + l.p.x*_tile + _tile/2, _by + l.p.y*_tile + _tile/2);
        Rounded(CGRectMake(c.x-19, c.y-19, 38, 38), [UIColor colorWithRed:0.24 green:0.19 blue:0.11 alpha:1], nil, 19);
        Line(c, CGPointMake(c.x + DX[l.dir]*_tile*0.34, c.y + DY[l.dir]*_tile*0.34), Gold(), 4);
        Rounded(CGRectMake(c.x-9, c.y-9, 18, 18), Cream(), nil, 9);
        Rounded(CGRectMake(c.x-3, c.y-3, 6, 6), [UIColor colorWithRed:0.48 green:0.34 blue:0.16 alpha:1], nil, 3);
    }

    for (int y = 0; y < 8; ++y) for (int x = 0; x < 12; ++x)
        if (_core->grid[y][x] == u'G') {
            CGPoint c = CGPointMake(_bx + x*_tile + _tile/2, _by + y*_tile + _tile/2);
            bool open = !_core->level().goalRequiresLight || lit[y][x];
            UIColor* col = open ? Cream() : [UIColor colorWithRed:0.48 green:0.53 blue:0.65 alpha:1];
            UIBezierPath* heart = [UIBezierPath bezierPath];
            [heart moveToPoint:CGPointMake(c.x, c.y+12)];
            [heart addCurveToPoint:CGPointMake(c.x-16, c.y-4) controlPoint1:CGPointMake(c.x-18, c.y-2) controlPoint2:CGPointMake(c.x-18, c.y-14)];
            [heart addCurveToPoint:CGPointMake(c.x, c.y+6) controlPoint1:CGPointMake(c.x-12, c.y+4) controlPoint2:CGPointMake(c.x-6, c.y+12)];
            [heart addCurveToPoint:CGPointMake(c.x+16, c.y-4) controlPoint1:CGPointMake(c.x+6, c.y+12) controlPoint2:CGPointMake(c.x+12, c.y+4)];
            [heart addCurveToPoint:CGPointMake(c.x, c.y+12) controlPoint1:CGPointMake(c.x+18, c.y-14) controlPoint2:CGPointMake(c.x+18, c.y-2)];
            [col setFill]; [heart fill];
        }

    {
        CGFloat bob = sin(now/160.0) * 1.5;
        CGPoint c = CGPointMake(_bx + _core->duja.x*_tile + _tile/2,
                                _by + _core->duja.y*_tile + _tile/2 + bob);
        CGFloat s = _tile * 0.72f;
        Rounded(CGRectMake(c.x-s/2, c.y-s/2, s, s), [UIColor colorWithRed:0.17 green:0.23 blue:0.41 alpha:1], Gold(), s/2);
        int look = DX[_core->dir];
        Rounded(CGRectMake(c.x-s*0.28+look*1.5, c.y-s*0.20, s*0.20, s*0.24), [UIColor whiteColor], nil, s*0.10);
        Rounded(CGRectMake(c.x+s*0.08+look*1.5, c.y-s*0.20, s*0.20, s*0.24), [UIColor whiteColor], nil, s*0.10);
        Rounded(CGRectMake(c.x-s*0.24+look*1.5, c.y-s*0.13, s*0.08, s*0.10), [UIColor blackColor], nil, s*0.04);
        Rounded(CGRectMake(c.x+s*0.12+look*1.5, c.y-s*0.13, s*0.08, s*0.10), [UIColor blackColor], nil, s*0.04);
    }

    if (!_core->bubble.empty()) {
        NSString* s = NSFromText(_core->bubble);
        CGFloat bw = std::min((CGFloat)280.0f, _tile*5);
        CGRect bubble = CGRectMake(std::max(_bx, std::min(_bx + _core->duja.x*_tile - bw/2, _bx + 12*_tile - bw)),
                                   std::max(CGFloat(2), _by + _core->duja.y*_tile - 30), bw, 28);
        Rounded(bubble, [UIColor colorWithRed:0.05 green:0.07 blue:0.14 alpha:0.96], Gold(), 10);
        DrawText(s, CGRectInset(bubble, 4, 2), 11, YES, Cream(), NSTextAlignmentCenter, _core->arabic());
    }

    [self drawHud:W h:H];
}

- (void)drawHud:(CGFloat)W h:(CGFloat)H {
    CGFloat px = _bx + 12*_tile + 14;
    CGFloat pw = W - px - 16;
    Rounded(CGRectMake(px, _by, pw, 8*_tile), Panel(), Gold(), 14);

    const sa::Level& L = _core->level();
    sa::Text tag = _core->arabic() ? sa::U("المرحلة ") : sa::U("Level ");
    tag += sa::U(std::to_string(L.id).c_str());
    DrawText(NSFromText(tag), CGRectMake(px+10, _by+8, pw-20, 18), 12, YES, Gold(), NSTextAlignmentLeft, _core->arabic());
    DrawText(NSFromText(_core->arabic() ? L.nameAr : L.nameEn),
             CGRectMake(px+10, _by+26, pw-20, 26), 17, YES, Cream(), NSTextAlignmentLeft, _core->arabic());
    DrawText(NSFromText(_core->arabic() ? L.hookAr : L.hookEn),
             CGRectMake(px+10, _by+56, pw-20, 60), 12, NO, Muted(), NSTextAlignmentLeft, _core->arabic());

    sa::Text st = _core->arabic() ? sa::U("الحركات: ") : sa::U("Moves: ");
    st += sa::U(std::to_string(_core->moves).c_str());
    st += _core->arabic() ? sa::U("  |  المثالي: ") : sa::U("  |  Par: ");
    st += sa::U(std::to_string(L.par).c_str());
    DrawText(NSFromText(st), CGRectMake(px+10, _by+120, pw-20, 22), 13, YES, Ink(), NSTextAlignmentLeft, _core->arabic());

    int earned = _core->moves <= L.par ? 3 : (_core->moves <= L.par+2 ? 2 : 1);
    NSString* stars = earned == 3 ? @"★★★" : (earned == 2 ? @"★★☆" : @"★☆☆");
    DrawText(stars, CGRectMake(px+10, _by+144, pw-20, 24), 20, YES, Gold(), NSTextAlignmentLeft);

    CGFloat by = _by + 176;
    AddBtn(_buttons, CGRectMake(px+10, by, pw-20, 30), 400,
           _core->running ? (_core->arabic() ? @"إيقاف" : @"PAUSE") : (_core->arabic() ? @"تشغيل" : @"RUN"), YES);
    AddBtn(_buttons, CGRectMake(px+10, by+34, (pw-24)/2, 30), 404, _core->arabic() ? @"تراجع" : @"UNDO");
    AddBtn(_buttons, CGRectMake(px+14+(pw-24)/2, by+34, (pw-24)/2, 30), 401, _core->arabic() ? @"إعادة" : @"RESET");
    AddBtn(_buttons, CGRectMake(px+10, by+68, pw-20, 30), 402, _core->arabic() ? @"تلميح" : @"HINT");
    AddBtn(_buttons, CGRectMake(px+10, by+102, pw-20, 30), 403,
           _core->arabic() ? @"القائمة الرئيسية" : @"MAIN MENU");
}

- (void)drawPaused:(CGFloat)W h:(CGFloat)H {
    CGFloat x = _bx + 12*_tile + 14, y = _by + 20, w = W - x - 16;
    Rounded(CGRectMake(x, y, w, 8*_tile-40), [UIColor colorWithRed:0.03 green:0.05 blue:0.10 alpha:0.98], Gold(), 14);
    DrawText(_core->arabic() ? @"إيقاف مؤقت" : @"PAUSED",
             CGRectMake(x+10, y+16, w-20, 40), 22, YES, Cream(), NSTextAlignmentCenter, _core->arabic());
    CGFloat by = y+70;
    AddBtn(_buttons, CGRectMake(x+12, by, w-24, 34), 500, _core->arabic() ? @"متابعة" : @"RESUME", YES); by += 42;
    AddBtn(_buttons, CGRectMake(x+12, by, w-24, 34), 401, _core->arabic() ? @"إعادة المرحلة" : @"RESTART"); by += 42;
    AddBtn(_buttons, CGRectMake(x+12, by, w-24, 34), 501, _core->arabic() ? @"الإعدادات" : @"SETTINGS"); by += 42;
    AddBtn(_buttons, CGRectMake(x+12, by, w-24, 34), 502, _core->arabic() ? @"القائمة الرئيسية" : @"MAIN MENU");
}

- (void)drawWin:(CGFloat)W h:(CGFloat)H {
    CGFloat x = _bx + 12*_tile + 14, y = _by + 10, w = W - x - 16;
    Rounded(CGRectMake(x, y, w, 8*_tile-20), [UIColor colorWithRed:0.03 green:0.05 blue:0.10 alpha:0.98], Gold(), 14);
    DrawText(_core->arabic() ? @"وصل دُجى إلى القلب!" : @"DUJA REACHED THE HEART!",
             CGRectMake(x+6, y+12, w-12, 40), 18, YES, Cream(), NSTextAlignmentCenter, _core->arabic());
    NSString* stars = _core->earnedSparks == 3 ? @"★★★" : (_core->earnedSparks == 2 ? @"★★☆" : @"★☆☆");
    DrawText(stars, CGRectMake(x+6, y+50, w-12, 30), 22, YES, Gold(), NSTextAlignmentCenter);
    DrawText(NSFromText(_core->arabic() ? _core->level().ahaAr : _core->level().ahaEn),
             CGRectMake(x+14, y+86, w-28, 120), 12, NO, Ink(), NSTextAlignmentCenter, _core->arabic());
    CGFloat by = y + 8*_tile - 150;
    AddBtn(_buttons, CGRectMake(x+12, by, w-24, 34), 601, _core->arabic() ? @"أعِد اللعب" : @"REPLAY"); by += 42;
    bool last = _core->levelIndex == 5;
    AddBtn(_buttons, CGRectMake(x+12, by, w-24, 34), last ? 602 : 600,
           last ? (_core->arabic() ? @"القائمة" : @"MENU") : (_core->arabic() ? @"التالي" : @"NEXT"), YES); by += 42;
    AddBtn(_buttons, CGRectMake(x+12, by, w-24, 32), 602,
           _core->arabic() ? @"القائمة الرئيسية" : @"MAIN MENU");
}

// ---------------- input ----------------
- (void)touchesBegan:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    CGPoint p = [[touches anyObject] locationInView:self];
    for (auto it = _buttons.rbegin(); it != _buttons.rend(); ++it) {
        if (it->disabled) continue;
        if (CGRectContainsPoint(it->r, p)) { [self button:it->tag]; return; }
    }
    if (_core->screen == sa::Screen::Playing && !_core->dead && !_core->won) {
        if (p.x >= _bx && p.y >= _by && p.x < _bx + 12*_tile && p.y < _by + 8*_tile) {
            int tx = (int)((p.x - _bx)/_tile), ty = (int)((p.y - _by)/_tile);
            if (_core->act(tx, ty)) [self playSfx:1];
        }
    }
}

- (void)button:(int)tag {
    if (tag == 100) { _core->initLevel(std::max(0, _core->settings.unlocked-1)); [self speak:_core->arabic() ? _core->level().speechAr : _core->level().speechEn seconds:3]; return; }
    if (tag == 101) { _core->returnScreen = sa::Screen::Menu; _core->screen = sa::Screen::LevelSelect; return; }
    if (tag == 102) { _core->returnScreen = sa::Screen::Menu; _core->screen = sa::Screen::HowTo; return; }
    if (tag == 103 || tag == 501) { _core->returnScreen = _core->screen == sa::Screen::Paused ? sa::Screen::Paused : sa::Screen::Menu; _core->screen = sa::Screen::Settings; return; }
    if (tag == 104) { _core->returnScreen = sa::Screen::Menu; _core->screen = sa::Screen::Credits; return; }
    if (tag == 106) { _core->screen = _core->returnScreen; return; }
    if (tag >= 200 && tag < 206) {
        int i = tag-200;
        if (i < _core->settings.unlocked) {
            _core->initLevel(i);
            [self speak:_core->arabic() ? _core->level().speechAr : _core->level().speechEn seconds:3];
        }
        return;
    }
    if (tag == 300) { _core->settings.music = std::max(0, _core->settings.music-1); [self applyMusic]; }
    if (tag == 301) { _core->settings.music = std::min(3, _core->settings.music+1); [self applyMusic]; }
    if (tag == 302) { _core->settings.sfx = std::max(0, _core->settings.sfx-1); }
    if (tag == 303) { _core->settings.sfx = std::min(3, _core->settings.sfx+1); }
    if (tag == 304 || tag == 305) { _core->settings.lang = _core->arabic() ? 1 : 0; [self saveSettings]; return; }
    if (tag == 306) { _core->settings.unlocked = 1; for (int i=0;i<6;++i) _core->settings.sparks[i]=0; }
    if (tag == 400) {
        if (_core->running) { _core->running = false; _core->screen = sa::Screen::Paused; }
        else { _core->running = true; _lastStep = [self nowMs]; }
        return;
    }
    if (tag == 404) { _core->undo(); return; }
    if (tag == 401) { _core->initLevel(_core->levelIndex); [self speak:_core->arabic() ? _core->level().speechAr : _core->level().speechEn seconds:3]; return; }
    if (tag == 402) { [self speak:_core->arabic() ? _core->level().hintAr : _core->level().hintEn seconds:4]; return; }
    if (tag == 403 || tag == 502 || tag == 602) { _core->running = false; _core->screen = sa::Screen::Menu; return; }
    if (tag == 500) { _core->screen = sa::Screen::Playing; _core->running = true; _lastStep = [self nowMs]; return; }
    if (tag == 600) { _core->initLevel(_core->levelIndex+1); [self speak:_core->arabic() ? _core->level().speechAr : _core->level().speechEn seconds:3]; return; }
    if (tag == 601) { _core->initLevel(_core->levelIndex); return; }
    [self saveSettings];
}

- (void)applyMusic {
    if (_core->settings.music == 0) { [_musicPlayer stop]; }
    else {
        _musicPlayer.volume = 0.05f + 0.045f * _core->settings.music;
        if (!_musicPlayer.playing) [_musicPlayer play];
    }
    [self saveSettings];
}

@end
