# react-native-kline-view — Developer Guide

A React Native candlestick (K-Line) chart library backed by a native iOS Swift renderer. This guide explains everything you need to know to work on, extend, or integrate the library, even without prior native mobile experience.

---

## Table of Contents

1. [Project Structure](#1-project-structure)
2. [How the Library Works (Big Picture)](#2-how-the-library-works-big-picture)
3. [The JavaScript Layer](#3-the-javascript-layer)
4. [The iOS Native Layer](#4-the-ios-native-layer)
5. [Data Model Reference](#5-data-model-reference)
6. [The `optionList` Config Object](#6-the-optionlist-config-object)
7. [Props & Events Reference](#7-props--events-reference)
8. [Drawing Tools System](#8-drawing-tools-system)
9. [Indicators Reference](#9-indicators-reference)
10. [Running the Example App](#10-running-the-example-app)
11. [Adding a New Feature: Step-by-Step](#11-adding-a-new-feature-step-by-step)
12. [Common Gotchas & Tips](#12-common-gotchas--tips)

---

## 1. Project Structure

```
react-native-kline-view/
├── index.js                        ← JS entry point (the component you import)
├── package.json                    ← Library package config
├── RNKLineView.podspec             ← iOS CocoaPods spec
│
├── ios/
│   └── Classes/
│       ├── Bridge.h                ← Objective-C bridge header (imports React headers)
│       ├── RNKLineView.m           ← ObjC file: declares all props/events to React Native
│       ├── RNKLineView.swift       ← Swift ViewManager: creates the view, sets up queues
│       ├── HTKLineContainerView.swift ← Main UIView: receives JS props, orchestrates everything
│       ├── HTKLineConfigManager.swift ← Holds ALL config state parsed from optionList
│       ├── HTKLineModel.swift      ← Data models: HTKLineModel (candle) + HTKLineItemModel (indicator line)
│       ├── HTKLineView.swift       ← The scrollable chart UIScrollView (renders everything)
│       ├── HTKLineDrawProtocol.swift ← Protocol + shared drawing utilities for all chart sections
│       ├── HTMainDraw.swift        ← Draws main chart area (candles, MA lines, BOLL)
│       ├── HTVolumeDraw.swift      ← Draws volume bars + MA volume lines
│       ├── HTMacdDraw.swift        ← Draws MACD histogram + DIF/DEA lines
│       ├── HTKdjDraw.swift         ← Draws KDJ lines (K, D, J)
│       ├── HTRsiDraw.swift         ← Draws RSI lines
│       ├── HTWrDraw.swift          ← Draws Williams %R lines
│       ├── HTDrawContext.swift     ← Manages drawing tool state + touch routing for annotations
│       ├── HTDrawItem.swift        ← Data model for a single drawing annotation (line, rect, etc.)
│       └── HTShotView.swift        ← Magnifier loupe shown during long-press
│
├── android/
│   └── build.gradle                ← Android build config (Android renderer not yet implemented)
│
└── example/
    ├── App.tsx                     ← Full featured demo app showing all capabilities
    ├── package.json                ← Example app deps (react-native 0.80, react 19)
    ├── ios/                        ← iOS example project (Xcode)
    └── android/                    ← Android example project
```

---

## 2. How the Library Works (Big Picture)

```
JavaScript (React Native)
        │
        │  props: optionList (JSON string), modelArray (JSON string)
        │  events: onNewOrder, onDrawItemComplete, onEndReached, etc.
        ▼
index.js  →  requireNativeComponent('RNKLineView')
        │
        ▼
RNKLineView.m  (Objective-C bridge)
  • Declares every prop and event React Native can pass to native
        │
        ▼
RNKLineView.swift  (Swift ViewManager)
  • Creates HTKLineContainerView as the root UIView
  • Provides a background DispatchQueue for data parsing
        │
        ▼
HTKLineContainerView.swift  (UIView)
  • Receives optionList / modelArray strings as @objc properties
  • Parses JSON on background queue → builds HTKLineConfigManager
  • Routes touch events for drawing tools
  • Fires JS callbacks (onNewOrder, onDrawItemComplete, etc.)
        │
        ▼
HTKLineView.swift  (UIScrollView)
  • Horizontal scroll = pan through candles
  • Pinch = zoom in/out (changes itemWidth/candleWidth via scale)
  • Long-press = hover mode (shows price selector + magnifier)
  • Calls HTMainDraw / HTVolumeDraw / HTMacdDraw / etc. to render each section
        │
        ├── HTMainDraw      → candles + MA/BOLL overlay
        ├── HTVolumeDraw    → volume bars + MA volume
        ├── HTMacdDraw      → MACD histogram + lines
        ├── HTKdjDraw       → KDJ lines
        ├── HTRsiDraw       → RSI lines
        ├── HTWrDraw        → Williams %R lines
        └── HTDrawContext   → overlay for user drawing annotations
```

**Key insight:** All configuration flows through `optionList`, a single JSON string sent from JS to native. Native parses it once, builds `HTKLineConfigManager`, and every drawing class reads from that manager. When you want to change almost anything — colors, visible indicator, candle data, drawing state — you rebuild `optionList` in JS and set it as the prop.

---

## 3. The JavaScript Layer

### `index.js`

This is the only JS file in the library itself. It wraps the native component and normalizes the `onNewOrder` event:

```js
import RNKLineView from 'react-native-kline-view';

<RNKLineView
  style={{ flex: 1 }}
  optionList={JSON.stringify(myOptionList)}
  modelArray={JSON.stringify(myCandles)}   // optional fast-path
  onNewOrder={(price) => console.log('User tapped price:', price)}
  onEndReached={() => loadOlderCandles()}
  onDrawItemComplete={(event) => saveDrawing(event)}
/>
```

### Updating candle data

There are **two ways** to send candle data to the chart:

**Option A — Inside `optionList` (full reload):**
Include `modelArray` as a key inside the `optionList` object. Use this for the initial load or when you change indicators/config at the same time.

**Option B — Via `modelArray` prop directly (fast path):**
After the initial load, update just the candles by setting the `modelArray` prop to a new JSON string. This skips full config parsing and is much faster for live tick updates or pagination. The native side preserves scroll position intelligently (pinned to newest candle if user was at the right edge, or shifted when older candles are prepended).

---

## 4. The iOS Native Layer

### File responsibilities at a glance

| File | What it owns |
|------|-------------|
| `RNKLineView.m` | **The contract**: every prop and event that JS can use must be declared here with `RCT_EXPORT_VIEW_PROPERTY` |
| `RNKLineView.swift` | Minimal ViewManager — creates the view, provides the background queue |
| `HTKLineContainerView.swift` | State machine — receives JS props, parses them, coordinates all sub-views and callbacks |
| `HTKLineConfigManager.swift` | Value object — holds every config value after parsing `optionList` |
| `HTKLineView.swift` | The actual chart — scroll, zoom, long-press hover, calls draw classes |
| `HTKLineDrawProtocol.swift` | Shared drawing math used by all chart section drawers |
| `HTDrawContext.swift` | Overlay drawing state — manages the list of user annotations and their touches |
| `HTDrawItem.swift` | A single drawn annotation (line, text, etc.) with its points and style |

### Adding a new prop to the native view

1. **Declare it in `RNKLineView.m`:**
   ```objc
   RCT_EXPORT_VIEW_PROPERTY(myNewProp, NSString)
   ```

2. **Add an `@objc var` in `HTKLineContainerView.swift`:**
   ```swift
   @objc var myNewProp: String? {
       didSet {
           // React to the new value
       }
   }
   ```

3. **Use it in JS:**
   ```jsx
   <RNKLineView myNewProp="hello" ... />
   ```

### Adding a new event (callback from native → JS)

1. **Declare it in `RNKLineView.m`:**
   ```objc
   RCT_EXPORT_VIEW_PROPERTY(onMyEvent, RCTBubblingEventBlock)
   ```

2. **Add the property in `HTKLineContainerView.swift`:**
   ```swift
   @objc var onMyEvent: RCTBubblingEventBlock?
   ```

3. **Fire it anywhere in native code:**
   ```swift
   self.onMyEvent?(["key": "value"])
   ```

4. **Receive it in JS:**
   ```jsx
   <RNKLineView onMyEvent={(e) => console.log(e.nativeEvent)} ... />
   ```

### The background queue

Data parsing (`optionList` and `modelArray`) runs on `RNKLineView.queue` — a serial background `DispatchQueue`. All UI updates (scroll, redraw) are dispatched back to the main thread. Never touch UIKit directly from that queue.

---

## 5. Data Model Reference

Each candle in `modelArray` is a plain JSON object. All pre-calculated indicator values are included alongside the OHLCV data.

```jsonc
{
  "id": 1700000000,         // Unix timestamp (used as X-axis value)
  "dateString": "11-14 20:00",  // Formatted date for the hover panel
  "open": 36500.00,
  "high": 36800.00,
  "low": 36400.00,
  "close": 36700.00,
  "vol": 1234.56,           // Volume — NOTE: key is "vol", not "volume"

  // Moving Average lines (pre-calculated, one entry per MA period)
  "maList": [
    { "title": "MA5",  "value": 36650.00, "selected": true,  "index": 0 },
    { "title": "MA10", "value": 36580.00, "selected": true,  "index": 1 },
    { "title": "MA20", "value": 36400.00, "selected": false, "index": 2 }
  ],

  // Volume Moving Average lines
  "maVolumeList": [
    { "title": "MA5",  "value": 1100.00, "selected": true, "index": 0 }
  ],

  // Bollinger Bands
  "bollMb": 36500.00,
  "bollUp": 37000.00,
  "bollDn": 36000.00,

  // MACD
  "macdValue": 120.5,   // MACD histogram bar value
  "macdDif": 80.2,      // DIF line
  "macdDea": 70.1,      // DEA line

  // KDJ
  "kdjK": 65.0,
  "kdjD": 60.0,
  "kdjJ": 75.0,

  // RSI (multiple periods, same structure as maList)
  "rsiList": [
    { "title": "RSI6",  "value": 58.0, "selected": true, "index": 0 },
    { "title": "RSI12", "value": 52.0, "selected": true, "index": 1 }
  ],

  // Williams %R
  "wrList": [
    { "title": "WR10", "value": -42.0, "selected": true, "index": 0 }
  ],

  // Extra overlay items shown in hover panel (any custom key-value pairs)
  "selectedItemList": [
    { "title": "Funding", "value": "0.01%", "color": 0xFF4CAF50 }
  ]
}
```

**Important notes:**
- `selected: false` items are filtered out before rendering. Use this to hide a specific MA period without removing it.
- `id` is the X-axis coordinate in value space. It is a `CGFloat` in native, so Unix timestamps work fine.
- All indicator values must be pre-calculated in JavaScript before sending to native. The native layer only renders; it does not compute indicators.
- Colors in `selectedItemList` are ARGB integers: `0xAARRGGBB`. Use React Native's `processColor()` to convert.

---

## 6. The `optionList` Config Object

`optionList` is the single configuration object that controls everything. Pass it as `JSON.stringify(optionList)`.

```js
const optionList = {
  // --- Candle data (use modelArray prop instead for updates) ---
  modelArray: [...],          // Array of candle objects (see section 5)

  // --- Chart mode ---
  time: 60,                   // Candle interval in minutes. Use -1 for minute/line chart mode.
  primary: 1,                 // Main overlay: -1=none, 1=MA, 2=BOLL
  second: 3,                  // Sub-chart: -1=none, 3=MACD, 4=KDJ, 5=RSI, 6=WR
  price: 2,                   // Decimal places for price labels
  volume: 4,                  // Decimal places for volume labels

  // --- Scroll behavior ---
  shouldScrollToEnd: true,    // Auto-scroll to newest candle on load

  // --- Indicator parameters (displayed as labels in the chart header) ---
  targetList: {
    maList:       [{ title: "MA5",  value: 5,  selected: true,  index: 0 },
                   { title: "MA10", value: 10, selected: true,  index: 1 }],
    maVolumeList: [{ title: "MA5",  value: 5,  selected: true,  index: 0 }],
    rsiList:      [{ title: "RSI6", value: 6,  selected: true,  index: 0 }],
    wrList:       [{ title: "WR10", value: 10, selected: true,  index: 0 }],
    bollN: "20", bollP: "2",
    macdS: "12", macdL: "26", macdM: "9",
    kdjN: "9", kdjM1: "3", kdjM2: "3",
  },

  // --- Drawing tool state ---
  drawList: {
    drawType: 0,              // Active drawing type (see HTDrawType enum below)
    drawShouldContinue: false, // Keep drawing after each shape is finished
    drawColor: processColor('#4460FF'),
    drawLineHeight: 1,
    drawDashWidth: 4,
    drawDashSpace: 4,
    drawIsLock: false,
    shouldFixDraw: false,     // Snap all drawing points to valid candle positions
    shouldClearDraw: false,   // Remove all drawings
    shouldReloadDrawItemIndex: -3, // Which drawing item is selected (-3 = none)
    drawShouldTrash: false,   // Delete the currently selected drawing
    shotBackgroundColor: processColor('#1A1A2E'),
    // Pre-load saved drawings:
    drawItemList: [...],      // Array of serialized HTDrawItem objects
  },

  // --- Visual config ---
  configList: {
    itemWidth: 9,             // Total width per candle slot in points
    candleWidth: 7,           // Width of the candle body/bar
    minuteVolumeCandleWidth: 3,
    macdCandleWidth: 3,
    paddingTop: 10,
    paddingRight: 60,         // Right padding (space for price labels)
    paddingBottom: 0,
    mainFlex: 0.6,            // Fraction of chart height for main area
    volumeFlex: 0.15,         // Fraction of chart height for volume area
    headerHeight: 20,         // Height of the text header row

    colorList: {
      increaseColor: processColor('#F0484A'),  // Bullish candle color
      decreaseColor: processColor('#1BAB6B'),  // Bearish candle color
    },

    targetColorList: [        // Colors for indicator lines (index order matters)
      processColor('#F0E442'), // MA1 / MACD DIF / KDJ K / RSI1 / WR1
      processColor('#CC79A7'), // MA2 / MACD DEA / KDJ D / RSI2 / WR2
      processColor('#56B4E9'), // MA3 / KDJ J / RSI3
      processColor('#009E73'), // MA4
      processColor('#D55E00'), // MA5
      processColor('#FF8000'), // MACD bar color (index 5)
    ],

    textColor: processColor('#AAAAAA'),
    candleTextColor: processColor('#FFFFFF'),
    headerTextFontSize: 10,
    rightTextFontSize: 10,
    candleTextFontSize: 10,
    fontFamily: '',           // Custom font name, or '' for system font

    // Hover panel (long-press info popup)
    panelBackgroundColor: processColor('#1E1E2E'),
    panelBorderColor: processColor('#333355'),
    panelGradientColorList: [...],
    panelGradientLocationList: [0, 1],
    panelMinWidth: 120,
    panelTextFontSize: 10,
    selectedPointContainerColor: processColor('#AAAAAA'),
    selectedPointContentColor: processColor('#FFFFFF'),

    // Current close price indicator (center line)
    closePriceCenterSeparatorColor: processColor('#555555'),
    closePriceCenterBackgroundColor: processColor('#1E1E2E'),
    closePriceCenterBorderColor: processColor('#4460FF'),
    closePriceCenterTriangleColor: processColor('#4460FF'),

    // Right-side hover price pill
    closePriceRightSeparatorColor: processColor('#555555'),
    closePriceRightBackgroundColor: processColor('#4460FF'),
    showPlusIcon: true,       // Show "+" icon in the hover price pill

    // Volume section visibility
    showVolume: true,

    // Minute chart gradient fill
    minuteLineColor: processColor('#4460FF'),
    minuteVolumeCandleColor: processColor('#4460FF'),
    minuteGradientColorList: [processColor('#884460FF'), processColor('#004460FF')],
    minuteGradientLocationList: [0, 1],

    // Center logo (base64 PNG shown behind candles)
    centerLogoSource: '',     // base64 string or data-URL

    // Lottie animation on the right price pill (optional)
    closePriceRightLightLottieFloder: '',
    closePriceRightLightLottieScale: 0.4,
    closePriceRightLightLottieSource: '',
  },
};
```

---

## 7. Props & Events Reference

### Props

| Prop | Type | Description |
|------|------|-------------|
| `optionList` | `string` (JSON) | Full configuration including data, indicators, drawing state, and visual config. Triggers a complete re-render. |
| `modelArray` | `string` (JSON) | Fast-path candle data update. Only replaces candle data without re-parsing full config. Preferred for live updates and pagination. |
| `style` | `ViewStyle` | Standard RN style. Set `flex: 1` or explicit `width`/`height`. |

### Events

| Event | Payload | When fired |
|-------|---------|-----------|
| `onNewOrder(price)` | `number` | User taps the "+" icon in the long-press hover price pill. The price is the currently hovered price level. Use this to pre-fill an order form. |
| `onEndReached(event)` | `{}` | User scrolls to the left edge (oldest visible candle). Use this to fetch older candles and prepend to `modelArray`. |
| `onDrawItemDidTouch(event)` | `{ index, id, drawType, drawColor, drawLineHeight, ... }` | User touched an existing drawing. Use the returned style values to populate your editing UI. |
| `onDrawItemComplete(event)` | `{ index, id, drawType, pointList, drawColor, drawLineHeight, drawDashWidth, drawDashSpace, drawIsLock, text, textColor, textBackgroundColor, textCornerRadius, fontSize, position }` | A drawing was finished (all points placed). Persist this to save drawings across sessions. |
| `onDrawItemMove(event)` | `{ index, id, drawType, pointList, text, position }` | Fired continuously while a drawing is being dragged. Use to keep your JS state in sync. |
| `onDrawPointComplete(event)` | `{ pointCount: number }` | Each time a new anchor point is placed during drawing. Use to show a "tap to place next point" hint. |

### Loading older candles (infinite scroll left)

```js
// 1. Set a flag so native knows the next modelArray is a prepend
optionList.drawList = { ..., loadingMoreFromLeft: true }; // Not needed; native handles this internally

// 2. In your onEndReached handler:
const handleEndReached = async () => {
  const olderCandles = await fetchOlderCandles();
  const newCandles = [...olderCandles, ...existingCandles];
  setModelArray(JSON.stringify(newCandles));
  // Native will automatically shift scroll offset to keep current view stable
};
```

---

## 8. Drawing Tools System

### Draw Types (`HTDrawType` / `drawType` integer values)

| Value | Name | Description | Points needed |
|-------|------|-------------|---------------|
| `0` | `none` | No drawing tool active | — |
| `1` | `line` | Line segment between two points | 2 |
| `2` | `horizontalLine` | Horizontal line | 2 |
| `3` | `verticalLine` | Vertical line | 2 |
| `4` | `halfLine` | Ray (extends infinitely in one direction) | 2 |
| `5` | `parallelLine` | Two parallel lines (channel) | 3 |
| `6` | `rectangle` (internal) | Rectangle | 2 |
| `7` | `parallelogram` (internal) | Parallelogram | 3 |
| `101` | `rectangle` | Rectangle via optionList | 2 |
| `102` | `parallelogram` | Parallelogram via optionList | 3 |
| `201` | `text` | Text annotation bubble | 1 |
| `301` | `globalHorizontalLine` | Full-width horizontal price level | 1 |
| `302` | `globalVerticalLine` | Full-height vertical time marker | 1 |
| `303` | `globalHorizontalLineWithLabel` | Horizontal line with text + price labels | 1 |
| `304` | `candleMarker` | Bubble annotation attached to a candle body | 1 |
| `305` | `rightHorizontalLineWithLabel` | Horizontal line from a point to the right edge | 1 |
| `306` | `ruler` | Measures price/time distance between two points | 2 |

### `shouldReloadDrawItemIndex` values

| Value | Meaning |
|-------|---------|
| `-3` (`HTDrawState.none`) | No drawing UI active, chart scrolls normally |
| `-2` (`HTDrawState.showPencil`) | Drawing pencil mode: show tool palette |
| `-1` (`HTDrawState.showContext`) | Context menu shown (global config) |
| `0+` | The drawing at this array index is selected for editing |

### Drawing workflow

```js
// 1. Activate a drawing tool
setOptionList(prev => ({
  ...prev,
  drawList: {
    drawType: 301,                    // globalHorizontalLine
    drawShouldContinue: false,        // stop after placing one line
    shouldReloadDrawItemIndex: -2,    // enter pencil mode
    drawColor: processColor('#FF0000'),
    drawLineHeight: 1,
  }
}));

// 2. User taps the chart — native places the line and fires onDrawItemComplete
const handleDrawComplete = (event) => {
  const { id, drawType, pointList } = event.nativeEvent;
  saveDrawingToStorage({ id, drawType, pointList, ... });
};

// 3. To restore saved drawings next time:
setOptionList(prev => ({
  ...prev,
  drawList: {
    drawItemList: savedDrawings,     // array of serialized drawing objects
    shouldReloadDrawItemIndex: -3,   // read-only, no active tool
  }
}));

// 4. To delete a selected drawing:
setOptionList(prev => ({
  ...prev,
  drawList: {
    shouldReloadDrawItemIndex: selectedIndex,
    drawShouldTrash: true,
  }
}));

// 5. To clear all drawings:
setOptionList(prev => ({
  ...prev,
  drawList: { shouldClearDraw: true }
}));
```

### Serialized drawing item format (for `drawItemList`)

```js
{
  id: "uuid-string",          // Stable ID from onDrawItemComplete
  drawType: 301,
  pointList: [
    { x: 1700000000, y: 36500.0 }  // x = timestamp, y = price
  ],
  drawColor: processColor('#FF0000'),  // ARGB int
  drawLineHeight: 1,
  drawDashWidth: 4,
  drawDashSpace: 4,
  drawIsLock: false,
  // For text annotations:
  text: "My note",
  textColor: processColor('#FFFFFF'),
  textBackgroundColor: processColor('#000000AA'),
  textCornerRadius: 8,
  fontSize: 12,
  // For candleMarker:
  position: "top",             // "top" or "bottom"
}
```

---

## 9. Indicators Reference

All indicators are **pre-calculated in JavaScript** and sent inside each candle object. Native only renders the values.

### Which indicator to show: `primary` and `second`

```
primary (main chart overlay):  -1 = none,  1 = MA,  2 = BOLL
second  (sub-chart):           -1 = none,  3 = MACD, 4 = KDJ, 5 = RSI, 6 = WR
```

### Color mapping for `targetColorList`

The `targetColorList` array is shared across all indicators. Index positions:

| Index | MA | MACD | KDJ | RSI | WR |
|-------|----|----|-----|-----|-----|
| 0 | MA line 1 | DIF | K | RSI 1 | WR 1 |
| 1 | MA line 2 | DEA | D | RSI 2 | WR 2 |
| 2 | MA line 3 | — | J | RSI 3 | — |
| 3 | MA line 4 | — | — | — | — |
| 4 | MA line 5 | — | — | — | — |
| 5 | — | MACD bar | — | — | — |

---

## 10. Running the Example App

### Prerequisites

- macOS with Xcode 14+ installed
- Node.js 18+
- Ruby (for CocoaPods) — use system Ruby or rbenv
- CocoaPods: `sudo gem install cocoapods`
- Yarn: `npm install -g yarn`

### First time setup

```bash
# 1. Install library deps
cd react-native-kline-view
yarn install

# 2. Install example app deps
cd example
yarn install

# 3. Install iOS pods
cd ios
pod install
cd ..

# 4. Run on iOS simulator
yarn ios
# OR open example/ios/ReactNativeKlineExample.xcworkspace in Xcode and press Run
```

### Running on a physical iOS device

Open `example/ios/ReactNativeKlineExample.xcworkspace` in Xcode. Select your device from the device picker. You'll need to sign the app with your Apple ID: go to Signing & Capabilities → Team and select your personal team. Then press Run (⌘R).

### Metro bundler (JS hot reload)

```bash
cd example
yarn start
```

Metro runs on `localhost:8081`. Changes to JS files in `example/App.tsx` hot-reload automatically. Changes to native Swift files require a full Xcode rebuild.

### Android (not yet implemented)

The `android/build.gradle` file exists but the Android renderer is not implemented. Running `yarn android` will fail. iOS only for now.

---

## 11. Adding a New Feature: Step-by-Step

### Example: Add a "show/hide crosshair grid" toggle

**Step 1 — Add config to `HTKLineConfigManager.swift`:**
```swift
var showCrosshairGrid: Bool = true
```

Parse it in `reloadOptionList`:
```swift
showCrosshairGrid = configList["showCrosshairGrid"] as? Bool ?? true
```

**Step 2 — Use it in `HTKLineView.swift`** (wherever crosshair grid lines are drawn):
```swift
if configManager.showCrosshairGrid {
    // draw the grid lines
}
```

**Step 3 — No native prop needed** because this flows through `optionList` → `configList`. The existing `optionList` prop already handles it.

**Step 4 — Use it in JS:**
```js
const optionList = {
  configList: {
    showCrosshairGrid: false,
    // ... rest of config
  }
};
```

---

### Example: Add a new drawing type

**Step 1 — Add to `HTDrawType` enum in `HTDrawItem.swift`:**
```swift
case myNewShape = 400

var count: Int {
    switch self {
    case .myNewShape: return 2  // needs 2 points
    // ...existing cases
    }
}
```

**Step 2 — Handle rendering in `HTDrawContext.swift`** (in the drawing render loop, look for the switch on `drawType`).

**Step 3 — Handle hit testing in `HTDrawItem.swift`** in `beganFillTouchMoveItemPointMapper` if your shape needs custom touch targeting.

**Step 4 — From JS, use `drawType: 400`** in `drawList`.

---

## 12. Common Gotchas & Tips

### Colors must use `processColor()`

All color values passed to native must be ARGB integers. Always use React Native's `processColor()`:
```js
import { processColor } from 'react-native';
increaseColor: processColor('#F0484A')
```
Raw hex strings like `'#F0484A'` will not work.

### `optionList` triggers a full re-render

Every time you change `optionList`, the entire config is re-parsed and `klineView.reloadConfigManager()` is called. For high-frequency updates (live price ticks), use the `modelArray` prop instead to avoid unnecessary work.

### Scroll position is managed automatically

When you prepend older candles (via `onEndReached`), just update `modelArray` and native will shift the scroll offset to keep the currently visible candles in view. You do not need to manually track or restore scroll position.

### The `loadingMoreFromLeft` flag

Native sets this flag internally when `onEndReached` fires. It is reset after the next `modelArray` update. You do not need to set it from JS.

### Drawing `id` is stable across sessions

Every `HTDrawItem` has a `uid` (UUID string). When you receive it in `onDrawItemComplete`, persist it alongside the drawing. When restoring drawings via `drawItemList`, include the same `id` so it maps back to the original item.

### `candleMarker` only needs `x` in `pointList`

For `drawType: 304` (candleMarker), you only need to provide the `x` (timestamp) in `pointList`. Native will automatically snap the `y` coordinate to the top or bottom of the candle body based on the `position` field (`"top"` or `"bottom"`).

### The `selected: false` pattern for indicators

In `maList`, `rsiList`, etc., setting `selected: false` for an item causes native to skip it. This is the correct way to temporarily hide a specific MA period — just mark it `selected: false` rather than removing it from the array, which would shift the color indices and break the `targetColorList` mapping.

### Swift version requirement

The podspec specifies `swift_version = "4.0"` but the code uses modern Swift 5 patterns. If you see build warnings about Swift version, update the podspec to `"5.0"`.

### Lottie dependency

The podspec and `android/build.gradle` both depend on Lottie (for the animated price pill). Make sure your host app's `Podfile` includes Lottie or the pod install will fail:
```ruby
pod 'lottie-ios'
```
