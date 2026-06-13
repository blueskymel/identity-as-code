import { expect, test } from '@playwright/test';
import path from 'node:path';
import { readFileSync } from 'node:fs';

type SsoApplication = {
  displayName: string;
  protocol: string;
  servicePrincipalAppId: string;
  oidcDiscoveryUrl?: string;
};

type SsoPlan = {
  applications: SsoApplication[];
};

const tenantId = process.env.IDENTITY_TENANT_ID ?? 'common';
const planPath = process.env.IDENTITY_SSO_PLAN_FILE
  ? path.resolve(process.env.IDENTITY_SSO_PLAN_FILE)
  : path.resolve(process.cwd(), 'tenant-transitions', 'templates', 'sso-test-plan.template.json');
const plan = JSON.parse(readFileSync(planPath, 'utf8')) as SsoPlan;

function toEnvKey(displayName: string): string {
  return displayName.toUpperCase().replace(/[^A-Z0-9]+/g, '_').replace(/^_|_$/g, '');
}

function samlStartUrl(application: SsoApplication): string | undefined {
  return process.env[`IDENTITY_SAML_START_URL_${toEnvKey(application.displayName)}`] ?? process.env.IDENTITY_SAML_START_URL;
}

for (const application of plan.applications) {
  test(`${application.protocol} flow validates for ${application.displayName}`, async ({ page, request }) => {
    if (/openid connect|oauth/i.test(application.protocol)) {
      test.skip(!application.oidcDiscoveryUrl, `${application.displayName} is missing oidcDiscoveryUrl in ${planPath}.`);

      const discoveryUrl = application.oidcDiscoveryUrl!.replace('{tenantId}', tenantId);
      const response = await request.get(discoveryUrl);

      expect(response.ok()).toBeTruthy();

      const metadata = await response.json();
      expect(metadata.issuer).toBeTruthy();
      expect(metadata.authorization_endpoint).toBeTruthy();
      expect(metadata.token_endpoint).toBeTruthy();
      return;
    }

    if (/saml/i.test(application.protocol)) {
      const startUrl = samlStartUrl(application);
      test.skip(!startUrl, `Set IDENTITY_SAML_START_URL_${toEnvKey(application.displayName)} or IDENTITY_SAML_START_URL.`);

      const response = await page.goto(startUrl!, { waitUntil: 'domcontentloaded' });
      expect((response?.status() ?? 0) < 400).toBeTruthy();

      if (page.url().includes('login.microsoftonline.com')) {
        await expect(page.locator('input[name="loginfmt"]')).toBeVisible();
      }

      const expectedText = process.env.IDENTITY_SAML_EXPECTED_TEXT;
      if (expectedText) {
        await expect(page.getByText(expectedText, { exact: false })).toBeVisible();
      }

      return;
    }

    throw new Error(`Unsupported SSO protocol '${application.protocol}' for ${application.displayName}.`);
  });
}
