# Security — One App At A Time

**Purpose:**
This document explains the security model and best practices for a platform that allows **only one application/cartridge to run at a time**. It covers the threat model, hardware and software controls, design patterns, and an operational checklist to minimize risks when switching or executing a single app instance.

---

## Overview

On systems where a single cartridge or application is present in the CPU address space at any moment, the security goal is to ensure that the active application cannot escalate privileges, persist beyond its authorized lifetime, or access sensitive system resources except through controlled interfaces. The model leverages exclusive memory mapping, verified boot, and strict kernel-mediated services to contain the running app.

---

## Assumptions
- The system has a single physical slot or a logical mapper that exposes exactly one ROM/image to the CPU address space at once.
- A small, trusted firmware or bootloader (the **monitor**) runs before any cartridge/app and mediates app selection, verification, and launching.
- The platform provides a kernel or hypervisor-like layer that offers controlled services (I/O, storage, network) through well-defined APIs.
- Hardware supports basic isolation primitives (memory protection registers, I/O gating, or an MMU) or the platform enforces isolation by fixed bus mapping and controlled peripherals.

---

## Threat Model
**Adversaries:** malicious cartridge images, supply-chain tampering of cartridges, physical access attackers trying to swap or spoof cartridges, and privileged OS components that could be compromised.

**Threat goals:**
- Unauthorized access to system secrets or persistent storage.
- Arbitrary code execution at higher privilege than intended.
- Persistence across cartridge swaps or reboots.
- Tampering with the monitor/bootloader to launch unsigned images.

**Out-of-scope:** sophisticated physical attacks that remove or tamper with the SoC or break hardware root-of-trust protections (e.g., invasive chip attacks).

---

## Security Controls

### 1. Trusted Monitor / Verified Boot
- Use a small immutable monitor in ROM or fused storage. This component must be the *root of trust* — verify the next-stage image (cartridge/app) signature before mapping it into executable address space.
- Sign cartridges/images using asymmetric keys. The monitor checks a cryptographic signature and image manifest (size, entry vector, allowed resources) before launching.
- Maintain a read-only whitelist or a revocation list for supremely high-security deployments.

### 2. Exclusive Memory Mapping
- Only map the cartridge ROM into the CPU’s executable address region after verification. While the cartridge is not active, its ROM lines should be tri-stated or physically disconnected to prevent bus contention and accidental reads.
- When switching apps, ensure the monitor unmaps previous ROM regions, clears caches, and resets peripheral state before mapping the new app.

### 3. Kernel-mediated Services & Least Privilege
- Provide no direct hardware access to the cartridge. Instead expose minimal, privilege-checked services (file I/O, network, timers, audio/video) via synchronous IPC or trapped syscalls routed through the monitor or kernel.
- Restrict service capabilities per image via a manifest (e.g., `can_access_network: false`, `max_memory_pages: 4`). The monitor enforces these constraints at launch.

### 4. Resource Isolation & Cleanup
- On app termination or swap, zero memory regions previously used by the app, flush and invalidate caches, and reset DMA masters and peripherals.
- Revoke any temporary credentials or tokens issued to the app. Rotate ephemeral keys as needed.

### 5. Mapper/Bank-switch Integrity
- If the cartridge uses a mapper (bank switching), validate mapper firmware/configuration. The monitor should treat mapper behavior as part of the image’s contract and verify it where possible.
- Prefer mappers with simple, auditable logic. Complex mapper microcontrollers increase attack surface and should be loaded only if signed/verified.

### 6. Auditing & Logging
- Log app launch metadata (image ID, signature fingerprint, timestamp, requested capabilities) to an immutable event log that is accessible only to the monitor/privileged code.
- If available, store critical log digests in a tamper-evident location (e.g., secure element or write-once region).

### 7. Secure Update Path
- Securely update the monitor/firmware using signed updates with rollback protections and anti-rollback counters.
- Allow cartridge key revocation or certificate updates to handle compromised signing keys.

### 8. Physical Protections
- If physical cartridge swapping is an expected threat, add tamper-evident seals, cartridge authentication tokens, or an HMAC-based challenge/response with a secure element embedded in the cartridge.

---

## Operational Procedures
- **Image Signing:** Use a central signing service and rotate signing keys periodically. Keep the root verification key very small and well-protected.
- **Pre-launch checks:** The monitor should check image metadata: required RAM, requested peripherals, entry address, signature, and allowed lifetime (e.g., ephemeral demo images).
- **Swap protocol:** Implement a strict swap procedure: unmap → drain DMA/peripherals → clear memory/caches → verify next image → map and start.
- **Incident response:** If an image fails verification, refuse to boot and record a forensic artifact. If repeated verification failures occur, enter a recovery mode requiring authenticated maintenance.

---

## Design Patterns & Examples
- **Capability Manifest:** Bundle a small JSON/TOML manifest with each image that lists the minimal capabilities required. The monitor enforces the manifest.
- **Sandboxed Drivers:** Keep device drivers in the monitor or kernel instead of in the cartridge image to reduce attack surface and enforce policy centrally.
- **Ephemeral Tokens:** Issue short-lived tokens for sensitive operations; revoke them on exit/swap.

---

## Checklist Before Deploying
- [ ] Immutable monitor is in place and verified.
- [ ] Cryptographic signing for all cartridge images configured.
- [ ] Image manifests define minimal capabilities and are enforced.
- [ ] Swap/unmap/reset flow implemented and tested (including cache and DMA clearing).
- [ ] Audit logging enabled and tamper evidence considered.
- [ ] Secure update / rollback protections for firmware.
- [ ] Mapper chips or multi-image cartridges verified and limited.
- [ ] Physical anti-tamper protections considered for production hardware.

---

## Conclusion
Running only one app/cartridge at a time significantly simplifies the security model by reducing concurrent resource-sharing risks. However, strong protections are still required around verification, mapping/unmapping, peripheral access, and cleanup to prevent privilege escalation, data leakage, or persistence. A small, auditable monitor combined with signed images and strict resource controls provides a robust foundation.

