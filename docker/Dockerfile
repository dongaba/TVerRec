FROM mcr.microsoft.com/powershell

LABEL org.opencontainers.image.title="TVerRec" \
	org.opencontainers.image.description="TVerRec is a download tool to download and save TVer programs. You can download TVer programs by specifying the name of genre, talent, program and more." \
	org.opencontainers.image.version=2.6.9 \
	org.opencontainers.image.source=https://github.com/dongaba/TVerRec \
	org.opencontainers.image.authors="dongaba" \
	org.opencontainers.image.licenses=MIT

#テレメトリ送信からのオプトアウト
ENV POWERSHELL_TELEMETRY_OPTOUT=1

#必要ソフトのインストール
RUN --mount=type=cache,target=/var/lib/apt \
	--mount=type=cache,target=/var/cache/apt \
	apt-get update \
	&& apt-get install --no-install-recommends -y \
	procps \
	yt-dlp \
	curl \
	wget \
	xz-utils \
	&& apt-get autoremove -y \
	&& apt-get clean -y

#ディレクトリの作成
RUN mkdir -p -m 777 /app/TVerRec \
	/mnt/Temp \
	/mnt/Work \
	/mnt/Video 


#TVerRecのCOPY
COPY . /app/TVerRec/

#User追加
ARG USERNAME=tverrec \
	GROUPNAME=tverrec \
	UID=1000 \
	GID=1000
RUN groupadd -g $GID $GROUPNAME && \
	useradd -m -s /bin/bash -u $UID -g $GID $USERNAME \
	&& chown -R 1000:1000 /app/TVerRec
USER $USERNAME

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

WORKDIR /app/TVerRec/unix
ENTRYPOINT ["bash"]
CMD ["start_tverrec.sh"]
