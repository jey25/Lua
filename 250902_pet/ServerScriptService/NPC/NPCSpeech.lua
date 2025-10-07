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
			"What you see isn't everything",
			"I have no business with those weaker than me",
			"I'm not particularly jealous of your pet",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["grandma"] = {
		templates = {"Plain"},
		lines = {
			"The older I get, the less I sleep—it's a problem",
			"Out early today, huh?",
			"After getting older, life doesn't seem like much",
			"This town has many hidden secrets",
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
			"Going to work is tough~",
			"Let's keep going today for the family!",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["engineer"] = {
		templates = {"Plain"},
		lines = {
			"Something broken somewhere?",
			"Need me to fix your house?",
			"I installed a ladder not long ago. The location is a secret",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["illidan"] = {
		templates = {"Plain"},
		lines = {
			"You are not prepared yet!",
			"There is no time to waste.",
			"I have no interest in small fry like you",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["nightwatch_savage"] = {
		templates = {"Plain"},
		lines = {
			"Anyone around worth picking a fight with?",
			"What are you looking at?",
			"Dogs? I'm not scared of them at all...",
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
			"Pets should be as classy as me",
			"Your pet would make the perfect snack for my cutie",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["thief"] = {
		templates = {"Plain"},
		lines = {
			"Anything worth stealing?",
			"Hey, you didn't see any cops on your way here, did you?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["timthespamm"] = {
		templates = {"Plain"},
		lines = {
			"Yo~ good morning?",
			"Your dog doesn't bite, right?",
			"What's your dog's name?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["Mewrila"] = {
		templates = {"Plain"},
		lines = {
			"Oh my, so cute~ ❤️",
			"How old is your pet?",
			"The animal hospital is past the laundromat, then a left, just a bit further",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["nightwatch_blackcat"] = {

		templates = {"Plain"},
		lines = {
			"You might be strong alone, but you can't beat a team",
			"I don't care to talk with rookies",
			"If you become stronger someday, I'll face you",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["STARCODEE_GUN"] = {
		templates = {"Plain"},
		lines = {
			"Shouldn't you put a muzzle on??",
			"Look at all that fur shedding..",
			"Big dogs are scary..",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["sportsman"] = {
		templates = {"Plain"},
		lines = {
			"Perfect weather for a car wash, huh?",
			"Can your pet ride and run too?",
			"Why spend money on something you can't even ride?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["xiaoleung"] = {
		templates = {"Plain"},
		lines = {
			"Puppies need to grow a bit before they can have treats",
			"Got lots of new treats in",
			"Honestly, shouldn't Saturdays be a day off?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["bleus_p"] = {
		templates = {"Plain"},
		lines = {
			"Better not go to the abandoned buildings at the edge of town",
			"Sometimes I see box-like things halfway up the mountain",
			"Sometimes at night, when most people are asleep, strange sounds come from outside",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["Crimson"] = {
		templates = {"Plain"},
		lines = {
			"Your outfit looks nice",
			"Your pet looks delicious",
			"Are you ignoring me because you have a lot of hair now?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["police_c"] = {
		templates = {"Plain"},
		lines = {
			"Seen anyone suspicious?",
			"Night shifts are tough~",
			"Sniff sniff, I think I smell something burning?",

		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["police_b"] = {
		templates = {"Plain"},
		lines = {
			"Seen anyone suspicious?",
			"Night shifts are tough~",
			"Be careful walking around after 10",

		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["police_a"] = {
		templates = {"Plain"},
		lines = {
			"You can't rummage through the substation",
			"When is the new police car arriving?",
			"Don't wander around the park too late at night",

		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},


	["nightwatch_flower"] = {
		templates = {"Plain"},
		lines = {
			"Will I be able to meet you today?",
			"I'll keep you by my side, even if I have to break your legs",
			"Help me so I can help you",

		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["c"] = {
		templates = {"Plain"},
		lines = {
			"Staring at the forest brings back nightmare-like memories",
			"Hey, have you ever been to the hill behind town?",
			"If you see it from afar, don't look back—just run",

		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["thegirl"] = {
		templates = {"Plain"},
		lines = {
			"Why is the bus always late?",
			"I'm allergic to dog hair",
			"Hey you, don't seat your dog next to me",

		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["vendor_bloxmart"] = {
		templates = {"Plain"},
		lines = {
			"Welcome~ This is Bloxmart.",
			"We have everything except what's not here",
			"(Should I confess to her after work?..)",

		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["payleey"] = {
		templates = {"Plain"},
		lines = {
			"Good weather for doing laundry",
			"If the town grows, maybe we'll have festivals?",
			"There are many ways to play with dogs",

		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["Nasynia"] = {
		templates = {"Plain"},
		lines = {
			"Have you seen my husband?",
			"Oh, how cute~ Does this one shed a lot?",
			"Where on earth did he go",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["HideHusband"] = {
		templates = {"Plain"},
		lines = {
			"What—how did you get into someone else's house?",
			"Hiding and hanging out behind my wife's back is the best thrill!",
			"Hey, it's a secret from my wife, got it?",

		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["Personaje"] = {
		templates = {"Plain"},
		lines = {
			"Oh my, what a cute dog—what's the name?",
			"What should we do for fun tonight?",
			"I once saw someone walking around with a very unusual pet",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["KlTSUBEE"] = {
		templates = {"Plain"},
		lines = {
			"Dogs won't like it if you put away the tasty-looking food",
			"They say there are thieves in town after treasure",
			"When you raise pets, you sometimes want to keep a few more",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["cowman"] = {
		templates = {"Plain"},
		lines = {
			"Don't go to the northern ravine of the town",
			"They say keeping affection high grants special abilities",
			"What kind of world will it be in 10 years?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["ninja_bae"] = {
		templates = {"Plain"},
		lines = {
			"Sometimes there are sounds from beneath the town... have you heard?",
			"Hiking is tough, but you might earn rewards!",
			"Don't hurt the dogs",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["gentleman"] = {
		templates = {"Plain"},
		lines = {
			"They say ancients carried special pets with them",
			"Have you ever looked into the water?",
			"When they bark at people, just calm them gently",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["gentlecow"] = {
		templates = {"Plain"},
		lines = {
			"When the dogs are sleepy, try your home bed",
			"You can play with them using various toys.",
			"Your dog really likes cats, huh?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["starcow"] = {
		templates = {"Plain"},
		lines = {
			"If affection stays low, they start disobeying",
			"If more people keep pets, wouldn't festivals appear?",
			"What's your name?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["hba"] = {
		templates = {"Plain"},
		lines = {
			"They say keeping affection high grants special abilities",
			"What kind of world will it be in 10 years?",
			"This darn code breaks everything else when I fix one thing",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["cowman2"] = {
		templates = {"Plain"},
		lines = {
			"Hiking is tough, but you might earn rewards!",
			"Don't hurt the dogs",
			"Stop with the spam calls...",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["cowman3"] = {
		templates = {"Plain"},
		lines = {
			"Have you ever looked into the water?",
			"When they bark at people, calm them gently",
			"Would you like to buy insurance?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["smurf"] = {
		templates = {"Plain"},
		lines = {
			"You can play with them using various toys.",
			"Your dog really likes cats, huh?",
			"Yo~ good morning?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["boxman"] = {
		templates = {"Plain"},
		lines = {
			"If more people keep pets, won't there be festivals?",
			"What's your name?",
			"Your dog doesn't bite, right?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["yellowman"] = {
		templates = {"Plain"},
		lines = {
			"What kind of world will it be in 10 years?",
			"Fix one thing in this darn code and everything else breaks",
			"What's your dog's name?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["bluebird"] = {
		templates = {"Plain"},
		lines = {
			"Don't hurt the dogs",
			"Stop with the spam calls...",
			"Better not go to the abandoned buildings at the edge of town",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["defaultman"] = {
		templates = {"Plain"},
		lines = {
			"When they bark at people, just calm them gently",
			"Would you like to buy insurance?",
			"Sometimes I see box-like things halfway up the mountain",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["signup"] = {
		templates = {"Plain"},
		lines = {
			"Your dog really likes cats, huh?",
			"Yo~ good morning?",
			"Sometimes at night, when most people are asleep, strange sounds come from outside",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["morning_sportsman"] = {
		templates = {"Plain"},
		lines = {
			"What's your name?",
			"Your dog doesn't bite, right?",
			"Good weather for doing laundry",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["stussy"] = {
		templates = {"Plain"},
		lines = {
			"Fix one thing in this darn code and everything else breaks",
			"What's your dog's name?",
			"If the town develops, maybe we'll have festivals?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["biking"] = {
		templates = {"Plain"},
		lines = {
			"Stop with the spam calls...",
			"It's better not to go to the abandoned building area at the edge of town",
			"There are many ways to play with dogs",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["d"] = {
		templates = {"Plain"},
		lines = {
			"Would you like to buy insurance?",
			"Sometimes I see box-like things halfway up the mountain",
			"Oh my, what a cute dog—what's the name?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["nerf"] = {
		templates = {"Plain"},
		lines = {
			"Better not go to the abandoned buildings at the edge of town",
			"Sometimes at night, when most people are asleep, strange sounds are heard outside",
			"What should we do for fun tonight?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["Indian"] = {
		templates = {"Plain"},
		lines = {
			"Sometimes I see box-like things halfway up the mountain",
			"Good weather for doing laundry",
			"I once saw someone walking around with a very unusual pet",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["Dxummy_gaurd"] = {
		templates = {"Plain"},
		lines = {
			"Sometimes at night, when most people are asleep, strange sounds come from outside",
			"There are many ways to play with dogs",
			"Don't go to the northern ravine of the town",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["timthespam"] = {
		templates = {"Plain"},
		lines = {
			"Good weather for doing laundry",
			"Oh my, what a cute dog—what's the name?",
			"Sometimes there are sounds from under the town... have you heard?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["Prabzil"] = {
		templates = {"Plain"},
		lines = {
			"There are many ways to play with dogs",
			"What should we do for fun tonight?",
			"They say the ancients carried special pets with them",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["peter"] = {
		templates = {"Plain"},
		lines = {
			"Oh my, what a cute dog—what's the name?",
			"I've seen someone walking around with a very unusual pet",
			"When the dogs are sleepy, try your home bed",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["hellotatta"] = {
		templates = {"Plain"},
		lines = {
			"What should we do for fun tonight?",
			"Don't go to the northern ravine of the town",
			"If affection stays low, they'll start disobeying",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["catman"] = {
		templates = {"Plain"},
		lines = {
			"They say ancients carried special pets",
			"What's your name?",
			"Hiking is tough, but you might earn rewards!",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["afternoon_cowman"] = {
		templates = {"Plain"},
		lines = {
			"When the dogs are sleepy, try your home bed",
			"Your dog doesn't bite, right?",
			"Have you ever looked into the water?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["eagle"] = {
		templates = {"Plain"},
		lines = {
			"If affection stays low, they start disobeying",
			"What's your dog's name?",
			"You can play with them using various toys.",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["mmp"] = {
		templates = {"Plain"},
		lines = {
			"Hiking is tough, but you might earn rewards!",
			"Better not go to the abandoned building area at the edge of town",
			"If more people keep pets, maybe we'll have festivals?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["ninjapark"] = {
		templates = {"Plain"},
		lines = {
			"Have you ever looked into the water?",
			"Sometimes I see box-like things halfway up the mountain",
			"What kind of world will it be in 10 years?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["canada"] = {
		templates = {"Plain"},
		lines = {
			"You can play with them using various toys.",
			"Sometimes at night, strange sounds come from outside when most people are asleep",
			"Don't hurt the dogs",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["b"] = {
		templates = {"Plain"},
		lines = {
			"If more people keep pets, maybe we'll have festivals?",
			"Good weather for doing laundry",
			"When they bark at people, calm them gently",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["afternoon_gentlecolor"] = {
		templates = {"Plain"},
		lines = {
			"What kind of world will it be in 10 years?",
			"There are many ways to play with dogs",
			"Your dog really likes cats, huh?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["afternoon_musicman"] = {
		templates = {"Plain"},
		lines = {
			"Don't hurt the dogs",
			"Oh my, what a cute dog—what's the name?",
			"Yo~ good morning?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["king"] = {
		templates = {"Plain"},
		lines = {
			"When they bark at people, just calm them gently",
			"What should we do for fun tonight?",
			"Sometimes there are sounds from beneath the town... have you heard?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["afternoon_smurf"] = {
		templates = {"Plain"},
		lines = {
			"Your dog really likes cats, huh?",
			"Sometimes I see box-like things halfway up the mountain",
			"They say ancients carried special pets",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["afternoon_gentlecow"] = {
		templates = {"Plain"},
		lines = {
			"Yo~ good morning?",
			"Sometimes at night, when most people are asleep, strange sounds come from outside",
			"When the dogs are sleepy, try your home bed",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["afternoon_ninja"] = {
		templates = {"Plain"},
		lines = {
			"Your dog doesn't bite, right?",
			"Good weather for doing laundry",
			"If affection stays low, they start disobeying",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["robloxman"] = {
		templates = {"Plain"},
		lines = {
			"What's your dog's name?",
			"If the town develops, maybe there'll be festivals?",
			"Hiking is tough, but you might earn rewards!",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["electroman"] = {
		templates = {"Plain"},
		lines = {
			"Better not go to the abandoned building area at the edge of town",
			"There are many ways to play with dogs",
			"Have you ever looked into the water?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["BarbieBankz"] = {
		templates = {"Plain"},
		lines = {
			"Sometimes I see box-like things halfway up the mountain",
			"Oh my, what a cute dog—what's the name?",
			"You can play with them using various toys.",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["IconicFatma"] = {
		templates = {"Plain"},
		lines = {
			"Sometimes at night, when most people are asleep, strange sounds come from outside",
			"What should we do for fun tonight?",
			"If more people keep pets, maybe we'll have festivals?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["TheOdd"] = {
		templates = {"Plain"},
		lines = {
			"Good weather for doing laundry",
			"They say ancients carried special pets",
			"What kind of world will it be in 10 years?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["theman"] = {
		templates = {"Plain"},
		lines = {
			"If the town develops, maybe we'll have festivals?",
			"When the dogs are sleepy, try your home bed",
			"Sometimes there are sounds from beneath the town... have you heard?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["ninja"] = {
		templates = {"Plain"},
		lines = {
			"What should we do for fun tonight?",
			"If affection stays low, they start disobeying",
			"Hiking is tough, but you might earn rewards!",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["savage"] = {
		templates = {"Plain"},
		lines = {
			"I've seen someone walking around with a very unusual pet",
			"Hiking is tough, but you might earn rewards!",
			"Have you ever looked into the water?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["sol"] = {
		templates = {"Plain"},
		lines = {
			"Don't go to the northern ravine of the town",
			"Have you ever looked into the water?",
			"When they bark at people, calm them gently",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["night_cowman"] = {
		templates = {"Plain"},
		lines = {
			"Sometimes there are sounds beneath the town... have you heard?",
			"You can play with them using various toys.",
			"Your dog really likes cats, huh?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["gentlecolor"] = {
		templates = {"Plain"},
		lines = {
			"They say ancients carried special pets",
			"If more people keep pets, maybe we'll have festivals?",
			"What's your name?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["bleus"] = {
		templates = {"Plain"},
		lines = {
			"When the dogs are sleepy, try your home bed",
			"What kind of world will it be in 10 years?",
			"Fix one thing in this darn code and everything else breaks",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["ggocalcon"] = {
		templates = {"Plain"},
		lines = {
			"If affection stays low, they start disobeying",
			"Don't hurt the dogs",
			"Stop with the spam calls...",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["a"] = {
		templates = {"Plain"},
		lines = {
			"Hiking is tough, but you might earn rewards!",
			"When they bark at people, calm them gently",
			"Would you like to buy insurance?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["night_cowman2"] = {
		templates = {"Plain"},
		lines = {
			"Have you ever looked into the water?",
			"Your dog really likes cats, huh?",
			"Yo~ good morning?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["musicman"] = {
		templates = {"Plain"},
		lines = {
			"You can play with them using various toys.",
			"What's your name?",
			"Your dog doesn't bite, right?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["musicman2"] = {
		templates = {"Plain"},
		lines = {
			"If more people keep pets, maybe we'll have festivals?",
			"Fix one thing in this darn code and everything else breaks",
			"What's your dog's name?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["night_boxman"] = {
		templates = {"Plain"},
		lines = {
			"What kind of world will it be in 10 years?",
			"Stop with the spam calls...",
			"Better not go to the abandoned building area at the edge of town",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["youtubu"] = {
		templates = {"Plain"},
		lines = {
			"Don't hurt the dogs",
			"Would you like to buy insurance?",
			"Sometimes I see box-like things halfway up the mountain",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["blackman"] = {
		templates = {"Plain"},
		lines = {
			"When they bark at people, calm them gently",
			"Yo~ good morning?",
			"Sometimes at night, when most people are asleep, strange sounds come from outside",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["night_ninja_bae"] = {
		templates = {"Plain"},
		lines = {
			"Your dog really likes cats, huh?",
			"What's your dog's name?",
			"Good weather for doing laundry",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["sunglasscow"] = {
		templates = {"Plain"},
		lines = {
			"Yo~ good morning?",
			"If the town develops, maybe we'll have festivals?",
			"Sometimes there are sounds from beneath the town... have you heard?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["purpleman"] = {
		templates = {"Plain"},
		lines = {
			"Your dog doesn't bite, right?",
			"When the dogs are sleepy, try your home bed",
			"They say ancients carried special pets",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},

	["runner"] = {
		templates = {"Plain"},
		lines = {
			"What's your dog's name?",
			"Hiking is tough, but you might earn rewards!",
			"If more people keep pets, maybe we'll have festivals?",
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
			"When the pets are sleepy, go to your bed",
			"You can play with a variety of toys",
			"Sometimes at night when people are asleep, strange noises are heard outside",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=20, max=50},
	},

	["walkingman"] = {
		templates = {"Plain"},
		lines = {
			"If your affection level remains low, your children will start to disobey you",
			"If more people start raising pets, wouldn't there be festivals?",
			"What are you doing tonight?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},
	
	["vendor_Chef"] = {
		templates = {"Plain"},
		lines = {
			"There are customers who leave expensive wine without even drinking it",
			"Welcome~ Have you made a reservation?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=30, max=60},
	},
	
	["vendor_doctor2"] = {
		templates = {"Plain"},
		lines = {
			"Mentally ill patients sometimes disappear after drinking alcohol",
			"Where does the cold wind keep coming from?",
		},
		offsetY = 3.25,
		duration = {min=5.5, max=6.5},
		interval = {min=20, max=50},
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

