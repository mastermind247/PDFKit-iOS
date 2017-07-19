//
//  PDFDocView.swift
//  PDFKit-iOS
//
//  Created by Parth on 14/07/17.
//  Copyright © 2017 Solution Analysts. All rights reserved.
//

import UIKit
import Material
import ZDStickerView
import SocketIO

class PDFDocView: UIView, UIScrollViewDelegate {

    fileprivate let fabMenuSize = CGSize(width: 40, height: 40)
    fileprivate let bottomInset: CGFloat = 16
    fileprivate let rightInset: CGFloat = 16

    fileprivate var fabButton: FABButton!
    fileprivate var fabMenu: FABMenu!
    fileprivate var clearAnnotationFABMenuItem: FABMenuItem!
    fileprivate var addSquareFABMenuItem: FABMenuItem!

    var socket: SocketIOClient?
    var pdfFile: CGPDFDocument!
    var numberOfPages: Int = 0
    var pdfScrollView: TiledPDFScrollView!
    var page: CGPDFPage!
    var myScale: CGFloat = 0
    var currentPageNumber: Int = 1 {
        didSet {
            page = pdfFile.page(at: currentPageNumber)
            pdfScrollView.setPDFPage(page)
            if let  _ = currentPageLabel {
                currentPageLabel.text = "\(currentPageNumber)/\(numberOfPages)"
            }
        }
    }
    var pageControlView: UIView!
    var currentPageLabel: UILabel!
    var annotationArray: [ZDStickerView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.configureView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.configureView()
    }

    func configureView() {
        loadPDFFromBundle()
        prepareFABButton()
        prepareFABMenu()
//        let uuid = UUID().uuidString
    }

    func loadPDFFromBundle() {
        if let pdfUrl = Bundle.main.url(forResource: "input_pdf.pdf", withExtension: nil) {
            let documentUrl = pdfUrl as CFURL
            pdfFile = CGPDFDocument(documentUrl)
            numberOfPages = pdfFile.numberOfPages as Int
            print("PDF Loaded with \(numberOfPages) pages")
            loadPDFInView()
        } else {
            print("Error Loading PDF file")
        }
    }

    func loadPDFInView() {
        if numberOfPages > 1 {
            pdfScrollView = TiledPDFScrollView(frame: CGRect(x: 0, y: 50, w: self.bounds.width, h: self.bounds.height - 50))
            addPageControlView()
        } else {
            pdfScrollView = TiledPDFScrollView(frame: self.bounds)
        }
        self.addSubview(pdfScrollView)
        self.pdfScrollView.delaysContentTouches = true
        self.pdfScrollView.isExclusiveTouch = true
        self.pdfScrollView.canCancelContentTouches = true
        let scrollRect = pdfFile.page(at: 1)?.getBoxRect(CGPDFBox.mediaBox)
        self.pdfScrollView.pdfFrameRect = scrollRect?.size
        self.pdfScrollView.frame = CGRect(x: 0, y: 50, width: self.pdfScrollView.frame.size.width, height: self.pdfScrollView.frame.size.height)
        currentPageNumber = 1
        self.pdfScrollView.tiledPDFView.layer.setNeedsLayout()
    }

    func addPageControlView() {
        pageControlView = UIView(frame: CGRect(x: 0, y: 0, width: self.bounds.width, height: 50))
        self.addSubview(pageControlView)
        currentPageLabel = UILabel(frame: CGRect(x: self.bounds.width/2 - 50, y: 0, width: 100, height: 50))
        currentPageLabel.textAlignment = .center
        currentPageLabel.text = "1/\(numberOfPages)"
        pageControlView.addSubview(currentPageLabel)

        func addButtonsToPageControl() {
            let nextButton = UIButton(x: self.bounds.width - 50, y: 0, w: 50, h: 50, target: self, action: #selector(changePdfPage(buttonTapped:)))
            nextButton.tag = 2
            nextButton.setImage(UIImage(named: "img_pdf_next"), for: .normal)
            pageControlView.addSubview(nextButton)

            let previousButton = UIButton(x: 0, y: 0, w: 50, h: 50, target: self, action: #selector(changePdfPage(buttonTapped:)))
            previousButton.tag = 1
            previousButton.setImage(UIImage(named: "img_pdf_previous"), for: .normal)
            pageControlView.addSubview(previousButton)
        }
        addButtonsToPageControl()
    }

    func changePdfPage(buttonTapped: UIButton) {
        if buttonTapped.tag == 1 {
            currentPageNumber = (currentPageNumber - 1).clamp(min: 1, numberOfPages)
        } else {
            currentPageNumber = (currentPageNumber + 1).clamp(min: 1, numberOfPages)
        }
    }

}

extension PDFDocView {
    fileprivate func prepareFABButton() {
        fabButton = FABButton(image: Icon.cm.add, tintColor: .white)
        fabButton.pulseColor = .white
        fabButton.backgroundColor = Color.red.base
    }

    fileprivate func prepareFABMenu() {
        fabMenu = FABMenu()
        fabMenu.fabButton = fabButton

        self.layout(fabMenu)
            .size(fabMenuSize)
            .bottom(bottomInset)
            .right(rightInset)
        prepareNotesFABMenuItem()
        prepareRemindersFABMenuItem()
        fabMenu.delegate = self
        fabMenu.fabMenuItems = [clearAnnotationFABMenuItem, addSquareFABMenuItem]

    }

    fileprivate func prepareNotesFABMenuItem() {
        clearAnnotationFABMenuItem = FABMenuItem()
        clearAnnotationFABMenuItem.title = "Clear Annotations"
        clearAnnotationFABMenuItem.fabButton.image = Icon.cm.clear
        clearAnnotationFABMenuItem.fabButton.tintColor = .white
        clearAnnotationFABMenuItem.fabButton.pulseColor = .white
        clearAnnotationFABMenuItem.fabButton.backgroundColor = Color.green.base
        clearAnnotationFABMenuItem.fabButton.addTarget(self, action: #selector(clearAnnotationFABMenuItem(button:)), for: .touchUpInside)

    }

    fileprivate func prepareRemindersFABMenuItem() {
        addSquareFABMenuItem = FABMenuItem()
        addSquareFABMenuItem.title = "Add Circle"
        addSquareFABMenuItem.fabButton.image = Icon.cm.pen
        addSquareFABMenuItem.fabButton.tintColor = .white
        addSquareFABMenuItem.fabButton.pulseColor = .white
        addSquareFABMenuItem.fabButton.backgroundColor = Color.blue.base
        addSquareFABMenuItem.fabButton.addTarget(self, action: #selector(addCircleFABMenuItem(button:)), for: .touchUpInside)
    }


    @objc
    fileprivate func clearAnnotationFABMenuItem(button: UIButton) {
        print("notesFABMenuItem")
        emitClearAnnotationEvent()
        fabMenu.close()
        fabMenu.fabButton?.animate(Motion.rotation(angle: 0))

    }

    @objc
    fileprivate func addCircleFABMenuItem(button: UIButton) {
        print("remindersFABMenuItem")
        let circle = addCircle(xPos: 50, yPos: 75, radius: 30)
        (circle.contentView as! CircleAnnotation).uuid = UUID().uuidString
        (circle.contentView as! CircleAnnotation).page = currentPageNumber
        annotationArray.append(circle)
        emitAddAnnotationEvent(annotation: circle)
        fabMenu.close()
        fabMenu.fabButton?.animate(Motion.rotation(angle: 0))

    }

}

extension PDFDocView {

    @discardableResult
    func addCircle(xPos: CGFloat, yPos: CGFloat, radius: CGFloat) -> ZDStickerView {
        let circleView = CircleAnnotation(frame: CGRect(x: 0, y: 0, w: radius * 2, h: radius * 2))
        circleView.backgroundColor = UIColor.clear
        circleView.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        let resizableCircle = ZDStickerView(frame: CGRect(x: xPos, y: yPos, w: radius * 2, h: radius * 2))
        resizableCircle.tag = 10
        resizableCircle.contentView = circleView
        resizableCircle.stickerViewDelegate = self
        resizableCircle.preventsPositionOutsideSuperview = true
        resizableCircle.setButton(ZDSTICKERVIEW_BUTTON_DEL, image: Icon.close)
        resizableCircle.showEditingHandles()
        pdfScrollView.tiledPDFView.addSubview(resizableCircle)
        return resizableCircle
    }

    func addText() {
    }

    func calculateFrameForAnnotation(annotation: ZDStickerView, fromView: TiledPDFScrollView) -> CGRect {
        var frame: CGRect = .zero
        let scale = pdfScrollView.zoomScale
        frame.size.width = annotation.contentView.frame.size.width * scale
        frame.size.height = annotation.contentView.frame.size.height * scale
        frame.origin.x = annotation.frame.origin.x + annotation.contentView.frame.origin.x * scale
        frame.origin.y = annotation.frame.origin.y + annotation.contentView.frame.origin.y * scale
        return frame
    }
}

extension PDFDocView {
    // Socket Event Updates 

    func addAnnotationSocketEvent(data: [Any]) {
        print("=======ADD ANNOTATION CALLED=======")
        if let circleData = data.first as? [String : Any] {
            let xPos = circleData["cx"] as! CGFloat
            let yPos = circleData["cy"] as! CGFloat
            let radius = circleData["r"] as! CGFloat
            let circleAnnotation = addCircle(xPos: xPos, yPos: yPos, radius: 30)
            (circleAnnotation.contentView as! CircleAnnotation).uuid = circleData["uuid"] as? String
            (circleAnnotation.contentView as! CircleAnnotation).page = circleData["page"] as? Int
            annotationArray.append(circleAnnotation)
        }
    }

    func emitAddAnnotationEvent(annotation: ZDStickerView) {

        let frame = calculateFrameForAnnotation(annotation: annotation, fromView: pdfScrollView)

        let annotationDict: [String:Any] = ["type":"fillcircle",
                                               "cx": round(frame.x),
                                               "cy": round(frame.y),
                                               "r": ceil(frame.width/2),
                                               "class": "Annotation",
                                               "uuid": (annotation.contentView as! CircleAnnotation).uuid!,
                                               "page": (annotation.contentView as! CircleAnnotation).page!,
                                               "color": "#808080",
                                               ]
        socket?.emit(SocketEvents.addAnnotation, with: [annotationDict])
    }

    func deleteAnnotationSocketEvent(data: [Any]) {
        print("=======DELETE ANNOTATION CALLED=======")
        if let annotationData = data.first as? [String : Any] {
            let uuid = annotationData["uuid"] as! String
            let annotation = annotationArray.filter { ($0.contentView as! CircleAnnotation).uuid == uuid }
            print(annotation)
            annotation.first?.removeFromSuperview()
        }
    }

    func emitDeleteAnnotationEvent(annotation: ZDStickerView) {
        socket?.emit(SocketEvents.deleteAnnotation, with: [["uuid": (annotation.contentView as! CircleAnnotation).uuid!,
                                                            "documentId":"shared/example.pdf",
                                                            "is_deleted":true,
                                                            "i_by":(annotation.contentView as! CircleAnnotation).uuid!,
                                                            "page":1]])
    }

    func clearAnnotationsSocketEvent(data: [Any]) {
        print("=======CLEAR ANNOTATION CALLED=======")
        annotationArray.forEach { (annotation) in
            annotation.removeFromSuperview()
        }
        annotationArray = []
    }

    func emitClearAnnotationEvent() {
        socket?.emit(SocketEvents.clearAnnotation, with: [["clear"]])
        annotationArray.forEach { (annotation) in
            annotation.removeFromSuperview()
        }
        annotationArray = []
    }

    func editAnnotationSocketEvent(data: [Any]) {
        print("=======EDIT ANNOTATION CALLED=======")
        if let annotationData = data.first as? [String : Any] {
            let uuid = annotationData["uuid"] as! String
            let annotation = annotationArray.filter { ($0.contentView as! CircleAnnotation).uuid == uuid }
            print(annotation)
            let cx = annotationData["cx"] as! CGFloat
            let cy = annotationData["cy"] as! CGFloat
            annotation.first?.frame.x = cx
            annotation.first?.frame.y = cy
        }
    }

    func emitEditAnnotationEvent(annotation: ZDStickerView) {
        let annotationDict: [String:Any] = ["type":"fillcircle",
                                            "cx": annotation.frame.x,
                                            "cy": annotation.frame.y,
                                            "r": annotation.frame.width/2,
                                            "class": "Annotation",
                                            "uuid": (annotation.contentView as! CircleAnnotation).uuid!,
                                            "page": (annotation.contentView as! CircleAnnotation).page!,
                                            "color": "#808080",
                                            ]
        socket?.emit(SocketEvents.editAnnotation, with: [annotationDict])
    }
}



extension PDFDocView: ZDStickerViewDelegate {

    func stickerViewDidClose(_ sticker: ZDStickerView!) {
        print(sticker)
        print("CLOSE")
        emitDeleteAnnotationEvent(annotation: sticker)
    }
    
    func stickerViewDidEndEditing(_ sticker: ZDStickerView!) {
        print(sticker)
        print("stickerViewDidEndEditing")
        emitEditAnnotationEvent(annotation: sticker)
    }
    
    func stickerViewDidCancelEditing(_ sticker: ZDStickerView!) {
        print(sticker)
        print("stickerViewDidCancelEditing")
    }
    
}

extension PDFDocView: FABMenuDelegate {

    func fabMenuWillOpen(fabMenu: FABMenu) {
        fabMenu.fabButton?.animate(Motion.rotation(angle: 45))
    }

    func fabMenuDidOpen(fabMenu: FABMenu) {
        print("DID OPEN")
    }

    func fabMenuWillClose(fabMenu: FABMenu) {
        fabMenu.fabButton?.animate(Motion.rotation(angle: 0))
    }

    func fabMenuDidClose(fabMenu: FABMenu) {
        print("fabMenuDidClose")
    }

    func fabMenu(fabMenu: FABMenu, tappedAt point: CGPoint, isOutside: Bool) {
    }
}

extension Int {
    func clamp(min: Int, _ max: Int) -> Int {
        return Swift.max(min, Swift.min(max, self))
    }
}
