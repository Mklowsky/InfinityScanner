import SwiftUI
import VisionKit
import PDFKit
import UniformTypeIdentifiers

struct ContentView: View {
    // Przechowujemy URL-e do tymczasowych plików ze zdjęciami,
    // aby uniknąć problemów z brakiem pamięci RAM (Out Of Memory) przy dużych książkach!
    @State private var scannedPageURLs: [URL] = []
    @State private var isShowingScanner = false
    @State private var isGeneratingPDF = false
    @State private var isRotating = false
    @State private var rotatingPageURL: URL?
    @State private var draggedPageURL: URL?
    @State private var previewingPageURL: URL?
    @State private var isShowingPreview = false
    @State private var pdfToShare: URL?
    @State private var isShowingShareSheet = false
    
    var body: some View {
        NavigationView {
            VStack {
                if scannedPageURLs.isEmpty {
                    // Ekran powitalny, gdy nie ma jeszcze skanów
                    VStack(spacing: 20) {
                        Image(systemName: "doc.viewfinder")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        Text("Brak zeskanowanych stron")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Skaner bez limitu stron.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Wskazówka dla użytkownika o podglądzie i przeciąganiu
                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap")
                            .foregroundColor(.secondary)
                        Text("Dotknij, aby powiększyć • Przytrzymaj i przesuń, aby zmienić kolejność")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                    
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 15) {
                            ForEach(scannedPageURLs, id: \.self) { url in
                                ZStack(alignment: .topTrailing) {
                                    // Ładowanie obrazu z pliku tymczasowego na dysku
                                    if let uiImage = UIImage(contentsOfFile: url.path) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 140)
                                            .cornerRadius(8)
                                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                                    }
                                    
                                    // Wskaźnik ładowania, jeśli dana strona jest akurat obracana
                                    if rotatingPageURL == url {
                                        ZStack {
                                            Color.black.opacity(0.4)
                                                .cornerRadius(8)
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        }
                                        .frame(width: 100, height: 140)
                                    }
                                    
                                    // Numer strony na dole miniatury
                                    if let index = scannedPageURLs.firstIndex(of: url) {
                                        Text("\(index + 1)")
                                            .font(.caption2.bold())
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(Color.black.opacity(0.6)))
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                            .padding(.bottom, 6)
                                    }
                                    
                                    // Przycisk obracania pojedynczej strony (lewy górny róg)
                                    Button(action: {
                                        rotatePage(url: url, by: 90)
                                    }) {
                                        Image(systemName: "rotate.right")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(6)
                                            .background(Circle().fill(Color.blue))
                                            .shadow(color: .black.opacity(0.3), radius: 2)
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                    .padding(4)
                                    .disabled(isRotating || isGeneratingPDF || rotatingPageURL != nil)
                                    
                                    // Przycisk usuwania strony (prawy górny róg)
                                    Button(action: {
                                        deletePage(url: url)
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.red)
                                            .background(Circle().fill(Color.white))
                                    }
                                    .padding(-5)
                                    .disabled(isRotating || isGeneratingPDF || rotatingPageURL != nil)
                                }
                                .frame(width: 100, height: 140)
                                .opacity(draggedPageURL == url ? 0.3 : 1.0)
                                .scaleEffect(draggedPageURL == url ? 1.05 : 1.0)
                                .onTapGesture {
                                    previewingPageURL = url
                                    isShowingPreview = true
                                }
                                .onDrag {
                                    self.draggedPageURL = url
                                    return NSItemProvider(object: url.path as NSString)
                                }
                                .onDrop(
                                    of: [UTType.text],
                                    delegate: PageDropDelegate(
                                        pageURL: url,
                                        pageURLs: $scannedPageURLs,
                                        draggedPageURL: $draggedPageURL
                                    )
                                )
                                .contextMenu {
                                    Button(action: {
                                        previewingPageURL = url
                                        isShowingPreview = true
                                    }) {
                                        Label("Powiększ i przeglądaj", systemImage: "arrow.up.left.and.arrow.down.right")
                                    }
                                    Button(action: { rotatePage(url: url, by: 90) }) {
                                        Label("Obróć o 90° w prawo", systemImage: "rotate.right")
                                    }
                                    Button(action: { rotatePage(url: url, by: -90) }) {
                                        Label("Obróć o 90° w lewo", systemImage: "rotate.left")
                                    }
                                    Button(action: { rotatePage(url: url, by: 180) }) {
                                        Label("Obróć o 180°", systemImage: "arrow.triangle.2.circlepath")
                                    }
                                    Divider()
                                    Button(role: .destructive, action: { deletePage(url: url) }) {
                                        Label("Usuń stronę", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .animation(.default, value: scannedPageURLs)
                        .padding()
                    }
                }
                
                VStack(spacing: 15) {
                    Button(action: {
                        isShowingScanner = true
                    }) {
                        Label(scannedPageURLs.isEmpty ? "Rozpocznij skanowanie" : "Skanuj kolejne strony", systemImage: "camera")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .disabled(isRotating || isGeneratingPDF || rotatingPageURL != nil)
                    
                    if !scannedPageURLs.isEmpty {
                        if isRotating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .cornerRadius(12)
                        } else {
                            HStack(spacing: 10) {
                                Button(action: {
                                    rotateAllPages(by: 90)
                                }) {
                                    Label("Obróć wszystkie (90°)", systemImage: "rotate.right")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.orange)
                                        .cornerRadius(12)
                                }
                                
                                Menu {
                                    Button(action: { rotateAllPages(by: 90) }) {
                                        Label("Obróć o 90° w prawo", systemImage: "rotate.right")
                                    }
                                    Button(action: { rotateAllPages(by: -90) }) {
                                        Label("Obróć o 90° w lewo", systemImage: "rotate.left")
                                    }
                                    Button(action: { rotateAllPages(by: 180) }) {
                                        Label("Obróć o 180°", systemImage: "arrow.triangle.2.circlepath")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding()
                                        .frame(width: 50)
                                        .background(Color.orange)
                                        .cornerRadius(12)
                                }
                            }
                            .disabled(isGeneratingPDF || rotatingPageURL != nil)
                        }
                        
                        Button(action: {
                            generatePDF()
                        }) {
                            if isGeneratingPDF {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .cornerRadius(12)
                            } else {
                                Label("Generuj PDF i Zapisz do Plików", systemImage: "square.and.arrow.up")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .cornerRadius(12)
                            }
                        }
                        .disabled(isGeneratingPDF || isRotating || rotatingPageURL != nil)
                    }
                }
                .padding()
            }
            .navigationTitle("Infinity Scanner")
            .toolbar {
                if !scannedPageURLs.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(action: { rotateAllPages(by: 90) }) {
                                Label("Obróć o 90° w prawo", systemImage: "rotate.right")
                            }
                            Button(action: { rotateAllPages(by: -90) }) {
                                Label("Obróć o 90° w lewo", systemImage: "rotate.left")
                            }
                            Button(action: { rotateAllPages(by: 180) }) {
                                Label("Obróć o 180°", systemImage: "arrow.triangle.2.circlepath")
                            }
                        } label: {
                            Image(systemName: "rotate.right")
                        }
                        .disabled(isRotating || isGeneratingPDF || rotatingPageURL != nil)
                    }
                }
            }
            .fullScreenCover(isPresented: $isShowingScanner) {
                DocumentCameraView(scannedPageURLs: $scannedPageURLs)
                    .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $isShowingPreview) {
                PagePreviewView(
                    scannedPageURLs: $scannedPageURLs,
                    selectedPageURL: $previewingPageURL,
                    onRotate: { url, degrees in
                        rotatePage(url: url, by: degrees)
                    },
                    onDelete: { url in
                        deletePage(url: url)
                    }
                )
            }
            .sheet(isPresented: $isShowingShareSheet) {
                if let pdfUrl = pdfToShare {
                    ShareSheet(activityItems: [pdfUrl])
                }
            }
        }
    }
    
    private func deletePage(url: URL) {
        if let index = scannedPageURLs.firstIndex(of: url) {
            try? FileManager.default.removeItem(at: url)
            scannedPageURLs.remove(at: index)
            if previewingPageURL == url {
                previewingPageURL = scannedPageURLs.indices.contains(index) ? scannedPageURLs[index] : scannedPageURLs.last
            }
        }
    }
    
    private func rotatePage(url: URL, by degrees: CGFloat = 90) {
        guard scannedPageURLs.contains(url) else { return }
        guard !isRotating && !isGeneratingPDF && rotatingPageURL == nil else { return }
        
        rotatingPageURL = url
        let oldURL = url
        
        DispatchQueue.global(qos: .userInitiated).async {
            var generatedURL: URL?
            autoreleasepool {
                if let image = UIImage(contentsOfFile: oldURL.path),
                   let rotatedImage = image.rotated(by: degrees),
                   let data = rotatedImage.jpegData(compressionQuality: 0.85) {
                    let tempDir = FileManager.default.temporaryDirectory
                    let destinationURL = tempDir.appendingPathComponent(UUID().uuidString + ".jpg")
                    do {
                        try data.write(to: destinationURL)
                        try? FileManager.default.removeItem(at: oldURL)
                        generatedURL = destinationURL
                    } catch {
                        print("Błąd zapisu obróconej strony: \(error)")
                    }
                }
            }
            
            DispatchQueue.main.async {
                if let newURL = generatedURL,
                   let currentIndex = self.scannedPageURLs.firstIndex(of: oldURL) {
                    self.scannedPageURLs[currentIndex] = newURL
                    if self.previewingPageURL == oldURL {
                        self.previewingPageURL = newURL
                    }
                }
                self.rotatingPageURL = nil
            }
        }
    }
    
    private func rotateAllPages(by degrees: CGFloat) {
        guard !scannedPageURLs.isEmpty else { return }
        guard rotatingPageURL == nil else { return }
        isRotating = true
        
        let urlsToRotate = scannedPageURLs
        
        // Wykonujemy obrót w tle z użyciem autoreleasepool, aby nie zająć pamięci RAM
        DispatchQueue.global(qos: .userInitiated).async {
            var newURLs: [URL] = []
            let tempDir = FileManager.default.temporaryDirectory
            
            for oldURL in urlsToRotate {
                autoreleasepool {
                    if let image = UIImage(contentsOfFile: oldURL.path),
                       let rotatedImage = image.rotated(by: degrees),
                       let data = rotatedImage.jpegData(compressionQuality: 0.85) {
                        let newURL = tempDir.appendingPathComponent(UUID().uuidString + ".jpg")
                        do {
                            try data.write(to: newURL)
                            newURLs.append(newURL)
                            try? FileManager.default.removeItem(at: oldURL)
                        } catch {
                            print("Błąd zapisu obróconego pliku: \(error)")
                            newURLs.append(oldURL)
                        }
                    } else {
                        newURLs.append(oldURL)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.scannedPageURLs = newURLs
                self.isRotating = false
            }
        }
    }
    
    private func generatePDF() {
        isGeneratingPDF = true
        
        // Wykonujemy w tle, żeby nie zablokować interfejsu przy generowaniu np. 300 stron
        DispatchQueue.global(qos: .userInitiated).async {
            let pdfDocument = PDFDocument()
            
            for (index, url) in self.scannedPageURLs.enumerated() {
                if let image = UIImage(contentsOfFile: url.path),
                   let pdfPage = PDFPage(image: image) {
                    pdfDocument.insert(pdfPage, at: index)
                }
            }
            
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "Skan_Książki_\(Date().timeIntervalSince1970).pdf"
            let pdfURL = tempDir.appendingPathComponent(fileName)
            
            pdfDocument.write(to: pdfURL)
            
            DispatchQueue.main.async {
                self.pdfToShare = pdfURL
                self.isGeneratingPDF = false
                self.isShowingShareSheet = true
            }
        }
    }
}

// MARK: - Przeciąganie i upuszczanie (Drag & Drop Reordering)
struct PageDropDelegate: DropDelegate {
    let pageURL: URL
    @Binding var pageURLs: [URL]
    @Binding var draggedPageURL: URL?

    func dropEntered(info: DropInfo) {
        guard let draggedPageURL = draggedPageURL,
              draggedPageURL != pageURL,
              let fromIndex = pageURLs.firstIndex(of: draggedPageURL),
              let toIndex = pageURLs.firstIndex(of: pageURL) else { return }

        withAnimation(.default) {
            pageURLs.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedPageURL = nil
        return true
    }
}

// MARK: - Pełnoekranowy podgląd strony (Page Preview)
struct PagePreviewView: View {
    @Binding var scannedPageURLs: [URL]
    @Binding var selectedPageURL: URL?
    var onRotate: (URL, CGFloat) -> Void
    var onDelete: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    var currentIndex: Int {
        guard let selected = selectedPageURL, let idx = scannedPageURLs.firstIndex(of: selected) else { return 0 }
        return idx
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)

                if scannedPageURLs.isEmpty {
                    Text("Brak stron do wyświetlenia")
                        .foregroundColor(.white)
                } else {
                    TabView(selection: Binding(
                        get: { selectedPageURL ?? scannedPageURLs.first! },
                        set: { selectedPageURL = $0 }
                    )) {
                        ForEach(scannedPageURLs, id: \.self) { url in
                            if let image = UIImage(contentsOfFile: url.path) {
                                ZoomableScrollView(image: image)
                                    .tag(url)
                            } else {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .tag(url)
                            }
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                }
            }
            .navigationTitle(scannedPageURLs.isEmpty ? "" : "Strona \(currentIndex + 1) z \(scannedPageURLs.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Gotowe") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }

                ToolbarItemGroup(placement: .bottomBar) {
                    if let currentURL = selectedPageURL, scannedPageURLs.contains(currentURL) {
                        Button(action: {
                            onRotate(currentURL, -90)
                        }) {
                            Label("W lewo", systemImage: "rotate.left")
                        }

                        Spacer()

                        Button(action: {
                            onRotate(currentURL, 90)
                        }) {
                            Label("W prawo", systemImage: "rotate.right")
                        }

                        Spacer()

                        Button(role: .destructive, action: {
                            let nextURL: URL?
                            if let idx = scannedPageURLs.firstIndex(of: currentURL) {
                                if idx + 1 < scannedPageURLs.count {
                                    nextURL = scannedPageURLs[idx + 1]
                                } else if idx > 0 {
                                    nextURL = scannedPageURLs[idx - 1]
                                } else {
                                    nextURL = nil
                                }
                            } else {
                                nextURL = nil
                            }
                            onDelete(currentURL)
                            if let next = nextURL {
                                selectedPageURL = next
                            } else {
                                dismiss()
                            }
                        }) {
                            Label("Usuń", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .accentColor(.white)
    }
}

// MARK: - Zoomowalny widok obrazu (Pinch to zoom + podwójne tapnięcie)
struct ZoomableScrollView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 5.0
        scrollView.minimumZoomScale = 1.0
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        let doubleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapGesture)

        context.coordinator.scrollView = scrollView
        context.coordinator.imageView = imageView
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: UIScrollView?
        var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return imageView
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = scrollView else { return }
            if scrollView.zoomScale > 1.0 {
                scrollView.setZoomScale(1.0, animated: true)
            } else {
                let point = gesture.location(in: imageView)
                let size = scrollView.bounds.size
                let w = size.width / 2.5
                let h = size.height / 2.5
                let rect = CGRect(x: point.x - w / 2, y: point.y - h / 2, width: w, height: h)
                scrollView.zoom(to: rect, animated: true)
            }
        }
    }
}

// MARK: - Pomocnicze rozszerzenia
extension UIImage {
    func rotated(by degrees: CGFloat) -> UIImage? {
        let normalizedDegrees = (Int(degrees.rounded()) % 360 + 360) % 360
        guard normalizedDegrees != 0 else { return self }
        
        let radians = CGFloat(normalizedDegrees) * .pi / 180.0
        
        let newSize: CGSize
        if normalizedDegrees == 90 || normalizedDegrees == 270 {
            newSize = CGSize(width: size.height, height: size.width)
        } else if normalizedDegrees == 180 {
            newSize = size
        } else {
            let rect = CGRect(origin: .zero, size: size)
                .applying(CGAffineTransform(rotationAngle: radians))
            newSize = CGSize(width: ceil(rect.width), height: ceil(rect.height))
        }
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: newSize.width / 2.0, y: newSize.height / 2.0)
            cgContext.rotate(by: radians)
            draw(in: CGRect(
                x: -size.width / 2.0,
                y: -size.height / 2.0,
                width: size.width,
                height: size.height
            ))
        }
    }
}

// MARK: - Skaner (VisionKit Wrapper)
struct DocumentCameraView: UIViewControllerRepresentable {
    @Binding var scannedPageURLs: [URL]
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let viewController = VNDocumentCameraViewController()
        viewController.delegate = context.coordinator
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var parent: DocumentCameraView
        
        init(_ parent: DocumentCameraView) {
            self.parent = parent
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // Zapisujemy obrazy na dysku aby nie zabić pamięci RAM przy wielkich skanach
            DispatchQueue.global(qos: .userInitiated).async {
                var newURLs: [URL] = []
                let tempDir = FileManager.default.temporaryDirectory
                
                for i in 0..<scan.pageCount {
                    let image = scan.imageOfPage(at: i)
                    // Kompresja JPG (0.85 to idealny balans jakość/waga dla wielostronicowych PDF)
                    if let data = image.jpegData(compressionQuality: 0.85) {
                        let fileURL = tempDir.appendingPathComponent(UUID().uuidString + ".jpg")
                        do {
                            try data.write(to: fileURL)
                            newURLs.append(fileURL)
                        } catch {
                            print("Błąd zapisu pliku: \(error)")
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self.parent.scannedPageURLs.append(contentsOf: newURLs)
                    self.parent.dismiss()
                }
            }
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Błąd skanera: \(error.localizedDescription)")
            parent.dismiss()
        }
    }
}

// MARK: - Moduł Udostępniania (Zapis do "Pliki")
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
