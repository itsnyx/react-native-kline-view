package com.github.fujianlian.klinechart.container;


import android.view.MotionEvent;
import android.view.ViewGroup;
import android.widget.RelativeLayout;
import android.widget.ScrollView;
import com.facebook.react.bridge.*;
import com.facebook.react.uimanager.ThemedReactContext;
import com.facebook.react.uimanager.events.RCTEventEmitter;
import com.github.fujianlian.klinechart.HTKLineConfigManager;
import com.github.fujianlian.klinechart.KLineChartView;
import com.github.fujianlian.klinechart.RNKLineView;
import com.github.fujianlian.klinechart.formatter.DateFormatter;
import java.util.List;
import java.util.Map;


public class HTKLineContainerView extends RelativeLayout {

    private ThemedReactContext reactContext;

    public HTKLineConfigManager configManager = new HTKLineConfigManager();

    public KLineChartView klineView;

    public HTShotView shotView;

    public HTKLineContainerView(ThemedReactContext context) {
        super(context);
        this.reactContext = context;
        klineView = new KLineChartView(getContext(), configManager);
        klineView.setGridColumns(5);
        klineView.setGridRows(3);
        klineView.setChildDraw(0);
        klineView.setDateTimeFormatter(new DateFormatter());
        klineView.configManager = configManager;
        // When scrolling to the left edge, request more historical candles from JS
        klineView.setRefreshListener(new KLineChartView.KChartRefreshListener() {
            @Override
            public void onLoadMoreBegin(KLineChartView chart) {
                int id = HTKLineContainerView.this.getId();
                reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(
                        id,
                        RNKLineView.onEndReachedKey,
                        Arguments.createMap()
                );
                // Immediately end loading state so scrolling isn't locked
                chart.refreshComplete();
            }
        });
        addView(klineView, new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT));
    }

    @Override
    protected void onAttachedToWindow() {
        super.onAttachedToWindow();
        ViewGroup willShotView = (ViewGroup)getParent();
        if (shotView == null) {
            shotView = new HTShotView(getContext(), willShotView);
            shotView.setEnabled(false);
            shotView.dimension = 300;
            RelativeLayout.LayoutParams layoutParams = new RelativeLayout.LayoutParams(shotView.dimension, shotView.dimension);
            layoutParams.setMargins(50, 50, 0, 0);
            ((ViewGroup)willShotView.getParent().getParent()).addView(shotView, layoutParams);
        }
    }

    public void reloadConfigManager() {
        klineView.changeMainDrawType(klineView.configManager.primaryStatus);
        klineView.changeSecondDrawType(klineView.configManager.secondStatus);
        klineView.setMainDrawLine(klineView.configManager.isMinute);
        klineView.setPointWidth(klineView.configManager.itemWidth);
        klineView.setCandleWidth(klineView.configManager.candleWidth);

        if (klineView.configManager.fontFamily.length() > 0) {
            klineView.setTextFontFamily(klineView.configManager.fontFamily);
        }
        klineView.setTextColor(klineView.configManager.textColor);
        klineView.setTextSize(klineView.configManager.rightTextFontSize);
        klineView.setMTextSize(klineView.configManager.candleTextFontSize);
        klineView.setMTextColor(klineView.configManager.candleTextColor);
        klineView.reloadColor();
        Boolean isEnd = klineView.getScrollOffset() >= klineView.getMaxScrollX();
        klineView.notifyChanged();
        if (isEnd || klineView.configManager.shouldScrollToEnd) {
            klineView.setScrollX(klineView.getMaxScrollX());
        }

        final int id = this.getId();
        configManager.onDrawItemDidTouch = new Callback() {
            @Override
            public void invoke(Object... args) {
                HTDrawItem drawItem = (HTDrawItem) args[0];
                int drawItemIndex = (int) args[1];
                configManager.shouldReloadDrawItemIndex = drawItemIndex;

                WritableMap map = Arguments.createMap();
                if (drawItem != null) {
                    int drawColor = drawItem.drawColor;
                    int alpha = (drawColor >> 24) & 0xFF;
                    int red = (drawColor >> 16) & 0xFF;
                    int green = (drawColor >> 8) & 0xFF;
                    int blue = (drawColor) & 0xFF;
                    WritableArray colorList = Arguments.createArray();

                    colorList.pushDouble(red / 255.0);
                    colorList.pushDouble(green / 255.0);
                    colorList.pushDouble(blue / 255.0);
                    colorList.pushDouble(alpha / 255.0);

                    map.putArray("drawColor", colorList);
                    map.putDouble("drawLineHeight", drawItem.drawLineHeight);
                    map.putDouble("drawDashWidth", drawItem.drawDashWidth);
                    map.putDouble("drawDashSpace", drawItem.drawDashSpace);
                    map.putBoolean("drawIsLock", drawItem.drawIsLock);
                }
                // Expose the index of the touched drawing item to React Native.
                map.putInt("index", drawItemIndex);
                map.putInt("shouldReloadDrawItemIndex", drawItemIndex);
                reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(
                        id,
                        RNKLineView.onDrawItemDidTouchKey,
                        map
                );
            }
        };
        configManager.onDrawItemComplete = new Callback() {
            @Override
            public void invoke(Object... args) {
                HTDrawItem drawItem = null;
                int drawItemIndex = -1;
                if (args != null && args.length >= 2) {
                    try {
                        drawItem = (HTDrawItem) args[0];
                        drawItemIndex = (int) args[1];
                    } catch (ClassCastException ignored) {
                    }
                }

                WritableMap map = Arguments.createMap();
                if (drawItem != null) {
                    map.putInt("index", drawItemIndex);
                    map.putInt("drawType", drawItem.drawType.rawValue());
                    map.putInt("drawColor", drawItem.drawColor);
                    map.putDouble("drawLineHeight", drawItem.drawLineHeight);
                    map.putDouble("drawDashWidth", drawItem.drawDashWidth);
                    map.putDouble("drawDashSpace", drawItem.drawDashSpace);
                    map.putBoolean("drawIsLock", drawItem.drawIsLock);
                    map.putString("text", drawItem.text);
                    map.putInt("textColor", drawItem.textColor);
                    map.putInt("textBackgroundColor", drawItem.textBackgroundColor);
                    map.putDouble("textCornerRadius", drawItem.textCornerRadius);
                    // Expose per-item text font size (falls back to candleTextFontSize when 0 on native).
                    map.putDouble("fontSize",
                            drawItem.textFontSize > 0 ? drawItem.textFontSize : configManager.candleTextFontSize);

                    WritableArray pointArray = Arguments.createArray();
                    for (HTPoint point : drawItem.pointList) {
                        WritableMap pointMap = Arguments.createMap();
                        pointMap.putDouble("x", point.x);
                        pointMap.putDouble("y", point.y);
                        pointArray.pushMap(pointMap);
                    }
                    map.putArray("pointList", pointArray);
                }
                reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(
                        id,
                        RNKLineView.onDrawItemCompleteKey,
                        map
                );
            }
        };
        configManager.onDrawItemMove = new Callback() {
            @Override
            public void invoke(Object... args) {
                HTDrawItem drawItem = null;
                int drawItemIndex = -1;
                if (args != null && args.length >= 2) {
                    try {
                        drawItem = (HTDrawItem) args[0];
                        drawItemIndex = (int) args[1];
                    } catch (ClassCastException ignored) {
                    }
                }

                if (drawItem == null) {
                    return;
                }

                WritableMap map = Arguments.createMap();
                map.putInt("index", drawItemIndex);
                map.putInt("drawType", drawItem.drawType.rawValue());
                map.putString("text", drawItem.text);

                WritableArray pointArray = Arguments.createArray();
                for (HTPoint point : drawItem.pointList) {
                    WritableMap pointMap = Arguments.createMap();
                    pointMap.putDouble("x", point.x);
                    pointMap.putDouble("y", point.y);
                    pointArray.pushMap(pointMap);
                }
                map.putArray("pointList", pointArray);

                reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(
                        id,
                        RNKLineView.onDrawItemMoveKey,
                        map
                );
            }
        };
        configManager.onDrawPointComplete = new Callback() {
            @Override
            public void invoke(Object... args) {
                HTDrawItem drawItem = (HTDrawItem) args[0];
                WritableMap map = Arguments.createMap();
                map.putInt("pointCount", drawItem.pointList.size());
                reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(
                        id,
                        RNKLineView.onDrawPointCompleteKey,
                        map
                );
            }
        };

        int reloadIndex = configManager.shouldReloadDrawItemIndex;
        if (reloadIndex >= 0 && reloadIndex < klineView.drawContext.drawItemList.size()) {
            HTDrawItem drawItem = klineView.drawContext.drawItemList.get(reloadIndex);
            drawItem.drawColor = configManager.drawColor;
            drawItem.drawLineHeight = configManager.drawLineHeight;
            drawItem.drawDashWidth = configManager.drawDashWidth;
            drawItem.drawDashSpace = configManager.drawDashSpace;
            drawItem.drawIsLock = configManager.drawIsLock;
            if (configManager.drawShouldTrash) {
                configManager.shouldReloadDrawItemIndex = HTDrawState.showPencil;
                klineView.drawContext.drawItemList.remove(reloadIndex);
                configManager.drawShouldTrash = false;
            }
            klineView.drawContext.invalidate();
        }


        if (configManager.shouldFixDraw) {
            configManager.shouldFixDraw = false;
            klineView.drawContext.fixDrawItemList();
        }
        if (configManager.shouldClearDraw) {
            configManager.shouldReloadDrawItemIndex = HTDrawState.none;
            configManager.shouldClearDraw = false;
            klineView.drawContext.clearDrawItemList();
        }

        // If a serialized drawing list was provided from React Native,
        // rebuild the native drawItemList from it (pre-insert drawings).
        if (configManager.drawItemList != null) {
            klineView.drawContext.clearDrawItemList();
            for (Object itemObject : configManager.drawItemList) {
                if (!(itemObject instanceof Map)) {
                    continue;
                }
                Map itemMap = (Map) itemObject;
                Object pointListObject = itemMap.get("pointList");
                if (!(pointListObject instanceof List)) {
                    continue;
                }
                List pointList = (List) pointListObject;
                if (pointList.size() == 0) {
                    continue;
                }

                // Draw type
                int rawType = 0;
                Object drawTypeObject = itemMap.get("drawType");
                if (drawTypeObject instanceof Number) {
                    rawType = ((Number) drawTypeObject).intValue();
                }
                HTDrawType drawType = HTDrawType.drawTypeFromRawValue(rawType);

                // First point (required)
                Object firstPointObject = pointList.get(0);
                if (!(firstPointObject instanceof Map)) {
                    continue;
                }
                Map firstPointMap = (Map) firstPointObject;
                Object xObject = firstPointMap.get("x");
                Object yObject = firstPointMap.get("y");
                if (!(xObject instanceof Number) || !(yObject instanceof Number)) {
                    continue;
                }
                HTPoint startPoint = new HTPoint(
                        ((Number) xObject).floatValue(),
                        ((Number) yObject).floatValue()
                );

                HTDrawItem drawItem = new HTDrawItem(drawType, startPoint);

                // Remaining points (optional)
                for (int i = 1; i < pointList.size(); i++) {
                    Object pointObject = pointList.get(i);
                    if (!(pointObject instanceof Map)) {
                        continue;
                    }
                    Map pointMap = (Map) pointObject;
                    Object pxObject = pointMap.get("x");
                    Object pyObject = pointMap.get("y");
                    if (!(pxObject instanceof Number) || !(pyObject instanceof Number)) {
                        continue;
                    }
                    drawItem.pointList.add(new HTPoint(
                            ((Number) pxObject).floatValue(),
                            ((Number) pyObject).floatValue()
                    ));
                }

                // Style properties: fall back to global drawList config when not provided
                Object colorObject = itemMap.get("drawColor");
                if (colorObject instanceof Number) {
                    drawItem.drawColor = ((Number) colorObject).intValue();
                } else {
                    drawItem.drawColor = configManager.drawColor;
                }
                Object lineHeightObject = itemMap.get("drawLineHeight");
                if (lineHeightObject instanceof Number) {
                    drawItem.drawLineHeight = ((Number) lineHeightObject).floatValue();
                } else {
                    drawItem.drawLineHeight = configManager.drawLineHeight;
                }
                Object dashWidthObject = itemMap.get("drawDashWidth");
                if (dashWidthObject instanceof Number) {
                    drawItem.drawDashWidth = ((Number) dashWidthObject).floatValue();
                } else {
                    drawItem.drawDashWidth = configManager.drawDashWidth;
                }
                Object dashSpaceObject = itemMap.get("drawDashSpace");
                if (dashSpaceObject instanceof Number) {
                    drawItem.drawDashSpace = ((Number) dashSpaceObject).floatValue();
                } else {
                    drawItem.drawDashSpace = configManager.drawDashSpace;
                }
                Object isLockObject = itemMap.get("drawIsLock");
                if (isLockObject instanceof Boolean) {
                    drawItem.drawIsLock = (Boolean) isLockObject;
                } else {
                    drawItem.drawIsLock = configManager.drawIsLock;
                }

                Object textObject = itemMap.get("text");
                if (textObject instanceof String) {
                    drawItem.text = (String) textObject;
                }

                Object textColorObject = itemMap.get("textColor");
                if (textColorObject instanceof Number) {
                    drawItem.textColor = ((Number) textColorObject).intValue();
                } else {
                    drawItem.textColor = configManager.drawTextColor;
                }
                Object textBackgroundColorObject = itemMap.get("textBackgroundColor");
                if (textBackgroundColorObject instanceof Number) {
                    drawItem.textBackgroundColor = ((Number) textBackgroundColorObject).intValue();
                } else {
                    drawItem.textBackgroundColor = configManager.drawTextBackgroundColor;
                }
                Object textCornerRadiusObject = itemMap.get("textCornerRadius");
                if (textCornerRadiusObject instanceof Number) {
                    drawItem.textCornerRadius = ((Number) textCornerRadiusObject).floatValue();
                } else {
                    drawItem.textCornerRadius = configManager.drawTextCornerRadius;
                }
                // Optional per-item font size for text annotations
                Object fontSizeObject = itemMap.get("fontSize");
                if (fontSizeObject instanceof Number) {
                    drawItem.textFontSize = ((Number) fontSizeObject).floatValue();
                } else {
                    drawItem.textFontSize = configManager.candleTextFontSize;
                }

                klineView.drawContext.drawItemList.add(drawItem);
            }
            klineView.drawContext.invalidate();
        }

    }

    private HTPoint convertLocation(HTPoint location) {
        HTPoint reloadLocation = new HTPoint(location.x, location.y);
        reloadLocation.x = Math.max(0, Math.min(reloadLocation.x, getWidth()));
        reloadLocation.y = Math.max(0, Math.min(reloadLocation.y, getHeight()));
//        reloadLocation.x += klineView.getScrollOffset();
        reloadLocation = klineView.valuePointFromViewPoint(reloadLocation);
        return reloadLocation;
    }


    @Override
    public boolean onInterceptTouchEvent(MotionEvent event) {
        int action = event.getActionMasked();

        // When no drawing UI is active, always let KLineChartView handle touch events
        // so that normal scrolling and zooming work as expected.
        if (configManager.shouldReloadDrawItemIndex == HTDrawState.none) {
            return false;
        }

        // If we are actively creating a drawing (line / rect / etc.), intercept all events
        // so the chart itself doesn't scroll while the user is drawing.
        if (configManager.drawType != HTDrawType.none) {
            return true;
        }

        // In "show" / manage-drawings mode (JS may pass drawType = -1 which maps to none
        // on native), we want the user to be able to scroll the chart freely and only
        // intercept gestures that actually hit an existing drawing.
        HTPoint location = new HTPoint(event.getX(), event.getY());
        location = convertLocation(location);
        boolean hitExisting =
                HTDrawItem.canResponseLocation(klineView.drawContext.drawItemList, location, klineView) != null;

        switch (action) {
            case MotionEvent.ACTION_DOWN:
                // Start handling the gesture only if the user touched a drawing item.
                return hitExisting;
            case MotionEvent.ACTION_MOVE:
            case MotionEvent.ACTION_UP:
            case MotionEvent.ACTION_CANCEL:
                // For move/up, keep the same routing decision as for ACTION_DOWN:
                // if the gesture started on a drawing, we keep intercepting; otherwise
                // let KLineChartView continue handling it for scrolling.
                return hitExisting;
            default:
                return false;
        }
    }

    private HTPoint lastLocation;

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        handlerDraw(event);
        handlerShot(event);
        return true;
    }

    private void handlerDraw(MotionEvent event) {
        HTPoint location = new HTPoint(event.getX(), event.getY());
        location = convertLocation(location);
        HTPoint previousLocation = lastLocation != null ? lastLocation : location;
        lastLocation = location;
        int state = event.getAction();
        Boolean isCancel = state == MotionEvent.ACTION_CANCEL;
        if (isCancel) {
            state = MotionEvent.ACTION_UP;
        }
        HTPoint translation = new HTPoint(
                location.x - previousLocation.x,
                location.y - previousLocation.y
        );
        if (event.getAction() == MotionEvent.ACTION_UP || event.getAction() == MotionEvent.ACTION_CANCEL) {
            lastLocation = null;
        }
        klineView.drawContext.touchesGesture(location, translation, state);
    }

    private void handlerShot(MotionEvent event) {
        if (event.getAction() == MotionEvent.ACTION_UP || event.getAction() == MotionEvent.ACTION_CANCEL) {
            shotView.setPoint(null);
            lastLocation = null;
        } else {
            shotView.setPoint(new HTPoint(event.getX(), event.getY()));
        }
    }

}
