-- Studio Command Bar에서 실행하면 전체 텍스트 출력
local HttpService = game:GetService("HttpService")

local function isTextObject(inst)
    return inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox")
end

-- 수집
local uniq = {}
for _, inst in ipairs(game:GetDescendants()) do
    if isTextObject(inst) then
        local t = inst.Text
        if t and t ~= "" then
            uniq[t] = true
        end
    end
end

-- 정렬
local list = {}
for s in pairs(uniq) do
    table.insert(list, s)
end
table.sort(list)

-- CSV 출력 (Key,Source,en-us,ko-kr)
print("Key,Source,en-us,ko-kr")
for i, src in ipairs(list) do
    -- 키는 임시로 자동 생성: 나중에 맥락 분리 필요시 이 키를 써서 갈라주면 됩니다.
    local key = ("ui.auto.%04d"):format(i)
    -- CSV 이스케이프
    local esc = '"' .. src:gsub('"', '""') .. '"'
    -- en-us는 보통 Source와 동일하게 둡니다.
    print(("%s,%s,%s,%s"):format(key, esc, esc, ""))
end
