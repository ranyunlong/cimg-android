# vim:set ft=dockerfile:

# Do not edit individual Dockerfiles manually. Instead, please make changes to the Dockerfile.template, which will be used by the build script to generate Dockerfiles.

# By policy, the base image tag should be a quarterly tag unless there's a
# specific reason to use a different one. This means January, April, July, or
# October.

FROM docker.1ms.run/cimg/base:2024.02

LABEL maintainer="CircleCI Execution Team <eng-execution@circleci.com>"

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
RUN curl -sSL -o /tmp/maven.tar.gz https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/${MAVEN_VERSION}/apache-maven-${MAVEN_VERSION}-bin.tar.gz && \
        sudo tar -xz -C /usr/local -f /tmp/maven.tar.gz && \
        sudo ln -sf /usr/local/apache-maven-${MAVEN_VERSION} /usr/local/apache-maven && \
        rm -rf /tmp/maven.tar.gz && \
        mkdir -p /home/circleci/.m2
ENV GRADLE_VERSION=8.12.1
ENV PATH $PATH:/usr/local/gradle-${GRADLE_VERSION}/bin
RUN URL=https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip && \
        curl -sSL -o /tmp/gradle.zip $URL && \
        sudo unzip -d /usr/local /tmp/gradle.zip && \
        rm -rf /tmp/gradle.zip

# Install Android SDK Tools
ENV ANDROID_HOME "/home/circleci/android-sdk"
ENV ANDROID_SDK_ROOT $ANDROID_HOME
ENV CMDLINE_TOOLS_ROOT "${ANDROID_HOME}/cmdline-tools/latest/bin"
ENV ADB_INSTALL_TIMEOUT 120
ENV PATH "${ANDROID_HOME}/emulator:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/platform-tools/bin:${PATH}"
# You can find the latest command line tools here: https://developer.android.com/studio#command-line-tools-only
RUN SDK_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" && \
        mkdir -p ${ANDROID_HOME}/cmdline-tools && \
        mkdir ${ANDROID_HOME}/platforms && \
        mkdir ${ANDROID_HOME}/ndk && \
        wget -O /tmp/cmdline-tools.zip -t 5 "${SDK_TOOLS_URL}" && \
        unzip -q /tmp/cmdline-tools.zip -d ${ANDROID_HOME}/cmdline-tools && \
        rm /tmp/cmdline-tools.zip && \
        mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest

# NOTE: "tools" package is obsolete and no longer available via sdkmanager.
# It has been removed to avoid "Failed to find package 'tools'" error.
RUN echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "platform-tools" && \
    echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "build-tools;36.0.0" && \
    echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "build-tools;35.0.0" && \
    echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "build-tools;34.0.0"
RUN echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "platforms;android-34" && \
    echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "platforms;android-35" && \
    echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "platforms;android-36"

# Install some useful packages
RUN echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "extras;android;m2repository" && \
        echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "extras;google;m2repository" && \
        echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "extras;google;google_play_services" && \
    sudo gem install fastlane --version 2.226.0 --no-document && \
        curl -sL https://firebase.tools | bash

# Install Google Cloud CLI
# Latest gcloud version can be found here: https://cloud.google.com/sdk/docs/release-notes
# NOTE: Package "google-cloud-sdk" has been renamed to "google-cloud-cli".
# Version pinning has been removed because old versions are periodically
# removed from Google's apt repository.
RUN ARCH=$(uname -m) && \
    case "$ARCH" in \
        x86_64) GCLOUD_ARCH="x86_64" ;; \
        aarch64) GCLOUD_ARCH="arm" ;; \
        *) echo "Unsupported arch: $ARCH" >&2; exit 1 ;; \
    esac && \
    curl -sSL --retry 3 -o /tmp/gcloud.tar.gz \
        "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-${GCLOUD_ARCH}.tar.gz" && \
    sudo tar -xzf /tmp/gcloud.tar.gz -C /usr/local && \
    rm /tmp/gcloud.tar.gz
    
RUN curl -o ${ANDROID_HOME}/platforms/android-34/android.jar http://mingqi-package.mingqi-tech.cn/aosp/34/android.jar
RUN curl -o ${ANDROID_HOME}/platforms/android-35/android.jar http://mingqi-package.mingqi-tech.cn/aosp/35/android.jar
RUN curl -o ${ANDROID_HOME}/platforms/android-36/android.jar http://mingqi-package.mingqi-tech.cn/aosp/36/android.jar