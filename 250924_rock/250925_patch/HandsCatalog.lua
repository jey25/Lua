--!strict
-- ReplicatedStorage/HandsCatalog (ModuleScript)
-- 테마 → Asset ID(문자열) 매핑표. rbxassetid:// 접두사 또는 숫자만 넣어도 됨(부트스트랩이 보정).
-- 빈 문자열("")이면 폴백(board)을 사용합니다.

return {
    a = {
        paper    = "rbxassetid://11111111", -- 예시
        rock     = "rbxassetid://22222222",
        scissors = "rbxassetid://33333333",
    },
    b = {
        paper    = "",
        rock     = "44444444",  -- 숫자만 넣어도 자동으로 rbxassetid:// 보정
        scissors = "",
    },
    -- c, d, e ... 계속 추가해도 됩니다.
}
