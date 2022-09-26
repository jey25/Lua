local UserInputService = game:GetService("UserInputService") -- 키보드 인식을 위해(13번째 줄)
local localPlayer = game.Players.LocalPlayer -- 플레이어 구해줌
local character -- 캐릭터를 담기위한 변수(28줄)
local humanoid -- 휴머노이드를 담기 위한 변수(29줄)
 print("jumpscriptloaded")
local canDoubleJump = false -- 이단점프가능한가?(제어)
local hasDoubleJumped = false -- 이단점프를 했는가?
local oldPower -- 원래점프력담기위한 변수(32줄)
local TIME_BETWEEN_JUMPS = 0.2 -- 점프하고 두번재 할때까지의 시간차
local DOUBLE_JUMP_POWER_MULTIPLIER = 2 -- 두번째 점프할때 원래점프력보다 몇배 더 강하게 하는가?

UserInputService.JumpRequest:connect(function() -- 점프요청을 함수로 받음
 if not character or not humanoid or not character:IsDescendantOf(workspace) or 
  humanoid:GetState() == Enum.HumanoidStateType.Dead then
  --캐릭터가 없거나, 휴머노이드가 없거나, 캐릭터가 workspace에 없거나, 캐릭터가 죽어있으면,
  return -- 함수 취소
 end
 
 if canDoubleJump and not hasDoubleJumped then -- 이단점프가능한가? 가 참이고, 이단점프했는가? 가 참이 아닌경우,
  hasDoubleJumped = true -- 더블점프한 상태라고 표시해줌
  humanoid.JumpPower = oldPower * DOUBLE_JUMP_POWER_MULTIPLIER -- 캐릭터 휴머노이드에서 점프력 설정해줌
  humanoid:ChangeState(Enum.HumanoidStateType.Jumping) -- 캐릭터 점프
 end
end)
 
local function characterAdded(newCharacter) --47줄이나 50줄에서 오는 함수
 character = newCharacter -- 캐릭터 구해줌
 humanoid = newCharacter:WaitForChild("Humanoid") -- 캐릭터 휴머노이드 구해줌
 hasDoubleJumped = false  --이단점프했는가? 거짓으로 설정
 canDoubleJump = false -- 이단점프가능한가? 거짓으로 설정
 oldPower = humanoid.JumpPower -- 원래 점프력 저장
 
 humanoid.StateChanged:connect(function(old, new) -- 휴머노이드 상태가 바뀔 때 함수 발동, 입력변수(전상태, 현재상태)
  if new == Enum.HumanoidStateType.Landed then -- 착지상태인경우
   canDoubleJump = false -- 이단점프가능한가? 거짓으로 설정
   hasDoubleJumped = false --이단점프했는가? 거짓으로 설정
   humanoid.JumpPower = oldPower -- 점프력되돌림(22줄에서 바꿈)
  elseif new == Enum.HumanoidStateType.Freefall then -- 떨어지는 상태인경우
   wait(TIME_BETWEEN_JUMPS) -- 10줄에서 정해준것만큼 기다림
   canDoubleJump = true -- 이단점프가능한가? 참으로 설정
  end
 end)
end
 