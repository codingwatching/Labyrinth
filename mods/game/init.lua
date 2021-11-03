-- ██╗      █████╗ ██████╗ ██╗   ██╗██████╗ ██╗███╗   ██╗████████╗██╗  ██╗
-- ██║     ██╔══██╗██╔══██╗╚██╗ ██╔╝██╔══██╗██║████╗  ██║╚══██╔══╝██║  ██║
-- ██║     ███████║██████╔╝ ╚████╔╝ ██████╔╝██║██╔██╗ ██║   ██║   ███████║
-- ██║     ██╔══██║██╔══██╗  ╚██╔╝  ██╔══██╗██║██║╚██╗██║   ██║   ██╔══██║
-- ███████╗██║  ██║██████╔╝   ██║   ██║  ██║██║██║ ╚████║   ██║   ██║  ██║
-- ╚══════╝╚═╝  ╚═╝╚═════╝    ╚═╝   ╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝   ╚═╝   ╚═╝  ╚═╝
-- Ascii art font: ANSI Shadow, from patorjk.com/software/taag/
--
-- The code for labyrinth is licensed as follows:
-- MIT License, ExeVirus (c) 2021
--
-- Please see the LICENSE file for texture licenses


--Settings Changes --
--BE VERY CAREFUL WHEN PLAYING WITH OTHER PEOPLES SETTINGS--
minetest.settings:set("enable_damage","false")
local max_block_send_distance = minetest.settings:get("max_block_send_distance")
local block_send_optimize_distance = minetest.settings:get("block_send_optimize_distance")
if max_block_send_distance == 31 then -- no one would set these to 31, so it must have been a crash,
    max_block_send_distance = 8       -- and we should revert to defaults on proper shutdown
end
if block_send_optimize_distance == 31 then
    block_send_optimize_distance = 4
end
minetest.settings:set("max_block_send_distance","30")
minetest.settings:set("block_send_optimize_distance","30")
minetest.register_on_shutdown(function()
    minetest.settings:set("max_block_send_distance",tostring(max_block_send_distance))
    minetest.settings:set("block_send_optimize_distance",tostring(block_send_optimize_distance))
end)
--End Settings Changes--

local DefaultGenerateMaze = dofile(minetest.get_modpath("game") .. "/maze.lua")
local GenMaze = DefaultGenerateMaze

--Style registrations

local numStyles = 0
local styles = {}
local music = nil

-------------------
-- Global function laby_register_style(name, music_name, map_from_maze, cleanup, genMaze)
--
-- name: text in lowercase, typically, of the map style
-- music_name: music file name
-- map_from_maze = function(maze, player)
--   maze is from GenMaze() above, an input
--   player is the player_ref to place them at the start of the maze
-- cleanup = function (maze_w, maze_h) -- should replace maze with air
-- genMaze is an optional arguement to provide your own algorithm for this style to generate maps with
--
function laby_register_style(name, music_name, map_from_maze, cleanup, genMaze)
    numStyles = numStyles + 1
    styles[numStyles] = {}
    styles[numStyles].name = name
    styles[numStyles].music = music_name
    styles[numStyles].gen_map = map_from_maze
    styles[numStyles].cleanup = cleanup
    styles[numStyles].genMaze = genMaze
end

--Common node between styles, used for hidden floor to fall onto
minetest.register_node("game:inv",
{
  description = "Ground Block",
  drawtype = "airlike",
  tiles = {"inv.png"},
  light_source = 11,
})

--Override the default hand
minetest.register_item(":", {
	type = "none",
	wield_image = "inv.png",
	groups = {not_in_creative_inventory=1},
})

--Style Registrations
dofile(minetest.get_modpath("game") .. "/styles/classic.lua")
dofile(minetest.get_modpath("game") .. "/styles/grassy.lua")
dofile(minetest.get_modpath("game") .. "/styles/glass.lua")
dofile(minetest.get_modpath("game") .. "/styles/cave.lua")
dofile(minetest.get_modpath("game") .. "/styles/club.lua")

local restart = styles[1].gen_map
local cleanup = styles[1].cleanup
local gwidth = 61
local gheight = 61
local gscroll = 0
local selectedStyle = 1
local first_load = false
local function setup(player)
    if styles[selectedStyle].genMaze ~= nil and type(styles[selectedStyle].genMaze) == "function" then
        GenMaze = styles[selectedStyle].genMaze
    else
        GenMaze = DefaultGenerateMaze
    end
    --Load up the level
    local maze = GenMaze(math.floor(gwidth/2)*2+((gwidth+1)%2),math.floor(gheight/2)*2+(gheight+1)%2)
    restart = styles[selectedStyle].gen_map
    cleanup = styles[selectedStyle].cleanup
    restart(maze, player)
    if music then
        minetest.sound_fade(music, 0.5, 0)
    end
    music = minetest.sound_play(styles[selectedStyle].music, {
        gain = 1.0,   -- default
        fade = 0.5,   -- default, change to a value > 0 to fade the sound in
        loop = true,
    })
    minetest.after(2, function() first_load = true end)
end

--------- GUI ------------

--Main_Menu formspec for Labyrinth
local function main_menu(width_in, height_in, scroll_in)
local width  = width_in or 57
local height  = height_in or 42
local scroll = scroll_in or 0
--Header
local r = {
[[
formspec_version[3]
size[11,11]
position[0.5,0.5]
anchor[0.5,0.5]
no_prepend[]
bgcolor[#DFE0EDD0;both;#00000080]
box[0.5,1;10,9.5;#DDD7]
hypertext[1,0.1;9,5;;<global halign=center color=#03A size=32 font=Regular>
Labyrinth<global halign=left color=#000 size=24 font=Regular>

Level style:]
button[7.5,0.15;3.3,0.7;labyexit;Quit Labyrinth]
scroll_container[0.5,2;10,2;scroll;horizontal;0.1]
]],
}
--for each set, output the icon and set_name as a button
for i=1, numStyles, 1 do
    if selectedStyle == i then
        table.insert(r,"box["..((i-1)*2+0.1)..",0.0;1.8,1.8;#0B35]")
    end
    local name = styles[i].name
    table.insert(r,"image_button["..((i-1)*2+0.25)..",0.15;1.5,1.5;"..name..".png;style"..i..";"..name.."]")
end
table.insert(r,"scroll_container_end[]")
table.insert(r,"scrollbaroptions[max="..(numStyles*10)..";thumbsize="..(numStyles*10).."]")
table.insert(r,"scrollbar[1,4;9,0.5;horizontal;scroll;"..scroll.."]")
table.insert(r,
[[button_exit[1.25,5.5;4,1;easy;Easy (40x40)]
button_exit[5.75,5.5;4,1;medium;Medium (70x70)]
button_exit[1.25,7;4,1;hard;Hard (120x120)]
]])
table.insert(r,"field[5.75,6.9;4,0.5;custom_w;"..minetest.colorize("#000","Width")..";"..width.."]")
table.insert(r,"field[5.75,7.9;4,0.5;custom_h;"..minetest.colorize("#000","Height")..";"..height.."]")
table.insert(r,
[[field_close_on_enter[custom_w;false]
field_close_on_enter[custom_h;false]
button_exit[5.75,8.5;4,1;custom;Custom]
]])
return table.concat(r);
end

local function pause_menu() return 
[[formspec_version[3]
size[8,8]
position[0.5,0.5]
anchor[0.5,0.5]
no_prepend[]
bgcolor[#DFE0EDD0;both;#00000080]
button_exit[0.6,0.5;6.8,1;game_menu;Quit to Game Menu]
button_exit[0.6,2;6.8,1;restart;Restart with new Map]
hypertext[2,3.5;4,4.25;;<global halign=center color=#03A size=32 font=Regular>Credits<global halign=center color=#000 size=16 font=Regular>
Original Game by ExeVirus
Source code is MIT License, 2021
Media/Music is:\nCC-BY-SA, ExeVirus 2021
Music coming soon to Spotify and other streaming services!]
]]
end

local function to_game_menu(player)
    first_load = false
    minetest.show_formspec(player:get_player_name(), "game:main", main_menu())
    cleanup(gwidth, gheight)
    if music then
        minetest.sound_fade(music, 0.5, 0)
    end
    music = minetest.sound_play("main", {
        gain = 1.0,   -- default
        fade = 0.8,   -- default, change to a value > 0 to fade the sound in
        loop = true,
    })
end

----------------------------------------------------------
--
-- onRecieveFields(player, formname, fields)
--
-- player: player object 
-- formname: use provided form name
-- fields: standard recieve fields
-- Callback for on_recieve fields
----------------------------------------------------------
local function onRecieveFields(player, formname, fields)
    if formname ~= "game:main" and formname ~= "" then return end
    if formname == "" then --process the inventory formspec
        if fields.game_menu then
            minetest.after(0.15, function() to_game_menu(player) end)
        elseif fields.restart then
            cleanup(gwidth, gheight)
            local maze = GenMaze(math.floor(gwidth/2)*2+((gwidth+1)%2),math.floor(gheight/2)*2+(gheight+1)%2)
            restart(maze, player)
        end
        return
    end
    
    local scroll_in = 0
    local width_in = 39
    local height_in = 74
    if fields.scroll then
        scroll_in = tonumber(fields.scroll)
    end
    if fields.custom_h then
        height_in = tonumber(fields.custom_h)
    end
    if fields.custom_w then
        width_in = tonumber(fields.custom_w)
    end

    --Loop through all fields
    for name,_ in pairs(fields) do
        if string.sub(name,1,5) == "style" then
            selectedStyle = tonumber(string.sub(name,6,-1))
            --load level style
        end
    end
    if fields.easy then
        gheight = 41
        gwidth = 41
        setup(player)
    elseif fields.medium then
        gheight = 71
        gwidth = 71
        setup(player)
    elseif fields.hard then
        gheight = 121
        gwidth = 121
        setup(player)
    --If after all that, nothing is set, they used escape to quit.
    elseif fields.custom then
        if tonumber(fields.custom_w) then
            local var = math.max(math.min(tonumber(fields.custom_w), 125),5)
            gwidth = var

        end
        if tonumber(fields.custom_h) then
            local var = math.max(math.min(tonumber(fields.custom_h), 125),5)
            gheight  = var
        end
        setup(player)
    elseif fields.quit then
        minetest.after(0.10, function() minetest.show_formspec(player:get_player_name(), "game:main", main_menu(width_in, height_in, scroll_in)) end)
        return
    elseif fields.labyexit then
        minetest.request_shutdown("Thanks for playing!")
        return
    else
        minetest.show_formspec(player:get_player_name(), "game:main", main_menu(width_in, height_in, scroll_in))
    end
end

minetest.register_on_player_receive_fields(onRecieveFields)

local function safe_clear(w, l)
    local vm         = minetest.get_voxel_manip()
    local emin, emax = vm:read_from_map({x=-10,y=-11,z=-10}, {x=w,y=10,z=l})
    local data = vm:get_data()
    local a = VoxelArea:new{
        MinEdge = emin,
        MaxEdge = emax
    }
    local invisible = minetest.get_content_id("game:inv")
    local air = minetest.get_content_id("air")
    
    for z=0, l-10 do --z
        for y=0,10 do --y
            for x=0, w-10 do --x
                data[a:index(x, y, z)] = air
            end
        end
    end

    for z=-10, l do --z
        for x=-10, w do --x
            data[a:index(x, -11, z)] = invisible
        end
    end
    vm:set_data(data)
    vm:write_to_map(true)
end

minetest.register_on_joinplayer(
function(player)
    safe_clear(300,300)
    player:set_properties({
			textures = {"inv.png", "inv.png"},
			visual = "upright_sprite",
			collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.75, 0.3},
			stepheight = 0.6,
			eye_height = 1.625,
		})
    player:hud_set_flags(
        {
            hotbar = false,
            healthbar = false,
            crosshair = false,
            wielditem = false,
            breathbar = false,
            minimap = false,
            minimap_radar = false,
        }
    )
    player:set_inventory_formspec(pause_menu())
    minetest.show_formspec(player:get_player_name(), "game:main", main_menu())
    music = minetest.sound_play("main", {
        gain = 1.0,   -- default
        fade = 0.8,   -- default, change to a value > 0 to fade the sound in
        loop = true,
    })
end
)

minetest.register_globalstep(
function(dtime)
    local player = minetest.get_player_by_name("singleplayer")
    if player and first_load then
        local pos = player:get_pos()
        if pos.y < -10 then
            minetest.sound_play("win")
            to_game_menu(player)
        end
    end
end
)
