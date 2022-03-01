//
//  TZSegmentedControl.swift
//  Pods
//
//  Created by Tasin Zarkoob on 05/05/17.
//
//

import UIKit

/// Selection Style for the Segmented control
///
/// - Parameter textWidth : Indicator width will only be as big as the text width
/// - Parameter fullWidth : Indicator width will fill the whole segment
/// - Parameter box : A rectangle that covers the whole segment
/// - Parameter arrow : An arrow in the middle of the segment pointing up or down depending
///                     on `TZSegmentedControlSelectionIndicatorLocation`
///
public enum TZSegmentedControlSelectionStyle {
    case textWidth
    case fullWidth
    case box
    case arrow
}

public enum TZSegmentedControlSelectionIndicatorLocation {
    case up
    case down
    case none // No selection indicator
}

public enum TZSegmentedControlSegmentWidthStyle {
    case fixed // Segment width is fixed
    case dynamic // Segment width will only be as big as the text width (including inset)
}

public enum TZSegmentedControlSegmentAlignment {
    case edge // Segments align to the edges of the view
    case center // Selected segments are always centered in the view
}

public enum TZSegmentedControlBorderType {
    case none // 0
    case top // (1 << 0)
    case left // (1 << 1)
    case bottom // (1 << 2)
    case right // (1 << 3)
}

public enum TZSegmentedControlType {
    case text
    case images
    case textImages
    case flexibleTextImages
}

public struct TextImage {
    var text: String?
    var image: UIImage?
    var badge: String?

    public init(text: String? = nil, image: UIImage? = nil, badge: String? = nil) {
        self.text = text
        self.image = image
        self.badge = badge
    }
}

public let TZSegmentedControlNoSegment = -1

public typealias IndexChangeBlock = ((Int) -> Void)
public typealias TZTitleFormatterBlock = ((_ segmentedControl: TZSegmentedControl, _ title: String, _ index: Int, _ selected: Bool) -> NSAttributedString)

open class TZSegmentedControl: UIControl {
    public var sectionTitles: [String]! {
        didSet {
            DispatchQueue.main.async { () -> Void in
                self.updateSegmentsRects()
                self.setNeedsLayout()
                self.setNeedsDisplay()
            }
        }
    }

    public var sectionImages: [UIImage]! {
        didSet {
            DispatchQueue.main.async { () -> Void in
                self.updateSegmentsRects()
                self.setNeedsLayout()
                self.setNeedsDisplay()
            }
        }
    }

    public var sectionItems: [TextImage]! {
        didSet {
            DispatchQueue.main.async { () -> Void in
                self.updateSegmentsRects()
                self.setNeedsLayout()
                self.setNeedsDisplay()
            }
        }
    }

    public var sectionSelectedImages: [UIImage]!

    /// Provide a block to be executed when selected index is changed.
    /// Alternativly, you could use `addTarget:action:forControlEvents:`
    public var indexChangeBlock: IndexChangeBlock?

    /// Used to apply custom text styling to titles when set.
    /// When this block is set, no additional styling is applied to the `NSAttributedString` object
    /// returned from this block.
    public var titleFormatter: TZTitleFormatterBlock? {
        didSet {
            DispatchQueue.main.async { () -> Void in
                self.updateSegmentsRects()
                self.setNeedsLayout()
                self.setNeedsDisplay()
            }
        }
    }

    /// Text attributes to apply to labels of the unselected segments
    public var titleTextAttributes: [NSAttributedString.Key: Any]?

    /// Text attributes to apply to selected item title text.
    /// Attributes not set in this dictionary are inherited from `titleTextAttributes`.
    public var selectedTitleTextAttributes: [NSAttributedString.Key: Any]?

    /// Text attributes to apply to badge text
    public var badgeTextAttributes: [NSAttributedString.Key: Any]? = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12), NSAttributedString.Key.foregroundColor: UIColor.white]

    /// Background color to apply to badge text
    public var badgeBackgroundColor = UIColor.black

    /// Segmented control background color.
    /// Default is `[UIColor whiteColor]`
    override open dynamic var backgroundColor: UIColor! {
        set {
            TZSegmentedControl.appearance().backgroundColor = newValue
        }
        get {
            return TZSegmentedControl.appearance().backgroundColor
        }
    }

    /// Color for the selection indicator stripe
    public var selectionIndicatorColor: UIColor = .black {
        didSet {
            selectionIndicator.backgroundColor = selectionIndicatorColor
            selectionIndicatorBoxColor = selectionIndicatorColor
        }
    }

    public lazy var selectionIndicator: UIView = {
        let selectionIndicator = UIView()
        selectionIndicator.backgroundColor = self.selectionIndicatorColor
        selectionIndicator.translatesAutoresizingMaskIntoConstraints = false
        return selectionIndicator
    }()

    /// Color for the selection indicator box
    /// Default is selectionIndicatorColor
    public var selectionIndicatorBoxColor: UIColor = .black

    /// Color for the vertical divider between segments.
    /// Default is `[UIColor blackColor]`
    public var verticalDividerColor = UIColor.black

    // TODO: Add other visual apperance properities

    /// Specifies the style of the control
    /// Default is `text`
    public var type: TZSegmentedControlType = .text

    /// Specifies the style of the selection indicator.
    /// Default is `textWidth`
    public var selectionStyle: TZSegmentedControlSelectionStyle = .textWidth

    /// Specifies the style of the segment's width.
    /// Default is `fixed`
    public var segmentWidthStyle: TZSegmentedControlSegmentWidthStyle = .fixed {
        didSet {
            if segmentWidthStyle == .dynamic, type == .images {
                segmentWidthStyle = .fixed
            }
        }
    }

    /// Specifies the location of the selection indicator.
    /// Default is `up`
    public var selectionIndicatorLocation: TZSegmentedControlSelectionIndicatorLocation = .down {
        didSet {
            if selectionIndicatorLocation == .none {
                selectionIndicatorHeight = 0.0
            }
        }
    }

    public var segmentAlignment: TZSegmentedControlSegmentAlignment = .edge

    /// Specifies the border type.
    /// Default is `none`
    public var borderType: TZSegmentedControlBorderType = .none {
        didSet {
            setNeedsDisplay()
        }
    }

    /// Specifies the border color.
    /// Default is `black`
    public var borderColor = UIColor.black

    /// Specifies the border width.
    /// Default is `1.0f`
    public var borderWidth: CGFloat = 1.0

    /// Default is NO. Set to YES to show a vertical divider between the segments.
    public var verticalDividerEnabled = false

    /// Index of the currently selected segment.
    public var selectedSegmentIndex: Int = 0

    /// Height of the selection indicator stripe.
    public var selectionIndicatorHeight: CGFloat = 5.0

    public var edgeInset = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
    public var selectionEdgeInset = UIEdgeInsets.zero
    public var verticalDividerWidth = 1.0
    public var selectionIndicatorBoxOpacity: Float = 0.3

    // MARK: Private variable

    internal var selectionIndicatorStripLayer = CALayer()
    internal var selectionIndicatorBoxLayer = CALayer() {
        didSet {
            selectionIndicatorBoxLayer.opacity = selectionIndicatorBoxOpacity
            selectionIndicatorBoxLayer.borderWidth = borderWidth
        }
    }

    internal var selectionIndicatorArrowLayer = CALayer()
    internal var segmentWidth: CGFloat = 0.0
    internal var segmentWidthsArray: [CGFloat] = []
    internal var scrollView: TZScrollView! = {
        let scroll = TZScrollView()
        scroll.scrollsToTop = false
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        return scroll
    }()

    internal var cachedBadge: String? = "0"

    // MARK: - Init Methods

    /// Initialiaze the segmented control with only titles.
    ///
    /// - Parameter sectionTitles: array of strings for the section title
    public convenience init(sectionTitles titles: [String]) {
        self.init()
        setup()
        sectionTitles = titles
        type = .text
        postInitMethod()
    }

    /// Initialiaze the segmented control with only images/icons.
    ///
    /// - Parameter sectionImages: array of images for the section images.
    /// - Parameter selectedImages: array of images for the selected section images.
    public convenience init(sectionImages images: [UIImage], selectedImages sImages: [UIImage]) {
        self.init()
        setup()
        sectionImages = images
        sectionSelectedImages = sImages
        type = .images
        segmentWidthStyle = .fixed
        postInitMethod()
    }

    /// Initialiaze the segmented control with both titles and images/icons.
    ///
    /// - Parameter sectionTitles: array of strings for the section title
    /// - Parameter sectionImages: array of images for the section images.
    /// - Parameter selectedImages: array of images for the selected section images.
    public convenience init(sectionTitles titles: [String], sectionImages images: [UIImage],
                            selectedImages sImages: [UIImage])
    {
        self.init()
        setup()
        sectionTitles = titles
        sectionImages = images
        sectionSelectedImages = sImages
        type = .textImages

        assert(sectionTitles.count == sectionSelectedImages.count, "Titles and images are not in correct count")
        postInitMethod()
    }

    /// Initialiaze the segmented control with titles and images/icons (can missing title or image)
    ///
    /// - Parameter sectionTitles: array of strings for the section title
    /// - Parameter sectionImages: array of images for the section images.
    /// - Parameter selectedImages: array of images for the selected section images.
    public convenience init(sectionTitleImages items: [TextImage]) {
        self.init()
        setup()
        sectionItems = items
        type = .flexibleTextImages

        postInitMethod()
    }

    override open func awakeFromNib() {
        setup()
        postInitMethod()
    }

    private func setup() {
        addSubview(scrollView)
        backgroundColor = UIColor.lightGray
        isOpaque = false
        contentMode = .redraw
    }

    open func postInitMethod() {}

    // MARK: - View LifeCycle

    override open func willMove(toSuperview newSuperview: UIView?) {
        if newSuperview == nil {
            // Control is being removed
            return
        }
        if sectionTitles != nil || sectionImages != nil || sectionItems != nil {
            updateSegmentsRects()
        }
    }

    // MARK: - Drawing

    private func measureTitleAtIndex(index: Int) -> CGSize {
        var text: String?
        if type == .flexibleTextImages {
            if index >= sectionItems.count {
                return CGSize.zero
            }
            text = sectionItems[index].text
        } else {
            if index >= sectionTitles.count {
                return CGSize.zero
            }
            text = sectionTitles[index]
        }

        guard let title = text else {
            return CGSize.zero
        }

        let selected = (index == selectedSegmentIndex)
        var size = CGSize.zero
        if let titleFormatter = titleFormatter {
            size = titleFormatter(self, title, index, selected).size()
        } else {
            var attributes: [NSAttributedString.Key: Any]
            if selected {
                attributes = finalSelectedTitleAttributes()
            } else {
                attributes = finalTitleAttributes()
            }
            size = (title as NSString).size(withAttributes: attributes)
        }
        return size
    }

    private func measureBadgeAtIndex(index: Int) -> CGSize {
        var badge: String?
        if type == .flexibleTextImages {
            if index >= sectionItems.count {
                return CGSize.zero
            }
            badge = sectionItems[index].badge
        }

        guard let text = badge else {
            return CGSize.zero
        }

        var size = (text as NSString).size(withAttributes: badgeTextAttributes)

        return size
    }

    private func attributedTitleAtIndex(index: Int) -> NSAttributedString {
        var text: String?
        if type == .flexibleTextImages {
            if index >= sectionItems.count {
                return NSAttributedString()
            }
            text = sectionItems[index].text
        } else {
            if index >= sectionTitles.count {
                return NSAttributedString()
            }
            text = sectionTitles[index]
        }
        guard let title = text else {
            return NSAttributedString()
        }

        let selected = (index == selectedSegmentIndex)
        var str = NSAttributedString()
        if let titleFormatter = titleFormatter {
            str = titleFormatter(self, title, index, selected)
        } else {
            let attr = selected ? finalSelectedTitleAttributes() : finalTitleAttributes()
            str = NSAttributedString(string: title, attributes: attr)
        }
        return str
    }

    override open func draw(_ rect: CGRect) {
        backgroundColor.setFill()
        UIRectFill(bounds)

        selectionIndicatorArrowLayer.backgroundColor = selectionIndicatorColor.cgColor
        selectionIndicatorStripLayer.backgroundColor = selectionIndicatorColor.cgColor
        selectionIndicatorBoxLayer.backgroundColor = selectionIndicatorBoxColor.cgColor
        selectionIndicatorBoxLayer.borderColor = selectionIndicatorBoxColor.cgColor

        // Remove all sublayers to avoid drawing images over existing ones
        scrollView.layer.sublayers = nil

        let oldrect = rect

        if type == .text {
            if sectionTitles == nil {
                return
            }
            for (index, _) in sectionTitles.enumerated() {
                let size = measureTitleAtIndex(index: index)
                let strWidth = size.width
                let strHeight = size.height
                var rectDiv = CGRect.zero
                var fullRect = CGRect.zero

                // Text inside the CATextLayer will appear blurry unless the rect values are rounded
                let isLocationUp: CGFloat = (selectionIndicatorLocation != .up) ? 0.0 : 1.0
                let isBoxStyle: CGFloat = (selectionStyle != .box) ? 0.0 : 1.0

                let a: CGFloat = (frame.height - (isBoxStyle * selectionIndicatorHeight)) / 2
                let b: CGFloat = (strHeight / 2) + (selectionIndicatorHeight * isLocationUp)
                let yPosition = CGFloat(roundf(Float(a - b)))

                var newRect = CGRect.zero
                if segmentWidthStyle == .fixed {
                    let xPosition = CGFloat((segmentWidth * CGFloat(index)) + (segmentWidth - strWidth) / 2)
                    newRect = CGRect(x: xPosition,
                                     y: yPosition,
                                     width: strWidth,
                                     height: strHeight)
                    rectDiv = calculateRectDiv(at: index, xoffSet: nil)
                    fullRect = CGRect(x: segmentWidth * CGFloat(index), y: 0.0, width: segmentWidth, height: oldrect.size.height)
                } else {
                    // When we are drawing dynamic widths, we need to loop the widths array to calculate the xOffset
                    var xOffset: CGFloat = 0.0
                    var i = 0
                    for width in segmentWidthsArray {
                        if index == i {
                            break
                        }
                        xOffset += width
                        i += 1
                    }

                    let widthForIndex = segmentWidthsArray[index]

                    newRect = CGRect(x: xOffset, y: yPosition, width: widthForIndex, height: strHeight)

                    fullRect = CGRect(x: segmentWidth * CGFloat(index), y: 0.0, width: widthForIndex, height: oldrect.size.height)
                    rectDiv = calculateRectDiv(at: index, xoffSet: xOffset)
                }
                // Fix rect position/size to avoid blurry labels
                newRect = CGRect(x: ceil(newRect.origin.x), y: ceil(newRect.origin.y), width: ceil(newRect.size.width), height: ceil(newRect.size.height))
                let titleLayer = CATextLayer()
                titleLayer.frame = newRect
                titleLayer.alignmentMode = CATextLayerAlignmentMode.center
                if (UIDevice.current.systemVersion as NSString).floatValue < 10.0 {
                    titleLayer.truncationMode = CATextLayerTruncationMode.end
                }
                titleLayer.string = attributedTitleAtIndex(index: index)
                titleLayer.contentsScale = UIScreen.main.scale
                scrollView.layer.addSublayer(titleLayer)

                // Vertical Divider
                addVerticalLayer(at: index, rectDiv: rectDiv)

                addBgAndBorderLayer(with: fullRect)
            }
        } else if type == .images {
            if sectionImages == nil {
                return
            }
            for (index, image) in sectionImages.enumerated() {
                let imageWidth = image.size.width
                let imageHeight = image.size.height

                let a = (frame.height - selectionIndicatorHeight) / 2
                let b = (imageHeight / 2) + (selectionIndicatorLocation == .up ? selectionIndicatorHeight : 0.0)
                let y = CGFloat(roundf(Float(a - b)))
                let x: CGFloat = (segmentWidth * CGFloat(index)) + (segmentWidth - imageWidth) / 2.0
                let newRect = CGRect(x: x, y: y, width: imageWidth, height: imageHeight)

                let imageLayer = CALayer()
                imageLayer.frame = newRect
                imageLayer.contents = image.cgImage

                if selectedSegmentIndex == index, sectionSelectedImages.count > index {
                    let highlightedImage = sectionSelectedImages[index]
                    imageLayer.contents = highlightedImage.cgImage
                }

                scrollView.layer.addSublayer(imageLayer)

                // vertical Divider
                addVerticalLayer(at: index, rectDiv: calculateRectDiv(at: index, xoffSet: nil))

                addBgAndBorderLayer(with: newRect)
            }
        } else if type == .textImages {
            if sectionImages == nil {
                return
            }
            for (index, image) in sectionImages.enumerated() {
                let imageWidth = image.size.width
                let imageHeight = image.size.height

                let stringHeight = measureTitleAtIndex(index: index).height
                let yOffset = CGFloat(roundf(Float(
                    ((frame.height - selectionIndicatorHeight) / 2) - (stringHeight / 2)
                )))

                var imagexOffset: CGFloat = edgeInset.left
                var textxOffset: CGFloat = edgeInset.left

                var textWidth: CGFloat = 0.0
                if segmentWidthStyle == .fixed {
                    imagexOffset = (segmentWidth * CGFloat(index)) + (segmentWidth / 2) - (imageWidth / 2.0)
                    textxOffset = segmentWidth * CGFloat(index)
                    textWidth = segmentWidth
                } else {
                    // When we are drawing dynamic widths, we need to loop the widths array to calculate the xOffset
                    let a = getDynamicWidthTillSegmentIndex(index: index)
                    imagexOffset = a.0 + (a.1 / 2) - (imageWidth / 2)
                    textxOffset = a.0
                    textWidth = segmentWidthsArray[index]
                }

                let imageyOffset = CGFloat(roundf(Float(
                    ((frame.height - selectionIndicatorHeight) / 2) + 8.0)))

                let imageRect = CGRect(x: imagexOffset, y: imageyOffset, width: imageWidth, height: imageHeight)
                var textRect = CGRect(x: textxOffset, y: yOffset, width: textWidth, height: stringHeight)

                // Fix rect position/size to avoid blurry labels
                textRect = CGRect(x: ceil(textRect.origin.x), y: ceil(textRect.origin.y), width: ceil(textRect.size.width), height: ceil(textRect.size.height))

                let titleLayer = CATextLayer()
                titleLayer.frame = textRect
                titleLayer.alignmentMode = CATextLayerAlignmentMode.center
                if (UIDevice.current.systemVersion as NSString).floatValue < 10.0 {
                    titleLayer.truncationMode = CATextLayerTruncationMode.end
                }
                titleLayer.string = attributedTitleAtIndex(index: index)
                titleLayer.contentsScale = UIScreen.main.scale

                let imageLayer = CALayer()
                imageLayer.frame = imageRect
                imageLayer.contents = image.cgImage
                if selectedSegmentIndex == index, sectionSelectedImages.count > index {
                    let highlightedImage = sectionSelectedImages[index]
                    imageLayer.contents = highlightedImage.cgImage
                }

                scrollView.layer.addSublayer(imageLayer)
                scrollView.layer.addSublayer(titleLayer)

                addBgAndBorderLayer(with: imageRect)
            }
        } else if type == .flexibleTextImages {
            if sectionItems == nil {
                return
            }

            for (index, item) in sectionItems.enumerated() {
                let imageWidth = item.image?.size.width ?? 0
                let imageHeight = item.image?.size.height ?? 0

                let stringSize = measureTitleAtIndex(index: index)
                let stringHeight = stringSize.height
                let yOffset = CGFloat(roundf(Float(
                    ((frame.height - selectionIndicatorHeight) / 2) - (stringHeight / 2)
                )))

                var imagexOffset: CGFloat = edgeInset.left
                let padding: CGFloat = 8.0
                var textWidth: CGFloat = stringSize.width
                if segmentWidthStyle == .fixed {
                    imagexOffset = segmentWidth * CGFloat(index) + segmentWidth / 2 - (imageWidth + textWidth + padding) / 2
                } else {
                    // When we are drawing dynamic widths, we need to loop the widths array to calculate the xOffset
                    let a = getDynamicWidthTillSegmentIndex(index: index)
                    imagexOffset = a.0 + segmentWidthsArray[index] / 2 - (imageWidth + textWidth + padding) / 2
                }

                var textxOffset: CGFloat = imagexOffset + padding + imageWidth
                var badgexOffset: CGFloat = imagexOffset + padding + imageWidth + padding + textWidth

                let imageyOffset = CGFloat(roundf(Float(
                    ((frame.height - selectionIndicatorHeight) / 2) - imageHeight / 2)))
                let badgeSize = measureBadgeAtIndex(index: index)
                let badgeWidth = (badgeSize.width + 4) < stringHeight ? stringHeight : (badgeSize.width + 4)
                let badgeHeight = (badgeSize.height + 4) < stringHeight ? stringHeight : (badgeSize.height + 4)

                let imageRect = CGRect(x: imagexOffset, y: imageyOffset, width: imageWidth, height: imageHeight)
                var textRect = CGRect(x: textxOffset, y: yOffset, width: textWidth, height: stringHeight)
                let badgeRect = CGRect(x: badgexOffset, y: yOffset, width: badgeWidth, height: badgeHeight)

                // Fix rect position/size to avoid blurry labels
                textRect = CGRect(x: ceil(textRect.origin.x), y: ceil(textRect.origin.y), width: ceil(textRect.size.width), height: ceil(textRect.size.height))

                let titleLayer = CATextLayer()
                titleLayer.frame = textRect
                titleLayer.alignmentMode = CATextLayerAlignmentMode.center
                if (UIDevice.current.systemVersion as NSString).floatValue < 10.0 {
                    titleLayer.truncationMode = CATextLayerTruncationMode.end
                }
                titleLayer.string = attributedTitleAtIndex(index: index)
                titleLayer.contentsScale = UIScreen.main.scale

                if let image = item.image {
                    let imageLayer = CALayer()
                    imageLayer.frame = imageRect
                    imageLayer.contents = image.cgImage

                    if selectedSegmentIndex == index, sectionItems.count > index {
                        if let highlightedImage = sectionItems[index].image {
                            imageLayer.contents = highlightedImage.cgImage
                        }
                    }

                    scrollView.layer.addSublayer(imageLayer)
                }

                if let badge = item.badge {
                    let badgeLayer = CenteredVeritcalCATextLayer()
                    badgeLayer.frame = badgeRect
                    badgeLayer.string = NSAttributedString(string: badge, attributes: badgeTextAttributes)
                    badgeLayer.cornerRadius = stringHeight / 2
                    badgeLayer.backgroundColor = badgeBackgroundColor.cgColor
                    badgeLayer.alignmentMode = .center
                    badgeLayer.contentsScale = UIScreen.main.scale

                    scrollView.layer.addSublayer(badgeLayer)

                    if cachedBadge != item.badge {
                        badgeLayer.makePulsate()
                        cachedBadge = item.badge
                    }
                }

                scrollView.layer.addSublayer(titleLayer)
                addBgAndBorderLayer(with: imageRect)
            }
        }

        // Add the selection indicators
        if selectedSegmentIndex != TZSegmentedControlNoSegment {
            if selectionStyle == .arrow {
                if selectionIndicatorArrowLayer.superlayer == nil {
                    setArrowFrame()
                    scrollView.layer.addSublayer(selectionIndicatorArrowLayer)
                }
            } else {
                if selectionIndicatorStripLayer.superlayer == nil {
                    selectionIndicatorStripLayer.frame = frameForSelectionIndicator()
                    scrollView.layer.addSublayer(selectionIndicatorStripLayer)

                    if selectionStyle == .box, selectionIndicatorBoxLayer.superlayer == nil {
                        selectionIndicatorBoxLayer.frame = frameForFillerSelectionIndicator()
                        selectionIndicatorBoxLayer.opacity = selectionIndicatorBoxOpacity
                        scrollView.layer.insertSublayer(selectionIndicatorBoxLayer, at: 0)
                    }
                }
            }
        }
    }

    private func calculateRectDiv(at index: Int, xoffSet: CGFloat?) -> CGRect {
        var a: CGFloat
        if xoffSet != nil {
            a = xoffSet!
        } else {
            a = segmentWidth * CGFloat(index)
        }
        let xPosition = CGFloat(a - CGFloat(verticalDividerWidth / 2))
        let rectDiv = CGRect(x: xPosition,
                             y: selectionIndicatorHeight * 2,
                             width: CGFloat(verticalDividerWidth),
                             height: frame.size.height - (selectionIndicatorHeight * 4))
        return rectDiv
    }

    // Add Vertical Divider Layer
    private func addVerticalLayer(at index: Int, rectDiv: CGRect) {
        if verticalDividerEnabled, index > 0 {
            let vDivLayer = CALayer()
            vDivLayer.frame = rectDiv
            vDivLayer.backgroundColor = verticalDividerColor.cgColor
            scrollView.layer.addSublayer(vDivLayer)
        }
    }

    private func addBgAndBorderLayer(with rect: CGRect) {
        // Background layer
        let bgLayer = CALayer()
        bgLayer.frame = rect
        layer.insertSublayer(bgLayer, at: 0)

        // Border layer
        if borderType != .none {
            let borderLayer = CALayer()
            borderLayer.backgroundColor = borderColor.cgColor
            var borderRect = CGRect.zero
            switch borderType {
            case .top:
                borderRect = CGRect(x: 0, y: 0, width: rect.size.width, height: borderWidth)
            case .left:
                borderRect = CGRect(x: 0, y: 0, width: borderWidth, height: rect.size.height)
            case .bottom:
                borderRect = CGRect(x: 0, y: rect.size.height, width: rect.size.width, height: borderWidth)
            case .right:
                borderRect = CGRect(x: 0, y: rect.size.width, width: borderWidth, height: rect.size.height)
            case .none:
                break
            }
            borderLayer.frame = borderRect
            bgLayer.addSublayer(borderLayer)
        }
    }

    private func setArrowFrame() {
        selectionIndicatorArrowLayer.frame = frameForSelectionIndicator()
        selectionIndicatorArrowLayer.mask = nil

        let arrowPath = UIBezierPath()
        var p1 = CGPoint.zero
        var p2 = CGPoint.zero
        var p3 = CGPoint.zero

        if selectionIndicatorLocation == .down {
            p1 = CGPoint(x: selectionIndicatorArrowLayer.bounds.size.width / 2, y: 0)
            p2 = CGPoint(x: 0, y: selectionIndicatorArrowLayer.bounds.size.height)
            p3 = CGPoint(x: selectionIndicatorArrowLayer.bounds.size.width, y: selectionIndicatorArrowLayer.bounds.size.height)
        } else if selectionIndicatorLocation == .up {
            p1 = CGPoint(x: selectionIndicatorArrowLayer.bounds.size.width / 2, y: selectionIndicatorArrowLayer.bounds.size.height)
            p2 = CGPoint(x: selectionIndicatorArrowLayer.bounds.size.width, y: 0)
        }
        arrowPath.move(to: p1)
        arrowPath.addLine(to: p2)
        arrowPath.addLine(to: p3)
        arrowPath.close()

        let maskLayer = CAShapeLayer()
        maskLayer.frame = selectionIndicatorArrowLayer.bounds
        maskLayer.path = arrowPath.cgPath
        selectionIndicatorArrowLayer.mask = maskLayer
    }

    /// Stripe width in range(0.0 - 1.0).
    /// Default is 1.0
    public var indicatorWidthPercent: Double = 1.0 {
        didSet {
            if !(indicatorWidthPercent <= 1.0 && indicatorWidthPercent >= 0.0) {
                indicatorWidthPercent = max(0.0, min(indicatorWidthPercent, 1.0))
            }
        }
    }

    private func frameForSelectionIndicator() -> CGRect {
        var indicatorYOffset: CGFloat = 0
        if selectionIndicatorLocation == .down {
            indicatorYOffset = bounds.size.height - selectionIndicatorHeight + edgeInset.bottom
        } else if selectionIndicatorLocation == .up {
            indicatorYOffset = edgeInset.top
        }
        var sectionWidth: CGFloat = 0.0
        if type == .text {
            sectionWidth = measureTitleAtIndex(index: selectedSegmentIndex).width
        } else if type == .images {
            sectionWidth = sectionImages[selectedSegmentIndex].size.width
        } else if type == .textImages {
            let stringWidth = measureTitleAtIndex(index: selectedSegmentIndex).width
            let imageWidth = sectionImages[selectedSegmentIndex].size.width
            sectionWidth = max(stringWidth, imageWidth)
        }

        var indicatorFrame = CGRect.zero

        if selectionStyle == .arrow {
            var widthToStartOfSelIndex: CGFloat = 0.0
            var widthToEndOfSelIndex: CGFloat = 0.0
            if segmentWidthStyle == .dynamic {
                let a = getDynamicWidthTillSegmentIndex(index: selectedSegmentIndex)
                widthToStartOfSelIndex = a.0
                widthToEndOfSelIndex = widthToStartOfSelIndex + a.1
            } else {
                widthToStartOfSelIndex = CGFloat(selectedSegmentIndex) * segmentWidth
                widthToEndOfSelIndex = widthToStartOfSelIndex + segmentWidth
            }
            let xPos = widthToStartOfSelIndex + ((widthToEndOfSelIndex - widthToStartOfSelIndex) / 2) - selectionIndicatorHeight
            indicatorFrame = CGRect(x: xPos, y: indicatorYOffset, width: selectionIndicatorHeight * 2, height: selectionIndicatorHeight)
        } else {
            if selectionStyle == .textWidth, sectionWidth <= segmentWidth,
               segmentWidthStyle != .dynamic
            {
                let widthToStartOfSelIndex = CGFloat(selectedSegmentIndex) * segmentWidth
                let widthToEndOfSelIndex: CGFloat = widthToStartOfSelIndex + segmentWidth

                var xPos = (widthToStartOfSelIndex - (sectionWidth / 2)) + ((widthToEndOfSelIndex - widthToStartOfSelIndex) / 2)
                xPos += edgeInset.left
                indicatorFrame = CGRect(x: xPos, y: indicatorYOffset, width: sectionWidth - edgeInset.right, height: selectionIndicatorHeight)
            } else {
                if segmentWidthStyle == .dynamic {
                    var selectedSegmentOffset: CGFloat = 0
                    var i = 0
                    for width in segmentWidthsArray {
                        if selectedSegmentIndex == i {
                            break
                        }
                        selectedSegmentOffset += width
                        i += 1
                    }
                    indicatorFrame = CGRect(x: selectedSegmentOffset + edgeInset.left,
                                            y: indicatorYOffset,
                                            width: segmentWidthsArray[selectedSegmentIndex] - edgeInset.right - edgeInset.left,
                                            height: selectionIndicatorHeight + edgeInset.bottom)
                } else {
                    let xPos = (segmentWidth * CGFloat(selectedSegmentIndex)) + edgeInset.left
                    indicatorFrame = CGRect(x: xPos, y: indicatorYOffset, width: segmentWidth - edgeInset.right - edgeInset.left, height: selectionIndicatorHeight)
                }
            }
        }

        if selectionStyle != .arrow {
            let currentIndicatorWidth = indicatorFrame.size.width
            let widthToMinus = CGFloat(1 - indicatorWidthPercent) * currentIndicatorWidth
            // final width
            indicatorFrame.size.width = currentIndicatorWidth - widthToMinus
            // frame position
            indicatorFrame.origin.x += widthToMinus / 2
        }

        return indicatorFrame
    }

    private func getDynamicWidthTillSegmentIndex(index: Int) -> (CGFloat, CGFloat) {
        var selectedSegmentOffset: CGFloat = 0
        var i = 0
        var selectedSegmentWidth: CGFloat = 0
        for width in segmentWidthsArray {
            if index == i {
                selectedSegmentWidth = width
                break
            }
            selectedSegmentOffset += width
            i += 1
        }
        return (selectedSegmentOffset, selectedSegmentWidth)
    }

    private func frameForFillerSelectionIndicator() -> CGRect {
        if segmentWidthStyle == .dynamic {
            var selectedSegmentOffset: CGFloat = 0
            var i = 0
            for width in segmentWidthsArray {
                if selectedSegmentIndex == i {
                    break
                }
                selectedSegmentOffset += width
                i += 1
            }

            return CGRect(x: selectedSegmentOffset, y: 0, width: segmentWidthsArray[selectedSegmentIndex], height: frame.height)
        }
        return CGRect(x: segmentWidth * CGFloat(selectedSegmentIndex), y: 0, width: segmentWidth, height: frame.height)
    }

    private func updateSegmentsRects() {
        scrollView.contentInset = UIEdgeInsets.zero
        scrollView.frame = CGRect(origin: CGPoint.zero, size: frame.size)

        let count = sectionCount()
        if count > 0 {
            segmentWidth = frame.size.width / CGFloat(count)
        }

        if type == .text {
            if segmentWidthStyle == .fixed {
                for (index, _) in sectionTitles.enumerated() {
                    let stringWidth = measureTitleAtIndex(index: index).width +
                        edgeInset.left + edgeInset.right
                    segmentWidth = max(stringWidth, segmentWidth)
                }
            } else if segmentWidthStyle == .dynamic {
                var arr = [CGFloat]()
                for (index, _) in sectionTitles.enumerated() {
                    let stringWidth = measureTitleAtIndex(index: index).width +
                        edgeInset.left + edgeInset.right
                    arr.append(stringWidth)
                }
                segmentWidthsArray = arr
            }
        } else if type == .images {
            for image in sectionImages {
                let imageWidth = image.size.width + edgeInset.left + edgeInset.right
                segmentWidth = max(imageWidth, segmentWidth)
            }
        } else if type == .textImages {
            if segmentWidthStyle == .fixed {
                for (index, _) in sectionTitles.enumerated() {
                    let stringWidth = measureTitleAtIndex(index: index).width +
                        edgeInset.left + edgeInset.right
                    segmentWidth = max(stringWidth, segmentWidth)
                }
            } else if segmentWidthStyle == .dynamic {
                var arr = [CGFloat]()
                for (index, _) in sectionTitles.enumerated() {
                    let stringWidth = measureTitleAtIndex(index: index).width +
                        edgeInset.right
                    let imageWidth = sectionImages[index].size.width + edgeInset.left
                    arr.append(max(stringWidth, imageWidth))
                }
                segmentWidthsArray = arr
            }
        } else if type == .flexibleTextImages {
            if segmentWidthStyle == .fixed {
                for (index, _) in sectionItems.enumerated() {
                    let stringWidth = measureTitleAtIndex(index: index).width +
                        edgeInset.left + edgeInset.right
                    segmentWidth = max(stringWidth, segmentWidth)
                }
            } else if segmentWidthStyle == .dynamic {
                var arr = [CGFloat]()
                for (index, _) in sectionItems.enumerated() {
                    let stringWidth = measureTitleAtIndex(index: index).width +
                        edgeInset.right
                    let imageWidth = sectionItems[index].image?.size.width ?? 0 + edgeInset.left
                    arr.append(max(stringWidth, imageWidth))
                }
                segmentWidthsArray = arr
            }
        }

        scrollView.isScrollEnabled = true
        scrollView.contentSize = CGSize(width: totalSegmentedControlWidth(), height: frame.height)

        switch segmentAlignment {
        case .center:
            let count = sectionCount() - 1
            scrollView.contentInset = UIEdgeInsets(top: 0,
                                                   left: scrollView.bounds.size.width / 2.0 - widthOfSegment(index: 0) / 2.0,
                                                   bottom: 0,
                                                   right: scrollView.bounds.size.width / 2.0 - widthOfSegment(index: count) / 2.0)

        case .edge: break
        }

        scrollToSelectedSegmentIndex(animated: false)
    }

    private func widthOfSegment(index: NSInteger) -> CGFloat {
        return index < (segmentWidthsArray.count - 1)
            ? CGFloat(segmentWidthsArray[index])
            : 0.0
    }

    private func sectionCount() -> Int {
        if type == .text {
            return sectionTitles.count
        } else if type == .flexibleTextImages {
            return sectionItems.count
        } else {
            return sectionImages.count
        }
    }

    var enlargeEdgeInset = UIEdgeInsets.zero

    // MARK: - Touch Methods

    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first
        guard let touchesLocation = touch?.location(in: self) else {
            assert(false, "Touch Location not found")
            return
        }

        // check to see if there are sections, if not then just return
        var sectionTitleCount = 0
        var sectionImagesCount = 0

        if sectionTitles != nil {
            sectionTitleCount = sectionTitles.count
        }

        if sectionImages != nil {
            sectionImagesCount = sectionImages.count
        }

        if sectionItems != nil {
            sectionImagesCount = sectionItems.count
        }

        if sectionTitleCount == 0, sectionImagesCount == 0 {
            return
        }
        // end check to see if there are sections

        let enlargeRect = CGRect(x: bounds.origin.x - enlargeEdgeInset.left,
                                 y: bounds.origin.y - enlargeEdgeInset.top,
                                 width: bounds.size.width + enlargeEdgeInset.left + enlargeEdgeInset.right,
                                 height: bounds.size.height + enlargeEdgeInset.top + enlargeEdgeInset.bottom)

        if enlargeRect.contains(touchesLocation) {
            var segment = 0
            if segmentWidthStyle == .fixed {
                segment = Int((touchesLocation.x + scrollView.contentOffset.x) / segmentWidth)
            } else {
                // To know which segment the user touched, we need to loop over the widths and substract it from the x position.
                var widthLeft = touchesLocation.x + scrollView.contentOffset.x
                for width in segmentWidthsArray {
                    widthLeft -= width
                    // When we don't have any width left to substract, we have the segment index.
                    if widthLeft <= 0 {
                        break
                    }
                    segment += 1
                }
            }

            var sectionsCount = 0
            if type == .images {
                sectionsCount = sectionImages.count
            } else if type == .flexibleTextImages {
                sectionsCount = sectionItems.count
            } else {
                sectionsCount = sectionTitles.count
            }

            if segment != selectedSegmentIndex, segment < sectionsCount {
                // Check if we have to do anything with the touch event
                setSelected(forIndex: segment, animated: true, shouldNotify: true)
            }
        }
    }

    // MARK: - Scrolling

    private func totalSegmentedControlWidth() -> CGFloat {
        if type == .images {
            return CGFloat(sectionImages.count) * segmentWidth
        }

        if type == .flexibleTextImages {
            return CGFloat(sectionItems.count) * segmentWidth
        }

        if segmentWidthStyle == .fixed {
            return CGFloat(sectionTitles.count) * segmentWidth
        } else {
            let sum = segmentWidthsArray.reduce(0, +)
            return sum
        }
    }

    func scrollToSelectedSegmentIndex(animated: Bool) {
        var rectForSelectedIndex = CGRect.zero
        var selectedSegmentOffset: CGFloat = 0
        if segmentWidthStyle == .fixed {
            rectForSelectedIndex = CGRect(x: segmentWidth * CGFloat(selectedSegmentIndex),
                                          y: 0,
                                          width: segmentWidth, height: frame.height)
            selectedSegmentOffset = (frame.width / 2) - (segmentWidth / 2)
        } else {
            var i = 0
            var offsetter: CGFloat = 0
            for width in segmentWidthsArray {
                if selectedSegmentIndex == i {
                    break
                }
                offsetter += width
                i += 1
            }
            rectForSelectedIndex = CGRect(x: offsetter, y: 0,
                                          width: segmentWidthsArray[selectedSegmentIndex],
                                          height: frame.height)
            selectedSegmentOffset = (frame.width / 2) - (segmentWidthsArray[selectedSegmentIndex] / 2)
        }
        rectForSelectedIndex.origin.x -= selectedSegmentOffset
        rectForSelectedIndex.size.width += selectedSegmentOffset * 2

        // Scroll to segment and apply segment alignment
        switch segmentAlignment {
        case .center:
            var contentOffset: CGPoint = scrollView.contentOffset
            contentOffset.x = rectForSelectedIndex.origin.x
            scrollView.setContentOffset(contentOffset, animated: true)

        case .edge: break
        }
    }

    // MARK: - Index Change

    public func setSelected(forIndex index: Int, animated: Bool) {
        setSelected(forIndex: index, animated: animated, shouldNotify: false)
    }

    public func setSelected(forIndex index: Int, animated: Bool, shouldNotify: Bool) {
        selectedSegmentIndex = index
        setNeedsDisplay()

        if index == TZSegmentedControlNoSegment {
            selectionIndicatorBoxLayer.removeFromSuperlayer()
            selectionIndicatorArrowLayer.removeFromSuperlayer()
            selectionIndicatorStripLayer.removeFromSuperlayer()
        } else {
            scrollToSelectedSegmentIndex(animated: animated)

            if animated {
                // If the selected segment layer is not added to the super layer, that means no
                // index is currently selected, so add the layer then move it to the new
                // segment index without animating.
                if selectionStyle == .arrow {
                    if selectionIndicatorArrowLayer.superlayer == nil {
                        scrollView.layer.addSublayer(selectionIndicatorArrowLayer)
                        setSelected(forIndex: index, animated: false, shouldNotify: true)
                        return
                    }
                } else {
                    if selectionIndicatorStripLayer.superlayer == nil {
                        scrollView.layer.addSublayer(selectionIndicatorStripLayer)
                        if selectionStyle == .box, selectionIndicatorBoxLayer.superlayer == nil {
                            scrollView.layer.insertSublayer(selectionIndicatorBoxLayer, at: 0)
                        }
                        setSelected(forIndex: index, animated: false, shouldNotify: true)
                        return
                    }
                }
                if shouldNotify {
                    notifyForSegmentChange(toIndex: index)
                }

                // Restore CALayer animations
                selectionIndicatorArrowLayer.actions = nil
                selectionIndicatorStripLayer.actions = nil
                selectionIndicatorBoxLayer.actions = nil

                // Animate to new position
                CATransaction.begin()
                CATransaction.setAnimationDuration(0.15)
                CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear))
                setArrowFrame()
                selectionIndicatorBoxLayer.frame = frameForFillerSelectionIndicator()
                selectionIndicatorStripLayer.frame = frameForSelectionIndicator()
                CATransaction.commit()

            } else {
                // Disable CALayer animations
                selectionIndicatorArrowLayer.actions = nil
                setArrowFrame()
                selectionIndicatorStripLayer.actions = nil
                selectionIndicatorStripLayer.frame = frameForSelectionIndicator()
                selectionIndicatorBoxLayer.actions = nil
                selectionIndicatorBoxLayer.frame = frameForFillerSelectionIndicator()
                if shouldNotify {
                    notifyForSegmentChange(toIndex: index)
                }
            }
        }
    }

    private func notifyForSegmentChange(toIndex index: Int) {
        if superview != nil {
            sendActions(for: .valueChanged)
        }
        indexChangeBlock?(index)
    }

    // MARK: - Styliing Support

    private func finalTitleAttributes() -> [NSAttributedString.Key: Any] {
        var defaults: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16),
                                                       NSAttributedString.Key.foregroundColor: UIColor.black]
        if titleTextAttributes != nil {
            defaults.merge(dict: titleTextAttributes!)
        }

        return defaults
    }

    private func finalSelectedTitleAttributes() -> [NSAttributedString.Key: Any] {
        var defaults: [NSAttributedString.Key: Any] = finalTitleAttributes()
        if selectedTitleTextAttributes != nil {
            defaults.merge(dict: selectedTitleTextAttributes!)
        }
        return defaults
    }
}

extension Dictionary {
    mutating func merge<K, V>(dict: [K: V]) {
        for (k, v) in dict {
            updateValue(v as! Value, forKey: k as! Key)
        }
    }
}

class CenteredVeritcalCATextLayer: CATextLayer {
    override open func draw(in ctx: CGContext) {
        let yDiff: CGFloat
        let fontSize: CGFloat
        let height = bounds.height

        if let attributedString = string as? NSAttributedString {
            fontSize = attributedString.size().height
            yDiff = (height - fontSize) / 2
        } else {
            fontSize = self.fontSize
            yDiff = (height - fontSize) / 2 - fontSize / 10
        }

        ctx.saveGState()
        ctx.translateBy(x: 0.0, y: yDiff)
        super.draw(in: ctx)
        ctx.restoreGState()
    }

    func makePulsate(fromValue: Double = 2, toValue: Double = 1.0, duration: Double = 0.3) {
        let pulse = CASpringAnimation(keyPath: "transform.scale")
        pulse.duration = duration
        pulse.fromValue = fromValue
        pulse.toValue = toValue
        pulse.repeatCount = 1

        add(pulse, forKey: "pulse")
    }
}
