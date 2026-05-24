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

The packaged archive name is:

```text
x265-<tag>-windows-x64.zip
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
cmake -S x265/source -B x265/build/windows-x64 -G "Visual Studio 17 2022" -A x64 -DENABLE_CLI=ON -DENABLE_SHARED=OFF
cmake --build x265/build/windows-x64 --config Release --target cli
```

NASM is installed with Chocolatey before the build so assembly primitives are
available.

## Upstream Licenses

This repository only contains automation. Built x265 binaries are subject to
the upstream x265 license terms. See the upstream project:

- https://github.com/Multicorewareinc/x265
- https://github.com/Multicorewareinc/x265/blob/master/COPYING
