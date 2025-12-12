#import "RCTViewManager.h"


@interface RCT_EXTERN_MODULE(RNKLineView, RCTViewManager)

RCT_EXPORT_VIEW_PROPERTY(onDrawItemDidTouch, RCTBubblingEventBlock)

RCT_EXPORT_VIEW_PROPERTY(onNewOrder, RCTBubblingEventBlock)

RCT_EXPORT_VIEW_PROPERTY(onDrawItemComplete, RCTBubblingEventBlock)

RCT_EXPORT_VIEW_PROPERTY(onDrawItemMove, RCTBubblingEventBlock)

RCT_EXPORT_VIEW_PROPERTY(onDrawPointComplete, RCTBubblingEventBlock)

RCT_EXPORT_VIEW_PROPERTY(onEndReached, RCTBubblingEventBlock)

RCT_EXPORT_VIEW_PROPERTY(optionList, NSString)

// Data-only payload: JSON string of the candle array.
// This lets iOS mirror the Android `modelArray` prop and keeps
// indicators (MA / BOLL / MACD / RSI / WR, etc.) in sync with the
// latest data without re-sending the whole optionList.
RCT_EXPORT_VIEW_PROPERTY(modelArray, NSString)

@end

