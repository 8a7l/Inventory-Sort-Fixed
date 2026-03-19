-- inventory_sort_fixed_safe
-- Автор: Василь Онуфрійчук
-- Ліцензія: GNU GPL v3

local inv_sort = {}

-- ====== Налаштування ======
inv_sort.config = {
    width = 12,
    height = 10,

    priority = { x = 1, y = 2.5, w = 8, h = 1 },
    main = { x = 1, y = 4.5, w = 8, h = 4 },

    buttons = {
        sort = { x = 1, y = 1, w = 1, h = 1, img = "ui_sort_inv.png" },
    },

    commands = { "sort" },
}

local sort_ascending = true

-- ====== Ініціалізація ======
minetest.register_on_joinplayer(function(player)
    player:get_inventory():set_size("priority", 8)
end)

-- ====== СОРТУВАННЯ (БЕЗПЕЧНЕ) ======
function inv_sort.sort(player)
    local inv = player:get_inventory()
    local main = inv:get_list("main")
    local priority = inv:get_list("priority")

    if not main then return end

    -- 🔹 копія предметів
    local items = {}
    for _, stack in ipairs(main) do
        if not stack:is_empty() then
            table.insert(items, stack:to_table())
        end
    end

    -- 🔹 взяти предмет
    local function take(name, need)
        local taken = 0

        for i = #items, 1, -1 do
            local s = items[i]

            if s.name == name then
                local can = math.min(s.count, need - taken)

                s.count = s.count - can
                taken = taken + can

                if s.count <= 0 then
                    table.remove(items, i)
                end

                if taken >= need then break end
            end
        end

        return taken
    end

    -- 🔹 формуємо новий список (але ще НЕ застосовуємо)
    local new_list = {}

    -- ====== FIXED ======
    for i = 1, 8 do
        local p = priority[i]

        if p and not p:is_empty() then
            local name = p:get_name()
            local max = ItemStack(name):get_stack_max()

            local count = take(name, max)

            if count > 0 then
                table.insert(new_list, ItemStack({name=name, count=count}))
            else
                table.insert(new_list, ItemStack(""))
            end
        else
            table.insert(new_list, ItemStack(""))
        end
    end

    -- ====== ЗАЛИШОК ======
    local remaining = {}

    for _, s in ipairs(items) do
        table.insert(remaining, ItemStack(s))
    end

    table.sort(remaining, function(a, b)
        if sort_ascending then
            return a:get_name() < b:get_name()
        else
            return a:get_name() > b:get_name()
        end
    end)

    for _, s in ipairs(remaining) do
        table.insert(new_list, s)
    end

    -- 🔥 ====== КРИТИЧНА ПЕРЕВІРКА ======
    local total_slots = #main
    if #new_list > total_slots then
        minetest.chat_send_player(player:get_player_name(),
            "❌ Недостатньо місця для сортування!")
        return
    end

    -- 🔹 ДОЗАПОВНЕННЯ ПУСТИМИ
    while #new_list < total_slots do
        table.insert(new_list, ItemStack(""))
    end

    -- 🔹 застосування
    inv:set_list("main", new_list)

    sort_ascending = not sort_ascending
end

-- ====== UI ======
function inv_sort.get_formspec(player)
    local c = inv_sort.config

    return string.format(
        "formspec_version[4]" ..
        "size[%f,%f]" ..

        "list[current_player;priority;%f,%f;%d,%d;]" ..
        "list[current_player;main;%f,%f;%d,%d;]" ..

        "image_button[%f,%f;%f,%f;%s;sort;]" ..

        "listring[current_player;main]" ..
        "listring[current_player;priority]",

        c.width, c.height,

        c.priority.x, c.priority.y, c.priority.w, c.priority.h,
        c.main.x, c.main.y, c.main.w, c.main.h,

        c.buttons.sort.x,
        c.buttons.sort.y,
        c.buttons.sort.w,
        c.buttons.sort.h,
        c.buttons.sort.img
    )
end

-- ====== ВІДКРИТТЯ ======
function inv_sort.open(player)
    minetest.show_formspec(
        player:get_player_name(),
        "inv_sort:main",
        inv_sort.get_formspec(player)
    )
end

-- ====== КОМАНДА ======
for _, cmd in ipairs(inv_sort.config.commands) do
    minetest.register_chatcommand(cmd, {
        description = "Відкрити інвентар сортування",
        func = function(name)
            local player = minetest.get_player_by_name(name)
            if player then
                inv_sort.open(player)
                return true, "Відкрито"
            end
            return false, "Гравець не знайдений"
        end
    })
end

-- ====== КНОПКА ======
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "inv_sort:main" then return end

    if fields.sort then
        inv_sort.sort(player)
        inv_sort.open(player)
    end
end)
