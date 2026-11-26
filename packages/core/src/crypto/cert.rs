use std::io::Cursor;
use std::net::IpAddr;
use x509_parser::asn1_rs::FromDer;
use x509_parser::certificate::X509Certificate;
use x509_parser::pem::Pem;
use x509_parser::x509::SubjectPublicKeyInfo;

/// A freshly generated device identity: an RSA-2048 key pair and a
/// self-signed certificate whose SHA-256 fingerprint identifies the device.
pub struct SelfSignedCert {
    /// The private key, PEM-encoded (PKCS#8).
    pub private_key_pem: String,
    /// The public key, PEM-encoded (SPKI).
    pub public_key_pem: String,
    /// The self-signed certificate, PEM-encoded.
    pub certificate_pem: String,
    /// The SHA-256 fingerprint of the certificate in DER format,
    /// encoded as uppercase hex (see [fingerprint_from_cert_der]).
    pub fingerprint: String,
}

/// Generates a new device identity, used for both the HTTP server and client
/// certificates.
///
/// - RSA-2048, matching the certificates the Flutter app has historically
///   generated in Dart.
/// - `CN=LocalSend User` and no SANs: peers identify each other purely by the
///   certificate fingerprint, so the name carries no information.
/// - The serial number is derived from the hash of the public key
///   (rcgen's default when no serial number is set).
/// - Validity is rcgen's default (1975 to 4096), so certificates do not expire
///   in practice and never need to be rotated for time reasons.
pub fn generate_self_signed() -> anyhow::Result<SelfSignedCert> {
    use rsa::pkcs8::{EncodePrivateKey, EncodePublicKey, LineEnding};

    let mut rng = rsa::rand_core::OsRng;
    let private_key = rsa::RsaPrivateKey::new(&mut rng, 2048)?;
    let private_key_pem = private_key.to_pkcs8_pem(LineEnding::LF)?;
    let public_key_pem = private_key
        .to_public_key()
        .to_public_key_pem(LineEnding::LF)?;

    let key_pair = rcgen::KeyPair::try_from(private_key.to_pkcs8_der()?.as_bytes())?;
    let mut params = rcgen::CertificateParams::default();
    params.not_before = rcgen::date_time_ymd(2026, 1, 1);
    params.not_after = rcgen::date_time_ymd(2027, 1, 1);
    params.distinguished_name = rcgen::DistinguishedName::new();
    params
        .distinguished_name
        .push(rcgen::DnType::CommonName, "LocalSend User");
    params.subject_alt_names = browser_subject_alt_names(&[]);
    let certificate = params.self_signed(&key_pair)?;

    Ok(SelfSignedCert {
        private_key_pem: private_key_pem.to_string(),
        public_key_pem,
        certificate_pem: certificate.pem(),
        fingerprint: fingerprint_from_cert_der(certificate.der()),
    })
}

/// The certificates used to serve the browser sharing pages over HTTPS.
///
/// The browser certificate is signed by the local CA, so users can remove the
/// browser security warning by trusting the CA once.
pub struct BrowserCertificates {
    /// The local CA certificate, PEM-encoded.
    pub ca_certificate_pem: String,
    /// The server certificate for browser sharing, PEM-encoded.
    pub server_certificate_pem: String,
}

/// Generates a stable local CA and a server certificate for browser sharing.
///
/// Both certificates reuse the device key pair, which keeps the LocalSend
/// certificate fingerprint stable: peers identify the device by its public
/// key, not by the serving certificate.
///
/// The caller provides the IP addresses the server may be reached on, because
/// the certificate needs a subject alternative name for every address the
/// browser uses to connect.
pub fn generate_browser_certificates(
    private_key_pem: &str,
    ip_addresses: &[IpAddr],
) -> anyhow::Result<BrowserCertificates> {
    let key_pair = rcgen::KeyPair::from_pem(private_key_pem)
        .map_err(|err| anyhow::anyhow!("Failed to parse device private key: {err}"))?;

    let public_key_der = key_pair.public_key_raw();
    let mut ca_params = local_ca_params();
    ca_params.serial_number = Some(stable_serial(&public_key_der, b"dropit-ca"));
    let ca_certificate = ca_params.self_signed(&key_pair)?;
    let issuer = rcgen::Issuer::from_params(&ca_params, &key_pair);

    let mut server_params = rcgen::CertificateParams::default();
    server_params.serial_number = Some(stable_serial(&public_key_der, b"dropit-browser"));
    // Modern browsers (Chromium/Brave/Safari) reject leaf certificates whose
    // validity exceeds 398 days (ERR_CERT_VALIDITY_TOO_LONG).
    server_params.not_before = rcgen::date_time_ymd(2026, 1, 1);
    server_params.not_after = rcgen::date_time_ymd(2027, 1, 1);
    server_params.distinguished_name = rcgen::DistinguishedName::new();
    server_params
        .distinguished_name
        .push(rcgen::DnType::CommonName, "Dropit Browser Sharing");
    server_params.is_ca = rcgen::IsCa::ExplicitNoCa;
    server_params.key_usages = vec![
        rcgen::KeyUsagePurpose::DigitalSignature,
        rcgen::KeyUsagePurpose::KeyEncipherment,
    ];
    server_params.extended_key_usages = vec![rcgen::ExtendedKeyUsagePurpose::ServerAuth];
    server_params.use_authority_key_identifier_extension = true;
    server_params.subject_alt_names = browser_subject_alt_names(ip_addresses);
    let server_certificate = server_params.signed_by(&key_pair, &issuer)?;

    Ok(BrowserCertificates {
        ca_certificate_pem: ca_certificate.pem(),
        server_certificate_pem: server_certificate.pem(),
    })
}

fn local_ca_params() -> rcgen::CertificateParams {
    let mut params = rcgen::CertificateParams::default();
    params.distinguished_name = rcgen::DistinguishedName::new();
    params
        .distinguished_name
        .push(rcgen::DnType::CommonName, "Dropit Local CA");
    params.is_ca = rcgen::IsCa::Ca(rcgen::BasicConstraints::Unconstrained);
    params.not_before = rcgen::date_time_ymd(1975, 1, 1);
    params.not_after = rcgen::date_time_ymd(2120, 1, 1);
    params.key_usages = vec![
        rcgen::KeyUsagePurpose::KeyCertSign,
        rcgen::KeyUsagePurpose::CrlSign,
        rcgen::KeyUsagePurpose::DigitalSignature,
    ];
    params
}

/// Derives a stable certificate serial from the device key and a label.
///
/// Relying on rcgen's defaults would make the CA certificate change when the
/// library's defaults change, forcing every user to trust it again.
fn stable_serial(public_key_der: &[u8], label: &[u8]) -> rcgen::SerialNumber {
    let mut input = public_key_der.to_vec();
    input.extend_from_slice(label);
    let hash = crate::crypto::hash::sha256(&input);
    rcgen::SerialNumber::from_slice(&hash[..16])
}

fn browser_subject_alt_names(ip_addresses: &[IpAddr]) -> Vec<rcgen::SanType> {
    let mut names = vec![
        rcgen::SanType::DnsName(
            "localhost"
                .try_into()
                .expect("localhost is a valid DNS name"),
        ),
        rcgen::SanType::IpAddress(std::net::Ipv4Addr::LOCALHOST.into()),
        rcgen::SanType::IpAddress(std::net::Ipv6Addr::LOCALHOST.into()),
    ];

    for ip in ip_addresses {
        if !ip.is_loopback()
            && !names
                .iter()
                .any(|name| matches!(name, rcgen::SanType::IpAddress(existing) if existing == ip))
        {
            names.push(rcgen::SanType::IpAddress(*ip));
        }
    }

    names
}

pub fn verify_cert_from_pem(cert: String, public_key: Option<&str>) -> anyhow::Result<()> {
    let (cert_pem, _) = Pem::read(Cursor::new(cert.into_bytes()))?;
    let parsed_cert: X509Certificate = cert_pem.parse_x509()?;

    verify_cert_from_cert(parsed_cert, public_key)
}

pub fn verify_cert_from_der(cert: &[u8], public_key: Option<&str>) -> anyhow::Result<()> {
    let (_, parsed_cert) = X509Certificate::from_der(&cert)?;

    verify_cert_from_cert(parsed_cert, public_key)
}

/// Verifies if the certificate is valid
/// - according to the signature
/// - according to the time validity
/// - according to the public key (if provided)
fn verify_cert_from_cert(cert: X509Certificate, public_key: Option<&str>) -> anyhow::Result<()> {
    if !cert.validity.is_valid() {
        return Err(anyhow::anyhow!("Time validity error"));
    }

    if let Some(public_key) = public_key {
        let cert_public_key = cert.tbs_certificate.subject_pki.parsed()?;

        let (public_key_pem, _) = Pem::read(Cursor::new(public_key.as_bytes()))?;
        let (_, public_key_spki) = SubjectPublicKeyInfo::from_der(&public_key_pem.contents)?;
        let expected_public_key = public_key_spki.parsed()?;

        if cert_public_key != expected_public_key {
            // We catch public key mismatch separately from signature verification
            // so that we can better unit test the function
            return Err(anyhow::anyhow!("Public key mismatch"));
        }
    }

    cert.verify_signature(None)?;

    Ok(())
}

/// Computes the SHA-256 fingerprint of a certificate in DER format.
/// Encoded as uppercase hex, the format used for LocalSend fingerprints.
pub fn fingerprint_from_cert_der(cert: &[u8]) -> String {
    crate::crypto::hash::sha256(cert)
        .iter()
        .map(|byte| format!("{byte:02X}"))
        .collect()
}

/// Extracts the public key from the certificate which is in DER format.
/// Encodes the public key in PEM format.
pub fn public_key_from_cert_der(cert: &[u8]) -> anyhow::Result<String> {
    let (_, parsed_cert) = X509Certificate::from_der(&cert)?;
    public_key_from_cert(parsed_cert)
}

/// Extracts the public key from the certificate.
/// Encodes the public key in PEM format.
pub fn public_key_from_cert(cert: X509Certificate) -> anyhow::Result<String> {
    let cert_public_key = cert.tbs_certificate.subject_pki.raw;
    let public_key = pem::encode(&pem::Pem::new("PUBLIC KEY", cert_public_key.to_vec()));
    Ok(public_key)
}

#[cfg(test)]
mod tests {
    use super::*;

    static PUBLIC_KEY: &str = "-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAi9uDMYRn63SZtEPGRogZ
Gdu5XXBAoQeMO60mycoinqLKDWyZdpMo+XWY3wYVhoAyxgzDOcPjIf+Uq1oEy/0K
4WwfpbK8SCy851qgYkfMCT9D9mFvXwWoULJCUHFF7f947ArDE1nmuK1nNx2RodN2
wJCXyzPjw0jn06bwGeg0EqfUC8wvW4FTZ6t1tErzmRqRdMUWuCJwsk1IMbDbFePh
iK5jecOBG0RVVWLuw+TkuX8TUgrpIktH2+qEM1KdLyAMnL71hx2wMvE+lDKFKK9p
37zXK8omjl+VgTC8ocjGeYDDsl43ZtW09V0pb7Vz2FM8b7BgM06kvJl48PIe5puY
bQIDAQAB
-----END PUBLIC KEY-----";

    static CERT: &str = "-----BEGIN CERTIFICATE-----
MIIDGTCCAgGgAwIBAgIBATANBgkqhkiG9w0BAQsFADBQMRcwFQYDVQQDEw5Mb2Nh
bFNlbmQgVXNlcjEJMAcGA1UEChMAMQkwBwYDVQQLEwAxCTAHBgNVBAcTADEJMAcG
A1UECBMAMQkwBwYDVQQGEwAwHhcNMjUwMjA5MDAwMzE0WhcNMzUwMjA3MDAwMzE0
WjBQMRcwFQYDVQQDEw5Mb2NhbFNlbmQgVXNlcjEJMAcGA1UEChMAMQkwBwYDVQQL
EwAxCTAHBgNVBAcTADEJMAcGA1UECBMAMQkwBwYDVQQGEwAwggEiMA0GCSqGSIb3
DQEBAQUAA4IBDwAwggEKAoIBAQCL24MxhGfrdJm0Q8ZGiBkZ27ldcEChB4w7rSbJ
yiKeosoNbJl2kyj5dZjfBhWGgDLGDMM5w+Mh/5SrWgTL/QrhbB+lsrxILLznWqBi
R8wJP0P2YW9fBahQskJQcUXt/3jsCsMTWea4rWc3HZGh03bAkJfLM+PDSOfTpvAZ
6DQSp9QLzC9bgVNnq3W0SvOZGpF0xRa4InCyTUgxsNsV4+GIrmN5w4EbRFVVYu7D
5OS5fxNSCukiS0fb6oQzUp0vIAycvvWHHbAy8T6UMoUor2nfvNcryiaOX5WBMLyh
yMZ5gMOyXjdm1bT1XSlvtXPYUzxvsGAzTqS8mXjw8h7mm5htAgMBAAEwDQYJKoZI
hvcNAQELBQADggEBABZ+I7D6wkeSrsi1NBLP2zoZ5oGh+INNcGTravfOQHs4Fbas
/CysaUYjsD3fmaDh4MxgWEqAmWnnBiojfpGX2SGuFqRBKyT9DgitBt0L7Ezg1k3h
bfSiFW4hXWp75grVO8xfML7ZcWMlhKrOsOMUGiy1qs3qsyJ3w7B2Tz78HhXGO5dd
jyPmZarhixKO92UpEvKGxjO0E/3UUNUzxKTAAgFfhKpuwHUgIijM/EppZtA8OcSh
fEztiV0xKfcPVx4d6dqRt/NMElK1Ivw2vUuxTymphZkkFOzht9m73/kyKaeFp8Ij
VRus1zGVD8IVpIdPMyz01WJyS7M0fWaHXKWo+Bo=
-----END CERTIFICATE-----";

    #[test]
    fn test_verify_cert() {
        assert_eq!(
            verify_cert_from_pem(CERT.to_string(), Some(PUBLIC_KEY)).map_err(|e| e.to_string()),
            Ok(())
        );

        let cert_invalid_signature = "-----BEGIN CERTIFICATE-----
MIIDGTCCAgGgAwIBAgIBATANBgkqhkiG9w0BAQsFADBQMRcwFQYDVQQDEw5Mb2Nh
bFNlbmQgVXNlcjEJMAcGA1UEChMAMQkwBwYDVQQLEwAxCTAHBgNVBAcTADEJMAcG
A1UECBMAMQkwBwYDVQQGEwAwHhcNMjUwMjA5MDAwMzE0WhcNMzUwMjA3MDAwMzE0
WjBQMRcwFQYDVQQDEw5Mb2NhbFNlbmQgVXNlcjEJMAcGA1UEChMAMQkwBwYDVQQL
EwAxCTAHBgNVBAcTADEJMAcGA1UECBMAMQkwBwYDVQQGEwAwggEiMA0GCSqGSIb3
DQEBAQUAA4IBDwAwggEKAoIBAQCL24MxhGfrdJm0Q8ZGiBkZ27ldcEChB4w7rSbJ
yiKeosoNbJl2kyj5dZjfBhWGgDLGDMM5w+Mh/5SrWgTL/QrhbB+lsrxILLznWqBi
R8wJP0P2YW9fBahQskJQcUXt/3jsCsMTWea4rWc3HZGh03bAkJfLM+PDSOfTpvAZ
6DQSp9QLzC9bgVNnq3W0SvOZGpF0xRa4InCyTUgxsNsV4+GIrmN5w4EbRFVVYu7D
5OS5fxNSCukiS0fb6oQzUp0vIAycvvWHHbAy8T6UMoUor2nfvNcryiaOX5WBMLyh
yMZ5gMOyXjdm1bT1XSlvtXPYUzxvsGAzTqS8mXjw8h7mm5htAgMBAAEwDQYJKoZI
hvcNAQELBQADggEBABZ+I7D6wkeSrsi1NBLP2zoZ5oGh+INNcGTravfOQHs4Fbas
/CysaUYjsD3fmaDh4MxgWEqAmWnnBiojfpGX2SGuFqRBKyT9DgitBt0L7Ezg1k3h
bfSiFW4hXWp75grVO8xfML7ZcWMlhKrOsOMUGiy1qs3qsyJ3w7B2Tz78HhXGO5dd
jyPmZarhixKO92UpEvKGxjO0E/3UUNUzxKTAAgFfhKpuwHUgIijM/EppZtA8OcSh
fEztiV0xKfcPVx4d6dqRt/NMElK1Ivw2vUuxTymphZkkFOzht9m73/kyKaeFp8Ij
VRus1zGVD8IVpIdPMyz01WJySwAAAAAAAAAAAAA=
-----END CERTIFICATE-----"
            .to_string();
        assert_eq!(
            verify_cert_from_pem(cert_invalid_signature, Some(PUBLIC_KEY))
                .map_err(|e| e.to_string()),
            Err("signature verification error".to_string())
        );

        let cert_invalid_public_key = "-----BEGIN CERTIFICATE-----
MIIDGTCCAgGgAwIBAgIBATANBgkqhkiG9w0BAQsFADBQMRcwFQYDVQQDEw5Mb2Nh
bFNlbmQgVXNlcjEJMAcGA1UEChMAMQkwBwYDVQQLEwAxCTAHBgNVBAcTADEJMAcG
A1UECBMAMQkwBwYDVQQGEwAwHhcNMjUwMjA5MDI1ODQxWhcNMzUwMjA3MDI1ODQx
WjBQMRcwFQYDVQQDEw5Mb2NhbFNlbmQgVXNlcjEJMAcGA1UEChMAMQkwBwYDVQQL
EwAxCTAHBgNVBAcTADEJMAcGA1UECBMAMQkwBwYDVQQGEwAwggEiMA0GCSqGSIb3
DQEBAQUAA4IBDwAwggEKAoIBAQCnrVjQQ0mAfBaucJd5rbZX9usLROwHDuXdczFq
XJhb8pPjEF18FoDHzobjz5JWq+GDkBmcg0k6+AeETGQEaJisZDBWH7NOjJahGGnQ
0okw1iVUoEpQ26ZSFkr3H5NNtGAa6EkS4xb0bsEDb3vs69zRvFyrVd6OEqmdsRy3
aU2AvAMoLthgY8bUZ/XyWpbA8euV3VjkRSHsju+DOQH4oj46ZITJ3M2/x5o/3jqJ
ILBhoLcu7UJJTHYqeBsPSTkMIGKLkYSUPOd/mSgwQB854wks4nf+hO4VWvKQFx9X
4gIjS7vJ6e9rQOn2NFfluPbRiijmWIiwUDUWz3UW2RS0b6gDAgMBAAEwDQYJKoZI
hvcNAQELBQADggEBAAO3rG2YcQqH8Z7jDX82q0nn/bglOWvTySv4EP3FNrVPZKfN
aR+oLo8WdAWulbxXDIOK7XLk1V9SxEJvVxOTp2EIgcoWqJANoWjp+5nNInE02eNX
G8euvPvh+p/1cTbHxhrZqtsSpkAx1AbbbcvT+5hUUDXSU7cMN+vFjUqkEVrBlj7S
vFbLDHP82ywisZrkOfNapxV67U4ENaEwJ4P4OERnqOOieJr0elv598cSDu+OSKmt
rFNYYHERELX36g4+KcWGN223Pg4Xl0bFYqV0xwRUThh0657t8cioXaOsjjpKnGAm
eVVihnrJ3sdk7nnreAYMse/OipyufRyZ9t3WU8A=
-----END CERTIFICATE-----"
            .to_string();
        assert_eq!(
            verify_cert_from_pem(cert_invalid_public_key, Some(PUBLIC_KEY))
                .map_err(|e| e.to_string()),
            Err("Public key mismatch".to_string())
        );

        let cert_expired = "-----BEGIN CERTIFICATE-----
MIIDGTCCAgGgAwIBAgIBATANBgkqhkiG9w0BAQsFADBQMRcwFQYDVQQDEw5Mb2Nh
bFNlbmQgVXNlcjEJMAcGA1UEChMAMQkwBwYDVQQLEwAxCTAHBgNVBAcTADEJMAcG
A1UECBMAMQkwBwYDVQQGEwAwHhcNMjUwMjA5MjEwOTQ0WhcNMjUwMjA5MjEwOTQ0
WjBQMRcwFQYDVQQDEw5Mb2NhbFNlbmQgVXNlcjEJMAcGA1UEChMAMQkwBwYDVQQL
EwAxCTAHBgNVBAcTADEJMAcGA1UECBMAMQkwBwYDVQQGEwAwggEiMA0GCSqGSIb3
DQEBAQUAA4IBDwAwggEKAoIBAQCL24MxhGfrdJm0Q8ZGiBkZ27ldcEChB4w7rSbJ
yiKeosoNbJl2kyj5dZjfBhWGgDLGDMM5w+Mh/5SrWgTL/QrhbB+lsrxILLznWqBi
R8wJP0P2YW9fBahQskJQcUXt/3jsCsMTWea4rWc3HZGh03bAkJfLM+PDSOfTpvAZ
6DQSp9QLzC9bgVNnq3W0SvOZGpF0xRa4InCyTUgxsNsV4+GIrmN5w4EbRFVVYu7D
5OS5fxNSCukiS0fb6oQzUp0vIAycvvWHHbAy8T6UMoUor2nfvNcryiaOX5WBMLyh
yMZ5gMOyXjdm1bT1XSlvtXPYUzxvsGAzTqS8mXjw8h7mm5htAgMBAAEwDQYJKoZI
hvcNAQELBQADggEBAH2/F6iEH8W5gIHcKJ6/EbrG2BY5Uhg5U8X6yPk6z9ctmY6w
n7fDT749PMVDJq+qhIcnoBlUgVJdJ2qFa5h3VaSF+tUFu/CImr+S8TYHCdQGYXA5
6b/pnHmbrWqZdNdxs6Y80A9Mu+iNeLDcrTo60/zGfJsiD9Cnlj0Q6c8nn+Obzeqq
iIwUmPFw0krH+ku/DlSenKnyL8jaktf48neufu0jObUvCuj62I2WlFZwzXd8CnDR
X2/mKq6FWHCDR6RTh1yMLfD+NoVNcswxwMFq8ILCfBuTjNVaSFm3eUqKeEOAaDes
nidU/qXQvBJ7NPUkXXgbcgqxK735iijOqQHmKts=
-----END CERTIFICATE-----"
            .to_string();
        assert_eq!(
            verify_cert_from_pem(cert_expired, Some(PUBLIC_KEY)).map_err(|e| e.to_string()),
            Err("Time validity error".to_string())
        );
    }

    #[test]
    fn test_generate_self_signed() {
        let generated = generate_self_signed().unwrap();

        assert!(generated
            .private_key_pem
            .starts_with("-----BEGIN PRIVATE KEY-----"));
        assert!(generated
            .public_key_pem
            .starts_with("-----BEGIN PUBLIC KEY-----"));

        // The certificate is self-consistent and carries the generated public key.
        verify_cert_from_pem(
            generated.certificate_pem.clone(),
            Some(&generated.public_key_pem),
        )
        .unwrap();

        // The fingerprint matches the DER bytes of the certificate.
        let (cert_pem, _) =
            Pem::read(Cursor::new(generated.certificate_pem.as_bytes().to_vec())).unwrap();
        assert_eq!(
            generated.fingerprint,
            fingerprint_from_cert_der(&cert_pem.contents)
        );

        // The public key extracted from the certificate is the generated one.
        let extracted = public_key_from_cert_der(&cert_pem.contents).unwrap();
        assert_eq!(
            extracted.replace("\r\n", "\n").trim(),
            generated.public_key_pem.trim()
        );
    }

    #[test]
    fn test_generate_browser_certificates() {
        let generated = generate_self_signed().unwrap();
        let ips = vec!["192.168.1.20".parse().unwrap(), "fe80::1".parse().unwrap()];
        let certificates = generate_browser_certificates(&generated.private_key_pem, &ips).unwrap();

        // The browser certificate keeps the device public key, so LocalSend
        // peers still recognize the device.
        verify_cert_from_pem(
            certificates.server_certificate_pem.clone(),
            Some(&generated.public_key_pem),
        )
        .unwrap();

        // The CA is self-signed and the browser certificate is signed by it.
        let (ca_pem, _) = Pem::read(Cursor::new(
            certificates.ca_certificate_pem.as_bytes().to_vec(),
        ))
        .unwrap();
        let (server_pem, _) = Pem::read(Cursor::new(
            certificates.server_certificate_pem.as_bytes().to_vec(),
        ))
        .unwrap();
        let (_, ca) = X509Certificate::from_der(ca_pem.contents.as_slice()).unwrap();
        let (_, server) = X509Certificate::from_der(server_pem.contents.as_slice()).unwrap();
        ca.verify_signature(None).unwrap();
        server.verify_signature(Some(ca.public_key())).unwrap();

        use x509_parser::extensions::GeneralName;
        let san = server.subject_alternative_name().unwrap().unwrap();
        let names = &san.value.general_names;
        assert!(names.iter().any(|name| matches!(
            name,
            GeneralName::IPAddress(bytes) if *bytes == [192, 168, 1, 20]
        )));
        assert!(names.iter().any(|name| matches!(
            name,
            GeneralName::IPAddress(bytes) if bytes.len() == 16
                && bytes[..2] == [0xfe, 0x80]
        )));
        assert!(names
            .iter()
            .any(|name| matches!(name, GeneralName::DNSName("localhost"))));

        // The certificates are stable for the same key and addresses.
        let again = generate_browser_certificates(&generated.private_key_pem, &ips).unwrap();
        assert_eq!(certificates.ca_certificate_pem, again.ca_certificate_pem);
        assert_eq!(
            certificates.server_certificate_pem,
            again.server_certificate_pem
        );
    }

    #[test]
    fn test_fingerprint_from_cert_der() {
        let (cert_pem, _) = Pem::read(Cursor::new(CERT.as_bytes().to_vec())).unwrap();
        assert_eq!(
            fingerprint_from_cert_der(&cert_pem.contents),
            // Must match the Dart side: uppercase hex SHA-256 of the DER bytes.
            "4BADDE53A7F7CDEEED93189FD898E02BF6B4806CA4C05DE0ACE08319B86552FA"
        );
    }
}
