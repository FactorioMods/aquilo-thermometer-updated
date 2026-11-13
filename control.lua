local migration_state = require("migration-state")
local mod_gui = require("mod-gui")
local util = require("util")

local SHOW_SETTING = "aquilo-thermometer-show-window"
local FRAME = "aq-thermometer-frame"
local TOGGLE = "aq-thermometer-toggle"
local CLOSE = "aq-thermometer-close"
local FUEL = "aq-thermometer-fuel"
local REFRESH = "aq-thermometer-refresh"

local function heating_tower_burner()
    local tower = prototypes.entity["heating-tower"]
    return tower and tower.burner_prototype
end

local function accepts_fuel(name, burner)
    local item = name and prototypes.item[name]
    if not (burner and item and item.fuel_value > 0) then return false end
    for _, category in pairs(item.fuel_categories or {}) do
        if burner.fuel_categories[category] then return true end
    end
    return false
end

local function default_fuel(burner)
    if accepts_fuel("rocket-fuel", burner) then return "rocket-fuel" end
    local names = {}
    for name in pairs(prototypes.item) do
        if accepts_fuel(name, burner) then names[#names + 1] = name end
    end
    table.sort(names)
    return names[1]
end

local function fuel_state(player, burner)
    storage.aq_thermometer_players = storage.aq_thermometer_players or {}
    local state = storage.aq_thermometer_players[player.index]
    if not state then
        state = {fuel = default_fuel(burner)}
        storage.aq_thermometer_players[player.index] = state
    elseif state.fuel and not accepts_fuel(state.fuel, burner) then
        state.fuel = default_fuel(burner)
    end
    return state
end

local function fuel_filters(burner)
    local categories = {}
    for category in pairs(burner and burner.fuel_categories or {}) do
        categories[#categories + 1] = category
    end
    table.sort(categories)
    local filters = {}
    for _, category in ipairs(categories) do
        filters[#filters + 1] = {filter = "fuel-category", ["fuel-category"] = category}
        filters[#filters + 1] = {filter = "fuel-value", comparison = ">", value = 0, mode = "and"}
    end
    return filters
end

local function format_rate(rate)
    if rate > 0 and rate < 0.1 then return string.format("%.3g", rate) end
    if rate >= 1000 then return util.format_number(rate, true) end
    return string.format("%.1f", rate)
end

local function calculate_heating_requirements(surface, force)
    local watts = 0
    for _, entity in pairs(surface.find_entities_filtered({force = force})) do
        watts = watts + entity.prototype.heating_energy * 60
    end
    return watts
end

local function show_window(player)
    return settings.get_player_settings(player)[SHOW_SETTING].value
end

local function update_player(player, refresh)
    local surface = player.surface
    local needs_heat = surface.planet and surface.planet.prototype.entities_require_heating
    local button_flow = mod_gui.get_button_flow(player)
    local button = button_flow[TOGGLE] or button_flow.add({
        type = "sprite-button", name = TOGGLE, style = mod_gui.button_style,
        sprite = "item/heating-tower", tooltip = {"aq.toggle-tooltip"}
    })
    button.visible = needs_heat == true
    button.toggled = show_window(player)

    local frame_flow = mod_gui.get_frame_flow(player)
    local frame = frame_flow[FRAME]
    if not needs_heat or not show_window(player) then
        if frame then frame.destroy() end
        return
    end
    if frame and not refresh and frame.tags.surface_index == surface.index
            and frame.tags.force_index == player.force.index then return end
    if frame then frame.destroy() end

    local watts = calculate_heating_requirements(surface, player.force)
    frame = frame_flow.add({type = "frame", name = FRAME, direction = "vertical"})
    frame.tags = {surface_index = surface.index, force_index = player.force.index, heating_watts = watts}
    frame.style.minimal_width = 320
    local header = frame.add({type = "flow", direction = "horizontal"})
    header.add({type = "label", style = "frame_title",
        caption = {"aq.frame-caption", surface.localised_name or surface.planet.prototype.localised_name}})
    header.add({type = "empty-widget"}).style.horizontally_stretchable = true
    header.add({type = "sprite-button", name = REFRESH, style = "frame_action_button",
        sprite = "utility/refresh", tooltip = {"aq.refresh-tooltip"}})
    header.add({type = "sprite-button", name = CLOSE, style = "frame_action_button",
        sprite = "utility/close", tooltip = {"aq.close-tooltip"}})
    frame.add({type = "label", name = "aq-thermometer-heating",
        caption = {"aq.heating-requirements", util.format_number(watts, true)}, tooltip = {"aq.snapshot-tooltip"}})

    local burner = heating_tower_burner()
    local state = fuel_state(player, burner)
    local fuel_row = frame.add({type = "flow", direction = "horizontal"})
    fuel_row.add({type = "label", caption = {"aq.fuel"}})
    local selector = fuel_row.add({type = "choose-elem-button", name = FUEL,
        elem_type = "item", elem_filters = fuel_filters(burner), tooltip = {"aq.fuel-tooltip"}})
    selector.elem_value = state.fuel
    selector.enabled = burner ~= nil
    local caption = {"aq.select-fuel"}
    if state.fuel and burner and burner.effectivity > 0 then
        local item = prototypes.item[state.fuel]
        local rate = watts / (item.fuel_value * burner.effectivity) * 60
        caption = {"aq.fuel-rate", "[item=" .. state.fuel .. "]", "[entity=heating-tower]", format_rate(rate)}
    elseif not burner or burner.effectivity <= 0 then
        caption = {"aq.no-heating-tower"}
    end
    frame.add({type = "label", name = "aq-thermometer-rate", caption = caption})
end

local function initialize()
    migration_state.adopt()
    for _, player in pairs(game.players) do
        -- Replace only thermometer-owned legacy frames, including renamed surfaces.
        for _, element in pairs(mod_gui.get_frame_flow(player).children) do
            if element.name:sub(1, 3) == "aq-" then
                local owner = element.get_mod()
                if owner == script.mod_name or owner == "aquilo-thermometer" then element.destroy() end
            end
        end
        update_player(player, true)
    end
end

script.on_event({defines.events.on_player_created, defines.events.on_player_joined_game,
    defines.events.on_player_changed_surface, defines.events.on_player_controller_changed,
    defines.events.on_player_changed_force}, function(event)
    local player = game.get_player(event.player_index)
    if player then update_player(player, event.name == defines.events.on_player_joined_game) end
end)

script.on_event(defines.events.on_gui_click, function(event)
    local element = event.element
    if not (element and element.valid) then return end
    if element.name ~= TOGGLE and element.name ~= CLOSE and element.name ~= REFRESH then return end
    if element.get_mod() ~= script.mod_name then return end
    local player = game.get_player(event.player_index)
    if not player then return end
    if element.name == REFRESH then
        update_player(player, true)
        return
    end
    local visible = element.name == TOGGLE and not show_window(player)
    settings.get_player_settings(player)[SHOW_SETTING] = {value = visible}
    update_player(player, false)
end)

script.on_event(defines.events.on_gui_elem_changed, function(event)
    local element = event.element
    if not (element and element.valid and element.name == FUEL) then return end
    if element.get_mod() ~= script.mod_name then return end
    local player = game.get_player(event.player_index)
    if not player then return end
    local burner = heating_tower_burner()
    local state = fuel_state(player, burner)
    if not element.elem_value or accepts_fuel(element.elem_value, burner) then
        state.fuel = element.elem_value
    end
    update_player(player, true)
end)

script.on_event(defines.events.on_player_removed, function(event)
    if storage.aq_thermometer_players then storage.aq_thermometer_players[event.player_index] = nil end
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
    if event.setting ~= SHOW_SETTING or not event.player_index then return end
    local player = game.get_player(event.player_index)
    if player then update_player(player, false) end
end)

script.on_init(initialize)
script.on_configuration_changed(initialize)
