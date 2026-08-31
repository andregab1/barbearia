# GetCutt catalog E2E

These tests exercise the real Flutter UI. Start the isolated QA API first and pass its URL explicitly:

```powershell
flutter test integration_test/catalog_e2e_test.dart -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api
```

On Flutter versions that require WebDriver, set `CHROMEDRIVER_PATH` and run `npm run test:flutter:e2e`; the orchestrator starts ChromeDriver on port 4444, provisions the disposable database/API, executes `flutter drive`, and cleans up.

Never point this suite at production. Screenshots are evidence, not a replacement for API and database assertions. Tests that mutate data must use fixtures prefixed by the catalog case ID and verify cleanup.
