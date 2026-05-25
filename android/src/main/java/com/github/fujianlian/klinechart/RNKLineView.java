package com.github.fujianlian.klinechart;

import android.animation.ValueAnimator;
import android.graphics.Color;
import android.os.Build;
import android.view.View;
import android.view.animation.DecelerateInterpolator;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.common.MapBuilder;
import com.facebook.react.uimanager.SimpleViewManager;
import com.facebook.react.uimanager.ThemedReactContext;
import com.facebook.react.uimanager.annotations.ReactProp;
import com.github.fujianlian.klinechart.container.HTKLineContainerView;
import com.github.fujianlian.klinechart.draw.PrimaryStatus;
import com.github.fujianlian.klinechart.draw.SecondStatus;
import com.github.fujianlian.klinechart.formatter.DateFormatter;
import com.github.fujianlian.klinechart.formatter.ValueFormatter;

import javax.annotation.Nonnull;
import javax.annotation.Nullable;
import java.text.SimpleDateFormat;
import java.util.*;
import com.alibaba.fastjson.JSON;
import com.alibaba.fastjson.parser.Feature;

public class RNKLineView extends SimpleViewManager<HTKLineContainerView> {

	public static String onDrawItemDidTouchKey = "onDrawItemDidTouch";

	public static String onDrawItemCompleteKey = "onDrawItemComplete";

    public static String onDrawItemMoveKey = "onDrawItemMove";

	public static String onDrawPointCompleteKey = "onDrawPointComplete";

    // Fired when user scrolls to the left edge (older candles requested)
    public static String onEndReachedKey = "onEndReached";

    // Fired when the user taps the hover price pill (long-press selector)
    public static String onNewOrderKey = "onNewOrder";

    @Nonnull
    @Override
    public String getName() {
        return "RNKLineView";
    }

    @Nonnull
    @Override
    protected HTKLineContainerView createViewInstance(@Nonnull ThemedReactContext reactContext) {
    	HTKLineContainerView containerView = new HTKLineContainerView(reactContext);
    	return containerView;
    }

	@Override
	public Map getExportedCustomDirectEventTypeConstants() {
        MapBuilder.Builder builder = MapBuilder.builder();
        builder.put(onDrawItemDidTouchKey, MapBuilder.of("registrationName", onDrawItemDidTouchKey));
        builder.put(onDrawItemCompleteKey, MapBuilder.of("registrationName", onDrawItemCompleteKey));
        builder.put(onDrawPointCompleteKey, MapBuilder.of("registrationName", onDrawPointCompleteKey));
        builder.put(onEndReachedKey, MapBuilder.of("registrationName", onEndReachedKey));
        builder.put(onDrawItemMoveKey, MapBuilder.of("registrationName", onDrawItemMoveKey));
        builder.put(onNewOrderKey, MapBuilder.of("registrationName", onNewOrderKey));
        return builder.build();
	}

    // Expose imperative commands so JS can control the loading lifecycle (e.g. unlock scroll
    // after older candles have been loaded).
    @Override
    public Map<String, Integer> getCommandsMap() {
        return MapBuilder.of(
                "refreshComplete", 1
        );
    }

    @Override
    public void receiveCommand(@Nonnull HTKLineContainerView root, int commandId, @Nullable ReadableArray args) {
        switch (commandId) {
            case 1:
                // Finish the "load more" state and re-enable scrolling/zooming.
                if (root.klineView != null) {
                    root.klineView.refreshComplete();
                }
                root.configManager.loadingMoreFromLeft = false;
                break;
            default:
                break;
        }
    }
    @ReactProp(name = "optionList")
    public void setOptionList(final HTKLineContainerView containerView, String optionList) {
        if (optionList == null) {
            return;
        }
        
        new Thread(new Runnable() {
            @Override
            public void run() {
                int disableDecimalFeature = JSON.DEFAULT_PARSER_FEATURE & ~Feature.UseBigDecimal.getMask();
                Map optionMap = (Map)JSON.parse(optionList, disableDecimalFeature);
                containerView.configManager.reloadOptionList(optionMap);
                containerView.post(new Runnable() {
                    @Override
                    public void run() {
                        containerView.reloadConfigManager();
                    }
                });
            }
        }).start();
    }

    /**
     * Lightweight data-only update: replace modelArray without reloading full optionList.
     * Accepts the same modelArray JSON you normally embed inside optionList.
     */
    @ReactProp(name = "modelArray")
    public void setModelArray(final HTKLineContainerView containerView, String modelArrayJson) {
        if (modelArrayJson == null) {
            return;
        }

        new Thread(new Runnable() {
            @Override
            public void run() {
                int disableDecimalFeature = JSON.DEFAULT_PARSER_FEATURE & ~Feature.UseBigDecimal.getMask();
                Object parsed = JSON.parse(modelArrayJson, disableDecimalFeature);
                if (!(parsed instanceof List)) {
                    return;
                }
                List modelArray = (List) parsed;

                // Pack on background thread but do NOT assign to configManager yet —
                // assigning here would let onDraw see new data before mItemCount/mScrollX
                // are updated, causing a visible scroll jump.
                final List<KLineEntity> packedList =
                        containerView.configManager.packModelList(modelArray);
                containerView.post(new Runnable() {
                    @Override
                    public void run() {
                        // Atomically assign data + adjust scroll on the UI thread.
                        int oldScrollOffset = containerView.klineView.getScrollOffset();
                        int oldMaxScrollX = containerView.klineView.getMaxScrollX();
                        boolean wasAtEnd = oldScrollOffset >= oldMaxScrollX;

                        // Detect prepend by finding where the current first candle
                        // appears in the new data. This is robust against intermediate
                        // live-tick updates that would corrupt a count-based comparison.
                        int prependedCount = 0;
                        boolean loadingMoreFromLeft = containerView.configManager.loadingMoreFromLeft;
                        if (loadingMoreFromLeft) {
                            List<KLineEntity> currentArray = containerView.configManager.modelArray;
                            if (currentArray != null && !currentArray.isEmpty() && !packedList.isEmpty()) {
                                double oldFirstId = currentArray.get(0).id;
                                boolean found = false;
                                for (int i = 0; i < packedList.size(); i++) {
                                    if (packedList.get(i).id == oldFirstId) {
                                        prependedCount = i;
                                        found = true;
                                        break;
                                    }
                                }
                                if (!found) {
                                    // Data replaced entirely (e.g. timeframe switch) — reset flag
                                    containerView.configManager.loadingMoreFromLeft = false;
                                }
                            }
                        }

                        // Assign the new data right before notifyChanged so both happen
                        // in the same UI frame — no stale-data draw in between.
                        containerView.configManager.modelArray = packedList;

                        if (prependedCount > 0) {
                            int shiftPx = Math.round(prependedCount * containerView.configManager.itemWidth);
                            int targetScrollX = oldScrollOffset + shiftPx;
                            containerView.klineView.notifyChanged();
                            containerView.klineView.setScrollX(targetScrollX);
                            containerView.configManager.loadingMoreFromLeft = false;
                        } else {
                            containerView.klineView.notifyChanged();
                            if (wasAtEnd) {
                                containerView.klineView.setScrollX(containerView.klineView.getMaxScrollX());
                            }
                            // Don't reset loadingMoreFromLeft for live ticks —
                            // the flag stays active until the actual prepend arrives.
                        }
                    }
                });
            }
        }).start();
    }

}
