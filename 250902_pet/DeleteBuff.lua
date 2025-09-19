-- ▶ Command Bar (Server)
local USER_ID = 3857750238

local Players = game:GetService("Players")
local SSS = game:GetService("ServerScriptService")

local function safeRequire(name)
    local m = SSS:FindFirstChild(name)
    if not m then
        for _, d in ipairs(SSS:GetDescendants()) do
            if d:IsA("ModuleScript") and d.Name == name then m = d; break end
        end
    end
    if not m then return nil end
    local ok, mod = pcall(require, m)
    return ok and mod or nil
end

local plr = Players:GetPlayerByUserId(USER_ID)
if not plr then
    warn("[CLEAR] 대상 플레이어가 접속 중이 아닙니다.")
    return
end

local BuffService = safeRequire("BuffService")
if not BuffService then
    warn("[CLEAR] BuffService 로드 실패")
    return
end

-- 1) 활성 버프 전부 해제
for kind in pairs(BuffService:GetActive(plr)) do
    pcall(function() BuffService:ClearBuff(plr, kind) end)
end
-- 혹시 명칭이 다를 때 대비한 보정(선택)
for _, kind in ipairs({"Speed","Exp2x"}) do
    pcall(function() BuffService:ClearBuff(plr, kind) end)
end

-- 2) 안전망: 배율/속도 리셋
plr:SetAttribute("ExpMultiplier", 1)
plr:SetAttribute("SpeedMultiplier", 1)
local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
if hum then
    local base = tonumber(plr:GetAttribute("BaseWalkSpeed")) or hum.WalkSpeed or 16
    plr:SetAttribute("BaseWalkSpeed", base)
    hum.WalkSpeed = base
end

print("[CLEAR] 런타임 버프/배율/속도 초기화 완료")
