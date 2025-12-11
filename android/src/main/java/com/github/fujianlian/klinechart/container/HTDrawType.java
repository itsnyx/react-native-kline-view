package com.github.fujianlian.klinechart.container;

public enum HTDrawType {

    none,

    line,

    horizontalLine,

    verticalLine,

    halfLine,

    parallelLine,

    // Global price-level horizontal line (spans entire chart horizontally, 1 anchor point)
    globalHorizontalLine,

    // Global price-level horizontal line with text label (left) and price label (right)
    globalHorizontalLineWithLabel,

    // Global time-level vertical line (spans entire chart vertically, 1 anchor point)
    globalVerticalLine,

    // Single-candle marker with label bubble and pointer to a candle
    candleMarker,

    rectangle,

    parallelogram,

    // Text annotation at a single anchor point
    text;

    public static HTDrawType drawTypeFromRawValue(int value) {
        switch (value) {
            case 1: {
                return line;
            }
            case 2: {
                return horizontalLine;
            }
            case 3: {
                return verticalLine;
            }
            case 4: {
                return halfLine;
            }
            case 5: {
                return parallelLine;
            }
            case 301: {
                return globalHorizontalLine;
            }
            case 302: {
                return globalVerticalLine;
            }
            case 303: {
                return globalHorizontalLineWithLabel;
            }
            case 304: {
                return candleMarker;
            }
            case 201: {
                return text;
            }
            case 101: {
                return rectangle;
            }
            case 102: {
                return parallelogram;
            }
            default: {
                return none;
            }
        }
    }

    public int count() {
        if (this == line || this == horizontalLine || this == verticalLine || this == halfLine || this == rectangle) {
            return 2;
        }
        if (this == parallelLine || this == parallelogram) {
            return 3;
        }
        // text, globalHorizontalLine, globalVerticalLine and other 1-point tools
        return 1;
    }

    /**
     * Convert enum case to the integer code used across the JS bridge.
     * This must stay in sync with {@link #drawTypeFromRawValue(int)}.
     */
    public int rawValue() {
        switch (this) {
            case line: {
                return 1;
            }
            case horizontalLine: {
                return 2;
            }
            case verticalLine: {
                return 3;
            }
            case halfLine: {
                return 4;
            }
            case parallelLine: {
                return 5;
            }
            case globalHorizontalLine: {
                return 301;
            }
            case globalVerticalLine: {
                return 302;
            }
            case globalHorizontalLineWithLabel: {
                return 303;
            }
            case candleMarker: {
                return 304;
            }
            case text: {
                return 201;
            }
            case rectangle: {
                return 101;
            }
            case parallelogram: {
                return 102;
            }
            default: {
                return 0;
            }
        }
    }

}
