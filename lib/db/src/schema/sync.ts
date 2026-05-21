import {
  pgTable,
  serial,
  text,
  timestamp,
  integer,
  index,
} from "drizzle-orm/pg-core";

// ── جدول سجل المزامنة ─────────────────────────────────────────
// كل تعديل (إضافة/تعديل/حذف) على أي جهاز يُسجَّل هنا
export const syncLogTable = pgTable(
  "sync_log",
  {
    id: serial("id").primaryKey(),
    deviceId: text("device_id").notNull(),
    tableName: text("table_name").notNull(),
    recordId: integer("record_id"),
    operation: text("operation").notNull(), // 'insert' | 'update' | 'delete'
    dataJson: text("data_json").notNull(),
    localTs: text("local_ts").notNull(),
    serverTs: timestamp("server_ts").defaultNow().notNull(),
  },
  (table) => ({
    deviceIdIdx: index("idx_sync_log_device_id").on(table.deviceId),
    serverTsIdx: index("idx_sync_log_server_ts").on(table.serverTs),
  }),
);

// ── جدول تسجيل الأجهزة ────────────────────────────────────────
// كل جهاز يُسجَّل مرة واحدة، والمدير يوافق على الأجهزة المحمولة
export const deviceRegistryTable = pgTable("device_registry", {
  id: serial("id").primaryKey(),
  deviceId: text("device_id").notNull().unique(),
  deviceName: text("device_name").notNull(),
  deviceType: text("device_type").notNull(), // 'desktop_trusted' | 'mobile' | 'tablet'
  platform: text("platform"),
  username: text("username"),
  status: text("status").notNull().default("pending"), // 'pending' | 'approved' | 'rejected'
  registeredAt: timestamp("registered_at").defaultNow().notNull(),
  approvedAt: timestamp("approved_at"),
  approvedBy: integer("approved_by"),
  rejectionReason: text("rejection_reason"),
  lastSyncAt: timestamp("last_sync_at"),
});

export type SyncLog = typeof syncLogTable.$inferSelect;
export type DeviceRegistry = typeof deviceRegistryTable.$inferSelect;
