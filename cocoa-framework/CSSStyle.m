#import "CSSStyle.h"
#import "CSSStylesheet.h"
#import "CSSContext.h"
#import "CSSSelectHandlerBase.h"
#import "NSColor-css.h"

#import "internal.h"

static CGFloat _UIScaleFactor() {
  // maybe move this somewhere so we don't call it _every time_?
  CGFloat sf = 1.0;
  NSScreen *screen = [NSScreen mainScreen];
  if (screen) sf = [screen userSpaceScaleFactor];
  return sf;
}


@implementation CSSStyle

@synthesize style = style_;


+ (CSSStyle*)selectStyleForObject:(void*)object
                        inContext:(CSSContext*)context
                    pseudoElement:(int)pseudoElement
                            media:(css_media_type)mediaTypes
                      inlineStyle:(CSSStylesheet*)inlineStyle
                     usingHandler:(css_select_handler*)handler {
  CSSStyle *style = [[self alloc] init];
  /**
   * css_select_style -- select a style for the given node
   *
   * \param ctx             Selection context to use
   * \param node            Node to select style for
   * \param pseudo_element  Pseudo element to select for, instead
   * \param media           Currently active media types
   * \param inline_style    Corresponding inline style for node, or NULL
   * \param result          Pointer to style to populate (assumed clean)
   * \param handler         Dispatch table of handler functions
   * \param pw              Client-specific private data for handler functions
   * \return CSS_OK on success, appropriate error otherwise.
   *
   * In computing the style, no reference is made to the parent node's
   * style. Therefore, the resultant computed style is not ready for
   * immediate use, as some properties may be marked as inherited.
   * Use css_computed_style_compose() to obtain a fully computed style.
   *
   * This two-step approach to style computation is designed to allow
   * the client to store the partially computed style and efficiently
   * update the fully computed style for a node when layout changes.
   */
  NSException *e =
      CSSCheck2(css_select_style(context.ctx, object, pseudoElement, mediaTypes, 
          (inlineStyle ? inlineStyle.sheet : NULL), style->style_, handler,
          style));
  if (e) {
    [style release];
    style = nil;
    [e raise];
  }
  return style;
}


- (id)init {
  if (!(self = [super init])) return nil;
  NSException *e =
      CSSCheck2(css_computed_style_create(&css_cf_realloc, 0, &style_));
	if (e) {
    [self release];
    [e raise];
    return nil;
  }
  return self;
}


- (void)dealloc {
  css_computed_style_destroy(style_);
  [super dealloc];
}


- (CSSStyle*)mergeWith:(CSSStyle*)child {
  CSSStyle *mergedStyle = [[isa alloc] init];
  NSException *e = CSSCheck2(css_computed_style_compose(self.style, child.style,
		CSSSelectHandlerBase.compute_font_size, self, mergedStyle.style));
  if (e) {
    [mergedStyle release];
    mergedStyle = nil;
    [e raise];
  }
  return [mergedStyle autorelease];
}


#pragma mark -
#pragma mark Style properties


// Color
#define SYNTHESIZE_COLOR(name, fun_suffix) - (NSColor*)name { \
  css_color rgba; \
  uint8_t type = css_computed_##fun_suffix(style_, &rgba); \
  if (type == CSS_COLOR_INHERIT) return nil; \
  else return [NSColor colorWithCSSColor:rgba]; \
}

SYNTHESIZE_COLOR(color, color)
SYNTHESIZE_COLOR(backgroundColor, background_color)
SYNTHESIZE_COLOR(outlineColor, outline_color)
SYNTHESIZE_COLOR(borderTopColor, border_top_color)
SYNTHESIZE_COLOR(borderRightColor, border_right_color)
SYNTHESIZE_COLOR(borderBottomColor, border_bottom_color)
SYNTHESIZE_COLOR(borderLeftColor, border_left_color)


// Font

- (int)fontWeight { return css_computed_font_weight(style_); }
- (int)fontStyle { return css_computed_font_style(style_); }
- (int)fontVariant { return css_computed_font_variant(style_); }


static CGFloat CSSDimensionToFontPoints(css_unit unit, css_fixed value) {
  //NSDictionary *deviceDescription = [[NSScreen mainScreen] deviceDescription];
  //NSValue *someValue = [deviceDescription objectForKey:NSDeviceResolution];
  //CGFloat resolution = [someValue sizeValue].height;
  // "describes the window’s raster resolution in dots per inch (dpi)."
  
  // em and ex whould have been computed into "absolute" units already
  assert(unit != CSS_UNIT_EM);
  assert(unit != CSS_UNIT_EX);
  
	switch (unit) {
	case CSS_UNIT_PX:
		return FIXTOFLT(value);;
		break;
	case CSS_UNIT_IN:
		// TODO: in
		break;
	case CSS_UNIT_CM:
		// TODO: cm
		break;
	case CSS_UNIT_MM:
		// TODO: mm
		break;
	case CSS_UNIT_PT:
		return FIXTOFLT(value);
		break;
	case CSS_UNIT_PC:
		// TODO: pc
		break;
	case CSS_UNIT_PCT:
		// TODO: %
		break;
	case CSS_UNIT_DEG:
		// TODO: deg
		break;
	case CSS_UNIT_GRAD:
		// TODO: grad
		break;
	case CSS_UNIT_RAD:
		// TODO: rad
		break;
	case CSS_UNIT_MS:
		// TODO: ms
		break;
	case CSS_UNIT_S:
		// TODO: s
		break;
	case CSS_UNIT_HZ:
		// TODO: Hz
		break;
	case CSS_UNIT_KHZ:
		// TODO: kHz
		break;
	}
  return FIXTOFLT(value); // FIXME
}


- (CGFloat)fontSize {
  css_fixed value;
  css_unit unit;
  uint8_t type = css_computed_font_size(style_, &value, &unit);
  CGFloat points = 0.0;
  if (type == CSS_FONT_SIZE_DIMENSION)
    points = CSSDimensionToFontPoints(unit, value);
  return points;
}

- (NSArray*)fontNames {
  //lwc_string **names style->font_family
  NSMutableArray *names = nil;
  lwc_string **string_list = NULL;
  uint8_t family_class = css_computed_font_family(style_, &string_list);
  if (family_class != CSS_FONT_FAMILY_INHERIT) {
    names = [NSMutableArray array];
		if (string_list != NULL) {
			while (*string_list != NULL) {
        NSString *name = [NSString stringWithLWCString:*(string_list++)];
        [names addObject:name];
			}
		}
    switch (family_class) {
      case CSS_FONT_FAMILY_SERIF: [names addObject:@"serif"]; break;
      case CSS_FONT_FAMILY_SANS_SERIF: [names addObject:@"sans-serif"]; break;
      case CSS_FONT_FAMILY_CURSIVE: [names addObject:@"cursive"]; break;
      case CSS_FONT_FAMILY_FANTASY: [names addObject:@"fantasy"]; break;
      case CSS_FONT_FAMILY_MONOSPACE: [names addObject:@"monospace"]; break;
    }
  }
  return names;
}

@end