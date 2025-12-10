package com.github.fujianlian.klinechart;

import android.graphics.Color;
import android.os.Build;
import android.view.View;
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
                // Reuse existing packModelList logic
                containerView.configManager.modelArray =
                        containerView.configManager.packModelList(modelArray);
                containerView.post(new Runnable() {
                    @Override
                    public void run() {
                        // Only notify data change, keep config/drawings as-is.
                        // If the user was previously at the right edge (latest candle),
                        // keep them "stuck" to the end; otherwise preserve their current
                        // scroll offset so loading older candles at the left does not
                        // snap them back to the newest data.
                        boolean wasAtEnd = containerView.klineView.getScrollOffset() >= containerView.klineView.getMaxScrollX();
                        containerView.klineView.notifyChanged();
                        if (wasAtEnd) {
                            containerView.klineView.setScrollX(containerView.klineView.getMaxScrollX());
                        }
                    }
                });
            }
        }).start();
    }

}
