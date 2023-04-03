FROM mcr.microsoft.com/powershell:alpine-3.14

ENV POWERSHELL_TELEMETRY_OPTOUT=1

LABEL org.opencontainers.image.title="TVerRec" \
	org.opencontainers.image.source=https://github.com/dongaba/TVerRec \
	org.opencontainers.image.authors="dongaba" \
	org.opencontainers.image.licenses=MIT \
	org.opencontainers.image.description="TVerRecは、TVerの番組をダウンロード保存するためのダウンロードツールです。番組のジャンルや出演タレント、番組名などを指定して一括ダウンロードします。CMは入っていないため気に入った番組を配信終了後も残しておくことができます。1回起動すれば新しい番組が配信される度にダウンロードされます。"

#必要ソフトのインストール
RUN apk --update --no-cache add \
	curl \
	git \
	python3 \
	ffmpeg \
	&& rm -rf /var/cache/apk/*

#User追加
ARG UID=1000 \
	GID=1000
RUN addgroup -g "$GID" tverrec \
	&& adduser -D -u "$UID" tverrec -G tverrec

#ディレクトリ準備
RUN mkdir -p -m 777 \ 
	/app \
	/mnt/Temp \
	/mnt/Work \
	/mnt/Video

#ユーザ切り替え
USER tverrec

#TVerRecのインストール
WORKDIR /app
RUN git clone https://github.com/dongaba/TVerRec.git

#コンテナ用修正
WORKDIR /app/TVerRec
RUN sed -i -e 's|\.\./src|/app/TVerRec/src|g' ./unix/*.sh \
	&& sed -i -e "s|'TVerRec'|'TVerRecContainer'|g" ./conf/system_setting.ps1 \
	&& sed -i -e "s|'W:'|'/mnt/Work'|g" ./conf/system_setting.ps1 \
	&& sed -i -e "s|=\ \$env:TMP|=\ '/mnt/Temp'|g" ./conf/system_setting.ps1 \
	&& sed -i -e "s|'V:'|'/mnt/Video'|g" ./conf/system_setting.ps1 \
	&& sed -i -e "s|read -r -t $sleepTime|sleep $sleepTime|g" ./unix/start_tverrec.sh

#youtube-dlインストール
RUN curl -L "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp" -o ./bin/youtube-dl \
	&& chmod a+x ./bin/youtube-dl \
	&& cp $(which ffmpeg) ./bin/. \
	&& cp $(which ffprobe) ./bin/.

WORKDIR /app/TVerRec/unix
ENTRYPOINT ["/bin/sh"]
CMD ["start_tverrec.sh"]
