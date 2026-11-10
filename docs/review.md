Latest pass: see [the current bug and enhancement review](bug-review.md) for the dialog migration and subsequent fixes.

What this change does:
Bulkhead manages one person's Docker engine from a Flutter desktop app. This review traces the socket/API boundary, resource providers, Compose commands, terminal and file operations, update checks, navigation, tables, and existing tests. The accompanying changes fix the issues marked **Fixed** and redesign the shared workspace UI.

Load assumed: one desktop user, potentially hundreds of local containers/images and bursts of Docker events during pulls and stack deployment. This is not a server serving many users.

**Must fix:**

1. **HTTP framing leaks into application data — Fixed** (`lib/core/docker_socket_connection.dart`, `_httpClient`, `request`, `streamResponse`)
   - **What this is:** Every API call and live stream uses this transport.
   - **Problem:** The old streaming transport stripped only HTTP headers. Chunk sizes reached log/JSON readers, HTTP errors looked like successful streams, and ordinary requests waited for socket closure without a timeout.
   - **Fix:** Use Dart's HTTP client over the existing socket connection. It handles response lengths and chunking; requests now have timeouts, streaming errors are surfaced, and clients close in `finally` blocks.
   - **If we skip it:** Chunk boundaries corrupt data, missing resources can look successful, and hung requests can leave loading states stuck.

2. **Log decoding deletes real output and corrupts characters — Fixed** (`lib/core/docker_api_client.dart`, `streamContainerLogs`, `startExec`, `_jsonLines`)
   - **What this is:** Container logs have either plain terminal output or binary frames containing a byte length.
   - **Problem:** Treating those frames as text loses fragmented headers and UTF-8 characters. The old filter deleted legitimate lines such as `42` and `deadbeef`, stripped indentation, and dropped the final line without a newline.
   - **Fix:** Inspect the container's terminal mode, decode frame lengths before text, and use streaming UTF-8 decoding plus `LineSplitter`. JSON streams share one reader and retain final records.
   - **If we skip it:** Logs, exec output, pull progress and engine events can silently lose or alter data.

3. **A file-browser path can execute shell commands — Fixed** (`lib/core/docker_api_client.dart`, `listContainerFiles`; `lib/core/docker_endpoint.dart`, `shellQuote`)
   - **What this is:** Browsing a directory runs `ls` inside the container.
   - **Problem:** Double-quoted paths still expand shell expressions. A directory name containing `$(...)` could run a command when browsed.
   - **Fix:** Quote paths as literal shell arguments and use `ls --` to stop option parsing. External-terminal host arguments use the same quoting helper.
   - **If we skip it:** Browsing a crafted path can change files or run unwanted programs inside the container.

4. **CLI actions can target a different engine — Fixed** (`lib/core/docker_endpoint.dart`; `lib/providers/compose_provider.dart`; container and volume screens)
   - **What this is:** Compose, interactive terminals and file transfers use the Docker CLI rather than the socket API.
   - **Problem:** Changing the socket in Settings did not change CLI operations. They continued using the inherited Docker context, potentially acting on a different engine.
   - **Fix:** Pass the selected endpoint to CLI processes, clear conflicting context/TLS environment overrides, and include an explicit host in external Unix terminal commands. The settings provider now uses the platform's detected default socket.
   - **If we skip it:** Users can stop a stack or copy files on an engine other than the one shown in the UI.

5. **Deploying a new stack overwrites an existing file — Fixed** (`lib/core/compose_cli_client.dart`, `createStack`)
   - **What this is:** The deploy dialog writes a Compose YAML file into a chosen directory.
   - **Problem:** Reusing an existing directory silently replaced its `docker-compose.yml`. A filename containing a parent path could also escape the selected directory.
   - **Fix:** Require a plain filename and exclusively create the new file. Existing files now produce an error instead of being overwritten.
   - **If we skip it:** Deploying a stack can destroy another stack's configuration.

6. **Cleanup reports success after daemon errors — Fixed** (`lib/core/docker_api_client.dart`, `systemPruneAll`; dashboard, image and volume screens)
   - **What this is:** Cleanup removes unused Docker resources in several steps.
   - **Problem:** System prune converted failed responses to empty maps. Image/volume screens also treated provider error maps as successful cleanup with zero deletions.
   - **Fix:** Stop system cleanup on its first failure, identify the failed step and warn that earlier steps may have completed. Show failures in the UI, refresh resource state after partial cleanup, and describe the actual deletion scope in the confirmation.
   - **If we skip it:** Users receive a success message even though cleanup failed or only partly completed.

7. **Pulling a private-registry image changes its reference — Fixed** (`lib/core/docker_api_client.dart`, `pullImage`; image progress dialog)
   - **What this is:** The pull dialog sends an image reference to Docker.
   - **Problem:** Splitting on every colon turned `localhost:5000/team/app:1.2` into the wrong image/tag. Error objects inside successful HTTP streams could also finish with a success message.
   - **Fix:** Pass the complete reference to Docker and surface daemon error objects, including final objects without a newline. Keep the failed status when the stream subsequently ends.
   - **If we skip it:** Registry ports and digests break, and rejected pulls can appear successful.

**Should fix:**

8. **Event bursts multiply refresh work — Fixed** (`lib/providers/events_provider.dart`, `_refresh`)
   - **What this is:** Docker events update resource lists and disk usage.
   - **Problem:** Every event refreshed all five resource groups and storage. A burst of 100 image events could start hundreds of unnecessary API calls and Compose processes, with overlapping results.
   - **Fix:** Group events into 250ms windows, refresh only affected resource groups, and wait for each batch before another batch starts. Keep the existing limit of 50 displayed events.
   - **If we skip it:** Pulling images or deploying stacks can overload the local engine and repeatedly spawn the CLI.

9. **Compose logs leave stderr unread and the process running — Fixed** (`lib/core/compose_cli_client.dart`, `streamServiceLogs`)
   - **What this is:** Compose logs stream stdout and stderr from a child process.
   - **Problem:** The code waited for stdout to finish before reading stderr. A full stderr pipe can block the process, and leaving the view did not kill the log follower.
   - **Fix:** Listen to both streams concurrently, report a nonzero exit code, and cancel subscriptions and kill the process when the consumer leaves.
   - **If we skip it:** Errors can be hidden, logging can stall, and background followers can accumulate.

10. **Update checks outlive their provider and hide failures — Fixed** (`lib/providers/update_provider.dart`; Settings update controls)
    - **What this is:** A delayed startup check calls the GitHub release endpoint.
    - **Problem:** The delayed callback could update disposed state, HTTP clients were never closed, and a rejected HTTP response was shown as “up to date.”
    - **Fix:** Cancel the startup timer on disposal, guard asynchronous state writes, close the client, limit request duration and show a failed check as an error.
    - **If we skip it:** Closing the app during a check can produce late errors, repeated checks leak resources, and users receive misleading update status.

11. **Desktop controls overflow and existing tests miss real failures — Fixed** (`lib/widgets/data_table_shell.dart`, `lib/widgets/page_header.dart`, `lib/main.dart`, `test/`)
    - **What this is:** Fixed-width navigation, page actions, table controls and action columns compete for window space.
    - **Problem:** The container action row and compact Networks/Settings layouts overflowed. Existing socket tests swallowed exceptions and passed even when Docker was absent.
    - **Fix:** Add a compact navigation rail, shared responsive headers, wrapping toolbars, usable scrollable tables, and sufficient action-column width. Add deterministic transport/API/provider tests and exercise all seven destinations in both themes at 800px and 1440px.
    - **If we skip it:** Controls can be clipped, and broken transport behavior can pass the test suite.

12. **Windows named pipes were unsupported — Implemented; native validation pending** (`lib/core/docker_socket_connection.dart`, `_connectSocket`)
    - **What this is:** Docker Desktop on Windows normally exposes a named pipe.
    - **Problem:** The old code tried localhost TCP first and then a Unix socket, neither of which implements Windows named-pipe transport. The first pass removed the silent connection to a different endpoint. The continuation adds direct Windows named-pipe support.
    - **Fix:** Use `WindowsPipeSocket` with cancellable overlapped Win32 I/O through the same HTTP decoder. Three Windows-only tests cover HTTP responses, cancellation and missing pipes; these must run on Windows before claiming platform validation.
    - **If we skip it:** Without the adapter, default Docker Desktop connections remain unavailable. Native behavior is still unverified on this Linux machine.

13. **Multiple Compose configuration files were treated as one filename — Fixed** (`lib/models/compose_stack_model.dart`, `configFiles`; `lib/core/compose_cli_client.dart`)
    - **What this is:** Docker can report several Compose files as a comma-separated `ConfigFiles` string.
    - **Problem:** Passing `/app/compose.yml,/app/override.yml` to one `-f` argument makes Docker look for a nonexistent combined filename. Reading and editing that path also fails.
    - **Fix:** Parse ordered paths and pass one `-f` argument per path for lifecycle, services and logs. The editor now selects one file, protects unsaved edits when switching, and disables saves after failed reads. Single-file stacks retain their existing workflow.
    - **If we skip it:** Stacks created with override files cannot reliably be managed or edited.

14. **Terminal copy history grew without a limit — Fixed** (`lib/features/containers/container_detail_screen.dart`, `_copyTerminalLogs`)
    - **What this is:** The terminal keeps a separate list for Copy Terminal Logs.
    - **Problem:** The visible terminal is bounded, but the copy list retains every stdout/stderr chunk. A long-running chatty session keeps growing in memory.
    - **Fix:** Delete the duplicate copy-history list and copy from xterm’s existing bounded buffer. A regression test feeds 1,000 output lines and checks that old history is discarded. Compose service logs are also capped at 2,000 lines.
    - **If we skip it:** Long terminal sessions can consume increasing amounts of memory.

15. **Some resource actions had no visible error handling — Fixed** (container, network and Compose screen action callbacks)
    - **What this is:** Several buttons await notifier calls that rethrow Docker errors.
    - **Problem:** If Docker rejects a network deletion because it is still in use, the network screen's callback lets the exception escape instead of showing the error. Similar callbacks exist in container and Compose bulk actions.
    - **Fix:** Shared UI handlers now catch operation failures and identify the action and resource. Bulk operations stop on the first failure, report completed counts, and remove only completed selections so unfinished resources remain selected for retry. Image deletion no longer swallows errors.
    - **If we skip it:** Users can see an unchanged screen without a useful explanation or recovery path.

Verification: `flutter analyze` passed. All 32 Linux-compatible tests passed; three native Windows pipe tests were skipped because this environment is Linux. The Linux release bundle built, and the native Linux application launched. Existing user edits to `analysis_options.yaml` and `pubspec.lock` were preserved. The existing transitive `ffi` and `win32` packages were promoted to direct dependencies without changing their resolved versions.

Verdict: run the three native pipe tests on Windows before claiming complete Windows validation. The other review findings have code fixes and regression coverage.

Not checked: macOS/Windows native runs, live destructive Docker operations, release packaging/installers, sustained-load measurements, and pixel-level native visual review. Runtime font fetching and existing specialized editor palettes remain unchanged.

Continuation notes: multi-file editor checks cover 800px and 1440px windows, saving only the selected file, and preventing saves after read failures. Shared action tests cover visible single failures and partial bulk progress. The Windows transport uses the [Win32 named-pipe client API](https://learn.microsoft.com/en-us/windows/win32/ipc/named-pipe-client), with overlapped operations so a stream can be cancelled without blocking the UI thread. HTTP framing remains delegated to Dart's HTTP client.
