
-- 술래잡기 사용 코드 모음 241113

-- 1. BGM 설정
-- 2. workspace 에 spawnlocation 생성, 배치


-- [[ package 목록 ]]
-- 1. 위아래 움직이는 파트
-- 2. 좌우 움직이는 파트
-- 3. 회전하는 원파트
-- 4. 회전하는 파트


-- [[ StarterGui ]]
-- 6. HP Bar, GuageBar

-- [[ StarterChareacterScripts ]]
-- 7. CharacterStatus
-- 8. HealthRegen

-- [[ StarterPlayerScripts ]]
-- 9. Doublejump
-- 10. jumpSound
-- 11. playerDash
-- 12. system_message


-- 캐릭터의 Pants와 Shirt 텍스처 ID를 변경하는 함수
local function applyRedClothes(character)
	local pants = character:FindFirstChildOfClass("Pants")
	local shirt = character:FindFirstChildOfClass("Shirt")

	if pants then
		pants.PantsTemplate = "rbxassetid://99793272974603" -- 붉은 Pants 텍스처
	end
	if shirt then
		shirt.ShirtTemplate = "rbxassetid://99793272974603" -- 붉은 Shirt 텍스처
	end
end

-- 캐릭터의 Pants와 Shirt를 원래 텍스처로 복구하는 함수
local function resetClothes(character, originalClothes)
	local pants = character:FindFirstChildOfClass("Pants")
	local shirt = character:FindFirstChildOfClass("Shirt")

	if pants and originalClothes.Pants then
		pants.PantsTemplate = originalClothes.Pants -- 원래 Pants 텍스처 복구
	end
	if shirt and originalClothes.Shirt then
		shirt.ShirtTemplate = originalClothes.Shirt -- 원래 Shirt 텍스처 복구
	end
end


