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
	xz-utils \
	&& apt-get autoremove -y \
	&& apt-get clean -y

#TVerRecのCOPY
RUN mkdir -p /app/TVerRec
COPY . /app/TVerRec/

#ffmpeg
RUN --mount=type=cache,target=/tmp \
	curl -SL https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz | tar -xJC /tmp \
	&& cp -f /tmp/ffmpeg*amd64-static/ff* /app/TVerRec/bin/.

#youtube-dl
RUN cp -f /usr/bin/yt-dlp /app/TVerRec/bin/youtube-dl

#データ用外部フォルダのマウントポイント
RUN mkdir -p /mnt/Temp \
	/mnt/Work \
	/mnt/Video

WORKDIR /app/TVerRec/unix
ENTRYPOINT ["bash"]
CMD ["start_tverrec.sh"]


