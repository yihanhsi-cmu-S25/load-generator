# 使用輕量級的 Python 基礎鏡像
FROM python:3.9-slim-buster

# 設定工作目錄
WORKDIR /app

# 將當前目錄下的所有文件複製到鏡像的 /app 目錄中
COPY . /app

# 安裝任何必要的 Python 依賴 (本例中沒有額外的依賴)
# RUN pip install requests # 如果你的腳本需要其他庫，在這裡添加

# 暴露服務端口
EXPOSE 8000

# 定義容器啟動時執行的命令
# CMD ["python", "load_simulator.py"]
# 允許透過環境變數設定端口和綁定地址
CMD ["python", "load_simulator.py", "--port", "8000", "--bind", "0.0.0.0"]