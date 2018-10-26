return {
	["custom_nodes"] = {
		{
			["category"] = "action",
			["description"] = "testaa",
			["name"] = "test",
			["properties"] = {
			},
			["scope"] = "node",
			["title"] = "test",
			["version"] = "0.3.0",
		},
	},
	["description"] = "",
	["display"] = {
		["camera_x"] = 550,
		["camera_y"] = 378,
		["camera_z"] = 1,
		["x"] = -144,
		["y"] = 36,
	},
	["id"] = "f8620da7-597a-4a26-8014-bcb402e857aa",
	["nodes"] = {
		["1a179508-8df5-41a0-80cd-4237fc68893e"] = {
			["children"] = {
				"d069f9d2-ffff-42ba-83ca-aef0a015362a",
				"72a80c6e-3677-4bd8-82bb-d7930e457ef8",
			},
			["description"] = "",
			["display"] = {
				["x"] = 264,
				["y"] = 192,
			},
			["id"] = "1a179508-8df5-41a0-80cd-4237fc68893e",
			["name"] = "MemSequence",
			["properties"] = {
				["precondition"] = "findTarget",
			},
			["title"] = "战斗",
		},
		["3b237620-f3f1-481e-b327-b720b29c6848"] = {
			["children"] = {
				"53ed2210-24ed-41a5-8855-cdff56965e3b",
				"461bf738-37c3-4bc8-865e-8d741b89a1ad",
			},
			["description"] = "",
			["display"] = {
				["x"] = 264,
				["y"] = 12,
			},
			["id"] = "3b237620-f3f1-481e-b327-b720b29c6848",
			["name"] = "MemSequence",
			["properties"] = {
				["precondition"] = "noTarget",
			},
			["title"] = "巡逻",
		},
		["461bf738-37c3-4bc8-865e-8d741b89a1ad"] = {
			["description"] = "",
			["display"] = {
				["x"] = 480,
				["y"] = 60,
			},
			["id"] = "461bf738-37c3-4bc8-865e-8d741b89a1ad",
			["name"] = "Runner",
			["properties"] = {
				["operation"] = "randomMove",
				["precondition"] = "",
			},
			["title"] = "随机移动",
		},
		["53ed2210-24ed-41a5-8855-cdff56965e3b"] = {
			["description"] = "",
			["display"] = {
				["x"] = 480,
				["y"] = -24,
			},
			["id"] = "53ed2210-24ed-41a5-8855-cdff56965e3b",
			["name"] = "Runner",
			["properties"] = {
				["operation"] = "randomSpeak",
				["precondition"] = "",
			},
			["title"] = "随机说话",
		},
		["59630548-aa01-4423-a437-1461917c9751"] = {
			["description"] = "",
			["display"] = {
				["x"] = 480,
				["y"] = -120,
			},
			["id"] = "59630548-aa01-4423-a437-1461917c9751",
			["name"] = "Runner",
			["properties"] = {
				["operation"] = "goHome",
				["precondition"] = "",
			},
			["title"] = "回家",
		},
		["72a80c6e-3677-4bd8-82bb-d7930e457ef8"] = {
			["description"] = "",
			["display"] = {
				["x"] = 480,
				["y"] = 240,
			},
			["id"] = "72a80c6e-3677-4bd8-82bb-d7930e457ef8",
			["name"] = "Runner",
			["properties"] = {
				["operation"] = "attack",
				["precondition"] = "",
			},
			["title"] = "攻击",
		},
		["c1b20100-b0ef-4137-99af-f48af9182318"] = {
			["children"] = {
				"e886a318-7db1-436e-b83c-1755651c1d2b",
				"3b237620-f3f1-481e-b327-b720b29c6848",
				"1a179508-8df5-41a0-80cd-4237fc68893e",
			},
			["description"] = "",
			["display"] = {
				["x"] = 60,
				["y"] = 36,
			},
			["id"] = "c1b20100-b0ef-4137-99af-f48af9182318",
			["name"] = "MemPriority",
			["properties"] = {
				["precondition"] = "",
			},
			["title"] = "预警",
		},
		["d069f9d2-ffff-42ba-83ca-aef0a015362a"] = {
			["description"] = "",
			["display"] = {
				["x"] = 480,
				["y"] = 144,
			},
			["id"] = "d069f9d2-ffff-42ba-83ca-aef0a015362a",
			["name"] = "Runner",
			["properties"] = {
				["operation"] = "moveToTarget",
				["precondition"] = "",
			},
			["title"] = "移动到目标符近",
		},
		["e886a318-7db1-436e-b83c-1755651c1d2b"] = {
			["children"] = {
				"59630548-aa01-4423-a437-1461917c9751",
			},
			["description"] = "",
			["display"] = {
				["x"] = 264,
				["y"] = -120,
			},
			["id"] = "e886a318-7db1-436e-b83c-1755651c1d2b",
			["name"] = "MemSequence",
			["properties"] = {
				["precondition"] = "isNeedGoHome",
			},
			["title"] = "回家",
		},
	},
	["properties"] = {
	},
	["root"] = "c1b20100-b0ef-4137-99af-f48af9182318",
	["scope"] = "tree",
	["title"] = "测试",
	["version"] = "0.3.0",
}
