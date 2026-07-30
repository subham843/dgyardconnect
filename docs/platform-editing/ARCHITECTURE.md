# Platform editing — image search & text assist

## Overview

Shared editing layer for DG Yard Connect admin (Shop today; Blog / Quotation later).

| Capability | Flutter | Backend |
|------------|---------|---------|
| Upload or Google Images | `ShopImageSourceFlow`, `DgGoogleImagePickSheet` | — (no image API; browser opens Google Images) |
| Image editor (crop, WebP, watermark, …) | `ShopImageEditorScreen` | — |
| Text spell / grammar / AI assist | `DgAssistTextField` | `platform-text-assist` (free: Groq / Gemini) |
| Media attribution | `ProcessedShopImage.sourceUrl` | DB columns on categories, sub_categories, products, brands, `product_media_assets` |

## Image workflow

1. User chooses **Upload image** or **Search on Google**.
2. Google: popup/tab opens `google.com/search?tbm=isch&q=…` (product + category + brand). User saves image to PC.
3. User taps **Use saved image** → file picker (opens Downloads folder on desktop) → bytes loaded into app.
4. **Image editor** → user confirms.
5. Pending image held until entity **Save** → upload to `shop-media` bucket.

> Web browsers cannot read the Downloads folder automatically after save — picking the file is required.

## Text workflow

- Inline chips show local + remote spell hints (never auto-replace).
- **AI assist** menu (✨) runs an action → preview dialog → user taps **Apply**.
- SEO fields support suggest title / meta / slug from context.

## Permissions

| Action | Who |
|--------|-----|
| Text assist API | `app_role = superadmin` |
| Storage write | `auth_is_superadmin()` (existing RLS) |

## Secrets (Supabase Dashboard → Edge Functions)

**Free (no billing):** see [FREE_AI_SETUP.md](FREE_AI_SETUP.md)

| Secret | Where to get |
|--------|----------------|
| `GROQ_API_KEY` | [console.groq.com](https://console.groq.com) — recommended |
| `GEMINI_API_KEY` | [aistudio.google.com/apikey](https://aistudio.google.com/apikey) |
| `OPENAI_API_KEY` | optional paid |

Deploy text assist:

```cmd
cd e:\dgyardconnect\scripts
npx supabase functions deploy platform-text-assist --no-verify-jwt
```

## Database impact

Migration `20260604141126_platform_media_text_attribution.sql`:

- `categories`, `sub_categories`, `products`: `image_source_*`, `image_attribution`
- `products`: `main_image_source_*`, `main_image_attribution`
- `brands`: `logo_*`, `image_source_*`
- `product_media_assets`: `source_url`, `source_provider`, `attribution`

## Adopting in new screens

**Images**

```dart
final processed = await ShopImageSourceFlow.pickProcessedImage(
  context,
  preset: ShopImagePreset.productMain,
  altTextHint: name,
  searchContext: DgImageSearchContext(productName: name, categoryName: cat),
);
```

**Text**

```dart
DgAssistTextField(
  controller: _descCtrl,
  assistProfile: TextAssistProfile.description,
  contextHints: TextAssistContext(productName: name, categoryName: cat),
  decoration: const InputDecoration(labelText: 'Description'),
)
```

## Future modules

- **Blog / Quotation**: reuse `lib/core/editing/`; add presets and save hooks in their repositories.
