# برنامج إدارة مخالفات هندسة صرف الفشن — Sync Backend

سيرفر المزامنة متعدد الأجهزة لبرنامج Flutter الخاص بإدارة المخالفات الهندسية.

## Run & Operate

- `pnpm --filter @workspace/api-server run dev` — run the API server (port 8080)
- `pnpm run typecheck` — full typecheck across all packages
- `pnpm run build` — typecheck + build all packages
- `pnpm --filter @workspace/api-spec run codegen` — regenerate API hooks and Zod schemas from the OpenAPI spec
- `pnpm --filter @workspace/db run push` — push DB schema changes (dev only)
- Required env: `DATABASE_URL` — Postgres connection string (auto-provisioned)
- Required env: `SYNC_API_KEY` — shared API key (default: `alfashn-sync-key-2024`)

## Stack

- pnpm workspaces, Node.js 24, TypeScript 5.9
- API: Express 5
- DB: PostgreSQL + Drizzle ORM
- Validation: Zod (`zod/v4`), `drizzle-zod`
- API codegen: Orval (from OpenAPI spec)
- Build: esbuild (CJS bundle)

## Where things live

- `lib/db/src/schema/sync.ts` — Drizzle schema for `sync_log` and `device_registry` tables
- `artifacts/api-server/src/routes/sync.ts` — POST /sync/push + GET /sync/pull
- `artifacts/api-server/src/routes/devices.ts` — device registration and approval routes
- `extracted_flutter/lib/` — Flutter files ready to copy into the Flutter project
- `extracted_flutter/SYNC_INTEGRATION_GUIDE.md` — step-by-step Flutter integration guide

## API Endpoints

All endpoints require `X-API-Key: alfashn-sync-key-2024` header.

| Method | Path | Description |
|--------|------|-------------|
| GET | /api/healthz | Health check |
| POST | /api/sync/push | Push sync_log entries from a device |
| GET | /api/sync/pull?after=N&device_id=X | Pull changes from other devices since seq N |
| POST | /api/devices/register | Register a new device |
| GET | /api/devices/status/:deviceId | Check device approval status |
| GET | /api/devices/pending | List pending devices (manager only) |
| GET | /api/devices/all | List all devices |
| POST | /api/devices/:id/approve | Approve a device |
| POST | /api/devices/:id/reject | Reject a device |

## Architecture decisions

- **Trusted desktops auto-approved**: `device_type = 'desktop_trusted'` gets auto-approved on register
- **Mobile needs manager approval**: `device_type = 'mobile'` starts with status `pending`
- **Images NOT synced**: Only text/metadata synced to keep data usage minimal (few KB per sync)
- **Last-write-wins conflict resolution**: Based on `local_ts` of the originating device
- **No new Flutter packages**: sync uses `dart:io` HttpClient directly (no http package needed)

## Product

خدمة مزامنة خفيفة الوزن تربط:
- **جهازَي الديسكتوب** (مكتب المطور + مكتب الهندسة): أوفلاين، يتصلان عبر الهوتسبوت دقائق معدودة يومياً
- **الموبايل والتابليت**: متصلة دائماً بالإنترنت، تزامن تلقائي كل 5 دقائق

## User preferences

- لا تُنشئ تطبيق ويب جديد أو أي واجهة مستخدم على الويب
- الملفات في `extracted_flutter/lib/` هي ملفات Dart جاهزة للنسخ إلى مشروع Flutter المستخدم
- الصور والمرفقات تبقى محلياً — لا تُزامَن عبر السيرفر

## Gotchas

- يجب تشغيل `pnpm run typecheck:libs` قبل `typecheck` لبناء مكتبة `@workspace/db` أولاً
- عند تغيير `SYNC_API_KEY`، يجب تحديثه في `sync_config.dart` أيضاً
- الديسكتوب يعمل بالكامل أوفلاين — المزامنة اختيارية تماماً

## Pointers

- See the `pnpm-workspace` skill for workspace structure, TypeScript setup, and package details
- Flutter integration instructions: `extracted_flutter/SYNC_INTEGRATION_GUIDE.md`
