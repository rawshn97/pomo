# Pomo Documentation (Diataxis Framework)

Welcome to the comprehensive documentation for Pomo. This documentation follows the [Diataxis framework](https://diataxis.fr/), organizing knowledge into four distinct modes: Tutorials, How-To Guides, Reference, and Explanation.

---

## Documentation Map

```
                  PRACTICAL                    THEORETICAL
          +-----------------------+-----------------------+
          |                       |                       |
          |       TUTORIALS       |      EXPLANATION      |
LEARNING  |   Getting Started     |  Target Timestamp     |
          |   (Clone to Running)  |     Sync Model        |
          |                       |                       |
          +-----------------------+-----------------------+
          |                       |                       |
          |     HOW-TO GUIDES     |       REFERENCE       |
WORKING   |   - Notion Sync       |   - Environment Vars  |
          |   - Cloudflare Worker |   - Scripts & Tooling |
          |   - Release & Deploy  |   - API Endpoints     |
          |   - RGB Webhooks      |                       |
          |                       |                       |
          +-----------------------+-----------------------+
```

---

## 1. Tutorials (Learning-Oriented)

Step-by-step learning paths for getting started with Pomo from scratch:

- **[Getting Started with Pomo](getting-started.md)**: From fresh git clone to running locally on macOS desktop, Android emulator/device, and the Web PWA in Google Chrome.

---

## 2. How-To Guides (Task-Oriented)

Practical guides addressing specific real-world tasks and operational procedures:

- **[How-To: Set Up Notion Sync](how-to/setup-notion-sync.md)**: Connect Pomo to your Notion PARA workspace for Pomodoro Time Logs and 24-hour Hourly Timeline tracking.
- **[How-To: Set Up Cloudflare Edge Sync Worker](how-to/setup-cloudflare-worker.md)**: Deploy your own low-latency Cloudflare Worker and Durable Object WebSocket sync relay.
- **[How-To: Release and Deploy](how-to/release-and-deploy.md)**: Complete guide to compiling signed Android APKs with in-app OTA updates, macOS DMGs, and Vercel web PWA releases.
- **[How-To: Set Up RGB Webhooks for Home Assistant](how-to/setup-webhooks-homeassistant.md)**: Trigger dynamic smart lighting and desk lamp ambient color shifts matching your Pomodoro ring color.

---

## 3. Reference (Information-Oriented)

Technical specifications, schemas, flag definitions, and tooling cheat-sheets:

- **[Reference: Environment Variables & Configuration](reference/environment-variables.md)**: Comprehensive table of Dart defines, Vercel secrets, Cloudflare secrets, Android signing keys, and SharedPreferences storage entries.
- **[Reference: Tooling and Build Scripts](reference/scripts.md)**: Detailed breakdown of all scripts in `scripts/` and the repository root (`setup.sh`, `verify.sh`, `build-web.sh`, `deploy_android_update.sh`, etc.).
- **[Reference: API Endpoints and Payloads](reference/endpoints.md)**: Complete interface contract for Cloudflare Worker WebSocket/REST endpoints, Vercel Notion proxy, and smart home webhook payloads.

---

## 4. Explanation (Understanding-Oriented)

Deep-dive architecture explorations into design decisions and synchronization mechanics:

- **[Explanation: Target Timestamp Sync Model and Session Handover](explanation/target-timestamp-sync-model.md)**: Architectural analysis of why streaming ticks over WebSockets fails, how the Target Timestamp model guarantees zero-drift accuracy, and how omnidirectional device takeover functions.

---

## Additional Architecture & Product Specifications

- **[ARCHITECTURE.md](../ARCHITECTURE.md)**: High-level codebase architecture, component diagrams, state management, and subsystem topology.
- **[SPEC.md](../SPEC.md)**: Product specification index of all shipped features.
- **[AGENTS.md](../AGENTS.md)**: Operating rules and execution constraints for AI agents.
- **[DEPLOYMENT.md](../DEPLOYMENT.md)**: Deployment and release management guide for maintainers.
