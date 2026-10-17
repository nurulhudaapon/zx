import { test, expect } from '@playwright/test';
import { templateUrl } from '../../helpers/env';

test.describe('Template Home Content', () => {
  test('Hero, counter, demo and feature cards render', async ({ page }) => {
    await page.goto(templateUrl());

    await expect(page).toHaveTitle(/Ziex/);
    await expect(page.getByRole('heading', { name: 'Build full-stack web apps with Zig.' })).toBeVisible();
    await expect(page.getByText("Declarative UI components using familiar patterns, with full access to Zig's control flow.")).toBeVisible();

    await expect(page.getByRole('link', { name: 'Read the Docs' })).toHaveAttribute('href', 'https://ziex.dev/learn');
    await expect(page.getByRole('link', { name: 'GitHub' })).toHaveAttribute('href', /github\.com\/ziex-dev\/ziex/);

    await expect(page.getByRole('heading', { name: 'Hybrid Rendering' })).toBeVisible();
    for (const name of ['Reset', 'Decrement', 'Increment']) {
      await expect(page.getByRole('button', { name })).toBeVisible();
    }

    const main = page.locator('main');
    const demos: [string, string][] = [
      ['Events', 'events'],
      ['Forms', 'form'],
      ['Actions', 'actions'],
      ['Database', 'db'],
      ['Key-Value', 'kv'],
    ];
    for (const [name, href] of demos) {
      await expect(main.getByRole('link', { name: new RegExp(`^${name} →`) })).toHaveAttribute('href', href);
    }

    for (const name of ['File System Routing', 'API Routes', 'Deploy Anywhere']) {
      await expect(main.getByRole('heading', { name })).toBeVisible();
    }
  });

  test('Header and footer links', async ({ page }) => {
    await page.goto(templateUrl());

    const nav = page.locator('header nav');
    await expect(nav.getByText('Demos')).toBeVisible();
    await expect(nav.getByRole('link', { name: 'Docs' })).toHaveAttribute('href', 'https://ziex.dev');
    await expect(page.locator('header .brand img')).toHaveAttribute('src', '/favicon.ico');

    await expect(page.locator('footer').getByRole('link', { name: 'app/pages/page.zx' }))
      .toHaveAttribute('href', '/.well-known/_zx/open-in-editor?file=app/pages/page.zx');
  });
});
