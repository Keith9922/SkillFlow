import SwiftUI

struct MainContentView: View {
    @ObservedObject var viewModel: AssistantViewModel
    @Binding var isDragging: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.3)
            
            // 视频上传区域 / 对话区域
            if viewModel.currentVideo == nil {
                VideoUploadView(viewModel: viewModel, isDragging: $isDragging)
            } else {
                ChatView(viewModel: viewModel)
            }
            
            Divider().opacity(0.3)
            
            // 输入区域
            InputBarView(viewModel: viewModel)
        }
    }
}
