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
/// - parameter textWidth : Indicator width will only be as big as the text width
/// - parameter fullWidth : Indicator width will fill the whole segment
/// - parameter box : A rectangle that covers the whole segment
/// - parameter arrow : An arrow in the middle of the segment pointing up or down depending
///                     on `TZSegmentedControlSelectionIndicatorLocation`
///
enum TZSegmentedControlSelectionStyle {
    case textWidth
    case fullWidth
    case box
    case arrow
}

enum TZSegmentedControlSelectionIndicatorLocation{
    case up
    case down
    case none // No selection indicator
}

enum TZSegmentedControlSegmentWidthStyle {
    case fixed      // Segment width is fixed
    case dynamic    // Segment width will only be as big as the text width (including inset)
}

enum TZSegmentedControlBorderType {
    case none   // 0
    case top    // (1 << 0)
    case left   // (1 << 1)
    case bottom // (1 << 2)
    case right  // (1 << 3)
}

enum TZSegmentedControlType {
    case text
    case images
    case textImages
}

let TZSegmentedControlNoSegment = -1

typealias IndexChangeBlock = ((Int) -> Void)
typealias TZTitleFormatterBlock = ((_ segmentedControl: TZSegmentedControl, _ title: String, _ index: Int, _ selected: Bool) -> NSAttributedString)

class TZSegmentedControl: UIControl {

    var sectionTitles : [String]! {
        didSet {
            self.setNeedsLayout()
            self.setNeedsDisplay()
        }
    }
    var sectionImages: [UIImage]! {
        didSet {
            self.setNeedsLayout()
            self.setNeedsDisplay()
        }
    }
    var sectionSelectedImages : [UIImage]!
    
    /// Provide a block to be executed when selected index is changed.
    /// Alternativly, you could use `addTarget:action:forControlEvents:`
    var indexChangeBlock : IndexChangeBlock?
    
    /// Used to apply custom text styling to titles when set.
    /// When this block is set, no additional styling is applied to the `NSAttributedString` object
    /// returned from this block.
    var titleFormatter : TZTitleFormatterBlock?
    
    /// Text attributes to apply to labels of the unselected segments
    var titleTextAttributes: [String:Any]? = [NSFontAttributeName: UIFont.systemFont(ofSize: 19.0),
                                              NSForegroundColorAttributeName: UIColor.black]
    
    /// Text attributes to apply to selected item title text.
    /// Attributes not set in this dictionary are inherited from `titleTextAttributes`.
    var selectedTitleTextAttributes: [String: Any]? =  [NSFontAttributeName: UIFont.systemFont(ofSize: 19.0),
                                                        NSForegroundColorAttributeName: UIColor.blue]
    
    /// Segmented control background color.
    /// Default is `[UIColor whiteColor]`
    dynamic override var backgroundColor: UIColor! {
        set {self.backgroundColor = newValue}
        get {return self.backgroundColor}
    }
    
    /// Color for the selection indicator stripe
    var selectionIndicatorColor: UIColor = .black {
        didSet {
            self.selectionIndicator.backgroundColor = selectionIndicatorColor
            self.selectionIndicatorBoxColor = selectionIndicatorColor
        }
    }
    
    lazy var selectionIndicator: UIView = {
        let selectionIndicator = UIView()
        selectionIndicator.backgroundColor = self.selectionIndicatorColor
        selectionIndicator.translatesAutoresizingMaskIntoConstraints = false
        return selectionIndicator
    }()
    
    /// Color for the selection indicator box
    /// Default is selectionIndicatorColor
    dynamic var selectionIndicatorBoxColor : UIColor!;
    
    /// Color for the vertical divider between segments.
    /// Default is `[UIColor blackColor]`
    dynamic var verticalDividerColor : UIColor!;
    
    //TODO Add other visual apperance properities
    
    /// Specifies the style of the control
    /// Default is `text`
    var type: TZSegmentedControlType = .text
    
    /// Specifies the style of the selection indicator.
    /// Default is `textWidth`
    var selectionStyle: TZSegmentedControlSelectionStyle = .textWidth
    
    /// Specifies the style of the segment's width.
    /// Default is `fixed`
    var segmentWidthStyle: TZSegmentedControlSegmentWidthStyle {
        set {
            if self.type == .images {
                self.segmentWidthStyle = .fixed
            } else {
                self.segmentWidthStyle = newValue
            }
        }
        get {
            return self.segmentWidthStyle
        }
    }
    
    /// Specifies the location of the selection indicator.
    /// Default is `up`
    var selectionIndicatorLocation: TZSegmentedControlSelectionIndicatorLocation = .up {
        didSet {
            if self.selectionIndicatorLocation == .none {
                self.selectionIndicatorHeight = 0.0
            }
        }
    }
    
    /// Specifies the border type.
    /// Default is `none`
    var borderType: TZSegmentedControlBorderType = .none {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    /// Specifies the border color.
    /// Default is `black`
    var borderColor = UIColor.black
    
    /// Specifies the border width.
    /// Default is `1.0f`
    var borderWidth: CGFloat = 1.0
    
    
    /// Default is NO. Set to YES to show a vertical divider between the segments.
    var verticalDividerEnabled = false
    
    /// Index of the currently selected segment.
    var selectedSegmentIndex: Int = 0
    
    /// Height of the selection indicator stripe.
    var selectionIndicatorHeight: CGFloat = 5.0
    
    var edgeInset = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
    var selectionEdgeInset = UIEdgeInsets.zero
    var verticalDividerWidth = 1.0
    var selectionIndicatorBoxOpacity : Float = 0.2
    
    ///MARK: Private variable
    internal var selectionIndicatorStripLayer = CALayer()
    internal var selectionIndicatorBoxLayer = CALayer() {
        didSet {
            self.selectionIndicatorBoxLayer.opacity = self.selectionIndicatorBoxOpacity
            self.selectionIndicatorBoxLayer.borderWidth = self.borderWidth
        }
    }
    internal var selectionIndicatorArrowLayer = CALayer()
    internal var segmentWidth : CGFloat = 0.0
    internal var segmentWidthsArray : [CGFloat] = []
    internal var scrollView : TZScrollView!  = {
        let scroll = TZScrollView()
        scroll.scrollsToTop = false
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        return scroll
    }()
    
    //MARK: - Init Methods
    
    /// Initialiaze the segmented control with only titles.
    ///
    /// - Parameter sectionTitles: array of strings for the section title
    convenience init(sectionTitles titles: [String]) {
        self.init()
        self.setup()
        self.sectionTitles = titles
        self.type = .text
    }
    
    /// Initialiaze the segmented control with only images/icons.
    ///
    /// - Parameter sectionImages: array of images for the section images.
    /// - Parameter selectedImages: array of images for the selected section images.
    convenience init(sectionImages images: [UIImage], selectedImages sImages: [UIImage]) {
        self.init()
        self.setup()
        self.sectionImages = images
        self.sectionSelectedImages = sImages
        self.type = .images
    }
    
    /// Initialiaze the segmented control with both titles and images/icons.
    ///
    /// - Parameter sectionTitles: array of strings for the section title
    /// - Parameter sectionImages: array of images for the section images.
    /// - Parameter selectedImages: array of images for the selected section images.
    convenience init(sectionTitles titles: [String], sectionImages images: [UIImage],
                     selectedImages sImages: [UIImage]) {
        self.init()
        self.setup()
        self.sectionTitles = titles
        self.sectionImages = images
        self.sectionSelectedImages = sImages
        self.type = .textImages
        
        assert(sectionTitles.count != sectionSelectedImages.count, "Titles and images are not in correct count")
        
    }
    
    private func setup(){
        self.addSubview(self.scrollView)
        self.backgroundColor = UIColor.white
        self.isOpaque = false
        self.contentMode = .redraw
    }
    
    //MARK: - Drawing 
    
    private func measureTitleAtIndex(index : Int) -> CGSize {
        if index >= self.sectionTitles.count {
            return CGSize.zero
        }
        let title = self.sectionTitles[index]
        let selected = (index == self.selectedSegmentIndex)
        var size = CGSize.zero
        if self.titleFormatter == nil {
            size = (title as NSString).size(attributes: selected ? selectedTitleTextAttributes : titleTextAttributes)
        } else {
            size = self.titleFormatter!(self, title, index, selected).size()
        }
        return size
    }
    
    private func attributedTitleAtIndex(index : Int) -> NSAttributedString {
        let title = self.sectionTitles[index]
        let selected = (index == self.selectedSegmentIndex)
        var str = NSAttributedString()
        if self.titleFormatter == nil {
            let attr = selected ? selectedTitleTextAttributes : titleTextAttributes
            str = NSAttributedString(string: title, attributes: attr)
        } else {
            str = self.titleFormatter!(self, title, index, selected)
        }
        return str
    }
    
    override func draw(_ rect: CGRect) {
        self.backgroundColor.setFill()
        UIRectFill(self.bounds)
        
        self.selectionIndicatorArrowLayer.backgroundColor = self.selectionIndicatorColor.cgColor
        self.selectionIndicatorStripLayer.backgroundColor = self.selectionIndicatorColor.cgColor
        self.selectionIndicatorBoxLayer.backgroundColor = self.selectionIndicatorBoxColor.cgColor
        self.selectionIndicatorBoxLayer.borderColor = self.selectionIndicatorBoxColor.cgColor
        
        // Remove all sublayers to avoid drawing images over existing ones
        self.scrollView.layer.sublayers = nil
        
        let oldrect = rect
        
        if self.type == .text {
            for (index, _) in self.sectionTitles.enumerated() {
                let size = self.measureTitleAtIndex(index: index)
                let strWidth  = size.width
                let strHeight = size.height
                var rectDiv = CGRect.zero
                var fullRect = CGRect.zero
                
                // Text inside the CATextLayer will appear blurry unless the rect values are rounded
                let isLocationUp : CGFloat = (self.selectionIndicatorLocation == .up) ? 0.0 : 1.0
                let isBoxStyle : CGFloat = (self.selectionStyle == .box) ? 0.0 : 1.0
                
                let a : CGFloat = (self.frame.height - (isBoxStyle * self.selectionIndicatorHeight)) / 2
                let b : CGFloat = (strHeight / 2) + (self.selectionIndicatorHeight * isLocationUp)
                let yPosition : CGFloat = CGFloat(roundf(Float(a - b)))
                
                var newRect = CGRect.zero
                if self.segmentWidthStyle == .fixed {
                    var xPosition : CGFloat = CGFloat((self.segmentWidth * CGFloat(index)) + (self.segmentWidth - strWidth) / 2)
                    newRect = CGRect(x: xPosition,
                                     y: yPosition,
                                     width: strWidth,
                                     height: strHeight)
                    rectDiv = self.calculateRectDiv(at: index, xoffSet: nil)
                    fullRect = CGRect(x: self.segmentWidth * CGFloat(index), y: 0.0, width: self.segmentWidth, height: oldrect.size.height)
                } else {
                    // When we are drawing dynamic widths, we need to loop the widths array to calculate the xOffset
                    var xOffset : CGFloat = 0.0
                    var i = 0
                    for width in self.segmentWidthsArray {
                        if index == i {
                            break
                        }
                        xOffset += width
                        i += 1
                    }
                    
                    let widthForIndex = self.segmentWidthsArray[index]
                    
                    newRect = CGRect(x: xOffset, y: yPosition, width: widthForIndex, height: strHeight)
                    
                    fullRect = CGRect(x: self.segmentWidth * CGFloat(index), y: 0.0, width: widthForIndex, height: oldrect.size.height)
                    rectDiv = self.calculateRectDiv(at: index, xoffSet: xOffset)
                }
                // Fix rect position/size to avoid blurry labels
                newRect = CGRect(x: ceil(newRect.origin.x), y: ceil(newRect.origin.y), width: ceil(newRect.size.width), height: ceil(newRect.size.height))
                let titleLayer = CATextLayer()
                titleLayer.frame = newRect
                titleLayer.alignmentMode = kCAAlignmentCenter
                if (UIDevice.current.systemVersion as NSString).floatValue < 10.0 {
                    titleLayer.truncationMode = kCATruncationEnd
                }
                titleLayer.string = self.attributedTitleAtIndex(index: index)
                titleLayer.contentsScale = UIScreen.main.scale
                self.scrollView.layer.addSublayer(titleLayer)
                
                // Vertical Divider
                self.addVerticalLayer(at: index, rectDiv: rectDiv)
                
                self.addBgAndBorderLayer(with: fullRect)
            }
        } else if self.type == .images {
            for (index, image) in self.sectionImages.enumerated() {
                let imageWidth = image.size.width
                let imageHeight = image.size.height
                
                let a = (self.frame.height - self.selectionIndicatorHeight) / 2
                let b = (imageHeight/2) + (self.selectionIndicatorLocation == .up ? self.selectionIndicatorHeight : 0.0)
                let y : CGFloat = CGFloat(roundf(Float(a - b)))
                let x : CGFloat = (self.segmentWidth * CGFloat(index)) + (self.segmentWidth - imageWidth) / 2.0
                let newRect = CGRect(x: x, y: y, width: imageWidth, height: imageHeight)
                
                let imageLayer = CALayer()
                imageLayer.frame = newRect
                imageLayer.contents = image.cgImage
                
                if self.selectedSegmentIndex == index && self.sectionSelectedImages.count > index {
                    let highlightedImage = self.sectionSelectedImages[index]
                        imageLayer.contents = highlightedImage.cgImage
                }
                
                self.scrollView.layer.addSublayer(imageLayer)
                
                //vertical Divider
                self.addVerticalLayer(at: index, rectDiv: self.calculateRectDiv(at: index, xoffSet: nil))
                
                self.addBgAndBorderLayer(with: newRect)
            }
        } else if self.type == .textImages {
            for (index, image) in self.sectionImages.enumerated() {
                let imageWidth = image.size.width
                let imageHeight = image.size.height
                
                let stringHeight = self.measureTitleAtIndex(index: index).height
                let yOffset : CGFloat = CGFloat(roundf(Float(
                    ((self.frame.height - self.selectionIndicatorHeight) / 2) - (stringHeight / 2)
                )))
                
                var imagexOffset : CGFloat = self.edgeInset.left
                var textxOffset : CGFloat = self.edgeInset.left
                
                var textWidth : CGFloat = 0.0
                if self.segmentWidthStyle == .fixed {
                    imagexOffset = (self.segmentWidth * CGFloat(index)) + (self.segmentWidth / 2) - (imageWidth / 2.0)
                    textxOffset = self.segmentWidth * CGFloat(index)
                    textWidth = self.segmentWidth
                } else {
                    // When we are drawing dynamic widths, we need to loop the widths array to calculate the xOffset
                    var xOffset : CGFloat = 0.0
                    var i = 0
                    for width in self.segmentWidthsArray {
                        if i == 1 {
                            break
                        }
                        xOffset += width
                        i += 1
                    }
                    
                    imagexOffset = xOffset + (self.segmentWidthsArray[index] / 2) - (imageWidth / 2)
                    textxOffset = xOffset
                    textWidth = self.segmentWidthsArray[index]
                }
                
                let imageyOffset : CGFloat = CGFloat(roundf(Float(
                    ((self.frame.height - self.selectionIndicatorHeight) / 2))))
                let imageRect = CGRect(x: imagexOffset, y: imageyOffset, width: imageWidth, height: imageHeight)
                var textRect = CGRect(x: textxOffset, y: yOffset, width: textWidth, height: stringHeight)
                
                // Fix rect position/size to avoid blurry labels
                textRect = CGRect(x: ceil(textRect.origin.x), y: ceil(textRect.origin.y), width: ceil(textRect.size.width), height: ceil(textRect.size.height))
                
                let titleLayer = CATextLayer()
                titleLayer.frame = textRect
                titleLayer.alignmentMode = kCAAlignmentCenter
                if (UIDevice.current.systemVersion as NSString).floatValue < 10.0 {
                    titleLayer.truncationMode = kCATruncationEnd
                }
                titleLayer.string = self.attributedTitleAtIndex(index: index)
                titleLayer.contentsScale = UIScreen.main.scale
                
                let imageLayer = CALayer()
                imageLayer.frame = imageRect
                imageLayer.contents = image.cgImage
                if self.selectedSegmentIndex == index && self.sectionSelectedImages.count > index {
                    let highlightedImage = self.sectionSelectedImages[index]
                    imageLayer.contents = highlightedImage.cgImage
                }
                
                self.scrollView.layer.addSublayer(imageLayer)
                self.scrollView.layer.addSublayer(titleLayer)
                
                self.addBgAndBorderLayer(with: imageRect)
            }
            
            // Add the selection indicators
            if self.selectedSegmentIndex != TZSegmentedControlNoSegment {
                if self.selectionStyle == .arrow {
                    if (self.selectionIndicatorArrowLayer.superlayer != nil) {
                        self.setArrowFrame()
                        self.scrollView.layer.addSublayer(self.selectionIndicatorArrowLayer)
                    }
                } else {
                    if (self.selectionIndicatorStripLayer.superlayer != nil) {
                        self.selectionIndicatorStripLayer.frame = self.frameForSelectionIndicator()
                        self.scrollView.layer.addSublayer(self.selectionIndicatorStripLayer)
                        
                        if self.selectionStyle == .box && self.selectionIndicatorBoxLayer.superlayer != nil {
                            self.selectionIndicatorBoxLayer.frame = self.frameForSelectionIndicator()
                            self.scrollView.layer.insertSublayer(self.selectionIndicatorBoxLayer, at: 0)
                        }
                    }
                }
            }
        }
    }
    
    private func calculateRectDiv(at index: Int, xoffSet: CGFloat?) -> CGRect {
        var a :CGFloat
        if xoffSet != nil {
            a = xoffSet!
        } else {
            a = self.segmentWidth * CGFloat(index)
        }
        let xPosition = CGFloat( a - CGFloat(self.verticalDividerWidth / 2))
        let rectDiv = CGRect(x: xPosition,
                             y: self.selectionIndicatorHeight * 2,
                             width: CGFloat(self.verticalDividerWidth),
                             height: self.frame.size.height - (self.selectionIndicatorHeight * 4))
        return rectDiv
    }
    
    // Add Vertical Divider Layer
    private func addVerticalLayer(at index: Int, rectDiv: CGRect) {
        if self.verticalDividerEnabled && index > 0 {
            let vDivLayer = CALayer()
            vDivLayer.frame = rectDiv
            vDivLayer.backgroundColor = self.verticalDividerColor.cgColor
            self.scrollView.layer.addSublayer(vDivLayer)
        }
    }
    
    private func addBgAndBorderLayer(with rect: CGRect){
        // Background layer
        let bgLayer = CALayer()
        bgLayer.frame = rect
        self.layer.insertSublayer(bgLayer, at: 0)
        
        // Border layer
        if self.borderType != .none {
            let borderLayer = CALayer()
            borderLayer.backgroundColor = self.borderColor.cgColor
            var borderRect = CGRect.zero
            switch self.borderType {
            case .top:
                borderRect = CGRect(x: 0, y: 0, width: rect.size.width, height: self.borderWidth)
                break
            case .left:
                borderRect = CGRect(x: 0, y: 0, width: self.borderWidth, height: rect.size.height)
                break
            case .bottom:
                borderRect = CGRect(x: 0, y: rect.size.height, width: rect.size.width, height: self.borderWidth)
                break
            case .right:
                borderRect = CGRect(x: 0, y: rect.size.width, width: self.borderWidth, height: rect.size.height)
                break
            case .none:
                break
            }
            borderLayer.frame = borderRect
            bgLayer.addSublayer(borderLayer)
        }
    }
    
    private func setArrowFrame(){
        
        
        
//        self.selectionIndicatorArrowLayer.frame = [self frameForSelectionIndicator];
//        
//        self.selectionIndicatorArrowLayer.mask = nil;
//        
//        UIBezierPath *arrowPath = [UIBezierPath bezierPath];
//        
//        CGPoint p1 = CGPointZero;
//        CGPoint p2 = CGPointZero;
//        CGPoint p3 = CGPointZero;
//        
//        if (self.selectionIndicatorLocation == HMSegmentedControlSelectionIndicatorLocationDown) {
//            p1 = CGPointMake(self.selectionIndicatorArrowLayer.bounds.size.width / 2, 0);
//            p2 = CGPointMake(0, self.selectionIndicatorArrowLayer.bounds.size.height);
//            p3 = CGPointMake(self.selectionIndicatorArrowLayer.bounds.size.width, self.selectionIndicatorArrowLayer.bounds.size.height);
//        }
//        
//        if (self.selectionIndicatorLocation == HMSegmentedControlSelectionIndicatorLocationUp) {
//            p1 = CGPointMake(self.selectionIndicatorArrowLayer.bounds.size.width / 2, self.selectionIndicatorArrowLayer.bounds.size.height);
//            p2 = CGPointMake(self.selectionIndicatorArrowLayer.bounds.size.width, 0);
//            p3 = CGPointMake(0, 0);
//        }
//        
//        [arrowPath moveToPoint:p1];
//        [arrowPath addLineToPoint:p2];
//        [arrowPath addLineToPoint:p3];
//        [arrowPath closePath];
//        
//        CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
//        maskLayer.frame = self.selectionIndicatorArrowLayer.bounds;
//        maskLayer.path = arrowPath.CGPath;
//        self.selectionIndicatorArrowLayer.mask = maskLayer;
    }
    
    private func frameForSelectionIndicator() -> CGRect {
        var indicatorYOffset : CGFloat = 0
        if self.selectionIndicatorLocation == .down {
            indicatorYOffset = self.bounds.size.height - self.selectionIndicatorHeight + self.edgeInset.bottom
        } else if self.selectionIndicatorLocation == .up {
            indicatorYOffset = self.edgeInset.top
        }
        var sectionWidth : CGFloat = 0.0
        if self.type == .text {
            sectionWidth = self.measureTitleAtIndex(index: self.selectedSegmentIndex).width
        } else if self.type == .images {
            sectionWidth = self.sectionImages[self.selectedSegmentIndex].size.width
        } else if self.type == .textImages {
            let stringWidth = self.measureTitleAtIndex(index: self.selectedSegmentIndex).width
            let imageWidth = self.sectionImages[self.selectedSegmentIndex].size.width
            sectionWidth = max(stringWidth, imageWidth)
        }
        
        if self.selectionStyle == .arrow {
            let widthToStartOfSelIndex : CGFloat = CGFloat(self.selectedSegmentIndex) * self.segmentWidth
            let widthToEndOfSelIndex : CGFloat = widthToStartOfSelIndex + self.segmentWidth
            let xPos = widthToStartOfSelIndex + ((widthToEndOfSelIndex - widthToStartOfSelIndex) / 2) - (self.selectionIndicatorHeight/2)
            
        }
        
//        if (self.selectionStyle == HMSegmentedControlSelectionStyleArrow) {
//            CGFloat widthToEndOfSelectedSegment = (self.segmentWidth * self.selectedSegmentIndex) + self.segmentWidth;
//            CGFloat widthToStartOfSelectedIndex = (self.segmentWidth * self.selectedSegmentIndex);
//            
//            CGFloat x = widthToStartOfSelectedIndex + ((widthToEndOfSelectedSegment - widthToStartOfSelectedIndex) / 2) - (self.selectionIndicatorHeight/2);
//            return CGRectMake(x - (self.selectionIndicatorHeight / 2), indicatorYOffset, self.selectionIndicatorHeight * 2, self.selectionIndicatorHeight);
//        }
        
        return CGRect.zero
    }

}