# MFA Manual Validation Checklist

Use this checklist when validating Microsoft Entra ID authentication controls that require human interaction or out-of-band approval.

---

## Prerequisites

- [ ] Confirm the test tenant, application, and target environment
- [ ] Confirm `CA002-Require-MFA-All-Users`, `CA003-Require-MFA-Admins`, and `CA006-Require-MFA-Azure-Management` are enabled as intended
- [ ] Confirm the test account is enrolled in the required authentication method
- [ ] Confirm a break-glass account exists and remains excluded through `grp-ca-exclusion-emergency`
- [ ] Record the application URL, user principal name, and expected authentication strength

---

## Standard User MFA Validation

- [ ] Start a fresh browser session and sign in as a standard user
- [ ] Verify the primary credential challenge completes successfully
- [ ] Verify an MFA prompt appears before application access is granted
- [ ] Approve the challenge with the expected method (Authenticator push, number match, FIDO2, or equivalent)
- [ ] Confirm sign-in succeeds only after MFA completion
- [ ] Review Entra sign-in logs and confirm the sign-in shows MFA satisfied

---

## Privileged User MFA Validation

- [ ] Sign in as a privileged user covered by `CA003-Require-MFA-Admins`
- [ ] Verify the sign-in enforces the stronger authentication requirement expected for administrators
- [ ] Confirm access to Azure portal, Azure CLI, or Azure PowerShell also triggers the `CA006-Require-MFA-Azure-Management` control
- [ ] Attempt the same action without completing MFA and verify access is blocked
- [ ] Capture evidence that the privileged session is recorded with the correct Conditional Access policy hits

---

## Risk and Session Validation

- [ ] Validate the risky-user flow for `CA008-Require-MFA-Risky-Users` in a safe test scenario if Identity Protection is licensed
- [ ] Confirm session controls such as sign-in frequency or persistent browser restrictions still apply after MFA completion
- [ ] Verify repeated access from the same session does not bypass configured reauthentication requirements

---

## Break-Glass and Exception Validation

- [ ] Verify the break-glass account can sign in without MFA when used for emergency-only testing
- [ ] Confirm the break-glass sign-in is still monitored and generates the required alerting
- [ ] Verify any documented exclusions are limited to the intended identities, groups, or apps

---

## Evidence and Sign-Off

- [ ] Save screenshots or audit references for each tested scenario
- [ ] Record policy names, user identities, test date, and tester name
- [ ] Document failures, false prompts, or missing prompts for remediation
- [ ] Confirm application owners and identity stakeholders reviewed the results
