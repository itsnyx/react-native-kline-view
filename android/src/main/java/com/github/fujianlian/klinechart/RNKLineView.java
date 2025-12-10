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
     * Control the native refresh lifecycle from JS.
     *
     * When the user scrolls to the left edge, Android calls onEndReached and
     * enters a "refreshing" state where scrolling is locked. Once your JS side
     * has finished loading and prepending older candles, set `refreshing={false}`
     * on RNKLineView to call refreshComplete() and unlock scrolling again.
     *
     * Example:
     * <RNKLineView
     *   ...
     *   refreshing={this.state.loadingMore}
     *   onEndReached={() => {
     *     this.setState({ loadingMore: true });
     *     loadMore().finally(() => this.setState({ loadingMore: false }));
     *   }}
     * />
     */
    @ReactProp(name = "refreshing")
    public void setRefreshing(final HTKLineContainerView containerView, boolean refreshing) {
        if (!refreshing) {
            containerView.klineView.refreshComplete();
        }
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
                        // Only notify data change, keep config/drawings as-is
                        boolean isEnd = containerView.klineView.getScrollOffset() >= containerView.klineView.getMaxScrollX();
                        containerView.klineView.notifyChanged();
                        if (isEnd || containerView.configManager.shouldScrollToEnd) {
                            containerView.klineView.setScrollX(containerView.klineView.getMaxScrollX());
                        }
                    }
                });
            }
        }).start();
    }

}
