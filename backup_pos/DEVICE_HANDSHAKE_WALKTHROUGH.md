# Device Handshake Rollout Walkthrough

## Summary
- The POS now uses device registration plus PIN-based daily access instead of cashier email/password login.
- Device onboarding is handled by one-time invite codes stored and claimed through Supabase.
- Day-to-day cashier access is device-local plus PIN-based, while hidden admin access still uses Supabase Auth for the device-management console.

## Implemented Now

### 1. Device-based onboarding and registration
- New hardware starts as unregistered and is routed to `InviteCodeScreen`.
- Invite codes are claimed through the `claim_invite_code` RPC, which registers the device in `registered_devices` and caches the device role/name locally.
- Registered devices cache enough local identity to support normal startup and offline PIN validation.

### 2. Startup routing
- App launch now resolves device status before trusting any cached login state.
- Current route matrix is:
  - `registered` + cached session -> `HomeScreen`
  - `registered` + no cached session -> `LoginScreen`
  - `unregistered` -> `InviteCodeScreen`
  - `deactivated` -> revoked/locked screen
  - `unknown` -> `LoginScreen`
- If a device is revoked or removed from registration, stale local session keys are cleared instead of reopening the home screen.

### 3. PIN login and session bootstrap
- Cashiers log in with the global Admin or Staff PIN instead of email/password.
- On successful PIN entry, the app creates the shift first and only then persists:
  - `is_logged_in`
  - `user_role`
  - `current_shift_id`
  - `display_name`
  - `user_email`
  - `business_day_start`
- If shift creation fails, partial login state is cleared so the next launch does not inherit a broken session.

### 4. PIN source of truth
- Online devices fetch `pin_admin` and `pin_staff` from `sync_control` and cache those values locally.
- Offline PIN entry uses the last cached values when the cloud is unavailable.
- This means PIN changes propagate on the next successful connected login cycle, not as an instant forced update on every device.

### 5. Admin device console
- The hidden five-tap logo path still exposes admin email/password auth for management access.
- Successful admin auth opens `AdminDevicesScreen`, which currently includes:
  - code generation
  - registered-device listing/revocation
  - system PIN management
- Invite expiry options currently include no expiry, `2h`, `24h`, and `72h`.

### 6. Offline-capable vs online-only devices
- The app still uses a hybrid device-mode model:
  - `offlineCapable`: local SQLite remains authoritative for write activity and syncs later
  - `onlineOnly`: writes require connectivity and go directly to Supabase
- Online-only devices still keep a local cache for reads and UI refresh. The distinction is write authority, not whether local data exists at all.
- The single offline-capable owner is still enforced through `sync_control.offline_owner_device_id` and the related RPCs.

### 7. Debt sale correctness
- “Sell to Customer” is now handled as one application workflow instead of a loose transaction-write followed by a separate debt-write.
- Offline-capable devices write the transaction, transaction items, debt record, and sync-queue entries in one SQLite transaction.
- Online-only devices use a direct cloud workflow that rolls back the transaction bundle if the debt write fails after the sale has already been created.
- UI success handling now happens only after the combined workflow succeeds:
  - cart clearing
  - success snackbar
  - WhatsApp launch
  - audit logging

### 8. Category CSV synchronization
- Category-name CSV imports still remain restricted to offline-capable devices because they rewrite local business data in bulk.
- Renamed categories now queue `products/UPSERT` sync entries for the affected products instead of stopping at local SQLite updates.
- When the device is online, the queue processor is kicked afterward so the category rename can propagate to Supabase and other devices.

## Backend Trust Model
- Sensitive transitions are enforced primarily by Supabase RPCs plus application-side trust boundaries.
- In practice, the important control points are:
  - `claim_invite_code`
  - `generate_invite_code`
  - `revoke_device`
  - `update_system_pins`
  - `claim_offline_owner`
  - `release_offline_owner`
- This rollout does **not** claim that every underlying table now has uniformly strict RLS. Some direct table policies remain broader than the RPC surface.

## Known Boundaries
- Hidden admin access still depends on Supabase Auth and `user_profiles`; employee-style online user management has been reduced, not fully removed from the backend.
- Cached offline PIN use is intentionally still possible until a device reconnects and refreshes cloud values.
- This pass improves client correctness and documentation accuracy. It does not include new Supabase migrations, new RPCs, or RLS hardening.

## Future Hardening
- Tighten table-level Supabase policies so the backend guarantees match the current RPC-driven trust model more explicitly.
- Consider a dedicated backend-side composite RPC for “sale + debt” if we want server-enforced atomicity for online-only devices instead of best-effort client rollback.
- Consider periodic or resume-time device-status revalidation beyond startup if near-real-time revocation becomes a product requirement.
