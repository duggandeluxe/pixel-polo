# Release verification (the last pass before Submit)

On the exact build you'll submit (from TestFlight, installed fresh):

- [ ] **It's a release build:** Settings shows no DEV button. There's no TEST STORE label or TEST AD
      button. The editor-only test wheel is absent.
- [ ] **Real store:** the shop shows App Store prices (local currency), not "$x.99" placeholders
      forever. "The store isn't available" appears only offline.
- [ ] **Real ads:** a real AdMob ad (not "Test Ad"). Consent shown where required.
- [ ] **Privacy:** Settings > PRIVACY opens the published policy. The same URL is in App Store Connect.
- [ ] **Name and icon:** "Pixel Polo" under the icon. The icon has no transparency or black corners.
- [ ] **Saves:** an existing TestFlight dynasty survives updating to this build (install over the top).
- [ ] **Version numbers:** `short_version` matches App Store Connect; the build number is new.
- [ ] **Metadata matches the build:** IAP descriptions match their amounts, screenshots are from
      this version, and there are no mentions of features that are hidden.
- [ ] **Multiplayer:** nowhere to be found, and the app asked for no Local Network / Bluetooth permission.
- [ ] Run on the Mac: `godot --headless --path game -- --test app_store` passes, and the regression
      suites you normally run (`reset`, `lucky_spin`, `slots`, `economy`, `language`) show no new failures.
