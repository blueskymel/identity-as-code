import { expect, test, type Browser, type BrowserContext, type Page } from '@playwright/test';

const loginUrl = process.env.IDENTITY_LOGIN_URL;
const protectedUrl = process.env.IDENTITY_RBAC_PROTECTED_URL;
const adminUser = process.env.IDENTITY_ADMIN_USERNAME;
const adminPassword = process.env.IDENTITY_ADMIN_PASSWORD;
const limitedUser = process.env.IDENTITY_LIMITED_USERNAME;
const limitedPassword = process.env.IDENTITY_LIMITED_PASSWORD;
const allowedText = process.env.IDENTITY_RBAC_ALLOWED_TEXT;
const deniedText = process.env.IDENTITY_RBAC_DENIED_TEXT ?? 'You do not have access';

function missingVariables(): string[] {
  return [
    ['IDENTITY_LOGIN_URL', loginUrl],
    ['IDENTITY_RBAC_PROTECTED_URL', protectedUrl],
    ['IDENTITY_ADMIN_USERNAME', adminUser],
    ['IDENTITY_ADMIN_PASSWORD', adminPassword],
    ['IDENTITY_LIMITED_USERNAME', limitedUser],
    ['IDENTITY_LIMITED_PASSWORD', limitedPassword]
  ].filter(([, value]) => !value).map(([name]) => name);
}

async function clickFirstVisible(page: Page, selectors: string[]): Promise<void> {
  for (const selector of selectors) {
    const control = page.locator(selector).first();

    if (await control.isVisible().catch(() => false)) {
      await control.click();
      return;
    }
  }

  throw new Error(`Unable to find a visible control for selectors: ${selectors.join(', ')}`);
}

async function signIn(browser: Browser, username: string, password: string): Promise<BrowserContext> {
  const context = await browser.newContext();
  const page = await context.newPage();

  await page.goto(loginUrl!, { waitUntil: 'domcontentloaded' });
  await page.locator('input[name="loginfmt"]').fill(username);
  await clickFirstVisible(page, ['input[type="submit"]', 'button[type="submit"]']);
  await page.locator('input[name="passwd"]').fill(password);
  await clickFirstVisible(page, ['input[type="submit"]', 'button[type="submit"]']);

  if (await page.locator('text=Stay signed in?').isVisible().catch(() => false)) {
    await clickFirstVisible(page, ['input[value="No"]', 'button:has-text("No")']);
  }

  return context;
}

test.describe('RBAC validation', () => {
  test('privileged identity can open the protected resource', async ({ browser }) => {
    const missing = missingVariables();
    test.skip(missing.length > 0, `Set ${missing.join(', ')} to run this test.`);

    const context = await signIn(browser, adminUser!, adminPassword!);
    const page = await context.newPage();

    await page.goto(protectedUrl!, { waitUntil: 'networkidle' });

    if (allowedText) {
      await expect(page.getByText(allowedText, { exact: false })).toBeVisible();
    } else {
      await expect(page.getByText(deniedText, { exact: false })).toHaveCount(0);
    }

    await context.close();
  });

  test('limited identity is blocked from the protected resource', async ({ browser }) => {
    const missing = missingVariables();
    test.skip(missing.length > 0, `Set ${missing.join(', ')} to run this test.`);

    const context = await signIn(browser, limitedUser!, limitedPassword!);
    const page = await context.newPage();

    await page.goto(protectedUrl!, { waitUntil: 'networkidle' });
    await expect(page.getByText(deniedText, { exact: false })).toBeVisible();

    await context.close();
  });
});
