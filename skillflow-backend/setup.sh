#!/bin/bash
# SkillFlow Backend 安装脚本

echo "🚀 开始安装 SkillFlow Backend..."

# 检查 Python 版本
python_version=$(python3 --version 2>&1 | awk '{print $2}')
echo "✓ Python 版本: $python_version"

# 创建虚拟环境
if [ ! -d "venv" ]; then
    echo "📦 创建虚拟环境..."
    python3 -m venv venv
fi

# 激活虚拟环境
echo "🔧 激活虚拟环境..."
source venv/bin/activate

# 升级 pip
echo "⬆️  升级 pip..."
pip install --upgrade pip

# 安装依赖
echo "📥 安装依赖包..."
pip install -r requirements.txt

# 创建 .env 文件
if [ ! -f ".env" ]; then
    echo "📝 创建 .env 配置文件..."
    cp .env.example .env
    echo "⚠️  请编辑 .env 文件填入 API Key"
fi

# 创建临时目录
mkdir -p temp

echo "✅ 安装完成！"
echo ""
echo "下一步："
echo "1. 编辑 .env 文件填入 API Key（可选）"
echo "2. 运行: python main.py"
echo "3. 访问: http://localhost:8000"
