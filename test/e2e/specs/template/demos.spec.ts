import { test, expect, type Page } from '@playwright/test';
import { templateUrl } from '../../helpers/env';

/** The demo card whose heading matches `name`. */
const card = (page: Page, name: string) =>
  page.locator('section.card', { has: page.getByRole('heading', { name, exact: true }) });

test.describe('Template Demos', () => {
  test('Events: client and server handlers update state', async ({ page }) => {
    await page.goto(templateUrl('/events'));

    for (const side of ['Client', 'Server']) {
      const button = card(page, side).getByRole('button');
      await expect(button).toHaveText(/Click Me 1/);
      await button.click();
      await expect(button).toHaveText(/Click Me 2/);
    }
  });

  test('Forms: validates input and keeps server state', async ({ page }) => {
    await page.goto(templateUrl('/form'));
    await expect(page.getByText('Please log in.')).toBeVisible();

    await page.getByPlaceholder('Enter name').fill('Ada');
    await page.getByPlaceholder('Enter ID (10-100)').fill('5');
    await page.getByRole('button', { name: 'Submit' }).click();
    await expect(page.getByText('ID must be between 10 and 100.')).toBeVisible();

    await page.getByPlaceholder('Enter name').fill('Ada');
    await page.getByPlaceholder('Enter ID (10-100)').fill('42');
    await page.getByRole('button', { name: 'Submit' }).click();
    await expect(page.getByText('Welcome back, Ada!')).toBeVisible();
    await expect(page.getByText('Hi Ada! You can register again!')).toBeVisible();
  });

  test('Actions: client and server forms submit to the same action', async ({ page }) => {
    await page.goto(templateUrl('/actions'));

    for (const [side, name] of [['Client-rendered', 'Ziex Client'], ['Server-rendered', 'Ziex Server']]) {
      const form = card(page, side);
      await expect(form.locator('input[name="name"]')).toHaveValue(name);
      await form.getByRole('button', { name: 'Submit' }).click();
      await expect(page.getByRole('heading', { level: 1, name: 'Actions' })).toBeVisible();
    }
  });

  test('Database: added note is persisted and listed', async ({ page }) => {
    const note = `e2e note ${Date.now()}`;
    await page.goto(templateUrl('/db'));

    await page.getByPlaceholder('Write a note').fill(note);
    await page.getByRole('button', { name: 'Add note' }).click();
    await expect(page.getByText(new RegExp(`^#\\d+ ${note}$`))).toBeVisible();

    await page.goto(templateUrl('/db'));
    await expect(page.getByText(note)).toBeVisible();
  });

  test('Key-Value: typed counter increments and message is saved', async ({ page }) => {
    const visits = async () =>
      Number((await page.getByText(/viewed \d+ times/).textContent())?.match(/\d+/)?.[0]);

    await page.goto(templateUrl('/kv'));
    const first = await visits();
    await page.reload();
    expect(await visits()).toBeGreaterThan(first);

    const message = `e2e message ${Date.now()}`;
    await page.getByPlaceholder('Save a message').fill(message);
    await page.getByRole('button', { name: 'Save' }).click();
    await expect(card(page, 'Expiring value').getByText(message)).toBeVisible();
  });
});
