//
//  HTKLineView.swift
//  HTKLineView
//
//  Created by hublot on 2020/3/17.
//  Copyright © 2020 hublot. All rights reserved.
//

import UIKit
import Lottie
import ObjectiveC

class HTKLineView: UIScrollView, UIGestureRecognizerDelegate {
        
    weak var containerView: HTKLineContainerView?
    var configManager: HTKLineConfigManager
    
    lazy var drawContext: HTDrawContext = {
        let drawContext = HTDrawContext.init(self, configManager)
        return drawContext
    }()

    var visibleRange = 0...0

    var selectedIndex = -1

    /// When selecting via long-press, we snap X to the nearest candle (selectedIndex),
    /// but keep Y free so the user can drag vertically to inspect arbitrary prices.
    /// Stored in view coordinates (same space as drawing).
    var selectedY: CGFloat = .nan

    // While long-press hovering, temporarily disable scrolling so the scroll view pan
    // doesn’t steal the gesture (and clear selection via scroll callbacks).
    private var wasScrollEnabledBeforeLongPress: Bool = true

    // Hit target for the right-side hover price pill (used to trigger `onNewOrder`).
    private var selectedPricePillRect: CGRect = .zero
    private var selectedPriceValue: CGFloat = .nan

    var scale: CGFloat = 1

    // --- Right y-axis drag scaling (vertical zoom) ---
    private var isMainScaleFixed: Bool = false
    private var fixedMainMaxValue: CGFloat = .nan
    private var fixedMainMinValue: CGFloat = .nan
    private var yAxisScaleStartY: CGFloat = .nan
    private var yAxisScaleStartMax: CGFloat = .nan
    private var yAxisScaleStartMin: CGFloat = .nan
    private var yAxisScaleVisibleHigh: CGFloat = .nan
    private var yAxisScaleVisibleLow: CGFloat = .nan
    private let yAxisGestureWidth: CGFloat = 64
    private let yAxisGestureSensitivityFactor: CGFloat = 0.7

    private lazy var yAxisPanGesture: UIPanGestureRecognizer = {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(yAxisPanSelector(_:)))
        pan.maximumNumberOfTouches = 1
        pan.delegate = self
        return pan
    }()

    private lazy var longPressGesture: UILongPressGestureRecognizer = {
        let g = UILongPressGestureRecognizer(target: self, action: #selector(longPressSelector(_:)))
        g.delegate = self
        // Be a bit more forgiving of tiny finger jitter while waiting for the long press.
        g.allowableMovement = 20
        return g
    }()

    let mainDraw = HTMainDraw.init()

    let volumeDraw = HTVolumeDraw.init()

    let macdDraw = HTMacdDraw.init()

    let kdjDraw = HTKdjDraw.init()

    let rsiDraw = HTRsiDraw.init()

    let wrDraw = HTWrDraw.init()

    var childDraw: HTKLineDrawProtocol?

    var animationView = LottieAnimationView()

    // Optional logo image drawn in the center of the main chart, behind candles.
    // Backed by a base64 string in configManager.centerLogoSource.
    private var centerLogoImage: UIImage?
    private var lastCenterLogoSource: String = ""

    var lastLoadAnimationSource = ""





    // 计算属性
    var visibleModelArray = [HTKLineModel]()
    var volumeRange: ClosedRange<CGFloat> = 0...0
    var allWidth: CGFloat = 0
    var allHeight: CGFloat = 0
    var mainMinMaxRange = Range<CGFloat>.init(uncheckedBounds: (lower: 0, upper: 0))
    var textHeight: CGFloat  = 0
    var mainBaseY: CGFloat  = 0
    var mainHeight: CGFloat  = 0
    var volumeMinMaxRange = Range<CGFloat>.init(uncheckedBounds: (lower: 0, upper: 0))
    var volumeBaseY: CGFloat  = 0
    var volumeHeight: CGFloat  = 0
    var childMinMaxRange = Range<CGFloat>.init(uncheckedBounds: (lower: 0, upper: 0))
    var childBaseY: CGFloat  = 0
    var childHeight: CGFloat  = 0




    init(_ frame: CGRect, _ configManager: HTKLineConfigManager) {
        self.configManager = configManager
        super.init(frame: frame)
        delegate = self
        bounces = false
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        backgroundColor = UIColor.clear

        addGestureRecognizer(longPressGesture)
        addGestureRecognizer(UITapGestureRecognizer.init(target: self, action: #selector(tapSelector)))
        addGestureRecognizer(UIPinchGestureRecognizer.init(target: self, action: #selector(pinchSelector)))
        addGestureRecognizer(yAxisPanGesture)

        // Prefer long-press hover over horizontal scrolling. This prevents the scroll view pan
        // from beginning immediately (due to tiny finger movement) and causing long-press to fail.
        panGestureRecognizer.require(toFail: longPressGesture)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reloadConfigManager(_ configManager: HTKLineConfigManager) {

        switch configManager.childType {
        case .none:
            childDraw = nil
        case .macd:
            childDraw = macdDraw
        case .kdj:
            childDraw = kdjDraw
        case .rsi:
            childDraw = rsiDraw
        case .wr:
            childDraw = wrDraw
        }

        let isEnd = contentOffset.x + 1 + bounds.size.width >= contentSize.width
        reloadContentSize()

        if (configManager.shouldScrollToEnd || isEnd) {
            let toEndContentOffset = contentSize.width - bounds.size.width
            let distance = abs(contentOffset.x - toEndContentOffset)
            let animated = distance <= configManager.itemWidth
            reloadContentOffset(toEndContentOffset, animated)
        }

        scrollViewDidScroll(self)

        // (1) Reload/prepare the Lottie "live price" animation when source changes.
        if lastLoadAnimationSource != configManager.closePriceRightLightLottieSource {
        lastLoadAnimationSource = configManager.closePriceRightLightLottieSource

        DispatchQueue.global().async { [weak self] in
                guard
                    let this = self,
                    let data = this.configManager.closePriceRightLightLottieSource.data(using: String.Encoding.utf8),
                    let animation = try? JSONDecoder().decode(LottieAnimation.self, from: data)
                else {
                return
            }
            DispatchQueue.main.async {
                this.animationView.animation = animation
                this.animationView.loopMode = .loop
                this.animationView.play()
                var size = animation.size
                let scale = this.configManager.closePriceRightLightLottieScale
                size.width *= scale
                size.height *= scale
                this.animationView.frame.size = size
                this.animationView.isHidden = true
                this.addSubview(this.animationView)
                this.setNeedsDisplay()
                }
            }
        }

        // (2) Decode / cache the center logo image (if any) when its source changes.
        let logoSource = configManager.centerLogoSource
        if logoSource != lastCenterLogoSource {
            lastCenterLogoSource = logoSource
            centerLogoImage = nil

            guard !logoSource.isEmpty else {
                return
            }

            // Accept either a bare base64 string or a data-URL string.
            var base64String = logoSource
            if let range = base64String.range(of: ",") {
                base64String = String(base64String[range.upperBound...])
            }

            if let data = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters) {
                centerLogoImage = UIImage(data: data)
            }
        }
    }

    func reloadContentSize() {
        configManager.reloadScrollViewScale(scale)
        // Content width is determined by candle count plus the configured right padding
        let contentWidth = configManager.itemWidth * CGFloat(configManager.modelArray.count) + configManager.paddingRight
        contentSize = CGSize(width: contentWidth, height: frame.size.height)
    }

    func reloadContentOffset(_ contentOffsetX: CGFloat, _ animated: Bool = false) {
        let offsetX = max(0, min(contentOffsetX, contentSize.width - bounds.size.width))
        setContentOffset(CGPoint.init(x: offsetX, y: 0), animated: animated)
    }
    

    func contextTranslate(_ context: CGContext, _ x: CGFloat, _ block: (CGContext) -> Void) {
        context.saveGState()
        context.translateBy(x: x, y: 0)
        block(context)
        context.restoreGState()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), configManager.modelArray.count > 0 else {
            return
        }

        calculateBaseHeight()

        // Draw center logo (if provided) behind all candles/lines but inside the main chart area.
        drawCenterLogo(in: context)

        contextTranslate(context, CGFloat(visibleRange.lowerBound) * configManager.itemWidth, { context in
            drawCandle(context)
        })

        contextTranslate(context, contentOffset.x, { context in
//            context.setFillColor(UIColor.red.withAlphaComponent(0.1).cgColor)
//            context.fill(CGRect.init(x: 0, y: mainBaseY, width: allWidth, height: mainHeight))

            drawText(context)
            drawValue(context)



            drawHighLow(context)
            drawTime(context)
            drawClosePrice(context)
            // Draw user drawings (lines/labels/etc.) below the hover selector overlays.
            // This ensures the right-side hover price pill is always rendered on top.
            drawContext.draw(contentOffset.x)
            drawSelectedLine(context)
            drawSelectedBoard(context)
            drawSelectedTime(context)
        })

        
    }

    func calculateBaseHeight() {
        self.visibleModelArray = configManager.modelArray.count > 0 ? Array(configManager.modelArray[visibleRange]) : configManager.modelArray
        // Layout:
        // - main section: [0 .. mainBoundary)
        // - volume section: [mainBoundary .. volumeBoundary) (optional)
        // - child section: [volumeBoundary .. 1]
        //
        // When volume is hidden, we "merge" volumeFlex into the main chart so the
        // main area expands and the child area stays the same size.
        let mainBoundary = configManager.mainFlex + (configManager.showVolume ? 0 : configManager.volumeFlex)
        let volumeBoundary = mainBoundary + (configManager.showVolume ? configManager.volumeFlex : 0)
        self.volumeRange = mainBoundary...volumeBoundary
        
        self.allHeight = self.bounds.size.height - configManager.paddingBottom
        self.allWidth = self.bounds.size.width
        
        // Auto range (includes MA/BOLL etc), then optionally override with fixed y-axis scale.
        let autoMainRange = mainDraw.minMaxRange(visibleModelArray, configManager)

        // Candle extremes (used to prevent clipping when zooming in via y-axis drag).
        var candleHigh: CGFloat = CGFloat.leastNormalMagnitude
        var candleLow: CGFloat = CGFloat.greatestFiniteMagnitude
        for model in visibleModelArray {
            candleHigh = max(candleHigh, model.high)
            candleLow = min(candleLow, model.low)
        }
        if candleHigh <= candleLow {
            candleHigh = autoMainRange.upperBound
            candleLow = autoMainRange.lowerBound
        }

        if isMainScaleFixed, fixedMainMaxValue.isFinite, fixedMainMinValue.isFinite {
            var maxV = fixedMainMaxValue
            var minV = fixedMainMinValue
            // Never clip the highest/lowest visible candle.
            if maxV < candleHigh { maxV = candleHigh }
            if minV > candleLow { minV = candleLow }
            if maxV <= minV { maxV = minV + 1e-6 }
            fixedMainMaxValue = maxV
            fixedMainMinValue = minV
            self.mainMinMaxRange = Range<CGFloat>(uncheckedBounds: (lower: minV, upper: maxV))
        } else {
            // Keep auto range as baseline for future y-axis drags.
            fixedMainMaxValue = autoMainRange.upperBound
            fixedMainMinValue = autoMainRange.lowerBound
            self.mainMinMaxRange = autoMainRange
        }
        self.textHeight = mainDraw.textHeight(font: UIFont.systemFont(ofSize: 11)) / 2
        self.mainBaseY = configManager.paddingTop - textHeight
        self.mainHeight = allHeight * volumeRange.lowerBound - mainBaseY - textHeight
        
        if configManager.showVolume {
            self.volumeMinMaxRange = volumeDraw.minMaxRange(visibleModelArray, configManager)
            self.volumeBaseY = allHeight * volumeRange.lowerBound + configManager.headerHeight + textHeight
            self.volumeHeight = allHeight * (volumeRange.upperBound - volumeRange.lowerBound) - configManager.headerHeight - textHeight
        } else {
            self.volumeMinMaxRange = Range<CGFloat>.init(uncheckedBounds: (lower: 0, upper: 0))
            self.volumeBaseY = allHeight * volumeRange.lowerBound
            self.volumeHeight = 0
        }
        
        self.childMinMaxRange = childDraw?.minMaxRange(visibleModelArray, configManager) ?? Range<CGFloat>.init(uncheckedBounds: (lower: 0, upper: 0))
        self.childBaseY = allHeight * volumeRange.upperBound + configManager.headerHeight + textHeight
        self.childHeight = allHeight * (1 - volumeRange.upperBound) - configManager.headerHeight - textHeight
        
    }

    private func isInRightYAxisArea(_ point: CGPoint) -> Bool {
        // Only allow scaling in the main chart vertical span.
        let mainTop = mainBaseY
        let mainBottom = mainBaseY + mainHeight
        if point.y < mainTop || point.y > mainBottom {
            return false
        }
        // Hit target on the far right where y-axis labels are drawn.
        let width = max(yAxisGestureWidth, configManager.paddingRight)
        return point.x >= (bounds.size.width - width)
    }

    // Only begin our y-axis pan when user drags vertically inside the right y-axis region.
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === yAxisPanGesture {
            let p = gestureRecognizer.location(in: self)
            guard isInRightYAxisArea(p) else { return false }
            let v = (gestureRecognizer as? UIPanGestureRecognizer)?.velocity(in: self) ?? .zero
            return abs(v.y) > abs(v.x)
        }
        if gestureRecognizer === longPressGesture {
            let p = gestureRecognizer.location(in: self)
            // Never allow the long-press hover selector to start from the y-axis area.
            return !isInRightYAxisArea(p)
        }
        return true
    }

    // Prevent scroll view's own pan from competing when we are handling y-axis scaling.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === yAxisPanGesture || otherGestureRecognizer === yAxisPanGesture {
            return false
        }
        return true
    }

    @objc private func yAxisPanSelector(_ pan: UIPanGestureRecognizer) {
        let point = pan.location(in: self)

        switch pan.state {
        case .began:
            guard isInRightYAxisArea(point) else { return }

            // Initialize from current visible range (auto or fixed).
            yAxisScaleStartY = point.y
            yAxisScaleStartMax = mainMinMaxRange.upperBound
            yAxisScaleStartMin = mainMinMaxRange.lowerBound

            // Visible candle extremes for clamp (never clip).
            var candleHigh: CGFloat = CGFloat.leastNormalMagnitude
            var candleLow: CGFloat = CGFloat.greatestFiniteMagnitude
            for model in visibleModelArray {
                candleHigh = max(candleHigh, model.high)
                candleLow = min(candleLow, model.low)
            }
            if candleHigh <= candleLow {
                candleHigh = yAxisScaleStartMax
                candleLow = yAxisScaleStartMin
            }
            yAxisScaleVisibleHigh = candleHigh
            yAxisScaleVisibleLow = candleLow

            isMainScaleFixed = true
            fixedMainMaxValue = yAxisScaleStartMax
            fixedMainMinValue = yAxisScaleStartMin
            setNeedsDisplay()

        case .changed:
            guard isMainScaleFixed, yAxisScaleStartY.isFinite else { return }

            let dy = point.y - yAxisScaleStartY
            var baseRange = yAxisScaleStartMax - yAxisScaleStartMin
            if baseRange <= 0 {
                baseRange = max(1e-6, yAxisScaleVisibleHigh - yAxisScaleVisibleLow)
            }
            let minRange = max(1e-6, yAxisScaleVisibleHigh - yAxisScaleVisibleLow)
            // Cap zoom-out: max zoom-out range is 10x the max zoom-in range
            // (i.e. max zoom-in range is 10% of max zoom-out range).
            let maxZoomOutRange = minRange / 0.10

            let denom = max(1, mainHeight * yAxisGestureSensitivityFactor)
            let factor = exp(dy / denom) // dy>0 => zoom out (range bigger)
            let minFactor = minRange / baseRange
            let clampedFactor = max(factor, minFactor)
            var newRange = baseRange * clampedFactor
            // Absolute clamp so zoom-out stops at a sensible limit.
            if newRange > maxZoomOutRange { newRange = maxZoomOutRange }
            let center = (yAxisScaleStartMax + yAxisScaleStartMin) / 2
            var newMax = center + newRange / 2
            var newMin = center - newRange / 2

            // Never clip candle extremes.
            if newMax < yAxisScaleVisibleHigh {
                newMax = yAxisScaleVisibleHigh
                newMin = newMax - newRange
            }
            if newMin > yAxisScaleVisibleLow {
                newMin = yAxisScaleVisibleLow
                newMax = newMin + newRange
            }
            if newMax <= newMin { newMax = newMin + 1e-6 }

            fixedMainMaxValue = newMax
            fixedMainMinValue = newMin
            setNeedsDisplay()

        case .ended, .cancelled, .failed:
            yAxisScaleStartY = .nan
            setNeedsDisplay()
        default:
            break
        }
    }

    /// Draw a semi-transparent logo image centered in the main chart area, behind candles.
    private func drawCenterLogo(in context: CGContext) {
        guard
            let image = centerLogoImage,
            mainHeight > 0,
            allWidth > 0
        else {
            return
        }

        // Constrain logo size relative to chart dimensions (e.g. at most ~35% of width/height).
        let maxLogoWidth = allWidth * 0.35
        let maxLogoHeight = mainHeight * 0.35
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else {
            return
        }

        let widthScale = maxLogoWidth / imageSize.width
        let heightScale = maxLogoHeight / imageSize.height
        let scale = min(widthScale, heightScale, 1.0)

        let drawWidth = imageSize.width * scale
        let drawHeight = imageSize.height * scale
        
        // Keep the logo visually fixed in the center of the viewport while the
        // candles (scrollable content) move underneath it.
        //
        // The scroll view exposes content in the range
        // [contentOffset.x, contentOffset.x + bounds.width]. To pin the logo to
        // the visual center of the screen, we place it at:
        //   worldX = contentOffset.x + (bounds.width - logoWidth) / 2
        // so that on-screen X is always (bounds.width - logoWidth) / 2.
        let originX = contentOffset.x + (allWidth - drawWidth) / 2.0
        let originY = mainBaseY + (mainHeight - drawHeight) / 2.0
        let drawRect = CGRect(x: originX, y: originY, width: drawWidth, height: drawHeight)

        context.saveGState()
        // Light transparency so candles and grid remain clearly visible.
        context.setAlpha(0.10)
        image.draw(in: drawRect)
        context.restoreGState()
    }

    func yFromValue(_ value: CGFloat) -> CGFloat {
        let scale = (mainMinMaxRange.upperBound - mainMinMaxRange.lowerBound) / mainHeight
        var y = mainBaseY + mainHeight * 0.5
        if (scale != 0) {
            y = mainBaseY + (mainMinMaxRange.upperBound - value) / scale
        }
        return y
    }
    
    func valueFromY(_ y: CGFloat) -> CGFloat {
        let scale = (mainMinMaxRange.upperBound - mainMinMaxRange.lowerBound) / mainHeight
        var value = scale * mainHeight * 0.5
        if (scale != 0) {
            value = mainMinMaxRange.upperBound - (y - mainBaseY) * scale
        }
        return value
    }
    
    func xFromValue(_ value: CGFloat) -> CGFloat {
        guard let firstItem = configManager.modelArray.first, let lastItem = configManager.modelArray.last else {
            return 0
        }
        let scale = (lastItem.id - firstItem.id) / (configManager.itemWidth * CGFloat(configManager.modelArray.count - 1))
        let x = (value - firstItem.id) / scale + configManager.itemWidth / 2.0 - contentOffset.x
        return x
    }
    
    func valueFromX(_ x: CGFloat) -> CGFloat {
        guard let firstItem = configManager.modelArray.first, let lastItem = configManager.modelArray.last else {
            return 0
        }
        let scale = (lastItem.id - firstItem.id) / (configManager.itemWidth * CGFloat(configManager.modelArray.count - 1))
        let value = scale * (x + contentOffset.x - configManager.itemWidth / 2.0) + firstItem.id
        return value
    }

    func drawCandle(_ context: CGContext) {
        if (configManager.isMinute) {
            mainDraw.drawGradient(visibleModelArray, mainMinMaxRange.upperBound, mainMinMaxRange.lowerBound, allWidth, mainBaseY, mainHeight, context, configManager)
        }

        for (i, model) in visibleModelArray.enumerated() {
            mainDraw.drawCandle(model, i, mainMinMaxRange.upperBound, mainMinMaxRange.lowerBound, mainBaseY, mainHeight, context, configManager)
            if configManager.showVolume {
                volumeDraw.drawCandle(model, i, volumeMinMaxRange.upperBound, volumeMinMaxRange.lowerBound, volumeBaseY, volumeHeight, context, configManager)
            }
            childDraw?.drawCandle(model, i, childMinMaxRange.upperBound, childMinMaxRange.lowerBound, childBaseY, childHeight, context, configManager)

            let lastIndex = i == 0 ? i : i - 1
            let lastModel = visibleModelArray[lastIndex]
            mainDraw.drawLine(model, lastModel, mainMinMaxRange.upperBound, mainMinMaxRange.lowerBound, mainBaseY, mainHeight, i, lastIndex, context, configManager)
            if configManager.showVolume {
                volumeDraw.drawLine(model, lastModel, volumeMinMaxRange.upperBound, volumeMinMaxRange.lowerBound, volumeBaseY, volumeHeight, i, lastIndex, context, configManager)
            }
            childDraw?.drawLine(model, lastModel, childMinMaxRange.upperBound, childMinMaxRange.lowerBound, childBaseY, childHeight, i, lastIndex, context, configManager)
        }
    }

    func drawText(_ context: CGContext) {
        var model = visibleModelArray.last
        if visibleRange.contains(selectedIndex) {
            model = visibleModelArray[selectedIndex - visibleRange.lowerBound]
        }
        if let model = model {
            let baseX: CGFloat = 5
            mainDraw.drawText(model, baseX, 10, context, configManager)
            if configManager.showVolume {
                volumeDraw.drawText(model, baseX, volumeBaseY - configManager.headerHeight, context, configManager)
            }
            childDraw?.drawText(model, baseX, childBaseY - configManager.headerHeight, context, configManager)
        }
    }

    func drawValue(_ context: CGContext) {
        let baseX = self.allWidth
        mainDraw.drawValue(mainMinMaxRange.upperBound, mainMinMaxRange.lowerBound, baseX, mainBaseY, mainHeight, context, configManager)
        if configManager.showVolume {
            volumeDraw.drawValue(volumeMinMaxRange.upperBound, volumeMinMaxRange.lowerBound, baseX, volumeBaseY, volumeHeight, context, configManager)
        }
        childDraw?.drawValue(childMinMaxRange.upperBound, childMinMaxRange.lowerBound, baseX, childBaseY, childHeight, context, configManager)

    }

    func drawTime(_ context: CGContext) {
        let count = 6
        let valueDistance = self.allWidth / CGFloat(count - 1)
        for i in 0..<count {
            let font = configManager.createFont(configManager.candleTextFontSize)
            let x = valueDistance * CGFloat(i)
            let itemNumber = (x - 1 + contentOffset.x) / configManager.itemWidth
            var itemIndex = Int(ceil(itemNumber))
            itemIndex -= 1
            itemIndex -= visibleRange.lowerBound
            itemIndex = max(0, itemIndex)
            if (itemIndex >= visibleModelArray.count) {
                continue
            }
            let item = visibleModelArray[itemIndex]
            let title = item.dateString
            let width = mainDraw.textWidth(title: title, font: font)
            let height = mainDraw.textHeight(font: font)
            let y = childBaseY + childHeight + (configManager.paddingBottom - height) / 2
            mainDraw.drawText(title: title, point: CGPoint.init(x: x - width / 2.0, y: y), color: configManager.textColor, font: font, context: context, configManager: configManager)
        }
    }

    func drawHighLow(_ context: CGContext) {
        guard !configManager.isMinute else {
            return
        }
        var highIndex = 0
        var lowIndex = 0
        for (i, model) in visibleModelArray.enumerated() {
            if (model.high > visibleModelArray[highIndex].high) {
                highIndex = i
            }
            if (model.low < visibleModelArray[lowIndex].low) {
                lowIndex = i
            }
        }

        let drawValue: (Int, CGFloat) -> Void = { [weak self] (index, value) in
            guard let this = self else {
                return
            }

            var title = this.configManager.precision(value, this.configManager.price)
            let font = this.configManager.createFont(this.configManager.candleTextFontSize)
            let lineString = "--"
            let offset = CGFloat(index + this.visibleRange.lowerBound) * this.configManager.itemWidth - this.contentOffset.x
            let halfWidth = this.allWidth / 2
            var x = offset + this.configManager.itemWidth / 2

            var y = this.yFromValue(value)
            if (offset < halfWidth) {
                title = lineString + title
            } else {
                title = title + lineString
                x -= this.mainDraw.textWidth(title: title, font: font)
            }
            y -= this.mainDraw.textHeight(font: font) / 2
            y -= 1
            this.mainDraw.drawText(title: title, point: CGPoint.init(x: x, y: y), color: this.configManager.candleTextColor, font: font, context: context, configManager: this.configManager)
        }
        drawValue(highIndex, visibleModelArray[highIndex].high)
        drawValue(lowIndex, visibleModelArray[lowIndex].low)

    }

    func drawClosePrice(_ context: CGContext) {
        guard let lastModel = configManager.modelArray.last else {
            return
        }
        let offset = CGFloat(visibleRange.upperBound) * configManager.itemWidth - contentOffset.x
        let valueWidth = mainDraw.textWidth(title: configManager.precision(lastModel.close, configManager.price), font: configManager.createFont(configManager.rightTextFontSize))
        let showCenter = offset > allWidth - valueWidth - configManager.itemWidth
        animationView.isHidden = true
        if (showCenter) {
            drawClosePriceCenter(context, lastModel)
        } else {
            drawClosePriceRight(context, lastModel, offset)
        }
    }

    func drawClosePriceCenter(_ context: CGContext, _ lastModel: HTKLineModel) {
        let title = configManager.precision(lastModel.close, configManager.price)
        let font = configManager.createFont(configManager.candleTextFontSize)
        let width = mainDraw.textWidth(title: title, font: font)
        let height = mainDraw.textHeight(font: font)
        let paddingHorizontal: CGFloat = 7
        let paddingVertical: CGFloat = 5
        let triangleWidth: CGFloat = 5
        let triangleHeight: CGFloat = 7
        let triangleMarginLeft: CGFloat = 3
        let x = allWidth - configManager.paddingRight
        let rectHeight = height + paddingVertical * 2
        let y = max(mainBaseY - textHeight + rectHeight / 2, min(mainBaseY + mainHeight + textHeight - rectHeight / 2, yFromValue(lastModel.close)))
        let rectWidth = paddingHorizontal + width + triangleMarginLeft + triangleWidth + paddingHorizontal
        let rect = CGRect.init(x: x - rectWidth / 2, y: y - height / 2 - paddingVertical, width: rectWidth, height: rectHeight)

        context.saveGState()
        context.setLineDash(phase: 0, lengths: [4, 4])
        context.setStrokeColor(configManager.closePriceCenterSeparatorColor.cgColor)
        context.setLineWidth(configManager.lineWidth / 2)
        context.addLines(between: [CGPoint.init(x: 0, y: y), CGPoint.init(x: allWidth, y: y)])
        context.strokePath()
        context.restoreGState()

        let rectPath = UIBezierPath.init(roundedRect: rect, cornerRadius: rect.size.height / 2)
        context.setFillColor(configManager.closePriceCenterBackgroundColor.cgColor)
        context.addPath(rectPath.cgPath)
        context.fillPath()
        context.setStrokeColor(configManager.closePriceCenterBorderColor.cgColor)
        context.addPath(rectPath.cgPath)
        context.strokePath()
        mainDraw.drawText(title: title, point: CGPoint.init(x: rect.minX + paddingHorizontal, y: rect.minY + paddingVertical), color: configManager.textColor, font: font, context: context, configManager: configManager)

        let trianglePath = UIBezierPath.init()
        trianglePath.move(to: CGPoint.init(x: rect.maxX - paddingHorizontal, y: y))
        trianglePath.addLine(to: CGPoint.init(x: rect.maxX - paddingHorizontal - triangleWidth, y: y + triangleHeight / 2))
        trianglePath.addLine(to: CGPoint.init(x: rect.maxX - paddingHorizontal - triangleWidth, y: y - triangleHeight / 2))
        trianglePath.close()
        context.setFillColor(configManager.closePriceCenterTriangleColor.cgColor)
        context.addPath(trianglePath.cgPath)
        context.fillPath()
    }

    func drawClosePriceRight(_ context: CGContext, _ lastModel: HTKLineModel, _ offset: CGFloat) {
        let y = yFromValue(lastModel.close)
        context.saveGState()
        context.setLineDash(phase: 0, lengths: [4, 4])
        context.setStrokeColor(configManager.closePriceRightSeparatorColor.cgColor)
        context.setLineWidth(configManager.lineWidth / 2)
        let x = offset + configManager.itemWidth / 2
        context.addLines(between: [CGPoint.init(x: x, y: y), CGPoint.init(x: allWidth, y: y)])
        context.strokePath()
        context.restoreGState()

        let title = configManager.precision(lastModel.close, configManager.price)
        let font = configManager.createFont(configManager.rightTextFontSize)
        let color = configManager.closePriceRightSeparatorColor
        let width = mainDraw.textWidth(title: title, font: font)
        let height = mainDraw.textHeight(font: font)

        let rect = CGRect.init(x: allWidth - width, y: y - height / 2, width: width, height: height)
        context.setFillColor(configManager.closePriceRightBackgroundColor.cgColor)
        context.fill(rect)
        mainDraw.drawText(title: title, point: rect.origin, color: color, font: font, context: context, configManager: configManager)


        if (configManager.isMinute) {
            animationView.isHidden = false
            UIView.animate(withDuration: 0.15) {
                self.animationView.center = CGPoint.init(x: x + self.configManager.itemWidth / 2 + self.contentOffset.x, y: y)
            }
        }
    }

    func drawSelectedLine(_ context: CGContext) {
        guard visibleRange.contains(selectedIndex) else {
            selectedPricePillRect = .zero
            selectedPriceValue = .nan
            return
        }
        let candleClose = visibleModelArray[selectedIndex - visibleRange.lowerBound].close
        let x = (CGFloat(selectedIndex) + 0.5) * configManager.itemWidth - contentOffset.x
        // Allow the crosshair Y to follow the finger, but clamp it to the main chart area
        // so the right-side "price" label remains meaningful.
        let mainTop = mainBaseY
        let mainBottom = mainBaseY + mainHeight
        let y: CGFloat
        if selectedY.isFinite {
            y = max(mainTop, min(mainBottom, selectedY))
        } else {
            y = yFromValue(candleClose)
        }
        let value = valueFromY(y)
        selectedPriceValue = value

        context.setStrokeColor(configManager.candleTextColor.cgColor)
        context.setLineWidth(configManager.lineWidth / 2)
        context.addLines(between: [CGPoint.init(x: 0, y: y), CGPoint.init(x: allWidth, y: y)])
        context.strokePath()

        context.addArc(center: CGPoint.init(x: x, y: y), radius: configManager.candleWidth * 2 / 2, startAngle: 0, endAngle: CGFloat(Double.pi * 2), clockwise: true)
        context.setFillColor(configManager.selectedPointContainerColor.cgColor)
        context.fillPath()
        // Inner (white) dot — keep it intentionally smaller than the outer halo for readability.
        context.addArc(center: CGPoint.init(x: x, y: y), radius: configManager.candleWidth / 2.25 / 2, startAngle: 0, endAngle: CGFloat(Double.pi * 2), clockwise: true)
        context.setFillColor(configManager.selectedPointContentColor.cgColor)
        context.fillPath()

        let colorList = configManager.packGradientColorList(configManager.panelGradientColorList)
        let locationList = configManager.panelGradientLocationList
        if let gradient = CGGradient.init(colorSpace: CGColorSpaceCreateDeviceRGB(), colorComponents: colorList, locations: locationList, count: locationList.count) {
            let start = mainBaseY
            let end = childBaseY + childHeight
            context.addRect(CGRect.init(x: x - configManager.candleWidth / 2, y: start, width: configManager.candleWidth, height: end - start))
            context.clip()
            context.drawLinearGradient(gradient, start: CGPoint.init(x: 0, y: start), end: CGPoint.init(x: 0, y: end), options: .drawsBeforeStartLocation)
            context.resetClip()
        }

        // Right-side hover price pill (always on the right, over the y-axis labels).
        let title = configManager.precision(value, configManager.price)
        let font = configManager.createFont(configManager.candleTextFontSize)
        let textWidth = mainDraw.textWidth(title: title, font: font)
        let textHeight = mainDraw.textHeight(font: font)

        let pillPaddingV: CGFloat = 4
        let pillHeight: CGFloat = max(22, textHeight + pillPaddingV * 2)
        let iconInset: CGFloat = 3
        let showPlus = configManager.showPlusIcon
        let iconAreaWidth: CGFloat = showPlus ? pillHeight : 0 // square area on the left for the plus icon
        let textPaddingH: CGFloat = 8
        let dividerWidth: CGFloat = showPlus ? (1 / UIScreen.main.scale) : 0

        let pillWidth = iconAreaWidth + dividerWidth + textWidth + textPaddingH * 2
        let rightEdge = allWidth
        var pillRect = CGRect(x: rightEdge - pillWidth, y: y - pillHeight / 2, width: pillWidth, height: pillHeight)

        // Clamp vertically inside the view.
        let marginY: CGFloat = 2
        if pillRect.minY < marginY {
            pillRect.origin.y = marginY
        }
        if pillRect.maxY > bounds.size.height - marginY {
            pillRect.origin.y = bounds.size.height - marginY - pillRect.height
        }

        selectedPricePillRect = pillRect

        context.saveGState()

        // Background (white pill) + subtle border.
        let radius = pillRect.height / 2
        let pillPath = UIBezierPath(roundedRect: pillRect, cornerRadius: radius)
        context.setFillColor(UIColor.white.cgColor)
        context.addPath(pillPath.cgPath)
        context.drawPath(using: .fill)

        context.setStrokeColor(UIColor(white: 0.85, alpha: 1).cgColor)
        context.setLineWidth(1 / UIScreen.main.scale)
        context.addPath(pillPath.cgPath)
        context.drawPath(using: .stroke)

        let dividerX = pillRect.minX + iconAreaWidth
        if showPlus {
            // Plus icon: black circle + white plus.
            let iconCenter = CGPoint(x: pillRect.minX + iconAreaWidth / 2, y: pillRect.midY)
            let circleRadius = (pillHeight - iconInset * 2) / 2
            context.addArc(center: iconCenter, radius: circleRadius, startAngle: 0, endAngle: CGFloat(Double.pi * 2), clockwise: true)
            context.setFillColor(UIColor.black.cgColor)
            context.fillPath()

            let plusStroke: CGFloat = max(1.2, circleRadius * 0.18)
            let plusLen: CGFloat = circleRadius * 1.0
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(plusStroke)
            context.setLineCap(.round)
            context.move(to: CGPoint(x: iconCenter.x - plusLen / 2, y: iconCenter.y))
            context.addLine(to: CGPoint(x: iconCenter.x + plusLen / 2, y: iconCenter.y))
            context.move(to: CGPoint(x: iconCenter.x, y: iconCenter.y - plusLen / 2))
            context.addLine(to: CGPoint(x: iconCenter.x, y: iconCenter.y + plusLen / 2))
            context.strokePath()

            // Divider.
            context.setStrokeColor(UIColor(white: 0.85, alpha: 1).cgColor)
            context.setLineWidth(dividerWidth)
            context.move(to: CGPoint(x: dividerX, y: pillRect.minY + 6))
            context.addLine(to: CGPoint(x: dividerX, y: pillRect.maxY - 6))
            context.strokePath()
        }

        // Price text (black).
        let textPoint = CGPoint(
            x: (showPlus ? dividerX : pillRect.minX) + textPaddingH,
            y: pillRect.midY - textHeight / 2
        )
        mainDraw.drawText(title: title, point: textPoint, color: UIColor.black, font: font, context: context, configManager: configManager)

        context.restoreGState()

    }

    func drawSelectedBoard(_ context: CGContext) {
        guard visibleRange.contains(selectedIndex) else {
            return
        }
        guard !configManager.isMinute else {
            return
        }
        let itemList = visibleModelArray[selectedIndex - visibleRange.lowerBound].selectedItemList

        let font = configManager.createFont(configManager.panelTextFontSize)
        let color = configManager.candleTextColor
        let offset = CGFloat(selectedIndex) * configManager.itemWidth - contentOffset.x
        let halfWidth = allWidth / 2
        let leftAlign = offset > halfWidth
        let margin: CGFloat = 5
        let padding: CGFloat = 7
        let lineSpace: CGFloat = 8
        let y = mainBaseY - textHeight + configManager.lineWidth
        var textY = y + padding
        var width = configManager.panelMinWidth
        for item in itemList {
            let title = item["title"] as? String ?? ""
            let detail = item["detail"] as? String ?? ""
            let text = String(format: "%@%@", title, detail)
            let textWidth = mainDraw.textWidth(title: text, font: font)
            let detailHeight = mainDraw.textHeight(font: font)
            width = max(width, textWidth + 20)
            textY += detailHeight
            textY += lineSpace
        }
        // Keep the hover info panel clear of the right-side y-axis labels.
        let axisFont = configManager.createFont(configManager.candleTextFontSize)
        let maxLabel = configManager.precision(mainMinMaxRange.upperBound, configManager.price)
        let minLabel = configManager.precision(mainMinMaxRange.lowerBound, configManager.price)
        let axisLabelWidth = max(
            mainDraw.textWidth(title: maxLabel, font: axisFont),
            mainDraw.textWidth(title: minLabel, font: axisFont)
        )
        let axisInset: CGFloat = axisLabelWidth + 10

        var x = leftAlign ? margin : max(margin, allWidth - width - margin - axisInset)

        // Also keep the hover info panel clear of the hover price pill (+ icon) on the right.
        // drawSelectedLine() runs before drawSelectedBoard(), so `selectedPricePillRect` is already updated.
        let pillGap: CGFloat = 8
        if !selectedPricePillRect.isEmpty {
            x = min(x, max(margin, selectedPricePillRect.minX - pillGap - width))
        }
        context.setFillColor(configManager.panelBackgroundColor.cgColor)
        context.setLineWidth(configManager.lineWidth / 2.0)
        context.setStrokeColor(configManager.panelBorderColor.cgColor)
        let rect = CGRect.init(x: x, y: y, width: width, height: textY - lineSpace + padding - y)
        let bezierPath  = UIBezierPath.init(roundedRect: rect, cornerRadius: 5)
        context.addPath(bezierPath.cgPath)
        context.fillPath()
        context.addPath(bezierPath.cgPath)
        context.strokePath()
        textY = y + padding
        for item in itemList {
            let title = item["title"] as? String ?? ""
            let detail = item["detail"] as? String ?? ""
            let detailColor = item["color"] as? UIColor ?? color
            mainDraw.drawText(title: title, point: CGPoint.init(x: x + padding, y: textY), color: color, font: font, context: context, configManager: configManager)
            let detailWidth = mainDraw.textWidth(title: detail, font: font)
            let detailHeight = mainDraw.textHeight(font: font)
            mainDraw.drawText(title: detail, point: CGPoint.init(x: x + width - padding - detailWidth, y: textY), color: detailColor, font: font, context: context, configManager: configManager)
            textY += detailHeight
            textY += lineSpace
        }
    }

    func drawSelectedTime(_ context: CGContext) {
        guard visibleRange.contains(selectedIndex) else {
            return
        }
        let value = visibleModelArray[selectedIndex - visibleRange.lowerBound].dateString
        let x = (CGFloat(selectedIndex) + 0.5) * configManager.itemWidth - contentOffset.x
        let font = configManager.createFont(configManager.candleTextFontSize)
        let title = value
        let width = mainDraw.textWidth(title: title, font: font)
        let textHeight = mainDraw.textHeight(font: font)

        // Bottom active date (hover mode): pill background (no border), compact height to match x-axis labels.
        let paddingH: CGFloat = 6
        let paddingV: CGFloat = 3
        let cornerRadius: CGFloat = 5

        let rowCenterY = childBaseY + childHeight + configManager.paddingBottom / 2
        let pillHeight = textHeight + paddingV * 2
        let rectY = rowCenterY - pillHeight / 2
        let rect = CGRect(x: x - width / 2 - paddingH, y: rectY, width: width + paddingH * 2, height: pillHeight)

        context.saveGState()
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        // Match the right-side hover price pill background.
        context.setFillColor(UIColor.white.cgColor)
        context.addPath(path.cgPath)
        context.drawPath(using: .fill)
        context.restoreGState()

        // Match the pill text color.
        mainDraw.drawText(
            title: title,
            point: CGPoint(x: x - width / 2.0, y: rectY + paddingV),
            color: .black,
            font: font,
            context: context,
            configManager: configManager
        )
    }
    
    func valuePointFromViewPoint(_ point: CGPoint) -> CGPoint {
        return CGPoint.init(x: valueFromX(point.x), y: valueFromY(point.y))
    }

    func viewPointFromValuePoint(_ point: CGPoint) -> CGPoint {
        return CGPoint.init(x: xFromValue(point.x), y: yFromValue(point.y))
    }
    

}

extension HTKLineView: UIScrollViewDelegate {

    // Use associated storage so we don't change the public API surface.
    private struct AssociatedKeys {
        static var onEndReachedFlag = "ht_onEndReachedFlag"
    }

    private var hasFiredOnEndReached: Bool {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.onEndReachedFlag) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &AssociatedKeys.onEndReachedFlag, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let contentOffsetX = scrollView.contentOffset.x
        var visibleStartIndex = Int(floor(contentOffsetX / configManager.itemWidth))
        var visibleEndIndex = Int(ceil((contentOffsetX + scrollView.bounds.size.width) / configManager.itemWidth))
        visibleStartIndex = min(max(0, visibleStartIndex), configManager.modelArray.count - 1)
        visibleEndIndex = min(max(0, visibleEndIndex), configManager.modelArray.count - 1)
        visibleRange = visibleStartIndex...visibleEndIndex
        self.setNeedsDisplay()

        // When the very first candle becomes visible, consider that "reached the left edge".
        // Using the computed index is more reliable than a strict contentOffset == 0 check
        // which can miss due to float rounding and padding.
        if visibleStartIndex == 0 {
            if !hasFiredOnEndReached {
                hasFiredOnEndReached = true
                containerView?.onEndReached?([:])
            }
        } else {
            // User has scrolled away from the start, so allow the event to fire again
            // next time they come back (after data has been prepended).
            hasFiredOnEndReached = false
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // If the user is hovering via long-press, don't clear selection.
        // (In hover mode we also disable scrolling, but this is an extra safety net.)
        if longPressGesture.state == .began || longPressGesture.state == .changed {
            return
        }
        selectedIndex = -1
        self.setNeedsDisplay()
    }

    @objc
    func longPressSelector(_ gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: self)
        // `location(in: self)` is already in this scroll view’s coordinate space which tracks
        // content (i.e. it naturally reflects scrolling). Do NOT add `contentOffset` again.
        let itemWidth = configManager.itemWidth
        let xInContent = location.x

        if itemWidth > 0, !configManager.modelArray.isEmpty {
            // X snaps to candle index; Y follows the finger (clamped during draw).
            let index = Int(floor(xInContent / itemWidth))
            selectedIndex = max(0, min(index, configManager.modelArray.count - 1))
            selectedY = location.y
        } else {
            selectedIndex = -1
            selectedY = .nan
        }

        // Update continuously while holding/dragging.
        switch gesture.state {
        case .began:
            wasScrollEnabledBeforeLongPress = isScrollEnabled
            isScrollEnabled = false
            setNeedsDisplay()
        case .changed:
            setNeedsDisplay()
        case .ended, .cancelled, .failed:
            isScrollEnabled = wasScrollEnabledBeforeLongPress
            setNeedsDisplay()
        default:
            break
        }
    }

    @objc
    func tapSelector(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)

        // If a hover price pill is visible and tapped, trigger onNewOrder(price) and keep the selector.
        if visibleRange.contains(selectedIndex),
           !selectedPricePillRect.isEmpty,
           selectedPricePillRect.contains(location),
           selectedPriceValue.isFinite {
            containerView?.onNewOrder?([
                "price": Double(selectedPriceValue)
            ])
            return
        }

        // Otherwise, clear selection.
        selectedIndex = -1
        selectedY = .nan
        selectedPricePillRect = .zero
        selectedPriceValue = .nan
        self.setNeedsDisplay()
    }

    @objc
    func pinchSelector(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .changed:
            scale += (gesture.scale - 1) / 10
        default:
            break
        }
        scale = max(0.3, min(scale, 3))

        let width = bounds.size.width
        let halfWidth = width / 2
        let offsetScale = (contentOffset.x + halfWidth) / (contentSize.width - configManager.paddingRight)

        reloadContentSize()
        let contentOffsetX = max(0, min((contentSize.width - configManager.paddingRight) * offsetScale - halfWidth, contentSize.width - width))
        reloadContentOffset(contentOffsetX)
        scrollViewDidScroll(self)
    }

}
