# Reifnir AWS Organization Build-Out Plan

Target architecture: Control Tower landing zone with Reifnir-Root reduced to billing and Control Tower operations only. Every operational power delegated to exactly one member account, with no member account holding two powers that combine into org-admin capability.

## Account and OU layout

| OU | Account | Role / delegated administration |
|---|---|---|
| — (management) | Reifnir-Root | Billing, Control Tower landing zone operations only |
| Security OU (foundational) | Reifnir-Audit | Delegated admin: GuardDuty, Security Hub, IAM Access Analyzer (detective only) |
| Security OU (foundational) | Reifnir-Log-Archive | Immutable log storage; no delegated admin |
| Governance OU | Reifnir-Governance | Organizations delegated admin: custom SCPs and RCPs only |
| Infrastructure OU | Reifnir-Aggregator | Delegated admin: AWS Config aggregator, IPAM, IAM Identity Center |
| Infrastructure OU | Reifnir-Vending | Account Factory provisioning via shared Service Catalog portfolio |
| Workloads OU | Reifnir-Prod | Production workloads; no delegated admin |
| Workloads OU | Reifnir-Dev | Dev/staging workloads; no delegated admin |

Notes:

- The Security OU is Control Tower's foundational OU. It holds only the two shared accounts — Account Factory cannot provision into it, which is why Governance gets its own OU.
- Separation of powers: detection (Audit) cannot alter policy; policy (Governance) cannot grant identity; identity (Aggregator) cannot loosen guardrails; vending (Vending) can only create enrolled, governed accounts.
- SCPs/RCPs never bind the management account. Root is protected only by root-user lockdown and near-zero use.

## Tasks

### 1. Harden the root users

- [ ] Add a hardware MFA key to Reifnir-Root's root user; stop using it afterward.
- [ ] Enable centralized root access in IAM (from the management account) so member-account root credentials are removed entirely.

### 2. Create and register the OUs

- [ ] In Control Tower from Root, create: Governance OU, Infrastructure OU (if not already present), Workloads OU.
- [ ] Register each OU so the Control Tower baseline applies.

### 3. Enable controls per OU

- [ ] Apply the strongly-recommended control set to Governance, Infrastructure, and Workloads OUs.
- [ ] Apply the tightest posture to the Governance OU (most dangerous account).
- [ ] Review the Security OU deliberately — it carries mandatory controls by default; decide whether to add electives.

### 4. Provision remaining accounts (last Account Factory run from Root)

- [ ] Reifnir-Governance → Governance OU
- [ ] Reifnir-Vending → Infrastructure OU
- [ ] Reifnir-Prod → Workloads OU (if not yet created)
- [ ] Reifnir-Dev → Workloads OU (if not yet created)

### 5. Set up the Account Factory portfolio share

- [ ] In Root: create a Service Catalog portfolio containing the Account Factory product.
- [ ] Attach a tightly scoped launch constraint role.
- [ ] Share the portfolio to Reifnir-Vending.
- [ ] In Vending: import the share and grant the Identity Center principal access.
- [ ] Scope Vending's permission set to Service Catalog actions only.
- [ ] Note: provisioning must run in the Control Tower home region; re-check the shared product version after every landing zone update.

### 6. Delegate Identity Center to Reifnir-Aggregator

- [ ] Register Aggregator as the IAM Identity Center delegated administrator.
- [ ] Limitation to remember: permission sets provisioned into Root itself must still be managed from Root.

### 7. Confirm Config delegation to Aggregator

- [ ] Verify the delegated admin registration for AWS Config.
- [ ] Confirm the org-wide aggregator is collecting from all accounts (Control Tower may have wired part of this at setup).

### 8. Enable IPAM with Aggregator as delegated admin

- [ ] Check whether the Free tier suffices before enabling Advanced (Advanced bills per active IP per hour).
- [ ] Register Aggregator as IPAM delegated administrator.
- [ ] Create the top-level pool and regional pools.
- [ ] RAM-share the pools to Prod and Dev.

### 9. Delegate the detective suite to Reifnir-Audit

- [ ] GuardDuty — delegated admin with auto-enable on.
- [ ] Security Hub — delegated admin with auto-enable on.
- [ ] IAM Access Analyzer — delegated admin.
- [ ] Optional, later: Inspector, Detective, Macie.

### 10. Delegate policy management to Reifnir-Governance

- [ ] Write the Organizations delegation resource policy: allow policy create/update/delete/attach/detach conditioned on policy types `SERVICE_CONTROL_POLICY` and `RESOURCE_CONTROL_POLICY`.
- [ ] Explicitly exclude Control Tower's `aws-guardrails-*` managed policies and `FullAWSAccess` / `RCPFullAWSAccess`.
- [ ] Move all custom SCP/RCP authoring to Governance.

### 11. Shrink Root's remaining surface

- [ ] Create a billing-only Identity Center permission set for invoice/payment tasks.
- [ ] Enable PDF invoice delivery by email.
- [ ] Set AWS Budgets alerts.
- [ ] Optional: register a Cost Optimization Hub delegated admin for cost visibility outside Root.

### 12. Verify end-to-end

- [ ] Provision a throwaway account from Reifnir-Vending.
- [ ] Confirm it lands enrolled: CloudTrail, Config, guardrails, GuardDuty membership all active.
- [ ] Confirm Governance can edit a custom SCP and **cannot** touch a Control Tower guardrail.
- [ ] Close the test account.

## Steady state

Root should only see logins for billing checks and Control Tower landing zone updates, a few times per year, via scoped Identity Center permission sets — never the root user.
