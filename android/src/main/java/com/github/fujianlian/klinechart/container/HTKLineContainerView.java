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
        int reloadIndex = configManager.shouldReloadDrawItemIndex;
        switch (reloadIndex) {
            case HTDrawState.none: {
                return false;
            }
            case HTDrawState.showPencil: {
                if (configManager.drawType == HTDrawType.none) {
                    HTPoint location = new HTPoint(event.getX(), event.getY());
                    location = convertLocation(location);
                    if ((HTDrawItem.canResponseLocation(klineView.drawContext.drawItemList, location, klineView)) == null) {
                        return false;
                    }
                }
            }
        }
        return true;
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
