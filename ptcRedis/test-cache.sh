#!/bin/bash
# Redis 缓存自动化测试脚本
# 用法: bash test-cache.sh

# ============ 配置 ============
APP_URL="http://localhost:8080"
REDIS_CONTAINER="redis"
BOOT_CMD="./mvnw spring-boot:run"
BOOT_LOG="target/boot.log"
# ==============================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

pass=0
fail=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo -e "  ${GREEN}[PASS]${NC} $desc"
        pass=$((pass + 1))
    else
        echo -e "  ${RED}[FAIL]${NC} $desc"
        echo -e "         期望: $expected"
        echo -e "         实际: $actual"
        fail=$((fail + 1))
    fi
}

assert_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if echo "$haystack" | grep -q "$needle"; then
        echo -e "  ${GREEN}[PASS]${NC} $desc"
        pass=$((pass + 1))
    else
        echo -e "  ${RED}[FAIL]${NC} $desc"
        echo -e "         期望包含: $needle"
        echo -e "         实际内容: $haystack"
        fail=$((fail + 1))
    fi
}

# 用 awk 代替 bc 做浮点比较
assert_lt() {
    local desc="$1" threshold="$2" actual="$3"
    local result
    result=$(awk "BEGIN { print ($actual < $threshold) ? 1 : 0 }")
    if [ "$result" = "1" ]; then
        echo -e "  ${GREEN}[PASS]${NC} $desc (${actual}s < ${threshold}s)"
        pass=$((pass + 1))
    else
        echo -e "  ${RED}[FAIL]${NC} $desc (${actual}s >= ${threshold}s)"
        fail=$((fail + 1))
    fi
}

assert_gt() {
    local desc="$1" threshold="$2" actual="$3"
    local result
    result=$(awk "BEGIN { print ($actual > $threshold) ? 1 : 0 }")
    if [ "$result" = "1" ]; then
        echo -e "  ${GREEN}[PASS]${NC} $desc (${actual}s > ${threshold}s)"
        pass=$((pass + 1))
    else
        echo -e "  ${RED}[FAIL]${NC} $desc (${actual}s <= ${threshold}s)"
        fail=$((fail + 1))
    fi
}

# 提取 JSON 字段的简单函数
json_val() {
    echo "$1" | grep -o "\"$2\":\"[^\"]*\"" | head -1 | sed 's/.*:"\(.*\)"/\1/'
}

# 计时: 直接用 date +%s%N 差值除以 10^9
# 注意: 把两次调用放在同一个 awk 中避免大数精度丢失
elapsed_sec() {
    local start_ns="$1" end_ns="$2"
    awk "BEGIN { printf \"%.3f\", ($end_ns - $start_ns) / 1000000000 }"
}

# ============ 1. 环境准备 ============
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Redis 缓存自动化测试${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

echo -e "${YELLOW}[准备] 检查 Redis 容器...${NC}"
if docker ps --format '{{.Names}}' | grep -q "^${REDIS_CONTAINER}$"; then
    echo "  Redis 容器已运行"
else
    if docker ps -a --format '{{.Names}}' | grep -q "^${REDIS_CONTAINER}$"; then
        docker start "$REDIS_CONTAINER" > /dev/null
        echo "  已启动已有 Redis 容器"
    else
        docker run -d --name "$REDIS_CONTAINER" -p 6379:6379 redis:latest > /dev/null
        echo "  已创建并启动新 Redis 容器"
    fi
fi
sleep 1

docker exec "$REDIS_CONTAINER" redis-cli FLUSHDB > /dev/null 2>&1 || true
echo "  已清空 Redis 数据"
echo ""

# ============ 2. 启动应用 ============
echo -e "${YELLOW}[准备] 启动 Spring Boot 应用...${NC}"
taskkill //F //FI "IMAGENAME eq java.exe" > /dev/null 2>&1 || true
sleep 2

$BOOT_CMD > "$BOOT_LOG" 2>&1 &
BOOT_PID=$!

echo -n "  等待应用就绪"
for i in $(seq 1 40); do
    if curl -s -o /dev/null -w "" "$APP_URL/users/0" 2>/dev/null; then
        echo ""
        echo "  应用已启动 (PID: $BOOT_PID)"
        break
    fi
    if ! kill -0 "$BOOT_PID" 2>/dev/null; then
        echo ""
        echo -e "  ${RED}应用启动失败，查看日志:${NC}"
        tail -15 "$BOOT_LOG" 2>/dev/null
        exit 1
    fi
    echo -n "."
    sleep 1
done
echo ""

# ============ 3. 执行测试 ============
echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  开始测试${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# --- 测试 1: 创建用户 ---
echo -e "${YELLOW}[测试1] POST /users - 创建用户${NC}"
resp=$(curl -s -X POST "$APP_URL/users" \
    -H "Content-Type: application/json" \
    -d '{"id":1,"name":"Alice","email":"alice@test.com"}')
assert_eq "返回 name"      "Alice"          "$(json_val "$resp" name)"
assert_eq "返回 email"     "alice@test.com"  "$(json_val "$resp" email)"

redis_data=$(docker exec "$REDIS_CONTAINER" redis-cli GET "users::1")
assert_contains "Redis 缓存已写入"      "Alice"   "$redis_data"
assert_contains "Redis 含 @class 类型"   "@class"  "$redis_data"
echo ""

# --- 测试 2: 缓存命中 ---
echo -e "${YELLOW}[测试2] GET /users/1 - 缓存命中 (应 < 0.2s)${NC}"
t0=$(date +%s%N)
resp=$(curl -s "$APP_URL/users/1")
t1=$(date +%s%N)
elapsed=$(elapsed_sec "$t0" "$t1")
assert_eq "返回 name" "Alice" "$(json_val "$resp" name)"
assert_lt "响应时间 < 0.2s" "0.2" "$elapsed"
echo ""

# --- 测试 3: 更新用户 ---
echo -e "${YELLOW}[测试3] POST /users - 更新用户${NC}"
resp=$(curl -s -X POST "$APP_URL/users" \
    -H "Content-Type: application/json" \
    -d '{"id":1,"name":"Bob","email":"bob@test.com"}')
assert_eq "返回 name" "Bob" "$(json_val "$resp" name)"
echo ""

# --- 测试 4: 查询更新后数据 ---
echo -e "${YELLOW}[测试4] GET /users/1 - 查询更新后数据${NC}"
resp=$(curl -s "$APP_URL/users/1")
assert_eq "返回 name" "Bob" "$(json_val "$resp" name)"
echo ""

# --- 测试 5: 删除用户 ---
echo -e "${YELLOW}[测试5] DELETE /users/1 - 删除用户${NC}"
resp=$(curl -s -X DELETE "$APP_URL/users/1")
assert_eq "返回 deleted" "deleted" "$resp"
echo ""

# --- 测试 6: 缓存已清除 ---
echo -e "${YELLOW}[测试6] GET /users/1 - 删除后查询 (走原始方法 ~1s)${NC}"
t0=$(date +%s%N)
resp=$(curl -s "$APP_URL/users/1")
t1=$(date +%s%N)
elapsed=$(elapsed_sec "$t0" "$t1")
assert_gt "响应时间 > 0.5s (未命中缓存)" "0.5" "$elapsed"

redis_data=$(docker exec "$REDIS_CONTAINER" redis-cli GET "users::1")
if [ -z "$redis_data" ]; then
    echo -e "  ${GREEN}[PASS]${NC} Redis 中缓存已清除"
    pass=$((pass + 1))
else
    echo -e "  ${RED}[FAIL]${NC} Redis 中仍有缓存数据"
    fail=$((fail + 1))
fi
echo ""

# ============ 4. 结果汇总 ============
total=$((pass + fail))
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  测试结果: ${pass}/${total} 通过${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# ============ 5. 清理 ============
echo -e "${YELLOW}[清理] 停止 Spring Boot 应用...${NC}"
kill "$BOOT_PID" 2>/dev/null || true
echo "  应用已停止"
echo ""
echo "Redis 容器保持运行，可手动停止: docker stop $REDIS_CONTAINER"
echo ""

if [ "$fail" -eq 0 ]; then
    echo -e "${GREEN}全部测试通过!${NC}"
    exit 0
else
    echo -e "${RED}存在 $fail 项失败!${NC}"
    exit 1
fi
