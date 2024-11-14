using Org.BouncyCastle.Asn1;
using Org.BouncyCastle.Asn1.Cms;
using Org.BouncyCastle.Cms;
using Org.BouncyCastle.Crypto;
using Org.BouncyCastle.Crypto.Operators;
using Org.BouncyCastle.Math;
using Org.BouncyCastle.OpenSsl;
using Org.BouncyCastle.Tsp;
using Org.BouncyCastle.X509;
using Org.BouncyCastle.X509.Store;
using System;
using System.IO;
using System.Linq;
using System.Text;
using Attribute = Org.BouncyCastle.Asn1.Cms.Attribute;

namespace LibTimeStamp
{
    public class TSResponder
    {        
        X509Certificate x509Cert;
        AsymmetricKeyParameter priKey;
        IX509Store x509Store;
        string hashAlg;
        public TSResponder(byte[] x509Cert, byte[] priKey, string hashAlg)
        {
            this.x509Cert = new X509CertificateParser().ReadCertificate(x509Cert);
            this.priKey = ((AsymmetricCipherKeyPair)(new PemReader(new StreamReader(new MemoryStream(priKey))).ReadObject())).Private;
            this.x509Store = X509StoreFactory.Create("Certificate/Collection",new X509CollectionStoreParameters(new X509CertificateParser().ReadCertificates(x509Cert)));
            this.hashAlg = hashAlg;
        }
        public byte[] GenResponse(byte[] bRequest, DateTime signTime, out bool isRFC, byte[] bSerial = null)
        {
            TimeStampRequest timeStampRequest = null;
            try { timeStampRequest = new TimeStampRequest(bRequest); int v = timeStampRequest.Version; } catch { timeStampRequest = null; }
            ;
            if (timeStampRequest == null)
            {
                isRFC = false;
                return Authenticode(bRequest, signTime);
            }
            else
            {
                isRFC = true;
                if (bSerial == null)
                {
                    bSerial = new byte[16];
                    new Random().NextBytes(bSerial);
                }
                BigInteger biSerial = new BigInteger(1, bSerial);
                return RFC3161(bRequest, signTime, biSerial);
            }
        }
        private byte[] RFC3161(byte[] bRequest,DateTime signTime,BigInteger biSerial)
        {
            TimeStampRequest timeStampRequest = new TimeStampRequest(bRequest);

            Asn1EncodableVector signedAttributes = new Asn1EncodableVector();
            signedAttributes.Add(new Attribute(CmsAttributes.ContentType, new DerSet(new DerObjectIdentifier("1.2.840.113549.1.7.1"))));
            signedAttributes.Add(new Attribute(CmsAttributes.SigningTime, new DerSet(new DerUtcTime(signTime))));
            AttributeTable signedAttributesTable = new AttributeTable(signedAttributes);
            signedAttributesTable.ToAsn1EncodableVector();

            TimeStampTokenGenerator timeStampTokenGenerator = new TimeStampTokenGenerator(priKey, x509Cert, new DefaultDigestAlgorithmIdentifierFinder().find(hashAlg).Algorithm.Id, "1.3.6.1.4.1.13762.3", signedAttributesTable, null);
            timeStampTokenGenerator.SetCertificates(x509Store);
            TimeStampResponseGenerator timeStampResponseGenerator = new TimeStampResponseGenerator(timeStampTokenGenerator, TspAlgorithms.Allowed);
            TimeStampResponse timeStampResponse = timeStampResponseGenerator.Generate(timeStampRequest, biSerial, signTime);
            byte[] result = timeStampResponse.GetEncoded();
            return result;
        }
        private byte[] Authenticode(byte[] bRequest, DateTime signTime)
        {
            string requestString = "";
            for (int i = 0; i < bRequest.Length; i++)
            {
                if (bRequest[i] >= 32)
                    requestString += (char)bRequest[i];
            }
            bRequest = Convert.FromBase64String(requestString);

            Asn1InputStream asn1InputStream = new Asn1InputStream(bRequest);
            Asn1Sequence instance = Asn1Sequence.GetInstance(asn1InputStream.ReadObject());
            Asn1Sequence instance2 = Asn1Sequence.GetInstance(instance[1]);
            Asn1TaggedObject instance3 = Asn1TaggedObject.GetInstance(instance2[1]);
            Asn1OctetString instance4 = Asn1OctetString.GetInstance(instance3.GetObject());
            byte[] octets = instance4.GetOctets();
            asn1InputStream.Close();

            Asn1EncodableVector signedAttributes = new Asn1EncodableVector();
            signedAttributes.Add(new Attribute(CmsAttributes.ContentType, new DerSet(new DerObjectIdentifier("1.2.840.113549.1.7.1"))));
            signedAttributes.Add(new Attribute(CmsAttributes.SigningTime, new DerSet(new DerUtcTime(signTime))));
            AttributeTable signedAttributesTable = new AttributeTable(signedAttributes);
            signedAttributesTable.ToAsn1EncodableVector();
            DefaultSignedAttributeTableGenerator signedAttributeGenerator = new DefaultSignedAttributeTableGenerator(signedAttributesTable);
            SignerInfoGeneratorBuilder signerInfoBuilder = new SignerInfoGeneratorBuilder();
            signerInfoBuilder.WithSignedAttributeGenerator(signedAttributeGenerator);
            ISignatureFactory signatureFactory = new Asn1SignatureFactory(hashAlg+"WithRSA", priKey);
            

            CmsSignedDataGenerator generator = new CmsSignedDataGenerator();
            generator.AddSignerInfoGenerator(signerInfoBuilder.Build(signatureFactory, x509Cert));
            generator.AddCertificates(x509Store);
            CmsSignedData cmsSignedData = generator.Generate(new CmsProcessableByteArray(octets), true);
            byte[] result = cmsSignedData.ContentInfo.GetEncoded("DER");
            return Encoding.ASCII.GetBytes(Convert.ToBase64String(result).ToArray());
        }
    }
}
