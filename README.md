

[![Build](https://github.com/anyvm-org/freebsd-builder/actions/workflows/build.yml/badge.svg)](https://github.com/anyvm-org/freebsd-builder/actions/workflows/build.yml)

Latest: v2.2.0


The image builder for `freebsd`


All the supported releases are here:



| Release | x86_64  | aarch64(arm64) | riscv64  | powerpc64 |
|---------|---------|---------|-----------------|-----------|
| 15.1    |  ✅     |  ✅    |           ✅    |     ✅    |
| 15.0    |  ✅     |  ✅    |           ✅    |     ✅    |
| 14.4    |  ✅     |  ✅    |           ✅    |     ✅    |
| 14.3    |  ✅     |  ✅    |           ✅    |     ✅    |
| 14.2    |  ✅     |  ✅    |           ✅    |     —    |
| 14.1    |  ✅     |  ✅    |           —    |     —    |
| 14.0    |  ✅     |  —    |           —    |     —    |
| 13.5    |  ✅     |  ✅    |           ✅    |     ✅    |
| 13.4    |  ✅     |  ✅    |           —    |     —    |
| 13.3    |  ✅     |  ✅    |           —    |     —    |
| 13.2    |  ✅     |  —    |           —    |     —    |
| 12.4    |  ✅     |  —    |           —    |     —    |



FreeBSD desktop images (x86_64):

| Release | x86_64  | aarch64(arm64) | riscv64  | powerpc64 |
|---------|---------|---------|-----------------|-----------|
| 15.1-xfce    |  ✅     |  —    |           —    |     —    |
| 15.1-gnome    |  ✅     |  —    |           —    |     —    |
| 15.1-kde6    |  ✅     |  —    |           —    |     —    |
| 15.0-xfce    |  ✅     |  —    |           —    |     —    |
| 15.0-gnome    |  ✅     |  —    |           —    |     —    |
| 15.0-kde6    |  ✅     |  —    |           —    |     —    |


How to build:

1. Use the [manual.yml](.github/workflows/manual.yml) to build manually.
   
    Run the workflow manually, you will get a view-only webconsole from the output of the workflow, just open the link in your web browser.
   
    You will also get an interactive VNC connection port from the output, you can connect to the vm by any vnc client.

2. Run the builder locally on your Ubuntu machine.

    Just clone the repo. and run:
    ```bash
    python3 build.py conf/freebsd-16.0.conf
    ```
   
