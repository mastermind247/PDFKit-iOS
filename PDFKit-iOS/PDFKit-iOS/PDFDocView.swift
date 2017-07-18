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
    var annotationArray = [PDFAnnotation]()

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
        if let pdfUrl = Bundle.main.url(forResource: "NCPocDoc.pdf", withExtension: nil) {
            let documentUrl = pdfUrl as CFURL
            pdfFile = CGPDFDocument(documentUrl)
            numberOfPages = pdfFile.numberOfPages as Int
            print("PDF Loaded with \(numberOfPages) pages")
            loadPDFInView()
        } else {
            print("Error Loading PDF file")
        }
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return pdfScrollView.tiledPDFView
    }

    func loadPDFInView() {
        if numberOfPages > 1 {
            pdfScrollView = TiledPDFScrollView(frame: CGRect(x: 0, y: 50, w: self.bounds.width, h: self.bounds.height - 50))
            addPageControlView()
        } else {
            pdfScrollView = TiledPDFScrollView(frame: self.bounds)
        }
        pdfScrollView.delegate = self
        self.addSubview(pdfScrollView)
        currentPageNumber = 1
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
        annotationArray.append(PDFAnnotation(type: "fillcircle",
                                             color: "blue",
                                             x: circle.frame.x,
                                             y: circle.frame.y,
                                             radius: circle.frame.height/2,
                                             classType: "Annotation",
                                             uuid: UUID().uuidString,
                                             page: 1))
        emitAddAnnotationEvent(annotation: circle)
        fabMenu.close()
        fabMenu.fabButton?.animate(Motion.rotation(angle: 0))

    }

}

extension PDFDocView {

    @discardableResult
    func addCircle(xPos: CGFloat, yPos: CGFloat, radius: CGFloat) -> UIView {
        let circleView = CircleAnnotation(frame: CGRect(x: 0, y: 0, w: radius * 2, h: radius * 2))
        circleView.backgroundColor = UIColor.clear
        let resizableCircle = ZDStickerView(frame: CGRect(x: xPos, y: yPos, w: radius * 2, h: radius * 2))
        resizableCircle.tag = 10
        resizableCircle.contentView = circleView
        resizableCircle.stickerViewDelegate = self
        resizableCircle.preventsPositionOutsideSuperview = true
        resizableCircle.setButton(ZDSTICKERVIEW_BUTTON_DEL, image: Icon.close)
        resizableCircle.showEditingHandles()
        pdfScrollView.tiledPDFView.addSubview(resizableCircle)
        return circleView
    }

    func addText() {
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
            addCircle(xPos: xPos, yPos: yPos, radius: radius)
            annotationArray.append(PDFAnnotation(type: circleData["type"] as! String,
                                                 color: circleData["color"] as! String,
                                                 x: circleData["cx"] as! CGFloat,
                                                 y: circleData["cy"] as! CGFloat,
                                                 radius: circleData["r"] as! CGFloat,
                                                 classType: circleData["class"] as! String,
                                                 uuid: circleData["uuid"] as! String,
                                                 page: circleData["page"] as! Int))
        }
    }

    func emitAddAnnotationEvent(annotation: UIView) {
        let annotationDict: [String:Any] = ["type":"area",
                                               "x": 45.11278195488722,
                                               "y": 40.6015037593985,
                                               "width": 498.49624060150376,
                                               "height": 66.9172932330827,
                                               "class": "Annotation",
                                               "uuid": UUID().uuidString,
                                               "page": 1
                                               ]
        socket?.emit(SocketEvents.addAnnotation, with: [annotationDict])
    }

    func deleteAnnotationSocketEvent(data: [Any]) {
        print("=======DELETE ANNOTATION CALLED=======")
        socket?.emit(SocketEvents.deleteAnnotation, with: [["uuid":"5bc6d96e-694d-456a-b687-3e6c1efc8c76",
                                                            "documentId":"shared/example.pdf",
                                                            "is_deleted":true,
                                                            "i_by":"5bc6d96e-694d-456a-b687-3e6c1efc8c76",
                                                            "page":1]])

    }

    func emitDeleteAnnotationEvent() {

    }

    func clearAnnotationsSocketEvent(data: [Any]) {
        print("=======CLEAR ANNOTATION CALLED=======")

    }

    func emitClearAnnotationEvent() {
        socket?.emit(SocketEvents.clearAnnotation, with: [["clear"]])
    }

    func editAnnotationSocketEvent(data: [Any]) {
        print("=======EDIT ANNOTATION CALLED=======")

    }

    func emitEditAnnotationEvent() {

    }
}



extension PDFDocView: ZDStickerViewDelegate {

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
