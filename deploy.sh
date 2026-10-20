#!/bin/bash
# ================================================
# 智能旅行规划 Web 版 · 部署脚本
# (备份 .env/数据 → 推送代码 → 同步前端 dist → 重建容器 → 健康检查)
# 用法: bash deploy.sh [服务器别名，默认 aliyun-stock]
# 说明: 服务器端目录 ~/travel-agent-web, 后端 Docker 容器 trip-planner-web
#       (宿主机 127.0.0.1:8002 → 容器 8000), 对外由 nginx web.lwylangchain.cn 反代
# ================================================
set -e

# 始终切到脚本所在仓库目录, 避免在其他目录执行时 git 操作到错误仓库
cd "$(dirname "$0")"

SERVER="${1:-aliyun-stock}"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  旅行规划 Web 版 · 部署到 ${SERVER}${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# ---- 1. 推送本地代码到 GitHub ----
echo -e "${YELLOW}[1/5] 推送代码到 GitHub...${NC}"
git add -A
if git diff --cached --quiet; then
    echo "  没有需要提交的改动"
else
    git commit -m "部署: ${TIMESTAMP}"
fi
git push origin master
echo -e "${GREEN}  GitHub 推送完成${NC}"
echo ""

# ---- 2. 服务器备份 (仅 .env 与 data 数据卷; 代码由 git 管理无需备份) ----
echo -e "${YELLOW}[2/5] 备份服务器 .env 与数据...${NC}"
ssh "${SERVER}" "
    set -e
    if [ ! -d ~/travel-agent-web ]; then
        echo '  首次部署, 跳过备份'
        exit 0
    fi
    BACKUP_DIR=~/travel-web-backups/${TIMESTAMP}
    mkdir -p \${BACKUP_DIR}
    cd ~/travel-agent-web/backend
    FAIL=0
    cp .env \${BACKUP_DIR}/ 2>/dev/null || { echo '  ⚠️ .env 不存在, 跳过'; }
    cp -r data \${BACKUP_DIR}/data 2>/dev/null || { echo '  ❌ data/ 备份失败'; FAIL=1; }
    if [ \$FAIL -eq 1 ]; then echo '  备份不完整, 中止部署'; exit 1; fi
    echo '  备份完成: '\${BACKUP_DIR}
"
echo ""

# ---- 3. 服务器拉取最新代码 ----
echo -e "${YELLOW}[3/5] 服务器拉取代码...${NC}"
ssh "${SERVER}" "
    set -e
    if [ ! -d ~/travel-agent-web ]; then
        git clone git@github.com:lwyKunKun/travel-agent.git ~/travel-agent-web
    else
        cd ~/travel-agent-web && git fetch origin && git reset --hard origin/master
    fi
"
echo -e "${GREEN}  代码同步完成${NC}"
echo ""

# ---- 4. 同步前端 dist 与 .env (均不在 git 内) ----
# dist 由本地 npm run build 产出, nginx 直接从 /var/www/travel-web/dist 托管
# (.DS_Store 等无关文件不同步); .env 含密钥不入库, 服务器旧配置已在第2步备份,
# 每次同步以便模型/API配置变更能随部署生效
echo -e "${YELLOW}[4/5] 同步前端 dist 与 .env...${NC}"
rsync -az --delete --exclude=.DS_Store frontend/dist/ "${SERVER}:/var/www/travel-web/dist/"
ssh "${SERVER}" 'chown -R www-data:www-data /var/www/travel-web'
rsync -az backend/.env "${SERVER}:~/travel-agent-web/backend/.env"
echo -e "${GREEN}  dist 与 .env 同步完成${NC}"
echo ""

# ---- 5. 重建容器 + 健康检查 ----
# chown 1000:1000: 容器内以非 root 用户 appuser(uid=1000) 运行,
# 宿主机 data/logs 目录若为 root 属主, 容器内写 SQLite 会报 unable to open database file
echo -e "${YELLOW}[5/5] 重建容器并健康检查...${NC}"
ssh "${SERVER}" "
    set -e
    cd ~/travel-agent-web/backend && \
    mkdir -p data logs && \
    chown -R 1000:1000 data logs && \
    docker compose up -d --build 2>&1 | tail -5 && \
    docker image prune -f >/dev/null
"
sleep 8
HEALTH=$(ssh "${SERVER}" "curl -s -m 10 http://localhost:8002/health || echo FAIL")
if echo "${HEALTH}" | grep -q '"healthy"'; then
    echo -e "${GREEN}  ✅ 服务健康: ${HEALTH}${NC}"
else
    echo -e "${RED}  ❌ 健康检查失败: ${HEALTH}${NC}"
    echo -e "${RED}  查看日志: ssh ${SERVER} 'docker logs --tail 50 trip-planner-web'${NC}"
    exit 1
fi
echo ""
echo -e "${GREEN}🎉 部署完成: https://web.lwylangchain.cn${NC}"
