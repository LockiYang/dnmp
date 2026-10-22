# PHP 7.4 安全回补镜像

构建链路：Alpine → 编译回补版 PHP-FPM 基础镜像 → 仓库原有 Dockerfile 安装扩展 → php74 服务。
原有默认 Compose 文件无需改动。所有命令在仓库根目录执行。

## 1. 编译基础镜像

需要 Docker（已启动）、curl 和 Python 3，构建过程需要访问 GitHub 和 Alpine 软件源。

```bash
bash services/php74/backports/build.sh
```

脚本固定以下来源，避免分支移动导致构建内容变化：

- PHP 回补源码：`shivammathur/php-src-backports` 提交 `9f3f6763497aa556d3fc56df7e66f44b8de49815`。
- 官方 PHP 镜像构建模板：`docker-library/php` 提交 `b9f17156020c3aef71df681b27684533529347a7` 的 `7.4/alpine3.16/fpm/`。

脚本替换官方源码下载步骤、加入 Git 源码需要的 buildconf/bison，保留官方安装路径、入口脚本、FPM 配置和 docker-php-ext-* 工具。
下载的源码归档 SHA256 会显示在终端并写入镜像标签；这是构建记录，不是独立来源的签名验证。

生成基础镜像：`dnmp/php74-base:7.4.33-backports-9f3f6763497a`。

## 2. 安装仓库配置的扩展

```bash
docker compose -f docker-compose.yml -f docker-compose.php74-patched.yml build php74
```

此步骤使用 `.env` 中的 `PHP74_EXTENSIONS`，生成完整运行镜像：
`dnmp/php74:7.4.33-backports-9f3f6763497a`。

## 3. 检查并启动

```bash
docker compose -f docker-compose.yml -f docker-compose.php74-patched.yml run --rm --no-deps php74 php -v
docker compose -f docker-compose.yml -f docker-compose.php74-patched.yml run --rm --no-deps php74 php -m
docker compose -f docker-compose.yml -f docker-compose.php74-patched.yml run --rm --no-deps php74 php-fpm -t
docker compose -f docker-compose.yml -f docker-compose.php74-patched.yml up -d --no-deps php74
docker compose -f docker-compose.yml -f docker-compose.php74-patched.yml exec php74 printenv PHP_BACKPORTS_COMMIT
```

新服务名称为 `php74`。如果 Nginx 位于同一 Compose 网络，站点配置的 FastCGI 地址应为 `php74:9000`，然后检查并重载 Nginx。这里不发布宿主机端口。
如果已使用其他 Compose 文件运行 PHP 服务，应修改那个服务的 `build.args.PHP_VERSION` 为上述基础镜像名，并重新构建、重建该服务，避免另起一套服务。
`.env` 中的 `PHP74_VERSION=7.4.33` 可以保留；本示例直接传入完整基础镜像名。

确认来源可以执行：

```bash
docker image inspect dnmp/php74:7.4.33-backports-9f3f6763497a --format '{{json .Config.Labels}}'
```

## 维护范围和限制

- 此提交包含 CVE-2026-109618、CVE-2026-109619 的官方 EOL 最小缓解回补，不能等同于受支持分支的完整修复方案。
- `php -v` 仍可能显示 7.4.33，应同时检查源码提交记录。
- 沿用官方 7.4 镜像的 Alpine 3.16 是为了兼容当前扩展脚本；这个旧系统本身已经停止常规安全维护。本方案解决的是 PHP 源码回补，不等于整个镜像的依赖都获得持续安全更新。
- 没有自动更新机制。以后核对新补丁提交后，需要更新脚本中的 SHA 和两处镜像标签，并重新构建两个镜像、重建容器。
- 构建默认针对当前 Docker 架构。Mac ARM 构建的镜像不能直接部署到 x86 Linux，应在目标架构构建或另外配置 buildx。
- 当前仓库的 Composer/扩展下载逻辑保持原样，完整镜像仍需要实机构建和业务验证。

来源：

- https://github.com/shivammathur/php-src-backports/commit/9f3f6763497aa556d3fc56df7e66f44b8de49815
- https://github.com/php/php-src/commit/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2
- https://github.com/docker-library/php/tree/b9f17156020c3aef71df681b27684533529347a7/7.4/alpine3.16/fpm
