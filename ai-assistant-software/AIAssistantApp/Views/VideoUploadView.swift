import SwiftUI
import UniformTypeIdentifiers

struct VideoUploadView: View {
    @ObservedObject var viewModel: AssistantViewModel
    @Binding var isDragging: Bool
    @State private var videoURL: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // 拖拽上传区域
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isDragging ? Color.blue : Color.primary.opacity(0.15),
                        style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(isDragging ? Color.blue.opacity(0.05) : Color.clear)
                    )
                
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: "arrow.up.doc.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.blue.opacity(0.8))
                    }
                    
                    VStack(spacing: 6) {
                        Text("拖拽视频到此处")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary.opacity(0.8))
                        
                        Text("支持 MP4, MOV, AVI 格式")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 180)
            .padding(.horizontal, 20)
            .onDrop(of: [UTType.movie], isTargeted: $isDragging) { providers in
                handleDrop(providers: providers)
                return true
            }
            
            // 分隔线
            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(height: 1)
                
                Text("或")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(height: 1)
            }
            .padding(.horizontal, 32)
            
            // URL 输入
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                TextField("粘贴视频链接...", text: $videoURL)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                
                Button(action: { submitURL() }) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(videoURL.isEmpty ? .secondary : .blue)
                }
                .buttonStyle(.plain)
                .disabled(videoURL.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        provider.loadItem(forTypeIdentifier: UTType.movie.identifier, options: nil) { item, error in
            if let url = item as? URL {
                DispatchQueue.main.async {
                    viewModel.uploadVideo(url: url)
                }
            }
        }
    }
    
    private func submitURL() {
        guard let url = URL(string: videoURL) else { return }
        viewModel.uploadVideo(url: url)
    }
}
