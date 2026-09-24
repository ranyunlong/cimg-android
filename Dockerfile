# vim:set ft=dockerfile:

FROM registry.cn-hangzhou.aliyuncs.com/geckoai/cimg:2025.02.2-ndk

LABEL maintainer="Community & Partner Engineering Team <community-partner@circleci.com>"

RUN echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "cmake;3.31.1" && \
	echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "cmake;3.31.4"

# Use the last two versions of the NDK
# Setup LTS release
ENV NDK_LTS_VERSION "28.0.12916984"
ENV ANDROID_NDK_HOME "/home/circleci/android-sdk/ndk/${NDK_LTS_VERSION}"
RUN echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "ndk;${NDK_LTS_VERSION}"

ENV ANDROID_NDK_ROOT "${ANDROID_NDK_HOME}"
ENV PATH "${ANDROID_NDK_HOME}:${PATH}"

# Setup Stable release
ENV NDK_STABLE_VERSION "27.2.12479018"
RUN echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "tools" && \
    echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "platform-tools" && \
    echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "build-tools;36.0.0"
RUN echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "platforms;android-36"
RUN curl -o ${ANDROID_HOME}/platforms/android-35/android.jar https://raw.githubusercontent.com/Reginer/aosp-android-jar/main/android-36/android.jar
RUN echo y | ${CMDLINE_TOOLS_ROOT}/sdkmanager "ndk;${NDK_STABLE_VERSION}"

