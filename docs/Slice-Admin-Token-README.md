---
layout: page
title: Slice & Admin Token Retrieval Script
description: Script for retrieving tokens for Kubernetes slices and admin users
permalink: /docs/token-retrieval/
---

# 🔑 Slice & Admin Token Retrieval Script - `fetch_egs_slice_token.sh`

`fetch_egs_slice_token.sh` is a Bash script designed to retrieve tokens for Kubernetes slices and admin users within a specified project/namespace. This script can fetch read-only, read-write, and admin tokens based on the provided arguments, making it flexible for various Kubernetes authentication requirements.

## 📋 Usage

```bash
./fetch_egs_slice_token.sh -k <kubeconfig_absolute_path> [-s <slice_name>] -p <project_name> [-a] -u <username1,username2,...>
```

## 🔹 Parameters

- **`-k, --kubeconfig`** (required): Absolute path to the kubeconfig file used to connect to the Kubernetes cluster.
- **`-s, --slice`** (optional if `-a` is provided): Name of the slice for which the tokens are to be retrieved.
- **`-p, --project`** (required): Name of the project (namespace) where the slice is located.
- **`-a, --admin`** (optional): Fetch admin tokens for specified usernames (makes `--slice` optional).
- **`-u, --username`** (required with `-a`): Comma-separated list of usernames for fetching admin tokens.
- **`-h, --help`**: Display help message.

## 🚀 Examples

### 1️⃣ Fetching Slice Tokens Only

Retrieve read-only and read-write tokens for a specified slice:

```bash
./fetch_egs_slice_token.sh -k /path/to/kubeconfig -s pool1 -p avesha
```

- **Explanation**: This command fetches tokens for the slice `pool1` in the namespace `kubeslice-avesha`.
- **Parameters**:
  - `-k /path/to/kubeconfig`: Specifies the path to the kubeconfig file.
  - `-s pool1`: Specifies the slice name (`pool1`).
  - `-p avesha`: Specifies the project/namespace name (`avesha`).

---

### 2️⃣ Fetching Admin Tokens Only 

Fetch admin tokens for specific users. When the `-a` flag is used, `--slice` becomes optional.

```bash
./fetch_egs_slice_token.sh -k /path/to/kubeconfig -p avesha -a -u admin,dev
```

- **Explanation**: This command fetches admin tokens for both `admin` and `dev` users in the namespace `kubeslice-avesha`.
- **Parameters**:
  - `-k /path/to/kubeconfig`: Specifies the path to the kubeconfig file.
  - `-p avesha`: Specifies the project/namespace name (`avesha`).
  - `-a`: Indicates that we are fetching admin tokens.
  - `-u admin,dev`: Specifies a comma-separated list of usernames (`admin` and `dev`).

---

### 3️⃣ Fetching Both Slice and Admin Tokens

Retrieve both slice tokens and admin tokens in a single command:

```bash
./fetch_egs_slice_token.sh -k /path/to/kubeconfig -s pool1 -p avesha -a -u admin,dev
```

- **Explanation**: This command retrieves both read-only and read-write tokens for slice `pool1` and admin tokens for `admin` and `dev` in the namespace `kubeslice-avesha`.
- **Parameters**:
  - `-k /path/to/kubeconfig`: Specifies the path to the kubeconfig file.
  - `-s pool1`: Specifies the slice name (`pool1`).
  - `-p avesha`: Specifies the project/namespace name (`avesha`).
  - `-a`: Indicates that we are fetching admin tokens.
  - `-u admin,dev`: Specifies a comma-separated list of usernames (`admin` and `dev`).

---

### 🛠️ Help

For more details on usage or troubleshooting, you can refer to the help option:

```bash
./fetch_egs_slice_token.sh --help
```

## Related Files

- **`fetch_egs_slice_token.sh`**: The main token retrieval script
