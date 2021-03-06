#!/usr/bin/env bash
set -e
this_dir="$( cd "$( dirname "$0" )" && pwd )"

if [[ -z "$(command -v qemu-arm-static)" ]]; then
    echo "Need to install qemu-user-static"
    sudo apt-get update
    sudo apt-get install qemu-arm-static
fi

# Copy qemu for ARM architectures
mkdir -p "${this_dir}/etc"
for qemu_file in qemu-arm-static qemu-aarch64-static; do
    dest_file="${this_dir}/etc/${qemu_file}"

    if [[ ! -s "${dest_file}" ]]; then
        cp "$(which ${qemu_file})" "${dest_file}"
    fi
done

# Do Docker builds
docker_archs=('amd64' 'arm32v7' 'arm64v8' 'arm32v6')
if [[ ! -z "$1" ]]; then
    docker_archs=("$@")
fi
declare -A friendly_archs
friendly_archs=(['amd64']='amd64' ['arm32v7']='armhf' ['arm64v8']='aarch64' ['arm32v6']='arm32v6')

for docker_arch in "${docker_archs[@]}"; do
    friendly_arch="${friendly_archs[${docker_arch}]}"
    echo "${docker_arch} ${friendly_arch}"

    if [[ -z "${friendly_arch}" ]]; then
       exit 1
    fi

    # Debian build (skip arm32v6)
    if [[ "${friendly_arch}" != 'arm32v6' ]]; then
        docker_tag="rhasspy/phonetisaurus:2019-${friendly_arch}"

        docker build "${this_dir}" \
               --build-arg "BUILD_FROM=${docker_arch}/debian:stretch" \
               --build-arg "FRIENDLY_ARCH=${friendly_arch}" \
               -t "${docker_tag}"

        # Copy out build artifacts
        mkdir -p "${this_dir}/dist"
        docker run -it \
               -v "${this_dir}/dist:/dist" \
               -u "$(id -u):$(id -g)" \
               "${docker_tag}" \
               /bin/tar -C /build -czf "/dist/phonetisaurus-2019-${friendly_arch}.tar.gz" .
    fi

    # Alpine build
    docker_tag="rhasspy/phonetisaurus:2019-${friendly_arch}-alpine"

    docker build "${this_dir}" \
           -f Dockerfile.alpine \
           --build-arg "BUILD_FROM=${docker_arch}/alpine:3.9" \
           --build-arg "FRIENDLY_ARCH=${friendly_arch}" \
           -t "${docker_tag}"

    # Copy out build artifacts
    mkdir -p "${this_dir}/dist"
    docker run -it \
           -v "${this_dir}/dist:/dist" \
           -u "$(id -u):$(id -g)" \
           "${docker_tag}" \
           /bin/tar -C /build -czf "/dist/phonetisaurus-2019-${friendly_arch}-alpine.tar.gz" .
done
