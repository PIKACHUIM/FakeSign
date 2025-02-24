from flask import Flask, request, jsonify
import time
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.backends import default_backend

app = Flask(__name__)
VALID_AUTH_CODE = "SECRET123"  # 预设的认证码

# 加载私钥
with open("TSA.key", "rb") as f:
    private_key = serialization.load_pem_private_key(
        f.read(), password=None, backend=default_backend())


@app.route('/timestamp', methods=['POST'])
def timestamp():
    # 验证AuthCode
    auth_code = request.headers.get('X-Auth-Code')
    if auth_code != VALID_AUTH_CODE:
        return jsonify({"error": "Unauthorized"}), 401

    # 获取数据哈希
    data = request.get_json()
    data_hash = data.get('hash')
    if not data_hash:
        return jsonify({"error": "Missing hash"}), 400

    # 生成时间戳和签名
    timestamp = int(time.time())
    message = f"{timestamp}:{data_hash}".encode()
    signature = private_key.sign(message, padding.PKCS1v15(), hashes.SHA256())

    return jsonify({
        "timestamp": timestamp,
        "signature": signature.hex()  # 十六进制便于传输
    })


if __name__ == '__main__':
    app.run(port=5000,debug=True)  # 启用HTTPS