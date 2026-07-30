# AI Business OS — Phase 3

Commercial documents: Quotation & BOQ, Proposal Generator, Website & App Estimator.

## Quotation & BOQ

- CCTV BOQ engine: cameras (IP/HD), NVR channels, PoE switches, cable, HDD TB, accessories, labour + 18% GST lines
- Link to deal / lead + customer fields
- Line-item viewer, mark sent, draft proposal from quotation

## Proposals

- Tenant templates (`bos_proposal_templates`, default seeded for DG.YARD)
- Edge `bos-proposal-draft`: fills template from deal/lead/quotation + KB; optional OpenAI polish
- Admin: AI draft picker, edit markdown, mark sent

## Estimator

- Questionnaire: website / app / both, pages, platforms, ecommerce, admin panel, SEO pack
- Live indicative total → save `bos_estimates`
- **To proposal** converts estimate into a draft proposal

## Edge

| Function | Purpose |
|----------|---------|
| `bos-proposal-draft` | Generate proposal markdown |

## Migration

`20260730162928_ai_business_os_phase3.sql`
