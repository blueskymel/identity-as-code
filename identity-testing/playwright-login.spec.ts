import { expect, test, type Page } from '@playwright/test';

const loginUrl = process.env.IDENTITY_LOGIN_URL;
const username = process.env.IDENTITY_TEST_USERNAME;
const password = process.env.IDENTITY_TEST_PASSWORD;
const expectedUrlPattern = process.env.IDENTITY_POST_LOGIN_URL_REGEX;
const expectedText = process.env.IDENTITY_POST_LOGIN_TEXT;
const staySignedIn = (process.env.IDENTITY_STAY_SIGNED_IN ?? 'false').toLowerCase() === 'true';

function missingVariables(): string[] {
  return [
    ['IDENTITY_LOGIN_URL', loginUrl],
    ['IDENTITY_TEST_USERNAME', username],
    ['IDENTITY_TEST_PASSWORD', password]
  ].filter(([, value]) => !value).map(([name]) => name);
}

async function clickFirstVisible(page: Page, selectors: string[]): Promise<boolean> {
  for (const selector of selectors) {
    const control = page.locator(selector).first();

    if (await control.isVisible().catch(() => false)) {
      await control.click();
      return true;
    }
  }

  return false;
}

async function completeMicrosoftSignIn(page: Page, accountName: string, accountPassword: string): Promise<void> {
  await page.goto(loginUrl!, { waitUntil: 'domcontentloaded' });
  await expect(page.locator('input[name="loginfmt"]')).toBeVisible();
  await page.locator('input[name="loginfmt"]').fill(accountName);
  await clickFirstVisible(page, ['input[type="submit"]', 'button[type="submit"]']);

  await expect(page.locator('input[name="passwd"]')).toBeVisible();
  await page.locator('input[name="passwd"]').fill(accountPassword);
  await clickFirstVisible(page, ['input[type="submit"]', 'button[type="submit"]']);

  if (await page.locator('text=Stay signed in?').isVisible().catch(() => false)) {
    await clickFirstVisible(
      page,
      staySignedIn ? ['input[value="Yes"]', 'button:has-text("Yes")'] : ['input[value="No"]', 'button:has-text("No")']
    );
  }
}

test('primary identity login succeeds', async ({ page }) => {
  const missing = missingVariables();
  test.skip(missing.length > 0, `Set ${missing.join(', ')} to run this test.`);

  await completeMicrosoftSignIn(page, username!, password!);
  await page.waitForLoadState('networkidle');

  if (expectedUrlPattern) {
    await expect(page).toHaveURL(new RegExp(expectedUrlPattern));
  }

  if (expectedText) {
    await expect(page.getByText(expectedText, { exact: false })).toBeVisible();
    return;
  }

  await expect(page.locator('input[name="passwd"]')).toHaveCount(0);
});
