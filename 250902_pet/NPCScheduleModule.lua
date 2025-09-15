-- ServerStorage/NPCScheduleConfig
local config = {
    POLL_SECS = 5, -- 몇 초 간격으로 시간대 체크할지
    TEMPLATE_FOLDER_NAME = "NPC_TEMPLATES",
    LIVE_FOLDER_NAME = "NPC_LIVE",

    -- 제거 방식: "destroy" (완전 삭제) 또는 "park" (Parent=nil로 숨기고 재사용)
    DESPAWN_MODE = "destroy",

    GROUPS = {
        Vendors = {
            windows = {{
                start = 9.0,
                stop = 18.0
            }},
            -- 이 그룹에서 시간대에 보이게 할 템플릿 이름들
            npcs = {"vendor_walmart", "vendor_doctor", "vendor_greenninja", "vendor_a", "vendor_dogman", "vendor_spy",
                    "vendor_doctor2", "vendor_cowman", "vendor_bloxmart", "vendor_jewelry", "vendor_Chef", "xiaoleung"}
        },

        morning = {
            windows = {{
                start = 6.0,
                stop = 12.0
            }},
            npcs = {"cowman", "ninja_bae", "gentleman", "gentlecow", "starcow", "police_b", "hba", "cowman2", "cowman3",
                    "smurf", "boxman", "yellowman", "bluebird", "defaultman", "bleus_p", "signup", "morning_sportsman",
                    "thegirl", "stussy", "biking", "d", "nerf", "Indian", "Dxummy_gaurd", "Mewrila", "Nasynia",
                    "timthespam", "Prabzil", "peter", "Walkingman", "grandma", "hellotatta"}
        },

        afternoon = {
            windows = {{
                start = 12.0,
                stop = 20.0
            }},
            npcs = {"catman", "afternoon_cowman", "eagle", "illidan", "mmp", "ninjapark", "canada", "b", "police_a",
                    "police_b", "sportsman", "afternoon_gentlecolor", "afternoon_musicman", "engineer", "king", "thief",
                    "afternoon_smurf", "afternoon_gentlecow", "afternoon_ninja", "c", "robloxman", "electroman",
                    "biking", "snakeman", "Indian", "Amogus", "BarbieBankz", "Crimson", "Dxummy_gaurd", "IconicFatma",
                    "KlTSUBEE", "Mewrila", "Nasynia", "timthespamm", "STARCODEE_GUN", "TheOdd", "peter", "payleey",
                    "theman"}
        },

        Night = {
            windows = {{
                start = 18.0,
                stop = 24.0
            }},
            npcs = {"ninja", "savage", "sol", "night_cowman", "gentlecolor", "bleus", "ggocalcon", "a", "night_cowman2",
                    "police_a", "police_c", "musicman", "musicman2", "night_boxman", "youtubu", "blackman",
                    "night_ninja_bae", "sunglasscow", "purpleman", "runner", "supreme", "eightman", "Amogus", "Crimson",
                    "IconicFatma", "KlTSUBEE", "Personaje", "STARCODEE_GUN", "TheOdd", "Walkingman", "walkingman"}
        },

        NightWatch = {
            windows = {{
                start = 22.0,
                stop = 3.0
            }},
            npcs = {"nightwatch_zombie", "nightwatch_pumpkin", "nightwatch_blackcat", "police_c", "nightwatch_zombie2",
                    "nightwatch_crazy", "nightwatch_savage", "nightwatch_nudeman", "nightwatch_flower",
                    "nightwatch_eagle", "nightwatch_DeathDollieOriginal", "nightwatch_Goblin", "nightwatch_Skeleton",
                    "nightwatch_zoechickie"}
        }
    }
}

return config
