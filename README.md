# Homelab Infrastructure

This repository contains Kubernetes configurations and infrastructure definitions for my homelab setup. Secrets are managed using [SOPS](https://github.com/getsops/sops).

## Git Hooks Setup

This repository includes a pre-commit hook to prevent accidentally committing unencrypted SOPS secrets. To enable this hook, you need to link it to your local `.git/hooks` directory.

From the root of the repository, run the following command:

```bash
ln -sf .hooks/pre-commit .git/hooks/pre-commit
```

**Prerequisites for the hook:**

*   **`yq`**: The pre-commit hook script requires `yq` (version 4+, by Mike Farah) to parse YAML files. Please ensure it's installed and available in your PATH. You can find installation instructions [here](https://github.com/mikefarah/yq#install).

This will ensure that the hook checks for unencrypted secrets before you make a commit.

---

## Kubernetes Cluster Documentation

This section provides an overview of the Kubernetes cluster setup managed by this repository.

### Cluster Overview

*   **Kubernetes Distribution**: Talos OS v1.10.0
*   **Version**: Kubernetes v1.33.0

### GitOps & Configuration Management

*   **Tooling**: FluxCD.
*   **Repository Structure**: This `homelab-infra` repository is my central place for managing Kubernetes cluster configurations and all application deployments using a GitOps approach. 
    *   `flux/` - FluxCD manifests for clusters, infrastructure controllers, and application deployments
    *   `talos/` - Talos Linux node configurations managed with Talhelper
    *   `terraform/` - Terraform infrastructure-as-code for Proxmox VMs and cluster nodes
    *   Reusable Helm charts might be sourced from other repositories (e.g., `danielclasen/charts`) or public chart repositories.

### Talos & Talhelper Node Management

[Talos Linux](https://www.talos.dev/) is a modern, immutable, and API-managed Linux distribution designed specifically for running Kubernetes. It eliminates SSH, focusing on security and predictability. All system management is performed via its API using the `talosctl` command-line utility.

[Talhelper](https://github.com/budimanjojo/talhelper) is a command-line utility that simplifies the generation of Talos Linux machine configuration files. It allows you to define your cluster declaratively in YAML and then generates the necessary Talos configurations. This setup uses Talhelper to manage the node configurations for this cluster.

A key feature of this Talhelper setup is its integration with [SOPS (Secrets OPerationS)](https://github.com/getsops/sops) using Age encryption. This allows sensitive parts of the Talos configuration, such as secrets or private keys, to be encrypted directly within the Talhelper configuration files and decrypted on-the-fly during generation or application.

**Useful `talosctl` Commands**

The following commands can be run from the `talos` directory within this repository (assuming your `talosconfig` is located at `clusterconfig/talosconfig` relative to that directory).

*   **Access Node Dashboards**:
    *   Control Plane Nodes:
        ```bash
        talosctl dashboard -n tcpl-01 --talosconfig clusterconfig/talosconfig
        talosctl dashboard -n tcpl-02 --talosconfig clusterconfig/talosconfig
        talosctl dashboard -n tcpl-03 --talosconfig clusterconfig/talosconfig
        ```
    *   Worker Nodes:
        ```bash
        talosctl dashboard -n tworker-01 --talosconfig clusterconfig/talosconfig
        talosctl dashboard -n tworker-02 --talosconfig clusterconfig/talosconfig
        ```
*   **Generate `kubeconfig` for `kubectl` Access**:
    To interact with the Kubernetes cluster using `kubectl`, generate a `kubeconfig` file using `talosctl`. From the `talos` directory (assuming your main `talosconfig` for node management is at `clusterconfig/talosconfig`), run:
    ```bash
    talosctl kubeconfig --talosconfig clusterconfig/talosconfig
    ```
    This command generates the `kubeconfig` content into your default `~/.kube/config` file. Once the `kubeconfig` is correctly set up, you can use standard `kubectl` commands to interact with the cluster.

### Infrastructure

*   **Nodes**:
    *   **Control Planes (3x)**: `tcpl-01`, `tcpl-02`, `tcpl-03`. These are amd64 VMs running on a Proxmox cluster.
    *   **Worker Nodes (2x)**: `tworker-01`, `tworker-02`. These are Rock Pi 4B Single Board Computers (SBCs) with arm64/aarch64 architecture.

*   **Networking**:
    *   **CNI**: Flannel
    *   **Ingress**: The cluster runs two Traefik ingress controllers:
        *   `traefik-internal`: For internal applications exposed on the `clsn.dev` domain.
        *   `traefik-external`: For public-facing applications exposed on the `clsn.cloud` domain.
    *   **DNS & Certificates**:
        *   Two `external-dns` controllers manage DNS records. One updates a local AdGuard Home instance (also deployed via this repository) for `clsn.dev` records, while the other manages public `clsn.cloud` records in Cloudflare.
        *   `cert-manager` is configured to automatically issue certificates for both domains using Cloudflare's DNS01 challenge.
    *   **LoadBalancer**: MetalLB provides LoadBalancer services for the cluster, operating in L2 mode.
        *   **Namespace**: `metallb`
        *   **IP Address Pool**: `192.168.95.20-192.168.95.40`
        *   **L2 Advertisement**: Service IPs are advertised by all nodes. Control planes (`tcpl-01` to `tcpl-03`) use the `ens18` interface, and worker nodes (`tworker-01`, `tworker-02`) use the `end0.95` interface.
*   **Storage**:
    *   **Block Storage (LINSTOR/Piraeus)**:
        *   **Provisioner**: `linstor.csi.linbit.com`, managed by the Piraeus Operator (Helm release: `linstor-affinity-controller`).
        *   **Namespace**: `piraeus-datastore`.
        *   **Underlying Pools**: LINSTOR utilizes host block devices (e.g., `/dev/nvme0n1`, `/dev/sdb`) selected via node labels (e.g., `storage/linstor-ssd-device: nvme0n1`).
        *   **StorageClasses**:
            *   `ssd-perf-r3` (3 replicas, default filesystem)
            *   `ssd-perf-r1` (1 replica, default filesystem)
            *   `ssd-perf-xfs-r1` (1 replica, XFS filesystem)
    *   **Object Storage (MinIO)**:
        *   **Deployment**: A 3-replica MinIO cluster runs in the `minio` namespace. It uses the `ssd-perf-xfs-r1` StorageClass for persistence.
        *   **Access**:
            *   S3 API: `s3.clsn.cloud` (publicly accessible via `traefik-external`).
            *   Web Console: `s3.clsn.dev` (internally accessible via `traefik-internal`).
        *   **Bucket Provisioning**: The `s3-operator` (from `inseefrlab/s3-operator`, also in the `minio` namespace) dynamically provisions S3 buckets, users, and policies. Applications request these resources by defining Kubernetes CRDs (e.g., `Bucket`, `S3User`, `Policy` with apiVersion `s3.onyxia.sh/v1alpha1`), as exemplified by the Notesnook application.

### Database Management

*   **MongoDB**:
    *   **MongoDB Kubernetes Operator**: The cluster utilizes the official MongoDB Kubernetes Operator (from `mongodb/mongodb-kubernetes`) to manage MongoDB deployments.
    *   **MongoDB Ops Manager**: A local instance of MongoDB Ops Manager is deployed in the `mongodb` namespace, providing monitoring, backup, and automation capabilities for MongoDB instances managed by the operator.
    *   **Application Databases**: Applications like Notesnook have their MongoDB replica sets deployed and managed by the operator, configured with TLS using CA bundles from `trust-manager`, and integrated with Ops Manager.

### Secrets Management

*   **Method**: SOPS (Sealed Operations) with GPG/Age is used for encrypting secrets, as mentioned in the introduction.
*   **Configuration**: Secrets are encrypted and committed directly to this Git repository.
    *   The `.sops.yaml` file in this repository defines which files and fields (e.g., `path_regex: .*.yaml`, `encrypted_regex: ^(data|stringData)$`) are subject to encryption.
    *   A pre-commit hook (detailed in the "Git Hooks Setup" section above) is in place to prevent committing unencrypted secrets. This hook requires `yq` (Mike Farah's Go version v4+) to be installed.
    *   **FluxCD Integration**: The SOPS AGE private key is provided to FluxCD by creating a Kubernetes secret in the `flux-system` namespace, typically using a command like:
        ```bash
        cat ~/.config/sops/age/keys.txt | kubectl create secret generic sops-age --namespace=flux-system --from-file=age.agekey=/dev/stdin
        ```

### Supporting Services & Operators

*   **Certificate & Trust Management**:
    *   **cert-manager**: (Already documented under Networking for DNS01 challenges) Handles automatic issuance and renewal of TLS certificates.
    *   **trust-manager**: Deployed alongside `cert-manager` in the `cert-manager` namespace. It provides CA bundles to applications, enabling them to trust custom or internal CAs. For example, it supplies a `ca-bundle` (including default CAs) to MongoDB instances for internal TLS communication.


*   **Secret Templating (External Secrets Operator)**:
    *   **Deployment**: The External Secrets Operator (ESO) is deployed in the `external-secrets` namespace.
    *   **Usage**: While ESO can connect to external secret providers, it's primarily used in this cluster for its templating capabilities. It accesses existing Kubernetes secrets within application namespaces (via a `SecretStore` configured with the `kubernetes` provider and a dedicated ServiceAccount) and can transform or template them into new Secrets or ConfigMaps as required by applications.
