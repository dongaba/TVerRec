FROM mcr.microsoft.com/powershell:lts-ubuntu-20.04

LABEL org.opencontainers.image.title="TVerRec" \
	org.opencontainers.image.description="TVerRec is a download tool to download and save TVer programs. You can download TVer programs by specifying the name of genre, talent, program and more." \
	org.opencontainers.image.version=2.6.9 \
	org.opencontainers.image.source=https://github.com/dongaba/TVerRec \
	org.opencontainers.image.authors="dongaba" \
	org.opencontainers.image.licenses=MIT

#必要ソフトのインストール
RUN --mount=type=cache,target=/var/lib/apt \
	--mount=type=cache,target=/var/cache/apt \
	apt-get update \
	&& apt-get install --no-install-recommends -y \
	procps \
	yt-dlp \
	wget \
	xz-utils \
	openssh-server \
	vim-tiny \
	net-tools \
	gosu \
	&& apt-get autoremove -y \
	&& apt-get clean -y \
	&& rm -rf /var/lib/apt/lists/*

#User追加
ARG UID=1000 \
	GID=1000
RUN groupadd -g "$GID" tverrec \
	&& useradd -l -m -s /bin/bash -u "$UID" -g "$GID" tverrec \
	&& echo "tverrec:tverrec" | chpasswd 

#ssh設定
ENV NOTVISIBLE "in users profile"
RUN sed -ri 's/^#Port 22/Port 20022/' /etc/ssh/sshd_config \
	&& sed -ri 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' /etc/pam.d/sshd \
	&& echo 'export VISIBLE=now' | tee -a /etc/profile \
	&& ssh-keygen -A
EXPOSE 20022

#ディレクトリ準備
RUN mkdir -p -m 777 \ 
	/app/TVerRec/bin \
	/app/TVerRec/conf \
	/app/TVerRec/db \
	/app/TVerRec/img \
	/app/TVerRec/list \
	/app/TVerRec/src \
	/app/TVerRec/unix \
	/app/TVerRec/win \
	/mnt/Temp \
	/mnt/Work \
	/mnt/Video

#TVerRecのインストール
COPY bin /app/TVerRec/bin
COPY conf /app/TVerRec/conf
COPY db /app/TVerRec/db
COPY img /app/TVerRec/img
COPY list /app/TVerRec/list
COPY src /app/TVerRec/src
COPY unix /app/TVerRec/unix
COPY win /app/TVerRec/win
COPY VERSION /app/TVerRec
COPY docker/entrypoint.sh /app/TVerRec/

#youtube-dl & ffmpegインストール
RUN cp -f /usr/bin/yt-dlp /app/TVerRec/bin/youtube-dl \
	&& wget -q --show-progress -O /tmp/ffmpeg-release-amd64-static.tar.xz https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz \
	&& tar -Jxf /tmp/ffmpeg-release-amd64-static.tar.xz -C /tmp \
	&& cp -f /tmp/ffmpeg*amd64-static/ff* /app/TVerRec/bin/. \
	&& chmod a+x /app/TVerRec/bin/ff* \
	&& rm -rf /tmp/ffmpeg*

#コンテナ用修正
RUN rm -rf /app/TVerRec/*/.gitkeep \
	&& sed -i -e 's#\.\./src#/app/TVerRec/src#g' /app/TVerRec/unix/*.sh \
	&& sed -i -e "s#'TVerRec'#'TVerRecContainer'#g" /app/TVerRec/conf/system_setting.ps1 \
	&& sed -i -e "s#'W:'#'/mnt/Work'#g" /app/TVerRec/conf/system_setting.ps1 \
	&& sed -i -e "s#=\ \$env:TMP#=\ '/mnt/Temp'#g" /app/TVerRec/conf/system_setting.ps1 \
	&& sed -i -e "s#'V:'#'/mnt/Video'#g" /app/TVerRec/conf/system_setting.ps1

#権限変更
RUN chown -R tverrec:tverrec /app/TVerRec \
	&& chmod a+x /app/TVerRec/entrypoint.sh
ENV POWERSHELL_TELEMETRY_OPTOUT=1

WORKDIR /app/TVerRec/unix
ENTRYPOINT ["/app/TVerRec/entrypoint.sh"]

