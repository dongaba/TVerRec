FROM ubuntu:latest

ENV POWERSHELL_TELEMETRY_OPTOUT=1

LABEL org.opencontainers.image.title="TVerRec" \
	org.opencontainers.image.source=https://github.com/dongaba/TVerRec \
	org.opencontainers.image.authors="dongaba" \
	org.opencontainers.image.licenses=MIT

#必要ソフトのインストール
RUN	apt-get update
RUN	apt-get install --no-install-recommends -y \
	curl \
	git \
	bash \
	python3 \
	xz-utils \
	wget \
	apt-transport-https \
	software-properties-common \
	jq \
	libssl-dev \
	libunwind8 \
	&& apt-get autoremove -y \
	&& apt-get clean -y  \
	&& rm -rf /var/lib/apt/lists/*
#Powershellのダウンロードと配置
RUN /bin/bash -c ' \
	arch=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/x64/ | sed s/amd64/x64/) ; \
	release=$(curl -sL https://api.github.com/repos/PowerShell/PowerShell/releases/latest) ; \
	package=$(echo $release | jq -r ".assets[].browser_download_url" | grep "linux-${arch}.tar.gz") ; \
	wget $package ; \
	mkdir -p /opt/microsoft/powershell ; \
	tar -xvf "./${package##*/}" -C /opt/microsoft/powershell ; \
	ln -s /opt/microsoft/powershell/pwsh /usr/bin/pwsh ; \
	rm -rf "./${package##*/}" \
	'

#ディレクトリ準備
RUN mkdir -p -m 777 \
	/app \
	/mnt/Temp \
	/mnt/Work \
	/mnt/Save

#TVerRecのインストール
WORKDIR /app
RUN git clone https://github.com/dongaba/TVerRec.git

#コンテナ用修正
WORKDIR /app/TVerRec
RUN sed -i -e "s|'TVerRec'|'TVerRecContainer'|g" ./conf/system_setting.ps1 \
	&& sed -i -e "s|\$script:confDir 'keyword.conf'|\$script:containerDir 'keyword.conf'|g" ./conf/system_setting.ps1 \
	&& sed -i -e "s|\$script:confDir 'ignore.conf'|\$script:containerDir 'ignore.conf'|g" ./conf/system_setting.ps1 \
	&& sed -i -e "s|\$script:dbDir 'history.csv'|\$script:containerDir 'history.csv'|g" ./conf/system_setting.ps1 \
	&& sed -i -e "s|\$script:listDir 'list.csv'|\$script:containerDir 'list.csv'|g" ./conf/system_setting.ps1 \
	&& sed -i -e "s|\$script:confDir 'user_setting.ps1'|\$script:containerDir 'user_setting.ps1'|g" ./src/*.ps1 \
	&& sed -i -e "s|\$script:confDir 'user_setting.ps1'|\$script:containerDir 'user_setting.ps1'|g" ./src/*/*.ps1 \
	&& sed -i -e "s|Enterを押して|コンテナを再起動して|g" ./unix/start_tverrec.sh \
	&& sed -i -e "s|read -r -t|sleep|g" ./unix/start_tverrec.sh \
	&& mkdir container-data \
	&& cp ./resources/sample/keyword.sample.conf ./container-data/keyword.conf \
	&& cp ./resources/sample/ignore.sample.conf ./container-data/ignore.conf \
	&& cp ./resources/sample/history.sample.csv ./container-data/history.csv \
	&& cp ./resources/sample/list.sample.csv ./container-data/list.csv \
	&& echo '$script:downloadBaseDir = '\''/mnt/Work'\''' >> ./container-data/user_setting.ps1 \
	&& echo '$script:downloadWorkDir = '\''/mnt/Temp'\''' >> ./container-data/user_setting.ps1 \
	&& echo '$script:saveBaseDir = '\''/mnt/Save'\''' >> ./container-data/user_setting.ps1

RUN chmod a+x ./unix/*.sh

WORKDIR /app/TVerRec/unix
ENTRYPOINT ["/bin/bash"]
CMD ["start_tverrec.sh"]
