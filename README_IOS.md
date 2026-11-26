# مهندس الظلال — Shadow Architect (iOS / C++)

لعبة أيفون أصلية بالكامل: C++17 للمنطق + UIKit/CoreGraphics للواجهة. **ما فيها HTML، ما فيها WebView، ما فيها exe، وما فيها إعلانات.**

## اللي موجود داخل اللعبة
- 6 مراحل متتابعة بآلية واحدة جديدة كل مرحلة (مصابيح، مرايا، تروس، بوابة القلب).
- قوائم كاملة: الرئيسية، اختيار المرحلة، كيفية اللعب، الإعدادات، الاعتمادات، إيقاف مؤقت، فوز/إعادة/تراجع/تلميح.
- دُجى يتكلم عربي (وإنجليزي)، مع فقاعة كلام داخل اللوحة.
- شاشة البداية: «بسم الله الرحمن الرحيم • سبحان الله وبحمده • سبحان الله العظيم» + «Designed & developed by Nasser» + زر AR/EN.
- موسيقى هادئة ومؤثرات صوتية **مولّدة في الذاكرة** (WAV) بدون ملفات صوت خارجية.
- حفظ التقدّم والشرارات والإعدادات في `NSUserDefaults`.
- دعم iPhone وiPad، اتجاه أفقي (landscape)، iOS 14+.

## الحجم
الـ IPA الناتج سيكون **بضعة ميغابايتات**، وهذا طبيعي جداً لألعاب App Store. الحجم (200MB+) ييجي من الأصول الضخمة (صور/صوت/فيديو HD) — منطق اللعبة ما يستهلك مساحة تُذكر. لو تفضّل تقريب الحجم من 200MB نضيف أصول HD لاحقاً، بس هذا **ما يزود الجودة**، اللعبة كاملة كما هي.

---

## الطريقة الأسهل: GitHub Actions يبني الـ IPA (بدون مايك عندك)

> التوقيع يحتاج macOS + Xcode + شهادة Apple. هذي الأشياء ما تتولّد على Windows.

### 1) اعمل repo جديد وارفع محتوى المجلد `shadow-architect-ios` كامل (بما فيه `.github/workflows/build-ios.yml`).

### 2) أضف الـ Secrets في:
`repo > Settings > Secrets and variables > Actions > New repository secret`

| الاسم | القيمة |
|---|---|
| `IOS_CERT_P12` | الشهادة بصيغة base64: `base64 -i cert.p12 \| tr -d '\n'` |
| `IOS_CERT_PASSWORD` | كلمة مرور الـ p12 |
| `IOS_PROVISIONING_PROFILE` | ملف `.mobileprovision` بصيغة base64 |
| `IOS_TEAM_ID` | معرّف الفريق، مثال `AB12CD34` |
| `IOS_PROFILE_NAME` | اسم الـ profile داخل Xcode |
| `IOS_CODE_SIGN_IDENTITY` | `Apple Development: Nasser (AB12CD34)` أو `Apple Distribution: ...` |

Variables اختيارية:
- `BUNDLE_ID` = `com.nasser.shadowarchitect` (لازم يطابق الـ profile).
- `IOS_EXPORT_METHOD` = `development` | `ad-hoc` | `app-store`.

### 3) شغّل الـ workflow
`Actions > Build Shadow Architect IPA > Run workflow`. بعد ما يخلص، نزّل الـ artifact اسمه **`ShadowArchitect-IPA`** من صفحة الـ run. داخله تجد ملف `.ipa` جاهز.

### 4) ثبّت على الجوال
- **development**: عبر Xcode (Devices and Simulators) أو Apple Configurator، وينتهي بعد 7 أيام إذا التوقيع مجاني.
- **ad-hoc**: يحتاج UDID الجهاز داخل الـ profile.
- **app-store**: ارفعه عبر Transporter/TestFlight (يحتاج Apple Developer Program مدفوع).

ملاحظة: التوقيع المجاني بالـ Apple ID الشخصي يصلح للتطوير بس، وليس للنشر على App Store.

---

## بناء محلي على Mac (اختياري)

```bash
cd shadow-architect-ios
cmake -S . -B build -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT=iphoneos \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
  -DSA_BUNDLE_ID=com.nasser.shadowarchitect

open build/ShadowArchitect.xcodeproj
```
اختر الـ team و sign من تبويب Signing & Capabilities، ثم Product > Archive > Distribute App.

---

## هيكل الملفات
```
GameCore.hpp / GameCore.cpp   منطق الألغاز، المراحل الست، الحفظ الداخلي
Audio.hpp / Audio.cpp         توليد الموسيقى والمؤثرات (WAV في الذاكرة)
ios/GameView.mm               كل الرسوم والقوائم والمساس (UIKit + CoreGraphics)
ios/AppDelegate.mm            إقلاع التطبيق
ios/GameViewController.mm     مدير الشاشة والاتجاه
ios/Info.plist                بيانات الحزمة
ios/LaunchScreen.storyboard   شاشة الإقلاع المطلوبة لـ App Store
ios/AppIcon.png               أيقونة التطبيق (1024×1024)
CMakeLists.txt                إعداد مشروع Xcode
.github/workflows/build-ios.yml  بناء وتوقيع وتصدير الـ IPA على macOS
```

الحقيقة: ما أقدر أطلع لك IPA موقع من بيئة Windows. اللي عندك هنا هو **المشروع الكامل الجاهز**، وأول تشغيل للـ workflow على Mac بيطلع لك الملف. أي خطأ بناء/توقيع يظهر في سجل الـ Actions نصلحه سوا.
