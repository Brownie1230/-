-- Locale (ModuleScript) — ReplicatedStorage
-- Все тексты игры на двух языках: русский (ru) и английский (en).
-- Язык выбирается автоматически по настройкам Roblox игрока:
-- русскоязычным — русский, всем остальным — английский.
-- Хочешь добавить язык? Скопируй блок en, переведи и добавь проверку в Locale.detect.

local Locale = {}

local S = {}

S.ru = {
	-- сообщения сервера
	alarm = "🚨 ТРЕВОГА! Повар в ЯРОСТИ и стал быстрее!",
	join_rats = "🐀 %s присоединился к крысам!",
	chef_is = "👨‍🍳 Повар — %s! Крысы, устройте хаос!",
	chef_bot = "🤖 На смену вышел повар-робот! Крысы, устройте хаос!",
	chef_left = "Повар сбежал! Его заменил робот 🤖",
	sabotaged = "💥 %s: «%s» — готово!",
	repaired = "🔧 %s починил: «%s»",
	busy = "Тут уже работает другая крыса!",
	caught = "🪤 %s в клетке! Спасите!",
	rescued = "🔓 %s открыл клетку! Свободно крыс: %d",
	trapped = "🪤 %s — в мышеловке!",
	trap_cooldown = "Мышеловка перезаряжается: %d сек.",
	trap_placed = "🪤 Мышеловка поставлена!",
	no_cheese = "Не хватает сыра 🧀 — играй, чтобы заработать!",
	bought = "Куплено: %s %s",
	bot_name = "Повар-робот 🤖",
	-- причины победы
	reason_chaos = "Ресторан в полном хаосе!",
	reason_caught = "Все крысы сидят в клетке!",
	reason_norats = "Крыс не осталось",
	reason_time = "Время вышло — ресторан выстоял!",
	-- награды
	reward_Sabotage = "Поломка",
	reward_Rescue = "Спасение",
	reward_Catch = "Поймал крысу",
	reward_Repair = "Ремонт",
	reward_RatWin = "Победа",
	reward_ChefWin = "Победа",
	reward_Participation = "За игру",
	-- интерфейс
	waiting = "Ждём игроков...",
	start_in = "Старт через %d",
	get_ready = "Приготовься!",
	round_over = "Раунд окончен",
	chaos_bar = "Хаос: %d%%",
	alarm_bar = "🚨 ТРЕВОГА! Хаос: %d%%",
	chaos_go = "ХАОС!",
	you_rat = "🐀 ТЫ — КРЫСА",
	goal_rat = "Ломай вещи (жёлтая обводка), наполни шкалу хаоса до 100% и не попадись повару!",
	you_chef = "👨‍🍳 ТЫ — ПОВАР",
	goal_chef = "Лови крыс сачком, ставь мышеловки и чини поломки, пока не кончится время!",
	role_caught = "🪤 Ты в клетке!",
	hint_caught = "Пищи (Q), чтобы позвать друзей!",
	role_stunned = "🪤 Мышеловка!",
	hint_stunned = "Подожди пару секунд...",
	role_rat = "🐀 Ты — крыса",
	hint_rat = "E — пакостить • Shift — бег • Q — писк",
	role_chef = "👨‍🍳 Ты — повар",
	hint_chef = "1 — сачок • 2 — мышеловка • E — чинить",
	role_lobby = "🏠 Лобби",
	hint_lobby = "Выбери шапку и жди начала раунда!",
	hunger = "🧀 Сытость",
	stamina = "🏃 Бег",
	tasks_rat = "🐀 Напакости:",
	tasks_chef = "🔧 Почини:",
	all_ok = "Пока всё цело... 👀",
	tab_hide = "Tab — скрыть",
	shop_button = "🎩 Шапки",
	shop_title = "🎩 Шапки для крысы",
	chef_yes = "👨‍🍳 Хочу быть поваром: ДА",
	chef_no = "👨‍🍳 Хочу быть поваром: НЕТ",
	equipped = "Надето ✓",
	equip = "Надеть",
	buy = "Купить 🧀%d",
	locked = "🔒 🧀%d",
	victory = "🎉 ПОБЕДА! 🎉",
	defeat = "😿 Поражение",
	rats_won = "🐀 Крысы победили!",
	chef_won = "👨‍🍳 Повар победил!",
	mvp = "⭐ Лучший игрок: %s (%d)",
	round_coins = "+%d 🧀 за раунд",
	next_round = "Следующий раунд через %d сек.",
	squeak = "Пи-пи! 🐭",
	-- подсказки E
	prompt_sabotage = "Напакостить",
	prompt_repair = "Починить",
	prompt_free = "Открыть клетку",
	cage = "Клетка",
	-- мини-игры
	mg_wires = "🔌 Перегрызи провода!",
	mg_wires_hint = "Соедини провода одного цвета",
	mg_mash = "🦷 Грызи быстрее!",
	mg_mash_hint = "Жми кнопку, E или Пробел",
	mg_code = "🔢 Взломай пароль!",
	mg_code_hint = "Набери пароль со стикера",
	mg_timing = "⏱ Жми вовремя!",
	mg_timing_hint = "Останови полоску на зелёном (E / Пробел)",
	mg_done = "✔ Готово!",
	mg_wrong = "❌ Не то!",
	mg_password = "Пароль:",
	mg_gnaw = "🦷 ГРЫЗТЬ!",
	mg_stop = "⏱ СТОП!",
	-- инструменты повара
	tool_net = "Сачок",
	tool_net_tip = "Клик — поймать крысу",
	tool_trap = "Мышеловка",
	tool_trap_tip = "Клик — поставить мышеловку",
	-- донат и бонусы
	reward_Golden = "Золотой сыр",
	golden_spawn = "✨ Появился ЗОЛОТОЙ СЫР! Кто найдёт первым?",
	golden_found = "✨ %s нашёл золотой сыр! +%d 🧀",
	daily = "🎁 Ежедневный бонус: +%d 🧀 (день %d подряд)",
	thanks_vip = "👑 Спасибо! Ты VIP: ×2 сыра и золотая корона!",
	thanks_double = "🧀 Спасибо! Теперь сыра в 2 раза больше!",
	thanks_cheese = "💎 +%d 🧀 Спасибо за поддержку!",
	not_configured = "Этот товар ещё не настроен 🙂",
	tab_hats = "🎩 Шапки",
	tab_robux = "💎 Магазин",
	vip_title = "👑 VIP",
	vip_desc = "×2 сыра • золотая корона • блеск",
	double_title = "🧀 ×2 Сыр",
	double_desc = "Вдвое больше сыра навсегда",
	pack_title = "🧀 %d сыра",
	pack_desc = "Сразу на счёт",
	owned = "Куплено ✓",
	vip_only = "👑 Только VIP",
	soon = "Скоро",
}

S.en = {
	alarm = "🚨 ALARM! The chef is FURIOUS and faster!",
	join_rats = "🐀 %s joined the rats!",
	chef_is = "👨‍🍳 %s is the chef! Rats, cause chaos!",
	chef_bot = "🤖 The robot chef is on duty! Rats, cause chaos!",
	chef_left = "The chef ran away! A robot took over 🤖",
	sabotaged = "💥 %s: «%s» — done!",
	repaired = "🔧 %s fixed: «%s»",
	busy = "Another rat is already working here!",
	caught = "🪤 %s is in the cage! Save them!",
	rescued = "🔓 %s opened the cage! Rats freed: %d",
	trapped = "🪤 %s got caught in a mousetrap!",
	trap_cooldown = "Mousetrap reloading: %d s",
	trap_placed = "🪤 Mousetrap placed!",
	no_cheese = "Not enough cheese 🧀 — play to earn more!",
	bought = "Bought: %s %s",
	bot_name = "Chef Bot 🤖",
	reason_chaos = "The restaurant is in total chaos!",
	reason_caught = "All rats are in the cage!",
	reason_norats = "No rats left",
	reason_time = "Time's up — the restaurant survived!",
	reward_Sabotage = "Sabotage",
	reward_Rescue = "Rescue",
	reward_Catch = "Caught a rat",
	reward_Repair = "Repair",
	reward_RatWin = "Victory",
	reward_ChefWin = "Victory",
	reward_Participation = "Played",
	waiting = "Waiting for players...",
	start_in = "Starting in %d",
	get_ready = "Get ready!",
	round_over = "Round over",
	chaos_bar = "Chaos: %d%%",
	alarm_bar = "🚨 ALARM! Chaos: %d%%",
	chaos_go = "CHAOS!",
	you_rat = "🐀 YOU ARE A RAT",
	goal_rat = "Break things (yellow outline), fill the chaos meter to 100% and don't get caught!",
	you_chef = "👨‍🍳 YOU ARE THE CHEF",
	goal_chef = "Catch rats with your net, place mousetraps and fix everything until time runs out!",
	role_caught = "🪤 You're in the cage!",
	hint_caught = "Squeak (Q) to call your friends!",
	role_stunned = "🪤 Mousetrap!",
	hint_stunned = "Wait a couple of seconds...",
	role_rat = "🐀 You're a rat",
	hint_rat = "E — sabotage • Shift — run • Q — squeak",
	role_chef = "👨‍🍳 You're the chef",
	hint_chef = "1 — net • 2 — mousetrap • E — repair",
	role_lobby = "🏠 Lobby",
	hint_lobby = "Pick a hat and wait for the round!",
	hunger = "🧀 Food",
	stamina = "🏃 Stamina",
	tasks_rat = "🐀 Sabotage:",
	tasks_chef = "🔧 Fix:",
	all_ok = "Everything is fine... for now 👀",
	tab_hide = "Tab — hide",
	shop_button = "🎩 Hats",
	shop_title = "🎩 Rat hats",
	chef_yes = "👨‍🍳 I want to be the chef: YES",
	chef_no = "👨‍🍳 I want to be the chef: NO",
	equipped = "Wearing ✓",
	equip = "Wear",
	buy = "Buy 🧀%d",
	locked = "🔒 🧀%d",
	victory = "🎉 VICTORY! 🎉",
	defeat = "😿 Defeat",
	rats_won = "🐀 The rats won!",
	chef_won = "👨‍🍳 The chef won!",
	mvp = "⭐ Best player: %s (%d)",
	round_coins = "+%d 🧀 this round",
	next_round = "Next round in %d s",
	squeak = "Squeak! 🐭",
	prompt_sabotage = "Sabotage",
	prompt_repair = "Repair",
	prompt_free = "Open cage",
	cage = "Cage",
	mg_wires = "🔌 Chew the wires!",
	mg_wires_hint = "Connect wires of the same color",
	mg_mash = "🦷 Gnaw faster!",
	mg_mash_hint = "Press the button, E or Space",
	mg_code = "🔢 Hack the password!",
	mg_code_hint = "Type the password from the sticky note",
	mg_timing = "⏱ Press on time!",
	mg_timing_hint = "Stop the bar on green (E / Space)",
	mg_done = "✔ Done!",
	mg_wrong = "❌ Nope!",
	mg_password = "Password:",
	mg_gnaw = "🦷 GNAW!",
	mg_stop = "⏱ STOP!",
	tool_net = "Net",
	tool_net_tip = "Click — catch a rat",
	tool_trap = "Mousetrap",
	tool_trap_tip = "Click — place a mousetrap",
	reward_Golden = "Golden cheese",
	golden_spawn = "✨ A GOLDEN CHEESE appeared! Who will find it first?",
	golden_found = "✨ %s found the golden cheese! +%d 🧀",
	daily = "🎁 Daily bonus: +%d 🧀 (day %d in a row)",
	thanks_vip = "👑 Thank you! You're VIP: ×2 cheese and a golden crown!",
	thanks_double = "🧀 Thank you! You now get double cheese!",
	thanks_cheese = "💎 +%d 🧀 Thanks for your support!",
	not_configured = "This item isn't set up yet 🙂",
	tab_hats = "🎩 Hats",
	tab_robux = "💎 Shop",
	vip_title = "👑 VIP",
	vip_desc = "×2 cheese • golden crown • sparkles",
	double_title = "🧀 ×2 Cheese",
	double_desc = "Double cheese forever",
	pack_title = "🧀 %d cheese",
	pack_desc = "Added instantly",
	owned = "Owned ✓",
	vip_only = "👑 VIP only",
	soon = "Soon",
}

local RU_LOCALES = { ru = true, uk = true, be = true, kk = true, uz = true, ky = true, hy = true, az = true, ka = true }

-- Язык игрока: "ru" или "en"
function Locale.detect(player)
	local chosen = player:GetAttribute("Lang")
	if chosen == "ru" or chosen == "en" then
		return chosen
	end
	local ok, id = pcall(function()
		return player.LocaleId
	end)
	if ok and type(id) == "string" and RU_LOCALES[string.lower(string.sub(id, 1, 2))] then
		return "ru"
	end
	return "en"
end

-- Перевести ключ. Аргументы-функции вызываются с языком (для имён заданий и т.п.)
function Locale.t(lang, key, ...)
	local text = (S[lang] and S[lang][key]) or S.en[key] or key
	local n = select("#", ...)
	if n == 0 then
		return text
	end
	local args = { ... }
	for i = 1, n do
		if type(args[i]) == "function" then
			args[i] = args[i](lang)
		end
	end
	return string.format(text, table.unpack(args, 1, n))
end

function Locale.forPlayer(player, key, ...)
	return Locale.t(Locale.detect(player), key, ...)
end

-- Название задания на нужном языке (атрибуты TaskName / TaskNameEn)
function Locale.taskName(lang, station)
	if lang == "en" then
		return station:GetAttribute("TaskNameEn") or station:GetAttribute("TaskName") or station.Name
	end
	return station:GetAttribute("TaskName") or station:GetAttribute("TaskNameEn") or station.Name
end

function Locale.hatName(lang, hat)
	if lang == "en" then
		return hat.NameEn or hat.Name
	end
	return hat.Name
end

return Locale
