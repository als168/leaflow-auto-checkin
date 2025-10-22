# Leaflow 自动签到脚本

![Python](https://img.shields.io/badge/Python-3.7%2B-blue)
![License](https://img.shields.io/badge/License-MIT-green)

* TG交流反馈群组：https://t.me/eooceu
* youtube视频教程：https://www.youtube.com/@eooce


Leaflow 多账号自动签到脚本，支持 Telegram 通知和 GitHub Actions 自动化运行。

## 功能特性

- ✅ 支持多个 Leaflow 账号自动签到
- 🤖 基于 Selenium 实现自动化操作
- 📱 自动处理网站弹窗和验证码
- 📢 支持 Telegram 通知推送
- ⏰ 支持 GitHub Actions 定时自动执行
- 🔄 智能重试机制，提高签到成功率
- 📊 详细的日志记录和错误处理

## 使用方法

### 注册Leaflow账号：https://leaflow.net/login

### 首次请在控制台签到页面授权，否则签到失败

#### 配置账号信息

脚本支持两种种方式配置账号信息：

##### 方式一：单个账号
```bash
LEAFLOW_EMAIL    your_email@example.com
LEAFLOW_PASSWORD    your_password
```

##### 方式二：多个账号（分隔符方式，向后兼容）
```bash
变量名：LEAFLOW_ACCOUNTS
变量值：邮箱1:密码1,邮箱2:密码2,邮箱3:密码3
```


### GitHub Actions 自动运行

1. Fork 本仓库
2. 在仓库 Settings > Secrets and variables > Actions 中添加以下 secrets：
   - `LEAFLOW_ACCOUNTS`: 账号信息(账号密码之间英文冒号分隔,多账号之间英文逗号分隔)

Telegram 通知配置（可选，不需要tg通知可不填）
   - `TELEGRAM_BOT_TOKEN`   Telegram Bot Token，https://t.me/BotFather 创建机器人
   - `TELEGRAM_CHAT_ID`     Telegram Chat ID，https://t.me/laowang_serv00_bot 发送 /start 获取

3. 启用 Actions 启用工作流

## 配置说明

| 环境变量 | 必需 | 说明 |
|---------|------|------|
| `LEAFLOW_EMAIL` | 否* | 单个账号邮箱（方式一） |
| `LEAFLOW_PASSWORD` | 否* | 单个账号密码（方式一） |
| `LEAFLOW_ACCOUNTS` | 否* | 多个账号密码，逗号分隔（方式二,推荐） |
| `TELEGRAM_BOT_TOKEN` | 否 | Telegram Bot Token |
| `TELEGRAM_CHAT_ID` | 否 | Telegram Chat ID |

*注：以上账号配置方式至少需要配置一种


## 注意事项
- 请确保在签到页面已授权
- 请确保账号信息正确无误,并正确配置secrets
- 脚本会在账号间间隔 10 秒钟，避免请求过于频繁
- 在 GitHub Actions 中运行时，脚本会自动使用无头模式（headless mode）
- 请遵守网站的使用条款，合理使用自动化脚本

## Alpine VPS 容器（TUIC + Hysteria2）

为方便在轻量级环境中部署 TUIC 与 Hysteria2 代理，仓库新增了基于最新 Alpine Linux 的容器化方案。

### 构建镜像

```bash
# 直接构建（默认安装最新版本的 tuic-server 与 hysteria 二进制）
docker build -t leaflow/alpine-vps .

# 或通过 docker compose
docker compose build
```

可通过构建参数自定义版本或跳过构建时的自动安装：

```bash
docker build \
  --build-arg TUIC_VERSION=tuic-server-1.0.0 \
  --build-arg HY2_VERSION=app/v2.6.4 \
  --build-arg INSTALL_AT_BUILD=false \
  -t leaflow/alpine-vps .
```

### 运行容器

使用 docker compose 示例：

```bash
mkdir -p data/tuic data/hysteria data/runtime
docker compose up -d
```

默认暴露端口：

- `443/udp`：TUIC QUIC 服务端口
- `8443/udp`：Hysteria2 推荐监听端口
- `1080/tcp`：可用于本地调试或 SOCKS/HTTP 代理

如需自定义端口或协议，请在 `docker-compose.yml` 中调整 `ports` 配置。

容器会自动挂载下列持久化目录：

- `./data/tuic -> /etc/tuic`
- `./data/hysteria -> /etc/hysteria`
- `./data/runtime -> /srv/proxy`

如需在容器内部以非 root 用户运行代理，可在 `docker-compose.yml` 中追加 `user: proxy`，或在自定义入口脚本中使用 `su - proxy` 切换用户；若需要配置 iptables 或管理低号端口，则保持默认的 root 权限。

> 提示：TUIC 与 Hysteria2 均需要 UDP 端口可达，为保证正常工作请打开宿主机对应的 UDP 端口并保留 `cap_add: [NET_ADMIN]` 与 `sysctls` 设置（用于容器内 iptables/IPv4 转发）。

### 安装脚本

容器内置 `install-tuic-hy2`（位于 `/usr/local/bin/install-tuic-hy2`）。如果需要重新安装或更换版本，可在容器内执行：

```bash
install-tuic-hy2 --tuic-version tuic-server-1.0.0 --hy2-version app/v2.6.4
```

常用参数：

- `--prefix`：指定二进制安装路径（默认 `/usr/local/bin`）
- `--config-root`：配置文件根目录（默认 `/etc`）
- `--keep-archive`：保留下载文件，便于离线分发

脚本会根据容器架构自动匹配对应的 musl 构建，并生成配置目录 `/etc/tuic` 与 `/etc/hysteria`。

### 基本配置示例

TUIC (`/etc/tuic/server.json`)：

```json
{
  "server": {
    "certificate": "/etc/tuic/cert.pem",
    "private_key": "/etc/tuic/key.pem"
  },
  "users": {
    "user1": {
      "password": "replace-with-secure-password"
    }
  },
  "listen": "0.0.0.0:443",
  "congestion_control": "bbr"
}
```

Hysteria2 (`/etc/hysteria/config.yaml`)：

```yaml
listen: :8443
acme: false
cert: /etc/hysteria/cert.pem
key: /etc/hysteria/key.pem
auth:
  type: password
  password: replace-with-secure-password
transport:
  udp:
    hopInterval: 30s
```

启动命令示例：

```bash
# TUIC server
tuic-server -c /etc/tuic/server.json

# Hysteria2 server
hysteria server --config /etc/hysteria/config.yaml
```

根据需要可结合 `supervisord`、`s6-overlay` 或 systemd-nspawn 等进程管理器进一步自动化，也可以在 docker compose 中通过 `command`/`entrypoint` 指定启动脚本。

## 许可证
GPL 3.0

## 郑重声明
* 禁止新建项目将代码复制到自己仓库中用做商业行为，违者必究
* 用于商业行为的任何分支必须完整保留本项目说明，违者必究
* 请遵守当地法律法规,禁止滥用做公共代理行为
