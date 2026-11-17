# In-app purchases

Prices and Polo Points amounts are unchanged from the game as it was.

## Products to create in App Store Connect

App Store Connect > your app > Monetization > In-App Purchases. **Product IDs must match exactly.**
They can never be reused or renamed, which is why the packs keep their old `blue_*` ids.

| Product ID | Type | Reference name / display name | US price | What the game gives |
|---|---|---|---|---|
| `pro_unlock` | **Non-Consumable** | PIXEL POLO + | $7.99 | Player name & number customization, plus 200 Polo Points once (first real purchase only) |
| `all_teams_unlock` | **Non-Consumable** | ALL 30 TEAMS | $2.99 | Every school selectable on the Road to Glory |
| `blue_100` | Consumable | Starter Pack | $1.99 | 60 Polo Points |
| `blue_350` | Consumable | Gameday Pack | $5.99 | 180 Polo Points |
| `blue_650` | Consumable | All-Star Pack | $9.99 | 350 Polo Points |
| `blue_1400` | Consumable | Legendary Pack | $19.99 | 800 Polo Points |
| `starter_pack` | Consumable | Starter Pack (one-time offer) | $1.99 | 600 Polo Points + gold cap trim |
| `playoff_bundle` | Consumable | Playoff Bundle | $4.99 | 900 Polo Points + whole roster healed |

`credits_*` ids also appear in `Store.PRODUCTS`, left over from Retro Swim. Nothing in the game
sells them, so **don't create them**.

Descriptions must match what's given. App Review checks them against the game. Each product needs
a review screenshot of where it's sold (the Polo Points Shop).

## How the game handles a purchase (`src/autoload/store.gd`, `src/store/backend_openiap.gd`)

- **Only a real transaction pays.** The shop never grants anything itself. Polo Points and unlocks
  are credited only when the store reports the transaction `Purchased` and it carries a
  transaction id.
- **Never twice.** Every credited transaction id is recorded (`CoinVault`). A repeated callback, a
  re-delivered transaction or a restore never pays again (tested).
- **Crash-safe order:** the purchase is credited and `store.cfg` is written (atomically,
  `SafeFile`), and only then is `finish_transaction` called. If the app dies in between, StoreKit
  delivers the transaction again on the next launch and it pays exactly once.
- **Canceled:** nothing happens, and no error is shown. **Failed:** the store's reason is shown.
  **Pending / Ask to Buy:** "Purchase pending: it will arrive once it's approved." It arrives later,
  even if the app was closed.
- **Restore Purchases** (Polo Points Shop, bottom): asks StoreKit to sync, then re-grants
  `pro_unlock` and `all_teams_unlock`. It never re-pays the PRO coins and never restores consumables.
- **Persistence:** everything bought lives in `user://store.cfg`, separate from dynasty saves. It
  survives restarts, deleting a dynasty, and starting a new one. On a new phone, one-time unlocks
  come back from the App Store at startup and through Restore; consumable Polo Points can't, which
  is how all consumables work.
- **Prices** shown are the App Store's own localized strings once it answers, and the USD list
  price until then.

## Refunds

- `Store._on_revoked` takes a refunded unlock away (tested). The private GodotStoreKit2 backend
  calls it on StoreKit's refund state.
- For godot-iap, refund detection at startup is **switched off** (`REVOKE_MISSING_ON_SYNC = false`
  in `backend_openiap.gd`). Its docs don't say whether `get_available_purchases()` returns every owned
  non-consumable (StoreKit "current entitlements") or only unfinished transactions. If it's the
  latter, turning revocation on would take PIXEL POLO + away from paying players. To enable it:
  1. In the sandbox, buy `pro_unlock`, relaunch, and confirm it appears in
     `get_available_purchases()` on every launch.
  2. Refund it (Xcode StoreKit testing or a sandbox refund request) and confirm it disappears.
  3. Then set `REVOKE_MISSING_ON_SYNC = true`.
- Refunded **consumables** are not clawed back. Apple doesn't require it, and the coins may
  already be spent.

## Entitlements and save editing

On iOS, `store.cfg` lives in the app's sandbox, which players can't edit on a non-jailbroken phone.
`user_data/accessible_from_files_app` and iTunes sharing stay off. One-time unlocks are re-confirmed
by the App Store at every launch. Full server-side receipt validation would need a server
(App Store Server API) and isn't built. That's a reasonable trade-off for a single-player game.

## Testing (sandbox / TestFlight)

1. Create a Sandbox Apple Account (Users and Access > Sandbox).
2. In a TestFlight or debug build, buy each product once, and check the Polo Points and toast.
3. Cancel a purchase: no message, no coins.
4. Enable Ask to Buy on a sandbox child account (or use Xcode's StoreKit test "Interrupted
   purchase"): pending, then approve, and it arrives once.
5. Force-quit right after the payment sheet succeeds, relaunch: paid once.
6. Delete the app, reinstall, then RESTORE PURCHASES: both unlocks return, coins don't.
