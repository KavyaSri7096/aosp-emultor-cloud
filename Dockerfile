# Copyright 2021 - The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# First stage: Unzipping system image
FROM alpine:3.18 AS unzipper
RUN apk add --update unzip

FROM unzipper as sys_unzipper
COPY x86_64-33_r02.zip /tmp/
RUN unzip -u -o /tmp/x86_64-33_r02.zip -d /sysimg/

# Second stage: Setting up emulator environment
FROM nvidia/opengl:1.2-glvnd-runtime-ubuntu20.04 AS emulator_env
ENV NVIDIA_DRIVER_CAPABILITIES ${NVIDIA_DRIVER_CAPABILITIES},display

RUN mkdir -p /android/sdk/platforms && \
    mkdir -p /android/sdk/platform-tools && \
    mkdir -p /android/sdk/system-images

COPY platform-tools/adb /android/sdk/platform-tools/adb

ENV ANDROID_SDK_ROOT /android/sdk
WORKDIR /android/sdk
COPY --from=sys_unzipper /sysimg/ /android/sdk/system-images/android/
RUN chmod +x /android/sdk/platform-tools/adb

LABEL maintainer="" \
    ro.system.build.fingerprint="google/sdk_gcar_x86_64/emulator_car64_x86_64:13/TAG1.230812.001.B6/11332649:userdebug/dev-keys" \
    ro.product.cpu.abi="x86_64" \
    ro.build.version.incremental="11332649" \
    ro.build.version.sdk="33" \
    ro.build.flavor="sdk_gcar_x86_64-userdebug" \
    ro.product.cpu.abilist="" \
    ro.build.type="userdebug" \
    SystemImage.TagId="android-automotive-playstore" \
    qemu.tag="android-automotive-playstore" \
    qemu.cpu="x86_64" \
    qemu.short_tag="automotive_playstore" \
    qemu.short_abi="x64"

# Use a base image with Java 8
FROM openjdk:8 AS android_sdk

# Install required packages
RUN apt-get update && \
    apt-get install -y wget unzip

# Download and install Android SDK (older version)
RUN wget https://dl.google.com/android/repository/sdk-tools-linux-3859397.zip -O android-sdk.zip && \
    unzip android-sdk.zip -d /usr/local/android-sdk && \
    rm android-sdk.zip

# Set environment variables
ENV ANDROID_HOME /usr/local/android-sdk
ENV PATH $PATH:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools

# Accept Android SDK licenses
RUN yes | sdkmanager --licenses

# Update SDK manager and repository information
RUN sdkmanager --update

# Download and install AAOS system image
RUN sdkmanager "system-images;android-33;android-automotive;x86_64"

# Final stage: Define the command to run the emulator
FROM android_sdk AS final
CMD ["emulator", "-avd", "aaos_avd"]

