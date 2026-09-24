# vim:set ft=dockerfile:

# Do not edit individual Dockerfiles manually. Instead, please make changes to the Dockerfile.template, which will be used by the build script to generate Dockerfiles.

# By policy, the base image tag should be a quarterly tag unless there's a
# specific reason to use a different one. This means January, April, July, or
# October.

FROM docker.1ms.run/cimg/base:2024.02

LABEL maintainer="CircleCI Execution Team <eng-execution@circleci.com>"

# ---------------------------------------------------------------------------
# 替换 Ubuntu 源为清华源 (cimg/base:2024.02 基于 Ubuntu 22.04 Jammy)
# ---------------------------------------------------------------------------
RUN sudo sed -i 's@//.*archive.ubuntu.com@//mirrors.tuna.tsinghua.edu.cn@g; s@//security.ubuntu.com@//mirrors.tuna.tsinghua.edu.cn@g' /etc/apt/sources.list && \
    sudo sed -i 's@http://@https://@g' /etc/apt/sources.list

# Java 17 is default
RUN sudo apt-get update && sudo apt-get install -y \
                ant \
                openjdk-8-jdk \
                openjdk-17-jdk \
                openjdk-21-jdk \
                ruby-full \
        && \
        sudo rm -rf /var/lib/apt/lists/* && \
        ruby -v && \
        sudo gem install bundler && \
        bundle version

#fixes issue with bundle install highlighted in https://github.com/CircleCI-Public/cimg-android/issues/82
RUN sudo chmod -R a+w /var/lib/gems/ /usr/local/bin

ENV M2_HOME /usr/local/apache-maven
ENV MAVEN_OPTS -Xmx2048m
ENV PATH $M2_HOME/bin:$PATH
# Set JAVA_HOME (and related) environment variable. This will be set to our
# default Java version of 21 but the user would need to reset it when changing
# JAVA versions.
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
ENV JDK_HOME=${JAVA_HOME}
ENV JRE_HOME=${JDK_HOME}
ENV MAVEN_VERSION=3.9.9

# ---------------------------------------------------------------------------
# Maven 改用华为云镜像
# ---------------------------------------------------------------------------
RUN curl -sSL -o /tmp/maven.tar.gz https://repo.huaweicloud.com/apache/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz && \
        sudo tar -xz -C /usr/local -f /tmp/maven.tar.gz && \
        sudo ln -sf /usr/local/apache-maven-${MAVEN_VERSION} /usr/local/apache-maven && \
        rm -rf /tmp/maven.tar.gz && \
        mkdir -p /home/circleci/.m2

ENV GRADLE_VERSION=8.12.1
ENV PATH $PATH:/usr/local/gradle-${GRADLE_VERSION}/bin

# ---------------------------------------------------------------------------
# Gradle 改用腾讯云镜像
# ---------------------------------------------------------------------------
RUN URL=https://mirrors.cloud.tencent.com/gradle/gradle-${GRADLE_VERSION}-bin.zip && \
        curl -sSL --retry 3 -o /tmp/gradle.zip $URL && \
        sudo unzip -d /usr/local /tmp/gradle.zip && \
        rm -rf /tmp/gradle.zip

# Install Android SDK Tools
ENV ANDROID_HOME "/home/circleci/android-sdk"
ENV ANDROID_SDK_ROOT $ANDROID_HOME
ENV CMDLINE_TOOLS_ROOT "${ANDROID_HOME}/cmdline-tools/latest/bin"
ENV ADB_INSTALL_TIMEOUT 120
ENV PATH "${ANDROID_HOME}/emulator:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/platform-tools/bin:${PATH}"

# ---------------------------------------------------------------------------
# Android command line tools：官方源不可靠换镜像，仅加 retry
# ---------------------------------------------------------------------------
# You can find the latest command line tools here: https://developer.android.com/studio#command-line-tools-only
RUN SDK_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" && \
        mkdir -p ${ANDROID_HOME}/cmdline-tools && \
        mkdir ${ANDROID_HOME}/platforms && \
        mkdir ${ANDROID_HOME}/ndk && \
        curl -sSL --retry 3 --retry-delay 5 -o /tmp/cmdline-tools.zip "${SDK_TOOLS_URL}" && \
        unzip -q /tmp/cmdline-tools.zip -d ${ANDROID_HOME}/cmdline-tools && \
        rm /tmp/cmdline-tools.zip && \
        mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest

# NOTE: "tools" package is obsolete and no longer available via sdkmanager.
# It has been removed to avoid "Failed to find package 'tools'" error.
# ---------------------------------------------------------------------------
# sdkmanager 走的还是官方源，但用 yes | 批量接受 license
# ---------------------------------------------------------------------------
RUN yes | ${CMDLINE_TOOLS_ROOT}/sdkmanager --licenses && \
    yes | ${CMDLINE_TOOLS_ROOT}/sdkmanager "platform-tools" && \
    yes | ${CMDLINE_TOOLS_ROOT}/sdkmanager "build-tools;36.0.0" && \
    yes | ${CMDLINE_TOOLS_ROOT}/sdkmanager "build-tools;35.0.0" && \
    yes | ${CMDLINE_TOOLS_ROOT}/sdkmanager "build-tools;34.0.0" && \
    yes | ${CMDLINE_TOOLS_ROOT}/sdkmanager "platforms;android-34" && \
    yes | ${CMDLINE_TOOLS_ROOT}/sdkmanager "platforms;android-35" && \
    yes | ${CMDLINE_TOOLS_ROOT}/sdkmanager "platforms;android-36"

# Install some useful packages
RUN yes | ${CMDLINE_TOOLS_ROOT}/sdkmanager "extras;android;m2repository" && \
        yes | ${CMDLINE_TOOLS_ROOT}/sdkmanager "extras;google;m2repository" && \
        yes | ${CMDLINE_TOOLS_ROOT}/sdkmanager "extras;google;google_play_services" && \
    sudo gem install fastlane --version 2.226.0 --no-document && \
        curl -sSL --retry 3 https://firebase.tools | bash

# ---------------------------------------------------------------------------
# Google Cloud CLI：无可靠国内 apt 镜像，保留官方源
# ---------------------------------------------------------------------------
# Install Google Cloud CLI
# Latest gcloud version can be found here: https://cloud.google.com/sdk/docs/release-notes
# NOTE: Package "google-cloud-sdk" has been renamed to "google-cloud-cli".
# Version pinning has been removed because old versions are periodically
# removed from Google's apt repository.
RUN curl -sSL --retry 3 https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - && \
        sudo add-apt-repository "deb https://packages.cloud.google.com/apt cloud-sdk main" && \
        sudo apt-get update && sudo apt-get install -y google-cloud-cli && \
        sudo gcloud config set --installation component_manager/disable_update_check true && \
        sudo gcloud config set disable_usage_reporting false

# ---------------------------------------------------------------------------
# android.jar：GitHub raw 无稳定镜像，合并并加 retry
# ---------------------------------------------------------------------------
RUN curl -sSL --retry 3 -o ${ANDROID_HOME}/platforms/android-34/android.jar https://raw.githubusercontent.com/Reginer/aosp-android-jar/main/android-34/android.jar && \
    curl -sSL --retry 3 -o ${ANDROID_HOME}/platforms/android-35/android.jar https://raw.githubusercontent.com/Reginer/aosp-android-jar/main/android-35/android.jar && \
    curl -sSL --retry 3 -o ${ANDROID_HOME}/platforms/android-36/android.jar https://raw.githubusercontent.com/Reginer/aosp-android-jar/main/android-36/android.jar