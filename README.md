# docker-pigpio

This repo builds a Docker image that installs Raspberry Pi OS packaged `rgpiod` and `rgpio-tools` with plain `apt`, then exposes the `rgpiod` socket interface for remote GPIO access.

It is designed to be buildable directly from a Git URL, for example with `docker buildx build https://github.com/...`.

It is also structured to work with the remote-client deployment model described in `ha-docker-pxe-deploy`: build the image from this Git repository on the Raspberry Pi client, then run it there with explicit `ports`, `devices`, and `env` settings instead of relying on Compose.

## Assumptions

- The supported target is a Raspberry Pi OS host running Docker on Raspberry Pi hardware.
- The image installs `rgpiod` and `rgpio-tools` from the default Raspberry Pi OS apt configuration already present in the base image.
- The default build uses a Raspberry Pi OS Lite `trixie` base image.
- This still does not make GPIO portable across arbitrary hosts. The container needs Linux gpiochip device nodes from the host, typically `/dev/gpiochip0` and sometimes additional gpiochips depending on the board.

## Package availability

- Raspberry Pi's current `trixie` archive includes `rgpiod`, `rgpio-tools`, `librgpio1`, and related `lg-gpio` packages.
- Debian proper did not contain `rgpiod`, `rgpio-tools`, or the `librgpio` packages in the `bookworm`, `trixie`, or `sid` `arm64` main package indexes I checked on March 15, 2026.
- Because of that, this repo now stays Raspberry Pi OS-specific instead of layering Raspberry Pi packages onto Debian.

## Build from a GitHub URL

Build directly from the repo URL:

```sh
docker buildx build \
  -t docker-pigpio:latest \
  --build-arg BASE_IMAGE=badaix/raspios-lite:trixie \
  https://github.com/<owner>/<repo>.git#main
```

No extra apt repositories are added in the Dockerfile. The base image is expected to already be Raspberry Pi OS with its normal package sources configured.

## Home Assistant PXE Docker Fleet

This repository matches the `source.type: git` remote-build pattern described in the `ha-docker-pxe-deploy` README.

Use a `containers` entry like this on the Raspberry Pi client:

```json
[
  {
    "name": "rgpiod",
    "image": "local/rgpiod:latest",
    "source": {
      "type": "git",
      "url": "https://github.com/<owner>/docker-pigpio.git",
      "dockerfile": "Dockerfile"
    },
    "env": {
      "RGPIOD_PORT": "8889",
      "RGPIOD_LOCAL_ONLY": "0"
    },
    "ports": [
      "8889:8889"
    ],
    "devices": [
      "/dev/gpiochip0:/dev/gpiochip0"
    ]
  }
]
```

Notes for that add-on model:

- Use `source.type: git`, not an image pull, so the Pi client builds this repository locally.
- Keep `image` as the local output tag for the client-side build.
- Add more entries under `devices` if the target board exposes additional gpiochips.
- If you want to restrict access, set `RGPIOD_LOCAL_ONLY=1` or provide `RGPIOD_ALLOWED_IPS`.
- The example JSON is also available in `examples/ha-docker-pxe-deploy.containers.json`.

## Run on a Raspberry Pi OS host

Minimal device mapping:

```sh
docker run -d \
  --name rgpiod \
  --restart unless-stopped \
  --device /dev/gpiochip0:/dev/gpiochip0 \
  -p 8889:8889 \
  docker-pigpio:latest
```

If your board exposes more than one gpiochip, pass each needed device:

```sh
docker run -d \
  --name rgpiod \
  --restart unless-stopped \
  --device /dev/gpiochip0:/dev/gpiochip0 \
  --device /dev/gpiochip4:/dev/gpiochip4 \
  -p 8889:8889 \
  docker-pigpio:latest
```

## Runtime configuration

Environment variables:

- `RGPIOD_PORT`: TCP port for `rgpiod`. Default: `8889`
- `RGPIOD_LOCAL_ONLY`: set to `1` to disable remote socket access (`rgpiod -l`)
- `RGPIOD_ALLOWED_IPS`: comma-separated allow-list, translated to repeated `rgpiod -n` flags
- `RGPIOD_ACCESS_CONTROL`: set to `1` to enable access control (`rgpiod -x`)
- `RGPIOD_CONFIG_DIR`: optional config directory passed as `rgpiod -c`
- `RGPIOD_WORK_DIR`: optional working directory passed as `rgpiod -w`
- `RGPIOD_SKIP_DEVICE_CHECK`: set to `1` only if you intentionally want to bypass the startup device check

Extra `rgpiod` flags can be passed as container arguments:

```sh
docker run --rm \
  --device /dev/gpiochip0:/dev/gpiochip0 \
  -p 8889:8889 \
  docker-pigpio:latest \
  -n 192.168.1.10
```

## Compose example

The included `compose.yaml` gives you a local Raspberry Pi OS deployment example. For `ha-docker-pxe-deploy`, treat it as reference material only and use the JSON container spec above instead of Compose directly.

```sh
docker compose up -d --build
```

Override build args or runtime settings through environment variables:

```sh
BASE_IMAGE=badaix/raspios-lite:trixie RGPIOD_ALLOWED_IPS=192.168.1.10 docker compose up -d --build
```

## Security note

By default `rgpiod` allows remote TCP clients. If the service should only be reachable locally or by a small set of clients, set either:

- `RGPIOD_LOCAL_ONLY=1`
- `RGPIOD_ALLOWED_IPS=192.168.1.10,192.168.1.11`
- `RGPIOD_ACCESS_CONTROL=1`

## Sources

- `ha-docker-pxe-deploy` agent guidance for Git-backed remote builds: <https://github.com/Clam-/ha-docker-pxe-deploy/blob/main/README.md>
- Raspberry Pi `trixie` package index showing `rgpiod` and `rgpio-tools`: <https://archive.raspberrypi.org/debian/dists/trixie/main/binary-arm64/Packages.gz>
- Raspberry Pi OS Lite OCI image tags used as the base here: <https://hub.docker.com/r/badaix/raspios-lite>
- Upstream `rgpiod` documentation and launch options: <https://lg.raspberrybasic.org/rgpiod.html>
- Upstream `rgs` client documentation: <https://lg.raspberrybasic.org/rgs.html>
- Debian package indexes checked for absence of `rgpiod` in main: <https://deb.debian.org/debian/dists/trixie/main/binary-arm64/Packages.gz> and <https://deb.debian.org/debian/dists/sid/main/binary-arm64/Packages.gz>
