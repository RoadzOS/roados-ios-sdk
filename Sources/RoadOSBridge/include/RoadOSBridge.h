// RoadOSBridge: Objective-C surface over RoadOS Graphics Core's binding facade.
//
// This header is pure Objective-C (no C++), so Swift imports it directly. The
// implementation (RoadOSBridge.mm) only converts values; all graphics and RVHL
// logic lives in the shared C++ core. App code should use the Swift API in the
// RoadOSGraphics module instead of this layer.
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const ROSErrorDomain;

/// Mirrors roados::ErrorCode (+1, so 0 is never a valid code).
typedef NS_ERROR_ENUM(ROSErrorDomain, ROSErrorCode) {
    ROSErrorInvalidArgument = 1,
    ROSErrorParse = 2,
    ROSErrorIo = 3,
    ROSErrorNotFound = 4,
    ROSErrorUnsupported = 5,
    ROSErrorRender = 6,
    ROSErrorValidation = 7,
    ROSErrorIncompatible = 8,
};

/// Core library version, e.g. "0.2.0".
FOUNDATION_EXPORT NSString *ROSCoreVersion(void);
/// Parses "#RGB", "#RGBA", "#RRGGBB", "#RRGGBBAA" or "transparent" with the core's parser.
FOUNDATION_EXPORT BOOL ROSParseColor(NSString *text, uint32_t *argb);

/// Fill or stroke paint. kind: 0 none, 1 solid, 2 linear gradient, 3 radial gradient.
@interface ROSPaint : NSObject
@property (nonatomic) NSInteger kind;
@property (nonatomic) uint32_t argb;
@property (nonatomic) float x0, y0, x1, y1, radius;
@property (nonatomic, copy) NSArray<NSNumber *> *stopOffsets;
@property (nonatomic, copy) NSArray<NSNumber *> *stopColors;  ///< 0xAARRGGBB
@property (nonatomic) NSInteger spread;                       ///< 0 pad, 1 repeat, 2 reflect
@end

@interface ROSStyle : NSObject
@property (nonatomic, strong) ROSPaint *fill;
@property (nonatomic, strong) ROSPaint *stroke;
@property (nonatomic) float strokeWidth;
@property (nonatomic) NSInteger lineCap;   ///< 0 butt, 1 round, 2 square
@property (nonatomic) NSInteger lineJoin;  ///< 0 miter, 1 round, 2 bevel
@property (nonatomic) float miterLimit;
@property (nonatomic, copy) NSArray<NSNumber *> *dash;
@property (nonatomic) float dashOffset;
@property (nonatomic) float opacity;
@property (nonatomic) NSInteger blend;  ///< roados::BlendMode order, 0 = source-over
@property (nonatomic) CGAffineTransform transform;
@end

/// Hazard composition options. Field meanings match roados::binding::HazardSpec.
@interface ROSHazardSpec : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *variant;  ///< empty = default
@property (nonatomic) NSInteger severity;       ///< 0 default, 1…5
@property (nonatomic) NSInteger theme;          ///< 0 dark, 1 light
@property (nonatomic) NSInteger representation; ///< 0 auto, 1 standard, 2 roados
@property (nonatomic) NSInteger sizeVariant;    ///< -1 none, 0…3 S/M/L/XL
@property (nonatomic) NSInteger count;
@property (nonatomic) NSInteger speedKind;      ///< -1 none, 0 posted, 1 advisory, 2 unknown
@property (nonatomic) double speedKmh;          ///< < 0 = no value
@property (nonatomic) NSInteger speedUnit;      ///< 0 km/h, 1 mph
@property (nonatomic) double distanceMeters;    ///< < 0 = none
@property (nonatomic) NSInteger unitSystem;     ///< 0 metric, 1 imperial
@property (nonatomic) NSInteger direction;      ///< -1 none, 0 left, 1 ahead, 2 right, 3 both
@property (nonatomic) NSInteger laneCount;
@property (nonatomic) NSInteger laneIndex;
@property (nonatomic) BOOL showSeverityCode;
@property (nonatomic) BOOL hasBackground;
@property (nonatomic) uint32_t backgroundARGB;
@property (nonatomic, copy) NSArray<NSNumber *> *layers;  ///< empty = default order
@property (nonatomic) NSInteger width;
@property (nonatomic) NSInteger height;
@end

@interface ROSFamily : NSObject
@property (nonatomic, readonly, copy) NSString *identifier;
@property (nonatomic, readonly, copy) NSString *code;
@property (nonatomic, readonly, copy) NSString *label;
@property (nonatomic, readonly, copy) NSString *section;
@property (nonatomic, readonly, copy) NSString *familyDescription;
@end

@interface ROSEntry : NSObject
@property (nonatomic, readonly, copy) NSString *identifier;
@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly, copy) NSString *slug;
@property (nonatomic, readonly, copy) NSString *family;
@property (nonatomic, readonly, copy) NSString *entryDescription;
@property (nonatomic, readonly, copy) NSString *frame;
@property (nonatomic, readonly, copy, nullable) NSString *standardFrame;
@property (nonatomic, readonly, copy) NSArray<NSString *> *variants;
@property (nonatomic, readonly, copy, nullable) NSString *defaultVariant;
@property (nonatomic, readonly) NSInteger defaultSeverity;
@property (nonatomic, readonly, copy) NSString *glyph;
@property (nonatomic, readonly, copy) NSString *speedAdvisory;
@property (nonatomic, readonly, copy) NSArray<NSString *> *tags;
@end

/// Immutable, thread-safe RVHL catalogue (cached per path by the core).
@interface ROSLibrary : NSObject
+ (nullable instancetype)libraryWithPath:(NSString *)path error:(NSError **)error;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, copy) NSString *rvhlVersion;
@property (nonatomic, readonly, copy) NSString *studioCommit;
@property (nonatomic, readonly, copy) NSArray<ROSEntry *> *entries;
@property (nonatomic, readonly, copy) NSArray<ROSFamily *> *families;
- (nullable ROSEntry *)entryForKey:(NSString *)idOrSlug;
/// Like entryForKey:, with an error naming candidate IDs (e.g. for "pothole").
- (nullable ROSEntry *)lookupEntry:(NSString *)idOrSlug error:(NSError **)error;
- (nullable NSString *)svgForHazard:(ROSHazardSpec *)spec error:(NSError **)error;
- (nullable CGImageRef)renderHazard:(ROSHazardSpec *)spec scale:(CGFloat)scale error:(NSError **)error CF_RETURNS_RETAINED;
@end

/// Scene builder. Not thread-safe while building; -copy returns an independent
/// snapshot that can be rendered on another thread.
@interface ROSScene : NSObject <NSCopying>
- (instancetype)initWithWidth:(NSInteger)width height:(NSInteger)height NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly) NSInteger width;
@property (nonatomic, readonly) NSInteger height;
@property (nonatomic, readonly) NSInteger groupDepth;
- (void)setBackgroundARGB:(uint32_t)argb;

- (BOOL)addCircleX:(float)cx y:(float)cy radius:(float)r style:(ROSStyle *)style error:(NSError **)error;
- (BOOL)addEllipseX:(float)cx y:(float)cy radiusX:(float)rx radiusY:(float)ry style:(ROSStyle *)style error:(NSError **)error;
- (BOOL)addRectX:(float)x y:(float)y width:(float)w height:(float)h radiusX:(float)rx radiusY:(float)ry
           style:(ROSStyle *)style error:(NSError **)error;
- (BOOL)addLineX1:(float)x1 y1:(float)y1 x2:(float)x2 y2:(float)y2 style:(ROSStyle *)style error:(NSError **)error;
/// points = x0, y0, x1, y1, …
- (BOOL)addPolyPoints:(NSArray<NSNumber *> *)points closed:(BOOL)closed style:(ROSStyle *)style error:(NSError **)error;
- (BOOL)addPathData:(NSString *)svgPathData evenOdd:(BOOL)evenOdd style:(ROSStyle *)style error:(NSError **)error;
- (BOOL)addText:(NSString *)text x:(float)x y:(float)y fontFamilies:(NSString *)families size:(float)size
         weight:(NSInteger)weight italic:(BOOL)italic anchor:(NSInteger)anchor baseline:(NSInteger)baseline
          style:(ROSStyle *)style error:(NSError **)error;
- (BOOL)addSVG:(NSString *)markup x:(float)x y:(float)y width:(float)w height:(float)h style:(ROSStyle *)style
         error:(NSError **)error;
- (BOOL)addImage:(CGImageRef)image x:(float)x y:(float)y width:(float)w height:(float)h style:(ROSStyle *)style
           error:(NSError **)error;
- (BOOL)addHazard:(ROSHazardSpec *)spec library:(ROSLibrary *)library x:(float)x y:(float)y width:(float)w
           height:(float)h error:(NSError **)error;
- (BOOL)beginGroupTransform:(CGAffineTransform)transform opacity:(float)opacity clip:(BOOL)clip clipRect:(CGRect)clipRect
                      error:(NSError **)error;
- (BOOL)endGroupWithError:(NSError **)error;
- (void)clear;

- (nullable CGImageRef)renderWithScale:(CGFloat)scale error:(NSError **)error CF_RETURNS_RETAINED;
- (nullable NSString *)svgWithError:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
