import PhotosUI
import StoreKit
import SwiftUI

struct ScannerHomeView: View {
    @EnvironmentObject var history: HistoryStore
    @EnvironmentObject var store: StoreManager
    @Environment(\.requestReview) private var requestReview

    @StateObject private var camera = CameraController()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var pasteSheetPresented = false
    @State private var pastedText = ""
    @State private var pastedProductName = ""
    @State private var isAnalyzing = false
    @State private var errorMessage: String?

    @Binding var activeResult: ScanRecord?
    @Binding var paywallRecordPreview: ScanRecord?
    @Binding var showPaywall: Bool
    var onOpenPK: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    headerStrip
                    activeRadarStrip
                    viewfinderCard
                    quickActionRow
                    instantSamplesSection
                    trustFooterBanner
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(LabTheme.paper.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        Image(systemName: "viewfinder.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(LabTheme.danger)
                        Text(L10n.t("配料照妖镜", "PureScan"))
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(LabTheme.ink)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        paywallRecordPreview = history.records.first
                        showPaywall = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: store.isPro ? "checkmark.seal.fill" : "crown.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(store.isPro ? "PRO" : L10n.t("解锁全雷达", "PRO"))
                                .font(.system(size: 12, weight: .black))
                        }
                        .foregroundStyle(store.isPro ? LabTheme.clean : .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(store.isPro ? LabTheme.cleanSoft : LabTheme.ink)
                        .clipShape(Capsule())
                    }
                }
            }
            .onAppear { camera.startIfPossible() }
            .onDisappear { camera.stop() }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task { await handlePickedPhoto(newItem) }
            }
            .sheet(isPresented: $pasteSheetPresented) {
                pasteInputSheet
            }
            .alert(L10n.t("识别提示", "Scan Notice"), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(L10n.t("好的", "OK"), role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var headerStrip: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.t("0广告离线拍配料 · 0.3秒照出狠活", "ZERO-AD OFFLINE OCR · INSTANT RED FLAGS"))
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(LabTheme.muted)
                Text(L10n.t("对准包装背面配料表，一眼看穿能不能买", "Point at any ingredient label — know in 1 second"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(LabTheme.ink)
            }
            Spacer()
            if !store.isPro {
                Text(L10n.t("今日余 \(store.remainingFreeScansToday) 次", "\(store.remainingFreeScansToday) free left"))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(LabTheme.clean)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(LabTheme.cleanSoft)
                    .clipShape(Capsule())
            }
        }
    }

    private var activeRadarStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RadarType.allCases) { radar in
                    let isOn = history.activeRadars.contains(radar)
                    Button {
                        let ok = history.toggleRadar(radar, isPro: store.isPro)
                        if !ok {
                            paywallRecordPreview = history.records.first
                            showPaywall = true
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: radar.icon)
                                .font(.system(size: 12, weight: .bold))
                            Text(radar.shortTag)
                                .font(.system(size: 12, weight: .bold))
                            if !radar.isFreeBase && !store.isPro && !isOn && history.activeRadars.filter({ !$0.isFreeBase }).count >= 1 {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 9))
                                    .opacity(0.7)
                            }
                        }
                        .foregroundStyle(isOn ? .white : LabTheme.ink)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(isOn ? LabTheme.ink : LabTheme.card)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(isOn ? Color.clear : LabTheme.hairline, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var viewfinderCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.09, green: 0.095, blue: 0.09))
                .frame(height: 270)

            if camera.isCameraAvailable && camera.isAuthorized {
                CameraPreviewRepresentable(session: camera.session)
                    .frame(height: 270)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            } else {
                // Crisp editorial demo label backdrop on simulator or before camera permission
                VStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Circle().fill(LabTheme.clean).frame(width: 7, height: 7)
                        Text(L10n.t("APPLE VISION 本地离线 OCR 引擎就绪", "ON-DEVICE APPLE VISION OCR READY"))
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.t("配料：小麦粉、白砂糖、人造奶油、果葡糖浆、", "Ingredients: Wheat Flour, Sugar, Margarine, HFCS,"))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.65))
                        HStack(spacing: 6) {
                            Text(L10n.t("脱氢乙酸钠", "Sodium Dehydroacetate"))
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(LabTheme.danger)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            Text(L10n.t("氢化植物油", "Hydrogenated Oil"))
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(LabTheme.danger)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            Text(L10n.t("三氯蔗糖", "Sucralose"))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.yellow)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 22)

                    Text(L10n.t("无惧条形码查不到 · 地下超市没信号也能 0.3 秒直出", "Works without barcodes or signal · 100% offline"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }

            // Corner viewfinder reticle
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [LabTheme.danger.opacity(0.9), LabTheme.clean.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 2, dash: [14, 10])
                )
                .padding(18)
                .frame(height: 270)

            // Bottom shutter bar inside viewfinder
            VStack {
                HStack {
                    Text(L10n.t("离线 · 免登录", "OFFLINE · NO LOGIN"))
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.55))
                        .clipShape(Capsule())
                    Spacer()
                    if camera.isCameraAvailable {
                        Button {
                            camera.toggleTorch()
                        } label: {
                            Image(systemName: camera.torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(camera.torchOn ? .yellow : .white)
                                .padding(8)
                                .background(.black.opacity(0.55))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(14)

                Spacer()

                HStack(spacing: 12) {
                    Button {
                        triggerPrimaryScan()
                    } label: {
                        HStack(spacing: 8) {
                            if isAnalyzing {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 17, weight: .bold))
                            }
                            Text(camera.isCameraAvailable
                                 ? L10n.t("拍照照配料", "Scan Label Now")
                                 : L10n.t("点我秒测网红吐司", "Try Live Demo Scan"))
                                .font(.system(size: 15, weight: .black))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(LabTheme.danger)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(isAnalyzing)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
            .frame(height: 270)
        }
    }

    private var quickActionRow: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(LabTheme.ink)
                    Text(L10n.t("相册/网购截图识图", "Photo / Screenshot"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(LabTheme.ink)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(LabTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(LabTheme.hairline, lineWidth: 1))
            }

            Button {
                pasteSheetPresented = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(LabTheme.ink)
                    Text(L10n.t("粘贴文字秒查", "Paste Label"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(LabTheme.ink)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(LabTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(LabTheme.hairline, lineWidth: 1))
            }
        }
    }

    private var instantSamplesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.t("手里没零食？1 秒实测热门爆款样本", "No package handy? Test real label samples"))
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(LabTheme.ink)
                Spacer()
                Button {
                    onOpenPK()
                } label: {
                    Text(L10n.t("去双品 PK →", "VS Compare →"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(LabTheme.danger)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(SampleCatalog.all) { sample in
                    Button {
                        runTextAnalysis(
                            rawText: sample.rawText,
                            productName: sample.displayName,
                            preferredDomain: sample.domain
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: sample.domain.icon)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(LabTheme.muted)
                                Spacer()
                                Text(sample.displayBadge)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(LabTheme.danger)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(LabTheme.dangerSoft)
                                    .clipShape(Capsule())
                            }
                            Text(sample.displayName)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(LabTheme.ink)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(LabTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LabTheme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var trustFooterBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 18))
                .foregroundStyle(LabTheme.clean)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("永久 0 广告 · 照片绝不上传云端", "Zero Ads Forever · Photos Never Leave Your iPhone"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(LabTheme.ink)
                Text(L10n.t("依据 GB 2760 / FDA / EFSA / INCI 公开标准做科普解析，仅供参考不构成医疗建议。", "Educational parsing based on GB 2760 / FDA / EFSA / INCI references. Not medical advice."))
                    .font(.system(size: 11))
                    .foregroundStyle(LabTheme.muted)
            }
        }
        .labCard(padding: 12)
    }

    private var pasteInputSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                TextField(L10n.t("商品名称（选填，例如：某品牌燕麦奶）", "Product name (optional)"), text: $pastedProductName)
                    .padding(12)
                    .background(LabTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(LabTheme.hairline, lineWidth: 1))

                Text(L10n.t("粘贴或输入完整配料表 / 护肤品成分表：", "Paste or type ingredients list:"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LabTheme.muted)

                TextEditor(text: $pastedText)
                    .frame(minHeight: 170)
                    .padding(10)
                    .background(LabTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(LabTheme.hairline, lineWidth: 1))

                HStack {
                    Button {
                        if let clip = UIPasteboard.general.string {
                            pastedText = clip
                        }
                    } label: {
                        Label(L10n.t("从剪贴板粘贴", "Paste Clipboard"), systemImage: "doc.on.clipboard")
                            .font(.system(size: 13, weight: .bold))
                    }
                    Spacer()
                }

                Spacer()

                Button {
                    let txt = pastedText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !txt.isEmpty else { return }
                    pasteSheetPresented = false
                    runTextAnalysis(rawText: txt, productName: pastedProductName.isEmpty ? nil : pastedProductName, preferredDomain: nil)
                    pastedText = ""
                    pastedProductName = ""
                } label: {
                    Text(L10n.t("立即照妖镜分析", "Analyze Now"))
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : LabTheme.danger)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
            .background(LabTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.t("粘贴配料表秒查", "Paste Label Text"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("取消", "Cancel")) { pasteSheetPresented = false }
                }
            }
        }
    }

    private func triggerPrimaryScan() {
        guard store.canScanForFree else {
            paywallRecordPreview = history.records.first
            showPaywall = true
            return
        }
        if camera.isCameraAvailable {
            isAnalyzing = true
            camera.capturePhoto { image in
                guard let image else {
                    isAnalyzing = false
                    errorMessage = L10n.t("未能获取相机画面，请改用相册识图或重试。", "Failed to capture frame. Try photo import.")
                    return
                }
                Task { await processCapturedImage(image) }
            }
        } else if let first = SampleCatalog.all.first {
            runTextAnalysis(rawText: first.rawText, productName: first.displayName, preferredDomain: first.domain)
        }
    }

    private func handlePickedPhoto(_ item: PhotosPickerItem) async {
        guard store.canScanForFree else {
            paywallRecordPreview = history.records.first
            showPaywall = true
            selectedPhotoItem = nil
            return
        }
        isAnalyzing = true
        defer { selectedPhotoItem = nil }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await processCapturedImage(image)
            } else {
                isAnalyzing = false
                errorMessage = VisionOCRError.invalidImage.localizedDescription
            }
        } catch {
            isAnalyzing = false
            errorMessage = error.localizedDescription
        }
    }

    private func processCapturedImage(_ image: UIImage) async {
        do {
            let text = try await VisionOCRService.recognizeIngredients(from: image)
            isAnalyzing = false
            runTextAnalysis(rawText: text, productName: nil, preferredDomain: nil)
        } catch {
            isAnalyzing = false
            errorMessage = error.localizedDescription
        }
    }

    private func runTextAnalysis(rawText: String, productName: String?, preferredDomain: ScanDomain?) {
        guard store.canScanForFree else {
            paywallRecordPreview = history.records.first
            showPaywall = true
            return
        }
        let record = IngredientAnalyzer.analyze(
            rawText: rawText,
            productName: productName,
            preferredDomain: preferredDomain,
            activeRadars: history.activeRadars,
            customBlacklist: history.customBlacklist
        )
        store.recordCompletedScan()
        history.saveRecord(record)

        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(record.grade == .clean ? .success : .warning)

        activeResult = record

        // Gently prompt 5-star review right after user's 2nd joyful free scan
        if store.totalSuccessfulScans == 2 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                requestReview()
            }
        }
    }
}
