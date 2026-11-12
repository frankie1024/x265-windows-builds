# x265 Windows Builds

This repository builds Windows x64 executable packages from official
[x265](https://github.com/Multicorewareinc/x265) releases.

The workflow checks the latest upstream GitHub release every day and can also
be run manually for a specific tag. When the target GitHub release already
exists, the scheduled job exits without rebuilding it.

## Output

Each GitHub release contains:

- `x265.exe`
- related runtime files produced by the Release build
- `BUILD_INFO.txt` with the source tag, commit, and build settings
- `bit-depth-validation.json` recording actual 8-bit and 10-bit output verification

The packaged archive name is:

```text
x265-<version>-x64.zip
```

## Manual Build

Open the `Build x265 Windows x64` workflow and run it with:

- `tag`: optional upstream tag, for example `4.2`
- `force`: rebuild and replace release assets if the release already exists

If `tag` is empty, the workflow uses the latest upstream GitHub release.

## Build Details

The GitHub Actions job runs on `windows-2022` and uses the upstream CMake build:

```powershell
git clone --branch <tag> --depth 1 https://github.com/Multicorewareinc/x265.git
./scripts/build-multilib.ps1
```

NASM is installed with Chocolatey before the build so assembly primitives are
available. The build first creates a namespaced 10-bit static library, then
links it into the 8-bit CLI with `LINKED_10BIT=ON`. Both output depths are tested
with real Y4M samples and a SHA256-verified, pinned FFprobe 9.0.2. A successful
exit code alone is insufficient: codec, pixel format, and decoded frame count
must match before the package is uploaded or published.

Pull requests always build and validate an artifact, even when that upstream
release already exists. They never publish or replace release assets. Release
publication runs in a separate job after validation for scheduled/manual runs.

For local source-only validation without NASM, use `-DisableAssembly`; the
release workflow keeps assembly enabled.

## Upstream Licenses

This repository only contains automation. Built x265 binaries are subject to
the upstream x265 license terms. See the upstream project:

- https://github.com/Multicorewareinc/x265
- https://github.com/Multicorewareinc/x265/blob/master/COPYING
