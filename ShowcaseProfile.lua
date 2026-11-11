local _, ns = ...
-- Showcase: the author's own everyday layout (made on Alberich), offered to
-- everyone as a ready-made profile. Seeded once per account at login by
-- ns:EnsureShowcaseProfile(); deleting or editing it is the player's choice.
ns.SHOWCASE_PROFILE_NAME = "Showcase"
-- Picker frames the profile uses, kept under the same IDs as the original.
ns.SHOWCASE_CUSTOM_TARGETS = {
    custom_frame_1783795632 = { exact = true, label = "CompactPartyFrameTitle", name = "CompactPartyFrameTitle" },
    custom_frame_1945410022 = { exact = true, label = "CompactRaidFrameManager", name = "CompactRaidFrameManager" },
    custom_frame_421152822 = { exact = true, label = "MinimapCluster", name = "MinimapCluster" },
    custom_frame_556906171 = { exact = false, label = "QuickJoinToastButton", name = "QuickJoinToastButton" },
    custom_frame_694667110 = { exact = true, label = "GamepadMainActionBarFramePageUnitLeftClassAction", name = "GamepadMainActionBarFramePageUnitLeftClassAction" },
}
ns.SHOWCASE_PROFILE = {
    groups = {
        group1 = {
            members = {
                eui_bar2 = true,
                eui_main = true,
                stance_bar = true,
            },
            name = "Reveal group",
        },
    },
    links = {
        eui_player = {
            eui_target = true,
        },
    },
    nextGroupID = 2,
    nextReactionID = 126,
    targets = {
        bags_bar = {
            atRest = 0,
            enabled = true,
            fadeDelay = 0.8,
            fadeDuration = 0.2,
            fadeInDuration = 0.2,
            fadeOutDuration = 0.2,
            reactions = {
                [1] = {
                    condition = "mouseover",
                    enabled = true,
                    id = 16,
                    opacity = 1,
                    requirements = {
                    },
                },
            },
        },
        blizzard_damage_meter = {
            atRest = 0,
            enabled = true,
            fadeDelay = 0.8,
            fadeInDuration = 0.2,
            fadeOutDuration = 0.2,
            reactions = {
                [1] = {
                    condition = "mouseover",
                    enabled = true,
                    id = 122,
                    opacity = 1,
                    requirements = {
                    },
                },
                [2] = {
                    condition = "dungeon",
                    enabled = true,
                    id = 124,
                    opacity = 1,
                    requirements = {
                        [1] = "combat",
                    },
                },
            },
        },
        cdm_buff_bars = {
            atRest = 0,
            enabled = true,
            fadeDelay = 0.8,
            fadeInDuration = 0.2,
            fadeOutDuration = 0.2,
            reactions = {
                [1] = {
                    condition = "mouseover",
                    enabled = true,
                    id = 87,
                    opacity = 1,
                    requirements = {
                    },
                },
                [2] = {
                    condition = "combat",
                    enabled = true,
                    id = 88,
                    opacity = 1,
                    requirements = {
                    },
                },
            },
        },
        cdm_buffs = {
            atRest = 0,
            enabled = true,
            fadeDelay = 0.8,
            fadeInDuration = 0.2,
            fadeOutDuration = 0.2,
            reactions = {
                [1] = {
                    condition = "mouseover",
                    enabled = true,
                    id = 85,
                    opacity = 1,
                    requirements = {
                    },
                },
                [2] = {
                    condition = "combat",
                    enabled = true,
                    id = 86,
                    opacity = 1,
                    requirements = {
                    },
                },
            },
        },
        cdm_cooldowns = {
            atRest = 0,
            enabled = true,
            fadeDelay = 0.8,
            fadeInDuration = 0.2,
            fadeOutDuration = 0.2,
            reactions = {
                [1] = {
                    condition = "mouseover",
                    enabled = true,
                    id = 89,
                    opacity = 1,
                    requirements = {
                    },
                },
                [2] = {
                    condition = "combat",
                    enabled = true,
                    id = 90,
                    opacity = 1,
                    requirements = {
                    },
                },
            },
        },
        cdm_utility = {
            atRest = 0,
            enabled = true,
            fadeDelay = 0.8,
            fadeInDuration = 0.2,
            fadeOutDuration = 0.2,
            reactions = {
                [1] = {
                    condition = "mouseover",
                    enabled = true,
                    id = 83,
                    opacity = 1,
                    requirements = {
                    },
                },
                [2] = {
                    condition = "combat",
                    enabled = true,
                    id = 84,
                    opacity = 1,
                    requirements = {
                    },
                },
            },
        },
        chat = {
            atRest = 0,
            enabled = true,
            fadeDelay = 2.35,
            fadeInDuration = 0.2,
            fadeOutDuration = 0.5,
            reactions = {
                [1] = {
                    condition = "mouseover",
                    enabled = true,
                    id = 92,
                    opacity = 1,
                    requirements = {
                    },
                },
                [2] = {
                    condition = "chat_typing",
                    enabled = true,
                    id = 94,
                    opacity = 1,
                    requirements = {
                    },
                },
            },
        },
        custom_frame_1783795632 = {
            atRest = 0,
            enabled = true,
            fadeDelay = 0.8,
            fadeInDuration = 0.2,
            fadeOutDuration = 0.2,
            reactions = {
            },
        },
        custom_frame_1945410022 = {
            atRest = 0,
            enabled = true,
            fadeDelay = 0.8,
            fadeInDuration = 0.2,
            fadeOutDuration = 0.2,
            reactions = {
                [1] = {
                    condition = "mouseover",
                    enabled = true,
                    id = 101,
                    opacity = 1,
                    requirements = {
                    },
                },
            },
        },
        custom_frame_421152822 = {
            atRest = 0.12,
            enabled = true,
            fadeDelay = 3.9,
            fadeDuration = 0.2,
            fadeInDuration = 0.2,
            fadeOutDuration = 0.2,
            layoutPivot = "BOTTOMRIGHT",
            reactions = {
                [1] = {
                    condition = "movement",
                    enabled = true,
                    id = 29,
                    layoutLine = true,
                    movementExpected = true,
                    opacity = 1,
                    requirements = {
                    },
                },
                [2] = {
                    condition = "mouseover",
                    enabled = true,
                    id = 8,
                    layoutInstant = true,
                    layoutLine = true,
                    opacity = 1,
                    requirements = {
                    },
                    scale = 1,
                },
                [3] = {
                    condition = "combat",
                    enabled = true,
                    id = 9,
                    opacity = 1,
                    requirements = {
                    },
                },
            },
            restLayoutInstant = true,
            restLayoutLine = true,
            restScale = 0.75,
        },
        custom_frame_556906171 = {
            atRest = 0.12,
            enabled = true,
            fadeDelay = 0.8,
            fadeInDuration = 0.2,
            fadeOutDuration = 0.2,
            reactions = {
                [1] = {
                    condition = "mouseover",
                    enabled = true,
                    id = 105,
                    opacity = 1,
                    requirements = {
                    },
                },
                [2] = {
                    condition = "combat",
                    enabled = true,
                    id = 106,
                    opacity = 1,
                    requirements = {
                    },
                },
            },
        },
        custom_frame_694667110 = {
            atRest = 0.12,
            enabled = true,
            fadeDelay = 0.8,
            fadeInDuration = 0.2,
            fadeOutDuration = 0.2,
            reactions = {
                [1] = {
                    condition = "mouseover",
                    enabled = true,
                    id = 119,
                    opacity = 1,
                    requirements = {
                    },
                },
                [2] = {
                    condition = "combat",
                    enabled = true,
                    id = 120,
                    opacity = 1,
                    requirements = {
                    },
                },
            },
        },
        eui_bar2 = {
            atRest = 0,
            enabled = true,
            fadeDelay = 0.8,
            fadeInDuration = 0.2,
            fadeOutDuration = 0.2,
            reactions = {
                [1] = {
                    condition = "mouseover",
                    enabled = true,
                    id = 97,
                    opacity = 1,
                    requirements = {
                    },
                },
            },
        },
        eui_bar8 = {
            atRest = 0,
            enabled = true,
            fadeDelay = 0.8,
            fadeInDuration = 0.2,
            fadeOutDuration = 0.2,
            reactions = {
                [1] = {
                    condition = "combat",
                    enabled = true,
                    id = 117,
                    opacity = 0.7,
                    requirements = {
                    },
                },
                [2] = {
                    condition = "dungeon",
                    enabled = true,
                    id = 121,
                    opacity = 0.7,
                    requirements = {
                    },
                },
            },
        },
        eui_main = {
            atRest = 0,
            enabled = true,
            fadeDelay = 0.8,
            fadeDuration = 0.2,
            fadeInDuration = 0.2,
            fadeOutDuration = 0.2,
            reactions = {
                [1] = {
                    condition = "mouseover",
                    enabled = true,
                    id = 18,
                    opacity = 1,
                    requirements = {
                    },
                },
            },
        },
        eui_player = {
            atRest = 0.12,
            enabled = true,
            fadeDelay = 0.8,
            fadeDuration = 0.2,
            fadeInDuration = 0.2,
            fadeOutDuration = 0.2,
            reactions = {
                [1] = {
                    condition = "mouseover",
                    enabled = true,
                    id = 26,
                    opacity = 1,
                    requirements = {
                    },
                },
                [2] = {
                    condition = "combat",
                    enabled = true,
                    id = 27,
                    opacity = 1,
                    requirements = {
                    },
                },
                [3] = {
                    condition = "target_hostile",
                    enabled = true,
                    id = 59,
                    opacity = 0.4,
                    requirements = {
                    },
                },
                [4] = {
                    condition = "target_friendly",
                    enabled = true,
                    id = 58,
                    opacity = 0.3,
                    requirements = {
                    },
                },
            },
        },
        eui_target = {
            atRest = 0.12,
            enabled = true,
            fadeDelay = 0.8,
            fadeDuration = 0.2,
            fadeInDuration = 0.2,
            fadeOutDuration = 0.2,
            reactions = {
                [1] = {
                    condition = "mouseover",
                    enabled = true,
                    id = 56,
                    opacity = 1,
                    requirements = {
                    },
                },
                [2] = {
                    condition = "combat",
                    enabled = true,
                    id = 57,
                    opacity = 1,
                    requirements = {
                    },
                },
            },
        },
        gamepad_base = {
            atRest = 0.12,
            enabled = true,
            fadeDelay = 0,
            fadeDuration = 0.05,
            fadeInDuration = 0.05,
            fadeOutDuration = 0.05,
            reactions = {
                [1] = {
                    condition = "mouseover",
                    enabled = true,
                    id = 36,
                    opacity = 1,
                    requirements = {
                    },
                },
                [2] = {
                    condition = "combat",
                    enabled = true,
                    id = 91,
                    opacity = 0.5,
                    requirements = {
                    },
                },
                [3] = {
                    condition = "gamepad_bar_active",
                    enabled = true,
                    gamepadExpected = false,
                    id = 72,
                    opacity = 0,
                    requirements = {
                    },
                },
            },
        },
        gamepad_both = {
            atRest = 0,
            enabled = true,
            fadeDelay = 0,
            fadeDuration = 0.05,
            fadeInDuration = 0.05,
            fadeOutDuration = 0.05,
            reactions = {
                [1] = {
                    condition = "gamepad_bar_active",
                    enabled = true,
                    gamepadExpected = true,
                    id = 71,
                    opacity = 1,
                    requirements = {
                    },
                },
            },
        },
        gamepad_input_legend = {
            atRest = 1,
            enabled = true,
            fadeDelay = 0.8,
            fadeDuration = 0.2,
            fadeInDuration = 0.2,
            fadeOutDuration = 0.2,
            reactions = {
                [1] = {
                    condition = "mouseover",
                    enabled = true,
                    id = 67,
                    opacity = 1,
                    requirements = {
                    },
                },
                [2] = {
                    condition = "gamepad_lt_held",
                    enabled = true,
                    gamepadExpected = false,
                    id = 73,
                    opacity = 0,
                    requirements = {
                        [1] = "gamepad_rt_held_no",
                        [2] = "gamepad_right_shoulder_held_no",
                        [3] = "gamepad_left_shoulder_held_no",
                    },
                },
            },
        },
        gamepad_lt = {
            atRest = 0,
            enabled = true,
            fadeDelay = 0,
            fadeDuration = 0.05,
            fadeInDuration = 0.05,
            fadeOutDuration = 0.05,
            reactions = {
                [1] = {
                    condition = "gamepad_bar_active",
                    enabled = true,
                    gamepadExpected = true,
                    id = 69,
                    opacity = 1,
                    requirements = {
                    },
                },
            },
        },
        gamepad_rt = {
            atRest = 0,
            enabled = true,
            fadeDelay = 0,
            fadeDuration = 0.05,
            fadeInDuration = 0.05,
            fadeOutDuration = 0.05,
            reactions = {
                [1] = {
                    condition = "gamepad_bar_active",
                    enabled = true,
                    gamepadExpected = true,
                    id = 70,
                    opacity = 1,
                    requirements = {
                    },
                },
            },
        },
        gamepad_shoulder_left = {
            atRest = 0,
            enabled = true,
            fadeDelay = 0,
            fadeDuration = 0.05,
            fadeInDuration = 0.05,
            fadeOutDuration = 0.05,
            reactions = {
                [1] = {
                    condition = "gamepad_left_shoulder_held",
                    enabled = true,
                    gamepadExpected = true,
                    id = 65,
                    opacity = 1,
                    requirements = {
                    },
                },
                [2] = {
                    condition = "mouseover",
                    enabled = true,
                    id = 61,
                    opacity = 1,
                    requirements = {
                    },
                },
            },
        },
        gamepad_shoulder_right = {
            atRest = 0,
            enabled = true,
            fadeDelay = 0,
            fadeDuration = 0.05,
            fadeInDuration = 0.05,
            fadeOutDuration = 0.05,
            reactions = {
                [1] = {
                    condition = "gamepad_right_shoulder_held",
                    enabled = true,
                    gamepadExpected = true,
                    id = 66,
                    opacity = 1,
                    requirements = {
                    },
                },
                [2] = {
                    condition = "mouseover",
                    enabled = true,
                    id = 63,
                    opacity = 1,
                    requirements = {
                    },
                },
            },
        },
        micro_menu = {
            atRest = 0,
            enabled = true,
            fadeDelay = 0.8,
            fadeDuration = 0.2,
            fadeInDuration = 0.2,
            fadeOutDuration = 0.2,
            reactions = {
                [1] = {
                    condition = "mouseover",
                    enabled = true,
                    id = 22,
                    opacity = 1,
                    requirements = {
                    },
                },
            },
        },
        objectives = {
            atRest = 0,
            enabled = true,
            fadeDelay = 2.1,
            fadeDuration = 0.2,
            fadeInDuration = 0.05,
            fadeOutDuration = 0.5,
            layoutPivot = "TOPRIGHT",
            reactions = {
                [1] = {
                    condition = "mouseover",
                    enabled = true,
                    id = 10,
                    layoutInstant = true,
                    layoutLine = true,
                    opacity = 1,
                    requirements = {
                    },
                    scale = 1,
                },
                [2] = {
                    condition = "quest_accepted",
                    duration = 3,
                    enabled = true,
                    id = 74,
                    opacity = 1,
                    requirements = {
                    },
                },
                [3] = {
                    condition = "quest_objective",
                    duration = 3,
                    enabled = true,
                    id = 75,
                    opacity = 1,
                    requirements = {
                    },
                },
                [4] = {
                    condition = "quest_update",
                    duration = 3,
                    enabled = true,
                    id = 76,
                    opacity = 1,
                    requirements = {
                    },
                },
            },
            restLayoutInstant = true,
            restLayoutLine = true,
            restScale = 0.8,
        },
        party_frames = {
            atRest = 0,
            enabled = true,
            fadeDelay = 0.8,
            fadeInDuration = 0.2,
            fadeOutDuration = 0.2,
            reactions = {
                [1] = {
                    condition = "elite_combat",
                    enabled = true,
                    id = 115,
                    opacity = 1,
                    requirements = {
                    },
                },
                [2] = {
                    condition = "mouseover",
                    enabled = true,
                    id = 111,
                    opacity = 1,
                    requirements = {
                    },
                },
                [3] = {
                    condition = "player_health",
                    enabled = true,
                    id = 114,
                    opacity = 0.7,
                    percentageOperator = "<",
                    percentageThreshold = 95,
                    requirements = {
                    },
                },
                [4] = {
                    condition = "party_health",
                    enabled = true,
                    id = 113,
                    opacity = 0.5,
                    percentageOperator = "<",
                    percentageThreshold = 95,
                    requirements = {
                    },
                },
            },
        },
        player_buffs = {
            atRest = 0.12,
            enabled = true,
            fadeDelay = 0.8,
            fadeInDuration = 0.2,
            fadeOutDuration = 0.2,
            reactions = {
                [1] = {
                    condition = "mouseover",
                    enabled = true,
                    id = 77,
                    opacity = 1,
                    requirements = {
                    },
                },
                [2] = {
                    condition = "combat",
                    enabled = true,
                    id = 78,
                    opacity = 0.7,
                    requirements = {
                    },
                },
            },
        },
        player_debuffs = {
            atRest = 0,
            enabled = true,
            fadeDelay = 0.8,
            fadeInDuration = 0.2,
            fadeOutDuration = 0.2,
            reactions = {
                [1] = {
                    condition = "mouseover",
                    enabled = true,
                    id = 79,
                    opacity = 1,
                    requirements = {
                    },
                },
                [2] = {
                    condition = "combat",
                    enabled = true,
                    id = 80,
                    opacity = 1,
                    requirements = {
                    },
                },
            },
        },
        stance_bar = {
            atRest = 0,
            enabled = true,
            fadeDelay = 0.8,
            fadeInDuration = 0.2,
            fadeOutDuration = 0.2,
            reactions = {
                [1] = {
                    condition = "mouseover",
                    enabled = true,
                    id = 100,
                    opacity = 1,
                    requirements = {
                    },
                },
            },
        },
        status_bar_primary = {
            atRest = 0,
            enabled = true,
            fadeDelay = 0.8,
            fadeDuration = 0.2,
            fadeInDuration = 0.2,
            fadeOutDuration = 0.2,
            reactions = {
                [1] = {
                    condition = "mouseover",
                    enabled = true,
                    id = 20,
                    opacity = 1,
                    requirements = {
                    },
                },
            },
        },
    },
    visibilityLinks = {
        chat = {
            custom_frame_556906171 = true,
        },
        eui_main = {
            eui_bar2 = true,
            stance_bar = true,
        },
        eui_player = {
            eui_target = true,
        },
    },
}
