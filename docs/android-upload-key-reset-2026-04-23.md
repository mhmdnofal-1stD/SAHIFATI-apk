## Upload Key Reset Materials

- App: `org.sahifati.app`
- Reason: the previous upload key is missing and the currently accepted Play upload certificate fingerprint does not match the local keystore.
- Play requires the public certificate for the new upload key in PEM format. A CSR is not required for the Play upload-key reset flow.

## Generated Files

- Current local keystore path: `C:\1stD\Public-data\UP.Key.jks`
- Public certificate for Play reset request: `android/upload_certificate_reset_2026.pem`
- Active signing properties: `android/key.properties`

## New Upload Key Identity

- Alias: `upload`
- Owner: `CN=Abdel-elah Shorbaji, OU=Sahifaty, O=Sahifaty, L=Amman, ST=Amman, C=jo`
- Created: `Feb 8, 2026` (valid until `Jun 26, 2053`)
- SHA1: `6F:DA:D4:C7:24:28:5A:F5:E3:A7:94:8B:00:4C:E3:81:D6:87:71:50`
- SHA256: `BD:35:02:FB:5A:EB:AD:AA:E5:E3:DB:8C:98:BF:27:BB:59:7D:5B:E5:05:29:38:9D:EE:47:0A:9C:5B:0F:E5:03`

> The store/key password and alias used to be `Mn.123123` / `sahifati_upload_reset_2026` in earlier drafts of this doc. The actual keystore at `C:\1stD\Public-data\UP.Key.jks` uses alias `upload` and password `P@ssw0rd`; verified 2026-04-30 by signing a successful release APK.

## Play Console Steps

1. Open Play Console for the Sahifati app.
2. Go to `Release > Setup > App signing`.
3. Open the upload key reset flow for a lost or compromised upload key.
4. Upload `android/upload_certificate_reset_2026.pem` when Play asks for the new upload certificate.
5. Submit the request and wait for Google to confirm the upload-key reset.
6. After approval, upload a new build signed with `C:\1stD\Public-data\UP.Key.jks` (alias `upload`).

## Local Verification Commands

Export PEM again if needed:

```powershell
keytool -export -rfc -keystore C:\1stD\Public-data\UP.Key.jks -storepass "P@ssw0rd" -alias upload -file android/upload_certificate_reset_2026.pem
```

Check the new key fingerprint:

```powershell
keytool -list -v -keystore C:\1stD\Public-data\UP.Key.jks -storepass "P@ssw0rd" -alias upload
```

Build a release bundle after Play approves the reset:

```powershell
flutter build appbundle --release
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```

## Important Note

- Builds signed with this upload key will still be rejected by Play until the reset request is approved on Google's side.
- The local workspace now resolves signing from `android/key.properties`, which points to `C:\1stD\Public-data\UP.Key.jks` outside the repo tree.