-- inventory_sort_fixed
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
    local inv = player:get_inventory()
    inv:set_size("priority", 8)
end)

-- ====== СОРТУВАННЯ З ФІКСОВАНИМИ СЛОТАМИ ======
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

    -- 🔹 функція: взяти частину предмета
    local function take_from_items(name, need_count)
        local taken = 0

        for i = #items, 1, -1 do
            local stack = items[i]

            if stack.name == name then
                local can_take = math.min(stack.count, need_count - taken)

                stack.count = stack.count - can_take
                taken = taken + can_take

                if stack.count <= 0 then
                    table.remove(items, i)
                end

                if taken >= need_count then
                    break
                end
            end
        end

        return taken
    end

    -- 🔹 новий список
    local new_list = {}

    -- ====== 1. FIXED СЛОТИ ЗІ СТАКОМ ======
    for i = 1, 8 do
        local p = priority[i]

        if p and not p:is_empty() then
            local name = p:get_name()
            local max_stack = ItemStack(name):get_stack_max()

            local count = take_from_items(name, max_stack)

            if count > 0 then
                table.insert(new_list, ItemStack({
                    name = name,
                    count = count
                }))
            else
                table.insert(new_list, ItemStack(""))
            end
        else
            table.insert(new_list, ItemStack(""))
        end
    end

    -- ====== 2. РОЗПАКОВКА ЗАЛИШКУ ======
    local remaining = {}

    for _, stack in ipairs(items) do
        table.insert(remaining, ItemStack(stack))
    end

    -- ====== 3. СОРТУВАННЯ ======
    table.sort(remaining, function(a, b)
        if sort_ascending then
            return a:get_name() < b:get_name()
        else
            return a:get_name() > b:get_name()
        end
    end)

    -- ====== 4. ДОДАЄМО В КІНЕЦЬ ======
    for _, stack in ipairs(remaining) do
        table.insert(new_list, stack)
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
                return true, "Відкрито інвентар сортування"
            end
            return false, "Гравець не знайдений"
        end
    })
end

-- ====== ОБРОБКА КНОПКИ ======
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "inv_sort:main" then return end

    if fields.sort then
        inv_sort.sort(player)
        inv_sort.open(player)
    end
end)
