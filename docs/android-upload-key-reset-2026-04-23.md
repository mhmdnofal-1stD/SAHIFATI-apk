## Upload Key Reset Materials

- App: `org.sahifati.app`
- Reason: the previous upload key is missing and the currently accepted Play upload certificate fingerprint does not match the local keystore.
- Play requires the public certificate for the new upload key in PEM format. A CSR is not required for the Play upload-key reset flow.

## Generated Files

- Current local keystore path: `C:\1stD\Public-data\UP.Key.jks`
- Public certificate for Play reset request: `android/upload_certificate_reset_2026.pem`
- Active signing properties: `android/key.properties`

## New Upload Key Identity

- Alias: `sahifati_upload_reset_2026`
- Owner: `CN=Sahifati Upload Reset 2026, OU=1stD, O=1stD, L=Amman, ST=Jordan, C=JO`
- SHA1: `2F:72:18:9F:7E:ED:8E:54:90:F1:07:43:E1:9F:9B:C9:91:62:50:BE`
- SHA256: `41:B1:69:3A:F3:95:29:CC:4B:0D:A2:03:A6:EB:7E:E8:73:DB:8B:1B:4E:5F:7F:47:31:3C:06:54:91:DE:FC:52`

## Play Console Steps

1. Open Play Console for the Sahifati app.
2. Go to `Release > Setup > App signing`.
3. Open the upload key reset flow for a lost or compromised upload key.
4. Upload `android/upload_certificate_reset_2026.pem` when Play asks for the new upload certificate.
5. Submit the request and wait for Google to confirm the upload-key reset.
6. After approval, upload a new build signed with `android/sahifati_upload_reset_2026.jks`.

## Local Verification Commands

Export PEM again if needed:

```powershell
keytool -export -rfc -keystore C:\1stD\Public-data\UP.Key.jks -storepass "Mn.123123" -alias sahifati_upload_reset_2026 -file android/upload_certificate_reset_2026.pem
```

Check the new key fingerprint:

```powershell
keytool -list -v -keystore C:\1stD\Public-data\UP.Key.jks -storepass "Mn.123123" -alias sahifati_upload_reset_2026
```

Build a release bundle after Play approves the reset:

```powershell
flutter build appbundle --release
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```

## Important Note

- Builds signed with this upload key will still be rejected by Play until the reset request is approved on Google's side.
- The local workspace now resolves signing from `android/key.properties`, which points to `C:\1stD\Public-data\UP.Key.jks` outside the repo tree.