What this change does:
This pass reviews the current Docker API, resource providers, Compose integration, update checks, terminal lifecycle, file browsing, and shared UI. It replaces every app-owned SnackBar with message or progress dialogs and fixes the confirmed bugs below. It does not claim that untested platforms or every possible Docker image are bug-free.

Load assumed: one desktop user, hundreds of resources, bursts of engine events, long log sessions, and overlapping refreshes or terminal reconnects. No live Docker resources were deleted during verification.

**Must fix:**

1. **Removing a container also removed anonymous volumes — Fixed** (`lib/core/docker_api_client.dart`, `removeContainer`)
   - **What this is:** Container deletion passed Docker's `v=1` option.
   - **Problem:** Deleting a database container could also delete its anonymous persistent volume without a separate volume action.
   - **Fix:** Use `v=0` and explain the remaining writable-container-data loss in the confirmation. Volume deletion remains an explicit action.
   - **If we skip it:** Container cleanup can destroy persisted application data.

2. **Running an image reported success before Docker replied — Fixed** (`lib/features/images/images_screen.dart`)
   - **What this is:** The Run Container from Image button starts a container asynchronously.
   - **Problem:** Its success notification appeared immediately, even when creation failed. Names also repeated every ten seconds.
   - **Fix:** Await creation inside a progress dialog, show success only after completion, and use the full creation timestamp. If creation succeeds but starting fails, the API error now identifies the created container.
   - **If we skip it:** Users believe a missing or stopped container is running and cannot clearly identify partial success.

3. **Old refresh responses replaced newer resource state — Fixed** (`lib/providers/{containers,images,volumes,networks,compose}_provider.dart`)
   - **What this is:** Manual refreshes, actions and engine events can request the same list concurrently.
   - **Problem:** A slower request started before a deletion could complete last and restore an already removed resource in the UI.
   - **Fix:** Apply only the newest refresh generation, including error responses. Connection checks use the same protection against stale pings.
   - **If we skip it:** Resource lists and connection indicators can move backward after successful actions.

4. **Engine recovery left the UI disconnected — Fixed** (`lib/providers/events_provider.dart`, `connection_status_provider.dart`)
   - **What this is:** The event listener retries after its socket closes.
   - **Problem:** Reopening the event stream did not recheck the connection provider, so resource providers could remain disconnected after Docker restarted.
   - **Fix:** Mark failed streams offline, recheck the daemon before resubscribing, and recreate resource state after recovery. Successful pings no longer unnecessarily rebuild already connected providers.
   - **If we skip it:** The engine can recover while the workspace continues to report that it is unavailable.

5. **Update checks could not reliably retry or share an in-flight request — Fixed** (`lib/providers/update_provider.dart`)
   - **What this is:** Startup and manual update checks share one notifier.
   - **Problem:** Reading `AsyncError.value` rethrew the previous failure. Clicking Check while a startup check was running returned immediately, and manual checks could leave a duplicate startup timer scheduled.
   - **Fix:** Read `valueOrNull`, cancel the startup timer when checking, and return the current check future to concurrent callers.
   - **If we skip it:** Failed checks can keep failing before making a request, or a progress dialog can finish before the real check does.

6. **Release versions were compared incorrectly — Fixed** (`lib/core/app_version.dart`, `isNewer`)
   - **What this is:** The update checker compares published and installed versions.
   - **Problem:** Parsing `1.0.0-rc.2` as integers lost prerelease ordering and confused stable releases with release candidates.
   - **Fix:** Compare numeric version parts, prerelease identifiers and stable-release precedence; ignore build metadata. Remove only a leading version prefix from tags.
   - **If we skip it:** Updates can be missed or offered in the wrong order.

7. **Downloads could select another operating system's package — Fixed** (`lib/models/update_model.dart`)
   - **What this is:** The update dialog selects a release asset.
   - **Problem:** If a Windows asset was absent, the old fallback selected the release's first asset, possibly a macOS disk image.
   - **Fix:** Return no asset when none match and use the release page instead. Prefer the portable Linux archive and macOS disk image when available.
   - **If we skip it:** Users can download an installer that cannot run on their system.

8. **File browsing corrupted valid names and hid command failures — Fixed** (`lib/core/docker_api_client.dart`, `listContainerFiles`, `execCommand`)
   - **What this is:** The file browser reads container directory entries through an exec command.
   - **Problem:** Splitting `ls` output on spaces changed `two  spaces` into `two spaces`; embedded newlines also broke records. A failed `ls` could appear to be an empty directory.
   - **Fix:** Use literal shell arguments and NUL-separated records, disable terminal rewriting for commands, preserve raw UTF-8 output and check the exec exit status. A Linux integration test checks spaces, newlines, Unicode, hidden files and shell characters without contacting Docker.
   - **If we skip it:** Valid files become impossible to browse or copy, and permission errors look like empty folders.

**Should fix:**

9. **Charts stopped advancing after thirty samples — Fixed** (`lib/features/containers/container_detail_screen.dart`)
   - **What this is:** CPU and memory charts retain thirty points.
   - **Problem:** Using the retained list length as the next x-coordinate produced the same coordinate after the history reached its limit.
   - **Fix:** Increment the last retained coordinate. The screen test sends sixty samples and verifies both charts retain coordinates 30 through 59.
   - **If we skip it:** Long-running charts collapse new samples onto the same position.

10. **Storage totals counted shared layers repeatedly — Fixed** (`lib/providers/containers_provider.dart`, `parseSystemDiskUsage`)
    - **What this is:** The dashboard totals image, container and volume disk usage.
    - **Problem:** Summing every image's full size counted shared image layers more than once. Unknown negative sizes reduced totals, and failures were silently reported as zero usage.
    - **Fix:** Prefer Docker's shared-layer total, ignore unknown negative sizes, preserve load errors and expose a retry control. Valid zero values no longer fall back to an old estimate.
    - **If we skip it:** Storage usage is inflated, reduced incorrectly or falsely displayed as empty.

11. **Malformed Compose output appeared to be an empty project list — Fixed** (`lib/core/compose_cli_client.dart`)
    - **What this is:** Compose versions produce either JSON arrays or one JSON object per line.
    - **Problem:** Broad exception handlers silently dropped invalid lines or returned an empty list after a parser failure.
    - **Fix:** Share strict parsing for both supported formats and let errors reach the resource error UI.
    - **If we skip it:** A broken CLI response looks like all stacks or services disappeared.

12. **Failed resource loads and small empty tables were misleading or clipped — Fixed** (`lib/widgets/data_table_shell.dart`, resource screens)
    - **What this is:** Resource tables displayed empty states even when loading failed.
    - **Problem:** Permission or API errors looked like zero resources. Adding recovery details also exposed an empty-state overflow in shorter windows.
    - **Fix:** Show the actual error with Retry, retain available rows and let the empty-state content scroll when space is limited. Reject empty connection endpoints before replacing a working one.
    - **If we skip it:** Users cannot distinguish missing data from a failed connection or reach all recovery content.

13. **Live logs stopped following capped or mutable lists — Fixed** (`lib/widgets/log_viewer.dart`)
    - **What this is:** The log view follows appended output when auto-scroll is enabled.
    - **Problem:** Comparing old and new list lengths missed in-place updates and histories that remove one line before adding another. Fixed toolbar widths also overflowed narrow panels.
    - **Fix:** Follow updates while auto-scroll is enabled and wrap toolbar controls. A test updates a mutable, capped history in a 360px panel and checks the final scroll position.
    - **If we skip it:** New output goes off-screen and some log controls become inaccessible.

14. **Terminal reconnects could leave the wrong process alive — Fixed** (`lib/core/terminal_session.dart`, container terminal view)
    - **What this is:** Starting a native terminal process completes asynchronously.
    - **Problem:** Leaving the view before startup completed could orphan the new process. Overlapping reconnects could replace a newer session with an older one.
    - **Fix:** Give each startup an ownership generation, kill stale completions and dispose the active process. Cancel old output subscriptions, ignore stale callbacks and decode UTF-8 incrementally. Tests complete starts in the wrong order and after disposal.
    - **If we skip it:** Background shells can accumulate and terminal output can arrive from the wrong session.

15. **Some feedback and release actions could be clipped or silently fail — Fixed** (`lib/widgets/message_dialog.dart`, `update_dialog.dart`, terminal launch callbacks)
    - **What this is:** Operations report completion, errors and download actions through UI feedback.
    - **Problem:** Transient notifications were easy to miss; long release asset names overflowed fixed action rows, and failed browser or external-terminal launches had no explanation.
    - **Fix:** Use shared scrollable message dialogs and owned progress routes, wrap release actions, scroll short-window release content and report launch failures. Progress cleanup removes only its own route.
    - **If we skip it:** Users miss operation results or cannot understand why an action did nothing.

Requested notification change: all app-owned SnackBar calls and theme configuration are removed. A source regression test enforces that the app does not reintroduce SnackBar or ScaffoldMessenger feedback. Existing destructive confirmation dialogs remain in use.

Needed enhancements, not implemented in this pass:

| Priority | Enhancement | Concrete need | Smallest useful next step |
| --- | --- | --- | --- |
| High | Persistent workspace settings | Socket and theme StateProviders reset after restarting the app. | Store settings in the platform's application-support directory and load them before connecting. |
| High | Remember inactive Compose projects | After `down` removes all containers, tracked configuration paths exist only in the current notifier. Restarting the app loses those entries. | Persist the ordered project file paths independently of connection/notifier recreation and provide an existing-project import action. |
| Medium | Offline font assets | Startup still allows runtime Google Fonts fetching, so typography depends on network/cache availability. | Bundle the existing font families and licenses and disable runtime fetching. |
| Medium | Broader container compatibility and performance | The new file listing requires `sh` and `stat -c` in the container and reads metadata per entry. | Validate Alpine/BusyBox alongside GNU utilities and measure very large directories before choosing a batched protocol. |

Validation: `flutter analyze` passed. All 55 Linux-compatible tests passed; three native Windows pipe tests were skipped on Linux. The Linux release build passed. The source check confirms no app-owned SnackBar or ScaffoldMessenger call sites remain.

Verdict: Ship for the tested Linux flows. Complete native Windows/macOS and live Docker validation before treating cross-platform behavior as verified.

Not checked: native Windows/macOS execution, live destructive Docker operations, real Docker exec streams for every image, sustained-load measurements, installer packaging, or cold-cache offline font loading. The three native Windows pipe tests remain platform-gated on Linux. No review can prove the absence of every bug.
