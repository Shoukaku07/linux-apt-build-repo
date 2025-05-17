# Linux APT Build Repo

**Linux APT Build Repo** is a tool designed to **build Debian packages (.deb)** and **create a local APT repository** automatically. This allows you to easily manage your own Debian packages and serve them through a local repository accessible by Debian-based systems like Ubuntu.

---

## What Are Debian Packages and APT Repositories?

* **Debian Package (.deb):** The standard package format for software installation on Debian-based systems. Each package contains the software files, metadata, and installation scripts.

* **APT Repository:** A structured storage location for Debian packages, containing metadata indexes so that APT tools (`apt-get`, `apt`) can find, install, update, or remove packages easily.

---

## Why Use This Tool?

When developing your own Debian packages or modifying software, you may want to:

* **Build your own .deb packages** for easier distribution and installation.
* **Set up a local APT repository** to serve packages within your internal network without using public servers.
* **Manage packages centrally**, including signing them with GPG keys for security.
* **Automate the build and repo creation process** to save time and reduce errors.

This tool automates these steps so you don’t have to run complex commands manually.

---

## How the Tool Works

The tool consists of two main scripts:

### 1. `build-packages.sh`

* Builds Debian packages from source directories.
* You can build a single package, multiple packages, or all available packages.
* For example, building a package named `hello-world` will create a `.deb` file ready for installation.

### 2. `build-repo.sh`

* After building `.deb` files, this script creates the APT repository metadata.
* It generates package indices and repository metadata for all specified architectures.
* Optionally signs the repository with GPG keys to ensure package authenticity.

---

## Usage Examples

### Build a Single Package

To build only the `hello-world` package:

```bash
bash build-packages.sh --package hello-world
bash build-repo.sh
```

---

### Build Multiple Packages

To build multiple packages, e.g., `hello-world` and `hello-world-2`:

```bash
bash build-packages.sh --package hello-world hello-world-2
bash build-repo.sh
```

---

### Build All Packages

To build every package in your source directory:

```bash
bash build-packages.sh --package all
bash build-repo.sh
```

---

## Requirements

Ensure the following tools are installed on your system:

* `bash`
* `dpkg-deb`
* `dpkg-scanpackages`
* `apt-ftparchive`
* `gpg` (optional, for signing)

You can install them on Debian/Ubuntu with:

```bash
sudo apt-get update
sudo apt-get install dpkg-dev apt-utils gnupg gzip xz-utils
```

---

## Configuration

Configure variables in the `config.sh` file:

* `suite` — Distribution name, e.g. `focal`, `buster`
* `component` — Repository component, e.g. `main`
* `arch` — Array of architectures, e.g. `("amd64" "arm64" "all")`
* `build` — Folder where `.deb` packages will be built
* `repo` — Folder where the repository metadata and packages will be stored

---

## Example

Suppose you have a `hello-world` package and want to build and create a local repo:

```bash
bash build-packages.sh --package hello-world
bash build-repo.sh
```

You can then add this repository to your system’s APT sources:

```text
deb [trusted=true] https://YOUR-REPO-LINK/ suite component
```

Or if you signed the repo with GPG:

```text
deb [signed-by=/usr/share/keyrings/YOUR-KEYRING.gpg] https://YOUR-REPO-LINK/ suite component
```

---

## Benefits

* **Automates** the packaging and repository creation process.
* **Supports multiple architectures**.
* **Supports GPG signing** for secure package distribution.
* **Easy to integrate** into CI/CD pipelines or local development workflows.

---

## Sample Generated Repository Structure

After running the build scripts, your repository directory might look like this:

```
.
├── dists
│   └── stable
│       ├── InRelease
│       ├── main
│       │   ├── binary-all
│       │   │   ├── Packages
│       │   │   ├── Packages.gz
│       │   │   └── Packages.xz
│       │   ├── binary-amd64
│       │   │   ├── Packages
│       │   │   ├── Packages.gz
│       │   │   └── Packages.xz
│       │   ├── binary-arm64
│       │   │   ├── Packages
│       │   │   ├── Packages.gz
│       │   │   └── Packages.xz
│       │   ├── binary-armel
│       │   │   ├── Packages
│       │   │   ├── Packages.gz
│       │   │   └── Packages.xz
│       │   ├── binary-armhf
│       │   │   ├── Packages
│       │   │   ├── Packages.gz
│       │   │   └── Packages.xz
│       │   └── binary-i386
│       │       ├── Packages
│       │       ├── Packages.gz
│       │       └── Packages.xz
│       ├── Release
│       └── Release.gpg
├── pool
│   └── main
│       └── h
│           └── helloworld
│               └── helloworld_1.0.0_all.deb
└── mykey.gpg
```

* The `dists` directory contains distribution metadata and package indexes per architecture.
* The `pool` directory stores the actual `.deb` package files.
* The `Release` and `Release.gpg` files contain repository metadata and GPG signatures.
* `test.gpg` could be your GPG public key used for signing.

---

## License

This project is licensed under the [Apache License 2.0](./LICENSE) - See the LICENSE file for full details.
