import AppKit
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        }
    }

    var localeIdentifier: String { rawValue }
}

enum MotionIntensity: String, CaseIterable, Identifiable {
    case enhanced
    case reduced
    case none

    var id: String { rawValue }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .enhanced: L10n.text("Enhanced", language: language)
        case .reduced: L10n.text("Reduced", language: language)
        case .none: L10n.text("Off", language: language)
        }
    }
}

struct AccentColorOption: Identifiable, Hashable {
    let id: String
    let simplifiedName: String
    let traditionalName: String
    let englishName: String
    let color: Color

    func name(for language: AppLanguage) -> String {
        switch language {
        case .english: englishName
        case .simplifiedChinese: simplifiedName
        case .traditionalChinese: traditionalName
        }
    }

    static let all: [AccentColorOption] = [
        AccentColorOption(id: "red", simplifiedName: "红", traditionalName: "紅", englishName: "Red", color: Color(red: 0.90, green: 0.24, blue: 0.28)),
        AccentColorOption(id: "orange", simplifiedName: "橙", traditionalName: "橙", englishName: "Orange", color: Color(red: 0.94, green: 0.48, blue: 0.16)),
        AccentColorOption(id: "yellow", simplifiedName: "黄", traditionalName: "黃", englishName: "Yellow", color: Color(red: 0.90, green: 0.72, blue: 0.18)),
        AccentColorOption(id: "green", simplifiedName: "绿", traditionalName: "綠", englishName: "Green", color: Color(red: 0.22, green: 0.70, blue: 0.38)),
        AccentColorOption(id: "cyan", simplifiedName: "青", traditionalName: "青", englishName: "Cyan", color: Color(red: 0.10, green: 0.70, blue: 0.76)),
        AccentColorOption(id: "blue", simplifiedName: "蓝", traditionalName: "藍", englishName: "Blue", color: Color(red: 0.20, green: 0.48, blue: 0.92)),
        AccentColorOption(id: "purple", simplifiedName: "紫", traditionalName: "紫", englishName: "Purple", color: Color(red: 0.56, green: 0.34, blue: 0.88)),
        AccentColorOption(id: "pink", simplifiedName: "粉", traditionalName: "粉", englishName: "Pink", color: Color(red: 0.92, green: 0.34, blue: 0.62)),
        AccentColorOption(id: "rose", simplifiedName: "玫瑰", traditionalName: "玫瑰", englishName: "Rose", color: Color(red: 0.86, green: 0.30, blue: 0.42)),
        AccentColorOption(id: "amber", simplifiedName: "琥珀", traditionalName: "琥珀", englishName: "Amber", color: Color(red: 0.96, green: 0.58, blue: 0.18)),
        AccentColorOption(id: "lime", simplifiedName: "青柠", traditionalName: "青檸", englishName: "Lime", color: Color(red: 0.54, green: 0.76, blue: 0.22)),
        AccentColorOption(id: "mint", simplifiedName: "薄荷", traditionalName: "薄荷", englishName: "Mint", color: Color(red: 0.18, green: 0.72, blue: 0.56)),
        AccentColorOption(id: "teal", simplifiedName: "蓝绿", traditionalName: "藍綠", englishName: "Teal", color: Color(red: 0.12, green: 0.58, blue: 0.70)),
        AccentColorOption(id: "indigo", simplifiedName: "靛蓝", traditionalName: "靛藍", englishName: "Indigo", color: Color(red: 0.36, green: 0.38, blue: 0.86)),
        AccentColorOption(id: "darkGray", simplifiedName: "深灰", traditionalName: "深灰", englishName: "Dark Gray", color: Color(red: 0.36, green: 0.38, blue: 0.43)),
        AccentColorOption(id: "lightGray", simplifiedName: "浅灰", traditionalName: "淺灰", englishName: "Light Gray", color: Color(red: 0.72, green: 0.74, blue: 0.78))
    ]

    static func option(for id: String) -> AccentColorOption {
        all.first { $0.id == id } ?? all[6]
    }
}

enum L10n {
    static func text(_ key: String, language: AppLanguage) -> String {
        switch language {
        case .english: key
        case .simplifiedChinese: simplified[key] ?? key
        case .traditionalChinese: traditional[key] ?? simplified[key] ?? key
        }
    }

    private static let simplified: [String: String] = [
        "Video Screen Saver Generator": "视频屏幕保护程序生成器", "Create": "创建", "Settings": "设置", "Workflow": "工作流", "Application": "应用程序",
        "Language": "语言", "Motion": "动态效果", "Accent Color": "强调色", "Enhanced": "增强", "Reduced": "减弱", "Off": "无动画",
        "Turn a local video into a native macOS screen saver.": "将本地视频转换为原生 macOS 屏幕保护程序。", "Tune the appearance and export defaults.": "调整外观和导出默认设置。",
        "Appearance": "外观", "Screen Saver": "屏幕保护程序", "Export": "导出", "Diagnostics": "诊断", "General": "通用",
        "Video preview": "视频预览", "Drop a file anywhere on the preview surface.": "将文件拖到预览区域的任意位置。", "Choose Video…": "选择视频…", "Replace…": "替换…",
        "No video selected": "未选择视频", "Container": "容器", "Duration": "时长", "Dimensions": "尺寸", "File size": "文件大小",
        "Screen saver settings": "屏幕保护程序设置", "Display name": "显示名称", "Content mode": "内容模式", "Fill": "填充", "Fit": "适应",
        "Fills the display and crops the edges when needed.": "填满显示区域，必要时裁剪边缘。", "Shows the complete frame with possible letterboxing.": "显示完整画面，可能出现黑边。",
        "Mute screen saver audio": "静音屏幕保护程序音频", "Export .saver…": "导出 .saver…", "Generate and Install": "生成并安装",
        "Copying video and signing…": "正在复制视频并签名…", "Ready": "已就绪", "Reveal in Finder": "在访达中显示", "Copy Path": "复制路径",
        "Technical details": "技术详情", "Choose a screen saver video": "选择屏幕保护程序视频", "Choose": "选择", "Export Screen Saver": "导出屏幕保护程序",
        "Generating screen saver…": "正在生成屏幕保护程序…", "Screen saver generated successfully.": "屏幕保护程序生成成功。", "Preview ready. Metadata is unavailable.": "预览就绪，但元数据不可用。", "Ready to export.": "已准备好导出。", "Choose a video to begin.": "选择视频以开始。", "The operation failed.": "操作失败。",
        "Default content mode": "默认内容模式", "Default mute": "默认静音", "Use these defaults for new exports.": "新导出将使用这些默认设置。",
        "The accent is used for actions, selection, and preview states.": "强调色用于操作、选择状态和预览状态。", "Reduce Motion in System Settings always takes priority.": "系统设置中的减弱动态效果始终优先。",
        "Generated screen savers contain a copy of the selected video. The original file is never moved, transcoded, or modified.": "生成的屏幕保护程序包含所选视频的副本。原始文件不会被移动、转码或修改。",
        "Universal 2 app and screen saver": "Universal 2 应用和屏幕保护程序", "Generated bundles use local ad-hoc signing": "生成的组件使用本地 ad-hoc 签名",
        "Application version": "应用版本", "Universal 2": "Universal 2", "Local ad-hoc signature": "本地 ad-hoc 签名", "Source file safety": "源文件安全", "Selected video": "已选视频", "None": "无", "Generator": "生成器", "Busy": "处理中", "Status": "状态", "Bundle": "组件", "Enabled": "已启用",
        "The original video is read-only during export.": "导出期间只读取原始视频。", "1.0.0": "1.0.0", "1.0.1": "1.0.1",
        "Create a screen saver": "创建屏幕保护程序", "Settings apply immediately to the native shell.": "设置会立即应用到原生界面。", "Drop a video here": "将视频拖到这里", "or choose an MP4, MOV, or M4V file": "或选择 MP4、MOV 或 M4V 文件", "Preview": "预览"
    ]

    private static let traditional: [String: String] = [
        "Video Screen Saver Generator": "影片螢幕保護程式產生器", "Create": "建立", "Settings": "設定", "Workflow": "工作流程", "Application": "應用程式",
        "Language": "語言", "Motion": "動態效果", "Accent Color": "強調色", "Enhanced": "增強", "Reduced": "減弱", "Off": "無動畫",
        "Turn a local video into a native macOS screen saver.": "將本機影片轉換為原生 macOS 螢幕保護程式。", "Tune the appearance and export defaults.": "調整外觀與匯出預設值。",
        "Appearance": "外觀", "Screen Saver": "螢幕保護程式", "Export": "匯出", "Diagnostics": "診斷", "General": "一般",
        "Video preview": "影片預覽", "Drop a file anywhere on the preview surface.": "將檔案拖曳到預覽區域的任意位置。", "Choose Video…": "選擇影片…", "Replace…": "取代…",
        "No video selected": "未選擇影片", "Container": "容器", "Duration": "長度", "Dimensions": "尺寸", "File size": "檔案大小",
        "Screen saver settings": "螢幕保護程式設定", "Display name": "顯示名稱", "Content mode": "內容模式", "Fill": "填滿", "Fit": "符合",
        "Fills the display and crops the edges when needed.": "填滿顯示區域，必要時裁切邊緣。", "Shows the complete frame with possible letterboxing.": "顯示完整畫面，可能出現黑邊。",
        "Mute screen saver audio": "將螢幕保護程式靜音", "Export .saver…": "匯出 .saver…", "Generate and Install": "產生並安裝",
        "Copying video and signing…": "正在複製影片並簽署…", "Ready": "已就緒", "Reveal in Finder": "在 Finder 中顯示", "Copy Path": "複製路徑",
        "Technical details": "技術詳細資料", "Choose a screen saver video": "選擇螢幕保護程式影片", "Choose": "選擇", "Export Screen Saver": "匯出螢幕保護程式",
        "Generating screen saver…": "正在產生螢幕保護程式…", "Screen saver generated successfully.": "螢幕保護程式產生成功。", "Preview ready. Metadata is unavailable.": "預覽就緒，但無法取得中繼資料。", "Ready to export.": "已準備匯出。", "Choose a video to begin.": "選擇影片以開始。", "The operation failed.": "操作失敗。",
        "Default content mode": "預設內容模式", "Default mute": "預設靜音", "Use these defaults for new exports.": "新的匯出會使用這些預設值。",
        "The accent is used for actions, selection, and preview states.": "強調色用於操作、選取狀態與預覽狀態。", "Reduce Motion in System Settings always takes priority.": "系統設定中的減少動態效果始終優先。",
        "Generated screen savers contain a copy of the selected video. The original file is never moved, transcoded, or modified.": "產生的螢幕保護程式包含所選影片的副本。原始檔案不會被移動、轉碼或修改。",
        "Universal 2 app and screen saver": "Universal 2 應用程式與螢幕保護程式", "Generated bundles use local ad-hoc signing": "產生的元件使用本機 ad-hoc 簽署",
        "Application version": "應用程式版本", "Universal 2": "Universal 2", "Local ad-hoc signature": "本機 ad-hoc 簽署", "Source file safety": "來源檔案安全性", "Selected video": "已選影片", "None": "無", "Generator": "產生器", "Busy": "處理中", "Status": "狀態", "Bundle": "元件", "Enabled": "已啟用",
        "The original video is read-only during export.": "匯出期間只會讀取原始影片。", "Create a screen saver": "建立螢幕保護程式", "Settings apply immediately to the native shell.": "設定會立即套用到原生介面。", "Drop a video here": "將影片拖曳到這裡", "or choose an MP4, MOV, or M4V file": "或選擇 MP4、MOV 或 M4V 檔案", "Preview": "預覽"
    ]
}

struct AccentColorPicker: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 16), spacing: 7), count: 8)
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 5) {
            ForEach(AccentColorOption.all) { option in
                Button {
                    withAnimation(reduceMotion ? nil : MotionTokens.color) {
                        model.accentColorID = option.id
                    }
                } label: {
                    Capsule(style: .continuous)
                        .fill(option.color)
                        .frame(height: 14)
                        .overlay {
                            if model.accentColorID == option.id {
                                Capsule(style: .continuous)
                                    .strokeBorder(.primary.opacity(0.9), lineWidth: 1.5)
                                    .overlay {
                                        Capsule(style: .continuous)
                                            .strokeBorder(.white.opacity(0.9), lineWidth: 0.8)
                                    }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 20)
                        .contentShape(Rectangle())
                        .accessibilityLabel(option.name(for: model.language))
                }
                .buttonStyle(LightweightPressButtonStyle())
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsRow<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .frame(width: 160, alignment: .leading)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SidebarStatusRow<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
            Spacer(minLength: 8)
            content
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

struct PageHeader: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let accentColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(accentColor)
                .frame(width: 38, height: 38)
                .background(accentColor.opacity(0.13), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title2.bold())
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SoftAppearModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : 8)
            .onAppear {
                guard !isVisible else { return }
                guard delay > 0 else {
                    withAnimation(reduceMotion ? nil : MotionTokens.appear) { isVisible = true }
                    return
                }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    withAnimation(reduceMotion ? nil : MotionTokens.appear) { isVisible = true }
                }
            }
    }
}

extension View {
    func softAppear(delay: Double = 0) -> some View {
        modifier(SoftAppearModifier(delay: delay))
    }
}

func makeInterfaceAnimation(reduceMotion: Bool, intensity: MotionIntensity) -> Animation? {
    guard !reduceMotion else { return nil }
    switch intensity {
    case .enhanced: return MotionTokens.page
    case .reduced: return MotionTokens.soft
    case .none: return nil
    }
}
