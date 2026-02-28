# audit_pro_mobile

Audit Pro Mobile (APM) Flutter app.

Developer docs:
- [GTApp integration docs](docs/gtapp/README.md)

## Run on Android emulator (debug)

This app uses `String.fromEnvironment('APM_API_BASE_URL')` to decide which API to call.

The Heat Network Assessment (HNA) feature uses a separate portal base URL:
- Flutter env define: `PORTAL_BASE_URL`
- Default: `https://buildingservices-portal.co.uk/`

Pre-auth mobile auth endpoints (`/api/mobile/auth/request-otp`, `verify-otp`, `tenant-options`) require an API key header:
- Flutter env define: `APM_MOBILE_AUTH_API_KEY`
- Header sent: `X-API-KEY`
- Portal container must set the same env var: `APM_MOBILE_AUTH_API_KEY`

1. Start an emulator (example):
	- `flutter emulators --launch Pixel_7`

2. Run with the admin portal URL:
	- `flutter run -d emulator-5554 --dart-define-from-file=auditpromobile.defines.json`

If you want to point at a local portal API instead, create another env file with:
`APM_API_BASE_URL=http://10.0.2.2:5168`

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
