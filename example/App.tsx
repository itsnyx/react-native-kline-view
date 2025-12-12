/**
 * K-Line Chart Example App
 * Supports indicators, drawing, theme switching, etc.
 */

import React, { Component } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  StatusBar,
  Dimensions,
  Switch,
  processColor,
  Platform,
  PixelRatio,
} from 'react-native';
import RNKLineView from 'react-native-kline-view';

// Helper Functions
const fixRound = (value, precision, showSign = false, showGrouping = false) => {
  if (value === null || value === undefined || isNaN(value)) {
    return '--';
  }

  let result = Number(value).toFixed(precision);

  if (showGrouping) {
    // Add thousands separator
    result = result.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  }

  if (showSign && value > 0) {
    result = '+' + result;
  }

  return result;
};

// FORMAT Helper Function
const FORMAT = text => text;

// Time formatting function, replaces moment
const formatTime = (timestamp, format = 'MM-DD HH:mm') => {
  const date = new Date(timestamp);

  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const hours = String(date.getHours()).padStart(2, '0');
  const minutes = String(date.getMinutes()).padStart(2, '0');
  const seconds = String(date.getSeconds()).padStart(2, '0');

  // Supports common formatting patterns
  return format
    .replace('MM', month)
    .replace('DD', day)
    .replace('HH', hours)
    .replace('mm', minutes)
    .replace('ss', seconds);
};

// Technical indicator calculation functions - original version replaced by config version, remove following functions

// Still needed basic technical indicator calculation functions
const calculateBOLL = (data, n = 20, p = 2) => {
  return data.map((item, index) => {
    if (index < n - 1) {
      return {
        ...item,
        bollMb: item.close,
        bollUp: item.close,
        bollDn: item.close,
      };
    }

    // Calculate MA
    let sum = 0;
    for (let i = index - n + 1; i <= index; i++) {
      sum += data[i].close;
    }
    const ma = sum / n;

    // Calculate Standard Deviation
    let variance = 0;
    for (let i = index - n + 1; i <= index; i++) {
      variance += Math.pow(data[i].close - ma, 2);
    }
    const std = Math.sqrt(variance / (n - 1));

    return {
      ...item,
      bollMb: ma,
      bollUp: ma + p * std,
      bollDn: ma - p * std,
    };
  });
};

const calculateMACD = (data, s = 12, l = 26, m = 9) => {
  let ema12 = data[0].close;
  let ema26 = data[0].close;
  let dea = 0;

  return data.map((item, index) => {
    if (index === 0) {
      return {
        ...item,
        macdValue: 0,
        macdDea: 0,
        macdDif: 0,
      };
    }

    // Calculate EMA
    ema12 = (2 * item.close + (s - 1) * ema12) / (s + 1);
    ema26 = (2 * item.close + (l - 1) * ema26) / (l + 1);

    const dif = ema12 - ema26;
    dea = (2 * dif + (m - 1) * dea) / (m + 1);
    const macd = 2 * (dif - dea);

    return {
      ...item,
      macdValue: macd,
      macdDea: dea,
      macdDif: dif,
    };
  });
};

const calculateKDJ = (data, n = 9, m1 = 3, m2 = 3) => {
  let k = 50;
  let d = 50;

  return data.map((item, index) => {
    if (index === 0) {
      return {
        ...item,
        kdjK: k,
        kdjD: d,
        kdjJ: 3 * k - 2 * d,
      };
    }

    // Find highest and lowest price in n periods
    const startIndex = Math.max(0, index - n + 1);
    let highest = -Infinity;
    let lowest = Infinity;

    for (let i = startIndex; i <= index; i++) {
      highest = Math.max(highest, data[i].high);
      lowest = Math.min(lowest, data[i].low);
    }

    const rsv =
      highest === lowest
        ? 50
        : ((item.close - lowest) / (highest - lowest)) * 100;
    k = (rsv + (m1 - 1) * k) / m1;
    d = (k + (m1 - 1) * d) / m1;
    const j = m2 * k - 2 * d;

    return {
      ...item,
      kdjK: k,
      kdjD: d,
      kdjJ: j,
    };
  });
};

// Get screen width
const { width: screenWidth, height: screenHeight } = Dimensions.get('window');
const isHorizontalScreen = screenWidth > screenHeight;

// Helper function: Convert RGB values from 0-1 range to 0-255 range
const COLOR = (r, g, b, a = 1) => {
  if (a === 1) {
    return `rgb(${Math.round(r * 255)}, ${Math.round(g * 255)}, ${Math.round(
      b * 255,
    )})`;
  } else {
    return `rgba(${Math.round(r * 255)}, ${Math.round(g * 255)}, ${Math.round(
      b * 255,
    )}, ${a})`;
  }
};

// Theme Configuration
class ThemeManager {
  static themes = {
    light: {
      // Basic Colors
      backgroundColor: 'white',
      titleColor: COLOR(0.08, 0.09, 0.12),
      detailColor: COLOR(0.55, 0.62, 0.68),
      textColor7724: COLOR(0.77, 0.81, 0.84),

      // Special Background Colors
      headerColor: COLOR(0.97, 0.97, 0.98),
      tabBarBackgroundColor: 'white',
      backgroundColor9103: COLOR(0.91, 0.92, 0.93),
      backgroundColor9703: COLOR(0.97, 0.97, 0.98),
      backgroundColor9113: COLOR(0.91, 0.92, 0.93),
      backgroundColor9709: COLOR(0.97, 0.97, 0.98),
      backgroundColor9603: COLOR(0.96, 0.97, 0.98),
      backgroundColor9411: COLOR(0.94, 0.95, 0.96),
      backgroundColor9607: COLOR(0.96, 0.97, 0.99),
      backgroundColor9609: 'white',
      backgroundColor9509: COLOR(0.95, 0.97, 0.99),

      // Functional Colors
      backgroundColorBlue: COLOR(0, 0.4, 0.93),
      buttonColor: COLOR(0, 0.4, 0.93),
      borderColor: COLOR(0.91, 0.92, 0.93),
      backgroundOpacity: COLOR(0, 0, 0, 0.5),

      // K-Line Related Colors
      increaseColor: COLOR(0.0, 0.78, 0.32), // Increase Color: Green
      decreaseColor: COLOR(1.0, 0.27, 0.27), // Decrease Color: Red
      minuteLineColor: COLOR(0, 0.4, 0.93),

      // Grid and Border
      gridColor: COLOR(0.91, 0.92, 0.93),
      separatorColor: COLOR(0.91, 0.92, 0.93),

      // Text Color
      textColor: COLOR(0.08, 0.09, 0.12),
    },
    dark: {
      // Basic Colors
      backgroundColor: COLOR(0.07, 0.12, 0.19),
      titleColor: COLOR(0.81, 0.83, 0.91),
      detailColor: COLOR(0.43, 0.53, 0.66),
      textColor7724: COLOR(0.24, 0.33, 0.42),

      // Special Background Colors
      headerColor: COLOR(0.09, 0.16, 0.25),
      tabBarBackgroundColor: COLOR(0.09, 0.16, 0.25),
      backgroundColor9103: COLOR(0.03, 0.09, 0.14),
      backgroundColor9703: COLOR(0.03, 0.09, 0.14),
      backgroundColor9113: COLOR(0.13, 0.2, 0.29),
      backgroundColor9709: COLOR(0.09, 0.16, 0.25),
      backgroundColor9603: COLOR(0.03, 0.09, 0.14),
      backgroundColor9411: COLOR(0.11, 0.17, 0.25),
      backgroundColor9607: COLOR(0.07, 0.15, 0.23),
      backgroundColor9609: COLOR(0.09, 0.15, 0.23),
      backgroundColor9509: COLOR(0.09, 0.16, 0.25),

      // Functional Colors
      backgroundColorBlue: COLOR(0.14, 0.51, 1),
      buttonColor: COLOR(0.14, 0.51, 1),
      borderColor: COLOR(0.13, 0.2, 0.29),
      backgroundOpacity: COLOR(0, 0, 0, 0.8),

      // K-Line Related Colors
      increaseColor: COLOR(0.0, 1.0, 0.53), // Increase Color: Bright Green
      decreaseColor: COLOR(1.0, 0.4, 0.4), // Decrease Color: Bright Red
      minuteLineColor: COLOR(0.14, 0.51, 1),

      // Grid and Border
      gridColor: COLOR(0.13, 0.2, 0.29),
      separatorColor: COLOR(0.13, 0.2, 0.29),

      // Text Color
      textColor: COLOR(0.81, 0.83, 0.91),
    },
  };

  static getCurrentTheme(isDark) {
    return this.themes[isDark ? 'dark' : 'light'];
  }
}

// Time Period Constants
const TimeConstants = {
  oneMinute: 1,
  threeMinute: 2,
  fiveMinute: 3,
  fifteenMinute: 4,
  thirtyMinute: 5,
  oneHour: 6,
  fourHour: 7,
  sixHour: 8,
  oneDay: 9,
  oneWeek: 10,
  oneMonth: 11,
  minuteHour: -1, // Line
};

// Time Period Types - Use constant values
const TimeTypes = {
  1: { label: 'Line', value: TimeConstants.minuteHour },
  2: { label: '1m', value: TimeConstants.oneMinute },
  3: { label: '3m', value: TimeConstants.threeMinute },
  4: { label: '5m', value: TimeConstants.fiveMinute },
  5: { label: '15m', value: TimeConstants.fifteenMinute },
  6: { label: '30m', value: TimeConstants.thirtyMinute },
  7: { label: '1h', value: TimeConstants.oneHour },
  8: { label: '4h', value: TimeConstants.fourHour },
  9: { label: '6h', value: TimeConstants.sixHour },
  10: { label: '1d', value: TimeConstants.oneDay },
  11: { label: '1w', value: TimeConstants.oneWeek },
  12: { label: '1M', value: TimeConstants.oneMonth },
};

// Indicator Types - Sub chart indicator index changed to 3-6
const IndicatorTypes = {
  main: {
    1: { label: 'MA', value: 'ma' },
    2: { label: 'BOLL', value: 'boll' },
    0: { label: 'NONE', value: 'none' },
  },
  sub: {
    3: { label: 'MACD', value: 'macd' },
    4: { label: 'KDJ', value: 'kdj' },
    5: { label: 'RSI', value: 'rsi' },
    6: { label: 'WR', value: 'wr' },
    0: { label: 'NONE', value: 'none' },
  },
};

// Drawing Type Constants
const DrawTypeConstants = {
  none: 0,
  show: -1,
  line: 1,
  horizontalLine: 2,
  verticalLine: 3,
  halfLine: 4,
  parallelLine: 5,
  rectangle: 101,
  parallelogram: 102,
  text: 201, // Text annotation
  // Global price-level horizontal line (1 tap: price only, spans entire chart)
  globalHorizontalLine: 301,
  // Global price-level horizontal line with left text + right price labels
  globalHorizontalLineWithLabel: 303,
  // Global time-level vertical line (1 tap: time only, spans full height)
  globalVerticalLine: 302,
  // Single-candle marker with label bubble and pointer to a candle
  candleMarker: 304,
};

// Drawing State Constants
const DrawStateConstants = {
  none: -3,
  showPencil: -2,
  showContext: -1,
};

// Drawing Tool Types - Use numeric constants
const DrawToolTypes = {
  [DrawTypeConstants.none]: {
    label: 'Stop Drawing',
    value: DrawTypeConstants.none,
  },
  [DrawTypeConstants.line]: { label: 'Segment', value: DrawTypeConstants.line },
  [DrawTypeConstants.horizontalLine]: {
    label: 'Horizontal',
    value: DrawTypeConstants.horizontalLine,
  },
  [DrawTypeConstants.verticalLine]: {
    label: 'Vertical',
    value: DrawTypeConstants.verticalLine,
  },
  [DrawTypeConstants.halfLine]: {
    label: 'Ray',
    value: DrawTypeConstants.halfLine,
  },
  [DrawTypeConstants.parallelLine]: {
    label: 'Channel',
    value: DrawTypeConstants.parallelLine,
  },
  [DrawTypeConstants.rectangle]: {
    label: 'Rect',
    value: DrawTypeConstants.rectangle,
  },
  [DrawTypeConstants.parallelogram]: {
    label: 'Parallelogram',
    value: DrawTypeConstants.parallelogram,
  },
  [DrawTypeConstants.text]: {
    label: 'Text',
    value: DrawTypeConstants.text,
  },
  [DrawTypeConstants.globalHorizontalLine]: {
    label: 'Price Line',
    value: DrawTypeConstants.globalHorizontalLine,
  },
  [DrawTypeConstants.globalHorizontalLineWithLabel]: {
    label: 'Price Line+Text',
    value: DrawTypeConstants.globalHorizontalLineWithLabel,
  },
  [DrawTypeConstants.globalVerticalLine]: {
    label: 'Time Line',
    value: DrawTypeConstants.globalVerticalLine,
  },
  [DrawTypeConstants.candleMarker]: {
    label: 'Candle Marker',
    value: DrawTypeConstants.candleMarker,
  },
};

// Drawing Tool Helper Methods
const DrawToolHelper = {
  name: type => {
    switch (type) {
      case DrawTypeConstants.line:
        return FORMAT('Segment');
      case DrawTypeConstants.horizontalLine:
        return FORMAT('Horizontal');
      case DrawTypeConstants.verticalLine:
        return FORMAT('Vertical');
      case DrawTypeConstants.halfLine:
        return FORMAT('Ray');
      case DrawTypeConstants.parallelLine:
        return FORMAT('Channel');
      case DrawTypeConstants.rectangle:
        return FORMAT('Rect');
      case DrawTypeConstants.parallelogram:
        return FORMAT('Parallelogram');
      case DrawTypeConstants.text:
        return FORMAT('Text');
      case DrawTypeConstants.globalHorizontalLine:
        return FORMAT('Price Line');
      case DrawTypeConstants.globalHorizontalLineWithLabel:
        return FORMAT('Price Line+Text');
      case DrawTypeConstants.globalVerticalLine:
        return FORMAT('Time Line');
      case DrawTypeConstants.candleMarker:
        return FORMAT('Candle Marker');
    }
    return '';
  },

  count: type => {
    if (
      type === DrawTypeConstants.line ||
      type === DrawTypeConstants.horizontalLine ||
      type === DrawTypeConstants.verticalLine ||
      type === DrawTypeConstants.halfLine ||
      type === DrawTypeConstants.rectangle
    ) {
      return 2;
    }
    if (
      type === DrawTypeConstants.parallelLine ||
      type === DrawTypeConstants.parallelogram
    ) {
      return 3;
    }
    // text and other 1-point tools
    if (
      type === DrawTypeConstants.text ||
      type === DrawTypeConstants.globalHorizontalLine ||
      type === DrawTypeConstants.globalHorizontalLineWithLabel ||
      type === DrawTypeConstants.globalVerticalLine ||
      type === DrawTypeConstants.candleMarker
    ) {
      return 1;
    }
    return 0;
  },
};

class App extends Component {
  constructor(props) {
    super(props);

    this.state = {
      isDarkTheme: false,
      selectedTimeType: 2, // 1m
      selectedMainIndicator: 1, // MA
      selectedSubIndicator: isHorizontalScreen ? 0 : 3, // MACD
      selectedDrawTool: DrawTypeConstants.none,
      showIndicatorSelector: false,
      showTimeSelector: false,
      showDrawToolSelector: false,
      klineData: this.generateMockData(),
      drawShouldContinue: true,
      optionList: null,
      modelArrayJson: null, // data-only payload for native
      savedDrawings: [], // persist all drawings including text
    };
  }

  componentDidMount() {
    this.updateStatusBar();
    // Initialize loading K-line data
    this.reloadKLineData();
  }

  componentDidUpdate(prevProps, prevState) {
    if (prevState.isDarkTheme !== this.state.isDarkTheme) {
      this.updateStatusBar();
    }
  }

  updateStatusBar = () => {
    StatusBar.setBarStyle(
      this.state.isDarkTheme ? 'light-content' : 'dark-content',
      true,
    );
  };

  // Generate mock K-line data
  generateMockData = () => {
    const data = [];
    let lastClose = 50000;
    const now = Date.now();

    for (let i = 0; i < 200; i++) {
      const time = now - (200 - i) * 15 * 60 * 1000; // 15 minute interval

      // Next open equals previous close, ensuring continuity
      const open = lastClose;

      // Generate reasonable high/low prices
      const volatility = 0.02; // 2% volatility
      const change = (Math.random() - 0.5) * open * volatility;
      const close = Math.max(open + change, open * 0.95); // Max drop 5%

      // Ensure high >= max(open, close), low <= min(open, close)
      const maxPrice = Math.max(open, close);
      const minPrice = Math.min(open, close);
      const high = maxPrice + Math.random() * open * 0.01; // At most 1% higher
      const low = minPrice - Math.random() * open * 0.01; // At most 1% lower

      const volume = (0.5 + Math.random()) * 1000000; // Volume between 500k and 1.5m

      data.push({
        time: time,
        open: parseFloat(open.toFixed(2)),
        high: parseFloat(high.toFixed(2)),
        low: parseFloat(low.toFixed(2)),
        close: parseFloat(close.toFixed(2)),
        volume: parseFloat(volume.toFixed(2)),
      });

      lastClose = close;
    }

    return data;
  };

  // Toggle Theme
  toggleTheme = () => {
    this.setState({ isDarkTheme: !this.state.isDarkTheme }, () => {
      // Reload data after theme switch to apply new colors
      this.reloadKLineData();
    });
  };

  // Select Time Period
  selectTimeType = timeType => {
    this.setState(
      {
        selectedTimeType: timeType,
        showTimeSelector: false,
      },
      () => {
        // Regenerate data and reload
        this.setState({ klineData: this.generateMockData() }, () => {
          this.reloadKLineData();
        });
      },
    );
    console.log('Switch Time Period:', TimeTypes[timeType].label);
  };

  // Select Indicator
  selectIndicator = (type, indicator) => {
    if (type === 'main') {
      this.setState({ selectedMainIndicator: indicator }, () => {
        this.reloadKLineData();
      });
    } else {
      this.setState({ selectedSubIndicator: indicator }, () => {
        this.reloadKLineData();
      });
    }
    this.setState({ showIndicatorSelector: false });
  };

  // Select Drawing Tool
  selectDrawTool = tool => {
    this.setState({
      selectedDrawTool: tool,
      showDrawToolSelector: false,
    });
    this.setOptionList({
      drawList: {
        shouldReloadDrawItemIndex:
          tool === DrawTypeConstants.none
            ? DrawStateConstants.none
            : DrawStateConstants.showContext,
        drawShouldContinue: this.state.drawShouldContinue,
        drawType: tool,
        shouldFixDraw: false,
      },
    });
  };

  // Clear Drawings
  clearDrawings = () => {
    this.setState(
      {
        selectedDrawTool: DrawTypeConstants.none,
      },
      () => {
        this.setOptionList({
          drawList: {
            shouldReloadDrawItemIndex: DrawStateConstants.none,
            shouldClearDraw: true,
          },
        });
      },
    );
  };

  // Reload K-Line Data
  reloadKLineData = () => {
    if (!this.kLineViewRef) {
      setTimeout(() => this.reloadKLineData(), 100);
      return;
    }

    const processedData = this.processKLineData(this.state.klineData);
    const optionList = this.packOptionList();
    this.setState({
      optionList: JSON.stringify(optionList),
      modelArrayJson: JSON.stringify(processedData),
    });
  };

  // Process K-line data, add technical indicator calculation
  processKLineData = rawData => {
    // Mock symbol configuration
    const symbol = {
      price: 2, // Price precision
      volume: 0, // Volume precision
    };
    const priceCount = symbol.price;
    const volumeCount = symbol.volume;

    // Get target configuration
    const targetList = this.getTargetList();

    // Calculate all technical indicators
    let processedData = rawData.map(item => ({
      ...item,
      id: item.time,
      open: item.open,
      high: item.high,
      low: item.low,
      close: item.close,
      vol: item.volume,
    }));

    // Calculate technical indicators based on targetList config
    processedData = this.calculateIndicatorsFromTargetList(
      processedData,
      targetList,
    );

    return processedData.map((item, index) => {
      // Time Formatting
      let time = formatTime(item.id, 'MM-DD HH:mm');

      // Calculate change amount and percentage
      let appendValue = item.close - item.open;
      let appendPercent = (appendValue / item.open) * 100;
      let isAppend = appendValue >= 0;
      let prefixString = isAppend ? '+' : '-';
      let appendValueString =
        prefixString + fixRound(Math.abs(appendValue), priceCount, true, false);
      let appendPercentString =
        prefixString + fixRound(Math.abs(appendPercent), 2, true, false) + '%';

      // Color Configuration
      const theme = ThemeManager.getCurrentTheme(this.state.isDarkTheme);
      let color = isAppend
        ? processColor(theme.increaseColor)
        : processColor(theme.decreaseColor);

      // Add formatted fields
      item.dateString = `${time}`;
      item.selectedItemList = [
        { title: FORMAT('Time'), detail: `${time}` },
        {
          title: FORMAT('Open'),
          detail: fixRound(item.open, priceCount, true, false),
        },
        {
          title: FORMAT('High'),
          detail: fixRound(item.high, priceCount, true, false),
        },
        {
          title: FORMAT('Low'),
          detail: fixRound(item.low, priceCount, true, false),
        },
        {
          title: FORMAT('Close'),
          detail: fixRound(item.close, priceCount, true, false),
        },
        { title: FORMAT('Change'), detail: appendValueString, color },
        { title: FORMAT('Change%'), detail: appendPercentString, color },
        {
          title: FORMAT('Vol'),
          detail: fixRound(item.vol, volumeCount, true, false),
        },
      ];

      // Add technical indicator display info to selectedItemList
      this.addIndicatorToSelectedList(item, targetList, priceCount);

      return item;
    });
  };

  // Pack Option List (configuration only, without modelArray)
  packOptionList = () => {
    const theme = ThemeManager.getCurrentTheme(this.state.isDarkTheme);

    // Basic Configuration
    const pixelRatio = Platform.select({
      android: PixelRatio.get(),
      ios: 1,
    });

    const configList = {
      colorList: {
        increaseColor: processColor(theme.increaseColor),
        decreaseColor: processColor(theme.decreaseColor),
      },
      targetColorList: [
        processColor(COLOR(0.96, 0.86, 0.58)),
        processColor(COLOR(0.38, 0.82, 0.75)),
        processColor(COLOR(0.8, 0.57, 1)),
        processColor(COLOR(1, 0.23, 0.24)),
        processColor(COLOR(0.44, 0.82, 0.03)),
        processColor(COLOR(0.44, 0.13, 1)),
      ],
      minuteLineColor: processColor(theme.minuteLineColor),
      minuteGradientColorList: [
        processColor(COLOR(0.094117647, 0.341176471, 0.831372549, 0.149019608)), // 15% opacity blue
        processColor(COLOR(0.266666667, 0.501960784, 0.97254902, 0.149019608)), // 26% opacity blue
        processColor(COLOR(0.074509804, 0.121568627, 0.188235294, 0)), // Fully transparent
        processColor(COLOR(0.074509804, 0.121568627, 0.188235294, 0)), // Fully transparent
      ],
      minuteGradientLocationList: [0, 0.3, 0.6, 1],
      backgroundColor: processColor(theme.backgroundColor),
      textColor: processColor(theme.detailColor),
      gridColor: processColor(theme.gridColor),
      candleTextColor: processColor(theme.titleColor),
      panelBackgroundColor: processColor(
        this.state.isDarkTheme
          ? COLOR(0.03, 0.09, 0.14, 0.9)
          : COLOR(1, 1, 1, 0.95),
      ), // 95% opacity
      panelBorderColor: processColor(theme.detailColor),
      panelTextColor: processColor(theme.titleColor),
      selectedPointContainerColor: processColor('transparent'),
      selectedPointContentColor: processColor(
        this.state.isDarkTheme ? theme.titleColor : 'white',
      ),
      closePriceCenterBackgroundColor: processColor(theme.backgroundColor9703),
      closePriceCenterBorderColor: processColor(theme.textColor7724),
      closePriceCenterTriangleColor: processColor(theme.textColor7724),
      closePriceCenterSeparatorColor: processColor(theme.detailColor),
      closePriceRightBackgroundColor: processColor(theme.backgroundColor),
      closePriceRightSeparatorColor: processColor(theme.backgroundColorBlue),
      closePriceRightLightLottieFloder: 'images',
      closePriceRightLightLottieScale: 0.4,
      panelGradientColorList: this.state.isDarkTheme
        ? [
            processColor(COLOR(0.0588235, 0.101961, 0.160784, 0.2)),
            processColor(COLOR(0.811765, 0.827451, 0.913725, 0.101961)),
            processColor(COLOR(0.811765, 0.827451, 0.913725, 0.2)),
            processColor(COLOR(0.811765, 0.827451, 0.913725, 0.101961)),
            processColor(COLOR(0.0784314, 0.141176, 0.223529, 0.2)),
          ]
        : [
            processColor(COLOR(1, 1, 1, 0)),
            processColor(COLOR(0.54902, 0.623529, 0.678431, 0.101961)),
            processColor(COLOR(0.54902, 0.623529, 0.678431, 0.25098)),
            processColor(COLOR(0.54902, 0.623529, 0.678431, 0.101961)),
            processColor(COLOR(1, 1, 1, 0)),
          ],
      panelGradientLocationList: [0, 0.25, 0.5, 0.75, 1],
      mainFlex:
        this.state.selectedSubIndicator === 0
          ? isHorizontalScreen
            ? 0.75
            : 0.85
          : 0.6,
      volumeFlex: isHorizontalScreen ? 0.25 : 0.15,
      paddingTop: 20 * pixelRatio,
      paddingBottom: 20 * pixelRatio,
      paddingRight: 50 * pixelRatio,
      itemWidth: 8 * pixelRatio,
      candleWidth: 6 * pixelRatio,
      minuteVolumeCandleColor: processColor(
        COLOR(0.0941176, 0.509804, 0.831373, 0.501961),
      ),
      minuteVolumeCandleWidth: 2 * pixelRatio,
      macdCandleWidth: 1 * pixelRatio,
      headerTextFontSize: 10 * pixelRatio,
      rightTextFontSize: 10 * pixelRatio,
      candleTextFontSize: 10 * pixelRatio,
      panelTextFontSize: 10 * pixelRatio,
      panelMinWidth: 130 * pixelRatio,
      fontFamily: Platform.select({
        ios: 'DINPro-Medium',
        android: '',
      }),
      closePriceRightLightLottieSource: '',
    };

    // Use unified target configuration
    const targetList = this.getTargetList();

    let drawList = {
      shotBackgroundColor: processColor(theme.backgroundColor),
      // Basic Drawing Configuration
      drawType: this.state.selectedDrawTool,
      shouldReloadDrawItemIndex: DrawStateConstants.showContext,
      drawShouldContinue: this.state.drawShouldContinue,
      drawColor: processColor(COLOR(1, 0.46, 0.05)),
      drawLineHeight: 2,
      drawDashWidth: 4,
      drawDashSpace: 4,
      drawIsLock: false,
      shouldFixDraw: false,
      shouldClearDraw: false,
      // Text annotation defaults (can be overridden per item)
      textColor: processColor(theme.titleColor),
      textBackgroundColor: processColor(
        this.state.isDarkTheme ? COLOR(0, 0, 0, 0.8) : COLOR(1, 1, 1, 0.9),
      ),
      textCornerRadius: 8,
      // Pre-insert saved drawings (including text) back into the chart
      drawItemList: this.state.savedDrawings,
    };

    return {
      shouldScrollToEnd: true,
      targetList: targetList,
      price: 2, // Price precision
      volume: 0, // Volume precision
      primary: this.state.selectedMainIndicator,
      second: this.state.selectedSubIndicator,
      time: TimeTypes[this.state.selectedTimeType].value,
      configList: configList,
      drawList: drawList,
    };
  };

  // Set optionList property
  setOptionList = optionList => {
    this.setState({
      optionList: JSON.stringify(optionList),
    });
  };

  // Indicator Judgment Helper Methods
  isMASelected = () => this.state.selectedMainIndicator === 1;
  isBOLLSelected = () => this.state.selectedMainIndicator === 2;
  isMACDSelected = () => this.state.selectedSubIndicator === 3;
  isKDJSelected = () => this.state.selectedSubIndicator === 4;
  isRSISelected = () => this.state.selectedSubIndicator === 5;
  isWRSelected = () => this.state.selectedSubIndicator === 6;

  // Get Target Configuration List
  getTargetList = () => {
    return {
      maList: [
        { title: '5', selected: this.isMASelected(), index: 0 },
        { title: '10', selected: this.isMASelected(), index: 1 },
        { title: '20', selected: this.isMASelected(), index: 2 },
      ],
      maVolumeList: [
        { title: '5', selected: true, index: 0 },
        { title: '10', selected: true, index: 1 },
      ],
      bollN: '20',
      bollP: '2',
      macdS: '12',
      macdL: '26',
      macdM: '9',
      kdjN: '9',
      kdjM1: '3',
      kdjM2: '3',
      rsiList: [
        { title: '6', selected: this.isRSISelected(), index: 0 },
        { title: '12', selected: this.isRSISelected(), index: 1 },
        { title: '24', selected: this.isRSISelected(), index: 2 },
      ],
      wrList: [{ title: '14', selected: this.isWRSelected(), index: 0 }],
    };
  };

  // Calculate Technical Indicators Based on Target Config
  calculateIndicatorsFromTargetList = (data, targetList) => {
    let processedData = [...data];

    // Calculate MA Indicator
    const selectedMAPeriods = targetList.maList
      .filter(item => item.selected)
      .map(item => ({ period: parseInt(item.title, 10), index: item.index }));

    if (selectedMAPeriods.length > 0) {
      processedData = this.calculateMAWithConfig(
        processedData,
        selectedMAPeriods,
      );
    }

    // Calculate Volume MA Indicator
    const selectedVolumeMAPeriods = targetList.maVolumeList
      .filter(item => item.selected)
      .map(item => ({ period: parseInt(item.title, 10), index: item.index }));

    if (selectedVolumeMAPeriods.length > 0) {
      processedData = this.calculateVolumeMAWithConfig(
        processedData,
        selectedVolumeMAPeriods,
      );
    }

    // Calculate BOLL Indicator
    if (this.isBOLLSelected()) {
      processedData = calculateBOLL(
        processedData,
        parseInt(targetList.bollN, 10),
        parseInt(targetList.bollP, 10),
      );
    }

    // Calculate MACD Indicator
    if (this.isMACDSelected()) {
      processedData = calculateMACD(
        processedData,
        parseInt(targetList.macdS, 10),
        parseInt(targetList.macdL, 10),
        parseInt(targetList.macdM, 10),
      );
    }

    // Calculate KDJ Indicator
    if (this.isKDJSelected()) {
      processedData = calculateKDJ(
        processedData,
        parseInt(targetList.kdjN, 10),
        parseInt(targetList.kdjM1, 10),
        parseInt(targetList.kdjM2, 10),
      );
    }

    // Calculate RSI Indicator
    const selectedRSIPeriods = targetList.rsiList
      .filter(item => item.selected)
      .map(item => ({ period: parseInt(item.title, 10), index: item.index }));

    if (selectedRSIPeriods.length > 0) {
      processedData = this.calculateRSIWithConfig(
        processedData,
        selectedRSIPeriods,
      );
    }

    // Calculate WR Indicator
    const selectedWRPeriods = targetList.wrList
      .filter(item => item.selected)
      .map(item => ({ period: parseInt(item.title, 10), index: item.index }));

    if (selectedWRPeriods.length > 0) {
      processedData = this.calculateWRWithConfig(
        processedData,
        selectedWRPeriods,
      );
    }

    return processedData;
  };

  // Calculate MA Indicator Based on Config
  calculateMAWithConfig = (data, periodConfigs) => {
    return data.map((item, index) => {
      const maList = new Array(3); // Fixed 3 positions

      periodConfigs.forEach(config => {
        if (index < config.period - 1) {
          maList[config.index] = {
            value: item.close,
            title: `${config.period}`,
          };
        } else {
          let sum = 0;
          for (let i = index - config.period + 1; i <= index; i++) {
            sum += data[i].close;
          }
          maList[config.index] = {
            value: sum / config.period,
            title: `${config.period}`,
          };
        }
      });

      return { ...item, maList };
    });
  };

  // Calculate Volume MA Indicator Based on Config
  calculateVolumeMAWithConfig = (data, periodConfigs) => {
    return data.map((item, index) => {
      const maVolumeList = new Array(2); // Fixed 2 positions

      periodConfigs.forEach(config => {
        if (index < config.period - 1) {
          maVolumeList[config.index] = {
            value: item.volume,
            title: `${config.period}`,
          };
        } else {
          let sum = 0;
          for (let i = index - config.period + 1; i <= index; i++) {
            sum += data[i].volume;
          }
          maVolumeList[config.index] = {
            value: sum / config.period,
            title: `${config.period}`,
          };
        }
      });

      return { ...item, maVolumeList };
    });
  };

  // Calculate RSI Indicator Based on Config
  calculateRSIWithConfig = (data, periodConfigs) => {
    return data.map((item, index) => {
      if (index === 0) {
        const rsiList = new Array(3); // Fixed 3 positions
        periodConfigs.forEach(config => {
          rsiList[config.index] = {
            value: 50,
            index: config.index,
            title: `${config.period}`,
          };
        });
        return { ...item, rsiList };
      }

      const rsiList = new Array(3); // Fixed 3 positions
      periodConfigs.forEach(config => {
        if (index < config.period) {
          rsiList[config.index] = {
            value: 50,
            index: config.index,
            title: `${config.period}`,
          };
          return;
        }

        let gains = 0;
        let losses = 0;

        for (let i = index - config.period + 1; i <= index; i++) {
          const change = data[i].close - data[i - 1].close;
          if (change > 0) gains += change;
          else losses += Math.abs(change);
        }

        const avgGain = gains / config.period;
        const avgLoss = losses / config.period;
        const rs = avgLoss === 0 ? 100 : avgGain / avgLoss;
        const rsi = 100 - 100 / (1 + rs);

        rsiList[config.index] = {
          value: rsi,
          index: config.index,
          title: `${config.period}`,
        };
      });

      return { ...item, rsiList };
    });
  };

  // Calculate WR Indicator Based on Config
  calculateWRWithConfig = (data, periodConfigs) => {
    return data.map((item, index) => {
      const wrList = new Array(1); // Fixed 1 position

      periodConfigs.forEach(config => {
        if (index < config.period - 1) {
          wrList[config.index] = {
            value: -50,
            index: config.index,
            title: `${config.period}`,
          };
          return;
        }

        // Find highest and lowest price in period
        let highest = -Infinity;
        let lowest = Infinity;

        for (let i = index - config.period + 1; i <= index; i++) {
          highest = Math.max(highest, data[i].high);
          lowest = Math.min(lowest, data[i].low);
        }

        const wr =
          highest === lowest
            ? -50
            : -((highest - item.close) / (highest - lowest)) * 100;
        wrList[config.index] = {
          value: wr,
          index: config.index,
          title: `${config.period}`,
        };
      });

      return { ...item, wrList };
    });
  };

  // Add Technical Indicators to Selected Item List
  addIndicatorToSelectedList = (item, targetList, priceCount) => {
    // Add MA Indicator Display
    if (this.isMASelected() && item.maList) {
      item.maList.forEach((maItem, index) => {
        if (maItem && maItem.title) {
          item.selectedItemList.push({
            title: `MA${maItem.title}`,
            detail: fixRound(maItem.value, priceCount, false, false),
          });
        }
      });
    }

    // Add BOLL Indicator Display
    if (this.isBOLLSelected() && item.bollMb !== undefined) {
      item.selectedItemList.push(
        {
          title: 'UP',
          detail: fixRound(item.bollUp, priceCount, false, false),
        },
        {
          title: 'MB',
          detail: fixRound(item.bollMb, priceCount, false, false),
        },
        {
          title: 'DN',
          detail: fixRound(item.bollDn, priceCount, false, false),
        },
      );
    }

    // Add MACD Indicator Display
    if (this.isMACDSelected() && item.macdDif !== undefined) {
      item.selectedItemList.push(
        { title: 'DIF', detail: fixRound(item.macdDif, 4, false, false) },
        { title: 'DEA', detail: fixRound(item.macdDea, 4, false, false) },
        { title: 'MACD', detail: fixRound(item.macdValue, 4, false, false) },
      );
    }

    // Add KDJ Indicator Display
    if (this.isKDJSelected() && item.kdjK !== undefined) {
      item.selectedItemList.push(
        { title: 'K', detail: fixRound(item.kdjK, 2, false, false) },
        { title: 'D', detail: fixRound(item.kdjD, 2, false, false) },
        { title: 'J', detail: fixRound(item.kdjJ, 2, false, false) },
      );
    }

    // Add RSI Indicator Display
    if (this.isRSISelected() && item.rsiList) {
      item.rsiList.forEach((rsiItem, index) => {
        if (rsiItem && rsiItem.title) {
          item.selectedItemList.push({
            title: `RSI${rsiItem.title}`,
            detail: fixRound(rsiItem.value, 2, false, false),
          });
        }
      });
    }

    // Add WR Indicator Display
    if (this.isWRSelected() && item.wrList) {
      item.wrList.forEach((wrItem, index) => {
        if (wrItem && wrItem.title) {
          item.selectedItemList.push({
            title: `WR${wrItem.title}`,
            detail: fixRound(wrItem.value, 2, false, false),
          });
        }
      });
    }
  };

  // Drawing Item Touch Event
  onDrawItemDidTouch = event => {
    const { nativeEvent } = event;
    console.log('Drawing item touched:', nativeEvent);
  };

  // Drawing Item Move Event (lines/text being dragged)
  onDrawItemMove = event => {
    const { nativeEvent } = event;
    // nativeEvent: { index, drawType, pointList: [{x, y}, ...], text? }
    console.log('Drawing item moved:', nativeEvent);

    // Example: if you keep drawings in state, you can update the moved one here
    // this.setState(prev => {
    //   const saved = [...prev.savedDrawings];
    //   if (nativeEvent.index >= 0 && nativeEvent.index < saved.length) {
    //     saved[nativeEvent.index] = {
    //       ...saved[nativeEvent.index],
    //       ...nativeEvent,
    //     };
    //   }
    //   return { savedDrawings: saved };
    // });
  };

  // Drawing Item Complete Event
  onDrawItemComplete = event => {
    const { nativeEvent } = event;
    console.log('Drawing item complete:', nativeEvent);

    // For text-like annotations, ensure we have some default text so it is visible
    let drawing = nativeEvent;
    if (nativeEvent.drawType === DrawTypeConstants.text && !nativeEvent.text) {
      drawing = { ...nativeEvent, text: 'Text' };
    } else if (
      nativeEvent.drawType === DrawTypeConstants.candleMarker &&
      !nativeEvent.text
    ) {
      // Default label for candle marker, can be customized in real app
      drawing = { ...nativeEvent, text: 'B' };
    }

    // Save all drawings, including text, so they can be restored via drawList.drawItemList
    this.setState(prev => ({
      savedDrawings: [...prev.savedDrawings, drawing],
    }));

    // Processing after drawing completion
    if (!this.state.drawShouldContinue) {
      this.selectDrawTool(DrawTypeConstants.none);
    }
  };

  // Drawing Point Complete Event
  onDrawPointComplete = event => {
    const { nativeEvent } = event;
    console.log('Drawing point complete:', nativeEvent.pointCount);

    // Can display current drawing progress here
    const currentTool = this.state.selectedDrawTool;
    const totalPoints = DrawToolHelper.count(currentTool);

    if (totalPoints > 0) {
      const progress = `${nativeEvent.pointCount}/${totalPoints}`;
      console.log(`Drawing progress: ${progress}`);
    }
  };

  // Reached left edge: load older candles
  onEndReached = () => {
    console.log('Reached start of data, should load older candles');
    // In a real app, trigger your WSS/history request here and prepend data,
    // then call reloadKLineData() or update modelArray via the new prop.
  };

  // Tap on the hover price pill (right side) → create a new order at that price.
  onNewOrder = (price: number) => {
    console.log('onNewOrder price:', price);
  };

  render() {
    const theme = ThemeManager.getCurrentTheme(this.state.isDarkTheme);
    const styles = this.getStyles(theme);

    return (
      <View style={styles.container}>
        {/* Top Toolbar */}
        {this.renderToolbar(styles, theme)}

        {/* K-Line Chart */}
        {this.renderKLineChart(styles, theme)}

        {/* Bottom Control Bar */}
        {this.renderControlBar(styles, theme)}

        {/* Selector Modal */}
        {this.renderSelectors(styles, theme)}
      </View>
    );
  }

  renderToolbar = (styles, theme) => {
    return (
      <View style={styles.toolbar}>
        <Text style={styles.title}>K-Line Chart</Text>
        <View style={styles.toolbarRight}>
          <Text style={styles.themeLabel}>
            {this.state.isDarkTheme ? 'Night' : 'Day'}
          </Text>
          <Switch
            value={this.state.isDarkTheme}
            onValueChange={this.toggleTheme}
            trackColor={{ false: '#E0E0E0', true: theme.buttonColor }}
            thumbColor={this.state.isDarkTheme ? '#FFFFFF' : '#F4F3F4'}
          />
        </View>
      </View>
    );
  };

  renderKLineChart = (styles, theme) => {
    const directRender = (
      <RNKLineView
        ref={ref => {
          this.kLineViewRef = ref;
        }}
        style={styles.chart}
        optionList={this.state.optionList}
        modelArray={this.state.modelArrayJson}
        onNewOrder={this.onNewOrder}
        onDrawItemDidTouch={this.onDrawItemDidTouch}
        onDrawItemMove={this.onDrawItemMove}
        onDrawItemComplete={this.onDrawItemComplete}
        onDrawPointComplete={this.onDrawPointComplete}
        onEndReached={this.onEndReached}
      />
    );
    if (global?.nativeFabricUIManager && Platform.OS == 'ios') {
      return directRender;
    }
    return (
      <View style={{ flex: 1 }} collapsable={false}>
        <View style={{ flex: 1 }} collapsable={false}>
          <View style={styles.chartContainer} collapsable={false}>
            {directRender}
          </View>
        </View>
      </View>
    );
  };

  renderControlBar = (styles, theme) => {
    return (
      <View style={styles.controlBar}>
        <TouchableOpacity
          style={styles.controlButton}
          onPress={() => this.setState({ showTimeSelector: true })}
        >
          <Text style={styles.controlButtonText}>
            {TimeTypes[this.state.selectedTimeType].label}
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.controlButton}
          onPress={() => this.setState({ showIndicatorSelector: true })}
        >
          <Text style={styles.controlButtonText}>
            {IndicatorTypes.main[this.state.selectedMainIndicator].label}/
            {IndicatorTypes.sub[this.state.selectedSubIndicator].label}
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[
            styles.toolbarButton,
            this.state.selectedDrawTool !== DrawTypeConstants.none &&
              styles.activeButton,
          ]}
          onPress={() =>
            this.setState({
              showDrawToolSelector: !this.state.showDrawToolSelector,
              showIndicatorSelector: false,
              showTimeSelector: false,
            })
          }
        >
          <Text
            style={[
              styles.buttonText,
              this.state.selectedDrawTool !== DrawTypeConstants.none &&
                styles.activeButtonText,
            ]}
          >
            {this.state.selectedDrawTool !== DrawTypeConstants.none
              ? DrawToolHelper.name(this.state.selectedDrawTool)
              : 'Draw'}
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.controlButton}
          onPress={this.clearDrawings}
        >
          <Text style={styles.controlButtonText}>Clear</Text>
        </TouchableOpacity>
      </View>
    );
  };

  renderSelectors = (styles, theme) => {
    return (
      <>
        {/* Time Selector */}
        {this.state.showTimeSelector && (
          <View style={styles.selectorOverlay}>
            <View style={styles.selectorModal}>
              <Text style={styles.selectorTitle}>Select Time Period</Text>
              <ScrollView style={styles.selectorList}>
                {Object.keys(TimeTypes).map(timeTypeKey => {
                  const timeType = parseInt(timeTypeKey, 10);
                  return (
                    <TouchableOpacity
                      key={timeType}
                      style={[
                        styles.selectorItem,
                        this.state.selectedTimeType === timeType &&
                          styles.selectedItem,
                      ]}
                      onPress={() => this.selectTimeType(timeType)}
                    >
                      <Text
                        style={[
                          styles.selectorItemText,
                          this.state.selectedTimeType === timeType &&
                            styles.selectedItemText,
                        ]}
                      >
                        {TimeTypes[timeType].label}
                      </Text>
                    </TouchableOpacity>
                  );
                })}
              </ScrollView>
              <TouchableOpacity
                style={styles.closeButton}
                onPress={() => this.setState({ showTimeSelector: false })}
              >
                <Text style={styles.closeButtonText}>Close</Text>
              </TouchableOpacity>
            </View>
          </View>
        )}

        {/* Indicator Selector */}
        {this.state.showIndicatorSelector && (
          <View style={styles.selectorOverlay}>
            <View style={styles.selectorModal}>
              <Text style={styles.selectorTitle}>Select Indicator</Text>
              <ScrollView style={styles.selectorList}>
                {Object.keys(IndicatorTypes).map(type => (
                  <View key={type}>
                    <Text style={styles.selectorSectionTitle}>
                      {type === 'main' ? 'Main' : 'Sub'}
                    </Text>
                    {Object.keys(IndicatorTypes[type]).map(indicatorKey => {
                      const indicator = parseInt(indicatorKey, 10);
                      return (
                        <TouchableOpacity
                          key={indicator}
                          style={[
                            styles.selectorItem,
                            ((type === 'main' &&
                              this.state.selectedMainIndicator === indicator) ||
                              (type === 'sub' &&
                                this.state.selectedSubIndicator ===
                                  indicator)) &&
                              styles.selectedItem,
                          ]}
                          onPress={() => this.selectIndicator(type, indicator)}
                        >
                          <Text
                            style={[
                              styles.selectorItemText,
                              ((type === 'main' &&
                                this.state.selectedMainIndicator ===
                                  indicator) ||
                                (type === 'sub' &&
                                  this.state.selectedSubIndicator ===
                                    indicator)) &&
                                styles.selectedItemText,
                            ]}
                          >
                            {IndicatorTypes[type][indicator].label}
                          </Text>
                        </TouchableOpacity>
                      );
                    })}
                  </View>
                ))}
              </ScrollView>
              <TouchableOpacity
                style={styles.closeButton}
                onPress={() => this.setState({ showIndicatorSelector: false })}
              >
                <Text style={styles.closeButtonText}>Close</Text>
              </TouchableOpacity>
            </View>
          </View>
        )}

        {/* Drawing Tool Selector */}
        {this.state.showDrawToolSelector && (
          <View style={styles.selectorContainer}>
            {Object.keys(DrawToolTypes).map(toolKey => (
              <TouchableOpacity
                key={toolKey}
                style={[
                  styles.selectorItem,
                  this.state.selectedDrawTool === parseInt(toolKey, 10) &&
                    styles.selectedItem,
                ]}
                onPress={() => this.selectDrawTool(parseInt(toolKey, 10))}
              >
                <Text
                  style={[
                    styles.selectorItemText,
                    this.state.selectedDrawTool === parseInt(toolKey, 10) &&
                      styles.selectedItemText,
                  ]}
                >
                  {DrawToolTypes[toolKey].label}
                </Text>
              </TouchableOpacity>
            ))}
            <Text style={styles.selectorItemText}>Continuous Drawing: </Text>
            <Switch
              value={this.state.drawShouldContinue}
              onValueChange={value => {
                this.setState({ drawShouldContinue: value });
              }}
            />
          </View>
        )}
      </>
    );
  };

  getStyles = theme => {
    return StyleSheet.create({
      container: {
        flex: 1,
        backgroundColor: 'red',
        paddingTop: isHorizontalScreen ? 10 : 50,
        paddingBottom: isHorizontalScreen ? 20 : 100,
      },
      toolbar: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        paddingHorizontal: 16,
        paddingVertical: 12,
        backgroundColor: theme.headerColor,
        borderBottomWidth: 1,
        borderBottomColor: theme.gridColor,
      },
      title: {
        fontSize: 18,
        fontWeight: 'bold',
        color: theme.textColor,
      },
      toolbarRight: {
        flexDirection: 'row',
        alignItems: 'center',
      },
      themeLabel: {
        fontSize: 14,
        color: theme.textColor,
        marginRight: 8,
      },
      chartContainer: {
        flex: 1,
        margin: 8,
        borderRadius: 8,
        backgroundColor: theme.backgroundColor,
        borderWidth: 1,
        borderColor: theme.gridColor,
      },
      chart: {
        flex: 1,
        backgroundColor: 'transparent',
      },
      controlBar: {
        flexDirection: 'row',
        justifyContent: 'space-around',
        alignItems: 'center',
        paddingHorizontal: 16,
        paddingVertical: 12,
        backgroundColor: theme.headerColor,
        borderTopWidth: 1,
        borderTopColor: theme.gridColor,
      },
      controlButton: {
        paddingHorizontal: 16,
        paddingVertical: 8,
        borderRadius: 20,
        backgroundColor: theme.buttonColor,
      },
      activeButton: {
        backgroundColor: theme.increaseColor,
      },
      controlButtonText: {
        fontSize: 14,
        color: '#FFFFFF',
        fontWeight: '500',
      },
      activeButtonText: {
        color: '#FFFFFF',
      },
      selectorOverlay: {
        position: 'absolute',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        backgroundColor: 'rgba(0, 0, 0, 0.5)',
        justifyContent: 'center',
        alignItems: 'center',
      },
      selectorModal: {
        width: screenWidth * 0.8,
        maxHeight: screenHeight * 0.6,
        backgroundColor: theme.backgroundColor,
        borderRadius: 12,
        padding: 16,
      },
      selectorTitle: {
        fontSize: 18,
        fontWeight: 'bold',
        color: theme.textColor,
        textAlign: 'center',
        marginBottom: 16,
      },
      selectorList: {
        maxHeight: screenHeight * 0.4,
      },
      selectorSectionTitle: {
        fontSize: 16,
        fontWeight: '600',
        color: theme.textColor,
        marginTop: 12,
        marginBottom: 8,
        paddingHorizontal: 12,
      },
      selectorItem: {
        paddingHorizontal: 16,
        paddingVertical: 12,
        borderRadius: 8,
        marginVertical: 2,
      },
      selectedItem: {
        backgroundColor: theme.buttonColor,
      },
      selectorItemText: {
        fontSize: 16,
        color: theme.textColor,
      },
      selectedItemText: {
        color: '#FFFFFF',
        fontWeight: '500',
      },
      closeButton: {
        marginTop: 16,
        paddingVertical: 12,
        backgroundColor: theme.buttonColor,
        borderRadius: 8,
        alignItems: 'center',
      },
      closeButtonText: {
        fontSize: 16,
        color: '#FFFFFF',
        fontWeight: '500',
      },
      selectorContainer: {
        flexDirection: 'row',
        flexWrap: 'wrap',
        padding: 16,
      },
      toolbarButton: {
        paddingHorizontal: 16,
        paddingVertical: 8,
        borderRadius: 20,
        backgroundColor: theme.buttonColor,
      },
      buttonText: {
        fontSize: 14,
        color: '#FFFFFF',
        fontWeight: '500',
      },
    });
  };
}

export default App;
