local git = require('gitblame.git')
local utils = require('gitblame.utils')
local start_job = utils.start_job
local timeago = require('lua-timeago')

---@type integer
local NAMESPACE_ID = vim.api.nvim_create_namespace('git-blame-virtual-text')

---@type table<string, string>
local last_position = {}

---@type table<string, table>
local files_data = {}

---@type string
local current_author

---@type boolean
local need_update_after_horizontal_move = false

---@type string
local date_format = vim.g.gitblame_date_format

---@type boolean
local date_format_has_relative_time

---@type boolean
local is_blame_info_available = false

---@type boolean
local print_virtual_text = true

local current_blame_text = nil

local function clear_virtual_text()
    vim.api.nvim_buf_del_extmark(0, NAMESPACE_ID, 1)
end

local function is_blame_available()
    return is_blame_info_available
end

---@param blames table[]
---@param filepath string
---@param lines string[]
local function process_blame_output(blames, filepath, lines)
    if not files_data[filepath] then files_data[filepath] = {} end
    local info
    for _, line in ipairs(lines) do
        local message = line:match('^([A-Za-z0-9]+) ([0-9]+) ([0-9]+) ([0-9]+)')
        if message then
            local parts = {}
            for part in line:gmatch("%w+") do
                table.insert(parts, part)
            end

            local startline = tonumber(parts[3])
            info = {
                startline = startline,
                sha = parts[1],
                endline = startline + tonumber(parts[4]) - 1
            }

            if parts[1]:match('^0+$') == nil then
                for _, found_info in ipairs(blames) do
                    if found_info.sha == parts[1] then
                        info.author = found_info.author
                        info.committer = found_info.committer
                        info.date = found_info.date
                        info.committer_date = found_info.committer_date
                        info.summary = found_info.summary
                        break
                    end
                end
            end

            table.insert(blames, info)
        elseif info then
            if line:match('^author ') then
                local author = line:gsub('^author ', '')
                info.author = author
            elseif line:match('^author%-time ') then
                local text = line:gsub('^author%-time ', '')
                info.date = text
            elseif line:match('^committer ') then
                local committer = line:gsub('^committer ', '')
                info.committer = committer
            elseif line:match('^committer%-time ') then
                local text = line:gsub('^committer%-time ', '')
                info.committer_date = text
            elseif line:match('^summary ') then
                local text = line:gsub('^summary ', '')
                info.summary = text
            end
        end
    end

    if not files_data[filepath] then files_data[filepath] = {} end
    files_data[filepath].blames = blames
end

---@param callback fun()
local function load_blames(callback)
    local blames = {}

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    if #lines == 0 then return end

    local filepath = vim.api.nvim_buf_get_name(0)
    if filepath == "" then return end

    git.get_repo_root(function(git_root)
        local command = 'git --no-pager -C ' .. git_root ..
                            ' blame -b -p --date relative --contents - ' ..
                            filepath

        start_job(command, {
            input = table.concat(lines, '\n') .. '\n',
            on_stdout = function(data)
                process_blame_output(blames, filepath, data)
                if callback then callback() end
            end
        })
    end)
end

---@param date osdate
---@return string
local function format_date(date)
    local format = date_format
    if date_format_has_relative_time then
        format = format:gsub("%%r", timeago.format(date))
    end

    return os.date(format, date)
end

---@param filepath string
---@param line_number number
local function get_blame_info(filepath, line_number)
    local info
    for _, v in ipairs(files_data[filepath].blames) do
        if line_number >= v.startline and line_number <= v.endline then
            info = v
            break
        end
    end
    return info
end

local function print_blame_text(line_number)
    clear_virtual_text()

    if current_blame_text then
        local options = {id = 1, virt_text = {{blame_text, 'gitblame'}}}
        local user_options = vim.g.gitblame_set_extmark_options or {}
        if type(user_options) == 'table' then
            utils.merge_map(user_options, options)
        elseif user_options then
            utils.log('gitblame_set_extmark_options should be a table')
        end

        vim.api.nvim_buf_set_extmark(0, NAMESPACE_ID, line_number - 1, 0, options)
    end
end

---@param blame_info table
local function get_blame_text(filepath, blame_info)
    local info = blame_info
    is_blame_info_available = info 
        and info.author 
        and info.date 
        and info.committer 
        and info.committer_date
        and info.author ~= 'Not Committed Yet'

    local not_commited_blame_text = '  Not Committed Yet'
    if is_blame_info_available then
        local blame_text = vim.g.gitblame_message_template
        blame_text = blame_text:gsub('<author>',
                                     info.author == current_author and 'You' or
                                         info.author)
        blame_text = blame_text:gsub('<committer>', info.committer ==
                                         current_author and 'You' or
                                         info.committer)
        blame_text = blame_text:gsub('<committer%-date>',
                                     format_date(info.committer_date))
        blame_text = blame_text:gsub('<date>', format_date(info.date))
        blame_text = blame_text:gsub('<summary>', info.summary)
        blame_text = blame_text:gsub('<sha>', string.sub(info.sha, 1, 7))

        return blame_text
    elseif #files_data[filepath].blames > 0 then
        return not_commited_blame_text
    else
        return nil
    end
end

local function show_blame_info()
    local filepath = utils.get_filepath()
    local line_number = utils.get_line_number()

    if last_position.filepath == filepath and last_position.line_number == line_number then
        if not need_update_after_horizontal_move then
            return
        else
            need_update_after_horizontal_move = false
        end
    end

    if not files_data[filepath] then
        load_blames(show_blame_info)
        return
    end
    if files_data[filepath].git_repo_path == "" then return end
    if not files_data[filepath].blames then
        load_blames(show_blame_info)
        return
    end

    last_position.filepath = filepath
    last_position.line_number = line_number

    local info = get_blame_info(filepath, line_number)
    current_blame_text = get_blame_text(filepath, info)
    if vim.g.gitblame_print_virtual_text then
        print_blame_text(line_number)
    end
end

local function cleanup_file_data()
    local filepath = vim.api.nvim_buf_get_name(0)
    files_data[filepath] = nil
end

---@param callback fun(current_author: string)
local function find_current_author(callback)
    start_job('git config --get user.name', {
        on_stdout = function(data)
            current_author = data[1]
            if callback then callback(current_author) end
        end
    })
end

local function clear_files_data() files_data = {} end

local function handle_buf_enter()
    git.get_repo_root(function(git_repo_path)
        if git_repo_path == "" then return end

        vim.schedule(function() show_blame_info() end)
    end)
end

local function init()
    date_format_has_relative_time = date_format:match('%%r') ~= nil
    vim.schedule(function() find_current_author(show_blame_info) end)
end

local function handle_text_changed()
    local filepath = utils.get_filepath()
    if not filepath then return end

    local line_number = utils.get_line_number()

    if last_position.filepath == filepath and last_position.line_number == line_number then
        need_update_after_horizontal_move = true
    end

    load_blames(show_blame_info)
end

local function handle_insert_leave()
    local timer = vim.loop.new_timer()
    timer:start(50, 0, vim.schedule_wrap(function() handle_text_changed() end))
end

local function open_commit_url()
    local filepath = utils.get_filepath()
    local line_number = utils.get_line_number()
    local info = get_blame_info(filepath, line_number)
    local sha = info.sha
    local empty_sha = '0000000000000000000000000000000000000000'

    if sha and sha ~= empty_sha then git.open_commit_in_browser(sha) end
end

local function get_current_blame_text()
    return current_blame_text
end

return {
    init = init,
    show_blame_info = show_blame_info,
    clear_virtual_text = clear_virtual_text,
    load_blames = load_blames,
    cleanup_file_data = cleanup_file_data,
    clear_files_data = clear_files_data,
    handle_buf_enter = handle_buf_enter,
    handle_text_changed = handle_text_changed,
    handle_insert_leave = handle_insert_leave,
    open_commit_url = open_commit_url,
    is_blame_info_available = is_blame_info_available,
    is_blame_available = is_blame_available,
    get_current_blame_text = get_current_blame_text
}
