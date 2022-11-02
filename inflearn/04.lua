--스크립트 기반으로 블럭 요소 찾기

local blockPart = game.Workspace.Cube
local blockPart = script.Parent


--fire 를 찾아서 컬러 속성 변경

local fire = script.Parent.Fire
fire.Color = Color3.fromRGB(15, 178, 45)


--컬러 변경하는 2가지 방법

blockPart.BrickColor = BrickColor.new("Mint")
blockPart.Color = Color3.fromRGB(0, 156, 187)
