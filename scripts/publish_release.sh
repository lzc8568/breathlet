#!/usr/bin/env bash
#
# 发布 Breathlet DMG 到 here.now 下载页（保留最近 3 个版本），并生成
# latest.json 供 App「检查更新」使用。
#
# 用法：
#   ./scripts/publish_release.sh /path/to/Breathlet.dmg [版本号]
#   SLUG=xxx ./scripts/publish_release.sh Breathlet.dmg 1.3.2
#
set -euo pipefail

# 留空则自动读取上次发布的 slug；首次发布自动生成
SLUG="${SLUG:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SITE_DIR="$ROOT/release_site"
DMG="${1:?用法: $0 /path/to/Breathlet.dmg [版本号]}"
VERSION="${2:-$(basename "$DMG" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)}"
VERSION="${VERSION:-latest}"

mkdir -p "$SITE_DIR"

# 定位 here-now 发布脚本：优先仓库内置副本（CI 无本地 skill）
HERE_PUBLISH="${HERENOW_PUBLISH_SCRIPT:-}"
if [ -z "$HERE_PUBLISH" ]; then
  for cand in "$ROOT/scripts/herenow/publish.sh" \
              "$HOME/.agents/skills/here-now/scripts/publish.sh" \
              "$HOME/.claude/skills/here-now/scripts/publish.sh"; do
    if [ -f "$cand" ]; then HERE_PUBLISH="$cand"; break; fi
  done
fi
[ -n "$HERE_PUBLISH" ] || { echo "错误：找不到 here-now publish.sh，请设置 HERENOW_PUBLISH_SCRIPT" >&2; exit 1; }

# CI 场景 release_site 是空目录：先从下载页预取已有 DMG，保证「保留最近 3 个版本」
if [ -n "${RELEASE_BASE_URL:-}" ]; then
  echo "→ 从 $RELEASE_BASE_URL 预取已有 DMG..."
  existing=$(curl -sL "$RELEASE_BASE_URL/" \
    | grep -oE 'Breathlet-[0-9]+\.[0-9]+\.[0-9]+\.dmg' | sort -u || true)
  for f in $existing; do
    [ -f "$SITE_DIR/$f" ] || curl -sL -o "$SITE_DIR/$f" "$RELEASE_BASE_URL/$f" || true
  done
  ls -1 "$SITE_DIR"/*.dmg 2>/dev/null | xargs -r -n1 basename
fi

# 1. 放入新 DMG
cp "$DMG" "$SITE_DIR/Breathlet-${VERSION}.dmg"
echo "→ 已加入 Breathlet-${VERSION}.dmg"

# 2. 只保留最近 3 个版本（按版本号排序，CI 预取场景下 mtime 不可靠）
cd "$SITE_DIR"
ls ./*.dmg 2>/dev/null | sort -V -r | tail -n +4 | while read -r old; do
  rm -- "$old"
  echo "→ 已移除旧版本: $(basename "$old")"
done

# 3. 图标（若有）：用于下载页顶部
if [ -f "$ROOT/docs/breathlet-icon.png" ]; then
  cp "$ROOT/docs/breathlet-icon.png" "$SITE_DIR/icon.png"
fi

# 4. 生成 index.html（最新在前，最多 3 个）+ latest.json（App 检查更新用）
BASE_URL="${RELEASE_BASE_URL:-}"
python3 - "$BASE_URL" <<'PY'
import glob
import json
import os
import re
import sys
import time

base_url = sys.argv[1] or ""

# 按版本号（主.次.修）降序排，保证「最新在前」且保留最近 3 个版本
def vkey(name):
    m = re.search(r"(\d+)\.(\d+)\.(\d+)", name)
    return tuple(map(int, m.groups())) if m else (0, 0, 0)

files = sorted(glob.glob("*.dmg"), key=vkey, reverse=True)[:3]
nonce = int(time.time())  # 每次构建变化，避免 here.now 全文件跳过时的上传 bug
cards = []
for f in files:
    ver = f.replace("Breathlet-", "").replace(".dmg", "")
    size_mb = os.path.getsize(f) / 1048576.0
    date = time.strftime("%Y-%m-%d", time.localtime(os.path.getmtime(f)))
    cards.append(f"""
      <a class="card" href="{f}" download>
        <div class="ver">v{ver}</div>
        <div class="meta">
          <span>{date}</span>
          <span>{size_mb:.1f} MB</span>
        </div>
        <div class="btn">下载 DMG</div>
      </a>""")

html = f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Breathlet · 下载</title>
  <!-- build: {nonce} -->
  <style>
    * {{ margin: 0; padding: 0; box-sizing: border-box; }}
    body {{
      font-family: -apple-system, "PingFang SC", "Microsoft YaHei", sans-serif;
      background: #f4f7fb; color: #22303f; min-height: 100vh;
      display: flex; flex-direction: column; align-items: center; padding: 40px 16px 60px;
    }}
    .logo {{
      width: 96px; height: 96px; border-radius: 22px; overflow: hidden;
      box-shadow: 0 8px 24px rgba(30, 60, 140, .22); margin-bottom: 18px;
    }}
    .logo img {{ width: 100%; height: 100%; display: block; }}
    h1 {{ font-size: 26px; font-weight: 800; }}
    .sub {{ color: #6b7c92; margin: 8px 0 28px; font-size: 14px; text-align: center; }}
    .tip {{ color: #8a97a8; font-size: 12px; margin-top: 24px; text-align: center; line-height: 1.7; }}
    .releases {{ width: 100%; max-width: 420px; display: flex; flex-direction: column; gap: 12px; }}
    .card {{
      background: #fff; border-radius: 14px; padding: 16px; text-decoration: none; color: inherit;
      display: flex; align-items: center; gap: 14px; box-shadow: 0 4px 16px rgba(30,60,140,.10);
      transition: transform .15s, box-shadow .15s;
    }}
    .card:active {{ transform: scale(.97); }}
    .ver {{ font-size: 20px; font-weight: 800; color: #1f4fd8; min-width: 72px; }}
    .meta {{ flex: 1; color: #6b7c92; font-size: 13px; display: flex; flex-direction: column; gap: 2px; }}
    .btn {{
      background: #1f4fd8; color: #fff; padding: 8px 16px; border-radius: 999px;
      font-size: 14px; font-weight: 600;
    }}
  </style>
</head>
<body>
  <div class="logo"><img src="icon.png" alt="Breathlet"></div>
  <h1>Breathlet</h1>
  <p class="sub">A tiny menu bar reminder to rest your eyes during focused work.</p>
  <div class="releases">
    {''.join(cards)}
  </div>
  <p class="tip">macOS 13 及以上版本<br>从菜单栏开始，专注时记得休息</p>
</body>
</html>"""

with open("index.html", "w", encoding="utf-8") as f:
    f.write(html)
print(f"→ 已生成 index.html，共 {len(cards)} 个版本")

# App 端检查更新：读取 latest.json 对比版本号，发现新版本提示下载
if files:
    latest = files[0]
    ver = latest.replace("Breathlet-", "").replace(".dmg", "")
    url = f"{base_url}/{latest}" if base_url else latest
    manifest = {
        "version": ver,
        "url": url,
        "size": os.path.getsize(latest),
        "updated_at": time.strftime("%Y-%m-%d", time.localtime(os.path.getmtime(latest))),
    }
    with open("latest.json", "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    print(f"→ 已生成 latest.json（最新版本 v{ver}）")
PY

# 5. 发布到 here.now
#    首次发布自动生成 slug 并写入 release_site/.herenow/state.json；
#    后续发布读取已有 slug 做原地更新。可用 SLUG 环境变量覆盖。
#    ⚠️ publish.sh 对绝对路径的文件映射有 bug，统一在站点目录内以 "." 执行。
SLUG_ARGS=()
STATE="$SITE_DIR/.herenow/state.json"
if [ -n "$SLUG" ]; then
  SLUG_ARGS=(--slug "$SLUG")
elif [ -f "$STATE" ]; then
  # 取最近一次发布的 slug
  SLUG_ARGS=(--slug "$(python3 -c "import json;print(list(json.load(open('$STATE'))['publishes'])[-1])" 2>/dev/null || true)")
fi
cd "$SITE_DIR"

# here.now API 偶发失败（Not found / 上传失败），自动重试最多 5 次
publish_ok=0
for attempt in 1 2 3 4 5; do
  echo "→ 发布尝试 $attempt/5..."
  if bash "$HERE_PUBLISH" . "${SLUG_ARGS[@]}" --client codex --title "Breathlet · 下载" >/tmp/breathlet_publish.log 2>&1; then
    publish_ok=1
    tail -6 /tmp/breathlet_publish.log
    break
  fi
  echo "  失败：$(tail -1 /tmp/breathlet_publish.log)"
  sleep 5
done
if [ "$publish_ok" != 1 ]; then
  echo "发布失败，请稍后重试（日志见 /tmp/breathlet_publish.log）"
  exit 1
fi

# 6. 发布成功后只保留当前 slug，避免 state 越积越多
python3 - "$SITE_DIR" <<'PY'
import json
import sys
import pathlib

site_dir = sys.argv[1]
state_path = pathlib.Path(site_dir) / ".herenow" / "state.json"
try:
    st = json.loads(state_path.read_text(encoding="utf-8"))
except Exception:
    st = {"publishes": {}}
slug = next(reversed(st.get("publishes", {})), "")
if slug:
    keep = {slug: st["publishes"][slug]}
    state_path.write_text(json.dumps({"publishes": keep}, ensure_ascii=False, indent=2), encoding="utf-8")
PY
