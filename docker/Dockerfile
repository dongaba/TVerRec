FROM mcr.microsoft.com/powershell

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
	sudo \
	&& apt-get autoremove -y \
	&& apt-get clean -y

#User追加
ARG USERNAME=tverrec \
	GROUPNAME=tverrec \
	PASSWORD=tverrec \
	UID=1000 \
	GID=1000
RUN groupadd -g $GID $GROUPNAME \
	&& useradd -m -s /bin/bash -u $UID -g $GID -G sudo $USERNAME \
	&& echo "$USERNAME:$PASSWORD" | chpasswd \
	#&& echo 'Defaults visiblepw' | sudo tee -a /etc/sudoers \
	&& echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers

#ssh
ENV NOTVISIBLE "in users profile"
RUN sed -ri 's/^#Port 22/Port 20022/' /etc/ssh/sshd_config \
	&& sed -ri 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' /etc/pam.d/sshd \
	&& echo 'export VISIBLE=now' | sudo tee -a /etc/profile \
	&& ssh-keygen -A
EXPOSE 20022

#ディレクトリの作成
RUN mkdir -p -m 777 /app/TVerRec \
	/mnt/Temp \
	/mnt/Work \
	/mnt/Video

#TVerRecのCOPY
COPY . /app/TVerRec/

#ffmpeg
RUN cd /tmp \
	&& wget https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz \
	&& tar -xf ffmpeg-release-amd64-static.tar.xz \
	&& cp -f ffmpeg*amd64-static/ff* /app/TVerRec/bin/. \
	&& chmod a+x /app/TVerRec/bin/ff* \
	&& cd \
	&& rm -rf /tmp/ffmpeg*

#youtube-dl
RUN cp -f /usr/bin/yt-dlp /app/TVerRec/bin/youtube-dl

#権限変更
RUN chown -R $UID:$GID /app/TVerRec
USER $USERNAME

WORKDIR /app/TVerRec/unix
ENTRYPOINT ["bash", "-c","sudo service ssh start && ./start_tverrec.sh"]
