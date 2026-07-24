# Build image for the RikkaHub Android app.
#
# Usage:
#   podman build -t rikkahub-builder .
#   podman run --rm -v "${PWD}:/work" -v "${HOME}/.gradle:/root/.gradle" rikkahub-builder
#
# Output APKs are written to /work/app/build/outputs/apk/debug/.
#
# Notes:
# - The repo uses a git submodule (material3/material-color-utilities). Either
#   initialize it on the host before building (`git submodule update --init`)
#   or uncomment the submodule init step below.
# - The Firebase google-services plugin requires a google-services.json file at
#   app/google-services.json. If you do not have the real one, the build injects
#   a dummy (package IDs me.rerere.rikkahub and me.rerere.rikkahub.debug) so
#   compilation proceeds. Set BUILD_ENV=release to fail instead.

FROM eclipse-temurin:17-jdk

ENV DEBIAN_FRONTEND=noninteractive \
    ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    PATH="${PATH}:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools"

# System dependencies: git (submodules), Node.js + npm (pnpm for web-ui), wget/unzip (sdkmanager).
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        git wget unzip ca-certificates \
        nodejs npm && \
    rm -rf /var/lib/apt/lists/*

# Android SDK command-line tools. License acceptance is required for any
# package install (including those the Gradle plugin pulls in at build time).
RUN mkdir -p "${ANDROID_HOME}/cmdline-tools" && \
    cd "${ANDROID_HOME}/cmdline-tools" && \
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O cmdtools.zip && \
    unzip -q cmdtools.zip && \
    mv cmdline-tools latest && \
    rm cmdtools.zip && \
    yes | sdkmanager --licenses > /dev/null 2>&1

# Pre-install the SDK packages the project pins, so first build does not
# spend minutes downloading them. Newer tooling is pulled in on demand by
# the Android Gradle plugin if the project bumps compileSdk/build-tools.
RUN sdkmanager --install \
        "platform-tools" \
        "platforms;android-37.0" \
        "build-tools;36.0.0" \
        "ndk;28.2.13676358"

# pnpm is required by the :web module's preBuild task (web-ui React app).
RUN npm install -g pnpm

WORKDIR /work

# Default entrypoint: compile the debug variant. Override with e.g.
#   podman run ... rikkahub-builder ./gradlew assembleRelease
ENTRYPOINT ["./gradlew"]
CMD ["--console=plain", "--no-daemon", ":app:assembleDebug"]