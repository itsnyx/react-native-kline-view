package com.github.fujianlian.klinechart;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.util.Base64;

import java.lang.reflect.Array;
import java.lang.reflect.Type;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import android.graphics.Typeface;
import com.facebook.react.bridge.Callback;
import com.github.fujianlian.klinechart.container.HTDrawState;
import com.github.fujianlian.klinechart.container.HTDrawType;
import com.github.fujianlian.klinechart.draw.PrimaryStatus;
import com.github.fujianlian.klinechart.draw.SecondStatus;
import com.github.fujianlian.klinechart.formatter.ValueFormatter;

public class HTKLineConfigManager {

    public List<KLineEntity> modelArray = new ArrayList<>();

	public Boolean shouldScrollToEnd = true;

    /**
     * Internal flag used by Android to know that the last scroll-to-left-edge
     * triggered a "load older candles" flow. When true, the next `modelArray`
     * update is treated as a prepend of older data and horizontal scroll
     * offset is adjusted so the previously visible candles stay in view.
     *
     * This flag is set in `HTKLineContainerView` when `onLoadMoreBegin`
     * fires and cleared after `setModelArray` finishes applying the update.
     */
    public boolean loadingMoreFromLeft = false;


	public int shotBackgroundColor = Color.RED;

	public Boolean drawShouldContinue = false;

	public HTDrawType drawType = HTDrawType.none;

    public int drawState = HTDrawState.none;

	public Boolean shouldFixDraw = false;

	public Boolean shouldClearDraw = false;


    public int drawColor = Color.RED;

    public float drawLineHeight = 1;

    public float drawDashWidth = 1;

    public float drawDashSpace = 1;

    public Boolean drawIsLock = false;

    // Text annotation defaults
    public int drawTextColor = Color.WHITE;

    public int drawTextBackgroundColor = Color.argb(153, 0, 0, 0); // ~60% black

    public float drawTextCornerRadius = 8;

    public int shouldReloadDrawItemIndex = HTDrawState.none;

    public Boolean drawShouldTrash = false;

    public Callback onDrawItemComplete;

    // Fired continuously while a drawing (line/text/etc.) is being moved/dragged.
    // JS can use this to keep its copy of pointList in sync with native.
    public Callback onDrawItemMove;

    public Callback onDrawItemDidTouch;

    public Callback onDrawPointComplete;





	public PrimaryStatus primaryStatus = PrimaryStatus.MA;

	public SecondStatus secondStatus = SecondStatus.MACD;

	public Boolean isMinute = false;

    public int increaseColor = Color.RED;

    public int decreaseColor = Color.GREEN;

    public int minuteLineColor = Color.BLUE;

    public int[] minuteGradientColorList = { Color.BLUE, Color.BLUE };

    public float[] minuteGradientLocationList = { 0, 1 };

    public float paddingTop = 0;

    public float paddingBottom = 0;

    public float paddingRight = 0;

    public float itemWidth = 9;

    public float candleWidth = 7;

    public int minuteVolumeCandleColor = Color.RED;

    public float minuteVolumeCandleWidth = 1.5f;

    public float macdCandleWidth = 0.6f;

    public float mainFlex = 0.716f;

    public float volumeFlex = 0.122f;

    public String fontFamily = "";

    public int textColor = Color.WHITE;

    public float headerTextFontSize = 9;

    public float rightTextFontSize = 10;

    public float candleTextFontSize = 11;

    public int candleTextColor = Color.WHITE;

    public int closePriceCenterSeparatorColor = Color.WHITE;

    public int closePriceCenterBorderColor = Color.WHITE;

    public int closePriceCenterBackgroundColor = Color.WHITE;

    public int closePriceCenterTriangleColor = Color.WHITE;

    public int closePriceRightSeparatorColor = Color.WHITE;

    public int closePriceRightBackgroundColor = Color.WHITE;

    public String closePriceRightLightLottieFloder = "";

    public String closePriceRightLightLottieSource = "";

    public float closePriceRightLightLottieScale = 1;

    // Optional base64-encoded logo image drawn in the center of the main chart,
    // behind the candles. Provided from JS via configList["centerLogoSource"].
    // May be a bare base64 string or a full data-URL (data:image/png;base64,...).
    public String centerLogoSource = "";

    // Decoded bitmap cached from centerLogoSource.
    public Bitmap centerLogoBitmap = null;

    public int[] panelGradientColorList = { Color.BLUE, Color.BLUE };

    public float[] panelGradientLocationList = { 0, 1 };

    public int panelBackgroundColor = Color.WHITE;

    public int panelBorderColor = Color.WHITE;

    public int selectedPointContainerColor = Color.WHITE;

    public int selectedPointContentColor = Color.WHITE;

    public float panelTextFontSize = 9;

    public float panelMinWidth = 130;




    public int[] targetColorList = { Color.RED, Color.RED, Color.RED, Color.RED, Color.RED, Color.RED };

    public String bollN = "";
    public String bollP = "";
    public String kdjM1 = "";
    public String kdjM2 = "";
    public String kdjN = "";
    public List<HTKLineTargetItem> maList = new ArrayList();
    public List<HTKLineTargetItem> maVolumeList = new ArrayList();
    public String macdL = "";
    public String macdM = "";
    public String macdS = "";
    public List<HTKLineTargetItem> rsiList = new ArrayList();
    public List<HTKLineTargetItem> wrList = new ArrayList();

    public static Typeface font = null;

    // Optional serialized drawing list coming from React Native (optionList.drawList.drawItemList)
    // This is later converted into real HTDrawItem instances inside HTKLineContainerView.
    public List<Map> drawItemList = null;

    public static Typeface findFont(Context context, String fontFamily) {
        if (font != null) {
            return font;
        }
        font = Typeface.createFromAsset(context.getAssets(), fontFamily);
        return font;
    }

    public static int[] parseColorList(Object object) {
        List colorArray = (List)object;
        int[] colorList = new int[colorArray.size()];
        for (int i = 0; i < colorArray.size(); i ++) {
            colorList[i] = ((Number) colorArray.get(i)).intValue();
        }
        return colorList;
    }

    public static float[] parseLocationList(Object object) {
        List locationArray = (List)object;
        float[] locationList = new float[locationArray.size()];
        for (int i = 0; i < locationArray.size(); i ++) {
            locationList[i] = ((Number) locationArray.get(i)).floatValue();
        }
        return locationList;
    }




    public Object getOrDefault(Map map, String key, Object defaultValue) {
        Object object = map.get(key);
        return object != null ? object : defaultValue;
    }

    public KLineEntity packModel(Map<String, Object> keyValue) {
    	KLineEntity entity = new KLineEntity();
        // IMPORTANT:
        // Use the full numeric value coming from JS for `id` (usually a millisecond
        // timestamp). Previously this used intValue(), which overflowed for large
        // timestamps and produced truncated values like 24762752. That broke the
        // mapping between candle ids, drawing pointList.x, and JS data, and caused
        // drawings to shift or appear at the wrong time when reloaded.
        //
        // We keep it as a float internally (KLineEntity.id is float), but convert
        // directly from the JS number to float to preserve as much precision as
        // possible without 32‑bit integer overflow.
    	entity.id = ((Number)keyValue.get("id")).floatValue();
        entity.Date = keyValue.get("dateString").toString();
        entity.Open = ((Number)keyValue.get("open")).floatValue();
        entity.High = ((Number)keyValue.get("high")).floatValue();
        entity.Low = ((Number)keyValue.get("low")).floatValue();
        entity.Close = ((Number)keyValue.get("close")).floatValue();
        entity.Volume = ((Number)keyValue.get("vol")).floatValue();
        entity.selectedItemList = (List<Map<String, Object>>) keyValue.get("selectedItemList");


        entity.maList = HTKLineTargetItem.packModelArray((List) this.getOrDefault(keyValue, "maList", new ArrayList()));
        entity.up = ((Number)this.getOrDefault(keyValue, "bollUp", 0.0)).floatValue();
        entity.dn = ((Number)this.getOrDefault(keyValue, "bollDn", 0.0)).floatValue();
        entity.mb = ((Number)this.getOrDefault(keyValue, "bollMb", 0.0)).floatValue();
        entity.maVolumeList = HTKLineTargetItem.packModelArray((List) this.getOrDefault(keyValue, "maVolumeList", new ArrayList()));
        entity.macd = ((Number)this.getOrDefault(keyValue, "macdValue", 0.0)).floatValue();
        entity.dea = ((Number)this.getOrDefault(keyValue, "macdDea", 0.0)).floatValue();
        entity.dif = ((Number)this.getOrDefault(keyValue, "macdDif", 0.0)).floatValue();
        entity.k = ((Number)this.getOrDefault(keyValue, "kdjD", 0.0)).floatValue();
        entity.d = ((Number)this.getOrDefault(keyValue, "kdjJ", 0.0)).floatValue();
        entity.j = ((Number)this.getOrDefault(keyValue, "kdjK", 0.0)).floatValue();
        entity.rsiList = HTKLineTargetItem.packModelArray((List) this.getOrDefault(keyValue, "rsiList", new ArrayList()));
        entity.wrList = HTKLineTargetItem.packModelArray((List) this.getOrDefault(keyValue, "wrList", new ArrayList()));
        return entity;
    }

    public List<KLineEntity> packModelList(List modelArray) {
    	List<KLineEntity> modelList = new ArrayList<KLineEntity>();
//      dateFormat.setTimeZone(TimeZone.getTimeZone("Asia/Shanghai"));
        for (Object object : modelArray) {
            Map<String, Object> keyValue = (Map<String, Object>)object;
            KLineEntity entity = packModel(keyValue);
            modelList.add(entity);
        }
        return modelList;
    
    }


    public void reloadOptionList(Map optionList) {

        // Reset optional serialized drawing list each time we reload
        this.drawItemList = null;

    	Map targetList = (Map)optionList.get("targetList");
    	if (targetList != null) {
    		this.maList = HTKLineTargetItem.packModelArray((List) targetList.get("maList"));
	        this.maVolumeList = HTKLineTargetItem.packModelArray((List) targetList.get("maVolumeList"));
	        this.rsiList = HTKLineTargetItem.packModelArray((List) targetList.get("rsiList"));
	        this.wrList = HTKLineTargetItem.packModelArray((List) targetList.get("wrList"));
	        this.bollN = (String) targetList.get("bollN");
	        this.bollP = (String) targetList.get("bollP");
	        this.macdL = (String) targetList.get("macdL");
	        this.macdM = (String) targetList.get("macdM");
	        this.macdS = (String) targetList.get("macdS");
	        this.kdjN = (String) targetList.get("kdjN");
	        this.kdjM1 = (String) targetList.get("kdjM1");
	        this.kdjM2 = (String) targetList.get("kdjM2");
    	}

    	Map drawList = (Map)optionList.get("drawList");
    	if (drawList != null) {
    	    Number shotBackgroundColorValue = (Number)drawList.get("shotBackgroundColor");
    	    if (shotBackgroundColorValue != null) {
    	        this.shotBackgroundColor = shotBackgroundColorValue.intValue();
            }
    	    Number drawTypeValue = (Number)drawList.get("drawType");
    	    if (drawTypeValue != null) {
    	        this.drawType = HTDrawType.drawTypeFromRawValue(drawTypeValue.intValue());
            }
    	    Boolean drawShouldContinue = (Boolean) drawList.get("drawShouldContinue");
    	    if (drawShouldContinue != null) {
    	        this.drawShouldContinue = drawShouldContinue;
            }
            Boolean shouldFixDraw = (Boolean) drawList.get("shouldFixDraw");
            if (shouldFixDraw != null) {
                this.shouldFixDraw = shouldFixDraw;
            }
            Boolean shouldClearDraw = (Boolean) drawList.get("shouldClearDraw");
            if (shouldClearDraw != null) {
                this.shouldClearDraw = shouldClearDraw;
            }
            Number drawColorValue = (Number)drawList.get("drawColor");
            if (drawColorValue != null) {
                this.drawColor = drawColorValue.intValue();
            }
            Number drawLineHeightValue = (Number)drawList.get("drawLineHeight");
            if (drawLineHeightValue != null) {
                this.drawLineHeight = drawLineHeightValue.floatValue();
            }
            Number drawDashWidthValue = (Number)drawList.get("drawDashWidth");
            if (drawDashWidthValue != null) {
                this.drawDashWidth = drawDashWidthValue.floatValue();
            }
            Number drawDashSpaceValue = (Number)drawList.get("drawDashSpace");
            if (drawDashSpaceValue != null) {
                this.drawDashSpace = drawDashSpaceValue.floatValue();
            }
            Number shouldReloadDrawItemIndexValue = (Number)drawList.get("shouldReloadDrawItemIndex");
            if (shouldReloadDrawItemIndexValue != null) {
                this.shouldReloadDrawItemIndex = shouldReloadDrawItemIndexValue.intValue();
            }
            Boolean drawIsLock = (Boolean) drawList.get("drawIsLock");
            if (drawIsLock != null) {
                this.drawIsLock = drawIsLock;
            }
            Boolean drawShouldTrash = (Boolean) drawList.get("drawShouldTrash");
            if (drawShouldTrash != null) {
                this.drawShouldTrash = drawShouldTrash;
            }

            // Optional text styling for text annotations
            Number textColorValue = (Number) drawList.get("textColor");
            if (textColorValue != null) {
                this.drawTextColor = textColorValue.intValue();
            }
            Number textBackgroundColorValue = (Number) drawList.get("textBackgroundColor");
            if (textBackgroundColorValue != null) {
                this.drawTextBackgroundColor = textBackgroundColorValue.intValue();
            }
            Number textCornerRadiusValue = (Number) drawList.get("textCornerRadius");
            if (textCornerRadiusValue != null) {
                this.drawTextCornerRadius = textCornerRadiusValue.floatValue();
            }

            // Optional: pre-defined drawing items from React Native
            List drawItemList = (List) drawList.get("drawItemList");
            if (drawItemList != null) {
                this.drawItemList = drawItemList;
            }
        }

        Boolean shouldScrollToEnd = (Boolean)optionList.get("shouldScrollToEnd");
        if (shouldScrollToEnd != null) {
            this.shouldScrollToEnd = shouldScrollToEnd;
        }

        if (shouldReloadDrawItemIndex >= HTDrawState.showPencil) {
            this.shouldScrollToEnd = false;
        }


    	Map configList = (Map)optionList.get("configList");
    	if (configList == null) {
    		return;
    	}
    	Integer primary = ((Number)this.getOrDefault(optionList, "primary", -1.0)).intValue();
        Integer second = ((Number)this.getOrDefault(optionList, "second", -1.0)).intValue();
        Integer time = ((Number)this.getOrDefault(optionList, "time", -1.0)).intValue();
        Integer priceRightLength = ((Number)this.getOrDefault(optionList, "price", -1.0)).intValue();
        Integer volumeRightLength = ((Number)this.getOrDefault(optionList, "volume", -1.0)).intValue();

        PrimaryStatus primaryStatus = PrimaryStatus.NONE;
        SecondStatus secondStatus = SecondStatus.NONE;
        switch(primary) {
            case 1: {
                primaryStatus = PrimaryStatus.MA;
                break;
            }
            case 2: {
                primaryStatus = PrimaryStatus.BOLL;
                break;
            }
        }
        switch(second) {
            case 3: {
                secondStatus = SecondStatus.MACD;
                break;
            }
            case 4: {
                secondStatus = SecondStatus.KDJ;
                break;
            }
            case 5: {
                secondStatus = SecondStatus.RSI;
                break;
            }
            case 6: {
                secondStatus = SecondStatus.WR;
                break;
            }
        }
        this.primaryStatus = primaryStatus;
        this.secondStatus = secondStatus;
        this.isMinute = time == -1;

        ValueFormatter.priceRightLength = priceRightLength;
        ValueFormatter.volumeRightLength = volumeRightLength;




    	Map colorList = (Map)configList.get("colorList");
        this.increaseColor = ((Number) colorList.get("increaseColor")).intValue();
        this.decreaseColor = ((Number) colorList.get("decreaseColor")).intValue();

        this.mainFlex = ((Number)configList.get("mainFlex")).floatValue();
        this.volumeFlex = ((Number)configList.get("volumeFlex")).floatValue();

        
        this.minuteLineColor = ((Number) configList.get("minuteLineColor")).intValue();
        this.paddingRight = ((Number)configList.get("paddingRight")).floatValue();
        this.paddingTop = ((Number)configList.get("paddingTop")).floatValue();
        this.paddingBottom = ((Number)configList.get("paddingBottom")).floatValue();
        this.itemWidth = ((Number)configList.get("itemWidth")).floatValue();
        this.candleWidth = ((Number)configList.get("candleWidth")).floatValue();

        this.fontFamily = (configList.get("fontFamily")).toString();
        this.textColor = ((Number) configList.get("textColor")).intValue();
        this.headerTextFontSize = ((Number)configList.get("headerTextFontSize")).floatValue();
        this.rightTextFontSize = ((Number)configList.get("rightTextFontSize")).floatValue();
        this.candleTextFontSize = ((Number)configList.get("candleTextFontSize")).floatValue();
        this.candleTextColor = ((Number) configList.get("candleTextColor")).intValue();
        this.closePriceCenterSeparatorColor = ((Number) configList.get("closePriceCenterSeparatorColor")).intValue();
        this.closePriceCenterBorderColor = ((Number) configList.get("closePriceCenterBorderColor")).intValue();
        this.closePriceCenterBackgroundColor = ((Number) configList.get("closePriceCenterBackgroundColor")).intValue();
        this.closePriceCenterTriangleColor = ((Number) configList.get("closePriceCenterTriangleColor")).intValue();
        this.closePriceRightSeparatorColor = ((Number) configList.get("closePriceRightSeparatorColor")).intValue();
        this.closePriceRightBackgroundColor = ((Number) configList.get("closePriceRightBackgroundColor")).intValue();
        this.closePriceRightLightLottieSource = (String) configList.get("closePriceRightLightLottieSource");
        this.closePriceRightLightLottieFloder = (String) configList.get("closePriceRightLightLottieFloder");
        this.closePriceRightLightLottieScale = ((Number)configList.get("closePriceRightLightLottieScale")).floatValue();

        this.panelGradientColorList = parseColorList(configList.get("panelGradientColorList"));
        this.panelGradientLocationList = parseLocationList(configList.get("panelGradientLocationList"));
        this.panelBackgroundColor = ((Number) configList.get("panelBackgroundColor")).intValue();
        this.panelBorderColor = ((Number) configList.get("panelBorderColor")).intValue();
        this.selectedPointContainerColor = ((Number) configList.get("selectedPointContainerColor")).intValue();
        this.selectedPointContentColor = ((Number) configList.get("selectedPointContentColor")).intValue();
        this.panelMinWidth = ((Number)configList.get("panelMinWidth")).floatValue();
        this.panelTextFontSize = ((Number)configList.get("panelTextFontSize")).floatValue();



        this.minuteVolumeCandleColor = ((Number) configList.get("minuteVolumeCandleColor")).intValue();
        this.minuteVolumeCandleWidth = ((Number)configList.get("minuteVolumeCandleWidth")).floatValue();
        this.macdCandleWidth = ((Number)configList.get("macdCandleWidth")).floatValue();


        this.targetColorList = parseColorList(configList.get("targetColorList"));
        this.minuteGradientColorList = parseColorList(configList.get("minuteGradientColorList"));
        this.minuteGradientLocationList = parseLocationList(configList.get("minuteGradientLocationList"));

        // Optional center logo (base64) from JS.
        Object centerLogoSourceObj = configList.get("centerLogoSource");
        if (centerLogoSourceObj instanceof String) {
            this.centerLogoSource = (String) centerLogoSourceObj;
        } else {
            this.centerLogoSource = "";
        }

        // Decode / cache bitmap when source changes.
        this.centerLogoBitmap = null;
        if (this.centerLogoSource != null && this.centerLogoSource.length() > 0) {
            try {
                String base64String = this.centerLogoSource;
                int commaIndex = base64String.indexOf(',');
                if (commaIndex >= 0) {
                    base64String = base64String.substring(commaIndex + 1);
                }
                byte[] data = Base64.decode(base64String, Base64.DEFAULT);
                this.centerLogoBitmap = BitmapFactory.decodeByteArray(data, 0, data.length);
            } catch (IllegalArgumentException e) {
                // Ignore invalid base64; logo simply won't be drawn.
                this.centerLogoBitmap = null;
            }
        }

        
    }

}
