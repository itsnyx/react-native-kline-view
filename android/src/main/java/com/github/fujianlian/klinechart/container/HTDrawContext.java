package com.github.fujianlian.klinechart.container;

import android.content.Context;
import android.graphics.*;
import android.view.MotionEvent;
import android.view.View;
import com.github.fujianlian.klinechart.BaseKLineChartView;
import com.github.fujianlian.klinechart.HTKLineConfigManager;
import com.github.fujianlian.klinechart.KLineChartView;

import java.util.ArrayList;
import java.util.List;

public class HTDrawContext {

    public List<HTDrawItem> drawItemList = new ArrayList<HTDrawItem>();

    private Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);

    private BaseKLineChartView klineView;

    private HTKLineConfigManager configManager;

    private Boolean breakTouch = false;
    // Tracks whether the user is currently moving an existing drawing item.
    private boolean isMovingExistingItem = false;

    public HTDrawContext(BaseKLineChartView klineView, HTKLineConfigManager configManager) {
        this.klineView = klineView;
        this.configManager = configManager;
    }

    public void touchesGesture(HTPoint location, HTPoint translation, int state) {
        // 能够处理点击, 改变拖动的点, 重新绘制
        if (breakTouch == true) {
            if (state == MotionEvent.ACTION_UP) {
                breakTouch = false;
            }
            return;
        }

        // If we were moving an existing item and the gesture just ended, fire a single move callback.
        if (state == MotionEvent.ACTION_UP && isMovingExistingItem) {
            HTDrawItem moveItem = HTDrawItem.findTouchMoveItem(drawItemList);
            if (moveItem != null && configManager.onDrawItemMove != null) {
                int moveItemIndex = drawItemList.indexOf(moveItem);
                configManager.onDrawItemMove.invoke(moveItem, moveItemIndex);
            }
            isMovingExistingItem = false;
            invalidate();
            return;
        }
        switch (state) {
            case MotionEvent.ACTION_DOWN: {
                if (configManager.shouldReloadDrawItemIndex > HTDrawState.showContext) {
                    HTDrawItem selectedDrawItem = drawItemList.get(configManager.shouldReloadDrawItemIndex);
                    if (selectedDrawItem.pointList.size() >= selectedDrawItem.drawType.count()) {
                        if (HTDrawItem.canResponseLocation(drawItemList, location, klineView) != selectedDrawItem) {
                            configManager.onDrawItemDidTouch.invoke(null, HTDrawState.showPencil);
                            breakTouch = true;
                            invalidate();
                            return;
                        }
                    }
                }
                break;
            }
        }
        if (HTDrawItem.canResponseTouch(drawItemList, location, translation, state, klineView)) {
            if (state == MotionEvent.ACTION_DOWN) {
                HTDrawItem moveItem = HTDrawItem.findTouchMoveItem(drawItemList);
                if (moveItem != null && configManager.onDrawItemDidTouch != null) {
                    // User started interacting with an existing drawing.
                    isMovingExistingItem = true;
                    int moveItemIndex = drawItemList.indexOf(moveItem);
                    configManager.onDrawItemDidTouch.invoke(moveItem, moveItemIndex);
                }
            }
            invalidate();
            return;
        }
        if (configManager.drawType == HTDrawType.none) {
            return;
        }


        int size = drawItemList.size();
        HTDrawItem drawItem = size > 0 ? drawItemList.get(size - 1) : null;
        switch (state) {
            case MotionEvent.ACTION_DOWN:
                if (drawItem == null || (drawItem.pointList.size() >= drawItem.drawType.count())) {
                    // For candleMarker, ignore the tapped Y-value and snap to the
                    // bottom of the corresponding candle body (min(open, close)).
                    HTPoint startLocation = location;
                    if (configManager.drawType == HTDrawType.candleMarker) {
                        startLocation = new HTPoint(location.x, bodyBottomValueForX(location.x));
                    }
                    drawItem = new HTDrawItem(configManager.drawType, startLocation);
                    drawItem.drawColor = configManager.drawColor;
                    drawItem.drawLineHeight = configManager.drawLineHeight;
                    drawItem.drawDashWidth = configManager.drawDashWidth;
                    drawItem.drawDashSpace = configManager.drawDashSpace;
                    // Apply text defaults (used when drawType == text)
                    drawItem.textColor = configManager.drawTextColor;
                    drawItem.textBackgroundColor = configManager.drawTextBackgroundColor;
                    drawItem.textCornerRadius = configManager.drawTextCornerRadius;
                    // Initialize per-item text font size from the current global candle text size,
                    // but make it a bit larger by default (2x).
                    drawItem.textFontSize = configManager.candleTextFontSize * 2f;
                    drawItemList.add(drawItem);
                    if (configManager.onDrawItemDidTouch != null) {
                        configManager.onDrawItemDidTouch.invoke(drawItem, drawItemList.size() - 1);
                    }
                } else {
                    drawItem.pointList.add(location);
                }
                // fall through to MOVE/UP handling so the first point is positioned correctly
            case MotionEvent.ACTION_MOVE:
            case MotionEvent.ACTION_UP:
                if (drawItem != null) {
                    int length = drawItem.pointList.size();
                    if (length >= 1) {
                        int index = length - 1;
                        drawItem.pointList.set(index, location);
                        if (state == MotionEvent.ACTION_UP) {
                            // When finishing a drag while creating/editing a drawing, report the final position once.
                            if (configManager.onDrawItemMove != null) {
                                configManager.onDrawItemMove.invoke(drawItem, drawItemList.size() - 1);
                            }
                            if (configManager.onDrawPointComplete != null) {
                                configManager.onDrawPointComplete.invoke(drawItem, drawItemList.size() - 1);
                            }
                            if (index == drawItem.drawType.count() - 1 && configManager.onDrawItemComplete != null) {
                                configManager.onDrawItemComplete.invoke(drawItem, drawItemList.size() - 1);
                                if (configManager.drawShouldContinue) {
                                    configManager.shouldReloadDrawItemIndex = HTDrawState.showContext;
                                } else {
                                    configManager.drawType = HTDrawType.none;
                                }
                            }
                        }
                    }
                }
                break;
            default:
                break;
        }
        invalidate();
    }

    public void invalidate() {
        klineView.invalidate();
    }

    public void fixDrawItemList() {
        int size = drawItemList.size();
        if (size <= 0) {
            return;
        }
        HTDrawItem drawItem = drawItemList.get(size - 1);
        if (drawItem.pointList.size() < drawItem.drawType.count()) {
            drawItemList.remove(drawItem);
        }
        invalidate();
    }

    public void clearDrawItemList() {
        drawItemList = new ArrayList<>();
        invalidate();
    }

    private int colorWithAlphaComponent(int color, double alpha) {
        int reloadColor = (color & 0x00FFFFFF) | ((int)(alpha * 255) << 24);
        return reloadColor;
    }

    private void drawLine(Canvas canvas, HTDrawItem drawItem, HTPoint startPoint, HTPoint endPoint) {
        paint.setColor(drawItem.drawColor);
        paint.setPathEffect(new DashPathEffect(new float[] { drawItem.drawDashWidth, drawItem.drawDashSpace }, 0));
        paint.setStrokeWidth(drawItem.drawLineHeight);
        Path path = new Path();
        path.moveTo(startPoint.x, startPoint.y);
        path.lineTo(endPoint.x, endPoint.y);
        paint.setStyle(Paint.Style.STROKE);
        canvas.drawPath(path, paint);
    }

    /**
     * For a given X-value (timestamp), find the candle whose id is closest and
     * return the bottom of its real body (min(open, close)) in value-space.
     * This is used to anchor candleMarker pointers to the corresponding candle.
     */
    private float bodyBottomValueForX(float valueX) {
        if (configManager == null || configManager.modelArray == null || configManager.modelArray.size() == 0) {
            return valueX;
        }
        KLineEntity closest = configManager.modelArray.get(0);
        float minDiff = Math.abs(closest.id - valueX);
        for (KLineEntity entity : configManager.modelArray) {
            float diff = Math.abs(entity.id - valueX);
            if (diff < minDiff) {
                minDiff = diff;
                closest = entity;
            }
        }
        float bodyLow = Math.min(closest.Open, closest.Close);
        return bodyLow;
    }

    public void drawMapper(Canvas canvas, HTDrawItem drawItem, int index, int itemIndex) {
        HTPoint point = drawItem.pointList.get(index);

        // Candle marker: bubble with text and a pointer to a specific candle/price.
        if (drawItem.drawType == HTDrawType.candleMarker) {
            HTPoint viewPoint = klineView.viewPointFromValuePoint(point);

            paint.setPathEffect(null);
            float fontSize = drawItem.textFontSize > 0 ? drawItem.textFontSize : configManager.candleTextFontSize;
            paint.setTextSize(fontSize);

            String text = (drawItem.text != null && drawItem.text.length() > 0) ? drawItem.text : "";

            Paint.FontMetrics fm = paint.getFontMetrics();
            float textHeight = fm.bottom - fm.top;
            float textWidth = paint.measureText(text);

            float paddingH = 12f;
            float paddingV = 6f;
            float gap = 4f;
            float triangleHeight = 6f;
            float triangleHalfWidth = 6f;
            float marginX = 4f;

            float bubbleWidth = textWidth + paddingH * 2f;
            float bubbleHeight = textHeight + paddingV * 2f;

            float centerX = viewPoint.x;
            float left = centerX - bubbleWidth / 2f;
            float right = centerX + bubbleWidth / 2f;

            // Clamp bubble within view bounds and adjust center if needed.
            if (left < marginX) {
                float shift = marginX - left;
                left += shift;
                right += shift;
                centerX += shift;
            }
            float maxRight = klineView.getWidth() - marginX;
            if (right > maxRight) {
                float shift = right - maxRight;
                left -= shift;
                right -= shift;
                centerX -= shift;
            }

            float triangleBaseY = viewPoint.y + gap;
            float top = triangleBaseY + triangleHeight;
            float bottom = top + bubbleHeight;

            android.graphics.RectF rect = new android.graphics.RectF(left, top, right, bottom);

            int backgroundColor = drawItem.textBackgroundColor != 0
                    ? drawItem.textBackgroundColor
                    : configManager.drawTextBackgroundColor;
            int textColor = drawItem.textColor != 0
                    ? drawItem.textColor
                    : configManager.drawTextColor;

            // Bubble background
            paint.setColor(backgroundColor);
            paint.setStyle(Paint.Style.FILL);
            float radius = drawItem.textCornerRadius > 0
                    ? drawItem.textCornerRadius
                    : configManager.drawTextCornerRadius;
            canvas.drawRoundRect(rect, radius, radius, paint);

            // Pointer triangle from bubble to candle/price
            Path triangle = new Path();
            triangle.moveTo(viewPoint.x, viewPoint.y);
            triangle.lineTo(centerX - triangleHalfWidth, triangleBaseY);
            triangle.lineTo(centerX + triangleHalfWidth, triangleBaseY);
            triangle.close();
            canvas.drawPath(triangle, paint);

            // Text
            paint.setColor(textColor);
            paint.setStyle(Paint.Style.FILL);
            float textX = left + paddingH;
            // Position baseline so that text sits inside the bubble.
            float textY = top + paddingV - fm.top;
            canvas.drawText(text, textX, textY, paint);

            if (itemIndex == configManager.shouldReloadDrawItemIndex) {
                Path highlight = new Path();
                paint.setStyle(Paint.Style.FILL);
                highlight.addCircle(viewPoint.x, viewPoint.y, 20, Path.Direction.CW);
                paint.setColor(colorWithAlphaComponent(drawItem.drawColor, 0.5));
                canvas.drawPath(highlight, paint);

                highlight = new Path();
                highlight.addCircle(viewPoint.x, viewPoint.y, 8, Path.Direction.CW);
                paint.setColor(drawItem.drawColor);
                canvas.drawPath(highlight, paint);
            }
            return;
        }

        // Global price-level horizontal line: spans full chart width at a given price.
        if (drawItem.drawType == HTDrawType.globalHorizontalLine ||
            drawItem.drawType == HTDrawType.globalHorizontalLineWithLabel) {
            HTPoint viewPoint = klineView.viewPointFromValuePoint(point);

            paint.setColor(drawItem.drawColor);
            paint.setStrokeWidth(drawItem.drawLineHeight);
            paint.setStyle(Paint.Style.STROKE);
            if (drawItem.drawDashSpace != 0) {
                paint.setPathEffect(new DashPathEffect(new float[] { drawItem.drawDashWidth, drawItem.drawDashSpace }, 0));
            } else {
                paint.setPathEffect(null);
            }

            Path path = new Path();
            path.moveTo(0, viewPoint.y);
            path.lineTo(klineView.getWidth(), viewPoint.y);
            canvas.drawPath(path, paint);

            // Labels: optional text on the left, price on the right.
            float priceValue = point.y;
            String priceText = klineView.formatValue(priceValue);
            String leftText = (drawItem.text != null && drawItem.text.length() > 0)
                    ? drawItem.text
                    : null;

            paint.setPathEffect(null);
            paint.setStyle(Paint.Style.FILL);
            paint.setTextSize(configManager.candleTextFontSize);

            Paint.FontMetrics fm = paint.getFontMetrics();
            float textHeight = fm.descent - fm.ascent;
            float paddingH = 8f;
            float paddingV = 4f;
            float marginX = 4f;

            // Baseline above the line so labels do not overlap the stroke.
            float baseLineY = viewPoint.y - textHeight - paddingV - fm.descent;
            if (baseLineY < textHeight) {
                baseLineY = textHeight;
            }

            // Left label (custom text), if any.
            if (drawItem.drawType == HTDrawType.globalHorizontalLineWithLabel && leftText != null) {
                float leftTextWidth = paint.measureText(leftText);
                float left = marginX;
                float right = left + leftTextWidth + paddingH * 2f;
                float top = baseLineY + fm.top - paddingV;
                float bottom = baseLineY + fm.bottom + paddingV;

                android.graphics.RectF rect = new android.graphics.RectF(left, top, right, bottom);
                float radius = (bottom - top) / 2f;

                // Background
                paint.setColor(configManager.panelBackgroundColor);
                paint.setStyle(Paint.Style.FILL);
                canvas.drawRoundRect(rect, radius, radius, paint);

                // Border
                paint.setStyle(Paint.Style.STROKE);
                paint.setStrokeWidth(1f);
                paint.setColor(configManager.panelBorderColor);
                canvas.drawRoundRect(rect, radius, radius, paint);

                // Text
                paint.setStyle(Paint.Style.FILL);
                paint.setColor(configManager.candleTextColor);
                canvas.drawText(leftText, left + paddingH, baseLineY, paint);
            }

            // Right price label.
            float priceTextWidth = paint.measureText(priceText);
            float rightRectRight = klineView.getWidth() - marginX;
            float rightRectLeft = rightRectRight - (priceTextWidth + paddingH * 2f);
            float top = baseLineY + fm.top - paddingV;
            float bottom = baseLineY + fm.bottom + paddingV;

            android.graphics.RectF priceRect = new android.graphics.RectF(rightRectLeft, top, rightRectRight, bottom);
            float priceRadius = (bottom - top) / 2f;

            // Background
            paint.setColor(configManager.panelBackgroundColor);
            paint.setStyle(Paint.Style.FILL);
            canvas.drawRoundRect(priceRect, priceRadius, priceRadius, paint);

            // Border
            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(1f);
            paint.setColor(configManager.panelBorderColor);
            canvas.drawRoundRect(priceRect, priceRadius, priceRadius, paint);

            // Text
            paint.setStyle(Paint.Style.FILL);
            paint.setColor(configManager.candleTextColor);
            canvas.drawText(priceText, rightRectLeft + paddingH, baseLineY, paint);

            if (itemIndex == configManager.shouldReloadDrawItemIndex) {
                Path highlight = new Path();
                paint.setStyle(Paint.Style.FILL);
                highlight.addCircle(viewPoint.x, viewPoint.y, 20, Path.Direction.CW);
                paint.setColor(colorWithAlphaComponent(drawItem.drawColor, 0.5));
                canvas.drawPath(highlight, paint);

                highlight = new Path();
                highlight.addCircle(viewPoint.x, viewPoint.y, 8, Path.Direction.CW);
                paint.setColor(drawItem.drawColor);
                canvas.drawPath(highlight, paint);
            }
            return;
        }

        // Global time-level vertical line: spans full chart height at a given timestamp.
        if (drawItem.drawType == HTDrawType.globalVerticalLine) {
            HTPoint viewPoint = klineView.viewPointFromValuePoint(point);

            paint.setColor(drawItem.drawColor);
            paint.setStrokeWidth(drawItem.drawLineHeight);
            paint.setStyle(Paint.Style.STROKE);
            if (drawItem.drawDashSpace != 0) {
                paint.setPathEffect(new DashPathEffect(new float[] { drawItem.drawDashWidth, drawItem.drawDashSpace }, 0));
            } else {
                paint.setPathEffect(null);
            }

            Path path = new Path();
            path.moveTo(viewPoint.x, 0);
            path.lineTo(viewPoint.x, klineView.getHeight());
            canvas.drawPath(path, paint);

            if (itemIndex == configManager.shouldReloadDrawItemIndex) {
                Path highlight = new Path();
                paint.setStyle(Paint.Style.FILL);
                highlight.addCircle(viewPoint.x, viewPoint.y, 20, Path.Direction.CW);
                paint.setColor(colorWithAlphaComponent(drawItem.drawColor, 0.5));
                canvas.drawPath(highlight, paint);

                highlight = new Path();
                highlight.addCircle(viewPoint.x, viewPoint.y, 8, Path.Direction.CW);
                paint.setColor(drawItem.drawColor);
                canvas.drawPath(highlight, paint);
            }
            return;
        }

        // Special handling for text annotations: draw text at the anchor point with background.
        if (drawItem.drawType == HTDrawType.text) {
            HTPoint viewPoint = klineView.viewPointFromValuePoint(point);
            paint.setPathEffect(null);
            paint.setStrokeWidth(0);
            // Use per-item font size when provided; otherwise fall back to the global candleTextFontSize.
            float fontSize = drawItem.textFontSize > 0 ? drawItem.textFontSize : configManager.candleTextFontSize;
            paint.setTextSize(fontSize);

            if (drawItem.text != null && drawItem.text.length() > 0) {
                String text = drawItem.text;
                float paddingH = 12f;
                float paddingV = 6f;

                Paint.FontMetrics fm = paint.getFontMetrics();
                float textHeight = fm.bottom - fm.top;
                float textWidth = paint.measureText(text);

                float left = viewPoint.x;
                float top = viewPoint.y + fm.top - paddingV;
                float right = left + textWidth + paddingH * 2;
                float bottom = viewPoint.y + fm.bottom + paddingV;

                float radius = drawItem.textCornerRadius > 0 ? drawItem.textCornerRadius : configManager.drawTextCornerRadius;

                // Background
                paint.setColor(drawItem.textBackgroundColor != 0 ? drawItem.textBackgroundColor : configManager.drawTextBackgroundColor);
                paint.setStyle(Paint.Style.FILL);
                android.graphics.RectF rect = new android.graphics.RectF(left, top, right, bottom);
                canvas.drawRoundRect(rect, radius, radius, paint);

                // Text
                paint.setColor(drawItem.textColor != 0 ? drawItem.textColor : configManager.drawTextColor);
                paint.setStyle(Paint.Style.FILL);
                canvas.drawText(text, left + paddingH, viewPoint.y, paint);
            }

            if (itemIndex == configManager.shouldReloadDrawItemIndex) {
                Path path = new Path();
                paint.setStyle(Paint.Style.FILL);
                path.addCircle(viewPoint.x, viewPoint.y, 20, Path.Direction.CW);
                paint.setColor(colorWithAlphaComponent(drawItem.drawColor, 0.5));
                canvas.drawPath(path, paint);

                path = new Path();
                paint.setStyle(Paint.Style.FILL);
                path.addCircle(viewPoint.x, viewPoint.y, 8, Path.Direction.CW);
                paint.setColor(drawItem.drawColor);
                canvas.drawPath(path, paint);
            }
            return;
        }

        List<List<HTPoint>> lineList = HTDrawItem.lineListWithIndex(drawItem, index, klineView);
        if (index == 2 && drawItem.drawType == HTDrawType.parallelLine) {
            List<HTPoint> firstLine = lineList.get(0);
            HTPoint startPoint = firstLine.get(0);
            HTPoint endPoint = firstLine.get(1);
            HTPoint firstPoint = drawItem.pointList.get(0);
            HTPoint secondPoint = drawItem.pointList.get(1);
            Path path = new Path();

            HTPoint firstViewPoint = klineView.viewPointFromValuePoint(firstPoint);
            HTPoint secondViewPoint = klineView.viewPointFromValuePoint(secondPoint);
            HTPoint startViewPoint = klineView.viewPointFromValuePoint(startPoint);
            HTPoint endViewPoint = klineView.viewPointFromValuePoint(endPoint);

            path.moveTo(firstViewPoint.x, firstViewPoint.y);
            path.lineTo(secondViewPoint.x, secondViewPoint.y);
            path.lineTo(startViewPoint.x, startViewPoint.y);
            path.lineTo(endViewPoint.x, endViewPoint.y);
            path.close();
            paint.setColor(colorWithAlphaComponent(drawItem.drawColor, 0.5));
            paint.setStyle(Paint.Style.FILL);
            canvas.drawPath(path, paint);

            HTPoint dashStartPoint = HTDrawItem.centerPoint(firstPoint, endPoint);
            HTPoint dashEndPoint = HTDrawItem.centerPoint(secondPoint, startPoint);
            path = new Path();

            HTPoint dashStartViewPoint = klineView.viewPointFromValuePoint(dashStartPoint);
            HTPoint dashEndViewPoint = klineView.viewPointFromValuePoint(dashEndPoint);

            path.moveTo(dashStartViewPoint.x, dashStartViewPoint.y);
            path.lineTo(dashEndViewPoint.x, dashEndViewPoint.y);
            paint.setColor(colorWithAlphaComponent(drawItem.drawColor, 0.5));
            paint.setPathEffect(new DashPathEffect(new float[] { 4, 4 }, 0));
            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(2);
            canvas.drawPath(path, paint);
        }
        for (List<HTPoint> pointList: lineList) {
            HTPoint startPoint = pointList.get(0);
            HTPoint endPoint = pointList.get(1);
            drawLine(canvas, drawItem, klineView.viewPointFromValuePoint(startPoint), klineView.viewPointFromValuePoint(endPoint));
        }

        if (itemIndex != configManager.shouldReloadDrawItemIndex) {
            return;
        }



        HTPoint viewPoint = klineView.viewPointFromValuePoint(point);

        Path path = new Path();
        paint.setStyle(Paint.Style.FILL);
        path.addCircle(viewPoint.x, viewPoint.y, 20, Path.Direction.CW);
        paint.setColor(colorWithAlphaComponent(drawItem.drawColor, 0.5));
        canvas.drawPath(path, paint);

        path = new Path();
        paint.setStyle(Paint.Style.FILL);
        path.addCircle(viewPoint.x, viewPoint.y, 8, Path.Direction.CW);
        paint.setColor(drawItem.drawColor);
        canvas.drawPath(path, paint);
    }


    public void onDraw(Canvas canvas) {
        for (int itemIndex = 0; itemIndex < drawItemList.size(); itemIndex ++) {
            HTDrawItem drawItem = drawItemList.get(itemIndex);
            for (int index = 0; index < drawItem.pointList.size(); index ++) {
                drawMapper(canvas, drawItem, index, itemIndex);
            }
        }
    }
}
