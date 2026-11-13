local migration_state = require("migration-state")
local mod_gui = require("mod-gui")
local util = require("util")

local SHOW_SETTING = "aquilo-thermometer-show-window"
local FRAME = "aq-thermometer-frame"
local TOGGLE = "aq-thermometer-toggle"
local CLOSE = "aq-thermometer-close"

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
    frame.tags = {surface_index = surface.index, force_index = player.force.index}
    frame.style.minimal_width = 320
    local header = frame.add({type = "flow", direction = "horizontal"})
    header.add({type = "label", style = "frame_title",
        caption = {"aq.frame-caption", surface.localised_name or surface.planet.prototype.localised_name}})
    header.add({type = "empty-widget"}).style.horizontally_stretchable = true
    header.add({type = "sprite-button", name = CLOSE, style = "frame_action_button",
        sprite = "utility/close", tooltip = {"aq.close-tooltip"}})
    frame.add({type = "label", name = "aq-thermometer-heating",
        caption = {"aq.heating-requirements", util.format_number(watts, true)}})

    local fuel = prototypes.item["rocket-fuel"]
    local tower = prototypes.entity["heating-tower"]
    if fuel and tower and tower.burner_prototype then
        local rate = watts / (fuel.fuel_value * tower.burner_prototype.effectivity) * 60
        frame.add({type = "label", name = "aq-thermometer-rate",
            caption = {"aq.rocket-fuel-rate", "[item=rocket-fuel]", "[entity=heating-tower]", string.format("%.1f", rate)}})
    end
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
    if element.name ~= TOGGLE and element.name ~= CLOSE then return end
    if element.get_mod() ~= script.mod_name then return end
    local player = game.get_player(event.player_index)
    if not player then return end
    local visible = element.name == TOGGLE and not show_window(player)
    settings.get_player_settings(player)[SHOW_SETTING] = {value = visible}
    update_player(player, false)
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
    if event.setting ~= SHOW_SETTING or not event.player_index then return end
    local player = game.get_player(event.player_index)
    if player then update_player(player, false) end
end)

script.on_init(initialize)
script.on_configuration_changed(initialize)
