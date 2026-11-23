// Objective-C++ bridge: converts Objective-C values into roados::binding specs
// and back. No rendering or RVHL logic lives here; see the shared C++ core.
#import "RoadOSBridge.h"

#include <memory>
#include <vector>

#include <roados/binding/Binding.h>

using namespace roados;

NSErrorDomain const ROSErrorDomain = @"RoadOSGraphicsErrorDomain";

// Private (C++-typed) initialisers and accessors, visible only inside this file.
@interface ROSFamily ()
- (instancetype)initWithFamily:(const rvhl::Family &)family;
@end
@interface ROSEntry ()
- (instancetype)initWithEntry:(const rvhl::Entry &)entry;
@end
@interface ROSLibrary ()
- (instancetype)initWithLibrary:(const rvhl::Library &)library;
- (const rvhl::Library &)cppLibrary;
@end

namespace {

NSString *str(const std::string &s) { return [[NSString alloc] initWithBytes:s.data() length:s.size() encoding:NSUTF8StringEncoding] ?: @""; }
std::string cpp(NSString *s) { return s ? std::string(s.UTF8String ?: "") : std::string(); }

BOOL fail(const Error &e, NSError **out) {
    if (out) {
        *out = [NSError errorWithDomain:ROSErrorDomain
                                   code:static_cast<NSInteger>(e.code) + 1
                               userInfo:@{NSLocalizedDescriptionKey: str(e.message)}];
    }
    return NO;
}

template <class T> std::vector<T> numbers(NSArray<NSNumber *> *a);
template <> std::vector<float> numbers(NSArray<NSNumber *> *a) {
    std::vector<float> v;
    v.reserve(a.count);
    for (NSNumber *n in a) v.push_back(n.floatValue);
    return v;
}
template <> std::vector<std::uint32_t> numbers(NSArray<NSNumber *> *a) {
    std::vector<std::uint32_t> v;
    v.reserve(a.count);
    for (NSNumber *n in a) v.push_back(n.unsignedIntValue);
    return v;
}

binding::PaintSpec spec(ROSPaint *p) {
    binding::PaintSpec s;
    if (!p) return s;
    s.kind = static_cast<int>(p.kind);
    s.argb = p.argb;
    s.x0 = p.x0; s.y0 = p.y0; s.x1 = p.x1; s.y1 = p.y1; s.radius = p.radius;
    s.stopOffsets = numbers<float>(p.stopOffsets);
    s.stopColors = numbers<std::uint32_t>(p.stopColors);
    s.spread = static_cast<int>(p.spread);
    return s;
}

binding::StyleSpec spec(ROSStyle *st) {
    binding::StyleSpec s;
    if (!st) return s;
    s.fill = spec(st.fill);
    s.stroke = spec(st.stroke);
    s.strokeWidth = st.strokeWidth;
    s.lineCap = static_cast<int>(st.lineCap);
    s.lineJoin = static_cast<int>(st.lineJoin);
    s.miterLimit = st.miterLimit;
    s.dash = numbers<float>(st.dash);
    s.dashOffset = st.dashOffset;
    s.opacity = st.opacity;
    s.blend = static_cast<int>(st.blend);
    const CGAffineTransform t = st.transform;
    const float m[6] = {float(t.a), float(t.b), float(t.c), float(t.d), float(t.tx), float(t.ty)};
    std::copy(m, m + 6, s.transform);
    return s;
}

binding::HazardSpec spec(ROSHazardSpec *h) {
    binding::HazardSpec s;
    s.id = cpp(h.identifier);
    s.variant = cpp(h.variant);
    s.severity = static_cast<int>(h.severity);
    s.theme = static_cast<int>(h.theme);
    s.representation = static_cast<int>(h.representation);
    s.sizeVariant = static_cast<int>(h.sizeVariant);
    s.count = static_cast<int>(h.count);
    s.speedKind = static_cast<int>(h.speedKind);
    s.speedKmh = h.speedKmh;
    s.speedUnit = static_cast<int>(h.speedUnit);
    s.distanceM = h.distanceMeters;
    s.unitSystem = static_cast<int>(h.unitSystem);
    s.direction = static_cast<int>(h.direction);
    s.laneCount = static_cast<int>(h.laneCount);
    s.laneIndex = static_cast<int>(h.laneIndex);
    s.showSeverityCode = h.showSeverityCode;
    s.hasBackground = h.hasBackground;
    s.backgroundArgb = h.backgroundARGB;
    for (NSNumber *n in h.layers) s.layers.push_back(n.intValue);
    s.width = static_cast<int>(h.width);
    s.height = static_cast<int>(h.height);
    return s;
}

/// roados::Image (premultiplied RGBA8888) → CGImage, sharing nothing with the core.
CGImageRef makeCGImage(const Image &img) {
    const auto px = img.pixels();
    CFDataRef data = CFDataCreate(kCFAllocatorDefault, px.data(), static_cast<CFIndex>(px.size()));
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGImageRef out = CGImageCreate(static_cast<size_t>(img.width()), static_cast<size_t>(img.height()), 8, 32,
                                   img.stride(), cs,
                                   static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big, provider, nullptr,
                                   false, kCGRenderingIntentDefault);
    CGColorSpaceRelease(cs);
    CGDataProviderRelease(provider);
    CFRelease(data);
    return out;
}

}  // namespace

NSString *ROSCoreVersion(void) { return str(binding::versionString()); }

BOOL ROSParseColor(NSString *text, uint32_t *argb) {
    auto c = Color::parse(cpp(text));
    if (!c) return NO;
    if (argb) *argb = c->argb();
    return YES;
}

// ---------------------------------------------------------------- value types

@implementation ROSPaint
- (instancetype)init {
    if ((self = [super init])) {
        _argb = 0xFF000000;
        _stopOffsets = @[];
        _stopColors = @[];
    }
    return self;
}
@end

@implementation ROSStyle
- (instancetype)init {
    if ((self = [super init])) {
        _fill = [ROSPaint new];
        _stroke = [ROSPaint new];
        _strokeWidth = 1;
        _miterLimit = 4;
        _dash = @[];
        _opacity = 1;
        _transform = CGAffineTransformIdentity;
    }
    return self;
}
@end

@implementation ROSHazardSpec
- (instancetype)init {
    if ((self = [super init])) {
        _identifier = @"";
        _variant = @"";
        _sizeVariant = -1;
        _speedKind = -1;
        _speedKmh = -1;
        _distanceMeters = -1;
        _direction = -1;
        _showSeverityCode = YES;
        _layers = @[];
        _width = 128;
        _height = 128;
    }
    return self;
}
@end

@implementation ROSFamily
- (instancetype)initWithFamily:(const rvhl::Family &)f {
    if ((self = [super init])) {
        _identifier = str(f.id);
        _code = str(f.code);
        _label = str(f.label);
        _section = str(f.section);
        _familyDescription = str(f.description);
    }
    return self;
}
@end

@implementation ROSEntry
- (instancetype)initWithEntry:(const rvhl::Entry &)e {
    if ((self = [super init])) {
        _identifier = str(e.id);
        _name = str(e.name);
        _slug = str(e.slug);
        _family = str(e.family);
        _entryDescription = str(e.description);
        _frame = @(rvhl::toString(e.frame));
        _standardFrame = e.standardFrame ? @(rvhl::toString(*e.standardFrame)) : nil;
        NSMutableArray *vs = [NSMutableArray array];
        for (const auto &v : e.variants) [vs addObject:str(v)];
        _variants = vs;
        _defaultVariant = e.visual.glyphVariant ? str(*e.visual.glyphVariant) : nil;
        _defaultSeverity = static_cast<NSInteger>(e.severity.defaultLevel);
        _glyph = str(e.visual.glyph);
        _speedAdvisory = str(e.speed.advisory);
        NSMutableArray *ts = [NSMutableArray array];
        for (const auto &t : e.tags) [ts addObject:str(t)];
        _tags = ts;
    }
    return self;
}
@end

// ---------------------------------------------------------------- library

@implementation ROSLibrary {
    rvhl::Library _lib;
    NSArray<ROSEntry *> *_entries;
    NSArray<ROSFamily *> *_families;
    NSDictionary<NSString *, ROSEntry *> *_byId;
}

+ (instancetype)libraryWithPath:(NSString *)path error:(NSError **)error {
    auto lib = binding::sharedLibrary(cpp(path));
    if (!lib) {
        fail(lib.error(), error);
        return nil;
    }
    return [[ROSLibrary alloc] initWithLibrary:*lib];
}

- (instancetype)initWithLibrary:(const rvhl::Library &)lib {
    if ((self = [super init])) {
        _lib = lib;
        NSMutableArray *es = [NSMutableArray arrayWithCapacity:lib.entries().size()];
        NSMutableDictionary *byId = [NSMutableDictionary dictionary];
        for (const auto &e : lib.entries()) {
            ROSEntry *x = [[ROSEntry alloc] initWithEntry:e];
            [es addObject:x];
            byId[x.identifier] = x;
        }
        _entries = es;
        _byId = byId;
        NSMutableArray *fs = [NSMutableArray array];
        for (const auto &f : lib.families()) [fs addObject:[[ROSFamily alloc] initWithFamily:f]];
        _families = fs;
    }
    return self;
}

- (const rvhl::Library &)cppLibrary { return _lib; }
- (NSString *)rvhlVersion { return str(_lib.info().rvhlVersion); }
- (NSString *)studioCommit { return str(_lib.info().studioCommit); }
- (NSArray<ROSEntry *> *)entries { return _entries; }
- (NSArray<ROSFamily *> *)families { return _families; }

- (ROSEntry *)entryForKey:(NSString *)key {
    const rvhl::Entry *e = _lib.find(cpp(key));
    return e ? _byId[str(e->id)] : nil;
}

- (ROSEntry *)lookupEntry:(NSString *)key error:(NSError **)error {
    auto e = _lib.get(cpp(key));
    if (!e) {
        fail(e.error(), error);
        return nil;
    }
    return _byId[str((*e)->id)];
}

- (NSString *)svgForHazard:(ROSHazardSpec *)hs error:(NSError **)error {
    auto h = binding::makeHazard(_lib, spec(hs));
    if (!h) {
        fail(h.error(), error);
        return nil;
    }
    auto svg = h->toSvg();
    if (!svg) {
        fail(svg.error(), error);
        return nil;
    }
    return str(*svg);
}

- (CGImageRef)renderHazard:(ROSHazardSpec *)hs scale:(CGFloat)scale error:(NSError **)error {
    auto h = binding::makeHazard(_lib, spec(hs));
    if (!h) {
        fail(h.error(), error);
        return nullptr;
    }
    RenderOptions o;
    o.scale = static_cast<float>(scale);
    auto img = h->render(o);
    if (!img) {
        fail(img.error(), error);
        return nullptr;
    }
    return makeCGImage(*img);
}

@end

// ---------------------------------------------------------------- scene

@implementation ROSScene {
    std::unique_ptr<binding::SceneBuilder> _b;
}

- (instancetype)initWithWidth:(NSInteger)width height:(NSInteger)height {
    if ((self = [super init])) {
        _b = std::make_unique<binding::SceneBuilder>(static_cast<int>(width), static_cast<int>(height));
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    ROSScene *c = [[ROSScene allocWithZone:zone] initWithWidth:_b->width() height:_b->height()];
    c->_b = std::make_unique<binding::SceneBuilder>(*_b);
    return c;
}

- (NSInteger)width { return _b->width(); }
- (NSInteger)height { return _b->height(); }
- (NSInteger)groupDepth { return _b->groupDepth(); }
- (void)setBackgroundARGB:(uint32_t)argb { _b->setBackground(argb); }
- (void)clear { _b->clear(); }

static BOOL done(const Result<void> &r, NSError **error) { return r ? YES : fail(r.error(), error); }

- (BOOL)addCircleX:(float)cx y:(float)cy radius:(float)r style:(ROSStyle *)style error:(NSError **)error {
    return done(_b->circle(cx, cy, r, spec(style)), error);
}
- (BOOL)addEllipseX:(float)cx y:(float)cy radiusX:(float)rx radiusY:(float)ry style:(ROSStyle *)style error:(NSError **)error {
    return done(_b->ellipse(cx, cy, rx, ry, spec(style)), error);
}
- (BOOL)addRectX:(float)x y:(float)y width:(float)w height:(float)h radiusX:(float)rx radiusY:(float)ry
           style:(ROSStyle *)style error:(NSError **)error {
    return done(_b->rect(x, y, w, h, rx, ry, spec(style)), error);
}
- (BOOL)addLineX1:(float)x1 y1:(float)y1 x2:(float)x2 y2:(float)y2 style:(ROSStyle *)style error:(NSError **)error {
    return done(_b->line(x1, y1, x2, y2, spec(style)), error);
}
- (BOOL)addPolyPoints:(NSArray<NSNumber *> *)points closed:(BOOL)closed style:(ROSStyle *)style error:(NSError **)error {
    const auto xy = numbers<float>(points);
    return done(_b->poly(xy, closed, spec(style)), error);
}
- (BOOL)addPathData:(NSString *)d evenOdd:(BOOL)evenOdd style:(ROSStyle *)style error:(NSError **)error {
    return done(_b->path(cpp(d), evenOdd, spec(style)), error);
}
- (BOOL)addText:(NSString *)text x:(float)x y:(float)y fontFamilies:(NSString *)families size:(float)size
         weight:(NSInteger)weight italic:(BOOL)italic anchor:(NSInteger)anchor baseline:(NSInteger)baseline
          style:(ROSStyle *)style error:(NSError **)error {
    return done(_b->text(cpp(text), x, y, cpp(families), size, static_cast<int>(weight), italic,
                         static_cast<int>(anchor), static_cast<int>(baseline), spec(style)),
                error);
}
- (BOOL)addSVG:(NSString *)markup x:(float)x y:(float)y width:(float)w height:(float)h style:(ROSStyle *)style
         error:(NSError **)error {
    return done(_b->svg(cpp(markup), x, y, w, h, spec(style)), error);
}

- (BOOL)addImage:(CGImageRef)image x:(float)x y:(float)y width:(float)w height:(float)h style:(ROSStyle *)style
           error:(NSError **)error {
    // Platform marshaling only: redraw the CGImage into premultiplied RGBA8888.
    const size_t iw = CGImageGetWidth(image), ih = CGImageGetHeight(image);
    if (iw == 0 || ih == 0) return fail(makeError(ErrorCode::InvalidArgument, "image is empty"), error);
    std::vector<std::uint8_t> px(iw * ih * 4);
    CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef ctx = CGBitmapContextCreate(px.data(), iw, ih, 8, iw * 4, cs,
                                             static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(cs);
    if (!ctx) return fail(makeError(ErrorCode::Render, "cannot create a bitmap context for the image"), error);
    CGContextDrawImage(ctx, CGRectMake(0, 0, iw, ih), image);
    CGContextRelease(ctx);
    return done(_b->image(px, static_cast<int>(iw), static_cast<int>(ih), iw * 4, x, y, w, h, spec(style)), error);
}

- (BOOL)addHazard:(ROSHazardSpec *)hs library:(ROSLibrary *)library x:(float)x y:(float)y width:(float)w
           height:(float)h error:(NSError **)error {
    return done(_b->hazard([library cppLibrary], spec(hs), x, y, w, h), error);
}

- (BOOL)beginGroupTransform:(CGAffineTransform)t opacity:(float)opacity clip:(BOOL)clip clipRect:(CGRect)r
                      error:(NSError **)error {
    const float m[6] = {float(t.a), float(t.b), float(t.c), float(t.d), float(t.tx), float(t.ty)};
    return done(_b->beginGroup(m, opacity, clip, float(r.origin.x), float(r.origin.y), float(r.size.width),
                               float(r.size.height)),
                error);
}

- (BOOL)endGroupWithError:(NSError **)error { return done(_b->endGroup(), error); }

- (CGImageRef)renderWithScale:(CGFloat)scale error:(NSError **)error {
    auto img = _b->render(static_cast<float>(scale));
    if (!img) {
        fail(img.error(), error);
        return nullptr;
    }
    return makeCGImage(*img);
}

- (NSString *)svgWithError:(NSError **)error {
    auto svg = _b->toSvg();
    if (!svg) {
        fail(svg.error(), error);
        return nil;
    }
    return str(*svg);
}

@end
