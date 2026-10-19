import { test, expect } from '@playwright/test';

test.describe('List Insert Example', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/examples/list-insert');
  });

  test('if turning true before a for list is inserted above the list', async ({ page }) => {
    const section = page.locator('#if-before-for');
    await expect(section.locator('.item')).toHaveText(['One', 'Two']);

    await section.getByRole('button', { name: 'Show' }).click();
    await expect(section.locator('.item')).toHaveText(['New', 'One', 'Two']);
  });

  test('for list grows in place when followed by an empty if', async ({ page }) => {
    const section = page.locator('#for-before-empty-if');
    await expect(section.locator('.item')).toHaveText(['One', 'Two']);

    await section.getByRole('button', { name: 'Add' }).click();
    await section.getByRole('button', { name: 'Add' }).click();
    await expect(section.locator('.item')).toHaveText(['One', 'Two', 'Three', 'Four']);
    // New items stay before the button rather than being appended after it.
    const order = await section.evaluate((el) => [...el.children].map((c) => c.textContent));
    expect(order).toEqual(['One', 'Two', 'Three', 'Four', 'Add']);
  });

  test('changing a form key remounts it with empty fields', async ({ page }) => {
    const section = page.locator('#keyed-form');
    const input = section.locator('input[name="text"]');

    await input.fill('first');
    await section.getByRole('button', { name: 'Save' }).click();
    await expect(section.locator('.last')).toHaveText('first');
    await expect(input).toHaveValue('');

    await input.fill('keep');
    await section.getByRole('button', { name: 'Save' }).click();
    await expect(section.locator('.last')).toHaveText('kept');
    await expect(input).toHaveValue('keep');

    // The remounted form still has its action wired up.
    await input.fill('second');
    await section.getByRole('button', { name: 'Save' }).click();
    await expect(section.locator('.last')).toHaveText('second');
    await expect(input).toHaveValue('');
  });
});
