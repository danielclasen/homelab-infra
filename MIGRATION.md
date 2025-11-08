# Repository Restructure Migration Guide

## Overview
This repository has been restructured to separate Flux CD configurations from infrastructure-as-code tools.

## New Structure
```
homelab-infra/
├── flux/               # FluxCD configurations (NEW)
│   ├── apps/          # Application deployments
│   ├── clusters/      # Cluster definitions
│   └── infrastructure/# Infrastructure components
├── terraform/         # Terraform for Proxmox/VM management (NEW)
├── talos/            # Talos Linux configurations
├── scripts/          # Helper scripts
└── .github/          # CI/CD and automation
```

## Migration Steps (Zero-Downtime)

### Phase 1: Prepare New Structure ✅ COMPLETED
- [x] Created `flux/` directory
- [x] Copied `apps/`, `clusters/`, `infrastructure/` to `flux/`
- [x] Updated path references in `flux/clusters/homelab/`:
  - `flux-system/gotk-sync.yaml`: `./flux/clusters/homelab`
  - `apps.yaml`: `./flux/apps/homelab`
  - `infrastructure.yaml`: `./flux/infrastructure/controllers` and `./flux/infrastructure/configs`
- [x] Updated `.github/renovate.json5` patterns
- [x] Created `terraform/` directory placeholder

### Phase 2: Commit and Push (NEXT STEPS)
```bash
# Stage all new changes
git add flux/ terraform/ .github/renovate.json5 MIGRATION.md

# Commit the new structure (old dirs still exist)
git commit -m "feat: restructure repo - add flux/ directory with updated paths

- Create flux/ directory containing apps, clusters, and infrastructure
- Update all Flux path references to point to flux/ subdirectories
- Update Renovate patterns for new structure
- Add terraform/ directory for future Proxmox/Talos IaC
- Keep old directories temporarily for zero-downtime migration"

# Push to remote
git push origin main
```

### Phase 3: Update Flux in Cluster
```bash
# Apply the updated flux-system Kustomization
kubectl apply -f flux/clusters/homelab/flux-system/gotk-sync.yaml

# Force reconciliation
flux reconcile source git flux-system --with-source

# Verify all Kustomizations are healthy
flux get kustomizations
```

### Phase 4: Verify Reconciliation
```bash
# Check that all resources reconciled successfully
flux get all

# Verify apps are running
kubectl get pods -A

# Check for any Flux errors
flux logs --all-namespaces
```

### Phase 5: Cleanup Old Directories
Once everything is working (wait at least 24 hours):
```bash
# Remove old directories
git rm -r apps/ clusters/ infrastructure/

# Commit cleanup
git commit -m "chore: remove old directory structure after successful migration"

# Push final cleanup
git push origin main
```

## Rollback Plan
If issues occur, rollback by:
```bash
# Revert to previous commit
git revert HEAD

# Or reset if not pushed
git reset --hard HEAD~1

# Reapply old flux-system
kubectl apply -f clusters/homelab/flux-system/gotk-sync.yaml
flux reconcile source git flux-system --with-source
```

## Files Modified
- `.github/renovate.json5` - Updated path patterns
- `flux/clusters/homelab/flux-system/gotk-sync.yaml` - Updated path
- `flux/clusters/homelab/apps.yaml` - Updated path
- `flux/clusters/homelab/infrastructure.yaml` - Updated paths (2)

## Validation Checklist
- [ ] Git changes committed and pushed
- [ ] Flux reconciled successfully
- [ ] All Kustomizations show "Applied" status
- [ ] All applications are running
- [ ] No error logs in Flux
- [ ] Renovate PRs work with new paths
- [ ] Wait 24-48 hours before cleanup
- [ ] Remove old directories
