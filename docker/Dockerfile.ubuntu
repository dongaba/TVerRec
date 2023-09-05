FROM mcr.microsoft.com/powershell:ubuntu-22.04

ENV POWERSHELL_TELEMETRY_OPTOUT=1

LABEL org.opencontainers.image.title="TVerRec" \
	org.opencontainers.image.source=https://github.com/dongaba/TVerRec \
	org.opencontainers.image.authors="dongaba" \
	org.opencontainers.image.licenses=MIT \
	org.opencontainers.image.description="TVerRecは、TVerの番組をダウンロード保存するためのダウンロードツールです。番組のジャンルや出演タレント、番組名などを指定して一括ダウンロードします。CMは入っていないため気に入った番組を配信終了後も残しておくことができます。1回起動すれば新しい番組が配信される度にダウンロードされます。"

#必要ソフトのインストール
RUN	apt-get update \
	&& apt-get install --no-install-recommends -y \
	curl \
	git \
	bash \
	python3 \
	xz-utils \
	&& apt-get autoremove -y \
	&& apt-get clean -y \
	&& rm -rf /var/lib/apt/lists/*

#User追加
ARG UID=1000 \
	GID=1000
RUN groupadd -g "$GID" tverrec \
	&& useradd -l -m -s /bin/bash -u "$UID" -g "$GID" tverrec

#ディレクトリ準備
RUN mkdir -p -m 777 \
	/app \
	/mnt/Temp \
	/mnt/Work \
	/mnt/Save

#ユーザ切り替え
USER tverrec

#TVerRecのインストール
WORKDIR /app
RUN git clone https://github.com/dongaba/TVerRec.git

#コンテナ用修正
WORKDIR /app/TVerRec
RUN sed -i -e "s|'TVerRec'|'TVerRecContainer'|g" ./conf/system_setting.ps1 \
	&& sed -i -e "s|\$script:confDir './keyword.conf'|\$script:containerDir 'keyword.conf'|g" ./conf/system_setting.ps1 \
	&& sed -i -e "s|\$script:confDir './ignore.conf'|\$script:containerDir 'ignore.conf'|g" ./conf/system_setting.ps1 \
	&& sed -i -e "s|\$script:dbDir './history.csv'|\$script:containerDir 'history.csv'|g" ./conf/system_setting.ps1 \
	&& sed -i -e "s|\$script:listDir './list.csv'|\$script:containerDir 'list.csv'|g" ./conf/system_setting.ps1 \
	&& sed -i -e "s|\$script:confDir './user_setting.ps1'|\$script:containerDir 'user_setting.ps1'|g" ./src/*.ps1 \
	&& sed -i -e "s|\$script:confDir './user_setting.ps1'|\$script:containerDir 'user_setting.ps1'|g" ./src/*/*.ps1 \
	&& sed -i -e "s|Enterを押して|コンテナを再起動して|g" ./unix/start_tverrec.sh \
	&& echo '$script:downloadBaseDir = '\''/mnt/Work'\''' >> ./conf/user_setting.ps1 \
	&& echo '$script:downloadWorkDir = '\''/mnt/Temp'\''' >> ./conf/user_setting.ps1 \
	&& echo '$script:saveBaseDir = '\''/mnt/Save'\''' >> ./conf/user_setting.ps1 \
	&& mkdir container-data

RUN chmod a+x ./unix/*.sh

WORKDIR /app/TVerRec/unix
ENTRYPOINT ["/bin/bash"]
CMD ["start_tverrec.sh"]
