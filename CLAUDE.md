# CLAUDE.md — FUSE VALLEY (Roblox)

You are building **FUSE VALLEY**: Huss Valley-style crossing tag where a tag sticks a ticking bomb on your back. Bump to pass it; the fuse never resets.

## Source of truth (read in this order every session)
1. `docs/ROADMAP.md`: what's next, in order, and who owns it. Then `docs/PROGRESS.md`: what's done, in detail.
2. `docs/design/MASTER_GDD.md`: the rules, numbers, architecture and phases. **The GDD is law.**
3. `docs/design/ASSET_BIBLE.md`: every asset. **§1, "The Quality Bar", applies to everything players see or hear.**
4. `docs/DECISIONS.md`: logged decisions and open questions.

PDFs live in `docs/design/pdf/`. To change the docs, edit `docs/design/src/*.md`, then run `docs/design/build/build.ps1`.

## Golden rules
1. **Build exactly what the GDD specifies, in phase order** (GDD §26). Never add features that aren't in it.
   - If something is ambiguous, pick the simplest option consistent with the pillars (GDD §1.2), log it in `docs/DECISIONS.md`, and continue.
   - Ask the human only for gameplay-rule, monetization or data-schema changes.
2. **Premium or nothing.**
   - No AI-generated art or audio, no toolbox models, no emoji icons, no default-plastic hero assets, no "coming soon" UI.
   - Placeholders are *simpler versions that still pass the Quality Bar*, never lower-quality ones.
3. **No magic numbers:**
   - tunables go in `src/shared/Config/*`
   - asset ids go in `src/shared/Assets.luau`
   - player-facing strings go in `Config.Strings` (from P3)
4. **Server-authoritative.**
   - Tags, passes, booms and rewards come only from server contact checks and timers (GDD §22.2, §24.1).
   - Clients send intents; the server validates them.
5. **One code path for humans and bots:** every gameplay function takes a `Participant`.
6. Every file is `--!strict` and has a header comment with the GDD feature IDs it implements.

## Toolchain
- **Rojo 7.7.1** via Rokit. **The user runs `rojo serve`**; never start one. Agents use `rojo build -o $env:TEMP\tt_chk.rbxlx`.
- **StyLua and Selene:**
  - `stylua src`
  - `selene src` must show 0 errors and 0 warnings
- **`tools/checkrequires.ps1`:** finds `require`s and `Config.<Section>` reads that don't resolve.
- **Roblox Studio MCP** for play-tests: `start_stop_play`, `execute_luau`, `get_console_output`, `screen_capture`.
- **Studio debug bindable:** `ServerScriptService.CG_Debug:Invoke("<cmd>", …)` (AdminService).

## Definition of done for every task
1. `stylua src`, `selene src` (clean), `rojo build`.
2. Studio play-test: 0 errors, 0 unexpected warnings.
3. Tick the task in `docs/PROGRESS.md`.
4. Commit `P<n> <TaskID>: <summary>` **and push**, automatically after every task (no need to ask). **Pull first**: the partner works in the same repo.

## Origin
- Movement, animations (`tools/anim`), ragdoll, plumbing and the temporary Meadow map were transferred from Chase Game (GDD §23).
- **Workspace "ANIM PACK" in the Chase place is a competitor rip: never copy, port or upload it.**
