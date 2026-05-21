import { Router, type Request, type Response, type NextFunction } from "express";
import { db } from "@workspace/db";
import { syncLogTable, deviceRegistryTable } from "@workspace/db";
import { gt, and, ne, sql } from "drizzle-orm";

const router = Router();

// ── مفتاح API ─────────────────────────────────────────────────
const requireApiKey = (req: Request, res: Response, next: NextFunction) => {
  const key = req.headers["x-api-key"];
  const validKey = process.env.SYNC_API_KEY ?? "alfashn-sync-key-2024";
  if (key !== validKey) {
    res.status(401).json({ error: "unauthorized" });
    return;
  }
  next();
};

router.use(requireApiKey);

// ── POST /sync/push — إرسال التغييرات من جهاز إلى السيرفر ─────
router.post("/sync/push", async (req: Request, res: Response) => {
  try {
    const { device_id, entries } = req.body as {
      device_id: string;
      entries: Array<{
        table_name: string;
        record_id: number | null;
        operation: string;
        data_json: string;
        local_ts: string;
      }>;
    };

    if (!device_id || !Array.isArray(entries) || entries.length === 0) {
      res.json({ success: true, inserted: 0, max_server_id: 0 });
      return;
    }

    // تحقق من أن الجهاز معتمد
    const device = await db
      .select()
      .from(deviceRegistryTable)
      .where(sql`device_id = ${device_id}`)
      .limit(1);

    if (device.length === 0 || device[0].status !== "approved") {
      res.status(403).json({ error: "device_not_approved" });
      return;
    }

    // أدرِج الإدخالات
    const inserted = await db
      .insert(syncLogTable)
      .values(
        entries.map((e) => ({
          deviceId: device_id,
          tableName: e.table_name,
          recordId: e.record_id ?? null,
          operation: e.operation,
          dataJson: e.data_json,
          localTs: e.local_ts,
        })),
      )
      .returning({ id: syncLogTable.id });

    const maxId =
      inserted.length > 0 ? Math.max(...inserted.map((r) => r.id)) : 0;

    // حدّث وقت آخر مزامنة للجهاز
    await db
      .update(deviceRegistryTable)
      .set({ lastSyncAt: new Date() })
      .where(sql`device_id = ${device_id}`);

    res.json({
      success: true,
      inserted: inserted.length,
      max_server_id: maxId,
    });
  } catch (e) {
    req.log.error(e);
    res.status(500).json({ error: "server_error" });
  }
});

// ── GET /sync/pull — سحب التغييرات من الأجهزة الأخرى ──────────
// query params: after=<last_server_id>  device_id=<my_device_id>
router.get("/sync/pull", async (req: Request, res: Response) => {
  try {
    const after = parseInt((req.query.after as string) ?? "0", 10) || 0;
    const deviceId = (req.query.device_id as string) ?? "";

    const entries = await db
      .select()
      .from(syncLogTable)
      .where(and(gt(syncLogTable.id, after), ne(syncLogTable.deviceId, deviceId)))
      .orderBy(syncLogTable.id)
      .limit(1000);

    const maxId =
      entries.length > 0 ? Math.max(...entries.map((e) => e.id)) : after;

    res.json({
      entries: entries.map((e) => ({
        id: e.id,
        device_id: e.deviceId,
        table_name: e.tableName,
        record_id: e.recordId,
        operation: e.operation,
        data_json: e.dataJson,
        local_ts: e.localTs,
      })),
      max_id: maxId,
    });
  } catch (e) {
    req.log.error(e);
    res.status(500).json({ error: "server_error" });
  }
});

export default router;
