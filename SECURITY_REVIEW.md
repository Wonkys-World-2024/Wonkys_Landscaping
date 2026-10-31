# Security review — v0.29.2 (static hardening; NOT a security certification)

## Added in v0.29.2
- Central server-side shift + optional Qbox job authorization in economic callbacks.
- Shift start now checks the optional configured job.
- Network entity owner must match the requester before vehicle keys are granted. This mitigates key theft but **does not prove that the entity was spawned by this resource**.
- Fleet key permit is tied to its issuance location; heavy rig permit cooldown increased.
- Trailer cargo ledger tracks the resolved entity handle to reduce network-ID reuse issues.
- Rate limits for client-requested state sync events.
- Existing item removal, job durations, proximity, model, capacity and bank payout checks remain.

## Remaining release blockers
1. **Fleet and logging rigs are still client-spawned.** Network owner can be a malicious client. A genuinely secure public fleet needs server-spawned, resource-owned vehicles, a server lease ledger, and server-controlled return/cleanup. This version deliberately does not pretend otherwise.
2. **Trailer cargo is in memory**, so resource restarts, disconnects, vehicle deletion and network-ID reuse require operational testing and potentially persistence/compensation.
3. **Economic operations are not database-transactional.** Resource crashes between inventory operations, cargo updates and bank payouts may cause losses or duplicates.
4. **No live or adversarial multiplayer testing** was performed. Owner migration can affect legitimate vehicle-key grants and needs verification.
5. **Third-party assets** are excluded; users must obtain them independently under their creators' terms.
6. An explicit source licence decision is still required.

Do not advertise this repository as audited, exploit-proof, or ready for public production. See SECURITY.md and RELEASE_CANDIDATE_TEST_PLAN.md.
