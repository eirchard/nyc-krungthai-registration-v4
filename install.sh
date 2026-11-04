#!/usr/bin/env bash
# NYC Krungthai Campus Registration V4 · separate from V3 survey.
set -euo pipefail
cd "$(dirname "$0")"; ROOT="$PWD"
mkdir -p "$ROOT/.local" "$ROOT/private/gas" "$ROOT/docs"
chmod 700 "$ROOT/.local" "$ROOT/private" 2>/dev/null || true
fail(){ printf '\nERROR: %s\n' "$*" >&2; exit 1; }
info(){ printf '\n\033[36m%s\033[0m\n' "$*"; }
need(){ command -v "$1" >/dev/null 2>&1 || fail "กรุณาติดตั้ง $1 ก่อน"; }
for x in node npm npx curl gh git clasp;do need "$x";done
info '=== NYC Krungthai Campus Registration V4 · ติดตั้งแยกจากระบบ V3 ==='
gh auth status >/dev/null 2>&1 || fail 'กรุณารัน gh auth login'
clasp list >/dev/null 2>&1 || fail 'กรุณารัน clasp login และเปิด Google Apps Script API'
OWNER="$(gh api user --jq .login)"
[ -n "$OWNER" ] || fail 'ไม่สามารถอ่านบัญชี GitHub'
STATE="$ROOT/.local/setup.env"
if [ -f "$STATE" ];then
 # Only source state file that this installer writes inside a non-symlink private folder.
 [ -L "$STATE" ] && fail 'พบ symbolic link ในไฟล์การตั้งค่า'
 # shellcheck disable=SC1090
 source "$STATE"
 info "ใช้ค่าติดตั้งเดิม: $REPO / $WORKER_NAME"
else
 read -rp 'GitHub Repository [nyc-krungthai-registration-v4]: ' REPO
 REPO="${REPO:-nyc-krungthai-registration-v4}"
 [[ "$REPO" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]{2,90}$ ]] || fail 'ชื่อ Repository ไม่ถูกต้อง'
 read -rp 'Cloudflare Worker [nyc-krungthai-registration-v4-api]: ' WORKER_NAME
 WORKER_NAME="${WORKER_NAME:-nyc-krungthai-registration-v4-api}"
 [[ "$WORKER_NAME" =~ ^[a-z0-9][a-z0-9-]{2,55}$ ]] || fail 'ชื่อ Worker ไม่ถูกต้อง'
 printf 'กำหนดรหัสผ่าน Admin อย่างน้อย 12 ตัวอักษร: ';IFS= read -rs ADMIN_PASSWORD;printf '\n'
 [ "${#ADMIN_PASSWORD}" -ge 12 ] || fail 'รหัสผ่านสั้นเกินไป'
 SHARED_SECRET="$(node -e "process.stdout.write(require('crypto').randomBytes(32).toString('hex'))")"
 ADMIN_PASSWORD_SHA256="$(ADMIN_PASSWORD_INPUT="$ADMIN_PASSWORD" node -e 'process.stdout.write(require("crypto").createHash("sha256").update(process.env.ADMIN_PASSWORD_INPUT).digest("hex"))')"
 unset ADMIN_PASSWORD
 printf 'REPO=%q\nWORKER_NAME=%q\nSHARED_SECRET=%q\nADMIN_PASSWORD_SHA256=%q\n' "$REPO" "$WORKER_NAME" "$SHARED_SECRET" "$ADMIN_PASSWORD_SHA256" > "$STATE"
 chmod 600 "$STATE"
fi
ORIGIN="https://${OWNER}.github.io"
info '[1/5] สร้าง Google Sheets + Apps Script'
GAS_DIR="$ROOT/private/gas"
if [ ! -f "$GAS_DIR/.clasp.json" ];then
 (cd "$GAS_DIR" && clasp create --type sheets --title 'NYC Krungthai Campus Registration V4 Database') || fail 'สร้าง Google Sheets ไม่สำเร็จ'
fi
cp "$ROOT/apps-script/Code.gs" "$GAS_DIR/Code.gs"
cp "$ROOT/apps-script/appsscript.json" "$GAS_DIR/appsscript.json"
SHARED_SECRET="$SHARED_SECRET" node -e 'const fs=require("fs");fs.writeFileSync(process.argv[1],"function getSharedSecret_(){return "+JSON.stringify(process.env.SHARED_SECRET)+";}\n",{mode:0o600})' "$GAS_DIR/Config.gs"
(cd "$GAS_DIR" && clasp push --force) || fail 'Apps Script push ไม่สำเร็จ'
SCRIPT_ID="$(node -e 'const j=require(process.argv[1]);process.stdout.write(j.scriptId||"")' "$GAS_DIR/.clasp.json")"
printf 'เปิด Google Apps Script: https://script.google.com/d/%s/edit\n' "$SCRIPT_ID"
info '[2/5] เปิด Web App ให้ Cloudflare เรียก API'
printf 'Deploy → New deployment → Web app; Execute as Me; Access Anyone; Authorize; คัดลอก URL /exec\n'
GAS_FILE="$ROOT/.local/gas_url";GAS_URL='';[ -f "$GAS_FILE" ] && GAS_URL="$(cat "$GAS_FILE")"
while :;do
 read -rp "Web App URL [/exec]${GAS_URL:+ (Enter ใช้ค่าเดิม)}: " answer
 GAS_URL="${answer:-$GAS_URL}"
 [[ "$GAS_URL" =~ ^https://script\.google\.com/macros/s/[^/]+/exec$ ]] || { echo 'URL ไม่ถูกต้อง ต้องเป็น /macros/s/.../exec';continue; }
 printf '%s' "$GAS_URL" > "$GAS_FILE";chmod 600 "$GAS_FILE"
 PING="$(SHARED_SECRET="$SHARED_SECRET" node -e 'process.stdout.write(JSON.stringify({action:"ping",secret:process.env.SHARED_SECRET}))')"
 RESPONSE="$(curl -sSL --max-time 35 -H 'Content-Type: application/json' --data "$PING" "$GAS_URL" || true)"
 if printf '%s' "$RESPONSE" | node -e 'let s="";process.stdin.on("data",x=>s+=x);process.stdin.on("end",()=>{try{const a=JSON.parse(s);process.exit(a.ok&&a.ready?0:1)}catch{process.exit(1)}})';then echo '✓ Apps Script พร้อมใช้งาน';break;fi
 echo 'Web App ยังไม่พร้อม: ไปที่ Deploy → Manage deployments → Edit → Version: New version แล้วกด Deploy'
 read -rp 'กด Enter เพื่อใส่ URL อีกครั้ง หรือ q เพื่อหยุด: ' decision
 [ "$decision" = 'q' ] && fail 'หยุดติดตั้งอย่างปลอดภัย รัน bash install.sh อีกครั้งเพื่อทำต่อ'
done
info '[3/5] เผยแพร่ Cloudflare Worker'
WORKER_NAME="$WORKER_NAME" node -e 'const fs=require("fs"),f=process.argv[1];let v=fs.readFileSync(f,"utf8");v=v.replace(/^name\s*=\s*"[^"]+"/m,`name = "${process.env.WORKER_NAME}"`);fs.writeFileSync(f,v)' "$ROOT/worker/wrangler.toml"
OUT="$(cd "$ROOT/worker" && npx --yes wrangler deploy 2>&1)" || { echo "$OUT";fail 'Worker deploy ไม่สำเร็จ'; }
echo "$OUT" | tail -8
WORKER_URL="$(printf '%s\n' "$OUT" | grep -oE 'https://[a-z0-9.-]+\.workers\.dev' | head -1 || true)"
[ -n "$WORKER_URL" ] || read -rp 'กรุณาวาง Worker URL จาก Cloudflare: ' WORKER_URL
[[ "$WORKER_URL" =~ ^https://[a-z0-9.-]+\.workers\.dev$ ]] || fail 'URL Worker ไม่ถูกต้อง'
for k in GAS_URL SHARED_SECRET ADMIN_PASSWORD_SHA256 ALLOWED_ORIGIN;do
 case "$k" in GAS_URL) value="$GAS_URL";;SHARED_SECRET) value="$SHARED_SECRET";;ADMIN_PASSWORD_SHA256) value="$ADMIN_PASSWORD_SHA256";;ALLOWED_ORIGIN) value="$ORIGIN";;esac
 printf '%s' "$value" | (cd "$ROOT/worker" && npx --yes wrangler secret put "$k" --name "$WORKER_NAME" >/dev/null) || fail "อัปโหลด $k ไม่สำเร็จ"
 echo "✓ ตั้งค่า $k"
done
info 'ตรวจสอบ Worker /health และ /api/config'
for i in 1 2 3 4 5;do
 health="$(curl -sS --max-time 20 "$WORKER_URL/health" || true)"
 cfg="$(curl -sS --max-time 35 -H "Origin: $ORIGIN" "$WORKER_URL/api/config" || true)"
 if printf '%s\n%s' "$health" "$cfg" | node -e 'let s="";process.stdin.on("data",c=>s+=c);process.stdin.on("end",()=>{try{const t=s.trim().split(/\r?\n/),h=JSON.parse(t[0]),j=JSON.parse(t[1]);process.exit(h.ok&&h.configured&&j.ok&&j.config?0:1)}catch{process.exit(1)}})';then echo '✓ Worker API และ Google Sheets ตอบสำเร็จ';break;fi
 if [ "$i" -eq 5 ];then fail 'API ตรวจไม่ผ่าน กรุณาตรวจ Apps Script deployment / Cloudflare secrets';fi
 sleep 3
done
info '[4/5] เผยแพร่ GitHub Pages (ซอร์สโค้ดสาธารณะ ไม่มีรายชื่อหรือรหัสลับ)'
WORKER_URL="$WORKER_URL" node -e 'const fs=require("fs");fs.writeFileSync(process.argv[1],"window.NYC_API_URL = "+JSON.stringify(process.env.WORKER_URL)+";\n")' "$ROOT/site/config.js"
cp -f "$ROOT/site/"* "$ROOT/docs/"
[ -d "$ROOT/.git" ] || git init -b main >/dev/null
[ -n "$(git config user.name || true)" ] || git config user.name "$OWNER"
[ -n "$(git config user.email || true)" ] || git config user.email "$(gh api user --jq .id)+$OWNER@users.noreply.github.com"
git branch -M main
git add .gitignore README.md install.sh bank-schema.json docs site worker/index.js worker/wrangler.toml apps-script/Code.gs apps-script/appsscript.json
if ! git diff --cached --quiet;then git commit -m 'NYC Krungthai registration V4' >/dev/null;fi
if gh repo view "$OWNER/$REPO" >/dev/null 2>&1;then
 [ -n "$(git remote get-url origin 2>/dev/null || true)" ] || git remote add origin "https://github.com/$OWNER/$REPO.git"
else
 gh repo create "$REPO" --public --source=. --remote=origin --push || fail 'สร้าง Repository ไม่สำเร็จ'
 echo '✓ สร้าง Repository Public (เผยแพร่เฉพาะโค้ด ไม่มีรายชื่อหรือ Secrets)'
fi
REMOTE="$(git remote get-url origin)"
[[ "$REMOTE" == *"$OWNER/$REPO"* ]] || fail 'ตรวจพบ remote ไม่ตรงชื่อโครงการ จะไม่ push ทับ'
git push --set-upstream origin main || fail 'Push GitHub ไม่สำเร็จ'
if ! gh api "repos/$OWNER/$REPO/pages" >/dev/null 2>&1;then
 if ! gh api -X POST "repos/$OWNER/$REPO/pages" -f 'source[branch]=main' -f 'source[path]=/docs' >/dev/null 2>&1;then
  echo 'GitHub Pages ยังเปิดไม่ได้ โปรดตรวจ';echo "ตรวจที่ https://github.com/$OWNER/$REPO/settings/pages"
 fi
fi
info '[5/5] สรุปการติดตั้ง'
echo "Repository: https://github.com/$OWNER/$REPO"
echo "เว็บไซต์ (เมื่อเปิด Pages สำเร็จ): https://$OWNER.github.io/$REPO/"
echo "Admin: https://$OWNER.github.io/$REPO/admin.html"
echo "Cloudflare: $WORKER_URL"
echo 'ระบบตั้งค่าปิดรับลงทะเบียนไว้ก่อน ให้ Admin ตรวจนโยบาย/รหัสคณะและเปิดเมื่อพร้อม'
echo 'ห้ามอัปโหลดแฟ้มทะเบียนที่มีเลขบัตรประชาชนหรือวันเกิดไปยัง Repository'
