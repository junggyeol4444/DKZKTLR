const { defineConfig } = require('@playwright/test');
module.exports = defineConfig({
  testDir: './tests/e2e', timeout: 30000,
  use: { baseURL: 'http://127.0.0.1:4173', screenshot: 'only-on-failure' },
  reporter: [['list'], ['html', { outputFolder: 'playwright-report', open: 'never' }]],
  webServer: { command: 'python3 -m http.server 4173', port: 4173, reuseExistingServer: true }
});
