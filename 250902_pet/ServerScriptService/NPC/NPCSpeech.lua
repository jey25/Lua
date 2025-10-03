--!strict
-- NPC 말풍선 관리자
-- - ReplicatedStorage/BubbleTemplates에서 BillboardGui 템플릿을 찾아 클론
-- - workspace/NPC_LIVE 하위의 NPC가 "이름으로" 매칭되는 경우에만 랜덤 간격으로 표시
-- - 텍스트는 이름별로 지정된 후보 중에서 랜덤 선택
-- - 표시 시간 지나면 자동 제거
-- - NPC가 workspace에서 제거되면 루프/말풍선도 자동 정리

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")

-- ====== 설정(이름별 매핑) ======
-- 템플릿은 ReplicatedStorage/BubbleTemplates 아래 BillboardGui로 준비해 두세요.
-- 템플릿 내에는 TextLabel(이름 "Text" 권장)이 있어야 합니다.
type Interval = {min: number, max: number}
type NpcCfg = {
	templates: {string}?,     -- 사용할 템플릿 이름 목록(랜덤). 없으면 {"Plain"}
	lines: {string}?,         -- 말풍선 문구 후보(랜덤). 비워두면 빈 말풍선(코드로 채우기 가능)
	offsetY: number?,         -- 머리 위 높이(Studs). 기본 3
	duration: Interval?,      -- 말풍선 표시 시간 범위(초). 기본 {min=2.5,max=4.0}
	interval: Interval?,      -- 다음 말풍선까지 대기 시간 범위(초). 기본 {min=6,max=12}
	maxDistance: number?,     -- 카메라 거리 제한. 기본 80
}

-- ▶ 여기만 채우면 됩니다. (NPC 이름 = 모델 이름)
local NPC_CONFIGS: {[string]: NpcCfg} = {
	["vendor_ninja(Lv.100)"] = {
		templates = {"Plain"}, -- 템플릿 이름 예시
		lines = {
			"눈에 보이는 것만이 전부가 아니야",
			"나보다 약한 자들에게 볼일은 없어",
			"특별히 네 애완동물이 부럽진 않아",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["grandma"] = {
		templates = {"Plain"},
		lines = {
			"나이들수록 잠이 없어져서 큰일이야",
			"오늘은 일찍 나왔네?",
			"나이 먹고 보니 사는 거 참 별거 없어",
			"이 마을에는 숨겨진 비밀이 많아",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},
	
	["Amona"] = {
		templates = {"Plain"},
		lines = {
			"Grrrrrrrr...",
			"Zzzzz...",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},
	
	["Walkingman"] = {
		templates = {"Plain"},
		lines = {
			"출근은 힘들어~",
			"가족을 위해 오늘도 힘내자!",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},
	
	["engineer"] = {
		templates = {"Plain"},
		lines = {
			"어디 고장난 곳 있어?",
			"집 수리 좀 해줄까?",
			"얼마 전 사다리 시공을 했었지. 위치는 비밀이야",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},
	
	["illidan"] = {
		templates = {"Plain"},
		lines = {
			"너희 아직, 준비가 안됐다!",
			"낭비할 시간 없다.",
			"난 너같은 조무래기에는 관심 없다",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},
	
	["nightwatch_savage"] = {
		templates = {"Plain"},
		lines = {
			"어디 시비 걸만한 놈 없을까?",
			"뭘 쳐다보지?",
			"개, 개 따윈 하나도 무섭지 않아...",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},
	
	["nightwatch_zombie"] = {
		templates = {"Plain"},
		lines = {
			"Groan...",
			"Moan...",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},
	
	["nightwatch_zombie2"] = {
		templates = {"Plain"},
		lines = {
			"Moan...",
			"Groan...",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},
	
	["snakeman"] = {
		templates = {"Plain"},
		lines = {
			"애완동물은 나처럼 고급스러운걸 키워야지",
			"니 애완동물 우리 귀염둥이 간식으로 딱인데?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},
	
	["thief"] = {
		templates = {"Plain"},
		lines = {
			"뭐 훔칠만한 것 좀 없나?",
			"이봐, 혹시 오는길에 경찰은 없었어?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},
	
	["timthespamm"] = {
		templates = {"Plain"},
		lines = {
			"여~ 좋은 아침?",
			"니 강아지 안물지?",
			"니 강아지 이름이 뭐야?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["Mewrila"] = {
		templates = {"Plain"},
		lines = {
			"어머 귀여워~ ❤️",
			"니 애완동물은 몇살이야?",
			"동물병원은 세탁소 지나 좌회전해서 조금만 더 가면 있어",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["nightwatch_blackcat"] = {
		
		templates = {"Plain"},
		lines = {
			"너 개인은 강할지 몰라도, 팀을 이길 순 없어",
			"애송이와는 말을 섞고 싶지 않아",
			"언젠가 니가 더 강해진다면 상대해주지",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},
	
	["STARCODEE_GUN"] = {
		templates = {"Plain"},
		lines = {
			"입마개는 하셔야 하는 거 아니에요??",
			"털 날리거 봐..",
			"큰 개는 무서워..",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},
	
	["sportsman"] = {
		templates = {"Plain"},
		lines = {
			"세차하기 딱 좋은 날씨네?",
			"니 애완동물도 타고 달릴 수 있어?",
			"타지도 못하는 거에 돈은 왜 쓰는거야?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},
	
	["xiaoleung"] = {
		templates = {"Plain"},
		lines = {
			"강아지들이 좀 자라야 간식을 먹을 수 있어",
			"새로운 간식 많이 들어왔어",
			"인간적으로 토요일은 휴무여야 하는 거 아냐?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},
	
	["bleus_p"] = {
		templates = {"Plain"},
		lines = {
			"마을 구석 폐건물 구역은 가지 않는 것이 좋아",
			"가끔 산 중턱을 지날 때 상자 같은 것이 보이던데?",
			"대부분의 사람이 잠든 밤에 가끔씩 밖에서 이상한 소리가 들려",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},
	
	["Crimson"] = {
		templates = {"Plain"},
		lines = {
			"니 옷 좋아보이는데?",
			"니 애완동물 맛있어 보이는데?",
			"지금 머리숱 많다고 나 무시해?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},
	
	["police_c"] = {
		templates = {"Plain"},
		lines = {
			"수상한 사람 못봤어?",
			"야간 근무는 힘들어~",
			"킁킁, 어디서 타는 냄새 나는 것 같은데?",
			
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},
	
	["police_b"] = {
		templates = {"Plain"},
		lines = {
			"수상한 사람 못봤어?",
			"야간 근무는 힘들어~",
			"10시 이후는 돌아다닐 때 조심해",

		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},
	
	["police_a"] = {
		templates = {"Plain"},
		lines = {
			"파출소는 함부로 뒤지는 거 아냐",
			"새 경찰차는 언제 들어오는거야?",
			"너무 늦은 밤 공원은 돌아다니지 마",

		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	
	["nightwatch_flower"] = {
		templates = {"Plain"},
		lines = {
			"오늘은 너를 만날 수 있을까?",
			"너를 내 옆에 잡아둘거야, 다리를 부러뜨려서라도",
			"제가 당신을 도울 수 있도록 도와줘요",

		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},
	
	["c"] = {
		templates = {"Plain"},
		lines = {
			"숲을 보고 있으니 악몽같은 기억이 떠오르는군",
			"이봐, 마을 뒷산에 가본 적 있어?",
			"멀리서 보이면 뒤도 돌아보지 말고 도망쳐",

		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},
	
	["thegirl"] = {
		templates = {"Plain"},
		lines = {
			"버스는 왜 항상 늦는거야?",
			"난 개털 알레르기가 있어",
			"당신, 강아지는 내 옆에 태우지 마",

		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},
	
	["vendor_bloxmart"] = {
		templates = {"Plain"},
		lines = {
			"어서오세요~ 블록스마트 입니다.",
			"없는 것 빼고 다 있어요",
			"(퇴근 후 그녀에게 고백해볼까?..)",

		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},
	
	["payleey"] = {
		templates = {"Plain"},
		lines = {
			"빨래하기 좋은 날씨네",
			"마을이 발전하면 축제도 생기지 않을까?",
			"강아지랑 놀아주는 방법은 다양해",

		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},
	
	["Nasynia"] = {
		templates = {"Plain"},
		lines = {
			"우리 남편 못 봤어요?",
			"아이구 귀여워라~ 얘는 털 많이 빠져요?",
			"도대체 어디를 간거야",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},
	
	["HideHusband"] = {
		templates = {"Plain"},
		lines = {
			"뭐야 너 남에 집에 어떻게 들어왔어?",
			"아내 몰래 짱박혀 노는 게 스릴이 최고지!",
			"이봐 아내에겐 비밀이야, 알겠지?",
		
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},
	
	["Personaje"] = {
		templates = {"Plain"},
		lines = {
			"어머나, 귀여운 강아지네요, 이름이 뭐에요?",
			"오늘 저녁엔 뭐하고 놀지?",
			"언젠가 특이한 애완동물을 데리고 다니는 사람을 본 적이 있어",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},
	
	["KlTSUBEE"] = {
		templates = {"Plain"},
		lines = {
			"맛있어 보이는 음식을 치우면 강아지들이 싫어할 걸?",
			"마을에 보물을 노리는 도둑들이 있다던데?",
			"애완동물을 키우다보면 몇마리 더 키우고 싶어질 때가 있지",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},
	
	["cowman"] = {
		templates = {"Plain"},
		lines = {
			"마을 북쪽 골짜기에는 가지마",
			"애정도를 높게 유지하면 특별한 능력이 생긴다는데?",
			"10년 후에는 어떤 세상이 올까?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["ninja_bae"] = {
		templates = {"Plain"},
		lines = {
			"가끔씩 마을 바닥에서 무슨 소리가 들려.. 들어봤어?",
			"등산은 고되지만 보상을 얻을 수도 있어!",
			"강아지들을 아프게 하지마",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["gentleman"] = {
		templates = {"Plain"},
		lines = {
			"고대인들은 특별한 애완동물을 데리고 다녔다던데?",
			"물 속을 들여다 본 적 있어?",
			"사람을 보고 짖을때는 살살 달래면 돼",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["gentlecow"] = {
		templates = {"Plain"},
		lines = {
			"강아지들이 졸려할 때는 너네 집 침대로 가봐",
			"다양한 장난감들로 놀아줄 수 있다.",
			"니 강아지는 고양이를 너무 좋아하는데?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["starcow"] = {
		templates = {"Plain"},
		lines = {
			"애정도가 낮게 유지되면 애들이 말을 안듣기 시작해",
			"반려동물을 키우는 사람들이 많아지면 축제도 생기지 않을까?",
			"이름이 뭐야?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["hba"] = {
		templates = {"Plain"},
		lines = {
			"애정도를 높게 유지하면 특별한 능력이 생긴다는데?",
			"10년 후에는 어떤 세상이 올까?",
			"이놈에 코드는 뭐 하나 수정하면 다른 게 다 고장나네",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["cowman2"] = {
		templates = {"Plain"},
		lines = {
			"등산은 고되지만 보상을 얻을 수도 있어!",
			"강아지들을 아프게 하지마",
			"스팸 전화 좀 그만 해...",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["cowman3"] = {
		templates = {"Plain"},
		lines = {
			"물 속을 들여다 본 적 있어?",
			"사람을 보고 짖을때는 살살 달래면 돼",
			"보험 가입하실래요?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["smurf"] = {
		templates = {"Plain"},
		lines = {
			"다양한 장난감들로 놀아줄 수 있다.",
			"니 강아지는 고양이를 너무 좋아하는데?",
			"여~ 좋은 아침?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["boxman"] = {
		templates = {"Plain"},
		lines = {
			"반려동물을 키우는 사람들이 많아지면 축제도 생기지 않을까?",
			"이름이 뭐야?",
			"니 강아지 안물지?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["yellowman"] = {
		templates = {"Plain"},
		lines = {
			"10년 후에는 어떤 세상이 올까?",
			"이놈에 코드는 뭐 하나 수정하면 다른 게 다 고장나네",
			"니 강아지 이름이 뭐야?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["bluebird"] = {
		templates = {"Plain"},
		lines = {
			"강아지들을 아프게 하지마",
			"스팸 전화 좀 그만 해...",
			"마을 구석 폐건물 구역은 가지 않는 것이 좋아",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["defaultman"] = {
		templates = {"Plain"},
		lines = {
			"사람을 보고 짖을때는 살살 달래면 돼",
			"보험 가입하실래요?",
			"가끔 산 중턱을 지날 때 상자 같은 것이 보이던데?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["signup"] = {
		templates = {"Plain"},
		lines = {
			"니 강아지는 고양이를 너무 좋아하는데?",
			"여~ 좋은 아침?",
			"대부분의 사람이 잠든 밤에 가끔씩 밖에서 이상한 소리가 들려",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["morning_sportsman"] = {
		templates = {"Plain"},
		lines = {
			"이름이 뭐야?",
			"니 강아지 안물지?",
			"빨래하기 좋은 날씨네",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["stussy"] = {
		templates = {"Plain"},
		lines = {
			"이놈에 코드는 뭐 하나 수정하면 다른 게 다 고장나네",
			"니 강아지 이름이 뭐야?",
			"마을이 발전하면 축제도 생기지 않을까?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["biking"] = {
		templates = {"Plain"},
		lines = {
			"스팸 전화 좀 그만 해...",
			"마을 구석 폐건물 구역은 가지 않는 것이 좋아",
			"강아지랑 놀아주는 방법은 다양해",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["d"] = {
		templates = {"Plain"},
		lines = {
			"보험 가입하실래요?",
			"가끔 산 중턱을 지날 때 상자 같은 것이 보이던데?",
			"어머나, 귀여운 강아지네요, 이름이 뭐에요?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["nerf"] = {
		templates = {"Plain"},
		lines = {
			"마을 구석 폐건물 구역은 가지 않는 것이 좋아",
			"대부분의 사람이 잠든 밤에 가끔씩 밖에서 이상한 소리가 들려",
			"오늘 저녁엔 뭐하고 놀지?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["Indian"] = {
		templates = {"Plain"},
		lines = {
			"가끔 산 중턱을 지날 때 상자 같은 것이 보이던데?",
			"빨래하기 좋은 날씨네",
			"언젠가 특이한 애완동물을 데리고 다니는 사람을 본 적이 있어",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["Dxummy_gaurd"] = {
		templates = {"Plain"},
		lines = {
			"대부분의 사람이 잠든 밤에 가끔씩 밖에서 이상한 소리가 들려",
			"강아지랑 놀아주는 방법은 다양해",
			"마을 북쪽 골짜기에는 가지마",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["timthespam"] = {
		templates = {"Plain"},
		lines = {
			"빨래하기 좋은 날씨네",
			"어머나, 귀여운 강아지네요, 이름이 뭐에요?",
			"가끔씩 마을 바닥에서 무슨 소리가 들려.. 들어봤어?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["Prabzil"] = {
		templates = {"Plain"},
		lines = {
			"강아지랑 놀아주는 방법은 다양해",
			"오늘 저녁엔 뭐하고 놀지?",
			"고대인들은 특별한 애완동물을 데리고 다녔다던데?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["peter"] = {
		templates = {"Plain"},
		lines = {
			"어머나, 귀여운 강아지네요, 이름이 뭐에요?",
			"언젠가 특이한 애완동물을 데리고 다니는 사람을 본 적이 있어",
			"강아지들이 졸려할 때는 너네 집 침대로 가봐",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["hellotatta"] = {
		templates = {"Plain"},
		lines = {
			"오늘 저녁엔 뭐하고 놀지?",
			"마을 북쪽 골짜기에는 가지마",
			"애정도가 낮게 유지되면 애들이 말을 안듣기 시작해",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["catman"] = {
		templates = {"Plain"},
		lines = {
			"고대인들은 특별한 애완동물을 데리고 다녔다던데?",
			"이름이 뭐야?",
			"등산은 고되지만 보상을 얻을 수도 있어!",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["afternoon_cowman"] = {
		templates = {"Plain"},
		lines = {
			"강아지들이 졸려할 때는 너네 집 침대로 가봐",
			"니 강아지 안물지?",
			"물 속을 들여다 본 적 있어?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["eagle"] = {
		templates = {"Plain"},
		lines = {
			"애정도가 낮게 유지되면 애들이 말을 안듣기 시작해",
			"니 강아지 이름이 뭐야?",
			"다양한 장난감들로 놀아줄 수 있다.",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["mmp"] = {
		templates = {"Plain"},
		lines = {
			"등산은 고되지만 보상을 얻을 수도 있어!",
			"마을 구석 폐건물 구역은 가지 않는 것이 좋아",
			"반려동물을 키우는 사람들이 많아지면 축제도 생기지 않을까?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["ninjapark"] = {
		templates = {"Plain"},
		lines = {
			"물 속을 들여다 본 적 있어?",
			"가끔 산 중턱을 지날 때 상자 같은 것이 보이던데?",
			"10년 후에는 어떤 세상이 올까?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["canada"] = {
		templates = {"Plain"},
		lines = {
			"다양한 장난감들로 놀아줄 수 있다.",
			"대부분의 사람이 잠든 밤에 가끔씩 밖에서 이상한 소리가 들려",
			"강아지들을 아프게 하지마",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["b"] = {
		templates = {"Plain"},
		lines = {
			"반려동물을 키우는 사람들이 많아지면 축제도 생기지 않을까?",
			"빨래하기 좋은 날씨네",
			"사람을 보고 짖을때는 살살 달래면 돼",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["afternoon_gentlecolor"] = {
		templates = {"Plain"},
		lines = {
			"10년 후에는 어떤 세상이 올까?",
			"강아지랑 놀아주는 방법은 다양해",
			"니 강아지는 고양이를 너무 좋아하는데?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["afternoon_musicman"] = {
		templates = {"Plain"},
		lines = {
			"강아지들을 아프게 하지마",
			"어머나, 귀여운 강아지네요, 이름이 뭐에요?",
			"여~ 좋은 아침?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["king"] = {
		templates = {"Plain"},
		lines = {
			"사람을 보고 짖을때는 살살 달래면 돼",
			"오늘 저녁엔 뭐하고 놀지?",
			"가끔씩 마을 바닥에서 무슨 소리가 들려.. 들어봤어?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["afternoon_smurf"] = {
		templates = {"Plain"},
		lines = {
			"니 강아지는 고양이를 너무 좋아하는데?",
			"가끔 산 중턱을 지날 때 상자 같은 것이 보이던데?",
			"고대인들은 특별한 애완동물을 데리고 다녔다던데?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["afternoon_gentlecow"] = {
		templates = {"Plain"},
		lines = {
			"여~ 좋은 아침?",
			"대부분의 사람이 잠든 밤에 가끔씩 밖에서 이상한 소리가 들려",
			"강아지들이 졸려할 때는 너네 집 침대로 가봐",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["afternoon_ninja"] = {
		templates = {"Plain"},
		lines = {
			"니 강아지 안물지?",
			"빨래하기 좋은 날씨네",
			"애정도가 낮게 유지되면 애들이 말을 안듣기 시작해",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["robloxman"] = {
		templates = {"Plain"},
		lines = {
			"니 강아지 이름이 뭐야?",
			"마을이 발전하면 축제도 생기지 않을까?",
			"등산은 고되지만 보상을 얻을 수도 있어!",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["electroman"] = {
		templates = {"Plain"},
		lines = {
			"마을 구석 폐건물 구역은 가지 않는 것이 좋아",
			"강아지랑 놀아주는 방법은 다양해",
			"물 속을 들여다 본 적 있어?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["BarbieBankz"] = {
		templates = {"Plain"},
		lines = {
			"가끔 산 중턱을 지날 때 상자 같은 것이 보이던데?",
			"어머나, 귀여운 강아지네요, 이름이 뭐에요?",
			"다양한 장난감들로 놀아줄 수 있다.",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["IconicFatma"] = {
		templates = {"Plain"},
		lines = {
			"대부분의 사람이 잠든 밤에 가끔씩 밖에서 이상한 소리가 들려",
			"오늘 저녁엔 뭐하고 놀지?",
			"반려동물을 키우는 사람들이 많아지면 축제도 생기지 않을까?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["TheOdd"] = {
		templates = {"Plain"},
		lines = {
			"빨래하기 좋은 날씨네",
			"고대인들은 특별한 애완동물을 데리고 다녔다던데?",
			"10년 후에는 어떤 세상이 올까?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["theman"] = {
		templates = {"Plain"},
		lines = {
			"마을이 발전하면 축제도 생기지 않을까?",
			"강아지들이 졸려할 때는 너네 집 침대로 가봐",
			"가끔씩 마을 바닥에서 무슨 소리가 들려.. 들어봤어?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["ninja"] = {
		templates = {"Plain"},
		lines = {
			"오늘 저녁엔 뭐하고 놀지?",
			"애정도가 낮게 유지되면 애들이 말을 안듣기 시작해",
			"등산은 고되지만 보상을 얻을 수도 있어!",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["savage"] = {
		templates = {"Plain"},
		lines = {
			"언젠가 특이한 애완동물을 데리고 다니는 사람을 본 적이 있어",
			"등산은 고되지만 보상을 얻을 수도 있어!",
			"물 속을 들여다 본 적 있어?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["sol"] = {
		templates = {"Plain"},
		lines = {
			"마을 북쪽 골짜기에는 가지마",
			"물 속을 들여다 본 적 있어?",
			"사람을 보고 짖을때는 살살 달래면 돼",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["night_cowman"] = {
		templates = {"Plain"},
		lines = {
			"가끔씩 마을 바닥에서 무슨 소리가 들려.. 들어봤어?",
			"다양한 장난감들로 놀아줄 수 있다.",
			"니 강아지는 고양이를 너무 좋아하는데?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["gentlecolor"] = {
		templates = {"Plain"},
		lines = {
			"고대인들은 특별한 애완동물을 데리고 다녔다던데?",
			"반려동물을 키우는 사람들이 많아지면 축제도 생기지 않을까?",
			"이름이 뭐야?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["bleus"] = {
		templates = {"Plain"},
		lines = {
			"강아지들이 졸려할 때는 너네 집 침대로 가봐",
			"10년 후에는 어떤 세상이 올까?",
			"이놈에 코드는 뭐 하나 수정하면 다른 게 다 고장나네",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["ggocalcon"] = {
		templates = {"Plain"},
		lines = {
			"애정도가 낮게 유지되면 애들이 말을 안듣기 시작해",
			"강아지들을 아프게 하지마",
			"스팸 전화 좀 그만 해...",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["a"] = {
		templates = {"Plain"},
		lines = {
			"등산은 고되지만 보상을 얻을 수도 있어!",
			"사람을 보고 짖을때는 살살 달래면 돼",
			"보험 가입하실래요?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["night_cowman2"] = {
		templates = {"Plain"},
		lines = {
			"물 속을 들여다 본 적 있어?",
			"니 강아지는 고양이를 너무 좋아하는데?",
			"여~ 좋은 아침?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["musicman"] = {
		templates = {"Plain"},
		lines = {
			"다양한 장난감들로 놀아줄 수 있다.",
			"이름이 뭐야?",
			"니 강아지 안물지?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["musicman2"] = {
		templates = {"Plain"},
		lines = {
			"반려동물을 키우는 사람들이 많아지면 축제도 생기지 않을까?",
			"이놈에 코드는 뭐 하나 수정하면 다른 게 다 고장나네",
			"니 강아지 이름이 뭐야?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["night_boxman"] = {
		templates = {"Plain"},
		lines = {
			"10년 후에는 어떤 세상이 올까?",
			"스팸 전화 좀 그만 해...",
			"마을 구석 폐건물 구역은 가지 않는 것이 좋아",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["youtubu"] = {
		templates = {"Plain"},
		lines = {
			"강아지들을 아프게 하지마",
			"보험 가입하실래요?",
			"가끔 산 중턱을 지날 때 상자 같은 것이 보이던데?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["blackman"] = {
		templates = {"Plain"},
		lines = {
			"사람을 보고 짖을때는 살살 달래면 돼",
			"여~ 좋은 아침?",
			"대부분의 사람이 잠든 밤에 가끔씩 밖에서 이상한 소리가 들려",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["night_ninja_bae"] = {
		templates = {"Plain"},
		lines = {
			"니 강아지는 고양이를 너무 좋아하는데?",
			"니 강아지 이름이 뭐야?",
			"빨래하기 좋은 날씨네",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["sunglasscow"] = {
		templates = {"Plain"},
		lines = {
			"여~ 좋은 아침?",
			"마을이 발전하면 축제도 생기지 않을까?",
			"가끔씩 마을 바닥에서 무슨 소리가 들려.. 들어봤어?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["purpleman"] = {
		templates = {"Plain"},
		lines = {
			"니 강아지 안물지?",
			"강아지들이 졸려할 때는 너네 집 침대로 가봐",
			"고대인들은 특별한 애완동물을 데리고 다녔다던데?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["runner"] = {
		templates = {"Plain"},
		lines = {
			"니 강아지 이름이 뭐야?",
			"등산은 고되지만 보상을 얻을 수도 있어!",
			"반려동물을 키우는 사람들이 많아지면 축제도 생기지 않을까?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["supreme"] = {
		templates = {"Plain"},
		lines = {
			"마을이 발전하면 축제도 생기지 않을까?",
			"물 속을 들여다 본 적 있어?",
			"가끔 산 중턱을 지날 때 상자 같은 것이 보이던데?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["eightman"] = {
		templates = {"Plain"},
		lines = {
			"강아지들이 졸려할 때는 너네 집 침대로 가봐",
			"다양한 장난감들로 놀아줄 수 있다.",
			"대부분의 사람이 잠든 밤에 가끔씩 밖에서 이상한 소리가 들려",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["walkingman"] = {
		templates = {"Plain"},
		lines = {
			"애정도가 낮게 유지되면 애들이 말을 안듣기 시작해",
			"반려동물을 키우는 사람들이 많아지면 축제도 생기지 않을까?",
			"오늘 저녁엔 뭐하고 놀지?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},
	
	["vendor_Chef"] = {
		templates = {"Plain"},
		lines = {
			"비싼 와인을 마시지도 않고 놓고 가는 손님들이 있어",
			"어서오세요~ 예약 하셨어요?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	

	-- 기본값(모든 미지정 NPC에 적용하고 싶다면 아래 주석 해제)
	-- ["*"] = {
	--     templates = {"Plain"},
	--     lines = {"…", "흠", "……"},
	-- }
}

-- ====== 기본값 ======
local DEFAULT_TEMPLATES = {"Plain"}
local DEFAULT_DURATION: Interval = {min = 3, max = 6.0}
local DEFAULT_INTERVAL: Interval = {min = 60.0, max = 120.0}
local DEFAULT_OFFSET_Y = 3.0
local DEFAULT_MAX_DISTANCE = 80

-- ====== 폴더/레퍼런스 ======
local NPC_LIVE = (Workspace:FindFirstChild("NPC_LIVE") :: Folder?) or Instance.new("Folder")
if not NPC_LIVE.Parent then
	NPC_LIVE.Name = "NPC_LIVE"
	NPC_LIVE.Parent = Workspace
end

local TEMPLATES = (ReplicatedStorage:FindFirstChild("BubbleTemplates") :: Folder?) or Instance.new("Folder")
if not TEMPLATES.Parent then
	TEMPLATES.Name = "BubbleTemplates"
	TEMPLATES.Parent = ReplicatedStorage
end

-- 기본 템플릿 자동 생성(없을 때만)
local function ensureDefaultTemplate(name: string)
	local existing = TEMPLATES:FindFirstChild(name)
	if existing and existing:IsA("BillboardGui") then return existing :: BillboardGui end
	-- 생성
	local bb = Instance.new("BillboardGui")
	bb.Name = name
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(0, 0) -- TextLabel의 AutomaticSize에 맡김
	bb.LightInfluence = 0
	bb.MaxDistance = DEFAULT_MAX_DISTANCE
	bb.ResetOnSpawn = false

	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 0.2
	frame.AutomaticSize = Enum.AutomaticSize.XY
	frame.Size = UDim2.fromOffset(0, 0)
	frame.Parent = bb
	local uic = Instance.new("UICorner", frame); uic.CornerRadius = UDim.new(0, 8)
	local pad = Instance.new("UIPadding", frame); pad.PaddingTop = UDim.new(0,6); pad.PaddingBottom = UDim.new(0,6); pad.PaddingLeft = UDim.new(0,10); pad.PaddingRight = UDim.new(0,10)

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.TextScaled = false
	text.TextWrapped = true
	text.AutomaticSize = Enum.AutomaticSize.XY
	text.TextSize = 18
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Center
	text.TextColor3 = Color3.new(1,1,1)
	text.Parent = frame

	bb.Parent = TEMPLATES
	return bb
end

-- Plain/Emphasis 기본 템플릿 보장
ensureDefaultTemplate("Plain")
do
	local e = TEMPLATES:FindFirstChild("Emphasis")
	if not (e and e:IsA("BillboardGui")) then
		local base = (TEMPLATES:FindFirstChild("Plain") :: BillboardGui)
		local clone = base:Clone()
		clone.Name = "Emphasis"
		-- 살짝 다른 스타일
		local frame = clone:FindFirstChildOfClass("Frame")
		if frame then frame.BackgroundTransparency = 0.1 end
		local text = clone:FindFirstChild("Text", true)
		if text and text:IsA("TextLabel") then text.TextSize = 20 end
		clone.Parent = TEMPLATES
	end
end

local function styleFrame(frame: Frame)
	-- 배경색/투명도
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	frame.BackgroundTransparency = 0.35

	-- 둥근 모서리
	if not frame:FindFirstChildOfClass("UICorner") then
		local uic = Instance.new("UICorner")
		uic.CornerRadius = UDim.new(0, 12)
		uic.Parent = frame
	end

	-- 흰색 테두리
	if not frame:FindFirstChildOfClass("UIStroke") then
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Transparency = 0.2
		stroke.Parent = frame
	end

	-- 안쪽 여백
	if not frame:FindFirstChildOfClass("UIPadding") then
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 6)
		pad.PaddingBottom = UDim.new(0, 6)
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 10)
		pad.Parent = frame
	end
end


-- ====== 유틸 ======
local rng = Random.new()

local function pickOne(list: {any}?): any?
	if not list or #list == 0 then return nil end
	local i = rng:NextInteger(1, #list)
	return list[i]
end

local function pickRange(r: Interval?): number
	local lo = r and r.min or nil
	local hi = r and r.max or nil
	if not lo or not hi then
		lo = DEFAULT_DURATION.min; hi = DEFAULT_DURATION.max
	end
	if hi < lo then hi = lo end
	return rng:NextNumber(lo, hi)
end

local function getHead(model: Model): BasePart?
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then return head end
	if model.PrimaryPart then return model.PrimaryPart end
	return model:FindFirstChildWhichIsA("BasePart")
end

local function getCfgFor(name: string): NpcCfg?
	local cfg = NPC_CONFIGS[name]
	if cfg then return cfg end
	return NPC_CONFIGS["*"]
end

-- 템플릿 찾기: 대소문자 무시
local function getTemplateByName(name: string): BillboardGui?
	local inst = TEMPLATES:FindFirstChild(name)
	if inst and inst:IsA("BillboardGui") then return inst end
	-- case-insensitive fallback
	local lname = string.lower(name)
	for _, c in ipairs(TEMPLATES:GetChildren()) do
		if c:IsA("BillboardGui") and string.lower(c.Name) == lname then
			return c
		end
	end
	return nil
end

-- 어떤 TextLabel이든 찾아오기 (이름/구조 상관없이)
local function getAnyTextLabel(root: Instance): TextLabel?
	-- 1) 우선 "Text"라는 이름을 우선 시도
	local t = root:FindFirstChild("Text", true)
	if t and t:IsA("TextLabel") then return t end
	-- 2) 없으면 후순위로 모든 자손 중 첫 TextLabel
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("TextLabel") then return d end
	end
	return nil
end

-- 말풍선 1회 표시
local function showOnce(npc: Model, cfg: NpcCfg)
	local head = getHead(npc)
	if not head then return end

	local templateName = (pickOne(cfg.templates) :: string?) or (pickOne(DEFAULT_TEMPLATES) :: string)
	local tpl = getTemplateByName(templateName)
	if not tpl then tpl = ensureDefaultTemplate("Plain") end

	local bb = tpl:Clone()
	local offsetY = cfg.offsetY or DEFAULT_OFFSET_Y
	local maxDist = cfg.maxDistance or DEFAULT_MAX_DISTANCE

	bb.Adornee = head
	bb.AlwaysOnTop = true
	bb.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	bb.MaxDistance = maxDist

	local chosenText = pickOne(cfg.lines) :: string?
	local label = getAnyTextLabel(bb) -- ← 변경 포인트
	if label then
		label.Text = chosenText or ""
		label.TextWrapped = true
		-- 필요하면: label.AutomaticSize = Enum.AutomaticSize.XY
	else
		warn(("[NPCSpeech] TextLabel not found in template '%s'"):format(templateName))
	end

	bb.Parent = head

	local life = pickRange(cfg.duration or DEFAULT_DURATION)
	task.delay(life, function()
		if bb and bb.Parent then bb:Destroy() end
	end)
end

-- NPC 루프 시작/중지 관리
local loops: {[Model]: boolean} = {}

local function startLoopFor(npc: Model, cfg: NpcCfg)
	if loops[npc] then return end
	loops[npc] = true
	task.spawn(function()
		-- 존재하는 동안 반복
		while loops[npc] and npc.Parent == NPC_LIVE do
			-- 존재/머리 확인
			local head = getHead(npc)
			if not head then break end

			showOnce(npc, cfg)

			-- 다음 표시까지 대기
			local waitSec = pickRange(cfg.interval or DEFAULT_INTERVAL)
			local elapsed = 0.0
			while loops[npc] and npc.Parent == NPC_LIVE and elapsed < waitSec do
				task.wait(0.25)
				elapsed += 0.25
			end
		end
		loops[npc] = nil
	end)

	-- NPC가 나가면 자동 중지
	npc.AncestryChanged:Connect(function(_, parent)
		if parent ~= NPC_LIVE then
			loops[npc] = nil
			-- 남은 BillboardGui는 헤드에 붙어있어도 헤드가 없어지면 함께 사라짐
			-- 혹시 남아있다면 아래처럼 강제 정리(옵션)
			local head = getHead(npc)
			if head then
				for _, gui in ipairs(head:GetChildren()) do
					if gui:IsA("BillboardGui") then gui:Destroy() end
				end
			end
		end
	end)
end

-- ====== 스폰/제거 감시 ======
local function tryStartForChild(inst: Instance)
	if not inst:IsA("Model") then return end
	local cfg = getCfgFor(inst.Name)
	if not cfg then return end
	startLoopFor(inst, cfg)
end

-- 현재 존재하는 NPC들 시작
for _, child in ipairs(NPC_LIVE:GetChildren()) do
	tryStartForChild(child)
end

-- 이후 추가/제거 감시
NPC_LIVE.ChildAdded:Connect(tryStartForChild)
NPC_LIVE.ChildRemoved:Connect(function(inst)
	if inst:IsA("Model") then
		loops[inst] = nil
		-- BillboardGui 정리(안전)
		local head = getHead(inst)
		if head then
			for _, gui in ipairs(head:GetChildren()) do
				if gui:IsA("BillboardGui") then gui:Destroy() end
			end
		end
	end
end)

