--[[
================================================================================
  PROJECT VECTOR — SCRIPT ĐANG BẢO TRÌ (ANIMATED · CARD EDITION)

  • Card panel tối (gradient bo góc, viền glow) — như trước
  • Icon gear xoay + vòng dashed + ping radar + vệ tinh bay quanh
  • Tiêu đề “SCRIPT ĐANG BẢO TRÌ” + gạch sáng có điểm chạy
  • Nền: quầng sáng + hạt bay + scanline (KHÔNG còn lưới vuông đen)
  • KHÔNG có thanh loading / tiến trình / ETA
  • F8 để ẩn / hiện giao diện

  Cách dùng:
    1) Dán vào executor → Execute.
    2) Bấm F8 để ẩn/hiện giao diện.
    3) Chỉnh CFG bên dưới.
================================================================================
--]]

local CFG = {
  unicode     = false,          -- true nếu font overlay hiển thị được tiếng Việt có dấu
  accent      = { 56, 189, 248},-- cyan
  accent2     = {139,  92, 246},-- violet
  warn        = {251, 191,  36},-- amber
  white       = {255, 255, 255},
  muted       = {148, 163, 184},

  api_url     = "",             -- ví dụ: "https://api.example.com/status.json" (trống = offline)
  poll_ms     = 20000,          -- chu kỳ poll API (ms)
  toggle_key  = 0x77,           -- F8
  show_fps    = true,
  region      = "ASIA-1",
  version     = "v2.4.1",
  error_code  = "503",
}

--------------------------------------------------------------------------------
-- Tiện ích chung
--------------------------------------------------------------------------------
local function clamp(v, lo, hi) return v < lo and lo or (v > hi and hi or v) end
local function lerp(a, b, t) return a + (b - a) * t end
local function ease(t) t = clamp(t, 0, 1) return t * t * (3 - 2 * t) end
local function C(rgb, a) return { rgb[1] / 255, rgb[2] / 255, rgb[3] / 255, a or 1 } end
local function mix(rgb1, rgb2, t, a)
  return {
    (rgb1[1] + (rgb2[1] - rgb1[1]) * t) / 255,
    (rgb1[2] + (rgb2[2] - rgb1[2]) * t) / 255,
    (rgb1[3] + (rgb2[3] - rgb1[3]) * t) / 255,
    a,
  }
end

local A, A2 = CFG.accent, CFG.accent2
local WHITE, MUTED = CFG.white, CFG.muted
local BG1 = { 7, 11, 22 }
local CARD_TOP = { 21, 30, 51 }
local CARD_BOT = { 10, 15, 29 }

local UNI = CFG.unicode
local function L(vi, en) return UNI and vi or en end

local STR = {
  brand    = "ThanhNhan in Fallen",
  brandSub = L("CHẾ ĐỘ BẢO TRÌ", "CHE DO BAO TRI"),
  title    = L("SCRIPT ĐANG BẢO TRÌ", "SCRIPT DANG BAO TRI"),
  sub1     = L("Chúng tôi đang nâng cấp máy chủ để hệ thống ổn định hơn.",
               "Chung toi dang nang cap may chu de he thong on dinh hon."),
  sub2     = L("Vui lòng quay lại sau - tiến trình được cập nhật tự động.",
               "Vui long quay lai sau - ban co the quay lai bat cu luc nao."),
  online   = L("SCRIPT ĐÃ HOẠT ĐỘNG TRỞ LẠI", "SCRIPT DA HOAT DONG TRO LAI"),
  onlineSub= L("Bạn có thể tiếp tục trải nghiệm.", "Ban co the tiep tuc trai nghiem."),
  startTtl = L("Bảo trì hệ thống", "Bao tri he thong"),
  startSub = L("Script đang được nâng cấp, vui lòng chờ...", "Script dang duoc nang cap, vui long cho..."),
  errLabel = L("MÃ LỖI", "MA LOI"),
  regLabel = L("KHU VỰC", "KHU VUC"),
  verLabel = L("PHIÊN BẢN", "PHIEN BAN"),
}

local function shorten(str, maxLen)
  if #str <= maxLen then return str end
  return str:sub(1, maxLen - 3) .. "..."
end

local function toast(kind, msg, sub, dur)
  if type(notify) ~= "table" then return end
  local fn = notify[kind]
  if fn then pcall(fn, msg, sub, dur or 6) end
end

--------------------------------------------------------------------------------
-- Trạng thái
--------------------------------------------------------------------------------
local st = {
  start     = utility.GetTime(),
  visible   = true,
  alpha     = 0,
  parx      = 0,
  pary      = 0,
  subtitle  = STR.sub2,
  online    = false,
  errored   = false,
}


--------------------------------------------------------------------------------
-- API status (tuỳ chọn) — utility.HttpGet + parse JSON đơn giản
--------------------------------------------------------------------------------
local function jsonStr(body, key)
  return body:match('"' .. key .. '"%s*:%s*"([^"]*)"')
end
local function jsonBool(body, key)
  local v = body:match('"' .. key .. '"%s*:%s*(%a+)')
  if v == "true" then return true end
  if v == "false" then return false end
  return nil
end

local function pollApi()
  if CFG.api_url == "" then return end
  local ok, body = pcall(utility.HttpGet, CFG.api_url)
  if not ok or type(body) ~= "string" or #body == 0 then return end

  local title = jsonStr(body, "title")
  if title and #title > 0 then STR.title = shorten(title:upper(), 40) end

  local msg = jsonStr(body, "message")
  if msg and #msg > 0 then st.subtitle = shorten(msg, 70) end

  local ver = jsonStr(body, "version")
  if ver and #ver > 0 then CFG.version = ver end

  local region = jsonStr(body, "region")
  if region and #region > 0 then CFG.region = region end

  local online = jsonBool(body, "maintenance")
  if online == false and not st.online then
    st.online = true
    st.visible = false
    toast("Success", STR.online, STR.onlineSub, 10)
  end
end

--------------------------------------------------------------------------------
-- Helpers vẽ
--------------------------------------------------------------------------------
local function txt(x, y, str, size, color, bold)
  draw.Text(x, y, str, color, size)
  if bold then draw.Text(x + math.max(0.6, size * 0.04), y, str, color, size) end
end

local function txtC(cx, y, str, size, color, bold)
  local w = draw.GetTextSize(str, size)
  txt(cx - w / 2, y, str, size, color, bold)
end

local function txtR(rx, y, str, size, color, bold)
  local w = draw.GetTextSize(str, size)
  txt(rx - w, y, str, size, color, bold)
end

local function drawArc(cx, cy, r, a0, a1, color, seg, thick)
  local n = math.max(2, seg or 24)
  local pts = {}
  for i = 0, n do
    local ang = a0 + (a1 - a0) * (i / n)
    pts[#pts + 1] = { cx + math.cos(ang) * r, cy + math.sin(ang) * r }
  end
  draw.Poly(pts, color, thick or 1.5)
end

-- Hình bánh răng (polygon khép kín)
local function gearPoints(cx, cy, r, teeth, rot, innerRatio)
  local pts = {}
  local n = teeth * 4
  for i = 0, n - 1 do
    local ang = rot + (i / n) * 6.2831853
    local rr = (i % 4 < 2) and r or r * innerRatio
    pts[#pts + 1] = { cx + math.cos(ang) * rr, cy + math.sin(ang) * rr }
  end
  return pts
end

local function drawGear(cx, cy, r, rot, rgb, alpha, thick)
  local pts = gearPoints(cx, cy, r, 9, rot, 0.80)
  draw.PolyClosed(pts, C(rgb, 0.10 * alpha), thick * 3.2)
  draw.PolyClosed(pts, C(rgb, alpha), thick)
  draw.Circle(cx, cy, r * 0.52, C(rgb, 0.55 * alpha), 40, thick * 0.9)
  draw.Circle(cx, cy, r * 0.24, C(rgb, 0.35 * alpha), 28, thick * 0.8)
end

-- Nền gradient bo góc (mô phỏng bằng các dải ngang + cắt góc)
local function roundedGradient(x, y, w, h, r, top, bot, alpha)
  local step = 3
  local i = 0
  while i < h do
    local hh = math.min(step, h - i)
    local dTop = i
    local dBot = h - (i + hh)
    local d = math.min(dTop, dBot)
    local inset = 0
    if d < r then
      local dx = r - d
      inset = r - math.sqrt(math.max(0, r * r - dx * dx))
    end
    local k = i / h
    draw.RectFilled(x + inset, y + i, w - inset * 2, hh + 0.7, mix(top, bot, k, alpha), 0)
    i = i + step
  end
end

--------------------------------------------------------------------------------
-- Render chính
--------------------------------------------------------------------------------
local function render()
  local sw, sh = draw.GetScreenSize()
  if not sw or sw < 64 or sh < 64 then return end

  local dt = utility.GetDeltaTime()
  local t = utility.GetTime() - st.start

  -- fade in / out khi đóng / mở
  local fadeTarget = st.visible and 1 or 0
  st.alpha = st.alpha + (fadeTarget - st.alpha) * math.min(1, dt * 6)
  if not st.visible and st.alpha < 0.003 then
    st.alpha = 0
    return
  end
  local a = st.alpha

  local s = clamp(math.min(sw / 1440, sh / 900), 0.58, 1.35)

  -- parallax nhẹ theo chuột
  local mx, my = input.GetMousePosition()
  if mx and my then
    local txp = ((mx - sw / 2) / sw) * 9 * s
    local typ = ((my - sh / 2) / sh) * 6 * s
    local k = math.min(1, dt * 3)
    st.parx = lerp(st.parx, txp, k)
    st.pary = lerp(st.pary, typ, k)
  end

  ------------------------------------------------------------------------------
  -- 1. NỀN (tối tĩnh, không hiệu ứng)
  ------------------------------------------------------------------------------
  draw.RectFilled(0, 0, sw, sh, C(BG1, 0.94 * a))

  ------------------------------------------------------------------------------
  -- 2. CARD
  ------------------------------------------------------------------------------
  local cw, ch = 620 * s, 360 * s
  local cx = sw / 2 + st.parx
  local cy = sh / 2 + st.pary
  local x0, y0 = cx - cw / 2, cy - ch / 2

  -- halo + shadow
  draw.RectFilled(x0 - 2, y0 - 2, cw + 4, ch + 4, C(A, 0.045 * a), 20 * s)
  draw.RectFilled(x0, y0 + 12 * s, cw, ch, { 0, 0, 0, 0.45 * a }, 18 * s)
  draw.RectFilled(x0, y0 + 5 * s, cw, ch, { 0, 0, 0, 0.30 * a }, 18 * s)

  -- nền gradient
  roundedGradient(x0, y0, cw, ch, 18 * s, CARD_TOP, CARD_BOT, 0.97 * a)

  -- viền + highlight
  draw.Rect(x0, y0, cw, ch, C(A, 0.22 * a), 18 * s, 1.2 * s)
  draw.Rect(x0 + 1.2, y0 + 1.2, cw - 2.4, ch - 2.4, C(WHITE, 0.035 * a), 17 * s, 1)

  -- vệt sáng quét trong card
  local sweepX = x0 + cw * ((t * 0.11) % 1)
  for i = -34, 34, 2 do
    local xx = sweepX + i * s
    if xx > x0 + 20 * s and xx < x0 + cw - 20 * s then
      local aa = (1 - math.abs(i) / 34) * 0.050 * a
      draw.RectFilled(xx, y0 + 62 * s, 2.2 * s, 236 * s, C(WHITE, aa))
    end
  end

  ------------------------------------------------------------------------------
  -- 3. HEADER
  ------------------------------------------------------------------------------
  drawGear(x0 + 34 * s, y0 + 32 * s, 9 * s, -t * 0.6, A, 0.9 * a, 1.4 * s)
  txt(x0 + 50 * s, y0 + 19 * s, STR.brand, 12 * s, C(WHITE, 0.92 * a), true)
  txt(x0 + 50 * s, y0 + 34 * s, STR.brandSub, 8 * s, C(MUTED, 0.8 * a))

  draw.Line(x0 + 26 * s, y0 + 58 * s, x0 + cw - 26 * s, y0 + 58 * s, C(WHITE, 0.08 * a))

  ------------------------------------------------------------------------------
  -- 4. ICON GEAR
  ------------------------------------------------------------------------------
  local gx, gy = cx, y0 + 122 * s
  local gr = 34 * s

  -- ping radar
  for k = 0, 1 do
    local pr = ((t * 0.42) + k * 0.5) % 1
    draw.Circle(gx, gy, 44 * s + pr * 34 * s, C(A, (1 - pr) * 0.22 * a), 56, 1.3 * s)
  end

  -- vòng dashed xoay
  for i = 0, 11 do
    local a0 = t * 0.6 + i * 0.5236
    drawArc(gx, gy, gr * 1.55, a0, a0 + 0.22, C(A2, 0.38 * a), 6, 1.4 * s)
  end

  -- gear chính
  draw.CircleFilled(gx, gy, gr * 1.75, C(A, 0.05 * a), 48)
  drawGear(gx, gy, gr, t * 0.55, A, 0.95 * a, 2.1 * s)

  -- điểm nhấn trung tâm
  local pulse = 0.5 + 0.5 * math.sin(t * 3.2)
  draw.CircleFilled(gx, gy, (4.6 + pulse * 1.6) * s, C(A, 0.95 * a), 20)
  draw.CircleFilled(gx, gy, (10 + pulse * 4.5) * s, C(A, 0.10 * a), 28)

  -- vệ tinh bay quanh
  local oa = -t * 1.15
  local sx2 = gx + math.cos(oa) * gr * 1.55
  local sy2 = gy + math.sin(oa) * gr * 1.55
  draw.CircleFilled(sx2, sy2, 8 * s, C(A, 0.10 * a), 20)
  draw.CircleFilled(sx2, sy2, 2.6 * s, C(WHITE, 0.95 * a), 14)

  ------------------------------------------------------------------------------
  -- 5. TIÊU ĐỀ
  ------------------------------------------------------------------------------
  local rv = ease((t - 0.55) / 1.05)
  local sv = ease((t - 1.05) / 0.85)
  local lv = ease((t - 1.55) / 0.75)

  local titleY = y0 + 174 * s + (1 - rv) * 14 * s
  txtC(cx, titleY, STR.title, 24 * s, C(WHITE, 0.96 * rv * a), true)

  -- gạch chân sáng có điểm chạy
  local uw = 84 * s * rv
  draw.Line(cx - uw, y0 + 202 * s, cx + uw, y0 + 202 * s, C(A, 0.65 * rv * a), 1.6 * s)
  local dotx = cx + math.sin(t * 1.6) * uw
  draw.CircleFilled(dotx, y0 + 202 * s, 8 * s, C(A, 0.20 * rv * a), 20)
  draw.CircleFilled(dotx, y0 + 202 * s, 2.8 * s, C(WHITE, 0.95 * rv * a), 14)

  txtC(cx, y0 + 216 * s, STR.sub1, 11.5 * s, C(MUTED, 0.92 * sv * a))
  txtC(cx, y0 + 233 * s, st.subtitle, 11.5 * s, C(MUTED, 0.78 * sv * a))

  ------------------------------------------------------------------------------
  -- 6. META + WAVEFORM + FOOTER
  ------------------------------------------------------------------------------
  local metaY = y0 + 264 * s
  txt(x0 + 40 * s, metaY, STR.errLabel .. ": " .. CFG.error_code, 9.5 * s, C(MUTED, 0.85 * lv * a))
  txtC(cx, metaY, STR.regLabel .. ": " .. CFG.region, 9.5 * s, C(MUTED, 0.85 * lv * a))
  txtR(x0 + cw - 40 * s, metaY, STR.verLabel .. ": " .. CFG.version, 9.5 * s, C(MUTED, 0.85 * lv * a))

  -- waveform
  local wpts = {}
  local wx0, wx1 = x0 + 40 * s, x0 + cw - 40 * s
  local wn = 64
  for i = 0, wn do
    local k = i / wn
    local px = wx0 + (wx1 - wx0) * k
    local py = y0 + 296 * s
      + math.sin(k * 10 + t * 2.2) * 3.2 * s
      + math.sin(k * 23 - t * 3.4) * 1.6 * s
    wpts[#wpts + 1] = { px, py }
  end
  draw.Poly(wpts, C(A, 0.32 * lv * a), 1.3 * s)

  draw.Line(x0 + 26 * s, y0 + 314 * s, x0 + cw - 26 * s, y0 + 314 * s, C(WHITE, 0.06 * a))
  local footPulse = 0.42 + 0.28 * (0.5 + 0.5 * math.sin(t * 2.4))
  txtC(cx, y0 + 328 * s,
    L("[F8] ẨN / HIỆN GIAO DIỆN", "[F8] AN / HIEN GIAO DIEN"),
    9 * s, C(MUTED, footPulse * a))

  ------------------------------------------------------------------------------
  -- 7. FPS
  ------------------------------------------------------------------------------
  if CFG.show_fps then
    local fps = string.format("FPS %d", math.floor(utility.GetFPS() + 0.5))
    txtR(sw - 20 * s, sh - 22 * s, fps, 9.5 * s, C(WHITE, 0.28 * a))
  end
end

--------------------------------------------------------------------------------
-- Khởi động
--------------------------------------------------------------------------------
local function safeRender()
  local ok, err = pcall(render)
  if not ok and not st.errored then
    st.errored = true
    toast("Error", L("Lỗi giao diện", "UI error"), tostring(err), 10)
  end
end

OnFrame = safeRender

-- API poll định kỳ (không chặn frame render)
pollApi()
if CFG.api_url ~= "" then
  thread.Create(function()
    pcall(pollApi)
  end, CFG.poll_ms)
end

-- F8 ẩn / hiện
utility.OnKey(CFG.toggle_key, "toggle", function(on)
  st.visible = on
  if on then st.alpha = math.max(st.alpha, 0.001) end
end)

-- Thông báo khi load
toast("Warning", STR.startTtl, STR.startSub, 6)
