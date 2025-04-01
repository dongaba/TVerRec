# **🎞TVerRec📺** TVer一括ダウンロード・保存

[🇺🇸English](https://github.com/dongaba/TVerRec/blob/master/README.en.md) | [🇯🇵日本語](https://github.com/dongaba/TVerRec/blob/master/README.md)

![Logo](https://raw.githubusercontent.com/dongaba/TVerRec/master/resources/img/TVerRec-Logo.png)
[![GitHub release](https://img.shields.io/github/v/release/dongaba/TVerRec?style=social&label=Release&logo=github)](https://github.com/dongaba/TVerRec/releases)
[![License](https://img.shields.io/github/license/dongaba/TVerRec?style=social&logo=github&label=License)](https://opensource.org/licenses/MIT)
[![GitHub commit activity](https://img.shields.io/github/commit-activity/y/dongaba/TVerRec?style=social&logo=github&label=Commit%20Activity)](https://github.com/dongaba/TVerRec/commits/master/)
[![GitHub last commit](https://img.shields.io/github/last-commit/dongaba/TVerRec?style=social&logo=github&label=Last%20Commit)](https://github.com/dongaba/TVerRec/commits/master/)
[![GitHub Repo stars](https://img.shields.io/github/stars/dongaba/tverrec?style=social&logo=github)](https://github.com/dongaba/TVerRec/stargazers)
[![GitHub Sponsors](https://img.shields.io/github/sponsors/dongaba?style=social&logo=githubsponsors)](https://github.com/sponsors/dongaba)
[![CodeFactor Grade](https://img.shields.io/codefactor/grade/github/dongaba/tverrec?logo=codefactor&style=social&label=CodeFactor)](https://www.codefactor.io/repository/github/dongaba/tverrec)
[![Codacy grade](https://img.shields.io/codacy/grade/1b42499be57b48818db8c3c90d73adb3?logo=codacy&style=social&label=Codacy)](https://app.codacy.com/gh/dongaba/TVerRec/dashboard)
[![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/dongaba/tverrec/devskim.yml?style=social&logo=githubactions&label=DevSkim)](https://github.com/dongaba/TVerRec/actions/workflows/devskim.yml)
[![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/dongaba/tverrec/powershell.yml?style=social&logo=githubactions&label=PSScriptAnalyzer)](https://github.com/dongaba/TVerRec/actions/workflows/powershell.yml)
[![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/dongaba/tverrec/push-to-dh.yml?style=social&logo=githubactions&label=Push%20to%20DockerHub)](https://github.com/dongaba/TVerRec/actions/workflows/push-to-dh.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/dongaba/tverrec?style=social&logo=docker)](https://hub.docker.com/repository/docker/dongaba/tverrec/general)
[![TVerRec Launched](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fhits.sh%2Fapi%2Furns%2Fgithub.com%2Fdongaba%2FTVerRec%2Flaunch&query=total&style=social&logo=data:image/svg%2bxml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMjgiIGhlaWdodD0iMTI4IiBzdHlsZT0ic2hhcGUtcmVuZGVyaW5nOmdlb21ldHJpY1ByZWNpc2lvbjt0ZXh0LXJlbmRlcmluZzpnZW9tZXRyaWNQcmVjaXNpb247aW1hZ2UtcmVuZGVyaW5nOm9wdGltaXplUXVhbGl0eTtmaWxsLXJ1bGU6ZXZlbm9kZDtjbGlwLXJ1bGU6ZXZlbm9kZCI+PHBhdGggc3R5bGU9Im9wYWNpdHk6Ljk5NSIgZmlsbD0iIzNiM2EzYSIgZD0iTTE2LjUtLjVoOTRjOCAzLjMzMyAxMy42NjcgOSAxNyAxN3Y5NGMtMy4zMzMgOC05IDEzLjY2Ny0xNyAxN2gtOTRjLTgtMy4zMzMtMTMuNjY3LTktMTctMTd2LTk0YzMuMzMzLTggOS0xMy42NjcgMTctMTd6Ii8+PHBhdGggc3R5bGU9Im9wYWNpdHk6MSIgZmlsbD0iI2ZjZmNmYyIgZD0iTTE4LjUgNy41YzI5LjY2OS0uMTY3IDU5LjMzNSAwIDg5IC41IDUuNDEgMS43NDMgOS4yNDQgNS4yNDIgMTEuNSAxMC41YTE5NzkuNTEgMTk3OS41MSAwIDAgMSAwIDg5Yy0xLjk0MSA1Ljc3NS01Ljc3NCA5Ljc3NS0xMS41IDEyYTIwOC41NTQgMjA4LjU1NCAwIDAgMS0yMi0xN2MxOC4xODItMTIuNzE4IDI1LjAxNS0zMC4wNSAyMC41LTUyLTUuMzY2LTE1LjM2OC0xNS44NjYtMjUuMjAxLTMxLjUtMjkuNWE1NDAuODcgNTQwLjg3IDAgMCAwLTU1LTEuNXY5OWMtNS45MS0xLjQwOC05Ljc0My01LjA3NC0xMS41LTExYTE5ODAuNDkgMTk4MC40OSAwIDAgMSAwLTg5YzIuMzU3LTQuODU0IDUuODU3LTguNTIxIDEwLjUtMTF6Ii8+PHBhdGggc3R5bGU9Im9wYWNpdHk6MSIgZmlsbD0iI2Q2NDQzZCIgZD0iTTU0LjUgMjUuNWMyMy4xNzgtMi4zNCAzOC42NzggNy4zMjYgNDYuNSAyOSAxLjgzMyAzMi44MzMtMTMuNjY3IDQ4LjMzMy00Ni41IDQ2LjVDMzIuNjczIDkzLjE5NyAyMy4xNzMgNzcuNjk3IDI2IDU0LjVjNC4zNS0xNC44NDkgMTMuODUtMjQuNTE1IDI4LjUtMjl6Ii8+PHBhdGggc3R5bGU9Im9wYWNpdHk6MSIgZmlsbD0iI2ZjZmNmYyIgZD0iTTYzLjUgMTA3LjVjMy4xNS0uMjg5IDYuMTUuMjExIDkgMS41YTE0OC42NzggMTQ4LjY3OCAwIDAgMCAxMyAxMGMtNy4zMjYuNS0xNC42Ni42NjYtMjIgLjV2LTEyeiIvPjwvc3ZnPg==&label=TVerRec%20Launched&link=https%3A%2F%2Fhits.sh%2Fgithub.com%2Fdongaba%2FTVerRec%2Flaunch)](https://hits.sh/github.com/dongaba/TVerRec/launch)
[![Video Searched](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fhits.sh%2Fapi%2Furns%2Fgithub.com%2Fdongaba%2FTVerRec%2Fsearch&query=total&style=social&logo=data:image/svg%2bxml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMjgiIGhlaWdodD0iMTI4IiBzdHlsZT0ic2hhcGUtcmVuZGVyaW5nOmdlb21ldHJpY1ByZWNpc2lvbjt0ZXh0LXJlbmRlcmluZzpnZW9tZXRyaWNQcmVjaXNpb247aW1hZ2UtcmVuZGVyaW5nOm9wdGltaXplUXVhbGl0eTtmaWxsLXJ1bGU6ZXZlbm9kZDtjbGlwLXJ1bGU6ZXZlbm9kZCI+PHBhdGggc3R5bGU9Im9wYWNpdHk6Ljk5NSIgZmlsbD0iIzNiM2EzYSIgZD0iTTE2LjUtLjVoOTRjOCAzLjMzMyAxMy42NjcgOSAxNyAxN3Y5NGMtMy4zMzMgOC05IDEzLjY2Ny0xNyAxN2gtOTRjLTgtMy4zMzMtMTMuNjY3LTktMTctMTd2LTk0YzMuMzMzLTggOS0xMy42NjcgMTctMTd6Ii8+PHBhdGggc3R5bGU9Im9wYWNpdHk6MSIgZmlsbD0iI2ZjZmNmYyIgZD0iTTE4LjUgNy41YzI5LjY2OS0uMTY3IDU5LjMzNSAwIDg5IC41IDUuNDEgMS43NDMgOS4yNDQgNS4yNDIgMTEuNSAxMC41YTE5NzkuNTEgMTk3OS41MSAwIDAgMSAwIDg5Yy0xLjk0MSA1Ljc3NS01Ljc3NCA5Ljc3NS0xMS41IDEyYTIwOC41NTQgMjA4LjU1NCAwIDAgMS0yMi0xN2MxOC4xODItMTIuNzE4IDI1LjAxNS0zMC4wNSAyMC41LTUyLTUuMzY2LTE1LjM2OC0xNS44NjYtMjUuMjAxLTMxLjUtMjkuNWE1NDAuODcgNTQwLjg3IDAgMCAwLTU1LTEuNXY5OWMtNS45MS0xLjQwOC05Ljc0My01LjA3NC0xMS41LTExYTE5ODAuNDkgMTk4MC40OSAwIDAgMSAwLTg5YzIuMzU3LTQuODU0IDUuODU3LTguNTIxIDEwLjUtMTF6Ii8+PHBhdGggc3R5bGU9Im9wYWNpdHk6MSIgZmlsbD0iI2Q2NDQzZCIgZD0iTTU0LjUgMjUuNWMyMy4xNzgtMi4zNCAzOC42NzggNy4zMjYgNDYuNSAyOSAxLjgzMyAzMi44MzMtMTMuNjY3IDQ4LjMzMy00Ni41IDQ2LjVDMzIuNjczIDkzLjE5NyAyMy4xNzMgNzcuNjk3IDI2IDU0LjVjNC4zNS0xNC44NDkgMTMuODUtMjQuNTE1IDI4LjUtMjl6Ii8+PHBhdGggc3R5bGU9Im9wYWNpdHk6MSIgZmlsbD0iI2ZjZmNmYyIgZD0iTTYzLjUgMTA3LjVjMy4xNS0uMjg5IDYuMTUuMjExIDkgMS41YTE0OC42NzggMTQ4LjY3OCAwIDAgMCAxMyAxMGMtNy4zMjYuNS0xNC42Ni42NjYtMjIgLjV2LTEyeiIvPjwvc3ZnPg==&label=Video%20Searched&link=https%3A%2F%2Fhits.sh%2Fgithub.com%2Fdongaba%2FTVerRec%2search)](https://hits.sh/github.com/dongaba/TVerRec/search)
[![Video Download](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fhits.sh%2Fapi%2Furns%2Fgithub.com%2Fdongaba%2FTVerRec%2Fdownload&query=total&style=social&logo=data:image/svg%2bxml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMjgiIGhlaWdodD0iMTI4IiBzdHlsZT0ic2hhcGUtcmVuZGVyaW5nOmdlb21ldHJpY1ByZWNpc2lvbjt0ZXh0LXJlbmRlcmluZzpnZW9tZXRyaWNQcmVjaXNpb247aW1hZ2UtcmVuZGVyaW5nOm9wdGltaXplUXVhbGl0eTtmaWxsLXJ1bGU6ZXZlbm9kZDtjbGlwLXJ1bGU6ZXZlbm9kZCI+PHBhdGggc3R5bGU9Im9wYWNpdHk6Ljk5NSIgZmlsbD0iIzNiM2EzYSIgZD0iTTE2LjUtLjVoOTRjOCAzLjMzMyAxMy42NjcgOSAxNyAxN3Y5NGMtMy4zMzMgOC05IDEzLjY2Ny0xNyAxN2gtOTRjLTgtMy4zMzMtMTMuNjY3LTktMTctMTd2LTk0YzMuMzMzLTggOS0xMy42NjcgMTctMTd6Ii8+PHBhdGggc3R5bGU9Im9wYWNpdHk6MSIgZmlsbD0iI2ZjZmNmYyIgZD0iTTE4LjUgNy41YzI5LjY2OS0uMTY3IDU5LjMzNSAwIDg5IC41IDUuNDEgMS43NDMgOS4yNDQgNS4yNDIgMTEuNSAxMC41YTE5NzkuNTEgMTk3OS41MSAwIDAgMSAwIDg5Yy0xLjk0MSA1Ljc3NS01Ljc3NCA5Ljc3NS0xMS41IDEyYTIwOC41NTQgMjA4LjU1NCAwIDAgMS0yMi0xN2MxOC4xODItMTIuNzE4IDI1LjAxNS0zMC4wNSAyMC41LTUyLTUuMzY2LTE1LjM2OC0xNS44NjYtMjUuMjAxLTMxLjUtMjkuNWE1NDAuODcgNTQwLjg3IDAgMCAwLTU1LTEuNXY5OWMtNS45MS0xLjQwOC05Ljc0My01LjA3NC0xMS41LTExYTE5ODAuNDkgMTk4MC40OSAwIDAgMSAwLTg5YzIuMzU3LTQuODU0IDUuODU3LTguNTIxIDEwLjUtMTF6Ii8+PHBhdGggc3R5bGU9Im9wYWNpdHk6MSIgZmlsbD0iI2Q2NDQzZCIgZD0iTTU0LjUgMjUuNWMyMy4xNzgtMi4zNCAzOC42NzggNy4zMjYgNDYuNSAyOSAxLjgzMyAzMi44MzMtMTMuNjY3IDQ4LjMzMy00Ni41IDQ2LjVDMzIuNjczIDkzLjE5NyAyMy4xNzMgNzcuNjk3IDI2IDU0LjVjNC4zNS0xNC44NDkgMTMuODUtMjQuNTE1IDI4LjUtMjl6Ii8+PHBhdGggc3R5bGU9Im9wYWNpdHk6MSIgZmlsbD0iI2ZjZmNmYyIgZD0iTTYzLjUgMTA3LjVjMy4xNS0uMjg5IDYuMTUuMjExIDkgMS41YTE0OC42NzggMTQ4LjY3OCAwIDAgMCAxMyAxMGMtNy4zMjYuNS0xNC42Ni42NjYtMjIgLjV2LTEyeiIvPjwvc3ZnPg==&label=Video%20Downloaded&link=https%3A%2F%2Fhits.sh%2Fgithub.com%2Fdongaba%2FTVerRec%2Fdownload)](https://hits.sh/github.com/dongaba/TVerRec/download)
[![Video Validate](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fhits.sh%2Fapi%2Furns%2Fgithub.com%2Fdongaba%2FTVerRec%2Fvalidate&query=total&style=social&logo=data:image/svg%2bxml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMjgiIGhlaWdodD0iMTI4IiBzdHlsZT0ic2hhcGUtcmVuZGVyaW5nOmdlb21ldHJpY1ByZWNpc2lvbjt0ZXh0LXJlbmRlcmluZzpnZW9tZXRyaWNQcmVjaXNpb247aW1hZ2UtcmVuZGVyaW5nOm9wdGltaXplUXVhbGl0eTtmaWxsLXJ1bGU6ZXZlbm9kZDtjbGlwLXJ1bGU6ZXZlbm9kZCI+PHBhdGggc3R5bGU9Im9wYWNpdHk6Ljk5NSIgZmlsbD0iIzNiM2EzYSIgZD0iTTE2LjUtLjVoOTRjOCAzLjMzMyAxMy42NjcgOSAxNyAxN3Y5NGMtMy4zMzMgOC05IDEzLjY2Ny0xNyAxN2gtOTRjLTgtMy4zMzMtMTMuNjY3LTktMTctMTd2LTk0YzMuMzMzLTggOS0xMy42NjcgMTctMTd6Ii8+PHBhdGggc3R5bGU9Im9wYWNpdHk6MSIgZmlsbD0iI2ZjZmNmYyIgZD0iTTE4LjUgNy41YzI5LjY2OS0uMTY3IDU5LjMzNSAwIDg5IC41IDUuNDEgMS43NDMgOS4yNDQgNS4yNDIgMTEuNSAxMC41YTE5NzkuNTEgMTk3OS41MSAwIDAgMSAwIDg5Yy0xLjk0MSA1Ljc3NS01Ljc3NCA5Ljc3NS0xMS41IDEyYTIwOC41NTQgMjA4LjU1NCAwIDAgMS0yMi0xN2MxOC4xODItMTIuNzE4IDI1LjAxNS0zMC4wNSAyMC41LTUyLTUuMzY2LTE1LjM2OC0xNS44NjYtMjUuMjAxLTMxLjUtMjkuNWE1NDAuODcgNTQwLjg3IDAgMCAwLTU1LTEuNXY5OWMtNS45MS0xLjQwOC05Ljc0My01LjA3NC0xMS41LTExYTE5ODAuNDkgMTk4MC40OSAwIDAgMSAwLTg5YzIuMzU3LTQuODU0IDUuODU3LTguNTIxIDEwLjUtMTF6Ii8+PHBhdGggc3R5bGU9Im9wYWNpdHk6MSIgZmlsbD0iI2Q2NDQzZCIgZD0iTTU0LjUgMjUuNWMyMy4xNzgtMi4zNCAzOC42NzggNy4zMjYgNDYuNSAyOSAxLjgzMyAzMi44MzMtMTMuNjY3IDQ4LjMzMy00Ni41IDQ2LjVDMzIuNjczIDkzLjE5NyAyMy4xNzMgNzcuNjk3IDI2IDU0LjVjNC4zNS0xNC44NDkgMTMuODUtMjQuNTE1IDI4LjUtMjl6Ii8+PHBhdGggc3R5bGU9Im9wYWNpdHk6MSIgZmlsbD0iI2ZjZmNmYyIgZD0iTTYzLjUgMTA3LjVjMy4xNS0uMjg5IDYuMTUuMjExIDkgMS41YTE0OC42NzggMTQ4LjY3OCAwIDAgMCAxMyAxMGMtNy4zMjYuNS0xNC42Ni42NjYtMjIgLjV2LTEyeiIvPjwvc3ZnPg==&label=Video%20Validated&link=https%3A%2F%2Fhits.sh%2Fgithub.com%2Fdongaba%2FTVerRec%2Fvalidate)](https://hits.sh/github.com/dongaba/TVerRec/validate)

TVerRecは、テレビ番組配信サイトTVerの番組をダウンロード保存するためのダウンローダー、ダウンロード支援ツールです。
番組のジャンルや出演タレント、番組名などを指定して一括ダウンロードする支援をします。
CMは入っていないため気に入った番組を配信終了後も残しておくことができます。
1回起動すれば新しい番組が配信される度にダウンロードされます。

- **TVerRecはWindows PowerShellをサポートしません。PowerShell Coreでご利用ください。**
- TVerRecはPowerShell CoreをインストールしたWindows/Mac/Linuxで動作します。
- WindowsでPowerShell Coreがインストールされていない場合は、TVerRecが自動的にPowerShell Coreをインストールします。
- Windowsに手動でPowerShell Coreをインストールする方法やMac、LinuxへのPowerShellのインストールについては[Wikiのこちらのページ](https://github.com/dongaba/TVerRec/wiki/PowerShell%E3%81%AE%E3%82%A4%E3%83%B3%E3%82%B9%E3%83%88%E3%83%BC%E3%83%AB)を参照してください。
- Dockerイメージも[配布中](https://hub.docker.com/r/dongaba/tverrec)です。
- 安定版は[リリース](https://github.com/dongaba/TVerRec/releases)から取得してください。

## 動作の前提条件

- OS
  - Windows
  - Mac
  - Linux

- 必要なソフトウェア
  - PowerShell Core (Windows環境では自動インストールされます)
  - youtube-dl (自動ダウンロードされます)
  - ffmpeg (自動ダウンロードされます)
  - Python (Linux/Macのみ必要。Windowsでは不要)

- 推奨ライブラリ
  - PyCryptodome (Linux/Mac環境でダウンロードが高速化します)

または、Dockerを使ってコンテナとして動作させることも可能です。
コンテナはUbuntu Linuxのイメージで作成されており、必要なツールは全て設定済みの状態で起動します。
設定ファイルを用意・修正し、ディスクのマウント・バインドを設定すればすぐに利用開始できます。

## Windows GUI版の動作イメージ

![GUIMain](https://github.com/user-attachments/assets/35d6e486-094a-4e7d-84fb-e8cdf88fbeb0)
![GUISetting](https://github.com/user-attachments/assets/1e53fcd8-55db-4429-9064-66cb4facbe30)

## Windows CUI版の動作イメージ

![CUI](https://github.com/user-attachments/assets/728d618b-43ab-43fb-a4df-02108ca2e4fd)

## 主な機能

各機能の詳細は[Wikiのこちらのページ](https://github.com/dongaba/TVerRec/wiki/)を参照してください。

1. 番組の**ジャンル**や**出演タレント**、**番組名**などの**キーワード指定**して**一括ダウンロード**します。
2. TVerの**マイページに登録した番組、特集など**からの一括ダウンロード
3. TVerの**全録**が可能です。
4. TVerの**番組サムネイルをダウンロードファイルに埋め込み**ます。
5. 字幕データがTVerにある場合は、**字幕情報もダウンロードファイルに埋め込み**ます。
6. 並列ダウンロードによる**高速ダウンロード**が可能です。(当方環境では1Gbpsの回線で1Gbpsでダウンロード可能)
7. もちろん**番組を1本ずつ指定したダウンロード**も可能です。
8. また、ダウンロードした**番組が破損していないかの検証**も行います。
9. ダウンロードされたファイルは、最終移動先に**自動的に整理**可能です。
10. 動作に必要なyoutube-dlやffmpegなどの必要コンポーネントは**自動的に最新版がダウンロード**されます。
11. トースト通知により動作状況を通知します。
12. TVerRecの安定版が更新されるとアップデートが通知されます。
13. Windows環境のみGUIも利用可能です。
14. 曜日時間帯別にダウンロードの実行可否を指定可能です。
15. Geo IPチェック回避としてProxyサーバを指定可能です。ProxyはGeo IPチェックの回避のみ使用されます。

## 使い方

使い方については[Wikiのこちらのページ](https://github.com/dongaba/TVerRec/wiki/TVerRec%E3%81%AE%E4%BD%BF%E3%81%84%E6%96%B9)を参照してください。
それ以外についても、ご不明点があれば[Wiki](https://github.com/dongaba/TVerRec/wiki)を確認するようにしてください。

## ダウンロード対象の設定

ダウンロード対象番組の設定方法については[Wikiのこちらのページ](https://github.com/dongaba/TVerRec/wiki/%E3%83%80%E3%82%A6%E3%83%B3%E3%83%AD%E3%83%BC%E3%83%89%E5%AF%BE%E8%B1%A1%E7%95%AA%E7%B5%84%E3%81%AE%E8%A8%AD%E5%AE%9A)を参照してください。

## 環境設定方法

初期設定や環境設定の方法については[Wikiのこちらのページ](https://github.com/dongaba/TVerRec/wiki/%E5%88%9D%E6%9C%9F%E8%A8%AD%E5%AE%9A%E3%83%BB%E7%92%B0%E5%A2%83%E8%A8%AD%E5%AE%9A%E3%81%AE%E6%96%B9%E6%B3%95)を参照してください。

## ディレクトリ構成

ディレクトリ構成は以下のようになっています。

    TVerRec/
    ├─ CHANGELOG.md ...................... 変更履歴
    ├─ LICENSE ........................... ライセンス
    ├─ README.md ......................... このファイル
    ├─ TODO.md ........................... 今後の改善予定
    ├─ VERSION ........................... バージョンファイル
    │
    ├─ bin/ .............................. 実行ファイル格納用ディレクトリ(初期状態は空)
    │
    ├─ conf/ ............................. 設定
    │  ├─ ignore.conf ...................... ダウンロード対象外設定ファイル(存在しない場合は自動作成)
    │  ├─ keyword.conf ..................... ダウンロード対象キーワードファイル(存在しない場合は自動作成)
    │  ├─ system_setting.ps1 ............... デフォルトシステム設定ファイル
    │  └─ user_setting.ps1 ................. ユーザ設定ファイル(必要に応じて自分で作成してください)
    │
    ├─ db/ ............................... データベース
    │  ├─ history.csv ...................... ダウンロード履歴(存在しない場合は自動作成)
    │  └─ list.csv ......................... ダウンロードリスト(存在しない場合は自動作成)
    │
    ├─ log/ .............................. ログ
    │  ├─ ffmpeg_err_*.log ................. ffmpegのエラーログ(処理中に作成され一定時間経過後に自動削除)
    │  ├─ ytdl_err_*.log ................... youtube-dlの実行ログ(処理中に作成され一定時間経過後に自動削除)
    │  └─ ytdl_out_*.log ................... youtube-dlのエラーログ(処理中に作成され一定時間経過後に自動削除)
    │
    ├─ resources/ ........................ 各種リソース
    │  ├─ b64/ ........................... GUI用画像(配下のファイルは省略)
    │  ├─ colab/ ......................... Gooble Colab用サンプル(配下のファイルは省略)
    │  ├─ crx/ ........................... Gooble Chrome拡張機能
    │  │  └─ TVerRecAssistant/ ............. TVerRec Assistant(配下のファイルは省略)
    │  ├─ docker/ ........................ Docker用サンプル
    │  │  ├─ docker-compose.yaml ........... docker-composeファイル
    │  │  └─ Dockerfile .................... Dockerファイル
    │  ├─ img/ ........................... 画像(配下のファイルは省略)
    │  ├─ lib/ ........................... ライブラリ(配下のファイルは省略)
    │  ├─ lang/ .......................... 言語ファイル
    │  │  └─ message.json .................. メッセージ定義ファイル
    │  ├─ lock/ .......................... ファイルのロック管理(配下のファイルは省略)
    │  ├─ sample/ ........................ サンプルファイル
    │  │  ├─ history.sample.csv ............ 空のダウンロード履歴
    │  │  ├─ ignore.sample.conf ............ サンプルダウンロード対象外設定ファイル
    │  │  ├─ keyword.sample.conf ........... サンプルダウンロード対象キーワードファイル
    │  │  └─ list.sample.csv ............... 空のダウンロードリスト
    │  ├─ wsb/ ........................... Windows SandBox用サンプル(配下のファイルは省略)
    │  └─ xaml/ .......................... GUI版のXAML定義(配下のファイルは省略)
    │
    ├─ src/ .............................. 各種ソース
    │  ├─ delete_trash.ps1 ................. ダウンロード対象外番組削除ツール
    │  ├─ download_bulk.ps1 ................ 一括ダウンロードツール
    │  ├─ download_list.ps1 ................ リストダウンロードツール
    │  ├─ download_single.ps1 .............. 単体ダウンロードツール
    │  ├─ generate_list.ps1 ................ ダウンロードリスト作成ツール
    │  ├─ generate_list_child.ps1 .......... ダウンロードリスト作成ツール再帰呼び出し用
    │  ├─ loop.ps1 ......................... ループ処理ツール
    │  ├─ move_vide.ps1 .................... 番組を移動先に移動するツール
    │  ├─ validate_video.ps1 ............... ダウンロード済番組の整合性チェックツール
    │  ├─ functions/ ....................... 各種共通関数
    │  │  ├─ common_functions.ps1 ............ 共通関数定義
    │  │  ├─ initialize.ps1 .................. 各ツールの初期処理定義
    │  │  ├─ initialize_child.ps1 ............ 各ツールの初期処理定義再帰呼び出し用
    │  │  ├─ tver_functions.ps1 .............. TVer共通関数定義
    │  │  ├─ tverrec_functions.ps1 ........... TVerRec共通関数定義
    │  │  ├─ update_ffmpeg.ps1 ............... ffmpeg自動更新ツール
    │  │  ├─ update_tverrec.ps1 .............. TVerRec自身の自動更新ツール
    │  │  └─ update_youtube-dl.ps1 ........... youtube-dl自動更新ツール
    │  └─ gui/ ............................. GUI設定
    │     ├─ gui_main.ps1 .................... GUI版のTVerRecを起動するツール
    │     └─ gui_setting.ps1 ................. TVerRecの設定用画面を起動するツール
    │
    ├─ test/ ............................... 自動テスト用スクリプト(配下のファイルは省略)
    │
    ├─ unix/ ............................. Linux/Mac用シェルスクリプト
    │  ├─ a.download_bulk.sh ............... キーワードを元一括ダウンロードするシェルスクリプト
    │  ├─ b.delete_trash.sh ................ ダウンロード対象外番組・中間ファイル削除シェルスクリプト
    │  ├─ c.validate_video.sh .............. ダウンロード済番組の整合性チェックシェルスクリプト
    │  ├─ d.move_video.sh .................. 番組を移動先に移動するシェルスクリプト
    │  ├─ start_tverrec.sh ................. キーワードを元に無限一括ダウンロード起動シェルスクリプト
    │  ├─ stop_tverrec.sh .................. 無限一括ダウンロード終了シェルスクリプト
    │  ├─ update_tverrec.sh ................ TVerRecのアップデートをするシェルスクリプト
    │  ├─ x.generate_list.sh ............... ダウンロードリストを生成するシェルスクリプト
    │  ├─ y.download_list.sh ............... ダウンロードリストを元にダンロードするシェルスクリプト
    │  └─ z.download_single.sh ............. 番組を1本ずつダウンロードするシェルスクリプト
    │
    └─ win/ .............................. Windows用CMDファイル
       ├─ a.download_bulk.cmd .............. キーワードを元一括ダウンロードするCMD
       ├─ b.delete_trash.cmd ............... ダウンロード対象外番組・中間ファイル削除CMD
       ├─ c.validate_video.cmd ............. ダウンロード済番組の整合性チェックCMD
       ├─ d.move_video.cmd ................. 番組を移動先に移動するCMD(もし必要であれば)
       ├─ Setting.cmd ...................... TVerRecの設定用画面を起動するCMD
       ├─ start_tverrec.cmd ................ キーワードを元に無限一括ダウンロード起動CMD
       ├─ stop_tverrec.cmd ................. 無限一括ダウンロード終了CMD
       ├─ TVerRec.cmd ...................... GUI版のTVerRecを起動するCMD
       ├─ update_tverrec.cmd ............... TVerRecのアップデートをするCMD
       ├─ x.generate_list.cmd .............. ダウンロードリストを生成するCMD
       ├─ y.download_list.cmd .............. ダウンロードリストを元にダンロードするCMD
       └─ z.download_single.cmd ............ 番組を1本ずつダウンロードするCMD

## 注意事項

- 著作権
  - このプログラムの著作権はdongabaが保有しています。

- 免責
  - このソフトウェアを使用して発生したいかなる損害にも、作者は責任を負わないものとします。
    ご利用の際は各自の自己責任で使用してください。

## ライセンス

- TVerRecは[The MIT License](https://opensource.org/licenses/MIT)に基づき、複製や再配布、改変が許可されます。

Copyright (c) dongaba. All rights reserved.
