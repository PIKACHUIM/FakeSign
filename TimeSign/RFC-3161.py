from flask import Flask, request, Response
from datetime import timezone
from asn1crypto import tsp, cms, core, algos
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography import x509  # 需要导入x509模块
import datetime
from asn1crypto.core import OctetString
app = Flask(__name__)

# 加载私钥和证书（示例需替换为实际文件）
with open("0.2-Pikachu_Time_Sub_CA.key", "rb") as f:
    private_key = serialization.load_pem_private_key(f.read(), None)
with open("0.2-Pikachu_Time_Sub_CA.crt", "rb") as f:
    cert = x509.load_pem_x509_certificate(f.read())


def generate_ts_response(tsq):
    # 构造TSTInfo
    tst_info = tsp.TSTInfo({
        'version': 1,
        'policy': '1.3.6.1.4.1.13762.3',  # 示例策略OID
        'message_imprint': tsq['message_imprint'],
        'serial_number': 1,
        'gen_time': datetime.datetime.now(timezone.utc),
        'ordering': False
    })
    tst_info_data = tst_info.dump()

    # 签名
    signature = private_key.sign(tst_info_data, padding.PKCS1v15(), hashes.SHA256())

    # 构建CMS SignedData
    signed_data = cms.SignedData({
        'version': 3,
        'digest_algorithms': [algos.DigestAlgorithm({'algorithm': 'sha256'})],
        'encap_content_info': cms.EncapsulatedContentInfo({
            'content_type': 'tst_info',  # 或明确使用OID: '1.2.840.113549.1.9.16.1.4'
            'content': tst_info  # 包装为ASN.1 OctetString
        }),
        'certificates': [cert],
        'signer_infos': [{
            'version': 1,
            'sid': {
                'issuer_and_serial_number': cms.IssuerAndSerialNumber({
                    'issuer': cert.issuer,  # 从证书中提取颁发者
                    'serial_number': cert.serial_number  # 从证书中提取序列号
                })
            },
            'digest_algorithm': algos.DigestAlgorithm({'algorithm': 'sha256'}),
            'signature_algorithm': algos.SignedDigestAlgorithm({
                'algorithm': 'rsassa_pkcs1v15',
                'parameters': algos.Null()
            }),
            'signature': signature
        }]
    })

    # 构建时间戳响应
    tsr = tsp.TimeStampResp({
        'status': {'status': 'granted'},
        'time_stamp_token': {'content_type': 'signed_data', 'content': signed_data}
    })
    return tsr.dump()


@app.route('/rfc3161', methods=['POST'])
def handle_rfc3161():
    tsq = tsp.TimeStampReq.load(request.data)
    tsr_data = generate_ts_response(tsq)
    return Response(tsr_data, mimetype='application/timestamp-reply')

if __name__ == '__main__':
    app.run(port=5000)