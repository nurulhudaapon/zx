import { test, expect } from '@playwright/test';
import { templateUrl } from '../../helpers/env';

const pages: { nav: string; path: string; heading: string }[] = [
  { nav: 'Events', path: '/events', heading: 'Events' },
  { nav: 'Forms', path: '/form', heading: 'Forms' },
  { nav: 'Actions', path: '/actions', heading: 'Actions' },
  { nav: 'DB', path: '/db', heading: 'Database' },
  { nav: 'KV', path: '/kv', heading: 'Key-Value' },
];

test.describe('Template Routing', () => {
  for (const { nav, path, heading } of pages) {
    test(`Nav link navigates to ${path}`, async ({ page }) => {
      await page.goto(templateUrl());
      await page.locator('header nav').getByRole('link', { name: nav, exact: true }).click();

      await expect(page).toHaveURL(new RegExp(`${templateUrl(path)}$`));
      await expect(page.getByRole('heading', { level: 1, name: heading })).toBeVisible();
    });
  }

  test('Demo card and brand link navigate', async ({ page }) => {
    await page.goto(templateUrl());
    await page.locator('main').getByRole('link', { name: /^Database →/ }).click();
    await expect(page).toHaveURL(new RegExp(`${templateUrl('/db')}$`));

    await page.locator('header .brand').click();
    await expect(page.getByRole('heading', { name: 'Build full-stack web apps with Zig.' })).toBeVisible();
  });
});
