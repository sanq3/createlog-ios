import SwiftUI
// AVFoundation は iOS 26 時点で Sendable 表記が不完全 (AVCaptureSession 等が Sendable 未宣言)。
// @preconcurrency import で「Sendable 関連 error を warning に格下げ」して運用する。
// Apple 側で annotation 完了したら外す。
@preconcurrency import AVFoundation

struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var scannedCode: String?
    @State private var scannedUsername: String?
    @State private var cameraPermissionDenied = false
    @State private var torchOn = false
    @State private var showResult = false

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if cameraPermissionDenied {
                permissionDeniedView
            } else {
                CameraPreview(scannedCode: $scannedCode, torchOn: $torchOn)
                    .ignoresSafeArea()

                // Scan overlay
                if showResult, let username = scannedUsername {
                    scanResultOverlay(username: username)
                } else {
                    scanOverlay
                }
            }

            // Top bar
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.white.opacity(0.15), in: Circle())
                    }

                    Spacer()

                    Button {
                        torchOn.toggle()
                    } label: {
                        Image(systemName: torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.white.opacity(0.15), in: Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer()
            }
        }
        .onChange(of: scannedCode) { _, code in
            guard let code else { return }
            HapticManager.light()
            handleScannedCode(code)
        }
        .onAppear {
            checkCameraPermission()
        }
    }

    private var scanOverlay: some View {
        VStack(spacing: 24) {
            Spacer()

            // Scan frame
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(.white.opacity(0.6), lineWidth: 3)
                .frame(width: 260, height: 260)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.black.opacity(0.01))
                )

            Text("share.qr.scanTitle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            Text("share.qr.instruction")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            Spacer()
        }
    }

    private func scanResultOverlay(username: String) -> some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                AvatarView(initials: String(username.prefix(1)).uppercased(), size: 72, status: .offline)

                Text("@\(username)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                NavigationLink {
                    UserProfileView(user: User(name: username, handle: username))
                } label: {
                    Text("profile.view")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 40)
            }
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 24)
            )
            .padding(.horizontal, 28)
            .transition(.move(edge: .bottom).combined(with: .opacity))

            Spacer().frame(height: 80)
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.4))

            Text("share.camera.permissionTitle")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)

            Text("share.camera.permissionBody")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("common.openSettings")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 160, height: 44)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 8)
        }
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if !granted {
                    Task { @MainActor in
                        cameraPermissionDenied = true
                    }
                }
            }
        default:
            cameraPermissionDenied = true
        }
    }

    private func handleScannedCode(_ code: String) {
        // Extract username from createlog.app URL
        if let url = URL(string: code),
           url.host() == "createlog.app" || url.host() == "www.createlog.app" {
            let username = url.lastPathComponent
            if !username.isEmpty, username != "/" {
                scannedUsername = username
                withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                    showResult = true
                }
                return
            }
        }
        // Not a valid CreateLog QR
        scannedUsername = nil
        scannedCode = nil
    }
}

// MARK: - Camera Preview

struct CameraPreview: UIViewRepresentable {
    @Binding var scannedCode: String?
    @Binding var torchOn: Bool

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.setTorch(on: torchOn)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(scannedCode: $scannedCode)
    }

    /// delegate callback は `output.setMetadataObjectsDelegate(delegate, queue: .main)` で
    /// main queue に固定されているため @MainActor 化して安全。これで `sending self` data race
    /// 警告と `scannedCode` Binding の main-actor access 違反が両方消える。
    @MainActor
    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        @Binding var scannedCode: String?
        private var hasScanned = false

        init(scannedCode: Binding<String?>) {
            _scannedCode = scannedCode
        }

        nonisolated func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value = object.stringValue
            else { return }

            Task { @MainActor in
                guard !hasScanned else { return }
                hasScanned = true
                scannedCode = value
            }
        }
    }
}

final class CameraPreviewUIView: UIView {
    /// Coordinator を weak で保持して UIView→Coordinator→UIView の retain cycle を断つ。
    /// UIViewRepresentable の Coordinator は SwiftUI 側で寿命管理されるので weak で十分。
    weak var delegate: AVCaptureMetadataOutputObjectsDelegate? {
        didSet { setupSession() }
    }

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }

    func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch
        else { return }

        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }

    private func setupSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device)
        else { return }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        let output = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
            output.setMetadataObjectsDelegate(delegate, queue: .main)
            output.metadataObjectTypes = [.qr]
        }

        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        self.layer.addSublayer(layer)
        previewLayer = layer

        // @Sendable closure 内から main-actor property `captureSession` を参照できないため、
        // local 変数にキャプチャしてから background で起動する。AVCaptureSession は
        // @preconcurrency import により Sendable 違反が warning 扱い化する。
        let session = captureSession
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    deinit {
        // AVCaptureSession.stopRunning() は synchronous & blocking。
        // deinit は main thread で呼ばれる場合があり、そこで blocking すると UI が hang する。
        // session を capture して background queue で停止する (Apple docs 推奨パターン)。
        //
        // UIView subclass の deinit は UIKit の lifecycle 保証で main thread 上で実行される
        // ため、`MainActor.assumeIsolated` で runtime assert してから main-actor property
        // `captureSession` へアクセスする (Swift 6 の nonisolated deinit 制約回避)。
        MainActor.assumeIsolated {
            let session = captureSession
            DispatchQueue.global(qos: .userInitiated).async {
                session.stopRunning()
            }
        }
    }
}
