package com.github.fujianlian.klinechart.utils;

import java.text.SimpleDateFormat;

/**
 * 时间工具类
 * Created by tifezh on 2016/4/27.
 */
public class DateUtil {
    public static SimpleDateFormat longTimeFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm");
    public static SimpleDateFormat shortTimeFormat = new SimpleDateFormat("HH:mm");
    public static SimpleDateFormat DateFormat = new SimpleDateFormat("yyyy/MM/dd");

    public static SimpleDateFormat intraday = new SimpleDateFormat("MM-dd HH:mm");
    public static SimpleDateFormat daily = new SimpleDateFormat("yyyy-MM-dd");
    public static SimpleDateFormat monthly = new SimpleDateFormat("yyyy-MM");

    static {
        java.util.TimeZone utc = java.util.TimeZone.getTimeZone("UTC");
        intraday.setTimeZone(utc);
        daily.setTimeZone(utc);
        monthly.setTimeZone(utc);
    }

    // TimeConstants enum values from JS (matches constants.ts)
    // oneDay=11, threeDay=12, oneWeek=13, oneMonth=14, minuteHour=-1
    private static final int TIME_ONE_DAY = 11;
    private static final int TIME_ONE_MONTH = 14;

    /**
     * Format a date based on the selected timeframe enum value.
     * @param epochMs  epoch timestamp in milliseconds
     * @param timeType TimeConstants enum value (2-14, or -1 for Line)
     */
    public static String formatByTimeframe(long epochMs, int timeType) {
        java.util.Date date = new java.util.Date(epochMs);
        if (timeType >= TIME_ONE_MONTH) {
            // 1M and above → yyyy-MM
            return monthly.format(date);
        } else if (timeType >= TIME_ONE_DAY) {
            // 1D, 3D, 1W → yyyy-MM-dd
            return daily.format(date);
        } else {
            // Below 1D (Line, 1m, 3m, 5m, 15m, 30m, 1h, 4h, 6h, 12h) → MM-dd HH:mm
            return intraday.format(date);
        }
    }
}
