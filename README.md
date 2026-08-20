# Ansible CIS Hardening on AWS

![Terraform](https://img.shields.io/badge/Terraform-844FBA?logo=terraform&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-EE0000?logo=ansible&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-FF9900?logo=amazonwebservices&logoColor=white)
![OpenSCAP](https://img.shields.io/badge/OpenSCAP-CIS_Level_2-2EC4B6)
![NIST](https://img.shields.io/badge/NIST-SP_800--53-0A66C2)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-OIDC-2088FF?logo=githubactions&logoColor=white)

Automated compliance enforcement with evidence. Terraform provisions Ubuntu 24.04 targets on AWS, an Ansible role enforces a CIS benchmark subset, and OpenSCAP scans before and after hardening prove the compliance delta. Every hardening task is mapped to NIST SP 800-53 controls, and the whole loop runs from GitHub Actions with OIDC (no static cloud keys).

The workflow models how ATO evidence collection works in practice: establish a scanned baseline, enforce configuration as code, re-scan, and archive machine-readable plus human-readable results as artifacts.

## Architecture

<img width="1113" height="601" alt="architecture" src="https://github.com/user-attachments/assets/477cd560-d557-4cee-b87e-3472d0cb1401" />


Flow: Terraform builds a VPC, a public subnet, an SSH security group scoped to a single /32, an SSM-enabled instance profile, and two EC2 targets tagged `Role=cis_target`. The `amazon.aws.aws_ec2` dynamic inventory plugin discovers targets by tag, so there is no static hosts file. Ansible runs a baseline OpenSCAP scan, applies the `cis_hardening` role, re-scans, and fetches both scans back as evidence. A Python script diffs the two XCCDF result sets into a markdown compliance delta.

## Control mapping

Scan profile: **CIS Ubuntu Linux 24.04 LTS Benchmark for Level 2 - Server** (`xccdf_org.ssgproject.content_profile_cis_level2_server`) from [ComplianceAsCode/content](https://github.com/ComplianceAsCode/content) v0.1.81, sha256 pinned in the scan playbook. Level 2 is used because the CIS Ubuntu benchmark places auditd controls at Level 2; Level 2 is a superset of Level 1.

NIST SP 800-53 references below were extracted directly from the v0.1.81 datastream's per-rule reference metadata, not assigned by hand. Rows marked `project-assigned` cover tasks where the upstream content carries no 800-53 reference; those mappings are mine and are called out as such.

| Hardening area | Role task file | SSG rules in scan profile | NIST SP 800-53 |
| --- | --- | --- | --- |
| SSH: root login disabled | `tasks/ssh.yml` | `sshd_disable_root_login` | AC-6(2), AC-17(a), CM-6(a), CM-7, IA-2, IA-2(5) |
| SSH: empty passwords rejected | `tasks/ssh.yml` | `sshd_disable_empty_passwords` | AC-17(a), CM-6(a), CM-7 |
| SSH: session timeout | `tasks/ssh.yml` | `sshd_set_idle_timeout`, `sshd_set_keepalive` | AC-2(5), AC-12, AC-17(a), CM-6(a), SC-10 |
| SSH: auth attempt limit | `tasks/ssh.yml` | `sshd_set_max_auth_tries` | AC-7 (project-assigned) |
| Password quality (pwquality) | `tasks/password_policy.yml` | `package_pam_pwquality_installed`, `accounts_password_pam_pwquality_enabled`, `accounts_password_pam_minlen`, `accounts_password_pam_minclass` | IA-5(c), IA-5(1)(a), IA-5(4), CM-6(a) |
| Password aging (login.defs) | `tasks/password_policy.yml` | `accounts_maximum_age_login_defs`, `accounts_password_warn_age_login_defs` | IA-5(f), IA-5(1)(d), CM-6(a) |
| Break-glass account with vaulted credential | `tasks/accounts.yml` | n/a | AC-2, IA-5(7) (project-assigned) |
| Audit daemon installed and running | `tasks/auditd.yml` | `package_audit_installed`, `service_auditd_enabled` | AU-2, AU-3, AU-12, AU-14, AC-2(g), AC-6(9), CM-6(a) |
| Audit rules: identity changes | `tasks/auditd.yml` | `audit_rules_usergroup_modification_passwd`, `_group`, `_shadow` | AC-2(4), AC-6(9), AU-2(d), AU-12(c), CM-6(a) |
| Audit rules: time, session, sudoers scope | `tasks/auditd.yml` | `audit_rules_time_settimeofday`, `audit_rules_session_events`, `audit_rules_sysadmin_actions` | AU-2(d), AU-12(c), AC-2(7)(b), AC-6(9), CM-6(a) |
| Audit log retention | `tasks/auditd.yml` | `auditd_data_retention_max_log_file`, `auditd_data_retention_max_log_file_action` | AU-5, AU-11, CM-6(a) |
| Host firewall (ufw) | `tasks/firewall.yml` | `package_ufw_installed`, `service_ufw_enabled`, `set_ufw_default_rule` | SC-7(12), CM-7 (project-assigned) |
| Patching and unattended upgrades | `tasks/patching.yml` | n/a | SI-2 (project-assigned) |

The same datastream also ships a Canonical Ubuntu 24.04 STIG V1R1 profile (`xccdf_org.ssgproject.content_profile_stig`). Swapping one variable (`scan_profile`) in `ansible/playbooks/scan.yml` retargets the entire pipeline at the STIG instead of CIS.

## Repository layout

```
.
├── terraform/                  VPC, security group, IAM/SSM profile, 2x EC2 targets
├── ansible/
│   ├── ansible.cfg
│   ├── requirements.yml        amazon.aws, community.general
│   ├── inventory/aws_ec2.yml   dynamic inventory, tag filtered
│   ├── group_vars/all/         vars.yml + vault.yml (Ansible Vault encrypted)
│   ├── playbooks/harden.yml    applies the role
│   ├── playbooks/scan.yml      OpenSCAP eval + evidence fetch
│   └── roles/cis_hardening/    SSH, passwords, accounts, auditd, ufw, patching
├── scans/results/              baseline/hardened reports and compliance-delta.md
├── scripts/compliance_delta.py XCCDF result differ
├── diagrams/architecture.drawio
└── .github/workflows/compliance.yml
```

## Prerequisites

Terraform >= 1.6, Ansible >= 2.15 (`pip install "ansible>=9" boto3 botocore`), AWS credentials with EC2/VPC/IAM permissions, and `unzip` on the control node. Estimated cost: two t3.micro instances for an afternoon is a few cents; the pipeline defaults to destroying everything when finished.

## Runbook

### Linux and macOS

1. Generate a lab key pair:

   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/cis_lab -N ""
   ```

2. Provision the targets:

   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars   # set allowed_ssh_cidr to your IP /32
   terraform init && terraform apply
   ```

3. Install Ansible dependencies and create the vaulted secret:

   ```bash
   cd ../ansible
   ansible-galaxy collection install -r requirements.yml
   cp group_vars/all/vault.yml.example group_vars/all/vault.yml
   # paste the output of: openssl passwd -6 'YourBreakGlassPassword'
   ansible-vault encrypt group_vars/all/vault.yml
   ```

   Once `vault.yml` is encrypted, add `--ask-vault-pass` to every `ansible-playbook` run, or point `ANSIBLE_VAULT_PASSWORD_FILE` at a password file.

4. Confirm the dynamic inventory sees the targets:

   ```bash
   ansible-inventory --graph
   # expect: @role_cis_target with cis-lab-0 and cis-lab-1
   ```

5. Baseline scan, harden, re-scan:

   ```bash
   ansible-playbook playbooks/scan.yml -e phase=baseline --ask-vault-pass
   ansible-playbook playbooks/harden.yml --ask-vault-pass
   ansible-playbook playbooks/scan.yml -e phase=hardened --ask-vault-pass
   ```

6. Generate the compliance delta:

   ```bash
   cd ..
   python3 scripts/compliance_delta.py scans/results -o scans/results/compliance-delta.md
   ```

7. Verify idempotence (a second hardening run should report zero changes), then tear down:

   ```bash
   ansible-playbook ansible/playbooks/harden.yml --ask-vault-pass
   cd terraform && terraform destroy
   ```

### Windows (PowerShell + WSL2)

ansible-core does not support Windows as a control node, so the Ansible commands below run inside WSL2 Ubuntu while Terraform, the key handoff, and the delta script stay in PowerShell. Git Bash is not a substitute: it provides bash syntax, not a POSIX runtime, so Ansible cannot install there either. If you prefer working in bash end to end, clone the repo inside the WSL filesystem (under `~`, not `/mnt/c`) and follow the Linux runbook verbatim instead. Every `ansible-*` command below carries `ANSIBLE_CONFIG=ansible.cfg` because WSL mounts Windows drives world writable and Ansible refuses to auto-load `ansible.cfg` from world-writable directories. `wsl` inherits the current PowerShell directory, so run each block from the directory shown.

1. One-time setup:

   ```powershell
   winget install Hashicorp.Terraform
   winget install Python.Python.3.12
   wsl --install -d Ubuntu
   wsl -d Ubuntu -- bash -c "sudo apt update && sudo apt install -y ansible python3-boto3 unzip"
   ```

2. Generate the lab key pair inside WSL (the private key must live on the Linux side to keep 0600 permissions), then export the public half for Terraform:

   ```powershell
   wsl -d Ubuntu -- bash -c "ssh-keygen -t ed25519 -f ~/.ssh/cis_lab -N ''"
   New-Item -ItemType Directory -Force "$env:USERPROFILE\.ssh" | Out-Null
   wsl -d Ubuntu -- bash -c "cat ~/.ssh/cis_lab.pub" | Set-Content -Encoding ascii "$env:USERPROFILE\.ssh\cis_lab.pub"
   ```

3. Authenticate to AWS in PowerShell as usual, then share the session with WSL so the dynamic inventory sees the same credentials:

   ```powershell
   $env:WSLENV = "AWS_ACCESS_KEY_ID:AWS_SECRET_ACCESS_KEY:AWS_SESSION_TOKEN:AWS_DEFAULT_REGION"
   ```

   If you use `~/.aws` credential files instead of environment variables, copy them into the WSL home as well.

4. Provision the targets:

   ```powershell
   cd terraform
   Copy-Item terraform.tfvars.example terraform.tfvars
   (Invoke-RestMethod https://checkip.amazonaws.com).Trim()   # set allowed_ssh_cidr to this IP /32
   terraform init
   terraform apply
   ```

5. Install collections and create the vaulted secret:

   ```powershell
   cd ..\ansible
   wsl -d Ubuntu -- bash -c "ansible-galaxy collection install -r requirements.yml"
   Copy-Item group_vars\all\vault.yml.example group_vars\all\vault.yml
   wsl -d Ubuntu -- bash -c "openssl passwd -6 'YourBreakGlassPassword'"
   notepad group_vars\all\vault.yml   # paste the hash, save, close
   wsl -d Ubuntu -- bash -c "ANSIBLE_CONFIG=ansible.cfg ansible-vault encrypt group_vars/all/vault.yml"
   ```

6. Confirm the dynamic inventory, then baseline scan, harden, re-scan:

   ```powershell
   wsl -d Ubuntu -- bash -c "ANSIBLE_CONFIG=ansible.cfg ansible-inventory --graph"
   wsl -d Ubuntu -- bash -c "ANSIBLE_CONFIG=ansible.cfg ansible-playbook playbooks/scan.yml -e phase=baseline --ask-vault-pass"
   wsl -d Ubuntu -- bash -c "ANSIBLE_CONFIG=ansible.cfg ansible-playbook playbooks/harden.yml --ask-vault-pass"
   wsl -d Ubuntu -- bash -c "ANSIBLE_CONFIG=ansible.cfg ansible-playbook playbooks/scan.yml -e phase=hardened --ask-vault-pass"
   ```

7. Generate the delta, verify idempotence (the second hardening run should report zero changes), tear down:

   ```powershell
   cd ..
   python scripts\compliance_delta.py scans\results -o scans\results\compliance-delta.md
   wsl -d Ubuntu -- bash -c "ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook ansible/playbooks/harden.yml --ask-vault-pass"
   cd terraform
   terraform destroy
   ```

## Evidence

`scans/results/` holds, per host, a baseline HTML report, a hardened HTML report, and `compliance-delta.md` summarizing result counts and every rule that flipped from fail to pass. Machine-readable XCCDF results XML is generated alongside but excluded from version control by size; the CI pipeline uploads all of it as a build artifact.

<!-- After the first full run: add a screenshot of the baseline vs hardened
     report headers and paste the delta summary table here. -->

## CI/CD

`.github/workflows/compliance.yml` runs two jobs:

- **lint** on every push and pull request: `terraform fmt` and `validate`, `ansible-playbook --syntax-check`, and `ansible-lint`.
- **harden-and-scan** on manual `workflow_dispatch`: authenticates to AWS through GitHub's OIDC provider (no long-lived keys), discovers its own egress IP and applies Terraform with SSH scoped to that runner /32, waits for the targets, then runs baseline scan, hardening, re-scan, and delta generation, and uploads everything in `scans/results/` as a `compliance-evidence` artifact. Teardown runs in an `always()` step so a failed run does not orphan instances; set the `teardown` input to false to keep the lab up for inspection.

Required repository secrets: `AWS_ROLE_ARN` (OIDC trust to this repo), `SSH_PRIVATE_KEY`, `SSH_PUBLIC_KEY`, `ANSIBLE_VAULT_PASSWORD`.

## Design notes

- **Behavioral verification over configuration reading.** The claim is not "the role ran," it is "an independent scanner confirms the state changed." Baseline and hardened scans come from the same pinned content version so the delta is apples to apples.
- **Pinned, checksummed content.** The scan playbook downloads ComplianceAsCode v0.1.81 with a sha256 checksum, extracts a single datastream on the control node, and copies it to targets. Scans are reproducible and the supply chain is verifiable.
- **Secrets discipline.** The one secret in this lab (a break-glass local admin credential) exists only as a SHA-512 crypt hash inside an Ansible Vault encrypted file. The role defaults to a locked account if the vault is absent, and the task that consumes it is `no_log`. SSH password authentication stays disabled, so the credential is useful only via console or SSM.
- **Least exposure.** SSH ingress is a single /32 (operator IP locally, runner IP in CI), IMDSv2 is required, root volumes are encrypted, and instances carry an SSM profile as a break-glass path if a firewall change ever cuts off SSH.
- **Canonical's own CIS tooling (USG) requires an Ubuntu Pro subscription.** This lab deliberately uses the open ComplianceAsCode content so the whole pipeline is reproducible by anyone.

## Scope and backlog

This role enforces a deliberate subset, not full benchmark coverage; the hardened scan will still show open findings, and that is the point of publishing the delta rather than claiming a score. Reasonable next increments: pam_faillock lockout policy, GRUB password and `audit=1` boot parameter, AIDE file integrity monitoring, journald forwarding, and remediation coverage expansion driven by the highest-count fail categories in the hardened report.
