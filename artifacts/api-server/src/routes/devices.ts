import { Router, type Request, type Response, type NextFunction } from "express";
import { db } from "@workspace/db";
import { deviceRegistryTable } from "@workspace/db";
import { sql } from "drizzle-orm";

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

// ── POST /devices/register — تسجيل جهاز جديد ──────────────────
router.post("/devices/register", async (req: Request, res: Response) => {
  try {
    const { device_id, device_name, device_type, platform, username } =
      req.body as {
        device_id: string;
        device_name: string;
        device_type: string;
        platform: string;
        username: string;
      };

    if (!device_id || !device_name) {
      res.status(400).json({ error: "missing_fields" });
      return;
    }

    // تحقق إذا كان الجهاز مسجلاً من قبل
    const existing = await db
      .select()
      .from(deviceRegistryTable)
      .where(sql`device_id = ${device_id}`)
      .limit(1);

    if (existing.length > 0) {
      res.json({ success: true, status: existing[0].status });
      return;
    }

    // الديسكتوب الموثوق: يُعتمد تلقائياً
    const isAutoApproved = device_type === "desktop_trusted";
    const inserted = await db
      .insert(deviceRegistryTable)
      .values({
        deviceId: device_id,
        deviceName: device_name,
        deviceType: device_type,
        platform: platform ?? null,
        username: username ?? null,
        status: isAutoApproved ? "approved" : "pending",
        approvedAt: isAutoApproved ? new Date() : null,
      })
      .returning();

    res.json({ success: true, status: inserted[0].status });
  } catch (e) {
    req.log.error(e);
    res.status(500).json({ error: "server_error" });
  }
});

// ── GET /devices/status/:deviceId — حالة الجهاز ───────────────
router.get("/devices/status/:deviceId", async (req: Request, res: Response) => {
  try {
    const { deviceId } = req.params;
    const rows = await db
      .select()
      .from(deviceRegistryTable)
      .where(sql`device_id = ${deviceId}`)
      .limit(1);

    if (rows.length === 0) {
      res.json({ status: "unknown" });
      return;
    }
    res.json({ status: rows[0].status, device_name: rows[0].deviceName });
  } catch (e) {
    res.status(500).json({ error: "server_error" });
  }
});

// ── GET /devices/pending — الأجهزة المعلّقة (للمدير) ───────────
router.get("/devices/pending", async (req: Request, res: Response) => {
  try {
    const rows = await db
      .select()
      .from(deviceRegistryTable)
      .where(sql`status = 'pending'`)
      .orderBy(deviceRegistryTable.registeredAt);
    res.json({ devices: rows });
  } catch (e) {
    res.status(500).json({ error: "server_error" });
  }
});

// ── GET /devices/all — كل الأجهزة (للمدير) ────────────────────
router.get("/devices/all", async (req: Request, res: Response) => {
  try {
    const rows = await db
      .select()
      .from(deviceRegistryTable)
      .orderBy(deviceRegistryTable.registeredAt);
    res.json({ devices: rows });
  } catch (e) {
    res.status(500).json({ error: "server_error" });
  }
});

// ── POST /devices/:id/approve — الموافقة على جهاز ─────────────
router.post("/devices/:id/approve", async (req: Request, res: Response) => {
  try {
    const id = parseInt(String(req.params.id), 10);
    if (isNaN(id)) {
      res.status(400).json({ error: "invalid_id" });
      return;
    }
    await db
      .update(deviceRegistryTable)
      .set({ status: "approved", approvedAt: new Date() })
      .where(sql`id = ${id}`);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: "server_error" });
  }
});

// ── POST /devices/:id/reject — رفض جهاز ───────────────────────
router.post("/devices/:id/reject", async (req: Request, res: Response) => {
  try {
    const id = parseInt(String(req.params.id), 10);
    const { reason } = req.body as { reason?: string };
    if (isNaN(id)) {
      res.status(400).json({ error: "invalid_id" });
      return;
    }
    await db
      .update(deviceRegistryTable)
      .set({ status: "rejected", rejectionReason: reason ?? "" })
      .where(sql`id = ${id}`);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: "server_error" });
  }
});

export default router;
