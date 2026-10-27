# Controller address recovery

Approved design, revised by the user: keep controller IP addresses only in a shared runtime address service. A hub stores its hostname and credentials; ReadyWateringHubAccess contains a hostname, not an IP. Older persisted IP fields are ignored without destructive migration.

ControllerAddressService has one required MdnsControllerResolver dependency and a hostname-to-IP cache in memory. It neither accesses application state nor persists addresses. No parallel-discovery coordination is needed. A fresh service must resolve through mDNS; there is no persisted IP fallback.

All HTTP API methods accept a hostname. The common send path obtains the cached address (resolving on cache miss), sends the request, and on socket failure or timeout refreshes via mDNS and retries once. Retry applies to GET, POST and PUT, even if the resolved address is unchanged. Method, path, token and body are preserved. The user explicitly authorized retries of commands despite the possibility of duplicate execution after a lost response.

HTTP, TLS and parsing errors do not trigger recovery. A non-200 response with an incomplete body stays an HTTP error. Technical failures are recorded in diagnostics; API exceptions do not carry user messages and screens retain their generic operation-failure messages.

New service dependencies are required constructor parameters. Startup does not resolve addresses separately; its settings read uses the HTTP client's normal resolution path. BLE may display the address read during onboarding but never stores it on the hub.

Alternatives rejected: persistent IP on the hub with state/storage updates; coordinated parallel discovery; resolving every healthy request. Chosen: small in-memory address cache and one centralized retry.
