# **🎞TVerRec📺** TVer Bulk download and Save

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

Software to support downloading video programs from TVer, a TV program distribution site in Japan.
TVerRec offers bulk downloading by specifying the program genre, talent, program name, etc.
Since commercials will be automatically excluded, you can keep your favorite programs even after they are no longer available.
Once launched, programs will be downloaded each time a new program is distributed.

- **TVerRec does not support Windows PowerShell, please use PowerShell Core.**
- TVerRec runs on Windows/Mac/Linux with PowerShell Core installed.
- If PowerShell Core is not installed on Windows, TVerRec will automatically install PowerShell Core.
- For information on how to manually install PowerShell Core on Windows, or on Mac or Linux, see [this page on the Wiki](https://github.com/dongaba/TVerRec/wiki/PowerShell%E3%81%AE%E3%82%A4%E3%83%B3%E3%82%B9%E3%83%88%E3%83%BC%E3%83%AB).
- Docker images are also available [here](https://hub.docker.com/r/dongaba/tverrec).
- Get the stable version from [Release](https://github.com/dongaba/TVerRec/releases).

## Prerequisites

- OS
  - Windows
  - Mac
  - Linux

- Required Software
  - PowerShell Core (will be automatically installed on Windows)
  - youtube-dl (will be automatically downloaded)
  - ffmpeg (will be automatically downloaded)
  - Python (required only for Linux/Mac, not required for Windows)

- Recommended Libraries
  - PyCryptodome (for faster downloads for Linux/Mac)

Alternatively, it can be run as a container using Docker.
The container is created with an Ubuntu Linux image and starts with all necessary tools already configured.
You can start using it immediately after preparing and modifying the configuration file and setting the disk mount bindings.

## Operation image of Windows GUI version

![GUIMain](https://github.com/user-attachments/assets/013b70f7-7508-423e-bdb9-3abced9cafc7)
![GUISetting](https://github.com/user-attachments/assets/c77860c0-7665-445c-963f-a45756498cba)

## Operation image of Windows CUI version

![CUI](https://github.com/user-attachments/assets/0a19f90a-ffc0-4d70-acc9-4d77969014c3)

## Main Features

Refer to [this page on the Wiki](https://github.com/dongaba/TVerRec/wiki/) for more information on each feature.

1. **Specify keywords** such as **genre**, **talent**, **program name**, etc. and **bulk download** them.
2. Bulk downloads from TVer's **My Page, including registered programs, specials, etc.**
3. **Record all TVer programs**. (Technically, it is not recording, but downloading.)
4. **Embed TVer's program thumbnails** into the downloaded file
5. **Embed subtitle** into the downloaded files when subtitle data is available in TVer.
6. **Ultra high speed download** by parallel downloading is available. (In my environment, downloading at 1Gbps on a 1Gbps line.)
7. Of course, **individual downloading** by specifying TVer program URL is also available.
8. **Verify the integrity** of the the downloaded files.
9. **Automatically organize** downloaded files into media labrary.
10. **Automatically download the latest required components** (such as youtube-dl and ffmpeg).
11. Toast notifications to keep you informed of the status.
12. Update notification when stable version of TVerRec is updated.
13. GUI is available for Windows.
14. Specify whether or not downloading is available for each day of the week and time.
15. Proxy server can be specified to bypass Geo IP checks; the Proxy is only used for Geo IP checks.

## How to Use

Please refer to [this page on the Wiki](https://github.com/dongaba/TVerRec/wiki/TVerRec%E3%81%AE%E4%BD%BF%E3%81%84%E6%96%B9) for instructions.
For any other questions, please check [Wiki](https://github.com/dongaba/TVerRec/wiki).

## Setting download targets

Please refer to [this page on the Wiki](https://github.com/dongaba/TVerRec/wiki/%E3%83%80%E3%82%A6%E3%83%B3%E3%83%AD%E3%83%BC%E3%83%89%E5%AF%BE%E8%B1%A1%E7%95%AA%E7%B5%84%E3%81%AE%E8%A8%AD%E5%AE%9A) for information on how to set up keyword file for download.

## Configuration

Please refer to [this page on the Wiki](https://github.com/dongaba/TVerRec/wiki/%E5%88%9D%E6%9C%9F%E8%A8%AD%E5%AE%9A%E3%83%BB%E7%92%B0%E5%A2%83%E8%A8%AD%E5%AE%9A%E3%81%AE%E6%96%B9%E6%B3%95) for information on how to complete initial setup.

## Directory structure

Directory structure is as follows.

    TVerRec/
    ├─ CHANGELOG.md ...................... Change Log
    ├─ LICENSE ........................... License
    ├─ README.md ......................... This file
    ├─ TODO.md ........................... ToDo file
    ├─ VERSION ........................... Version File
    │
    ├─ bin/ .............................. Directory to store executable files
    │
    ├─ conf/ ............................. Confgurations
    │  ├─ ignore.conf ...................... Exclusion list file (automatically created)
    │  ├─ keyword.conf ..................... Keyword list file (automatically created)
    │  ├─ system_setting.ps1 ............... Default system setting file
    │  └─ user_setting.ps1 ................. User setting file
    │
    ├─ db/ ............................... Database
    │  ├─ history.csv ...................... Download history file (automatically created)
    │  └─ list.csv ......................... Download list file (automatically created)
    │
    ├─ log/ .............................. Log
    │  ├─ ffmpeg_err_*.log ................. ffmpeg error log file (Automatically created during processing and deleted after a certain period of time)
    │  ├─ ytdl_err_*.log ................... youtube-dl execution log file (Automatically created during processing and deleted after a certain period of time)
    │  └─ ytdl_out_*.log ................... youtube-dl error log file (Automatically created during processing and deleted after a certain period of time)
    │
    ├─ resources/ ........................ Various Resources
    │  ├─ b64/ ........................... Images for GUI
    │  ├─ colab/ ......................... Sample file for Google Colab
    │  ├─ crx/ ........................... Google Chrome extension
    │  │  └─ TVerRecAssistant/ ............. TVerRec Assistant
    │  ├─ docker/ ........................ Sample for Docker
    │  │  ├─ docker-compose.yaml ........... docker-compose file
    │  │  └─ Dockerfile .................... Docker file
    │  ├─ img/ ........................... Images
    │  ├─ lib/ ........................... Library
    │  ├─ lang/ .......................... Language file
    │  │  └─ message.json .................. Message definition file
    │  ├─ lock/ .......................... Lock management files
    │  ├─ sample/ ........................ Sample file
    │  │  ├─ history.sample.csv ............ Empty download history file
    │  │  ├─ ignore.sample.conf ............ Empty exclusion list file
    │  │  ├─ keyword.sample.conf ........... Empty keyword list file with examples
    │  │  └─ list.sample.csv ............... Empty download list file
    │  ├─ wsb/ ........................... Sample of Windows SandBox
    │  └─ xaml/ .......................... XAML definition for GUI
    │
    ├─ src/ .............................. Source Files
    │  ├─ delete_trash.ps1 ................. Tool to delete junk
    │  ├─ download_bulk.ps1 ................ Tool to bulk downlod
    │  ├─ download_list.ps1 ................ Tool to list download
    │  ├─ download_single.ps1 .............. Tool to individual download
    │  ├─ generate_list.ps1 ................ Tool to create download list
    │  ├─ generate_list_child.ps1 .......... Tool to support create download list
    │  ├─ loop.ps1 ......................... Tool to loop process
    │  ├─ move_vide.ps1 .................... Tool to move videos
    │  ├─ validate_video.ps1 ............... Tool to integrity check
    │  ├─ functions/ ....................... Common Functions
    │  │  ├─ common_functions.ps1 ............ Common function
    │  │  ├─ initialize.ps1 .................. Initializer
    │  │  ├─ initialize_child.ps1 ............ Initializer for child process
    │  │  ├─ tver_functions.ps1 .............. TVer function
    │  │  ├─ tverrec_functions.ps1 ........... TVerRec function (loads the files below)
    │  │  ├─ tverrec_*_functions.ps1 ......... TVerRec function (split by purpose)
    │  │  ├─ update_ffmpeg.ps1 ............... ffmpeg auto update tool
    │  │  ├─ update_tverrec.ps1 .............. TVerRec auto update tool
    │  │  └─ update_youtube-dl.ps1 ........... youtube-dl auto update tool
    │  └─ gui/ ............................. GUI
    │     ├─ gui_main.ps1 .................... GUI version of TVerRec
    │     └─ gui_setting.ps1 ................. GUI version of setting tool
    │
    ├─ test/ ............................... Test scripts
    │
    ├─ unix/ ............................. Shellscript for Linux/Mac
    │  ├─ a.download_bulk.sh ............... Script to launch bulk download
    │  ├─ b.delete_trash.sh ................ Script to launch delete junk
    │  ├─ c.validate_video.sh .............. Script to launch integrity check
    │  ├─ d.move_video.sh .................. Script to launch move video
    │  ├─ start_tverrec.sh ................. Script to launch loop processing
    │  ├─ stop_tverrec.sh .................. Script to stop loop processing
    │  ├─ update_tverrec.sh ................ Script to update TVerRec
    │  ├─ x.generate_list.sh ............... Script to update download list
    │  ├─ y.download_list.sh ............... Script to launch list download
    │  └─ z.download_single.sh ............. Script to launch induvidual download
    │
    └─ win/ .............................. CMD files for Windows
       ├─ a.download_bulk.cmd .............. Script to launch bulk download
       ├─ b.delete_trash.cmd ............... Script to launch delete junk
       ├─ c.validate_video.cmd ............. Script to launch integrity check
       ├─ d.move_video.cmd ................. Script to launch move video
       ├─ Setting.cmd ...................... Script to launch GUI version of setting tool
       ├─ start_tverrec.cmd ................ Script to launch loop processing
       ├─ stop_tverrec.cmd ................. Script to stop loop processing
       ├─ TVerRec.cmd ...................... Script to launch GUI version of TVerRec
       ├─ update_tverrec.cmd ............... Script to update TVerRec
       ├─ x.generate_list.cmd .............. Script to update download list
       ├─ y.download_list.cmd .............. Script to launch list download
       └─ z.download_single.cmd ............ Script to launch induvidual download

## Precautions

- Copyright
  - This program is copyrighted by dongaba.

- Disclaimer
  - The author assumes no responsibility for any damage caused by the use of this software.
    Use at your own risk.

## License

- TVerRec may be copied, redistributed and/or modified under [The MIT License](https://opensource.org/licenses/MIT).

Copyright (c) dongaba. All rights reserved.
