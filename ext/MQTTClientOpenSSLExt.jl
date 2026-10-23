module MQTTClientOpenSSLExt

using MQTTClient: MQTTClient, TLS
using OpenSSL: OpenSSL
using Sockets: Sockets

function MQTTClient.tls_connect(protocol::TLS)
    ctx = if isempty(protocol.ca_file)
        OpenSSL.SSLContext(OpenSSL.TLSClientMethod())
    else
        OpenSSL.SSLContext(OpenSSL.TLSClientMethod(), protocol.ca_file)
    end
    if !isempty(protocol.cert_file)
        OpenSSL.ssl_use_certificate(ctx, OpenSSL.X509Certificate(read(protocol.cert_file, String)))
        OpenSSL.ssl_use_private_key(ctx, OpenSSL.EvpPKey(read(protocol.key_file, String)))
    end
    ssl = OpenSSL.SSLStream(ctx, Sockets.connect(protocol.host, protocol.port))
    try
        OpenSSL.hostname!(ssl, protocol.host)
        Sockets.connect(ssl; require_ssl_verification=protocol.verify)
    catch
        close(ssl)
        rethrow()
    end
    return ssl
end

end
