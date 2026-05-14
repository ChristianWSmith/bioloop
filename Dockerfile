FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    openjdk-17-jdk \
    && rm -rf /var/lib/apt/lists/*

# Android SDK
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=$ANDROID_HOME
RUN mkdir -p $ANDROID_HOME/cmdline-tools && \
    curl -fsSL https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip \
    -o /tmp/cmdline-tools.zip && \
    unzip -q /tmp/cmdline-tools.zip -d /tmp/ && \
    mkdir -p $ANDROID_HOME/cmdline-tools/latest && \
    mv /tmp/cmdline-tools/* $ANDROID_HOME/cmdline-tools/latest/ && \
    rm /tmp/cmdline-tools.zip && \
    rm -rf /tmp/cmdline-tools

ENV PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH

RUN yes | sdkmanager --licenses && \
    sdkmanager \
    "platforms;android-36" \
    "build-tools;36.0.0" \
    "ndk;28.2.13676358" \
    "platform-tools"

# Flutter SDK
ENV FLUTTER_HOME=/opt/flutter
ENV PATH=$FLUTTER_HOME/bin:$PATH
RUN git clone --depth 1 --branch stable https://github.com/flutter/flutter.git $FLUTTER_HOME && \
    flutter config --android-sdk $ANDROID_HOME && \
    flutter precache --android && \
    yes | flutter doctor --android-licenses 2>/dev/null || true

WORKDIR /app
CMD ["sh", "-c", "flutter pub get && flutter build apk --release"]
