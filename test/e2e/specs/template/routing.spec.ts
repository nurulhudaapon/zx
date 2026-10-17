import { test, expect } from '@playwright/test';
import { isTemplateServer, templateUrl } from '../../helpers/env';

test.describe('Template Home UI and Navigation', () => {
  test('Internal routing between Home and example pages works', async ({ page }) => {
    await page.goto(templateUrl());

    if (isTemplateServer) {
      await page.getByRole('link', { name: 'Client Action' }).click();
      await expect(page).toHaveURL(/\/actions\/client$/);
    } else {
      // Site embeds the template under /templates; absolute hrefs in the
      // template source leave that prefix, so navigate the embed paths directly.
      await page.goto(templateUrl('/actions/client'));
      await expect(page).toHaveURL(/\/templates\/actions\/client$/);
    }
    await expect(page.getByRole('button', { name: /Click Me/ })).toBeVisible();

    if (isTemplateServer) {
      await page.goto(templateUrl());
      await page.getByRole('link', { name: 'Server Event' }).click();
      await expect(page).toHaveURL(/\/actions\/server$/);
    } else {
      await page.goto(templateUrl('/actions/server'));
      await expect(page).toHaveURL(/\/templates\/actions\/server$/);
    }
    await expect(page.getByRole('heading', { name: 'Ziex' })).toBeVisible();

    await page.goto(templateUrl());
    await expect(page.getByRole('button', { name: 'Reset' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Decrement' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Increment' })).toBeVisible();
  });
});
