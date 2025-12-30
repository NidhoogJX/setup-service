#!/bin/bash
# 检查服务运行状态 sudo systemctl status grpc-sync
# 查看实时日志​ sudo journalctl -u grpc-sync -f
# 查看历史日志​ sudo journalctl -u grpc-sync
# 停止服务​ sudo systemctl stop grpc-sync
# 启动服务​ sudo systemctl start grpc-sync
# 重启服务​ sudo systemctl restart grpc-sync
# 重新加载配置​ sudo systemctl daemon-reload
# 禁用开机自启​ sudo systemctl disable grpc-sync
# 启用开机自启​ sudo systemctl enable grpc-sync

DEFAULT_SERVICE_NAME="grpc-sync"
DEFAULT_BINARY_PATH="/home/grpc/grpc-sync"
DEFAULT_WORKING_DIRECTORY="/home/grpc"

print_help() {
    echo "用法: sudo bash $0 [参数]"
    echo "参数说明:"
    echo "  start      启动服务"
    echo "  stop       停止服务"
    echo "  restart    重启服务"
    echo "  status     查看服务状态"
    echo "  enable     设置服务开机自启"
    echo "  disable    关闭服务开机自启"
    echo "  log        查看历史日志 (journalctl -u 服务名)"
    echo "  logf       查看实时日志 (journalctl -u 服务名 -f)"
    echo "  help/-h    打印本帮助信息"
    echo "无参数时，默认启动并设置开机自启"
}

# 只读参数提前处理，不做任何写操作和输入
case "$1" in
    log)
        read -p "请输入服务名 [$DEFAULT_SERVICE_NAME]: " SERVICE_NAME
        SERVICE_NAME=${SERVICE_NAME:-$DEFAULT_SERVICE_NAME}
        journalctl -u $SERVICE_NAME
        exit 0
        ;;
    logf)
        read -p "请输入服务名 [$DEFAULT_SERVICE_NAME]: " SERVICE_NAME
        SERVICE_NAME=${SERVICE_NAME:-$DEFAULT_SERVICE_NAME}
        journalctl -u $SERVICE_NAME -f
        exit 0
        ;;
    help|-h|--help)
        print_help
        exit 0
        ;;
esac

# 需要写操作的命令才提示输入参数
read -p "请输入服务名 [$DEFAULT_SERVICE_NAME]: " SERVICE_NAME
SERVICE_NAME=${SERVICE_NAME:-$DEFAULT_SERVICE_NAME}

read -p "请输入启动文件绝对路径 [$DEFAULT_BINARY_PATH]: " BINARY_PATH
BINARY_PATH=${BINARY_PATH:-$DEFAULT_BINARY_PATH}

read -p "请输入工作目录 [$DEFAULT_WORKING_DIRECTORY]: " WORKING_DIRECTORY
WORKING_DIRECTORY=${WORKING_DIRECTORY:-$DEFAULT_WORKING_DIRECTORY}

SERVICE_USER="$USER" # 运行服务的用户
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"


print_help() {
    echo "用法: sudo bash $0 [参数]"
    echo "参数说明:"
    echo "  start      启动服务"
    echo "  stop       停止服务"
    echo "  restart    重启服务"
    echo "  status     查看服务状态"
    echo "  enable     设置服务开机自启"
    echo "  disable    关闭服务开机自启"
    echo "  log        查看历史日志 (journalctl -u $SERVICE_NAME)"
    echo "  logf       查看实时日志 (journalctl -u $SERVICE_NAME -f)"
    echo "  help/-h    打印本帮助信息"
    echo "无参数时，默认启动并设置开机自启"
}

# 只读参数提前处理，不做任何写操作
case "$1" in
    log)
        journalctl -u $SERVICE_NAME
        exit 0
        ;;
    logf)
        journalctl -u $SERVICE_NAME -f
        exit 0
        ;;
    help|-h|--help)
        print_help
        exit 0
        ;;
esac

# 下面是需要写操作的分支，先做权限和文件检查
# 检查是否为 root 用户
if [[ $EUID -ne 0 ]]; then
   echo "此脚本需要以 root 权限运行。请使用 sudo。" 
   exit 1
fi

# 检查二进制文件是否存在
if [ ! -f "$BINARY_PATH" ]; then
    echo "错误：二进制文件不存在于 $BINARY_PATH"
    exit 1
fi

# 赋予二进制文件执行权限（可选但推荐）
chmod +x "$BINARY_PATH"

# 检查是否已存在同名服务文件
if [ -f "$SERVICE_FILE" ]; then
    echo "警告：服务文件 $SERVICE_FILE 已存在。"
    read -p "是否覆盖？(y/n): " yn
    case $yn in
        [Yy]*)
            echo "将覆盖原有服务文件..."
            ;;
        *)
            echo "已取消操作。"
            exit 1
            ;;
    esac
fi

# 写入服务文件
cat > $SERVICE_FILE <<EOF
[Unit]
Description=Automated Service for $SERVICE_NAME
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$WORKING_DIRECTORY
ExecStart=$BINARY_PATH
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
echo "服务文件已写入 $SERVICE_FILE"

# 重新加载 systemd 配置
systemctl daemon-reload
echo "Systemd 配置已重载。"

# 根据传入参数操作服务
case "$1" in
    start)
        systemctl start $SERVICE_NAME
        ;;
    stop)
        systemctl stop $SERVICE_NAME
        ;;
    status)
        systemctl status $SERVICE_NAME
        ;;
    enable)
        systemctl enable $SERVICE_NAME
        ;;
    disable)
        systemctl disable $SERVICE_NAME
        ;;
    restart)
        systemctl restart $SERVICE_NAME
        ;;
    "")
        # 如果没有参数，默认启动并启用开机自启
        systemctl enable $SERVICE_NAME
        systemctl start $SERVICE_NAME
        ;;
    *)
        echo "未知参数: $1"
        print_help
        exit 1
        ;;
esac

# 检查服务是否已启动
is_active=$(systemctl is-active $SERVICE_NAME)
if [ "$is_active" = "active" ]; then
    echo "服务 $SERVICE_NAME 已启动。"
else
    echo "服务 $SERVICE_NAME 未启动。可用: systemctl start $SERVICE_NAME 启动。"
fi

# 检查服务状态
echo "检查服务状态："
systemctl status $SERVICE_NAME --no-pager -l