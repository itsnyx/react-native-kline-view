package com.github.fujianlian.klinechart.draw;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Typeface;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.github.fujianlian.klinechart.BaseKLineChartView;
import com.github.fujianlian.klinechart.HTKLineConfigManager;
import com.github.fujianlian.klinechart.HTKLineTargetItem;
import com.github.fujianlian.klinechart.KLineEntity;
import com.github.fujianlian.klinechart.base.IChartDraw;
import com.github.fujianlian.klinechart.base.IValueFormatter;
import com.github.fujianlian.klinechart.entity.IWR;
import com.github.fujianlian.klinechart.formatter.ValueFormatter;

import static android.graphics.Typeface.NORMAL;

/**
 * KDJ实现类
 * Created by tifezh on 2016/6/19.
 */
public class WRDraw implements IChartDraw<IWR> {

    private Context mContext = null;

    private Paint mRPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private Paint primaryPaint = new Paint(Paint.ANTI_ALIAS_FLAG);

    public WRDraw(BaseKLineChartView view) {
        mContext = view.getContext();
    }

    @Override
    public void drawTranslated(@Nullable IWR lastPoint, @NonNull IWR curPoint, float lastX, float curX, @NonNull Canvas canvas, @NonNull BaseKLineChartView view, int position) {
        // Guard against transient config/data mismatches (e.g. when WR is toggled on
        // before modelArray has been updated) to avoid IndexOutOfBounds crashes.
        if (!(curPoint instanceof KLineEntity) || !(lastPoint instanceof KLineEntity)) {
            return;
        }
        KLineEntity lastItem = (KLineEntity) lastPoint;
        KLineEntity currentItem = (KLineEntity) curPoint;
        if (currentItem.wrList == null || lastItem.wrList == null) {
            return;
        }
        int dataSize = Math.min(currentItem.wrList.size(), lastItem.wrList.size());
        int configSize = view.configManager.wrList != null ? view.configManager.wrList.size() : 0;
        int loopSize = Math.min(dataSize, configSize);
        for (int i = 0; i < loopSize; i++) {
            HTKLineTargetItem currentTargetItem = (HTKLineTargetItem) currentItem.wrList.get(i);
            HTKLineTargetItem lastTargetItem = (HTKLineTargetItem) lastItem.wrList.get(i);
            int colorIndex = view.configManager.wrList.get(i).index;
            if (colorIndex >= 0 && colorIndex < view.configManager.targetColorList.length) {
                primaryPaint.setColor(view.configManager.targetColorList[colorIndex]);
            }
            view.drawChildLine(canvas, primaryPaint, lastX, lastTargetItem.value, curX, currentTargetItem.value);
        }
    }

    @Override
    public void drawText(@NonNull Canvas canvas, @NonNull BaseKLineChartView view, int position, float x, float y) {
        KLineEntity point = (KLineEntity) view.getItem(position);
        if (point.wrList == null || view.configManager.wrList == null) {
            return;
        }
        int dataSize = point.wrList.size();
        int configSize = view.configManager.wrList.size();
        int loopSize = Math.min(dataSize, configSize);
        String text = "";
        for (int i = 0; i < loopSize; i++) {
            HTKLineTargetItem targetItem = (HTKLineTargetItem) point.wrList.get(i);
            int colorIndex = view.configManager.wrList.get(i).index;
            if (colorIndex >= 0 && colorIndex < view.configManager.targetColorList.length) {
                this.primaryPaint.setColor(view.configManager.targetColorList[colorIndex]);
            }
            StringBuilder stringBuilder = new StringBuilder();
            stringBuilder.append("WR(");
            stringBuilder.append(targetItem.title);
            stringBuilder.append("):");
            stringBuilder.append(view.formatValue(targetItem.value));
            stringBuilder.append("  ");
            text = stringBuilder.toString();
            canvas.drawText(text, x, y, this.primaryPaint);
            x += this.primaryPaint.measureText(text);
        }
    }

    @Override
    public float getMaxValue(IWR point) {
        KLineEntity item = (KLineEntity) point;
        if (item.wrList == null || item.wrList.isEmpty()) {
            return 0;
        }
        return item.targetListISMax(item.wrList, true);
    }

    @Override
    public float getMinValue(IWR point) {
        KLineEntity item = (KLineEntity) point;
        if (item.wrList == null || item.wrList.isEmpty()) {
            return 0;
        }
        return item.targetListISMax(item.wrList, false);
    }

    @Override
    public IValueFormatter getValueFormatter() {
        return new ValueFormatter();
    }

    /**
     * 设置%R颜色
     */
    public void setRColor(int color) {
        mRPaint.setColor(color);
    }

    /**
     * 设置曲线宽度
     */
    public void setLineWidth(float width) {
        mRPaint.setStrokeWidth(width);
        primaryPaint.setStrokeWidth(width);
    }

    /**
     * 设置文字大小
     */
    public void setTextSize(float textSize) {
        mRPaint.setTextSize(textSize);
        primaryPaint.setTextSize(textSize);
    }

    public void setTextFontFamily(String fontFamily) {
        Typeface typeface = HTKLineConfigManager.findFont(mContext, fontFamily);
        mRPaint.setTypeface(typeface);
        primaryPaint.setTypeface(typeface);
    }

}
