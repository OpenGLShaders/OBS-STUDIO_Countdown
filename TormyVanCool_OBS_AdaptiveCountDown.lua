obs           = obslua
source_name   = ""
total_seconds = 0

cur_seconds   = 0
last_text     = ""
stop_text     = ""
timer_format  = ""
next_scene	  = ""
start_recording = ""
activated     = false

hotkey_id     = obs.OBS_INVALID_HOTKEY_ID

-- Function to set the time text
function set_time_text()
	local text = ''
	local seconds       = math.floor(cur_seconds % 60)
	local total_minutes = math.floor(cur_seconds / 60)
	local minutes       = math.floor(total_minutes % 60)
	local total_hours   = math.floor(total_minutes / 60)
	local hours	    = math.floor(total_hours % 24)
	local days	    = math.floor(total_hours / 24)

	if timer_format == "ss" then
		text = string.format("%02d", seconds)
	end

	if timer_format == "mm : ss" then
		text = string.format("%02d:%02d", minutes, seconds)
	end

	if timer_format == "hh : mm : ss" then
		text = string.format("%02d:%02d:%02d", hours, minutes, seconds)
	end

	if timer_format == "dd : hh : mm : ss" then
		text = string.format("%01d:%02d:%02d:%02d", days, hours, minutes, seconds)
	end

	-- local text = string.format("%01d:%02d:%02d:%02d", days, hours, minutes, seconds)
	
	text = start_text  .. text

	if cur_seconds < 1 then
		if next_scene ~= "" and next_scene ~= "Use: FINAL TEXT" then
			if start_recording == "Yes" then
					obs.obs_frontend_recording_start()
			end
			local source = obs.obs_get_source_by_name(next_scene)
			obs.obs_source_release(source)
			obs.obs_frontend_set_current_scene(source)
		else
			text = stop_text	
			if start_recording == "Yes" then
					obs.obs_frontend_recording_start()
			end
		end
	end

	if text ~= last_text then
		local source = obs.obs_get_source_by_name(source_name)
		if source ~= nil then
			local settings = obs.obs_data_create()
			obs.obs_data_set_string(settings, "text", text)
			obs.obs_source_update(source, settings)
			obs.obs_data_release(settings)
			obs.obs_source_release(source)
		end
	end
	last_text = text
end

function timer_callback()
	cur_seconds = cur_seconds - 1
	if cur_seconds < 0 then
		obs.remove_current_callback()
		cur_seconds = 0
	end

	set_time_text()
end

function activate(activating)
	if activated == activating then
		return
	end

	activated = activating

	if activating then
		cur_seconds = total_seconds
		set_time_text()
		obs.timer_add(timer_callback, 1000)
	else
		obs.timer_remove(timer_callback)
	end
end

-- Called when a source is activated/deactivated
function activate_signal(cd, activating)
	local source = obs.calldata_source(cd, "source")
	if source ~= nil then
		local name = obs.obs_source_get_name(source)
		if (name == source_name) then
			activate(activating)
		end
	end
end

function source_activated(cd)
	activate_signal(cd, true)
end

function source_deactivated(cd)
	activate_signal(cd, false)
end

function reset(pressed)
	if not pressed then
		return
	end

	activate(false)
	local source = obs.obs_get_source_by_name(source_name)
	if source ~= nil then
		local active = obs.obs_source_active(source)
		obs.obs_source_release(source)
		activate(active)
	end
end

function reset_button_clicked(props, p)
	reset(true)
	return false
end

----------------------------------------------------------

-- A function named script_properties defines the properties that the user
-- can change for the entire script module itself
function script_properties()
	local props = obs.obs_properties_create()
	local p = obs.obs_properties_add_list(props, "source", "Timer Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local sources = obs.obs_enum_sources()
	if sources ~= nil then
		for _, source in ipairs(sources) do
			source_id = obs.obs_source_get_unversioned_id(source)
			if source_id == "text_gdiplus" or source_id == "text_ft2_source" then
				local name = obs.obs_source_get_name(source)
				obs.obs_property_list_add_string(p, name, name)
			end
		end
	end
	obs.source_list_release(sources)


	
	local f = obs.obs_properties_add_list(props, "timer_format", "Format", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	obs.obs_property_list_add_string(f, "ss", "ss")
	obs.obs_property_list_add_string(f, "mm : ss", "mm : ss")
	obs.obs_property_list_add_string(f, "hh : mm : ss", "hh : mm : ss")
	obs.obs_property_list_add_string(f, "dd : hh : mm : ss", "dd : hh : mm : ss")

	obs.obs_properties_add_text(props, "start_text", "Start Text", obs.OBS_TEXT_DEFAULT)
	obs.obs_properties_add_text(props, "stop_text", "Final Text or leave blank", obs.OBS_TEXT_DEFAULT)

    local r = obs.obs_properties_add_list(props, "start_recording", "Start Recording: Yes/No", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	obs.obs_property_list_add_string(r, "Yes", "yes")
	obs.obs_property_list_add_string(r, "No", "no")

	local t = obs.obs_properties_add_list(props, "next_scene", "Next Scene -or-", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	obs.obs_property_list_add_string(t, "Use: FINAL TEXT", "Use: FINAL TEXT")
	local scenes = obs.obs_frontend_get_scene_names()
	if scenes ~= nil then
		for _, scene in ipairs(scenes) do
			obs.obs_property_list_add_string(t, scene, scene)
		end
		obs.bfree(scene)
	end

	obs.obs_properties_add_int(props, "days", "Days", 0, 366, 1)
	obs.obs_properties_add_int(props, "hours", "Hours", 0, 23, 1)
	obs.obs_properties_add_int(props, "minutes", "Minutes", 0, 59, 1)
	obs.obs_properties_add_int(props, "seconds", "Seconds", 0, 59, 1)
	obs.obs_properties_add_button(props, "reset_button", "Reset Timer", reset_button_clicked)

	return props
end

-- A function named script_description returns the description shown to
-- the user
function script_description()
	return "COUNTDOWN ADAPTIVE v2.1\n\nSelect the format you prefer\n\nTimer Source counts down to 00:00 and displays:\n> Text Format\n> Start Text\n> Final Text\n> Starts Recording\n> Switches to a scene\n> Setup Days, Hours, Minutes and Seconds"
end

-- A function named script_update will be called when settings are changed
function script_update(settings)
	activate(false)

	total_seconds = (obs.obs_data_get_int(settings, "days")*24*60*60) + (obs.obs_data_get_int(settings, "hours")*60*60) + (obs.obs_data_get_int(settings, "minutes")*60) + obs.obs_data_get_int(settings, "seconds")
	source_name = obs.obs_data_get_string(settings, "source")
	start_text = obs.obs_data_get_string(settings, "start_text")
	stop_text = obs.obs_data_get_string(settings, "stop_text")
	next_scene = obs.obs_data_get_string(settings, "next_scene")
	start_recording = obs.obs_data_get_string(settings, "start_recording")
	timer_format = obs.obs_data_get_string(settings, "timer_format")

	reset(true)
end

-- A function named script_defaults will be called to set the default settings
function script_defaults(settings)
	obs.obs_data_set_default_int(settings, "days", 0)
	obs.obs_data_set_default_int(settings, "hours", 0)
	obs.obs_data_set_default_int(settings, "minutes", 0)
	obs.obs_data_set_default_int(settings, "seconds", 0)
	obs.obs_data_set_default_string(settings, "start_text", "Live in: ")
	obs.obs_data_set_default_string(settings, "stop_text", "LIVE NOW!")
	obs.obs_data_set_default_string(settings, "next_scene", "Use: FINAL TEXT")
	obs.obs_data_set_default_string(settings, "start_recording", "No")
	obs.obs_data_set_default_string(settings, "timer_format", "mm : ss")
end

-- A function named script_save will be called when the script is saved
--
-- NOTE: This function is usually used for saving extra data (such as in this
-- case, a hotkey's save data).  Settings set via the properties are saved
-- automatically.
function script_save(settings)
	local hotkey_save_array = obs.obs_hotkey_save(hotkey_id)
	obs.obs_data_set_array(settings, "reset_hotkey", hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)
end

-- a function named script_load will be called on startup
function script_load(settings)
	-- Connect hotkey and activation/deactivation signal callbacks
	--
	-- NOTE: These particular script callbacks do not necessarily have to
	-- be disconnected, as callbacks will automatically destroy themselves
	-- if the script is unloaded.  So there's no real need to manually
	-- disconnect callbacks that are intended to last until the script is
	-- unloaded.
	local sh = obs.obs_get_signal_handler()
	obs.signal_handler_connect(sh, "source_activate", source_activated)
	obs.signal_handler_connect(sh, "source_deactivate", source_deactivated)

	hotkey_id = obs.obs_hotkey_register_frontend("reset_timer_thingy", "Reset Timer", reset)
	local hotkey_save_array = obs.obs_data_get_array(settings, "reset_hotkey")
	obs.obs_hotkey_load(hotkey_id, hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)
end