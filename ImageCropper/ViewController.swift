//
//  ViewController.swift
//  ImageCropper
//
//  Created by 이지훈 on 12/23/24.
//

import UIKit
import Photos

class ViewController: UIViewController {
    
    private let imageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        view.backgroundColor = .lightGray
        return view
    }()
    
    private let selectButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("이미지 선택", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 10
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        title = "이미지 크롭"
        
        view.addSubview(imageView)
        view.addSubview(selectButton)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),
            
            selectButton.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
            selectButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            selectButton.widthAnchor.constraint(equalToConstant: 200),
            selectButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        selectButton.addTarget(self, action: #selector(selectButtonTapped), for: .touchUpInside)
    }
    
    @objc private func selectButtonTapped() {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        present(imagePicker, animated: true)
    }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        guard let selectedImage = info[.originalImage] as? UIImage else { return }
        
        picker.dismiss(animated: true) { [weak self] in
            let cropperVC = ImageCropperViewController(image: selectedImage) { croppedImage in
                self?.imageView.image = croppedImage
            }
            self?.navigationController?.pushViewController(cropperVC, animated: true)
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

// ImageCropperViewController.swift
import UIKit

public class ImageCropperViewController: UIViewController {
    
    // MARK: - Properties
    private let containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
        return view
    }()
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        return imageView
    }()
    
    private let cropAreaView: CropAreaView = {
        let view = CropAreaView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        return view
    }()
    
    private var imageViewWidthConstraint: NSLayoutConstraint?
    private var imageViewHeightConstraint: NSLayoutConstraint?
    
    private let pinchGR = UIPinchGestureRecognizer()
    private let panGR = UIPanGestureRecognizer()
    
    private var originalImage: UIImage
    private var cropCompletion: ((UIImage) -> Void)?
    
    // MARK: - Initialization
    public init(image: UIImage, completion: @escaping (UIImage) -> Void) {
        self.originalImage = image
        self.cropCompletion = completion
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupGestureRecognizers()
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        setupImageViewSize()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .black
        
        view.addSubview(containerView)
        containerView.addSubview(imageView)
        view.addSubview(cropAreaView)
        
        imageView.image = originalImage
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Crop",
            style: .done,
            target: self,
            action: #selector(cropButtonTapped)
        )
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            cropAreaView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cropAreaView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cropAreaView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            cropAreaView.heightAnchor.constraint(equalTo: cropAreaView.widthAnchor)
        ])
        
        imageView.center = cropAreaView.center
    }
    
    private func setupGestureRecognizers() {
        pinchGR.addTarget(self, action: #selector(pinch(_:)))
        panGR.addTarget(self, action: #selector(pan(_:)))
        
        pinchGR.delegate = self
        panGR.delegate = self
        
        cropAreaView.addGestureRecognizer(pinchGR)
        cropAreaView.addGestureRecognizer(panGR)
    }
    
    private func setupImageViewSize() {
        let imageRatio = originalImage.size.width / originalImage.size.height
        let cropViewRatio = cropAreaView.frame.width / cropAreaView.frame.height
        let screenWidth = UIScreen.main.bounds.width
        
        if imageViewWidthConstraint == nil {
            imageViewWidthConstraint = imageView.widthAnchor.constraint(equalToConstant: screenWidth)
            imageViewHeightConstraint = imageView.heightAnchor.constraint(equalToConstant: screenWidth / imageRatio)
            
            if cropViewRatio > imageRatio {
                imageViewWidthConstraint?.constant = screenWidth
                imageViewHeightConstraint?.constant = screenWidth / imageRatio
            } else {
                imageViewWidthConstraint?.constant = screenWidth * imageRatio
                imageViewHeightConstraint?.constant = screenWidth
            }
            
            imageViewWidthConstraint?.isActive = true
            imageViewHeightConstraint?.isActive = true
        }
    }
    
    // MARK: - Actions
    @objc private func cropButtonTapped() {
        guard let image = imageView.image else { return }
        
        let xCrop = cropAreaView.frame.minX - imageView.frame.minX
        let yCrop = cropAreaView.frame.minY - imageView.frame.minY
        let scaleRatio = image.size.width / imageView.frame.width
        
        let scaledCropRect = CGRect(
            x: xCrop * scaleRatio,
            y: yCrop * scaleRatio,
            width: cropAreaView.frame.width * scaleRatio,
            height: cropAreaView.frame.height * scaleRatio
        )
        
        guard let cutImageRef = image.cgImage?.cropping(to: scaledCropRect) else { return }
        
        let croppedImage = UIImage(cgImage: cutImageRef)
        cropCompletion?(croppedImage)
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - Gesture Recognition
extension ImageCropperViewController: UIGestureRecognizerDelegate {
    
    @objc private func pinch(_ sender: UIPinchGestureRecognizer) {
        switch sender.state {
        case .began, .changed:
            var transform = imageView.transform
            transform = transform.scaledBy(x: sender.scale, y: sender.scale)
            imageView.transform = transform
        case .ended:
            validatePinchGesture()
        default:
            break
        }
        sender.scale = 1.0
    }
    
    private func validatePinchGesture() {
        var transform = imageView.transform
        let minZoom: CGFloat = 1.0
        let maxZoom: CGFloat = 3.0
        var needsReset = false
        
        if transform.a < minZoom {
            transform = .identity
            needsReset = true
        }
        
        if transform.a > maxZoom {
            transform.a = maxZoom
            transform.d = maxZoom
            needsReset = true
        }
        
        if needsReset {
            UIView.animate(withDuration: 0.3) {
                self.imageView.transform = transform
            }
        }
    }
    
    @objc private func pan(_ sender: UIPanGestureRecognizer) {
        let translation = sender.translation(in: view)
        imageView.center = CGPoint(
            x: imageView.center.x + translation.x,
            y: imageView.center.y + translation.y
        )
        sender.setTranslation(.zero, in: view)
        
        if sender.state == .ended {
            validatePanGesture()
        }
    }
    
    private func validatePanGesture() {
        let imageRect = imageView.frame
        let cropRect = cropAreaView.frame
        var correctedFrame = imageRect
        
        if imageRect.minY > cropRect.minY {
            correctedFrame.origin.y = cropRect.minY
        }
        if imageRect.maxY < cropRect.maxY {
            correctedFrame.origin.y = cropRect.maxY - imageRect.height
        }
        if imageRect.minX > cropRect.minX {
            correctedFrame.origin.x = cropRect.minX
        }
        if imageRect.maxX < cropRect.maxX {
            correctedFrame.origin.x = cropRect.maxX - imageRect.width
        }
        
        if imageRect != correctedFrame {
            UIView.animate(withDuration: 0.3) {
                self.imageView.frame = correctedFrame
            }
        }
    }
    
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return true
    }
}

// CropAreaView.swift
public class CropAreaView: UIView {
    public override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        backgroundColor?.setFill()
        UIRectFill(rect)
        
        let layer = CAShapeLayer()
        let path = CGMutablePath()
        
        path.addRoundedRect(
            in: bounds,
            cornerWidth: bounds.width/2,
            cornerHeight: bounds.width/2
        )
        path.addRect(bounds)
        
        layer.path = path
        layer.fillRule = .evenOdd
        
        self.layer.mask = layer
    }
}
