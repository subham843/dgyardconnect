// Shared plan limit checks for Edge functions.
import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

export async function assertUsageLimit(
  db: SupabaseClient,
  tenantId: string,
  metric: string,
  addQuantity = 1,
): Promise<void> {
  const { data: tenant } = await db.from("bos_tenants").select("plan_id").eq("id", tenantId).maybeSingle();
  if (!tenant?.plan_id) return;
  const { data: plan } = await db.from("bos_plans").select("limits").eq("id", tenant.plan_id).maybeSingle();
  const limits = (plan?.limits ?? {}) as Record<string, number>;
  const max = Number(limits[metric] ?? -1);
  if (max < 0) return;

  const since = new Date(Date.now() - 30 * 86400000).toISOString();
  const { data: events } = await db
    .from("bos_usage_events")
    .select("quantity")
    .eq("tenant_id", tenantId)
    .eq("metric", metric)
    .gte("occurred_at", since);

  let used = 0;
  for (const e of events ?? []) used += Number(e.quantity ?? 0);
  if (used + addQuantity > max) {
    throw new Error(`Plan limit reached for ${metric} (${max}/30d). Upgrade plan.`);
  }
}
