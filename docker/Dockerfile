FROM mcr.microsoft.com/powershell:latest

LABEL org.opencontainers.image.title="TVerRec" \
	org.opencontainers.image.description="TVerRec is a download tool to download and save TVer programs. You can download TVer programs by specifying the name of genre, talent, program and more." \
	org.opencontainers.image.version=2.6.9 \
	org.opencontainers.image.source=https://github.com/dongaba/TVerRec \
	org.opencontainers.image.authors="dongaba" \
	org.opencontainers.image.licenses=MIT

ENV POWERSHELL_TELEMETRY_OPTOUT=1

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
	&& apt-get clean -y

#User追加
ARG UID=1000 \
	GID=1000
RUN groupadd -g $GID tverrec \
	&& useradd -m -s /bin/bash -u $UID -g $GID tverrec \
	&& echo "tverrec:tverrec" | chpasswd 

#ssh
ENV NOTVISIBLE "in users profile"
RUN sed -ri 's/^#Port 22/Port 20022/' /etc/ssh/sshd_config \
	&& sed -ri 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' /etc/pam.d/sshd \
	&& echo 'export VISIBLE=now' | tee -a /etc/profile \
	&& ssh-keygen -A
EXPOSE 20022

#TVerRecのCOPY
COPY ./TVerRec /app/TVerRec/
COPY entrypoint.sh /app/TVerRec/
RUN chmod a+x /app/TVerRec/entrypoint.sh \
	&& mkdir -p -m 777 /app/TVerRec/bin \
	/mnt/Temp \
	/mnt/Work \
	/mnt/Video

#youtube-dl & ffmpeg
RUN cp -f /usr/bin/yt-dlp /app/TVerRec/bin/youtube-dl \
	&&wget -O /tmp/ffmpeg-release-amd64-static.tar.xz https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz \
	&& tar -Jxvf /tmp/ffmpeg-release-amd64-static.tar.xz -C /tmp \
	&& cp -f /tmp/ffmpeg*amd64-static/ff* /app/TVerRec/bin/. \
	&& chmod a+x /app/TVerRec/bin/ff* \
	&& rm -rf /tmp/ffmpeg*

#権限変更
RUN chown -R tverrec:tverrec /app/TVerRec

WORKDIR /app/TVerRec/unix
ENTRYPOINT ["/app/TVerRec/entrypoint.sh"]

